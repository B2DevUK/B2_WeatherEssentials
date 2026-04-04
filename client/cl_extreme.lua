-- ===============================================
-- Module: client/cl_extreme.lua
-- Description: All extreme event handlers.
--              Each event uses a single per-event thread
--              guarded by activeExtremeEvent so that
--              CLEAR_EXTREME_EVENT terminates it cleanly.
--
--              EARTHQUAKE uses a GlobalState state-bag approach:
--               • AddStateBagChangeHandler fires when the server sets or
--                 clears GlobalState.earthquake, including for late joiners.
--               • A per-tick loop applies alternating lateral forces to
--                 vehicles and nearby props, and randomly ragdolls NPCs
--                 and the local player to simulate ground instability.
--               • Camera shake is suppressed automatically when the player
--                 is airborne or in water.
--
--              TSUNAMI uses a dedicated water-level system:
--               • flood_initial.xml loaded for wave + high-water support.
--               • UPDATE_WATER_HEIGHT events from the server call both
--                 ModifyWater() (global plane) AND SetWaterQuadLevel()
--                 on every quad (swim physics). Both are required —
--                 ModifyWater alone avoids quad-edge glitches;
--                 SetWaterQuadLevel alone causes them.
--               • NPC/vehicle spawning is suppressed and existing
--                 NPCs are flagged to drown when water is present.
--               • Population budgets and water.xml are restored on clear.
-- Depends on: sh_constants, sh_utils, config
-- ===============================================

-- -----------------------------------------------
-- State (module-local)
-- -----------------------------------------------
local activeExtremeEvent    = nil
local earthquakeActive      = false  -- guards the earthquake physics tick loop
local particleFxHandle      = nil   -- EXTREME_COLD looped particle
local inTsunami             = false  -- true while the tsunami flood is active
local waterLoaded           = false  -- true once flood_initial.xml has been loaded
local meteorRockModel       = nil   -- cached model hash while meteor shower is active
local hurricaneActive          = false
local cachedHurricaneVehicles  = {}   -- populated by cache thread, read by physics thread
local cachedHurricanePeds      = {}

-- -----------------------------------------------
-- applyWaterHeight(height)
-- Raises/lowers the game world's water level.
-- Must call BOTH:
--   ModifyWater()       — sets the global continuous water plane,
--                         eliminating the hard rectangular quad-edge
--                         glitch seen when using SetWaterQuadLevel alone.
--   SetWaterQuadLevel() — updates individual quad swim/physics boundaries
--                         so players and peds interact correctly with the
--                         water surface (swim, drown, buoyancy).
-- Loop is 1-indexed — GTA V water quads use a 1-based index.
-- -----------------------------------------------
local function applyWaterHeight(height)
    ModifyWater(height)

    local quadCount = GetWaterQuadCount()
    for i = 1, quadCount do
        local ok = GetWaterQuadLevel(i)
        if ok then
            SetWaterQuadLevel(i, height)
        end
    end
end

-- -----------------------------------------------
-- clearExtremeEffects()
-- Shared cleanup invoked by CLEAR_EXTREME_EVENT.
-- -----------------------------------------------
local function clearExtremeEffects()
    StopGameplayCamShaking(true)
    ClearTimecycleModifier()
    SetWindSpeed(2.0)

    if particleFxHandle then
        StopParticleFxLooped(particleFxHandle, false)
        particleFxHandle = nil
    end

    -- Meteor shower cleanup — release cached model
    if meteorRockModel then
        SetModelAsNoLongerNeeded(meteorRockModel)
        meteorRockModel = nil
        B2WE.debugPrint("MeteorShower: model released on clear")
    end

    -- Tsunami cleanup
    if inTsunami then
        inTsunami   = false
        waterLoaded = false

        -- Restore NPC/vehicle spawning
        SetPedPopulationBudget(3)
        SetVehiclePopulationBudget(3)

        -- Force water back to sea level
        applyWaterHeight(0.0)

        -- Reload the full GTA V water map, removing the flood_initial.xml
        -- wave quads and restoring normal ocean/river definitions.
        pcall(function()
            if LoadWaterFromPath then
                local ok = LoadWaterFromPath(GetCurrentResourceName(), 'water.xml')
                if ok ~= 1 then
                    B2WE.debugPrint("Tsunami cleanup: water.xml reload failed")
                end
            end
        end)

        B2WE.debugPrint("Tsunami cleanup: population restored, water reset")
    end

    -- Hurricane cleanup
    if hurricaneActive then
        hurricaneActive          = false
        cachedHurricaneVehicles  = {}
        cachedHurricanePeds      = {}
        SetWindSpeed(2.0)
        SetWind(0.0)
        B2WE.debugPrint("Hurricane cleanup: wind reset")
    end

    SendNUIMessage({ action = "activeEvent", event = nil })
    B2WE.debugPrint("Extreme effects cleared")
