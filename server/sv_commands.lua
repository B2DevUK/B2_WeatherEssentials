-- ===============================================
-- Module: server/sv_commands.lua
-- Description: Admin-only RegisterCommand wrappers.
--              All commands are gated behind ACE permissions.
-- Depends on: sh_constants, sh_utils, config,
--             sv_weather, sv_time, sv_blackout, sv_extreme, sv_voting
-- ===============================================

-- -----------------------------------------------
-- /setweather [type] [region?]
-- ACE: command.setweather
-- -----------------------------------------------
RegisterCommand("setweather", function(source, args, rawCommand)
    if not IsPlayerAceAllowed(source, "command.setweather") then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "You do not have permission to use this command!" }
        })
        return
    end

    if not args[1] then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "Usage: /setweather [type] [region?]" }
        })
        return
    end

    local newWeather = args[1]:upper()
    if not Config.WeatherTypes[newWeather] then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "Invalid weather type!" }
        })
        return
    end

    if Config.UseRegionalWeather and args[2] then
        local region = B2WE.capitalize(args[2])
        if not Config.Regions[region] then
            TriggerClientEvent("chat:addMessage", source, {
                args = { "^1SYSTEM", "Invalid region!" }
            })
            return
        end
        B2WE.changeWeather(newWeather, region)
    else
        B2WE.changeWeather(newWeather)
    end
end, false)

-- -----------------------------------------------
-- /settime [hours] [minutes?]
-- ACE: command.settime
-- -----------------------------------------------
RegisterCommand("settime", function(source, args, rawCommand)
    if not IsPlayerAceAllowed(source, "command.settime") then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "You do not have permission to use this command!" }
        })
        return
    end

    local hours   = tonumber(args[1])
    local minutes = tonumber(args[2]) or 0
    if not hours or hours < 0 or hours >= 24 or minutes < 0 or minutes >= 60 then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "Invalid time! Usage: /settime [hours] [minutes]" }
        })
        return
    end

    B2WE.setTime(hours, minutes)
end, false)

-- -----------------------------------------------
-- /blackout
-- ACE: command.setweather
-- -----------------------------------------------
RegisterCommand("blackout", function(source, args, rawCommand)
    if not IsPlayerAceAllowed(source, "command.setweather") then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "You do not have permission to use this command!" }
        })
        return
    end
    B2WE.triggerBlackout()
end, false)

-- -----------------------------------------------
-- /clearblackout
-- ACE: command.setweather
-- -----------------------------------------------
RegisterCommand("clearblackout", function(source, args, rawCommand)
    if not IsPlayerAceAllowed(source, "command.setweather") then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "You do not have permission to use this command!" }
        })
        return
    end
    B2WE.clearBlackout()
end, false)

-- -----------------------------------------------
-- /extremeevent [type]
-- ACE: command.setweather
-- -----------------------------------------------
RegisterCommand("extremeevent", function(source, args, rawCommand)
    if not IsPlayerAceAllowed(source, "command.setweather") then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "You do not have permission to use this command!" }
        })
        return
    end

    if not args[1] then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "Usage: /extremeevent [EARTHQUAKE|STORM|EXTREME_COLD|EXTREME_HEAT|TSUNAMI]" }
        })
        return
    end

    local event = args[1]:upper()
    if not Config.ExtremeEvents[event] then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "Invalid extreme event!" }
        })
        return
    end

    B2WE.triggerExtremeEvent(event)
end, false)

-- -----------------------------------------------
-- /clearextremeevent
-- ACE: command.setweather
-- -----------------------------------------------
RegisterCommand("clearextremeevent", function(source, args, rawCommand)
    if not IsPlayerAceAllowed(source, "command.setweather") then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "You do not have permission to use this command!" }
        })
        return
    end
    B2WE.clearExtremeEvent()
end, false)

-- -----------------------------------------------
-- Net event: b2we:adminAction
-- Receives admin panel actions from cl_nui.lua and
-- dispatches them after a server-side ACE check.
-- All paths are validated here; the client cannot
-- trigger any action that bypasses this handler.
-- -----------------------------------------------
RegisterNetEvent(B2WE.Events.ADMIN_ACTION)
AddEventHandler(B2WE.Events.ADMIN_ACTION, function(data)
    local src = source
    if not IsPlayerAceAllowed(src, "command.setweather") then return end
    if type(data) ~= "table" then return end

    local action = data.action

    if action == "setWeather" then
        if Config.WeatherTypes[data.weather] then
            B2WE.changeWeather(data.weather, data.region or nil)
        end

    elseif action == "setTime" then
        local h = tonumber(data.hours)
        local m = tonumber(data.minutes) or 0
        if h and h >= 0 and h < 24 and m >= 0 and m < 60 then
            B2WE.setTime(h, m)
        end

    elseif action == "blackout" then
        B2WE.triggerBlackout()

    elseif action == "clearBlackout" then
        B2WE.clearBlackout()

    elseif action == "triggerEvent" then
        if Config.ExtremeEvents[data.event] then
            B2WE.triggerExtremeEvent(data.event)
        end

    elseif action == "clearEvent" then
        B2WE.clearExtremeEvent()

    elseif action == "forceVote" then
        if Config.EnableVotingSystem then
            Citizen.CreateThread(function() B2WE.startVoting() end)
        end

    elseif action == "setSeason" then
        B2WE.setCurrentSeason(data.season)

    elseif action == "enableWeatherSync" then
        EnableWeatherSync()

    elseif action == "disableWeatherSync" then
        DisableWeatherSync()

    elseif action == "enableTimeSync" then
        EnableTimeSync()

    elseif action == "disableTimeSync" then
        DisableTimeSync()
    end
end)

-- -----------------------------------------------
-- /forcevote
-- ACE: command.setweather
-- Detaches to a new thread so the command handler returns immediately
-- (avoids the legacy bug of blocking the server thread for the full
-- VotingDuration via Citizen.Wait inside a RegisterCommand callback).
-- -----------------------------------------------
RegisterCommand("forcevote", function(source, args, rawCommand)
    if not IsPlayerAceAllowed(source, "command.setweather") then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "You do not have permission to use this command!" }
        })
        return
    end

    if not Config.EnableVotingSystem then
        TriggerClientEvent("chat:addMessage", source, {
            args = { "^1SYSTEM", "Voting system is disabled!" }
        })
        return
    end

    Citizen.CreateThread(function()
        B2WE.startVoting()
    end)
end, false)
