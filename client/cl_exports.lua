-- ===============================================
-- Module: client/cl_exports.lua
-- Description: Client-side exports.
--              Loaded last — all module state flags
--              (B2WE.weatherSyncEnabled, B2WE.timeSyncEnabled)
--              must be defined before this file runs.
-- Depends on: cl_weather (weatherSyncEnabled),
--             cl_time    (timeSyncEnabled)
-- ===============================================

-- -----------------------------------------------
-- EnableWeatherSync / DisableWeatherSync
-- Re-enables weather sync and immediately re-requests
-- the current server weather so the client snaps back
-- to the authoritative state without waiting for the
-- next 30-second sync tick.
-- -----------------------------------------------
exports("EnableWeatherSync", function()
    B2WE.weatherSyncEnabled = true
    TriggerServerEvent(B2WE.Events.REQUEST_CURRENT_WEATHER)
    B2WE.debugPrint("Client weather sync enabled")
end)

exports("DisableWeatherSync", function()
    B2WE.weatherSyncEnabled = false
    B2WE.debugPrint("Client weather sync disabled")
end)

-- -----------------------------------------------
-- EnableTimeSync / DisableTimeSync
-- -----------------------------------------------
exports("EnableTimeSync", function()
    B2WE.timeSyncEnabled = true
    TriggerServerEvent(B2WE.Events.REQUEST_CURRENT_TIME)
    B2WE.debugPrint("Client time sync enabled")
end)

exports("DisableTimeSync", function()
    B2WE.timeSyncEnabled = false
    B2WE.debugPrint("Client time sync disabled")
end)
