-- ===============================================
-- Module: server/sv_extreme.lua
-- Description: Extreme event state, per-event broadcasts,
--              and clear broadcast.
--              Includes the server-side tsunami water controller
--              which broadcasts synchronized water heights to all
--              clients so every player sees an identical flood level.
-- Depends on: sh_constants, sh_utils, config
-- ===============================================

-- -----------------------------------------------
-- State (module-local)
-- -----------------------------------------------
local currentExtremeEvent = nil

-- Tsunami water controller state
local tsunamiWaterHeight = 0.0   -- current authoritative flood level (metres)
local tsunamiRunning     = false  -- guards the controller thread

-- Meteor shower controller state
local meteorRunning      = false  -- guards the controller thread

-- Hurricane controller state
local hurricaneRunning = false  -- guards the movement thread

-- -----------------------------------------------
-- Dispatch map: extreme event name → client event constant.
-- EARTHQUAKE is omitted — it is driven by GlobalState.earthquake
-- HURRICANE is also omitted for the same reason
-- so all clients receive parameters automatically, including
-- players who join while the event is already active.
-- -----------------------------------------------
local EVENT_DISPATCH = {
    STORM        = B2WE.Events.TRIGGER_STORM,
    EXTREME_COLD = B2WE.Events.TRIGGER_EXTREME_COLD,
    EXTREME_HEAT = B2WE.Events.TRIGGER_EXTREME_HEAT,
    TSUNAMI      = B2WE.Events.TRIGGER_TSUNAMI,
    METEOR_SHOWER = B2WE.Events.TRIGGER_METEOR_SHOWER,
}

-- -----------------------------------------------
-- B2WE.startMeteorShowerController()
-- Runs the meteor spawn broadcaster in a detached thread.
-- Each tick generates one random X/Y offset and broadcasts
-- SPAWN_METEOR to all clients. Every client adds the offset
-- to their own player position — visually identical showers
-- without needing networked entities.
-- Stopped by setting meteorRunning = false in clearExtremeEvent.
-- -----------------------------------------------
function B2WE.startMeteorShowerController()
    if meteorRunning then
        B2WE.debugPrint("startMeteorShowerController: already running, skipping")
        return
    end

    meteorRunning = true

    Citizen.CreateThread(function()
        local cfg    = Config.MeteorShower or {}
        local radius = cfg.SpawnRadius  or 80
        local height = cfg.SpawnHeight  or 60

        B2WE.debugPrint("Meteor shower controller: running")

        while meteorRunning do
            local offsetX = math.random(-radius, radius)
            local offsetY = math.random(-radius, radius)
            TriggerClientEvent(B2WE.Events.SPAWN_METEOR, -1, offsetX, offsetY, height)
            Citizen.Wait(cfg.SpawnInterval or 500)
        end

        B2WE.debugPrint("Meteor shower controller: exited")
    end)
end

-- -----------------------------------------------
-- B2WE.startHurricaneController()
-- Publishes GlobalState.hurricane = { active, direction, force,
-- weatherType, windSpeed } on startup, then loops sleeping a random
-- interval between DirectionShiftMin and DirectionShiftMax seconds
-- before publishing a new random wind direction.
-- Clients read GlobalState directly in their state-bag handler
-- so direction updates are applied instantly with no extra event.
-- Stopped by setting hurricaneRunning = false in clearExtremeEvent,
-- which also nils GlobalState.hurricane to fire the client handler.
-- -----------------------------------------------
function B2WE.startHurricaneController()
    if hurricaneRunning then
        B2WE.debugPrint("startHurricaneController: already running, skipping")
        return
    end

    hurricaneRunning = true

    Citizen.CreateThread(function()
        local cfg         = Config.Hurricane or {}
        local force       = cfg.Force             or 3.0
        local weatherType = cfg.WeatherType       or "THUNDER"
        local windSpeed   = cfg.WindSpeed         or 90.0
        local shiftMin    = (cfg.DirectionShiftMin or 10) * 1000
        local shiftMax    = (cfg.DirectionShiftMax or 30) * 1000

        local function randomDir()
            local a = math.random() * math.pi * 2
            return vector3(math.cos(a), math.sin(a), 0.0)
        end

        local dir = randomDir()

        -- Publish initial state. AddStateBagChangeHandler fires immediately
        -- on all connected clients and on any player who joins mid-event.
        -- weatherType and windSpeed are included so clients never read
        -- local config — every machine uses identical values.
        GlobalState.hurricane = {
            active      = true,
            direction   = dir,
            force       = force,
            weatherType = weatherType,
            windSpeed   = windSpeed,
        }
        B2WE.debugPrint(string.format(
            "Hurricane started: dir=%.2f,%.2f force=%.1f", dir.x, dir.y, force
        ))

        while hurricaneRunning do
            local window = math.max(0, shiftMax - shiftMin)
            Citizen.Wait(shiftMin + math.random(0, window))
            if not hurricaneRunning then break end

            -- Pick a new random direction and overwrite GlobalState.
            -- The state-bag handler on every client fires instantly, updating
            -- SetWindDirection and the physics thread's dir reference together
            -- so there is no frame where wind visuals and forces disagree.
            dir = randomDir()
            GlobalState.hurricane = {
                active      = true,
                direction   = dir,
                force       = force,
                weatherType = weatherType,
                windSpeed   = windSpeed,
            }
            B2WE.debugPrint(string.format(
                "Hurricane direction shifted: %.2f,%.2f", dir.x, dir.y
            ))
        end

        B2WE.debugPrint("Hurricane controller exited")
    end)
