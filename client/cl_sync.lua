-- ===============================================
-- Module: client/cl_sync.lua
-- Description: Periodic weather + time re-sync thread.
--              Re-requests authoritative state from the
--              server every 30 seconds to recover from
--              any client-side drift or missed events.
-- Depends on: sh_constants, sh_utils, config
-- ===============================================

-- -----------------------------------------------
-- Sync verification thread
-- Waits 15 s after resource start (to allow the
-- initial FULL_STATE_SYNC to arrive and apply),
-- then re-requests weather and time every 30 s.
-- Only fires requests when the respective sync
-- flags are enabled.
-- -----------------------------------------------
Citizen.CreateThread(function()
    -- Give the initial join sync time to settle
    Citizen.Wait(15000)

    while true do
        Citizen.Wait(30000)

        if B2WE.weatherSyncEnabled then
            B2WE.debugPrint("Sync: re-requesting weather")
            TriggerServerEvent(B2WE.Events.REQUEST_CURRENT_WEATHER)
        end

        if B2WE.timeSyncEnabled then
            B2WE.debugPrint("Sync: re-requesting time")
            TriggerServerEvent(B2WE.Events.REQUEST_CURRENT_TIME)
        end
    end
end)
