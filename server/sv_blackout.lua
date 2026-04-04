-- ===============================================
-- Module: server/sv_blackout.lua
-- Description: Blackout state, trigger/clear broadcasts.
-- Depends on: sh_constants, sh_utils, config
-- ===============================================

-- -----------------------------------------------
-- State (module-local)
-- -----------------------------------------------
local isBlackout = false

-- -----------------------------------------------
-- B2WE.triggerBlackout()
-- Sets blackout state to true and broadcasts to all clients.
-- -----------------------------------------------
function B2WE.triggerBlackout()
    isBlackout = true
    B2WE.debugPrint("Blackout triggered")
    TriggerClientEvent(B2WE.Events.TOGGLE_BLACKOUT, -1, true)
end

-- -----------------------------------------------
-- B2WE.clearBlackout()
-- Sets blackout state to false and broadcasts to all clients.
-- -----------------------------------------------
function B2WE.clearBlackout()
    isBlackout = false
    B2WE.debugPrint("Blackout cleared")
    TriggerClientEvent(B2WE.Events.TOGGLE_BLACKOUT, -1, false)
end

-- -----------------------------------------------
-- B2WE.isBlackoutActive() → boolean
-- Used by sv_main for full-state sync on player join.
-- -----------------------------------------------
function B2WE.isBlackoutActive()
    return isBlackout
end

-- -----------------------------------------------
-- Export-facing globals (wired up in sv_exports.lua)
-- -----------------------------------------------
function TriggerBlackout()
    B2WE.triggerBlackout()
end

function ClearBlackout()
    B2WE.clearBlackout()
end