end

-- -----------------------------------------------
-- B2WE.startTsunamiWater()
-- Runs the full tsunami flood sequence in a detached
-- thread. Phases:
--   1. Warning  — waits Config.Tsunami.WarningDuration s
--                 while the client shows chat warnings.
--   2. Rise     — increments tsunamiWaterHeight by
--                 RiseSpeed every TickRate ms, broadcasting
--                 each step via UPDATE_WATER_HEIGHT.
--   3. Hold     — holds at MaxWaterHeight for
--                 PeakHoldDuration seconds.
--   4. Drain    — decrements at DrainSpeed per tick back
--                 to 0.0, then auto-clears the event.
--
-- Calling clearExtremeEvent() at any point sets
-- tsunamiRunning = false, which exits rise/hold
-- immediately and skips the natural drain — the
-- clearExtremeEvent caller sends a force-reset (height 0)
-- directly so the client world recovers instantly.
-- -----------------------------------------------
function B2WE.startTsunamiWater()
    if tsunamiRunning then
        B2WE.debugPrint("startTsunamiWater: controller already running, skipping")
        return
    end

    tsunamiRunning     = true
    tsunamiWaterHeight = 0.0

    Citizen.CreateThread(function()
        local cfg = Config.Tsunami

        -- ---- Phase 1: Warning ----
        B2WE.debugPrint("Tsunami phase: WARNING (" .. cfg.WarningDuration .. "s)")
        local elapsed = 0
        while tsunamiRunning and elapsed < cfg.WarningDuration * 1000 do
            Citizen.Wait(100)
            elapsed = elapsed + 100
        end
        if not tsunamiRunning then return end   -- aborted during warning

        -- ---- Phase 2: Rise ----
        B2WE.debugPrint("Tsunami phase: RISE → " .. cfg.MaxWaterHeight .. "m")
        while tsunamiRunning and tsunamiWaterHeight < cfg.MaxWaterHeight do
            tsunamiWaterHeight = math.min(
                tsunamiWaterHeight + cfg.RiseSpeed,
                cfg.MaxWaterHeight
            )
            TriggerClientEvent(B2WE.Events.UPDATE_WATER_HEIGHT, -1, tsunamiWaterHeight, false)
            Citizen.Wait(cfg.TickRate)
        end
        if not tsunamiRunning then return end   -- aborted mid-rise

        -- ---- Phase 3: Hold ----
        B2WE.debugPrint("Tsunami phase: HOLD (" .. cfg.PeakHoldDuration .. "s)")
        elapsed = 0
        while tsunamiRunning and elapsed < cfg.PeakHoldDuration * 1000 do
            Citizen.Wait(100)
            elapsed = elapsed + 100
        end
        if not tsunamiRunning then return end   -- aborted during hold

        -- ---- Phase 4: Drain ----
        B2WE.debugPrint("Tsunami phase: DRAIN")
        while tsunamiWaterHeight > 0.0 do
            tsunamiWaterHeight = math.max(
                tsunamiWaterHeight - cfg.DrainSpeed,
                0.0
            )
            TriggerClientEvent(B2WE.Events.UPDATE_WATER_HEIGHT, -1, tsunamiWaterHeight, false)
            Citizen.Wait(cfg.TickRate)
        end

        -- ---- Natural completion ----
        tsunamiRunning = false
        B2WE.debugPrint("Tsunami: drain complete, auto-clearing event")

        -- Only auto-clear if TSUNAMI is still the active event (an admin may
        -- have already cleared it while the drain was finishing).
        if currentExtremeEvent == "TSUNAMI" then
            -- Use the internal clear path — don't force-reset water because
            -- we just drained it to 0 naturally.
            currentExtremeEvent = nil
            TriggerClientEvent(B2WE.Events.CLEAR_EXTREME_EVENT, -1)
        end
    end)
