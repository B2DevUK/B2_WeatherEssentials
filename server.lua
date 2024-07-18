-- ===============================================
-- Module: server.lua
-- Author: B2DevUK | Discord: b2dev
-- Date: 15/07/24
-- Description: Server-side script for b2_weatherEssentials
-- ===============================================

-- ===============================================
-- Variables
-- ===============================================

local currentWeather = "CLEAR"
local regionWeather = {City = "CLEAR", Sandy = "CLEAR", Paleto = "CLEAR"}

local isBlackout = false

local votingActive = false
local voteCounts = {}
local votingTimer = Config.VotingDuration * 60 * 1000
local votedPlayers = {}

local currentServerTime = {hours = 12, minutes = 0}

local weatherSyncEnabled = true
local timeSyncEnabled = true
local timeSyncInterval = (Config.TimeScale * 60 * 1000) / 1440

-- ===============================================
-- Sync Functions
-- ===============================================

AddEventHandler('playerJoining', function()
    local source = source
    local weather = Config.UseRegionalWeather and regionWeather or currentWeather
    TriggerClientEvent('syncWeatherAndTime', source, weather, currentServerTime.hours, currentServerTime.minutes)
end)

-- ===============================================
-- Helper Functions
-- ===============================================

local function debugPrint(message)
    if Config.Debugging then
        print("[SERVER DEBUG]: " .. message)
    end
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

local function getRealWorldTime()
    local realTime = os.date('*t')
    return realTime.hour, realTime.min
end

-- ===============================================
-- Main Functions
-- ===============================================

-- Weather Update Functions
-- ===============================================

-- Weather update function
local function changeWeather(weather, region, transitionTime)
    transitionTime = transitionTime or 10.0

    if region then
        regionWeather[region] = weather
        debugPrint("Changing weather for region " .. region .. " to " .. weather)
    else
        currentWeather = weather
        debugPrint("Changing global weather to " .. currentWeather)
    end

    if Config.UseRegionalWeather then
        TriggerClientEvent('updateRegionalWeather', -1, regionWeather, transitionTime)
    else
        TriggerClientEvent('updateWeather', -1, currentWeather, transitionTime)
    end
end

-- Randomly select weather based on chances
local function getRandomWeather()
    local random = math.random(1, 100)
    local cumulativeChance = 0

    for weather, chance in pairs(Config.WeatherChances) do
        cumulativeChance = cumulativeChance + chance
        if random <= cumulativeChance then
            debugPrint("Random weather selected: " .. weather)
            return weather
        end
    end

    return "CLEAR"
end

-- Function to get random weather for regions
local function getRandomRegionalWeather()
    for region, _ in pairs(Config.Regions) do
        regionWeather[region] = getRandomWeather()
    end
    debugPrint("Random regional weather: " .. json.encode(regionWeather))
end

-- Function to get live local weather from Open-Meteo
local function getLiveWeather()
    local url = 'https://api.open-meteo.com/v1/forecast?latitude=' .. Config.Latitude ..
                '&longitude=' .. Config.Longitude .. '&hourly=weathercode&current_weather=true'
    
    debugPrint("Fetching live weather data from " .. url)
    PerformHttpRequest(url, function(statusCode, response, headers)
        if statusCode == 200 then
            local data = json.decode(response)
            local weatherCode = data.current_weather.weathercode

            -- Map weather codes to FiveM weather types
            local weatherMap = {
                [0] = "CLEAR", [1] = "CLOUDS", [2] = "OVERCAST", [3] = "OVERCAST",
                [45] = "FOGGY", [48] = "FOGGY", [51] = "RAIN", [53] = "RAIN",
                [55] = "RAIN", [56] = "RAIN", [57] = "RAIN", [61] = "RAIN",
                [63] = "RAIN", [65] = "RAIN", [66] = "RAIN", [67] = "RAIN",
                [71] = "SNOWLIGHT", [73] = "SNOWLIGHT", [75] = "BLIZZARD",
                [77] = "SNOWLIGHT", [80] = "RAIN", [81] = "RAIN", [82] = "RAIN",
                [85] = "SNOWLIGHT", [86] = "BLIZZARD", [95] = "THUNDER",
                [96] = "THUNDER", [99] = "THUNDER"
            }

            local newWeather = weatherMap[weatherCode] or "CLEAR"
            debugPrint("Live weather fetched: " .. newWeather)
            changeWeather(newWeather)
        else
            debugPrint("Failed to fetch live weather data, status code: " .. statusCode)
        end
    end, 'GET')
