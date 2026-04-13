-- ===============================================
-- Module: server/sv_main.lua
-- Description: Resource bootstrap — startup banner, version check,
--              optional tsunami-on-restart trigger, and full-state sync
--              to joining players.
-- NOTE: Loaded FIRST in server_scripts. All B2WE.* references inside
--       threads/handlers are safe because they execute only after all
--       remaining server modules have been parsed (post Wait(0), or on
--       events that fire well after resource start completes).
-- Depends on: sh_constants, sh_utils, config (shared),
--             all other server modules (resolved at runtime)
-- ===============================================

local RESOURCE_VERSION = "2.1.0"
local GITHUB_API_URL   = "https://api.github.com/repos/B2DevUK/B2_WeatherEssentials/releases/latest"

-- -----------------------------------------------
-- Startup banner
-- -----------------------------------------------
print("^2[b2_weatherEssentials] v" .. RESOURCE_VERSION .. " loading...^0")

-- -----------------------------------------------
-- Version check (async — does not block startup)
-- -----------------------------------------------
Citizen.CreateThread(function()
    Citizen.Wait(0)

    PerformHttpRequest(GITHUB_API_URL, function(statusCode, response)
        if statusCode == 200 then
            local data = json.decode(response)
            if data and data.tag_name then
                local latest = data.tag_name
                if latest ~= RESOURCE_VERSION then
                    print("^3[b2_weatherEssentials] Update available! "
                          .. "Current: v" .. RESOURCE_VERSION
                          .. " → Latest: " .. latest .. "^0")
                    print("^3[b2_weatherEssentials] https://github.com/B2DevUK/B2_WeatherEssentials^0")
                else
                    print("^2[b2_weatherEssentials] v" .. RESOURCE_VERSION .. " is up to date.^0")
                end
            else
                B2WE.debugPrint("Version check: malformed API response")
            end
        else
            B2WE.debugPrint("Version check: HTTP " .. tostring(statusCode))
        end
    end, "GET")
end)

-- -----------------------------------------------
-- Tsunami on resource stop
-- When Config.Tsunami.TriggerOnResourceStop = true, triggering a
-- resource restart (e.g. `restart b2_weatherEssentials`) will fire
-- the tsunami event as a dramatic restart warning to all connected
-- players before the resource unloads.
--
-- ⚠  This is reliable for resource restarts.  For full server
--    process shutdowns the OS may kill the process before client
--    events are delivered — use a scheduled restart command instead.
-- -----------------------------------------------
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if Config.Tsunami and Config.Tsunami.TriggerOnResourceStop then
        B2WE.debugPrint("TriggerOnResourceStop: triggering TSUNAMI on resource stop")
        B2WE.triggerExtremeEvent("TSUNAMI")
    end
end)

-- -----------------------------------------------
-- REQUEST_FULL_SYNC — full state sync (pull model)
-- Triggered by the client once it is fully ready to receive events.
-- Using a client-initiated request avoids the net-ID mismatch that
-- occurs when TriggerClientEvent is called during playerJoining.
--
-- Payload fields sent back:
--   weather      string|nil   Global weather (nil when UseRegionalWeather)
--   regionMap    table|nil    {[region]=weather} (nil when not regional)
--   season       string|nil   Current season (nil when EnableSeasons=false)
--   hours        number       Current in-game hour (0–23)
--   minutes      number       Current in-game minute (0–59)
--   forecast     table|nil    [{weather,estimatedIn},...] (nil when disabled)
--   activeEvent  string|nil   Active extreme event name, or nil
--   votingActive boolean      Whether a vote is currently in progress
--   voteCounts   table        {[weather]=count,...} (empty when not active)
-- -----------------------------------------------
RegisterNetEvent(B2WE.Events.REQUEST_FULL_SYNC)
AddEventHandler(B2WE.Events.REQUEST_FULL_SYNC, function()
    local src = source

    -- Weather
    local weather   = nil
    local regionMap = nil
    if Config.UseRegionalWeather then
        regionMap = B2WE.getRegionWeather()
    else
        weather = B2WE.getCurrentWeather()
    end

    -- Time
    local time = B2WE.getCurrentTime()

    -- Season
    local season = nil
    if Config.EnableSeasons then
        season = B2WE.getCurrentSeason()
    end

    -- Forecast
    local forecast = nil
    if Config.EnableForecast then
        forecast = B2WE.getForecast()
    end

    -- Extreme event and voting
    local activeEvent  = B2WE.getCurrentExtremeEvent()
    local votingActive = B2WE.isVotingActive()
    local voteCounts   = votingActive and B2WE.getVoteCounts() or {}

    B2WE.debugPrint("fullStateSync → player " .. tostring(src))

    TriggerClientEvent(B2WE.Events.FULL_STATE_SYNC, src, {
        weather      = weather,
        regionMap    = regionMap,
        season       = season,
        hours        = time.hours,
        minutes      = time.minutes,
        forecast     = forecast,
        activeEvent  = activeEvent,
        votingActive = votingActive,
        voteCounts   = voteCounts,
    })
end)