fx_version 'cerulean'
game 'gta5'

author 'B2DevUK | B2 Scripts'
description 'Dynamic Weather System for FiveM'
version '1.0.0'

server_script {
    'server.lua'
}

client_script {
    'client.lua'
}

shared_script {
    'config.lua'
}

export 'SetWeather'
export 'GetCurrentWeather'
