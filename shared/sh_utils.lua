-- ===============================================
-- Module: shared/sh_utils.lua
-- Description: Shared utility functions
-- Loaded after sh_constants.lua, before config.lua.
-- Config is referenced only inside function bodies
-- (resolved at call time, after config.lua has run).
-- ===============================================

B2WE = B2WE or {}

-- -----------------------------------------------
-- table.contains(tbl, element) -> boolean
-- Linear scan; works on both array and hash tables.
-- Fixes the original bug where Config.WeatherBlacklist
-- (an array) was accessed with a key lookup instead.
-- -----------------------------------------------
function table.contains(tbl, element)
    for _, value in pairs(tbl) do
        if value == element then
            return true
        end
    end
    return false
end

-- -----------------------------------------------
-- debugPrint(message)
-- Respects Config.Debugging; prefixes by context.
-- -----------------------------------------------
local _debugContext = IsDuplicityVersion() and "[SERVER DEBUG]" or "[CLIENT DEBUG]"

function B2WE.debugPrint(message)
    if Config and Config.Debugging then
        print(_debugContext .. ": " .. tostring(message))
    end
end

-- -----------------------------------------------
-- capitalize(str) -> string
-- "city" → "City"  (first letter uppercased only)
-- -----------------------------------------------
function B2WE.capitalize(str)
    return (str:gsub("^%l", string.upper))
end
