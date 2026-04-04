-- ===============================================
-- Module: client/cl_time.lua
-- Description: Time event handler — applies server-driven
--              in-game time via NetworkOverrideClockTime
--              and notifies the NUI.
-- Depends on: sh_constants, sh_utils, config
-- ===============================================

B2WE.timeSyncEnabled = true

-- -----------------------------------------------
-- Event: SET_TIME_OF_DAY
-- Fired by the server on every clock tick and on
-- explicit setTime calls.  Applies the authoritative
-- hour/minute to the local game clock and pushes the
-- value to the NUI for the panel display.
-- -----------------------------------------------
AddEventHandler(B2WE.Events.SET_TIME_OF_DAY, function(hours, minutes)
    if not B2WE.timeSyncEnabled then return end

    NetworkOverrideClockTime(hours, minutes, 0)
    B2WE.debugPrint("Time applied: " .. hours .. ":" .. string.format("%02d", minutes))

    SendNUIMessage({ action = "updateTime", hours = hours, minutes = minutes })
end)
