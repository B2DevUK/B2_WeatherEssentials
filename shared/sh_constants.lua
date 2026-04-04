-- ===============================================
-- Module: shared/sh_constants.lua
-- Description: Shared constants — weather types, WMO code map, event names
-- Loaded before config.lua; no Config references here.
-- ===============================================

B2WE = B2WE or {}

-- -----------------------------------------------
-- Weather type names (ordered for deterministic iteration)
-- -----------------------------------------------
B2WE.WEATHER_TYPES = {
    "CLEAR", "EXTRASUNNY", "CLOUDS", "OVERCAST",
    "RAIN",  "CLEARING",   "THUNDER", "SMOG",
    "FOGGY", "XMAS",       "SNOWLIGHT", "BLIZZARD"
}

-- -----------------------------------------------
-- WMO weather-code → GTA weather-type
-- Source: Open-Meteo current_weather.weathercode
-- -----------------------------------------------
B2WE.WMO_MAP = {
    [0]  = "CLEAR",     -- Clear sky
    [1]  = "CLOUDS",    -- Mainly clear
    [2]  = "OVERCAST",  -- Partly cloudy
    [3]  = "OVERCAST",  -- Overcast
    [45] = "FOGGY",     -- Fog
    [48] = "FOGGY",     -- Depositing rime fog
    [51] = "RAIN",      -- Light drizzle
    [53] = "RAIN",      -- Moderate drizzle
    [55] = "RAIN",      -- Dense drizzle
    [56] = "RAIN",      -- Light freezing drizzle
    [57] = "RAIN",      -- Dense freezing drizzle
    [61] = "RAIN",      -- Slight rain
    [63] = "RAIN",      -- Moderate rain
    [65] = "RAIN",      -- Heavy rain
    [66] = "RAIN",      -- Light freezing rain
    [67] = "RAIN",      -- Heavy freezing rain
    [71] = "SNOWLIGHT", -- Slight snow fall
    [73] = "SNOWLIGHT", -- Moderate snow fall
    [75] = "BLIZZARD",  -- Heavy snow fall
    [77] = "SNOWLIGHT", -- Snow grains
    [80] = "RAIN",      -- Slight rain showers
    [81] = "RAIN",      -- Moderate rain showers
    [82] = "RAIN",      -- Violent rain showers
    [85] = "SNOWLIGHT", -- Slight snow showers
    [86] = "BLIZZARD",  -- Heavy snow showers
    [95] = "THUNDER",   -- Thunderstorm
    [96] = "THUNDER",   -- Thunderstorm with slight hail
    [99] = "THUNDER",   -- Thunderstorm with heavy hail
}

-- -----------------------------------------------
-- Network event names  (b2we: prefix throughout)
-- -----------------------------------------------
B2WE.Events = {
    -- Server → Client
    UPDATE_WEATHER          = "b2we:updateWeather",
    UPDATE_REGIONAL_WEATHER = "b2we:updateRegionalWeather",
    UPDATE_TIME             = "b2we:updateTime",
    SET_TIME_OF_DAY         = "b2we:setTimeOfDay",
    TOGGLE_BLACKOUT         = "b2we:toggleBlackout",
    START_BLACKOUT          = "b2we:startBlackout",
    TRIGGER_EARTHQUAKE      = "b2we:triggerEarthquake",
    TRIGGER_STORM           = "b2we:triggerStorm",
    TRIGGER_EXTREME_COLD    = "b2we:triggerExtremeCold",
    TRIGGER_EXTREME_HEAT    = "b2we:triggerExtremeHeat",
    TRIGGER_TSUNAMI         = "b2we:triggerTsunami",
    TRIGGER_HURRICANE = "b2we:triggerHurricane",
    TRIGGER_METEOR_SHOWER   = "b2we:triggerMeteorShower",
    SPAWN_METEOR = "b2we:spawnMeteor",
    CLEAR_EXTREME_EVENT     = "b2we:clearExtremeEvent",
    UPDATE_WATER_HEIGHT     = "b2we:updateWaterHeight",   -- Tsunami flood level sync
    START_VOTING            = "b2we:startVoting",
    UPDATE_VOTES            = "b2we:updateVotes",
    END_VOTING              = "b2we:endVoting",
    FULL_STATE_SYNC         = "b2we:fullStateSync",
    UPDATE_SEASON           = "b2we:updateSeason",
    UPDATE_FORECAST         = "b2we:updateForecast",

    -- Client → Server
    SUBMIT_WEATHER_VOTE     = "b2we:submitWeatherVote",
    REQUEST_CURRENT_WEATHER = "b2we:requestCurrentWeather",
    REQUEST_CURRENT_TIME    = "b2we:requestCurrentTime",
    ADMIN_ACTION            = "b2we:adminAction",
    REQUEST_FULL_SYNC       = "b2we:requestFullSync",
}

-- -----------------------------------------------
-- Extreme event names
-- -----------------------------------------------
B2WE.EXTREME_EVENTS = {
    "EARTHQUAKE", "STORM", "EXTREME_COLD", "EXTREME_HEAT",
    "TSUNAMI", "METEOR_SHOWER", "HURRICANE"
}

-- -----------------------------------------------
-- Season names
-- -----------------------------------------------
B2WE.SEASONS = { "SPRING", "SUMMER", "AUTUMN", "WINTER" }