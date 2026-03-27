-- ===============================================
-- Module: client.lua
-- Author: B2DevUK | Discord: b2dev
-- Date: 15/07/24
-- Description: Client side script for b2_weatherEssentials
-- ===============================================

-- ===============================================
-- Variables
-- ===============================================

local weatherSyncEnabled = true
local timeSyncEnabled = true
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
local lightsState = false

local votingActive = false
local voteCounts = {}
local votingTimer = Config.VotingDuration * 60 * 1000
local adminPanelOpen = false
local activeRegion = nil

-- ===============================================
-- Helper Functions
-- ===============================================

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- Support for b2_vehicleEssentials
local function updateDrivingStyle(style)
    if Config.UsingVehicleEssentials then
        exports.b2_vehicleEssentials:ChangeNPCDrivingStyle(style)
    end
end

-- Sound Player
function PlaySound(soundFile, soundSet)
    SendNUIMessage({
        transactionType = 'playSound',
        transactionFile = soundFile,
        transactionVolume = 0.5
    })
end

local function debugPrint(message)
    if Config.Debugging then
        print("[CLIENT DEBUG]: " .. message)
    end
end

local function getPlayerRegion()
    if not Config.UseRegionalWeather then
        return nil
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    for regionName, data in pairs(Config.Regions or {}) do
        local distance = #(playerCoords.xy - vector2(data.x, data.y))
        if distance <= data.radius then
            return regionName
        end
    end

    return nil
end

local function applyWeatherInstant(weatherType, transitionTime)
    transitionTime = transitionTime or 15.0

    if not weatherType or currentExtremeEvent then
        return
    end

    SetWeatherTypeOverTime(weatherType, transitionTime)
    Citizen.CreateThread(function()
        Citizen.Wait(math.floor(transitionTime * 1000))
        SetWeatherTypePersist(weatherType)
        SetWeatherTypeNow(weatherType)
        SetWeatherTypeNowPersist(weatherType)

        if Config.WeatherDrivingStyles[weatherType] then
            updateDrivingStyle(Config.WeatherDrivingStyles[weatherType])
        end
    end)
end


local function sendAdminPanelState(state)
    SendNUIMessage({
        action = 'updateAdminPanelState',
        state = state
    })
end

local function openAdminPanel(state)
    adminPanelOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'openAdminPanel',
        state = state
    })
end

local function closeAdminPanel()
    if not adminPanelOpen then
        return
    end

    adminPanelOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'closeAdminPanel'
    })
    TriggerServerEvent('b2_weather:closePanel')
end

-- ===============================================
-- Main Functions
-- ===============================================

-- Weather Update Functions
-- ===============================================

-- Weather Update
RegisterNetEvent('updateWeather')
AddEventHandler('updateWeather', function(newWeather, transitionTime)
    transitionTime = transitionTime or 15.0
    if not currentExtremeEvent then
        currentWeather = newWeather
        applyWeatherInstant(newWeather, transitionTime)
    end
end)

-- Regional Weather Update
RegisterNetEvent('updateRegionalWeather')
AddEventHandler('updateRegionalWeather', function(newRegionWeather, transitionTime)
    transitionTime = transitionTime or 15.0
    if not currentExtremeEvent then
        regionWeather = newRegionWeather or regionWeather
        local playerRegion = getPlayerRegion()
        local newWeather = playerRegion and regionWeather[playerRegion] or currentWeather
        applyWeatherInstant(newWeather, transitionTime)
    end
end)


-- Blackout Functions
-- ===============================================

-- Blackout Toggle Event
RegisterNetEvent('toggleBlackout')
AddEventHandler('toggleBlackout', function(state)
    if state then
        TriggerEvent('startBlackout')
    else
        isBlackout = false
        SetArtificialLightsState(false)
        if Config.UsingVehicleEssentials then
            updateDrivingStyle(786603)
        end
    end
end)

-- Blackout Start Event
RegisterNetEvent('startBlackout')
AddEventHandler('startBlackout', function()
    isBlackout = true

    SendNUIMessage({
        action = 'playSound',
        sound = 'blackout.wav'
    })

    if Config.UsingVehicleEssentials then
        updateDrivingStyle(2883621)
    end

    Citizen.CreateThread(function()
        local flickerDuration = 5000
        local endTime = GetGameTimer() + flickerDuration
        while GetGameTimer() < endTime do
            lightsState = not lightsState
            SetArtificialLightsState(lightsState)
            SetArtificialLightsStateAffectsVehicles(false)
            Citizen.Wait(math.random(200, 800))
        end
        SetArtificialLightsState(true)
        SetArtificialLightsStateAffectsVehicles(false)
    end)
end)

