-- ===============================================
-- Module: server.lua
-- Author: B2DevUK | Discord: b2dev
-- Date: 15/07/24
-- Description: Server-side script for b2_weatherEssentials
-- ===============================================
local currentVersion = "1.3.5"
-- GITHUB VERSION CHECK
function fetchLatestVersion(callback)
    PerformHttpRequest("https://api.github.com/repos/B2DevUK/B2_WeatherEssentials/releases/latest", function(statusCode, response, headers)
        if statusCode == 200 then
            local data = json.decode(response)
            if data and data.tag_name then
                callback(data.tag_name)
            else
                print("Failed to fetch the latest version")
            end
        else
            print("HTTP request failed with status code: " .. statusCode)
        end
    end, "GET")
end

function checkForUpdates()
    fetchLatestVersion(function(latestVersion)
        if currentVersion ~= latestVersion then
            print("A new version of the script is available!")
            print("Current version: " .. currentVersion)
            print("Latest version: " .. latestVersion)
            print("Please update the script from: https://github.com/B2DevUK/B2_WeatherEssentials")
        else
            print("Your script is up to date!")
        end
    end)
end

checkForUpdates()


-- ===============================================
-- Variables
-- ===============================================

local currentWeather = "CLEAR"

local function buildRegionWeatherState(defaultWeather)
    local state = {}
    for regionName, _ in pairs(Config.Regions or {}) do
        state[regionName] = defaultWeather or "CLEAR"
    end
    return state
end

local regionWeather = buildRegionWeatherState(currentWeather)

local isBlackout = false
local currentExtremeEvent = nil

local votingActive = false
local voteCounts = {}
local votedPlayers = {}

local currentServerTime = {hours = 12, minutes = 0}

local weatherSyncEnabled = true
local timeSyncEnabled = true
local timeSyncInterval = (Config.TimeScale * 60 * 1000) / 1440


local adminPanelSubscribers = {}
local broadcastAdminPanelState

local function hasWeatherUiPermission(source)
    return source == 0
        or IsPlayerAceAllowed(source, "command.setweather")
        or IsPlayerAceAllowed(source, "command.settime")
        or IsPlayerAceAllowed(source, "b2weather.admin")
end

local function buildAdminPanelState()
    return {
        currentWeather = currentWeather,
        regionWeather = regionWeather,
        isBlackout = isBlackout,
        currentExtremeEvent = currentExtremeEvent,
        currentServerTime = currentServerTime,
        weatherSyncEnabled = weatherSyncEnabled,
        timeSyncEnabled = timeSyncEnabled,
        useRegionalWeather = Config.UseRegionalWeather,
        weatherTypes = Config.WeatherTypes,
        regions = Config.Regions,
        extremeEvents = Config.ExtremeEvents
    }
end

broadcastAdminPanelState = function()
    local state = buildAdminPanelState()

    for player, _ in pairs(adminPanelSubscribers) do
        TriggerClientEvent('b2_weather:updateAdminPanelState', player, state)
    end
end

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

local function normalizeRegionName(region)
    if type(region) ~= 'string' then
        return nil
    end

    local trimmed = region:gsub('^%s+', ''):gsub('%s+$', '')
    if trimmed == '' then
        return nil
    end

    if trimmed:upper() == 'GLOBAL' then
        return nil
    end

    for regionName, _ in pairs(Config.Regions or {}) do
        if trimmed == regionName or trimmed:lower() == tostring(regionName):lower() then
            return regionName
        end

        local normalizedTrimmed = trimmed:lower():gsub('[%s_%-]', '')
        local normalizedRegion = tostring(regionName):lower():gsub('[%s_%-]', '')
        if normalizedTrimmed == normalizedRegion then
            return regionName
        end
    end

    return false
end

-- ===============================================
-- Main Functions
-- ===============================================

-- Weather Update Functions
-- ===============================================

