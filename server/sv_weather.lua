-- ===============================================
-- Module: server/sv_weather.lua
-- Description: Weather state, random selection, live weather fetch,
--              weather-change broadcasts, and sync enable/disable.
-- Depends on: sh_constants, sh_utils, config
-- ===============================================

-- -----------------------------------------------
-- State (module-local)
-- -----------------------------------------------
local currentWeather     = "CLEAR"
local regionWeather      = {}
local weatherSyncEnabled = true

-- Initialise regionWeather from Config.Regions at load time.
-- config.lua is a shared_script and is already evaluated before this file.
for region in pairs(Config.Regions) do
    regionWeather[region] = "CLEAR"
end

-- -----------------------------------------------
-- B2WE.getRandomWeather(weights)
-- weights: optional table {weatherType = weight, ...}
--   Falls back to Config.WeatherChances when nil.
-- Keys are sorted alphabetically before iteration so the draw is
-- deterministic regardless of table insertion order (bug fix).
-- -----------------------------------------------
function B2WE.getRandomWeather(weights)
    weights = weights or Config.WeatherChances

    -- Sorted list for deterministic iteration
    local sortedTypes = {}
    for weatherType in pairs(weights) do
        table.insert(sortedTypes, weatherType)
    end
    table.sort(sortedTypes)

    -- Sum all weights (weights need not pre-sum to 100)
    local total = 0
    for _, weatherType in ipairs(sortedTypes) do
        total = total + (weights[weatherType] or 0)
    end
    if total <= 0 then return "CLEAR" end

    local roll = math.random() * total
    local cumulative = 0
    for _, weatherType in ipairs(sortedTypes) do
        cumulative = cumulative + (weights[weatherType] or 0)
        if roll <= cumulative then
            B2WE.debugPrint("Random weather selected: " .. weatherType)
            return weatherType
        end
    end

    return sortedTypes[1] or "CLEAR"
end

-- -----------------------------------------------
-- B2WE.changeWeather(weather, region, transitionTime)
-- Updates state and broadcasts the appropriate event to all clients.
-- After broadcasting, triggers a forecast regeneration if sv_forecast
-- has been loaded (called at runtime so load order is not an issue).
-- -----------------------------------------------
function B2WE.changeWeather(weather, region, transitionTime)
    transitionTime = transitionTime or 10.0

    if region then
        regionWeather[region] = weather
        B2WE.debugPrint("Weather → region " .. region .. ": " .. weather)
    elseif Config.UseRegionalWeather then
        -- No region specified but regional mode is active — apply to all regions
        -- so the subsequent broadcast sends the correct weather everywhere.
        -- Without this, currentWeather is updated but regionWeather is stale,
        -- meaning the vote winner is set but never reaches any client.
        for r in pairs(regionWeather) do
            regionWeather[r] = weather
        end
        currentWeather = weather
        B2WE.debugPrint("Weather → all regions: " .. weather)
    else
        currentWeather = weather
        B2WE.debugPrint("Weather → global: " .. weather)
    end

    if Config.UseRegionalWeather then
        TriggerClientEvent(B2WE.Events.UPDATE_REGIONAL_WEATHER, -1, regionWeather, transitionTime)
    else
        TriggerClientEvent(B2WE.Events.UPDATE_WEATHER, -1, currentWeather, transitionTime)
    end

    -- Regenerate forecast (sv_forecast.lua defines this; available at runtime)
    if B2WE.broadcastForecast then
        B2WE.broadcastForecast()
    end
end

-- -----------------------------------------------
-- B2WE.getLiveWeather()
-- Fetches current weather from the Open-Meteo API (async).
-- Maps the WMO code using B2WE.WMO_MAP from sh_constants.
-- -----------------------------------------------
function B2WE.getLiveWeather()
    local url = "https://api.open-meteo.com/v1/forecast?latitude=" .. Config.Latitude
                .. "&longitude=" .. Config.Longitude .. "&current_weather=true"

    B2WE.debugPrint("Fetching live weather from Open-Meteo")
    PerformHttpRequest(url, function(statusCode, response)
        if statusCode == 200 then
            local data = json.decode(response)
            local code = data and data.current_weather and data.current_weather.weathercode
            if code then
                local mapped = B2WE.WMO_MAP[code] or "CLEAR"
                B2WE.debugPrint("Live weather: code " .. tostring(code) .. " → " .. mapped)
                B2WE.changeWeather(mapped)
            else
                B2WE.debugPrint("Live weather: malformed API response")
            end
        else
            B2WE.debugPrint("Live weather fetch failed (HTTP " .. tostring(statusCode) .. ")")
        end
    end, "GET")