-- Extreme Event Handler Functions
-- ===============================================

-- Earthquake Event
RegisterNetEvent('triggerEarthquake')
AddEventHandler('triggerEarthquake', function()
    currentExtremeEvent = "EARTHQUAKE"

    SendNUIMessage({
        action = 'playSound',
        sound = 'earthquake.wav'
    })

    ShakeGameplayCam("LARGE_EXPLOSION_SHAKE", 1.0)
    local playerPed = PlayerPedId()

    TriggerEvent('startBlackout')

    Citizen.CreateThread(function()
        local shakeEndTime = GetGameTimer() + 10000
        while GetGameTimer() < shakeEndTime do
            if IsPedOnFoot(playerPed) then
                SetPedToRagdoll(playerPed, 5000, 5000, 0, false, false, false)
            end
            Citizen.Wait(1000)
        end
        StopGameplayCamShaking(true)
    end)

    Citizen.Wait(60000 - 10000)
    currentExtremeEvent = nil
end)

-- Storm Event
RegisterNetEvent('triggerStorm')
AddEventHandler('triggerStorm', function()
    currentExtremeEvent = "STORM"
    SetWeatherTypeOverTime("THUNDER", 15.0)
    SetWeatherTypePersist("THUNDER")
    SetWeatherTypeNow("THUNDER")
    SetWeatherTypeNowPersist("THUNDER")

    SetWindSpeed(12.0)
    SetWindDirection(math.random(0, 360))

    if Config.UsingVehicleEssentials then
        updateDrivingStyle(Config.ExtremeEventDrivingStyles.STORM)
    end

    Citizen.CreateThread(function()
        while currentExtremeEvent == "STORM" do
            Citizen.Wait(math.random(3000, 10000))
            if math.random(1, 100) > 70 then
                local x = math.random(-1000, 1000)
                local y = math.random(-1000, 1000)
                local z = math.random(0, 100)
                AddExplosion(x, y, z, 1, 1.0, true, false, 1.0)
            end
        end
    end)

    Citizen.Wait(60000)
    currentExtremeEvent = nil
end)

-- Extreme Cold Event
RegisterNetEvent('triggerExtremeCold')
AddEventHandler('triggerExtremeCold', function()
    currentExtremeEvent = "EXTREME_COLD"
    SetWeatherTypeOverTime("XMAS", 15.0)
    SetWeatherTypePersist("XMAS")
    SetWeatherTypeNow("XMAS")
    SetWeatherTypeNowPersist("XMAS")

    SetWindSpeed(25.0)
    SetWindDirection(math.random(0, 360))

    local particleDict = "core"
    local particleName = "ent_snow_blizzard"

    RequestNamedPtfxAsset(particleDict)
    while not HasNamedPtfxAssetLoaded(particleDict) do
        Citizen.Wait(1)
    end

    UseParticleFxAssetNextCall(particleDict)
    local particleHandle = StartParticleFxLoopedAtCoord(particleName, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 100.0, false, false, false, 0)
    
    Citizen.CreateThread(function()
        while currentExtremeEvent == "EXTREME_COLD" do
            Citizen.Wait(0)
            UseParticleFxAssetNextCall(particleDict)
            StartParticleFxLoopedAtCoord(particleName, GetEntityCoords(PlayerPedId()).x, GetEntityCoords(PlayerPedId()).y, GetEntityCoords(PlayerPedId()).z, 0.0, 0.0, 0.0, 100.0, false, false, false, 0)
        end
        StopParticleFxLooped(particleHandle, 0)
    end)

    Citizen.Wait(60000)
    currentExtremeEvent = nil
end)

-- Extreme Heat Event
RegisterNetEvent('triggerExtremeHeat')
AddEventHandler('triggerExtremeHeat', function()
    currentExtremeEvent = "EXTREME_HEAT"
    SetWeatherTypeOverTime("EXTRASUNNY", 15.0)
    SetWeatherTypePersist("EXTRASUNNY")
    SetWeatherTypeNow("EXTRASUNNY")
    SetWeatherTypeNowPersist("EXTRASUNNY")

    Citizen.CreateThread(function()
        while currentExtremeEvent == "EXTREME_HEAT" do
            Citizen.Wait(0)
            SetTimecycleModifier("REDMIST_blend")
            SetTimecycleModifierStrength(0.5)
        end
        ClearTimecycleModifier()
    end)

    Citizen.Wait(60000) 
    currentExtremeEvent = nil
end)

