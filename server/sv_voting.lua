-- ===============================================
-- Module: server/sv_voting.lua
-- Description: Voting thread, vote submission handler,
--              season-aware blacklist filtering, and results dispatch.
-- Depends on: sh_constants, sh_utils, config, sv_weather, sv_seasons
-- ===============================================

-- -----------------------------------------------
-- State (module-local)
-- -----------------------------------------------
local votingActive = false
local voteCounts   = {}
local votedPlayers = {}

-- -----------------------------------------------
-- getActiveBlacklist() → table (array of strings)
-- Returns the season-specific blacklist when EnableSeasons is active;
-- falls back to the global Config.WeatherBlacklist otherwise.
-- -----------------------------------------------
local function getActiveBlacklist()
    if Config.EnableSeasons and B2WE.getCurrentSeason and Config.SeasonVotingBlacklist then
        local season = B2WE.getCurrentSeason()
        return Config.SeasonVotingBlacklist[season] or Config.WeatherBlacklist
    end
    return Config.WeatherBlacklist
end

-- -----------------------------------------------
-- buildVoteOptions() → table (array of weather strings)
-- Iterates B2WE.WEATHER_TYPES in deterministic order, skipping any
-- type that is absent from Config.WeatherTypes or on the active blacklist.
-- -----------------------------------------------
local function buildVoteOptions()
    local blacklist = getActiveBlacklist()
    local options   = {}
    for _, weather in ipairs(B2WE.WEATHER_TYPES) do
        if Config.WeatherTypes[weather] and not table.contains(blacklist, weather) then
            table.insert(options, weather)
        end
    end
    return options
end

-- -----------------------------------------------
-- B2WE.handleVotingResults()
-- Tallies votes, picks winner (random tiebreak), applies weather,
-- resets state, and broadcasts END_VOTING to all clients.
-- -----------------------------------------------
function B2WE.handleVotingResults()
    local maxVotes = 0
    local winners  = {}

    for weather, count in pairs(voteCounts) do
        if count > maxVotes then
            maxVotes = count
            winners  = { weather }
        elseif count == maxVotes then
            table.insert(winners, weather)
        end
    end

    local selected
    if #winners > 0 then
        selected = winners[math.random(#winners)]
    else
        selected = B2WE.getRandomWeather(nil)
    end

    voteCounts   = {}
    votedPlayers = {}
    votingActive = false

    B2WE.debugPrint("Voting ended, winner: " .. selected)
    B2WE.changeWeather(selected, nil, 30.0)
    TriggerClientEvent(B2WE.Events.END_VOTING, -1)
    TriggerClientEvent("chat:addMessage", -1, {
        args = { "^2[Weather]", "Voting has ended. New weather: " .. selected }
    })
end

-- -----------------------------------------------
-- B2WE.startVoting()
-- Resets state, broadcasts START_VOTING with filtered options,
-- then spawns a detached thread to call handleVotingResults after
-- VotingDuration minutes (avoids blocking the calling thread).
-- No-ops when Config.EnableVotingSystem = false or a vote is already active.
-- -----------------------------------------------
function B2WE.startVoting()
    if not Config.EnableVotingSystem then return end
    if votingActive then
        B2WE.debugPrint("startVoting: vote already in progress, skipping")
        return
    end

    votingActive = true
    voteCounts   = {}
    votedPlayers = {}

    local options = buildVoteOptions()
    B2WE.debugPrint("Voting started, options: " .. json.encode(options))
    TriggerClientEvent(B2WE.Events.START_VOTING, -1, Config.VotingDuration, options)

    Citizen.CreateThread(function()
        Citizen.Wait(Config.VotingDuration * 60000)
        if votingActive then
            B2WE.handleVotingResults()
        end
    end)
end

-- -----------------------------------------------
-- B2WE.isVotingActive() → boolean
-- Used by sv_main for full-state sync on player join.
-- -----------------------------------------------
function B2WE.isVotingActive()
    return votingActive
end

-- -----------------------------------------------
-- B2WE.getVoteCounts() → table
-- Returns a shallow copy of the current vote tally.
-- -----------------------------------------------
function B2WE.getVoteCounts()
    local copy = {}
    for k, v in pairs(voteCounts) do
        copy[k] = v
    end
    return copy
end

-- -----------------------------------------------
-- Net event: player submits a weather vote
-- Validates: voting active, not already voted, valid weather type,
-- not blacklisted. Broadcasts updated counts on success.
-- -----------------------------------------------
RegisterNetEvent(B2WE.Events.SUBMIT_WEATHER_VOTE)
AddEventHandler(B2WE.Events.SUBMIT_WEATHER_VOTE, function(weatherType)
    local src = source

    if not votingActive then
        TriggerClientEvent("chat:addMessage", src, {
            args = { "^1[Weather]", "Voting is not currently active!" }
        })
        return
    end

    if votedPlayers[src] then
        TriggerClientEvent("chat:addMessage", src, {
            args = { "^1[Weather]", "You have already voted in this session!" }
        })
        return
    end

    if not Config.WeatherTypes[weatherType] then
        TriggerClientEvent("chat:addMessage", src, {
            args = { "^1[Weather]", "Invalid weather type!" }
        })
        return
    end

    if table.contains(getActiveBlacklist(), weatherType) then
        TriggerClientEvent("chat:addMessage", src, {
            args = { "^1[Weather]", weatherType .. " is not available for voting!" }
        })
        return
    end

    voteCounts[weatherType] = (voteCounts[weatherType] or 0) + 1
    votedPlayers[src]       = true
    TriggerClientEvent(B2WE.Events.UPDATE_VOTES, -1, voteCounts)
    TriggerClientEvent("chat:addMessage", src, {
        args = { "^2[Weather]", "Your vote for " .. weatherType .. " has been counted!" }
    })
    B2WE.debugPrint("Vote from " .. src .. " for " .. weatherType .. ". Total: " .. voteCounts[weatherType])
end)

-- -----------------------------------------------
-- Export-facing global (wired up in sv_exports.lua)
-- -----------------------------------------------
function ForceVote()
    B2WE.startVoting()
end

-- -----------------------------------------------
-- Voting interval thread
-- Waits VotingInterval minutes, then starts a vote (if none active).
-- -----------------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.VotingInterval * 60000)
        if Config.EnableVotingSystem and not votingActive then
            B2WE.startVoting()
        end
    end
end)