end

-- Exported function to set weather
function SetWeather(weather, region)
    if Config.WeatherTypes[weather] then
        if Config.UseRegionalWeather and region then
            if Config.Regions[region] then
                debugPrint("Export: Setting weather for region " .. region .. ": " .. weather)
                changeWeather(weather, region)
            end
        else
            debugPrint("Export: Setting global weather: " .. weather)
            changeWeather(weather)
        end
    end
end

-- Exported function to get current weather
function GetCurrentWeather(region)
    if Config.UseRegionalWeather and region then
        debugPrint("Export: Getting weather for region " .. region .. ": " .. regionWeather[region])
        return regionWeather[region]
    end
    debugPrint("Export: Getting global weather: " .. currentWeather)
    return currentWeather
end

-- Exported function to enable weather sync
function EnableWeatherSync()
    weatherSyncEnabled = true
    debugPrint("Weather sync enabled")
end

-- Exported function to disable weather sync
function DisableWeatherSync()
    weatherSyncEnabled = false
    debugPrint("Weather sync disabled")
end

-- Exported function to enable time sync
function EnableTimeSync()
    timeSyncEnabled = true
    debugPrint("Time sync enabled")
end

-- Exported function to disable time sync
function DisableTimeSync()
    timeSyncEnabled = false
    debugPrint("Time sync disabled")
end

-- Blackout Functions
-- ===============================================

-- Function to trigger a blackout
local function triggerBlackout()
    isBlackout = true
    debugPrint("Triggering blackout")
    TriggerClientEvent('toggleBlackout', -1, isBlackout)
end

-- Function to clear a blackout
local function clearBlackout()
    isBlackout = false
    debugPrint("Clearing blackout")
    TriggerClientEvent('toggleBlackout', -1, isBlackout)
end

-- Extreme Weather Functions
-- ===============================================

-- Function to trigger an extreme event
local function triggerExtremeEvent(event)
    debugPrint("Triggering extreme event: " .. event)
    if event == "EARTHQUAKE" then
        TriggerClientEvent('triggerEarthquake', -1)
    elseif event == "STORM" then
        TriggerClientEvent('triggerStorm', -1)
    elseif event == "EXTREME_COLD" then
        TriggerClientEvent('triggerExtremeCold', -1)
    elseif event == "EXTREME_HEAT" then
        TriggerClientEvent('triggerExtremeHeat', -1)
    elseif event == "TSUNAMI" and Config.TsunamiForRestart then
        TriggerClientEvent('triggerTsunami', -1)
    else
        debugPrint("Unknown extreme event: " .. event)
    end
end

-- Function to clear an extreme event
local function clearExtremeEvent()
    debugPrint("Clearing extreme event")
    TriggerClientEvent('clearExtremeEvent', -1)
end

-- Voting Functions
-- ===============================================