end

-- -----------------------------------------------
-- B2WE.applyExtremeEvent(event)
-- Called by cl_main during FULL_STATE_SYNC to restore
-- an already-active extreme event for players joining
-- mid-session.
-- EARTHQUAKE is intentionally absent from the dispatch
-- HURRICANE is also intentionally absent
-- table — GlobalState.earthquake is already set server-side,
-- so AddStateBagChangeHandler fires automatically for any
-- client that joins while the event is active.
-- -----------------------------------------------
function B2WE.applyExtremeEvent(event)
    if not event then return end
    local dispatch = {
        STORM         = B2WE.Events.TRIGGER_STORM,
        EXTREME_COLD  = B2WE.Events.TRIGGER_EXTREME_COLD,
        EXTREME_HEAT  = B2WE.Events.TRIGGER_EXTREME_HEAT,
        TSUNAMI       = B2WE.Events.TRIGGER_TSUNAMI,
        METEOR_SHOWER = B2WE.Events.TRIGGER_METEOR_SHOWER,
    }
    if dispatch[event] then
        TriggerEvent(dispatch[event])
    end
end

-- ===============================================
-- EARTHQUAKE
--
-- Driven by GlobalState.earthquake set by the server:
--   start → GlobalState.earthquake = { force, frequency, seed }
--   stop  → GlobalState.earthquake = nil
--
-- AddStateBagChangeHandler fires for all currently connected
-- clients AND for any player who joins while the event is active,
-- eliminating the need for a separate join-sync step.
--
-- Per-tick loop (frequency ticks/s):
--   1. Suppress or apply ROAD_VIBRATION_SHAKE based on
--      whether the player is airborne / in water.
--   2. Alternate a flip multiplier (1 → -1 → 1 …) so forces
--      push left then right on every tick.
--   3. processEarthquakeEntities() pushes vehicles and nearby
--      props and gives NPCs / the local player a random chance
--      to stumble into a ragdoll.
-- ===============================================

