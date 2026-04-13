fx_version 'cerulean'
game 'gta5'

author 'B2DevUK | B2 Scripts'
description 'Dynamic Weather System for FiveM'
version '2.1.0'

shared_scripts {
    'shared/sh_constants.lua',
    'shared/sh_utils.lua',
    'config.lua'
}

server_scripts {
    'server/sv_main.lua',
    'server/sv_weather.lua',
    'server/sv_time.lua',
    'server/sv_seasons.lua',
    'server/sv_forecast.lua',
    'server/sv_blackout.lua',
    'server/sv_extreme.lua',
    'server/sv_voting.lua',
    'server/sv_commands.lua',
    'server/sv_exports.lua',
    'server/sv_bridge.lua',
}

client_scripts {
    'client/cl_weather.lua',
    'client/cl_time.lua',
    'client/cl_blackout.lua',
    'client/cl_extreme.lua',
    'client/cl_voting.lua',
    'client/cl_nui.lua',
    'client/cl_sync.lua',
    'client/cl_main.lua',    -- loaded last: dispatches to all of the above
    'client/cl_exports.lua'
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/sounds/*.wav',
    'water.xml',
    'flood_initial.xml'
}

data_file 'WATER_FILE' 'flood_initial.xml'
data_file 'WATER_FILE' 'water.xml'

ui_page 'html/index.html'

provide 'cd_easytime'
provide 'qb-weathersync'
provide 'vSync'

export 'SetWeather'
export 'GetCurrentWeather'
export 'TriggerBlackout'
export 'ClearBlackout'
export 'TriggerExtremeEvent'
export 'ClearExtremeEvent'
export 'EnableWeatherSync'
export 'DisableWeatherSync'
export 'EnableTimeSync'
export 'DisableTimeSync'
export 'GetCurrentExtremeWeather'
export 'GetCurrentSeason'
export 'SetCurrentSeason'
export 'GetForecast'
