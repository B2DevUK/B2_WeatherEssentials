-- ===============================================
-- Module: server/sv_time.lua
-- Description: Server-side time state, real-world clock sync,
--              accelerated clock tick, and sync enable/disable.
-- Depends on: sh_constants, sh_utils, config
-- ===============================================

-- -----------------------------------------------
-- State (module-local)
-- -----------------------------------------------
local currentServerTime = { hours = 12, minutes = 0 }
local timeSyncEnabled   = true

-- Duration of one in-game minute in real milliseconds.
-- Formula: one full 24-hour day = Config.TimeScale real-world minutes
--          → 1440 in-game minutes per day
--          → timeSyncInterval ms per in-game minute
local timeSyncInterval = math.floor((Config.TimeScale * 60 * 1000) / 1440)

-- -----------------------------------------------
-- getRealWorldTime() → hour (0-23), minute (0-59)
-- os.date("*t") is used with an explicit format to avoid the no-argument
-- null-terminator bug present in FiveM's sandboxed Lua.
-- -----------------------------------------------
local function getRealWorldTime()
    local t = os.date("*t")
    return t.hour, t.min
end

-- -----------------------------------------------
-- B2WE.getCurrentTime() → {hours, minutes}
-- Returns a copy so callers cannot mutate internal state.
-- -----------------------------------------------
function B2WE.getCurrentTime()
    return { hours = currentServerTime.hours, minutes = currentServerTime.minutes }
end

-- -----------------------------------------------
-- B2WE.setTime(hours, minutes)
-- Overwrites the current server time and broadcasts immediately to all
-- clients regardless of timeSyncEnabled (explicit set is always pushed).
-- -----------------------------------------------
function B2WE.setTime(hours, minutes)
    currentServerTime.hours   = hours
    currentServerTime.minutes = minutes
    TriggerClientEvent(B2WE.Events.SET_TIME_OF_DAY, -1, hours, minutes)
    B2WE.debugPrint("Time set to " .. hours .. ":" .. string.format("%02d", minutes))
end

-- -----------------------------------------------
-- Export-facing globals (wired up in sv_exports.lua)
-- -----------------------------------------------
function EnableTimeSync()
    timeSyncEnabled = true
    TriggerClientEvent(B2WE.Events.SET_TIME_OF_DAY, -1, currentServerTime.hours, currentServerTime.minutes)
    B2WE.debugPrint("Time sync enabled")
end

function DisableTimeSync()
    timeSyncEnabled = false
    B2WE.debugPrint("Time sync disabled")
end

-- -----------------------------------------------
-- Net event: player requests current time state
-- (sent on join via cl_main.lua)
-- -----------------------------------------------
RegisterNetEvent(B2WE.Events.REQUEST_CURRENT_TIME)
AddEventHandler(B2WE.Events.REQUEST_CURRENT_TIME, function()
    local src = source
    TriggerClientEvent(B2WE.Events.SET_TIME_OF_DAY, src, currentServerTime.hours, currentServerTime.minutes)
end)

-- -----------------------------------------------
-- Time thread
-- Two mutually exclusive paths controlled by Config.UseRealTime:
--
--   UseRealTime = true  → mirror the server's real-world clock;
--                         re-reads and broadcasts every 60 s.
--   UseRealTime = false → advance one in-game minute every
--                         timeSyncInterval ms (accelerated clock).
-- -----------------------------------------------
Citizen.CreateThread(function()
    while true do
        if Config.UseRealTime then
            local h, m = getRealWorldTime()
            currentServerTime.hours   = h
            currentServerTime.minutes = m

            if timeSyncEnabled then
                TriggerClientEvent(B2WE.Events.SET_TIME_OF_DAY, -1, h, m)
            end

            Citizen.Wait(60000)
        else
            Citizen.Wait(timeSyncInterval)

            currentServerTime.minutes = currentServerTime.minutes + 1
            if currentServerTime.minutes >= 60 then
                currentServerTime.hours   = (currentServerTime.hours + 1) % 24
                currentServerTime.minutes = 0
            end

            if timeSyncEnabled then
                TriggerClientEvent(B2WE.Events.SET_TIME_OF_DAY, -1, currentServerTime.hours, currentServerTime.minutes)
            end
        end
    end
end)
