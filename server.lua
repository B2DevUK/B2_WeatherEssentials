local currentWeather = "CLEAR"

-- Function to change weather
local function changeWeather(weather)
    currentWeather = weather
    TriggerClientEvent('updateWeather', -1, currentWeather)
end

-- Function to randomly select weather based on chances
local function getRandomWeather()
    local random = math.random(1, 100)
    local cumulativeChance = 0

    for weather, chance in pairs(Config.WeatherChances) do
        cumulativeChance = cumulativeChance + chance
        if random <= cumulativeChance then
            return weather
        end
    end

    return "CLEAR"
end

-- Function to get live local weather from Open-Meteo
local function getLiveWeather()
    local url = 'https://api.open-meteo.com/v1/forecast?latitude=' .. Config.Latitude ..
                '&longitude=' .. Config.Longitude .. '&hourly=weathercode&current_weather=true'
    
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
            changeWeather(newWeather)
        end
    end, 'GET')
end

-- Weather change timer
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.WeatherChangeInterval * 60000)
        if Config.UseLiveWeather then
            getLiveWeather()
        else
            changeWeather(getRandomWeather())
        end
    end
end)

-- Command for admins to change weather
RegisterCommand('setweather', function(source, args, rawCommand)
    if IsPlayerAceAllowed(source, "command.setweather") then
        local newWeather = args[1]:upper()
        if Config.WeatherTypes[newWeather] then
            changeWeather(newWeather)
        else
            TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid weather type!' } })
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'You do not have permission to use this command!' } })
    end
end, false)

-- Exported function to set weather
function SetWeather(weather)
    if Config.WeatherTypes[weather] then
        changeWeather(weather)
    end
end

-- Exported function to get current weather
function GetCurrentWeather()
    return currentWeather
end

exports('SetWeather', SetWeather)
exports('GetCurrentWeather', GetCurrentWeather)