-- Weather update function
local function changeWeather(weather, region, transitionTime)
    transitionTime = transitionTime or 10.0

    if Config.UseRegionalWeather then
        if region then
            regionWeather[region] = weather
            debugPrint("Changing weather for region " .. region .. " to " .. weather)
        else
            currentWeather = weather
            for regionName, _ in pairs(Config.Regions or {}) do
                regionWeather[regionName] = weather
            end
            debugPrint("Changing all configured regions to global weather " .. currentWeather)
        end

        TriggerClientEvent('updateRegionalWeather', -1, regionWeather, transitionTime)
    else
        currentWeather = weather
        debugPrint("Changing global weather to " .. currentWeather)
        TriggerClientEvent('updateWeather', -1, currentWeather, transitionTime)
    end

    broadcastAdminPanelState()
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
    if not Config.WeatherTypes[weather] then
        return
    end

    local normalizedRegion = normalizeRegionName(region)

    if Config.UseRegionalWeather and normalizedRegion then
        debugPrint("Export: Setting weather for region " .. normalizedRegion .. ": " .. weather)
        changeWeather(weather, normalizedRegion)
        return
    end

    debugPrint("Export: Setting global weather: " .. weather)
    changeWeather(weather)
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
    -- Immediately sync current weather to all clients
    if Config.UseRegionalWeather then
        TriggerClientEvent('updateRegionalWeather', -1, regionWeather, 0)
    else
        TriggerClientEvent('updateWeather', -1, currentWeather, 0)
    end
    debugPrint("Weather sync enabled and current weather synced to all clients")
    broadcastAdminPanelState()
end

-- Exported function to disable weather sync
function DisableWeatherSync()
    weatherSyncEnabled = false
    debugPrint("Weather sync disabled")
    broadcastAdminPanelState()
end

-- Exported function to enable time sync
function EnableTimeSync()
    timeSyncEnabled = true
    -- Immediately sync current time to all clients
    TriggerClientEvent('setTimeOfDay', -1, currentServerTime.hours, currentServerTime.minutes)
    debugPrint("Time sync enabled and current time synced to all clients")
    broadcastAdminPanelState()
end

-- Exported function to disable time sync
function DisableTimeSync()
    timeSyncEnabled = false
    debugPrint("Time sync disabled")
    broadcastAdminPanelState()
end

RegisterNetEvent('requestCurrentWeather', function()
    local source = source
    if Config.UseRegionalWeather then
        TriggerClientEvent('updateRegionalWeather', source, regionWeather, 0)
    else
        TriggerClientEvent('updateWeather', source, currentWeather, 0)
    end
end)

RegisterNetEvent('requestCurrentTime', function()
    local source = source
    TriggerClientEvent('setTimeOfDay', source, currentServerTime.hours, currentServerTime.minutes)
end)

-- Blackout Functions
-- ===============================================

-- Function to trigger a blackout
local function triggerBlackout()
    isBlackout = true
    debugPrint("Triggering blackout")
    TriggerClientEvent('toggleBlackout', -1, isBlackout)
    broadcastAdminPanelState()
end

-- Function to clear a blackout
local function clearBlackout()
    isBlackout = false
    debugPrint("Clearing blackout")
    TriggerClientEvent('toggleBlackout', -1, isBlackout)
    broadcastAdminPanelState()
end

-- Extreme Weather Functions
-- ===============================================

-- Function to trigger an extreme event
local function triggerExtremeEvent(event)
    currentExtremeEvent = event
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

    broadcastAdminPanelState()
end

-- Function to clear an extreme event
local function clearExtremeEvent()
    currentExtremeEvent = nil
    debugPrint("Clearing extreme event")
    TriggerClientEvent('clearExtremeEvent', -1)
    broadcastAdminPanelState()
end

function GetCurrentExtremeWeather()
    return currentExtremeEvent
end

-- Voting Functions
-- ===============================================

-- Function to handle voting results
local function handleVotingResults()
    debugPrint("handleVotingResults called")
    local maxVotes = 0
    local weatherOptions = {}

    for weather, count in pairs(voteCounts) do
        debugPrint("Weather: " .. weather .. ", Count: " .. count)
        if count > maxVotes then
            maxVotes = count
            weatherOptions = {weather}
        elseif count == maxVotes then
            table.insert(weatherOptions, weather)
        end
    end

    local selectedWeather
    if #weatherOptions > 0 then
        selectedWeather = weatherOptions[math.random(#weatherOptions)]
        debugPrint("Voting result: " .. selectedWeather)
        changeWeather(selectedWeather, nil, 30.0)
    else
        local randomWeather = getRandomWeather()
        debugPrint("No votes cast, selecting random weather: " .. randomWeather)
        changeWeather(randomWeather, nil, 30.0)
        selectedWeather = randomWeather
    end

    voteCounts = {}
    votedPlayers = {}
    votingActive = false

    broadcastAdminPanelState()

    TriggerClientEvent('endVoting', -1)
    TriggerClientEvent('chat:addMessage', -1, {args = {"^2[Weather]", "Voting has ended. New weather: " .. selectedWeather}})
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

-- Handle player votes
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
            broadcastAdminPanelState()
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
            debugPrint("Voting session ended, handling results")
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
            Citizen.Wait(Config.VotingDuration * 60000)
            debugPrint("Force voting session ended, handling results")
            handleVotingResults()
        else
            TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Voting system is disabled!' } })
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'You do not have permission to use this command!' } })
    end