-- -----------------------------------------------
-- processEarthquakeEntities(force, flip)
-- Applies one physics tick of earthquake forces.
-- Called from within the state-bag loop; must run
-- fast — avoid expensive GetGamePool calls here
-- only when the player is actually on the ground.
-- -----------------------------------------------
local function processEarthquakeEntities(force, flip)
    local cfg    = Config.Earthquake or {}
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)

    -- ---- Vehicles ----
    -- Motorcycle (class 8) and Bicycle (class 13) receive a much lower
    -- force multiplier so they tip naturally rather than launching skyward.
    local vehicleMult     = cfg.VehicleForceMultiplier              or 1.0
    local twowheelMult    = cfg.MotorcycleBicycleForceMultiplier    or 0.2

    for _, veh in ipairs(GetGamePool("CVehicle")) do
        if not IsEntityInAir(veh) and not IsEntityInWater(veh) then
            local vClass = GetVehicleClass(veh)
            local mult   = (vClass == 8 or vClass == 13) and twowheelMult or vehicleMult

            -- forceType 1 = MaxForceRot (world-relative impulse).
            -- X-axis push: alternates direction each tick via flip.
            -- isDirectionRel = false  → world-space, not entity-relative.
            -- isForceRel     = false  → absolute Newtons, not mass-scaled.
            ApplyForceToEntity(
                veh, 1,
                force * mult * flip, 0.0, 0.0,
                0.0, 0.0, 0.0,
                0, false, true, false, false, true
            )
        end
    end

    -- ---- Physics props ----
    -- CObject pool contains spawned dynamic props (debris, barrels, etc.).
    -- Static map geometry (buildings, roads) is not in this pool and does
    -- not need to be filtered out.
    local propForce  = cfg.PropForce  or 50.0
    local propRadius = cfg.PropRadius or 50.0

    for _, obj in ipairs(GetGamePool("CObject")) do
        local dist = #(coords - GetEntityCoords(obj))
        if dist <= propRadius then
            ApplyForceToEntity(
                obj, 1,
                propForce * flip, 0.0, 0.0,
                0.0, 0.0, 0.0,
                0, false, true, false, false, true
            )
        end
    end

    -- ---- NPCs ----
    -- Each nearby pedestrian has a per-tick probability of stumbling.
    -- SetPedToRagdollWithFall uses the flip vector as the fall direction
    -- so NPCs tumble in the same alternating lateral direction as the forces.
    local npcChance = cfg.NpcRagdollChance or 0.02

    for _, p in ipairs(GetGamePool("CPed")) do
        if not IsPedAPlayer(p)
            and not IsPedDeadOrDying(p)
            and not IsEntityInAir(p)
            and not IsEntityInWater(p)
            and math.random() < npcChance
        then
            SetPedToRagdollWithFall(
                p, 1500, 2000, 1,
                flip * 1.0, 0.0, 0.0,
                1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
            )
        end
    end

    -- ---- Local player ----
    -- Only ragdolls when on foot; in-vehicle shaking is handled by the
    -- vehicle force above.  Slightly lower chance than NPCs.
    local playerChance = cfg.PlayerRagdollChance or 0.01

    if not IsPedInAnyVehicle(ped, false)
        and not IsPedDeadOrDying(ped)
        and not IsEntityInAir(ped)
        and not IsEntityInWater(ped)
        and math.random() < playerChance
    then
        SetPedToRagdollWithFall(
            ped, 1500, 2000, 1,
            flip * 1.0, 0.0, 0.0,
            1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
        )
    end
end

-- -----------------------------------------------
-- State-bag handler: GlobalState.earthquake
-- value = table  → quake starting; read force/frequency
--         nil    → quake stopping; exit the loop
-- -----------------------------------------------
AddStateBagChangeHandler("earthquake", "global", function(_, _, value)
    if value then
        -- ---- Earthquake starting ----
        earthquakeActive        = true
        activeExtremeEvent      = "EARTHQUAKE"
        B2WE.activeExtremeEvent = "EARTHQUAKE"

        local cfg       = Config.Earthquake or {}
        local force     = value.force     or cfg.Force     or 1000.0
        local frequency = value.frequency or cfg.Frequency or 3.0
        -- Clamp tick interval: at least 50 ms to avoid starving other threads
        local tickMs    = math.max(50, math.floor(1000.0 / frequency))
        local flip      = 1

        SendNUIMessage({ action = "playSound",   sound = "earthquake.wav" })
        SendNUIMessage({ action = "activeEvent", event = "EARTHQUAKE" })
        B2WE.debugPrint(string.format(
            "Earthquake started: force=%.1f freq=%.1f tick=%dms",
            force, frequency, tickMs
        ))

        -- Single persistent tick loop — no new thread per event.
        -- Checks player context each tick so airborne/swimming suppression
        -- and on-foot-only ragdoll guards run without extra threads.
        Citizen.CreateThread(function()
            while earthquakeActive do
                local localPed = PlayerPedId()
                local inAir    = IsEntityInAir(localPed)
                local inWater  = IsEntityInWater(localPed)

                if inAir or inWater then
                    -- Suppress ground tremors; player is not touching the ground.
                    StopGameplayCamShaking(true)
                else
                    ShakeGameplayCam("ROAD_VIBRATION_SHAKE", cfg.CameraShakeIntensity or 0.5)
                    processEarthquakeEntities(force, flip)
                end

                flip = flip * -1   -- alternate direction each tick
                Citizen.Wait(tickMs)
            end

            -- Loop exited — ensure camera shake is fully removed.
            StopGameplayCamShaking(true)
            B2WE.debugPrint("Earthquake loop exited")
        end)
    else
        -- ---- Earthquake stopping (GlobalState.earthquake = nil) ----
        -- Set the guard to false; the loop exits on its next iteration.
        -- clearExtremeEffects() and activeExtremeEvent cleanup are handled
        -- by the CLEAR_EXTREME_EVENT handler which the server also fires.
        earthquakeActive = false
        B2WE.debugPrint("Earthquake state bag cleared")
    end
end)