-- Tsunami Event
RegisterNetEvent('triggerTsunami')
AddEventHandler('triggerTsunami', function()
    currentExtremeEvent = "TSUNAMI"

    -- Stage 1: Screen shake effect
    ShakeGameplayCam("LARGE_EXPLOSION_SHAKE", 1.0)
    Citizen.Wait(10000)
    StopGameplayCamShaking(true)

    -- Stage 2: City blackout
    TriggerEvent('toggleBlackout', true)
    Citizen.Wait(10000)

    -- Stage 3: Air raid sirens
    local sirenSoundId = GetSoundId()
    PlaySoundFromCoord(sirenSoundId, "Air_Defenses_Air_Raid_Siren", GetEntityCoords(PlayerPedId()).x, GetEntityCoords(PlayerPedId()).y, GetEntityCoords(PlayerPedId()).z, "DLC_WMSIRENS", false, 0, false)
    Citizen.Wait(10000)
    StopSound(sirenSoundId)
    ReleaseSoundId(sirenSoundId)

    currentExtremeEvent = nil
end)

-- Clear Extreme Events
RegisterNetEvent('clearExtremeEvent')
AddEventHandler('clearExtremeEvent', function()
    currentExtremeEvent = nil
    SetWindSpeed(0.0)
    ClearWeatherTypePersist()
    ClearOverrideWeather()
    ClearTimecycleModifier()
    TriggerEvent('toggleBlackout', false)
    
    if Config.UseRegionalWeather then
        local playerCoords = GetEntityCoords(PlayerPedId())
        for region, data in pairs(Config.Regions) do
            local distance = #(playerCoords.xy - vector2(data.x, data.y))
            if distance <= data.radius then
                local regionWeatherType = regionWeather[region]
                if Config.WeatherDrivingStyles[regionWeatherType] then
                    updateDrivingStyle(Config.WeatherDrivingStyles[regionWeatherType])
                else
                    updateDrivingStyle(786603)
                end
                break
            end
        end
    else
        if Config.WeatherDrivingStyles[currentWeather] then
            updateDrivingStyle(Config.WeatherDrivingStyles[currentWeather])
        else
            updateDrivingStyle(786603)
        end
    end
end)

-- Voting Functions
-- ===============================================

RegisterNetEvent('startVoting')
AddEventHandler('startVoting', function(duration, weatherTypes, blacklist)
    debugPrint("Received startVoting event")
    
    SendNUIMessage({
        action = 'startVoting',
        duration = duration,
        weatherTypes = weatherTypes,
        blacklist = blacklist
    })
    votingActive = true
end)

RegisterNetEvent('endVoting')
AddEventHandler('endVoting', function()
    debugPrint("Received endVoting event")
    SendNUIMessage({
        action = 'endVoting'
    })
    votingActive = false
end)

RegisterNetEvent('updateVotes')
AddEventHandler('updateVotes', function(newVotes)
    debugPrint("Received updateVotes event")
    SendNUIMessage({
        action = 'updateVotes',
        votes = newVotes
    })
end)

RegisterCommand('weathervote', function(source, args, rawCommand)
    debugPrint("Weather vote command received")
    if #args > 0 then
        local weatherType = args[1]:upper()
        debugPrint("Attempting to vote for: " .. weatherType)
        TriggerServerEvent('submitWeatherVote', weatherType)
    else
        debugPrint("No weather type specified")
    end
end, false)

AddEventHandler('chatMessage', function(source, name, message)
    if string.sub(message, 1, 1) == '!' then
        local cmd = string.sub(message, 2):upper()
        if Config.WeatherTypes[cmd] then
            if not table.contains(Config.WeatherBlacklist, cmd) then
                CancelEvent()
                TriggerServerEvent('submitWeatherVote', cmd)
            else
                TriggerEvent('chat:addMessage', {
                    args = {"^1[Weather]", cmd .. " is not available for voting!"}
                })
            end
        end
    end
end)

-- Time Related Functions
-- ===============================================

-- Event to set the time of day
RegisterNetEvent('setTimeOfDay')
AddEventHandler('setTimeOfDay', function(hours, minutes)
    NetworkOverrideClockTime(hours, minutes, 0)
end)

RegisterNetEvent('updateTime')
AddEventHandler('updateTime', function(hours, minutes)
    if timeSyncEnabled then
        NetworkOverrideClockTime(hours, minutes, 0)
    end
end)

-- Weather & Time Sync Functions
-- ===============================================

RegisterNetEvent('syncWeatherAndTime')
AddEventHandler('syncWeatherAndTime', function(weather, hours, minutes)
    if Config.UseRegionalWeather then
        TriggerEvent('updateRegionalWeather', weather, 0)
    else
        TriggerEvent('updateWeather', weather, 0)
    end
    NetworkOverrideClockTime(hours, minutes, 0)
end)