end, false)

-- Command for admins to change weather
RegisterCommand('setweather', function(source, args, rawCommand)
    if not IsPlayerAceAllowed(source, "command.setweather") then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'You do not have permission to use this command!' } })
        return
    end

    local rawWeather = args[1]
    local newWeather = rawWeather and rawWeather:upper()

    if not newWeather or not Config.WeatherTypes[newWeather] then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid weather type!' } })
        return
    end

    local regionArg = args[2]
    local normalizedRegion = Config.UseRegionalWeather and normalizeRegionName(regionArg) or nil

    if Config.UseRegionalWeather and regionArg and normalizedRegion == false then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid region!' } })
        return
    end

    if Config.UseRegionalWeather and normalizedRegion then
        changeWeather(newWeather, normalizedRegion)
        return
    end

    debugPrint("Setting global weather: " .. newWeather)
    changeWeather(newWeather)
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
            broadcastAdminPanelState()
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
-- Admin UI Events
-- ===============================================

RegisterNetEvent('b2_weather:requestPanelOpen', function()
    local source = source

    if not hasWeatherUiPermission(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'You do not have permission to use this command!' } })
        return
    end

    adminPanelSubscribers[source] = true
    TriggerClientEvent('b2_weather:openAdminPanel', source, buildAdminPanelState())
end)

RegisterNetEvent('b2_weather:closePanel', function()
    adminPanelSubscribers[source] = nil
end)

AddEventHandler('playerDropped', function()
    adminPanelSubscribers[source] = nil
end)

RegisterNetEvent('b2_weather:requestAdminPanelState', function()
    local source = source

    if not hasWeatherUiPermission(source) then
        return
    end

    adminPanelSubscribers[source] = true
    TriggerClientEvent('b2_weather:updateAdminPanelState', source, buildAdminPanelState())
end)

RegisterNetEvent('b2_weather:setWeatherFromUi', function(weather, region)
    local source = source

    if not hasWeatherUiPermission(source) then
        return
    end

    if type(weather) ~= 'string' then
        return
    end

    weather = weather:upper()
    local normalizedRegion = Config.UseRegionalWeather and normalizeRegionName(region) or nil

    if not Config.WeatherTypes[weather] then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid weather type!' } })
        return
    end

    if Config.UseRegionalWeather and region and normalizedRegion == false then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid region!' } })
        return
    end

    if Config.UseRegionalWeather and normalizedRegion then
        changeWeather(weather, normalizedRegion, 12.0)
        return
    end

    changeWeather(weather, nil, 12.0)
end)

RegisterNetEvent('b2_weather:setTimeFromUi', function(hours, minutes)
    local source = source

    if not hasWeatherUiPermission(source) then
        return
    end

    hours = tonumber(hours)
    minutes = tonumber(minutes) or 0

    if not hours or hours < 0 or hours > 23 or minutes < 0 or minutes > 59 then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid time format!' } })
        return
    end

    currentServerTime.hours = hours
    currentServerTime.minutes = minutes

    if timeSyncEnabled then
        TriggerClientEvent('setTimeOfDay', -1, hours, minutes)
    end

    broadcastAdminPanelState()
end)

RegisterNetEvent('b2_weather:setBlackoutFromUi', function(state)
    local source = source

    if not hasWeatherUiPermission(source) then
        return
    end

    if state then
        triggerBlackout()
    else
        clearBlackout()
    end
end)

RegisterNetEvent('b2_weather:setExtremeEventFromUi', function(eventName)
    local source = source

    if not hasWeatherUiPermission(source) then
        return
    end

    if type(eventName) ~= 'string' then
        return
    end

    eventName = eventName:upper()

    if not Config.ExtremeEvents[eventName] then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid extreme event!' } })
        return
    end

    triggerExtremeEvent(eventName)
end)

RegisterNetEvent('b2_weather:clearExtremeEventFromUi', function()
    local source = source

    if not hasWeatherUiPermission(source) then
        return
    end

    clearExtremeEvent()
end)

RegisterNetEvent('b2_weather:setWeatherSyncFromUi', function(state)
    local source = source

    if not hasWeatherUiPermission(source) then
        return
    end

    if state then
        EnableWeatherSync()
    else
        DisableWeatherSync()
    end
end)

RegisterNetEvent('b2_weather:setTimeSyncFromUi', function(state)
    local source = source

    if not hasWeatherUiPermission(source) then
        return
    end

    if state then
        EnableTimeSync()
    else
        DisableTimeSync()
    end
end)

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
exports('GetCurrentExtremeWeather', GetCurrentExtremeWeather)