-- Function to handle voting results
local function handleVotingResults()
    local maxVotes = 0
    local weatherOptions = {}

    for weather, count in pairs(voteCounts) do
        if count > maxVotes then
            maxVotes = count
            weatherOptions = {weather}
        elseif count == maxVotes then
            table.insert(weatherOptions, weather)
        end
    end

    if #weatherOptions > 0 then
        local selectedWeather = weatherOptions[math.random(#weatherOptions)]
        debugPrint("Voting result: " .. selectedWeather)
        changeWeather(selectedWeather, nil, 30.0)
    else
        local randomWeather = getRandomWeather()
        debugPrint("No votes cast, selecting random weather: " .. randomWeather)
        changeWeather(randomWeather, nil, 30.0)
    end

    voteCounts = {}
    votedPlayers = {}
    votingActive = false

    TriggerClientEvent('endVoting', -1)
end

-- Handle player votes
RegisterNetEvent('voteWeather')
AddEventHandler('voteWeather', function(weather)
    if votingActive and not Config.WeatherBlacklist[weather] then
        voteCounts[weather] = (voteCounts[weather] or 0) + 1
        debugPrint("Vote received for " .. weather .. ". Total votes: " .. voteCounts[weather])
    else
        debugPrint("Invalid vote received or voting not active")
    end
end)

RegisterNetEvent('submitWeatherVote')
AddEventHandler('submitWeatherVote', function(weatherType)
    local source = source
    print("Vote received from source: " .. source .. " for weather: " .. weatherType)  -- Debug print

    if votingActive then
        if not votedPlayers[source] then
            if Config.WeatherTypes[weatherType] then
                if not table.contains(Config.WeatherBlacklist, weatherType) then
                    voteCounts[weatherType] = (voteCounts[weatherType] or 0) + 1
                    votedPlayers[source] = true
                    TriggerClientEvent('updateVotes', -1, voteCounts)
                    TriggerClientEvent('chat:addMessage', source, {args = {"^2[Weather]", "Your vote for " .. weatherType .. " has been counted!"}})
                    print("Vote counted for " .. weatherType .. ". Total votes: " .. voteCounts[weatherType])
                else
                    TriggerClientEvent('chat:addMessage', source, {args = {"^1[Weather]", weatherType .. " is not available for voting!"}})
                end
            else
                TriggerClientEvent('chat:addMessage', source, {args = {"^1[Weather]", "Invalid weather type!"}})
            end
        else
            TriggerClientEvent('chat:addMessage', source, {args = {"^1[Weather]", "You have already voted in this session!"}})
        end
    else
        TriggerClientEvent('chat:addMessage', source, {args = {"^1[Weather]", "Voting is not currently active!"}})
    end
end)

-- ===============================================
-- Citizen Threads
-- ===============================================

-- Function to update server time
Citizen.CreateThread(function()
    while true do
        if Config.UseRealTime then
            local hours, minutes = getRealWorldTime()
            currentServerTime.hours = hours
            currentServerTime.minutes = minutes
        else
            Citizen.Wait(timeSyncInterval)
            currentServerTime.minutes = currentServerTime.minutes + 1
            if currentServerTime.minutes >= 60 then
                currentServerTime.hours = (currentServerTime.hours + 1) % 24
                currentServerTime.minutes = 0
            end
        end

        if timeSyncEnabled then
            TriggerClientEvent('setTimeOfDay', -1, currentServerTime.hours, currentServerTime.minutes)
        end

        if Config.UseRealTime then
            Citizen.Wait(60000) -- Update every minute if using real-time sync
        end
    end
end)

-- Live weather timer
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000)
        if Config.UseLiveWeather then
            debugPrint("Fetching live weather")
            getLiveWeather()
        end
    end
end)

-- Random regional weather timer
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.WeatherChangeInterval * 60000)
        if Config.UseRegionalWeather then
            getRandomRegionalWeather()
            TriggerClientEvent('updateRegionalWeather', -1, regionWeather)
        end
    end
end)

-- Voting timer
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.VotingInterval * 60000)
        if Config.EnableVotingSystem then
            votingActive = true
            voteCounts = {}
            votedPlayers = {}
            debugPrint("Starting voting session")
            TriggerClientEvent('startVoting', -1, Config.VotingDuration, Config.WeatherTypes, Config.WeatherBlacklist)
            Citizen.Wait(Config.VotingDuration * 60000)
            handleVotingResults()
        end
    end
