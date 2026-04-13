-- ===============================================
-- Module: server/sv_bridge.lua
-- Description: Compatibility bridge for popular weather/time systems.
--              Exposes export and event interfaces matching:
--                • cd_easytime  (also covers vSync + qb-weathersync
--                                via cd_easytime's own provide entries)
--                • qb-weathersync (direct exports + net events)
--                • vSync        (net events)
--              All calls delegate to B2WE internals — no duplicate state.
-- Depends on: sv_weather, sv_time, sv_blackout
-- ===============================================

-- ===============================================
-- cd_easytime exports
-- GetWeather()      → string
-- GetAllData()      → table  { weather, hours, minutes }
-- GetRealData()     → table  (same shape, alias)
-- SetWeather(type)  → void
-- SetTime(h, m)     → void
-- ===============================================

exports('GetWeather', function()
    return B2WE.getCurrentWeather()
end)

exports('GetAllData', function()
    local time = B2WE.getCurrentTime()
    return {
        weather = B2WE.getCurrentWeather(),
        hours   = time.hours,
        minutes = time.minutes,
    }
end)

exports('GetRealData', function()
    local time = B2WE.getCurrentTime()
    return {
        weather = B2WE.getCurrentWeather(),
        hours   = time.hours,
        minutes = time.minutes,
    }
end)

exports('SetTime', function(hours, minutes)
    hours   = tonumber(hours)
    minutes = tonumber(minutes) or 0
    if not hours or hours < 0 or hours > 23 then return false end
    if minutes < 0 or minutes > 59 then return false end
    B2WE.setTime(hours, minutes)
    return true
end)

-- ===============================================
-- qb-weathersync exports
-- setWeather(type)         → boolean
-- setTime(hour, minute)    → boolean
-- setBlackout(state?)      → boolean  (toggle if nil)
-- setTimeFreeze(state?)    → boolean  (no-op — B2WE has no freeze; returns state)
-- setDynamicWeather(state?) → boolean (maps to Enable/DisableWeatherSync)
-- nextWeatherStage()       → boolean
-- ===============================================

exports('setWeather', function(weatherType)
    if type(weatherType) ~= "string" then return false end
    weatherType = weatherType:upper()
    if not Config.WeatherTypes[weatherType] then return false end
    B2WE.changeWeather(weatherType)
    return true
end)

exports('setTime', function(hours, minutes)
    hours   = tonumber(hours)
    minutes = tonumber(minutes) or 0
    if not hours or hours < 0 or hours > 23 then return false end
    if minutes < 0 or minutes > 59 then return false end
    B2WE.setTime(hours, minutes)
    return true
end)

exports('setBlackout', function(state)
    local current = B2WE.isBlackoutActive()
    local enable  = (state == nil) and not current or state
    if enable then
        B2WE.triggerBlackout()
    else
        B2WE.clearBlackout()
    end
    return enable
end)

exports('setTimeFreeze', function(state)
    -- B2WE does not implement time freeze — return the requested state
    -- so callers that check the return value do not error.
    B2WE.debugPrint("Bridge: setTimeFreeze called (no-op)")
    return state ~= nil and state or false
end)

exports('setDynamicWeather', function(state)
    if state == nil then state = true end
    if state then
        EnableWeatherSync()
    else
        DisableWeatherSync()
    end
    return state
end)

exports('nextWeatherStage', function()
    local weights = nil
    if Config.EnableSeasons and B2WE.getSeasonWeights and B2WE.getCurrentSeason then
        weights = B2WE.getSeasonWeights(B2WE.getCurrentSeason())
    end
    local next = B2WE.getRandomWeather(weights)
    B2WE.changeWeather(next)
    return true
end)

-- ===============================================
-- qb-weathersync net events
-- ===============================================

RegisterNetEvent('qb-weathersync:server:setWeather')
AddEventHandler('qb-weathersync:server:setWeather', function(weatherType)
    if type(weatherType) ~= "string" then return end
    weatherType = weatherType:upper()
    if Config.WeatherTypes[weatherType] then
        B2WE.changeWeather(weatherType)
    end
end)

RegisterNetEvent('qb-weathersync:server:setTime')
AddEventHandler('qb-weathersync:server:setTime', function(hour, minute)
    hour   = tonumber(hour)
    minute = tonumber(minute) or 0
    if hour and hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 then
        B2WE.setTime(hour, minute)
    end
end)

RegisterNetEvent('qb-weathersync:server:toggleBlackout')
AddEventHandler('qb-weathersync:server:toggleBlackout', function(state)
    local enable = (state == nil) and not B2WE.isBlackoutActive() or state
    if enable then B2WE.triggerBlackout() else B2WE.clearBlackout() end
end)

RegisterNetEvent('qb-weathersync:server:toggleFreezeTime')
AddEventHandler('qb-weathersync:server:toggleFreezeTime', function()
    B2WE.debugPrint("Bridge: qb-weathersync toggleFreezeTime (no-op)")
end)

RegisterNetEvent('qb-weathersync:server:toggleDynamicWeather')
AddEventHandler('qb-weathersync:server:toggleDynamicWeather', function(state)
    if state then EnableWeatherSync() else DisableWeatherSync() end
end)

RegisterNetEvent('qb-weathersync:server:RequestStateSync')
AddEventHandler('qb-weathersync:server:RequestStateSync', function()
    local src  = source
    local time = B2WE.getCurrentTime()
    TriggerClientEvent(B2WE.Events.UPDATE_WEATHER, src, B2WE.getCurrentWeather(), 0)
    TriggerClientEvent(B2WE.Events.SET_TIME_OF_DAY, src, time.hours, time.minutes)
end)

-- ===============================================
-- vSync net events
-- ===============================================

RegisterNetEvent('vSync:setWeather')
AddEventHandler('vSync:setWeather', function(weatherType)
    if type(weatherType) ~= "string" then return end
    weatherType = weatherType:upper()
    if Config.WeatherTypes[weatherType] then
        B2WE.changeWeather(weatherType)
    end
end)

RegisterNetEvent('vSync:setTime')
AddEventHandler('vSync:setTime', function(hour, minute)
    hour   = tonumber(hour)
    minute = tonumber(minute) or 0
    if hour and hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 then
        B2WE.setTime(hour, minute)
    end
end)