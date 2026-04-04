-- ===============================================
-- Module: client/cl_blackout.lua
-- Description: Blackout state, artificial light toggle,
--              sound trigger, and flicker thread.
-- Depends on: sh_constants, sh_utils, config
-- ===============================================

-- -----------------------------------------------
-- State (module-local)
-- -----------------------------------------------
local isBlackout     = false
local flickerEndTime = 0   -- game-timer ms after which flicker settles

-- -----------------------------------------------
-- B2WE.isBlackoutActive() → boolean
-- Exposed for cl_main to restore state on FULL_STATE_SYNC.
-- -----------------------------------------------
function B2WE.isBlackoutActive()
    return isBlackout
end

-- -----------------------------------------------
-- Flicker thread
-- Single persistent thread — no new threads per event.
-- While isBlackout = true and within the flicker window:
--   rapidly toggles SetArtificialLightsState to simulate
--   an electrical flicker before settling to "lights off".
-- While isBlackout = false:
--   ensures lights are restored (state = false = normal).
-- -----------------------------------------------
Citizen.CreateThread(function()
    while true do
        if not isBlackout then
            -- Ensure lights are on (normal state = false = not forced off)
            SetArtificialLightsState(false)
            Citizen.Wait(500)
        else
            local now = GetGameTimer()
            if now < flickerEndTime then
                -- Flicker phase: random on/off every 100–400 ms
                SetArtificialLightsState(math.random(2) == 1)
                Citizen.Wait(100 + math.random(300))
            else
                -- Settled: all artificial lights off
                SetArtificialLightsState(true)
                Citizen.Wait(500)
            end
        end
    end
end)

-- -----------------------------------------------
-- Event: TOGGLE_BLACKOUT
-- enabled = true  → begin blackout (flicker → dark)
-- enabled = false → end blackout (restore lights)
-- -----------------------------------------------
AddEventHandler(B2WE.Events.TOGGLE_BLACKOUT, function(enabled)
    isBlackout = enabled
    B2WE.debugPrint("Blackout: " .. tostring(enabled))

    if enabled then
        -- 3-second flicker window before lights settle off
        flickerEndTime = GetGameTimer() + 3000
        SendNUIMessage({ action = "playSound", sound = "blackout.wav" })
    else
        -- Immediately restore lights; flicker thread will keep them off
        SetArtificialLightsState(false)
    end
end)