-- ===============================================
-- HURRICANE
--
-- Directional wind event driven by GlobalState.hurricane:
--   { active, direction = vector3, force = number }
--
-- The state bag fires on every server write (including direction
-- shifts), so wind direction is always kept in sync. Thread
-- lifecycle is guarded by hurricaneActive so shifts do not
-- spawn duplicate threads.
--
-- Three concerns separated by responsibility:
--   State bag handler — environment natives (weather, wind)
--   Cache thread      — entity discovery every 1000ms
--   Physics thread    — force application every 50ms
-- ===============================================
AddStateBagChangeHandler("hurricane", "global", function(_, _, value)
    if value then
        -- Always update wind direction so shifts from the server take
        -- effect immediately without needing the threads to wake.
        if value.direction then
            SetWindDirection(value.direction.x)
        end

        if not hurricaneActive then
            -- ---- First activation ----
            hurricaneActive         = true
            activeExtremeEvent      = "HURRICANE"
            B2WE.activeExtremeEvent = "HURRICANE"

            local cfg         = Config.Hurricane or {}
            local pullR       = cfg.PullRadius        or 100.0
            local vForce      = cfg.VehicleForce      or 200.0
            local vSpeedScale = cfg.VehicleSpeedScale or 0.15
            local ragChance   = cfg.PedRagdollChance  or 0.01
            local pSlide      = cfg.PedSlideForce     or 350.0

            -- Read authoritative environment values from GlobalState so every
            -- client uses identical settings regardless of local config.
            local weatherType = value.weatherType or cfg.WeatherType or "THUNDER"
            local windSpeed   = value.windSpeed   or cfg.WindSpeed   or 90.0

            SendNUIMessage({ action = "activeEvent", event = "HURRICANE" })
            B2WE.debugPrint("Extreme event: HURRICANE")

            -- ---- Phase 2: Environment ----
            SetWeatherTypePersist(weatherType)
            SetWeatherTypeNowPersist(weatherType)
            SetWind(1.0)
            SetWindSpeed(windSpeed)

            -- ---- Phase 3: Cache thread ----
            -- Scans CVehicle and CPed pools every 1000ms. Stores results in
            -- two separate tables so the physics thread avoids GetEntityType
            -- checks inside its tight loop.
            -- GetInteriorFromEntity == 0 excludes entities inside buildings
            -- without an expensive ray cast.
            Citizen.CreateThread(function()
                while hurricaneActive do
                    local origin  = GetEntityCoords(PlayerPedId())
                    local newVehs = {}
                    local newPeds = {}

                    for _, veh in ipairs(GetGamePool("CVehicle")) do
                        local dist = #(GetEntityCoords(veh) - origin)
                        if dist <= pullR and GetInteriorFromEntity(veh) == 0 then
                            newVehs[#newVehs + 1] = veh
                        end
                    end

                    for _, p in ipairs(GetGamePool("CPed")) do
                        if not IsPedInAnyVehicle(p, false) then
                            local dist = #(GetEntityCoords(p) - origin)
                            if dist <= pullR and GetInteriorFromEntity(p) == 0 then
                                newPeds[#newPeds + 1] = p
                            end
                        end
                    end

                    cachedHurricaneVehicles = newVehs
                    cachedHurricanePeds     = newPeds

                    Citizen.Wait(1000)
                end
            end)

            -- ---- Phase 4: Physics thread ----
            -- Re-reads GlobalState each tick so direction shifts published
            -- by the server are picked up immediately without the thread
            -- needing to restart or receive a separate event.
            Citizen.CreateThread(function()
                while hurricaneActive do
                    local state = GlobalState.hurricane
                    if state and state.direction and state.force then
                        local dir   = state.direction
                        local scale = state.force

                        -- Vehicles: linear push along wind direction.
                        -- Faster vehicles catch more wind (aerodynamic scaling).
                        -- SetEntityDynamic un-freezes parked cars so they react.
                        for _, veh in ipairs(cachedHurricaneVehicles) do
                            if DoesEntityExist(veh) and not IsEntityDead(veh) then
                                local spd  = GetEntitySpeed(veh)
                                local mult = scale * (vForce + spd * vSpeedScale)
                                SetEntityDynamic(veh, true)
                                ApplyForceToEntityCenterOfMass(
                                    veh, 0,
                                    dir.x * mult, dir.y * mult, 0.0,
                                    false, false, true, true
                                )
                            end
                        end

                        -- Peds: random ragdoll + directional slide while down.
                        -- Slide force only fires when already ragdolled so peds
                        -- visibly tumble along the ground in the wind direction.
                        for _, p in ipairs(cachedHurricanePeds) do
                            if DoesEntityExist(p) and not IsPedDeadOrDying(p) then
                                if math.random() < ragChance then
                                    SetPedToRagdoll(p, 1500, 2000, 0, false, false, false)
                                end

                                if IsPedRagdoll(p) then
                                    ApplyForceToEntityCenterOfMass(
                                        p, 0,
                                        dir.x * pSlide, dir.y * pSlide, 0.0,
                                        false, false, true, true
                                    )
                                end
                            end
                        end
                    end

                    Citizen.Wait(50)
                end
            end)
        end

    elseif not value then
        hurricaneActive         = false
        B2WE.activeExtremeEvent = nil
        cachedHurricaneVehicles = {}
        cachedHurricanePeds     = {}
        SetWindSpeed(2.0)
        SetWind(0.0)
        B2WE.debugPrint("Hurricane state bag cleared")
    end
end)

-- ===============================================
-- STORM
-- ===============================================
AddEventHandler(B2WE.Events.TRIGGER_STORM, function()
    activeExtremeEvent      = "STORM"
    B2WE.activeExtremeEvent = "STORM"

    SetWindSpeed(12.0)
    SetWindDirection(-1.0)
    ShakeGameplayCam("SKY_DIVING_SHAKE", 0.2)

    SendNUIMessage({ action = "activeEvent", event = "STORM" })
    B2WE.debugPrint("Extreme event: STORM")
end)

-- ===============================================
-- EXTREME_COLD
-- ===============================================
AddEventHandler(B2WE.Events.TRIGGER_EXTREME_COLD, function()
    activeExtremeEvent      = "EXTREME_COLD"
    B2WE.activeExtremeEvent = "EXTREME_COLD"

    SetTimecycleModifier("dark_cloud_dist")
    SetTimecycleModifierStrength(0.6)

    SendNUIMessage({ action = "activeEvent", event = "EXTREME_COLD" })
    B2WE.debugPrint("Extreme event: EXTREME_COLD")

    Citizen.CreateThread(function()
        RequestNamedPtfxAsset("core")
        local deadline = GetGameTimer() + 5000
        while not HasNamedPtfxAssetLoaded("core") and GetGameTimer() < deadline do
            Citizen.Wait(0)
        end

        if HasNamedPtfxAssetLoaded("core") then
            UseParticleFxAsset("core")
            local coords     = GetEntityCoords(PlayerPedId())
            particleFxHandle = StartParticleFxLoopedAtCoord(
                "ent_amb_fog_bank_small",
                coords.x, coords.y, coords.z,
                0.0, 0.0, 0.0, 2.0,
                false, false, false, false
            )
        end

        while activeExtremeEvent == "EXTREME_COLD" do
            if particleFxHandle then
                local coords = GetEntityCoords(PlayerPedId())
                StopParticleFxLooped(particleFxHandle, false)
                UseParticleFxAsset("core")
                particleFxHandle = StartParticleFxLoopedAtCoord(
                    "ent_amb_fog_bank_small",
                    coords.x, coords.y, coords.z,
                    0.0, 0.0, 0.0, 2.0,
                    false, false, false, false
                )
            end
            Citizen.Wait(500)
        end

        ClearTimecycleModifier()
        if particleFxHandle then
            StopParticleFxLooped(particleFxHandle, false)
            particleFxHandle = nil
        end
    end)
end)

-- ===============================================
-- EXTREME_HEAT
-- ===============================================
AddEventHandler(B2WE.Events.TRIGGER_EXTREME_HEAT, function()
    activeExtremeEvent      = "EXTREME_HEAT"
    B2WE.activeExtremeEvent = "EXTREME_HEAT"

    SetTimecycleModifier("REDMIST_blend")
    SetTimecycleModifierStrength(0.5)

    SendNUIMessage({ action = "activeEvent", event = "EXTREME_HEAT" })
    B2WE.debugPrint("Extreme event: EXTREME_HEAT")
end)

-- ===============================================
-- TSUNAMI
--
-- Phase flow (server-driven timing, client reacts):
--   1. This handler fires on TRIGGER_TSUNAMI:
--        • Loads flood_initial.xml (wave quads + extended water bounds).
--        • Freezes NPC/vehicle population.
--        • Plays warning messages.
--        • Starts the NPC drowning thread.
--   2. UPDATE_WATER_HEIGHT ticks arrive from the server and call
--      applyWaterHeight() — ModifyWater + all quad levels updated.
--   3. CLEAR_EXTREME_EVENT (auto after drain or admin-forced) calls
--      clearExtremeEffects() which restores population, resets water
--      to 0.0, and reloads water.xml to remove the flood wave quads.
-- ===============================================
AddEventHandler(B2WE.Events.TRIGGER_TSUNAMI, function()
    activeExtremeEvent      = "TSUNAMI"
    B2WE.activeExtremeEvent = "TSUNAMI"
    inTsunami               = true

    -- ---- Freeze spawning ----
    SetPedPopulationBudget(0)
    SetVehiclePopulationBudget(0)

    -- ---- Load flood water definitions ----
    -- flood_initial.xml defines the large wave-quad that creates the
    -- visual tsunami effect. LoadWaterFromPath return value 1 = success.
    if not waterLoaded then
        waterLoaded = true
        pcall(function()
            if LoadWaterFromPath then
                local ok = LoadWaterFromPath(GetCurrentResourceName(), 'flood_initial.xml')
                B2WE.debugPrint("flood_initial.xml load: " .. tostring(ok))
                if ok ~= 1 then
                    B2WE.debugPrint("WARNING: flood_initial.xml failed to load — is it listed under data_file 'WATER_FILE' in fxmanifest.lua?")
                end
            end
        end)
    end

    SendNUIMessage({ action = "activeEvent", event = "TSUNAMI" })
    B2WE.debugPrint("Extreme event: TSUNAMI")

    -- ---- Warning messages ----
    Citizen.CreateThread(function()
        local warnings = {
            "^1[TSUNAMI WARNING] Extreme waves inbound! Seek higher ground immediately!",
            "^1[TSUNAMI WARNING] Coastal areas are at critical risk. Move inland NOW!",
            "^1[TSUNAMI WARNING] This is not a drill. Find high ground!",
        }
        for _, msg in ipairs(warnings) do
            if activeExtremeEvent ~= "TSUNAMI" then break end
            TriggerEvent("chat:addMessage", { args = { msg } })
            Citizen.Wait(4000)
        end
        if activeExtremeEvent == "TSUNAMI" then
            ShakeGameplayCam("LARGE_EXPLOSION_SHAKE", 0.15)
        end
    end)

    -- ---- NPC drowning thread ----
    -- GetWaterQuadAtCoords_3d returns -1 when no water quad exists at
    -- the given coords; any other value means water is present.
    -- Runs every 2 seconds — enough to catch newly streamed peds without
    -- hammering the CPU.
    Citizen.CreateThread(function()
        while activeExtremeEvent == "TSUNAMI" do
            local ped    = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local quad   = GetWaterQuadAtCoords_3d(coords.x, coords.y, coords.z)

            if quad ~= -1 then
                local allPeds = GetGamePool('CPed')
                for _, p in ipairs(allPeds) do
                    if not IsPedAPlayer(p) then
                        SetPedConfigFlag(p, 65, true)   -- DROWNING_IN_WATER
                        SetPedDiesInWater(p, true)
                    end
                end
            end

            Citizen.Wait(2000)
        end
    end)
end)

-- ===============================================
-- METEOR SHOWER
--
-- Phase flow (server-driven spawn timing):
--   1. TRIGGER_METEOR_SHOWER fires — sets state, shows warnings,
--      pre-loads and caches the rock model.
--   2. SPAWN_METEOR ticks arrive from the server controller. Each
--      carries an offsetX/offsetY so all clients spawn the rock at
--      the same relative position around their player — visually
--      identical showers without networked entities.
--   3. Per-meteor tracking thread watches height above ground.
--      On impact: AddExplosion then DeleteEntity.
--      Failsafe: force-delete after Config.MeteorShower.Timeout seconds.
--   4. CLEAR_EXTREME_EVENT stops the server controller, sets
--      activeExtremeEvent = nil (SPAWN_METEOR guards on this),
--      and releases the cached model via clearExtremeEffects.
-- ===============================================
AddEventHandler(B2WE.Events.TRIGGER_METEOR_SHOWER, function()
    activeExtremeEvent      = "METEOR_SHOWER"
    B2WE.activeExtremeEvent = "METEOR_SHOWER"

    local cfg       = Config.MeteorShower or {}
    local modelName = cfg.Model or "prop_rock_4_d"

    SendNUIMessage({ action = "activeEvent", event = "METEOR_SHOWER" })
    B2WE.debugPrint("Extreme event: METEOR_SHOWER")

    -- ---- Warning messages ----
    Citizen.CreateThread(function()
        local warnings = {
            "^1[METEOR SHOWER] Incoming debris from the sky! Seek cover immediately!",
            "^1[METEOR SHOWER] Rocks falling across the area — stay away from open ground!",
            "^1[METEOR SHOWER] This is not a drill. Find shelter NOW!",
        }
        for _, msg in ipairs(warnings) do
            if activeExtremeEvent ~= "METEOR_SHOWER" then break end
            TriggerEvent("chat:addMessage", { args = { msg } })
            Citizen.Wait(4000)
        end
    end)

    -- ---- Pre-load and cache the rock model ----
    -- SPAWN_METEOR events will start arriving immediately; having the
    -- model ready avoids per-meteor load stalls.
    Citizen.CreateThread(function()
        local rockModel  = GetHashKey(modelName)
        RequestModel(rockModel)
        local deadline = GetGameTimer() + 5000
        while not HasModelLoaded(rockModel) and GetGameTimer() < deadline do
            Citizen.Wait(10)
        end
        if HasModelLoaded(rockModel) then
            meteorRockModel = rockModel
            B2WE.debugPrint("MeteorShower: model cached")
        else
            B2WE.debugPrint("MeteorShower: model '" .. modelName .. "' failed to load")
        end
    end)
end)

-- ===============================================
-- SPAWN_METEOR  (server → client, meteor shower only)
--
-- offsetX  number   X offset from player position (metres).
-- offsetY  number   Y offset from player position (metres).
-- height   number   Z offset above player position (metres).
--
-- The server generates the offsets so every client spawns the
-- rock at the same relative position — consistent shower pattern
-- across all players without needing networked entities.
-- ===============================================
AddEventHandler(B2WE.Events.SPAWN_METEOR, function(offsetX, offsetY, height)
    if activeExtremeEvent ~= "METEOR_SHOWER" then return end
    if not meteorRockModel or not HasModelLoaded(meteorRockModel) then return end

    local cfg    = Config.MeteorShower or {}
    local fallSpd = cfg.FallSpeed      or -100.0
    local drift   = cfg.LateralDrift   or 15
    local expType = cfg.ExplosionType  or 29
    local expRad  = cfg.ExplosionRadius or 8.0
    local timeout = (cfg.Timeout or 8) * 1000
    local scale   = cfg.Scale          or 1.0

    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local meteor = CreateObject(
        meteorRockModel,
        coords.x + offsetX,
        coords.y + offsetY,
        coords.z + height,
        true, true, true
    )

    if not DoesEntityExist(meteor) then return end

    SetEntityDynamic(meteor, true)

    -- Physics params matched to known-working reference.
    -- Param 6 (700.0) provides the impulse force that keeps the
    -- rock moving; setting it to 0 kills velocity immediately.
    SetObjectPhysicsParams(meteor, 99999.0, 0.0, 0.0, 0.0, 0.0, 700.0, 0.0, 0.0, 0.0, 0.0, 0.0)

    -- Downward velocity + small random lateral drift for variety
    local vx = math.random(-drift * 10, drift * 10) * 0.1
    local vy = math.random(-drift * 10, drift * 10) * 0.1
    SetEntityVelocity(meteor, vx, vy, fallSpd)

    -- ---- Per-meteor impact/cleanup thread ----
    local spawnTime = GetGameTimer()
    Citizen.CreateThread(function()
        while DoesEntityExist(meteor) do
            -- Failsafe: hard delete after Timeout seconds
            if GetGameTimer() - spawnTime > timeout then
                B2WE.debugPrint("MeteorShower: timeout — deleting stale rock")
                DeleteEntity(meteor)
                break
            end

            -- Ground proximity is the sole impact signal.
            -- Velocity stall is NOT used — at spawn vel.z reads
            -- near-zero before physics applies, causing instant deletion.
            if GetEntityHeightAboveGround(meteor) < 2.5 then
                local impactCoords = GetEntityCoords(meteor)
                AddExplosion(
                    impactCoords.x, impactCoords.y, impactCoords.z,
                    expType, expRad, true, false, 1.0
                )
                DeleteEntity(meteor)
                break
            end

            Citizen.Wait(50)
        end
    end)
end)

-- ===============================================
-- UPDATE_WATER_HEIGHT  (server → client, tsunami only)
--
-- height     number   Authoritative flood level in metres.
-- forceReset bool     Hard-reset to 0 — sent when admin clears the event.
-- ===============================================
AddEventHandler(B2WE.Events.UPDATE_WATER_HEIGHT, function(height, forceReset)
    if not inTsunami and not forceReset then return end

    -- Load water file on first height update if TRIGGER_TSUNAMI was
    -- missed (e.g. player joined mid-event).
    if inTsunami and not waterLoaded then
        waterLoaded = true
        pcall(function()
            if LoadWaterFromPath then
                LoadWaterFromPath(GetCurrentResourceName(), 'flood_initial.xml')
            end
        end)
    end

    applyWaterHeight(height)

    B2WE.debugPrint(string.format(
        "Water height applied: %.2fm (forceReset=%s)", height, tostring(forceReset)
    ))
end)

-- ===============================================
-- CLEAR_EXTREME_EVENT
-- ===============================================
AddEventHandler(B2WE.Events.CLEAR_EXTREME_EVENT, function()
    B2WE.debugPrint("Extreme event cleared (was: " .. tostring(activeExtremeEvent) .. ")")
    activeExtremeEvent      = nil
    B2WE.activeExtremeEvent = nil
    clearExtremeEffects()
end)