end

-- -----------------------------------------------
-- B2WE.getCurrentWeather(region) → string
-- B2WE.getRegionWeather()        → table (full regionWeather)
-- -----------------------------------------------
function B2WE.getCurrentWeather(region)
    if Config.UseRegionalWeather and region then
        return regionWeather[region]
    end
    return currentWeather
end

function B2WE.getRegionWeather()
    return regionWeather
end

-- -----------------------------------------------
-- Export-facing globals (wired up in sv_exports.lua)
-- -----------------------------------------------
function SetWeather(weather, region)
    if not Config.WeatherTypes[weather] then return end

    if Config.UseRegionalWeather and region then
        if Config.Regions[region] then
            B2WE.debugPrint("Export SetWeather: region=" .. region .. " weather=" .. weather)
            B2WE.changeWeather(weather, region)
        end
    else
        B2WE.debugPrint("Export SetWeather: global weather=" .. weather)
        B2WE.changeWeather(weather)
    end
end

function GetCurrentWeather(region)
    return B2WE.getCurrentWeather(region)
end

function EnableWeatherSync()
    weatherSyncEnabled = true
    if Config.UseRegionalWeather then
        TriggerClientEvent(B2WE.Events.UPDATE_REGIONAL_WEATHER, -1, regionWeather, 0)
    else
        TriggerClientEvent(B2WE.Events.UPDATE_WEATHER, -1, currentWeather, 0)
    end
    B2WE.debugPrint("Weather sync enabled")
end

function DisableWeatherSync()
    weatherSyncEnabled = false
    B2WE.debugPrint("Weather sync disabled")
end

-- -----------------------------------------------
-- Net event: player requests current weather state
-- (sent on join via cl_main.lua)
-- -----------------------------------------------
RegisterNetEvent(B2WE.Events.REQUEST_CURRENT_WEATHER)
AddEventHandler(B2WE.Events.REQUEST_CURRENT_WEATHER, function()
    local src = source
    if Config.UseRegionalWeather then
        TriggerClientEvent(B2WE.Events.UPDATE_REGIONAL_WEATHER, src, regionWeather, 0)
    else
        TriggerClientEvent(B2WE.Events.UPDATE_WEATHER, src, currentWeather, 0)
    end
    -- Also re-send the forecast so the NUI recovers if the initial
    -- FULL_STATE_SYNC was received before the React app had mounted.
    if Config.EnableForecast and B2WE.getForecast then
        TriggerClientEvent(B2WE.Events.UPDATE_FORECAST, src, B2WE.getForecast())
    end
end)

-- -----------------------------------------------
-- Weather interval thread
-- Advances weather every WeatherChangeInterval minutes.
-- Skipped when UseLiveWeather = true (live polling thread handles that).
-- Season weights are applied if EnableSeasons = true and sv_seasons
-- has exposed B2WE.getSeasonWeights / B2WE.getCurrentSeason.
-- -----------------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.WeatherChangeInterval * 60000)

        if not weatherSyncEnabled or Config.UseLiveWeather then
            -- Nothing to do: sync is off or live weather drives changes
        else
            -- Resolve season weights if the seasons module is loaded
            local weights = nil
            if Config.EnableSeasons and B2WE.getSeasonWeights and B2WE.getCurrentSeason then
                weights = B2WE.getSeasonWeights(B2WE.getCurrentSeason())
            end

            if Config.UseRegionalWeather then
                -- Batch-update all regions and send one event
                for region in pairs(Config.Regions) do
                    regionWeather[region] = B2WE.getRandomWeather(weights)
                end
                B2WE.debugPrint("Interval: regional weather → " .. json.encode(regionWeather))
                TriggerClientEvent(B2WE.Events.UPDATE_REGIONAL_WEATHER, -1, regionWeather, 10.0)
            else
                currentWeather = B2WE.getRandomWeather(weights)
                B2WE.debugPrint("Interval: global weather → " .. currentWeather)
                TriggerClientEvent(B2WE.Events.UPDATE_WEATHER, -1, currentWeather, 10.0)
            end

            if B2WE.broadcastForecast then
                B2WE.broadcastForecast()
            end
        end
    end
end)

-- -----------------------------------------------
-- Live weather polling thread
-- Only does work when UseLiveWeather = true.
-- -----------------------------------------------
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000)
        if Config.UseLiveWeather and weatherSyncEnabled then
            B2WE.getLiveWeather()
        end
    end
end)