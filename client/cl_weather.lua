-- ===============================================
-- Module: client/cl_weather.lua
-- Description: Weather update handlers, region detection,
--              and single dirty-flag regional weather thread.
-- Depends on: sh_constants, sh_utils, config
-- ===============================================

-- -----------------------------------------------
-- Shared client state
-- Initialised here; read/written by other modules
-- via the B2WE namespace.
-- -----------------------------------------------
B2WE.currentWeather     = "CLEAR"
B2WE.currentSeason      = "SPRING"
B2WE.currentRegion      = nil
B2WE.weatherSyncEnabled = true

-- -----------------------------------------------
-- Wind speed (m/s) per weather type.
-- Clamped by the engine to 0–12; BLIZZARD hits max.
-- -----------------------------------------------
local WIND_SPEEDS = {
    CLEAR      = 1.0,  EXTRASUNNY = 0.5,  CLOUDS   = 2.0,
    OVERCAST   = 3.0,  RAIN       = 5.0,  CLEARING = 2.5,
    THUNDER    = 8.0,  SMOG       = 1.5,  FOGGY    = 1.0,
    XMAS       = 3.0,  SNOWLIGHT  = 4.0,  BLIZZARD = 12.0,
}

-- -----------------------------------------------
-- State (module-local)
-- -----------------------------------------------
local regionWeatherMap   = {}
local regionWeatherDirty = false

-- -----------------------------------------------
-- applyWeather(weather, transitionTime)
-- Applies a weather type locally, sets wind speed,
-- updates shared state, and notifies the NUI.
-- transitionTime = 0 → instant; > 0 → smooth fade.
-- -----------------------------------------------
local function applyWeather(weather, transitionTime)
    if transitionTime and transitionTime > 0 then
        SetWeatherTypeOvertimePersist(weather, transitionTime)
    else
        SetWeatherTypeNowPersist(weather)
    end

    local wind = WIND_SPEEDS[weather] or 2.0
    SetWindSpeed(wind)
    SetWindDirection(-1.0)

    B2WE.currentWeather = weather
    B2WE.debugPrint("Weather applied: " .. weather)

    SendNUIMessage({
        action  = "updateWeather",
        weather = weather,
        region  = B2WE.currentRegion or "Global",
        season  = B2WE.currentSeason or "SPRING",
    })
end

-- -----------------------------------------------
-- detectRegion() → string|nil
-- Returns the name of the Config.Regions entry whose
-- circle (x, y, radius) contains the player's position,
-- or nil if the player is outside all defined regions.
-- Returns nil immediately when UseRegionalWeather = false.
-- -----------------------------------------------
local function detectRegion()
    if not Config.UseRegionalWeather then return nil end

    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local px, py = coords.x, coords.y

    for regionName, data in pairs(Config.Regions) do
        local dx = px - data.x
        local dy = py - data.y
        if math.sqrt(dx * dx + dy * dy) <= data.radius then
            return regionName
        end
    end

    return nil
end

-- -----------------------------------------------
-- Event: UPDATE_WEATHER  (global, non-regional)
-- Fired by the server when UseRegionalWeather = false.
-- -----------------------------------------------
AddEventHandler(B2WE.Events.UPDATE_WEATHER, function(weather, transitionTime)
    if not B2WE.weatherSyncEnabled then return end
    applyWeather(weather, transitionTime or 10.0)
end)

-- -----------------------------------------------
-- Event: UPDATE_REGIONAL_WEATHER
-- Stores the new region map and marks it dirty so
-- the detection thread re-evaluates immediately.
-- -----------------------------------------------
AddEventHandler(B2WE.Events.UPDATE_REGIONAL_WEATHER, function(regionMap, transitionTime)
    if not B2WE.weatherSyncEnabled then return end
    regionWeatherMap   = regionMap
    regionWeatherDirty = true
end)

-- -----------------------------------------------
-- Region detection thread
-- Single persistent thread with a dirty flag —
-- no new threads spawned per weather event (bug fix).
-- Runs every second. Applies regional weather when:
--   • the player has moved into a different region, or
--   • regionWeatherMap was just updated (dirty flag).
-- Falls back to "City" when outside all regions.
-- -----------------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)

        if not Config.UseRegionalWeather or not B2WE.weatherSyncEnabled then
            regionWeatherDirty = false
        else
            local newRegion = detectRegion()

            if newRegion ~= B2WE.currentRegion or regionWeatherDirty then
                B2WE.currentRegion = newRegion
                regionWeatherDirty = false

                local weather = (newRegion and regionWeatherMap[newRegion])
                             or regionWeatherMap["City"]
                             or "CLEAR"

                applyWeather(weather, 10.0)
            end
        end
    end
end)
