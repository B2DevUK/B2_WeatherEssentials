-- ===============================================
-- Module: server/sv_forecast.lua
-- Description: Pre-generated weather forecast queue.
--              Regenerated on every weather change and season change.
--              Exposes B2WE.broadcastForecast() called from sv_weather
--              and sv_seasons via nil-guard.
-- Depends on: sh_constants, sh_utils, config, sv_weather, sv_seasons
-- ===============================================

-- -----------------------------------------------
-- State (module-local)
-- -----------------------------------------------
local forecastQueue = {}

-- -----------------------------------------------
-- generateForecast()
-- Builds Config.ForecastSteps entries using the current
-- season weights (if EnableSeasons = true).
-- Each entry: { weather = "RAIN", estimatedIn = "~30 min" }
-- -----------------------------------------------
local function generateForecast()
    local weights = nil

    if Config.EnableSeasons and B2WE.getCurrentSeason and B2WE.getSeasonWeights then
        weights = B2WE.getSeasonWeights(B2WE.getCurrentSeason())
    end

    forecastQueue = {}
    for i = 1, Config.ForecastSteps do
        table.insert(forecastQueue, {
            weather     = B2WE.getRandomWeather(weights),
            estimatedIn = "~" .. (i * Config.WeatherChangeInterval) .. " min",
        })
    end

    B2WE.debugPrint("Forecast generated: " .. json.encode(forecastQueue))
end

-- -----------------------------------------------
-- B2WE.broadcastForecast()
-- Regenerates the forecast and broadcasts it to all
-- clients via b2we:updateForecast.
-- Called by sv_weather and sv_seasons after any change.
-- No-ops when Config.EnableForecast = false.
-- -----------------------------------------------
function B2WE.broadcastForecast()
    if not Config.EnableForecast then return end
    generateForecast()
    TriggerClientEvent(B2WE.Events.UPDATE_FORECAST, -1, forecastQueue)
end

-- -----------------------------------------------
-- B2WE.getForecast() → table
-- Returns a shallow copy of the current forecast queue.
-- -----------------------------------------------
function B2WE.getForecast()
    local copy = {}
    for i, entry in ipairs(forecastQueue) do
        copy[i] = { weather = entry.weather, estimatedIn = entry.estimatedIn }
    end
    return copy
end

-- -----------------------------------------------
-- Export-facing global (wired up in sv_exports.lua)
-- -----------------------------------------------
function GetForecast()
    return B2WE.getForecast()
end

-- -----------------------------------------------
-- Initial forecast generation
-- Called directly at parse time — sv_weather and sv_seasons
-- are parsed before sv_forecast (see fxmanifest), so
-- B2WE.getRandomWeather and B2WE.getSeasonWeights are already
-- defined.  No Wait(0) needed; avoiding the deferred thread
-- ensures forecastQueue is populated before any player can
-- send REQUEST_FULL_SYNC.
-- -----------------------------------------------
generateForecast()
