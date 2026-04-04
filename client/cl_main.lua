-- ===============================================
-- Module: client/cl_main.lua
-- Description: Bootstrap — handles the full-state sync
--              payload sent by the server on player join
--              and dispatches each field to the appropriate
--              client module via local event triggers.
-- NOTE: Loaded after all other client modules so that
--       B2WE.applyExtremeEvent (cl_extreme) and the
--       voting/NUI handlers (cl_voting, cl_nui) are
--       all registered before this runs.
-- Depends on: all other client modules
-- ===============================================

-- -----------------------------------------------
-- Register all server→client events as network-safe.
-- Without these, FiveM will log "was not safe for net"
-- warnings and silently drop the events.
-- -----------------------------------------------
RegisterNetEvent(B2WE.Events.UPDATE_WEATHER)
RegisterNetEvent(B2WE.Events.UPDATE_REGIONAL_WEATHER)
RegisterNetEvent(B2WE.Events.UPDATE_TIME)
RegisterNetEvent(B2WE.Events.SET_TIME_OF_DAY)
RegisterNetEvent(B2WE.Events.TOGGLE_BLACKOUT)
RegisterNetEvent(B2WE.Events.START_BLACKOUT)
RegisterNetEvent(B2WE.Events.TRIGGER_EARTHQUAKE)
RegisterNetEvent(B2WE.Events.TRIGGER_STORM)
RegisterNetEvent(B2WE.Events.TRIGGER_EXTREME_COLD)
RegisterNetEvent(B2WE.Events.TRIGGER_EXTREME_HEAT)
RegisterNetEvent(B2WE.Events.TRIGGER_TSUNAMI)
RegisterNetEvent(B2WE.Events.TRIGGER_METEOR_SHOWER)
RegisterNetEvent(B2WE.Events.CLEAR_EXTREME_EVENT)
RegisterNetEvent(B2WE.Events.UPDATE_WATER_HEIGHT)  -- Tsunami flood level sync
RegisterNetEvent(B2WE.Events.SPAWN_METEOR)         -- Meteor shower per-rock spawn
RegisterNetEvent(B2WE.Events.START_VOTING)
RegisterNetEvent(B2WE.Events.UPDATE_VOTES)
RegisterNetEvent(B2WE.Events.END_VOTING)
RegisterNetEvent(B2WE.Events.FULL_STATE_SYNC)
RegisterNetEvent(B2WE.Events.UPDATE_SEASON)
RegisterNetEvent(B2WE.Events.UPDATE_FORECAST)

-- -----------------------------------------------
-- Event: FULL_STATE_SYNC
-- Sent by sv_main when a player joins.  Single event
-- carrying everything needed to initialise the client
-- without individual request round-trips.
--
-- Payload fields (all optional / may be nil):
--   weather      string       Global weather type
--   regionMap    table        {[region]=weather}
--   season       string       Current season
--   hours        number       In-game hour  (0–23)
--   minutes      number       In-game minute (0–59)
--   forecast     table        [{weather, estimatedIn}, ...]
--   activeEvent  string|nil   Active extreme event name
--   votingActive boolean
--   voteCounts   table        {[weather]=count, ...}
-- -----------------------------------------------
AddEventHandler(B2WE.Events.FULL_STATE_SYNC, function(state)
    B2WE.debugPrint("Received fullStateSync")

    -- ---- Weather ----
    if state.regionMap then
        TriggerEvent(B2WE.Events.UPDATE_REGIONAL_WEATHER, state.regionMap, 0)
    elseif state.weather then
        TriggerEvent(B2WE.Events.UPDATE_WEATHER, state.weather, 0)
    end

    -- ---- Time ----
    if state.hours then
        TriggerEvent(B2WE.Events.SET_TIME_OF_DAY, state.hours, state.minutes or 0)
    end

    -- ---- Season ----
    if state.season then
        B2WE.currentSeason = state.season
        SendNUIMessage({ action = "updateSeason", season = state.season })
    end

    -- ---- Forecast ----
    if state.forecast then
        B2WE.debugPrint("Forecast entries received: " .. tostring(#state.forecast))
        SendNUIMessage({ action = "updateForecast", forecast = state.forecast })
    else
        B2WE.debugPrint("Forecast: nil (not included in sync payload)")
    end

    -- ---- Extreme event ----
    if state.activeEvent then
        B2WE.applyExtremeEvent(state.activeEvent)
    end

    -- ---- Voting ----
    if state.votingActive and state.voteCounts then
        SendNUIMessage({ action = "updateVotes", votes = state.voteCounts })
    end

    -- ---- Full NUI sync (single consolidated message) ----
    local nuiWeather = state.weather
    if not nuiWeather and state.regionMap then
        nuiWeather = state.regionMap["City"]
        if not nuiWeather then
            local _, v = next(state.regionMap)
            nuiWeather = v
        end
    end
    nuiWeather = nuiWeather or "CLEAR"

    SendNUIMessage({
        action       = "fullSync",
        weather      = nuiWeather,
        region       = B2WE.currentRegion or "Global",
        season       = state.season       or "SPRING",
        hours        = state.hours        or 12,
        minutes      = state.minutes      or 0,
        forecast     = state.forecast,
        activeEvent  = state.activeEvent,
        votingActive = state.votingActive or false,
    })
end)

-- -----------------------------------------------
-- Request full state from server once the resource
-- is loaded and the client is ready to receive events.
-- -----------------------------------------------
AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    TriggerServerEvent(B2WE.Events.REQUEST_FULL_SYNC)
end)