RegisterNetEvent('b2_weather:openAdminPanel')
AddEventHandler('b2_weather:openAdminPanel', function(state)
    openAdminPanel(state)
end)

RegisterNetEvent('b2_weather:updateAdminPanelState')
AddEventHandler('b2_weather:updateAdminPanelState', function(state)
    sendAdminPanelState(state)
end)

RegisterCommand('weatherui', function()
    TriggerServerEvent('b2_weather:requestPanelOpen')
end, false)

RegisterKeyMapping('weatherui', 'Open Weather Control Panel', 'keyboard', '')

-- UI Functions
-- ===============================================

-- Handle NUI callbacks
RegisterNUICallback('close', function(data, cb)
    votingActive = false
    closeAdminPanel()
    cb('ok')
end)

RegisterNUICallback('closeAdminPanel', function(data, cb)
    closeAdminPanel()
    cb('ok')
end)

RegisterNUICallback('requestAdminState', function(data, cb)
    TriggerServerEvent('b2_weather:requestAdminPanelState')
    cb('ok')
end)

RegisterNUICallback('setWeather', function(data, cb)
    TriggerServerEvent('b2_weather:setWeatherFromUi', data.weather, data.region)
    cb('ok')
end)

RegisterNUICallback('setTime', function(data, cb)
    TriggerServerEvent('b2_weather:setTimeFromUi', data.hours, data.minutes)
    cb('ok')
end)

RegisterNUICallback('setBlackout', function(data, cb)
    TriggerServerEvent('b2_weather:setBlackoutFromUi', data.state == true)
    cb('ok')
end)

RegisterNUICallback('setExtremeEvent', function(data, cb)
    TriggerServerEvent('b2_weather:setExtremeEventFromUi', data.event)
    cb('ok')
end)

RegisterNUICallback('clearExtremeEvent', function(data, cb)
    TriggerServerEvent('b2_weather:clearExtremeEventFromUi')
    cb('ok')
end)

RegisterNUICallback('setWeatherSync', function(data, cb)
    TriggerServerEvent('b2_weather:setWeatherSyncFromUi', data.state == true)
    cb('ok')
end)

RegisterNUICallback('setTimeSync', function(data, cb)
    TriggerServerEvent('b2_weather:setTimeSyncFromUi', data.state == true)
    cb('ok')
end)
-- ===============================================
-- Citizen Threads
-- ===============================================

-- Main Thread
Citizen.CreateThread(function()
    local CHECK_INTERVAL = 2000
    local fullSyncTimer = 0

    while true do
        Citizen.Wait(CHECK_INTERVAL)
        fullSyncTimer = fullSyncTimer + CHECK_INTERVAL

        if weatherSyncEnabled then
            if Config.UseRegionalWeather then
                local playerRegion = getPlayerRegion()
                if playerRegion ~= activeRegion then
                    activeRegion = playerRegion
                    local targetWeather = playerRegion and regionWeather[playerRegion] or currentWeather
                    applyWeatherInstant(targetWeather, 2.0)
                end
            end

            if fullSyncTimer >= 30000 then
                local gameWeather = GetPrevWeatherTypeHashName()
                local expectedWeather = currentWeather

                if Config.UseRegionalWeather then
                    local playerRegion = getPlayerRegion()
                    expectedWeather = playerRegion and regionWeather[playerRegion] or currentWeather
                end

                if expectedWeather and GetHashKey(expectedWeather) ~= gameWeather then
                    TriggerServerEvent('requestCurrentWeather')
                end
            end
        end

        if timeSyncEnabled and fullSyncTimer >= 30000 then
            TriggerServerEvent('requestCurrentTime')
        end

        if fullSyncTimer >= 30000 then
            fullSyncTimer = 0
        end
    end
end)

-- ===============================================
-- Exports & Weather Sync
-- ===============================================

-- Function to enable weather sync
function EnableWeatherSync()
    weatherSyncEnabled = true
    -- Request current weather from server
    TriggerServerEvent('requestCurrentWeather')
end

-- Function to disable weather sync
function DisableWeatherSync()
    weatherSyncEnabled = false
end

-- Function to enable time sync
function EnableTimeSync()
    timeSyncEnabled = true
    -- Request current time from server
    TriggerServerEvent('requestCurrentTime')
end

-- Function to disable time sync
function DisableTimeSync()
    timeSyncEnabled = false
end

-- Register the exports
exports('EnableWeatherSync', EnableWeatherSync)
exports('DisableWeatherSync', DisableWeatherSync)
exports('EnableTimeSync', EnableTimeSync)
exports('DisableTimeSync', DisableTimeSync)
