fx_version 'cerulean'
game 'gta5'

author 'B2DevUK | B2 Scripts'
description 'Dynamic Weather System for FiveM'
version '1.1.0'

server_script 'server.lua'
client_script 'client.lua'
shared_script 'config.lua'

files {
    'html/index.html',
    'html/sounds/*.wav'
}

ui_page 'html/index.html'

export 'SetWeather'
export 'GetCurrentWeather'
export 'TriggerBlackout'
export 'ClearBlackout'
export 'EnableWeatherSync'
export 'DisableWeatherSync'
export 'EnableTimeSync'
export 'DisableTimeSync'
export 'GetCurrentExtremeWeather'