end)

-- ===============================================
-- Register Commands
-- ===============================================

RegisterCommand('forcevote', function(source, args, rawCommand)
    if IsPlayerAceAllowed(source, "command.setweather") then
        if Config.EnableVotingSystem then
            votingActive = true
            votedPlayers = {}
            print("Force starting voting session")
            TriggerClientEvent('startVoting', -1, Config.VotingDuration, Config.WeatherTypes, Config.WeatherBlacklist)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Voting system is disabled!' } })
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'You do not have permission to use this command!' } })
    end
end, false)

-- Command for admins to change weather
RegisterCommand('setweather', function(source, args, rawCommand)
    if IsPlayerAceAllowed(source, "command.setweather") then
        local newWeather = args[1]:upper()
        if Config.WeatherTypes[newWeather] then
            if Config.UseRegionalWeather then
                local region = args[2] and args[2]:capitalize()
                if Config.Regions[region] then
                    changeWeather(newWeather, region)
                else
                    TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid region!' } })
                end
            else
                debugPrint("Setting global weather: " .. newWeather)
                changeWeather(newWeather)
            end
        else
            TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid weather type!' } })
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'You do not have permission to use this command!' } })
    end
end, false)

-- Command for admins to change time
RegisterCommand('settime', function(source, args, rawCommand)
    if IsPlayerAceAllowed(source, "command.settime") then
        local hours = tonumber(args[1])
        local minutes = tonumber(args[2]) or 0
        if hours and hours >= 0 and hours < 24 and minutes >= 0 and minutes < 60 then
            currentServerTime.hours = hours
            currentServerTime.minutes = minutes
            TriggerClientEvent('setTimeOfDay', -1, hours, minutes)
            debugPrint("Setting time to: " .. hours .. ":" .. string.format("%02d", minutes))
        else
            TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid time format! Use /settime [hours] [minutes]' } })
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'You do not have permission to use this command!' } })
    end
end, false)

-- Command for admins to trigger blackout
RegisterCommand('blackout', function(source, args, rawCommand)
    if IsPlayerAceAllowed(source, "command.setweather") then
        triggerBlackout()
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'You do not have permission to use this command!' } })
    end
end, false)

-- Command for admins to clear blackout
RegisterCommand('clearblackout', function(source, args, rawCommand)
    if IsPlayerAceAllowed(source, "command.setweather") then
        clearBlackout()
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'You do not have permission to use this command!' } })
    end
end, false)

-- Command for admins to trigger extreme events
RegisterCommand('extremeevent', function(source, args, rawCommand)
    if IsPlayerAceAllowed(source, "command.setweather") then
        local event = args[1]:upper()
        if Config.ExtremeEvents[event] then
            triggerExtremeEvent(event)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid extreme event!' } })
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'You do not have permission to use this command!' } })
    end
end, false)

-- Command for admins to clear extreme events
RegisterCommand('clearextremeevent', function(source, args, rawCommand)
    if IsPlayerAceAllowed(source, "command.setweather") then
        clearExtremeEvent()
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'You do not have permission to use this command!' } })
    end
end, false)

-- ===============================================
-- Exports
-- ===============================================

-- Register the exports
exports('SetWeather', SetWeather)
exports('GetCurrentWeather', GetCurrentWeather)
exports('TriggerBlackout', triggerBlackout)
exports('ClearBlackout', clearBlackout)
exports('TriggerExtremeEvent', triggerExtremeEvent)
exports('ClearExtremeEvent', clearExtremeEvent)
exports('EnableWeatherSync', EnableWeatherSync)
exports('DisableWeatherSync', DisableWeatherSync)
exports('EnableTimeSync', EnableTimeSync)
exports('DisableTimeSync', DisableTimeSync)