end

-- -----------------------------------------------
-- B2WE.triggerExtremeEvent(event)
-- Validates the event name against Config.ExtremeEvents,
-- records state, and fires the appropriate client event.
-- EARTHQUAKE uses GlobalState so late-joining players receive
-- parameters automatically from the state-bag system.
-- For TSUNAMI, also starts the server-side water controller.
-- -----------------------------------------------
function B2WE.triggerExtremeEvent(event)
    if not Config.ExtremeEvents[event] then
        B2WE.debugPrint("triggerExtremeEvent: event disabled or unknown '" .. tostring(event) .. "'")
        return
    end

    currentExtremeEvent = event
    B2WE.debugPrint("Extreme event triggered: " .. event)

    -- EARTHQUAKE — publish parameters via GlobalState so the client-side
    -- AddStateBagChangeHandler fires on all connected clients and also on
    -- any player who joins while the event is active.
    if event == "EARTHQUAKE" then
        local cfg = Config.Earthquake or {}
        GlobalState.earthquake = {
            force     = cfg.Force     or 1000.0,
            frequency = cfg.Frequency or 3.0,
            seed      = math.random(10000),   -- unique per trigger for future RNG use
        }
        B2WE.debugPrint(string.format(
            "Earthquake GlobalState set: force=%.1f freq=%.1f",
            GlobalState.earthquake.force, GlobalState.earthquake.frequency
        ))
        return
    end

    if event == "METEOR_SHOWER" then
        -- Trigger client state + model load, then start server-side spawn broadcaster
        TriggerClientEvent(B2WE.Events.TRIGGER_METEOR_SHOWER, -1)
        B2WE.startMeteorShowerController()
        return
    end

    if event == "HURRICANE" then
        -- Parameters live in GlobalState so late-joining clients receive them
        -- automatically via AddStateBagChangeHandler — no separate join-sync needed.
        B2WE.startHurricaneController()
        return
    end

    local clientEvent = EVENT_DISPATCH[event]
    if not clientEvent then
        B2WE.debugPrint("triggerExtremeEvent: no dispatch entry for '" .. tostring(event) .. "'")
        return
    end

    TriggerClientEvent(clientEvent, -1)

    if event == "TSUNAMI" then
        B2WE.startTsunamiWater()
    end
end

-- -----------------------------------------------
-- B2WE.clearExtremeEvent()
-- Clears the active extreme event and notifies all clients.
-- EARTHQUAKE: nils GlobalState.earthquake so the client-side
-- state-bag handler fires and exits the physics loop.
-- TSUNAMI: aborts the controller and force-resets water to 0.0.
-- -----------------------------------------------
function B2WE.clearExtremeEvent()
    local wasEvent = currentExtremeEvent
    currentExtremeEvent = nil

    if wasEvent == "EARTHQUAKE" then
        -- Setting to nil removes the key from the state bag and fires the
        -- change handler on all clients with value = nil, which exits the loop.
        GlobalState.earthquake = nil
        B2WE.debugPrint("Earthquake GlobalState cleared")
    end

    if wasEvent == "TSUNAMI" then
        tsunamiRunning     = false
        tsunamiWaterHeight = 0.0
        TriggerClientEvent(B2WE.Events.UPDATE_WATER_HEIGHT, -1, 0.0, true)
    end

    if wasEvent == "METEOR_SHOWER" then
        meteorRunning = false
    end

    if wasEvent == "HURRICANE" then
        hurricaneRunning = false
        -- Nil removes the state-bag key and fires the change handler on every
        -- client with value = nil, which exits all three client-side threads.
        GlobalState.hurricane = nil
        B2WE.debugPrint("Hurricane GlobalState cleared")
    end

    B2WE.debugPrint("Extreme event cleared (was: " .. tostring(wasEvent) .. ")")
    TriggerClientEvent(B2WE.Events.CLEAR_EXTREME_EVENT, -1)
end

-- -----------------------------------------------
-- B2WE.getCurrentExtremeEvent() → string|nil
-- Returns the active extreme event name, or nil if none.
-- Used by sv_main for full-state sync on player join.
-- -----------------------------------------------
function B2WE.getCurrentExtremeEvent()
    return currentExtremeEvent
end

-- -----------------------------------------------
-- Export-facing globals (wired up in sv_exports.lua)
-- -----------------------------------------------
function TriggerExtremeEvent(event)
    B2WE.triggerExtremeEvent(event)
end

function ClearExtremeEvent()
    B2WE.clearExtremeEvent()
end

function GetCurrentExtremeWeather()
    return B2WE.getCurrentExtremeEvent()
end