-- ===============================================
-- Module: server/sv_seasons.lua
-- Description: Season detection (real / cycle / manual), per-season
--              weight computation, and season-change broadcasts.
-- Depends on: sh_constants, sh_utils, config
-- ===============================================

-- -----------------------------------------------
-- State (module-local)
-- -----------------------------------------------
local currentSeason = "SPRING"

-- -----------------------------------------------
-- monthToSeason(month) → season string
-- -----------------------------------------------
local function monthToSeason(month)
    if month >= 3 and month <= 5  then return "SPRING" end
    if month >= 6 and month <= 8  then return "SUMMER" end
    if month >= 9 and month <= 11 then return "AUTUMN" end
    return "WINTER"
end

-- -----------------------------------------------
-- detectRealSeason() → season string
-- Uses os.date("*t") — explicit format avoids the
-- no-argument null-terminator bug in FiveM Lua.
-- -----------------------------------------------
local function detectRealSeason()
    local t = os.date("*t")
    return monthToSeason(t.month)
end

-- Seed currentSeason at load time for "real" mode.
-- Cycle and manual start at "SPRING" (no persistence).
if Config.EnableSeasons and Config.SeasonMode == "real" then
    currentSeason = detectRealSeason()
end

-- -----------------------------------------------
-- B2WE.getCurrentSeason() → string
-- -----------------------------------------------
function B2WE.getCurrentSeason()
    return currentSeason
end

-- -----------------------------------------------
-- B2WE.setCurrentSeason(season)
-- Changes the active season, broadcasts to clients,
-- and regenerates the forecast queue.
-- -----------------------------------------------
function B2WE.setCurrentSeason(season)
    if not table.contains(B2WE.SEASONS, season) then
        B2WE.debugPrint("setCurrentSeason: invalid season '" .. tostring(season) .. "'")
        return
    end
    currentSeason = season
    TriggerClientEvent(B2WE.Events.UPDATE_SEASON, -1, season)
    B2WE.debugPrint("Season changed to " .. season)
    if B2WE.broadcastForecast then
        B2WE.broadcastForecast()
    end
end

-- -----------------------------------------------
-- B2WE.getSeasonWeights(season) → table
-- Returns combined weights: Config.WeatherChances[type]
-- multiplied by Config.SeasonWeights[season][type],
-- then normalised so they sum to 100.
-- Passed directly into B2WE.getRandomWeather(weights).
-- -----------------------------------------------
function B2WE.getSeasonWeights(season)
    local multipliers = (Config.SeasonWeights and Config.SeasonWeights[season]) or {}
    local combined = {}
    local total    = 0

    for weatherType, baseWeight in pairs(Config.WeatherChances) do
        local mult = multipliers[weatherType]
        if mult == nil then mult = 1.0 end
        local w = baseWeight * mult
        combined[weatherType] = w
        total = total + w
    end

    if total > 0 then
        for weatherType in pairs(combined) do
            combined[weatherType] = (combined[weatherType] / total) * 100
        end
    end

    return combined
end

-- -----------------------------------------------
-- Export-facing globals (wired up in sv_exports.lua)
-- -----------------------------------------------
function GetCurrentSeason()
    return B2WE.getCurrentSeason()
end

function SetCurrentSeason(season)
    B2WE.setCurrentSeason(season)
end

-- -----------------------------------------------
-- Season detection thread
-- "real"   — re-checks real-world month every 5 min.
-- "cycle"  — advances one season every SeasonCycleDays
--            in-game days (Config.TimeScale min/day).
-- "manual" — idles; only B2WE.setCurrentSeason moves it.
-- -----------------------------------------------
Citizen.CreateThread(function()
    while true do
        if not Config.EnableSeasons or Config.SeasonMode == "manual" then
            Citizen.Wait(60000)
        elseif Config.SeasonMode == "real" then
            Citizen.Wait(300000) -- re-check every 5 real minutes
            local newSeason = detectRealSeason()
            if newSeason ~= currentSeason then
                B2WE.setCurrentSeason(newSeason)
            end
        elseif Config.SeasonMode == "cycle" then
            -- One in-game day = Config.TimeScale real-world minutes
            local msPerDay = (Config.TimeScale or 60) * 60 * 1000
            local cycleMs  = (Config.SeasonCycleDays or 7) * msPerDay
            Citizen.Wait(cycleMs)

            -- Advance to the next season in the SEASONS array
            local nextIdx = 1
            for i, s in ipairs(B2WE.SEASONS) do
                if s == currentSeason then
                    nextIdx = (i % #B2WE.SEASONS) + 1
                    break
                end
            end
            B2WE.setCurrentSeason(B2WE.SEASONS[nextIdx])
        else
            Citizen.Wait(60000)
        end
    end
end)
