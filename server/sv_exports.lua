-- ===============================================
-- Module: server/sv_exports.lua
-- Description: Wires all export-facing globals to the FiveM exports table.
--              Loaded last — all server modules must be parsed before this.
-- Depends on: all other server modules
-- ===============================================

-- -----------------------------------------------
-- Preserved exports (identical signatures to v1.x)
-- -----------------------------------------------
exports('SetWeather',             SetWeather)
exports('GetCurrentWeather',      GetCurrentWeather)
exports('TriggerBlackout',        TriggerBlackout)
exports('ClearBlackout',          ClearBlackout)
exports('TriggerExtremeEvent',    TriggerExtremeEvent)
exports('ClearExtremeEvent',      ClearExtremeEvent)
exports('EnableWeatherSync',      EnableWeatherSync)
exports('DisableWeatherSync',     DisableWeatherSync)
exports('EnableTimeSync',         EnableTimeSync)
exports('DisableTimeSync',        DisableTimeSync)
exports('GetCurrentExtremeWeather', GetCurrentExtremeWeather)

-- -----------------------------------------------
-- New exports (v2.0)
-- -----------------------------------------------
exports('GetCurrentSeason',  GetCurrentSeason)
exports('SetCurrentSeason',  SetCurrentSeason)
exports('GetForecast',       GetForecast)
