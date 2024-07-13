local currentWeather = "CLEAR"

RegisterNetEvent('updateWeather')
AddEventHandler('updateWeather', function(newWeather)
    currentWeather = newWeather
    SetWeatherTypeOverTime(newWeather, 15.0)
    SetWeatherTypePersist(newWeather)
    SetWeatherTypeNow(newWeather)
    SetWeatherTypeNowPersist(newWeather)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)
        SetWeatherTypePersist(currentWeather)
        SetWeatherTypeNowPersist(currentWeather)
    end
end)
