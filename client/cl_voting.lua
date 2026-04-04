-- ===============================================
-- Module: client/cl_voting.lua
-- Description: Voting NUI bridge and /weathervote command.
--              Listens for server voting events, mirrors
--              state to the NUI, and forwards player votes
--              to the server.
-- Depends on: sh_constants, sh_utils, config
-- ===============================================

-- -----------------------------------------------
-- State (module-local)
-- -----------------------------------------------
local votingActive = false
local voteOptions  = {}

-- -----------------------------------------------
-- Event: START_VOTING
-- Fired by the server when a new vote begins.
-- Stores options, marks voting active, and updates
-- the NUI.  Optionally auto-opens the player panel
-- when Config.UI.AutoShowVotingPanel = true.
-- -----------------------------------------------
AddEventHandler(B2WE.Events.START_VOTING, function(duration, options)
    votingActive = true
    voteOptions  = options or {}
    B2WE.debugPrint("Voting started, duration=" .. tostring(duration))

    SendNUIMessage({
        action   = "startVoting",
        duration = duration,
        options  = voteOptions,
    })

    if Config.UI and Config.UI.AutoShowVotingPanel then
        SendNUIMessage({ action = "showPanel", panel = "player" })
    end
end)

-- -----------------------------------------------
-- Event: UPDATE_VOTES
-- Fired after every successful vote submission so
-- all clients see live counts.
-- -----------------------------------------------
AddEventHandler(B2WE.Events.UPDATE_VOTES, function(votes)
    SendNUIMessage({ action = "updateVotes", votes = votes })
end)

-- -----------------------------------------------
-- Event: END_VOTING
-- Clears local state and removes the voting panel.
-- -----------------------------------------------
AddEventHandler(B2WE.Events.END_VOTING, function()
    votingActive = false
    voteOptions  = {}
    B2WE.debugPrint("Voting ended")
    SendNUIMessage({ action = "endVoting" })
end)

-- -----------------------------------------------
-- /weathervote [type]
-- Submits the player's vote to the server.
-- The server validates the type, blacklist, and
-- duplicate-vote rules — the client just forwards.
-- -----------------------------------------------
RegisterCommand("weathervote", function(source, args)
    if not args[1] then
        TriggerEvent("chat:addMessage", {
            args = { "^3[Weather]", "Usage: /weathervote [type]" }
        })
        return
    end
    TriggerServerEvent(B2WE.Events.SUBMIT_WEATHER_VOTE, args[1]:upper())
end, false)
