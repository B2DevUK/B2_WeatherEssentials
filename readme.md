# b2_weatherEssentials v1.3.0

## Description
b2_weatherEssentials is an advanced, dynamic weather system for FiveM servers. It offers a range of features including regional weather, extreme weather events, blackouts, and a voting system for weather changes. This script enhances the immersion and realism of your FiveM server by providing a diverse and interactive weather experience.

## Version
1.3.0

## Author
B2DevUK | B2 Scripts

## Features
- Dynamic weather changes
- Regional weather system
- Extreme weather events (earthquakes, storms, extreme cold/heat, tsunamis)
- Blackout system
- Weather voting system
- Live weather integration (optional)
- Time & Weather synchronization
- Admin commands for weather and time control
- Integration with b2_vehicleEssentials for weather-based driving styles
- Customizable configuration
- Time scale customization
- Real-time server clock synchronization (optional)

## Installation
1. Download the b2_weatherEssentials script.
2. Place the script in your FiveM server's resources folder.
3. Add `ensure b2_weatherEssentials` to your server.cfg file.
4. Configure the script by editing the `config.lua` file.

## Configuration
The `config.lua` file allows you to customize various aspects of the script:

- Weather types and their chances
- Weather change intervals
- Regional weather settings
- Blackout settings
- Voting system settings
- Extreme event settings
- Time scale settings
- Real-time server clock synchronization
- Debugging options
- And more...

## Usage

### Player Commands
- `/weathervote [WEATHER_TYPE]`: Vote for a weather type during active voting sessions.
- `!WEATHER_TYPE`: Quick vote for a weather type in chat (e.g., !CLEAR, !RAIN).

### Admin Commands
- `/setweather [WEATHER_TYPE] [REGION]`: Set the weather (and optionally for a specific region).
- `/settime [HOURS] [MINUTES]`: Set the server time.
- `/blackout`: Trigger a blackout.
- `/clearblackout`: Clear an active blackout.
- `/extremeevent [EVENT_TYPE]`: Trigger an extreme weather event.
- `/clearextremeevent`: Clear an active extreme weather event.
- `/forcevote`: Force start a weather voting session.

## Exports
The script provides the following exports for integration with other resources:

- `SetWeather(weather, region)`: Set the weather (optionally for a specific region).
- `GetCurrentWeather(region)`: Get the current weather (optionally for a specific region).
- `TriggerBlackout()`: Trigger a blackout.
- `ClearBlackout()`: Clear an active blackout.
- `TriggerExtremeEvent(event)`: Trigger an extreme weather event.
- `ClearExtremeEvent()`: Clear an active extreme weather event.
- `EnableWeatherSync()`: Enable weather synchronization.
- `DisableWeatherSync()`: Disable weather synchronization.
- `EnableTimeSync()`: Enable time synchronization.
- `DisableTimeSync()`: Disable time synchronization.

## Integration
b2_weatherEssentials integrates with b2_vehicleEssentials to adjust NPC driving styles based on weather conditions. Ensure you have b2_vehicleEssentials installed and set `Config.UsingVehicleEssentials = true` in the configuration file.

## Live Weather
To use live weather data, set `Config.UseLiveWeather = true` and provide your latitude and longitude in the configuration file. This feature uses the Open-Meteo API to fetch real-world weather data.

## Time Scale Customization
You can customize how quickly an in-game day passes by setting `Config.TimeScale` in the configuration file. For example, to make a 24-hour in-game period last 60 real-world minutes, set `Config.TimeScale = 60`.

## Real-Time Server Clock Synchronization
To synchronize the in-game time with the real-world time of the server's location, set `Config.UseRealTime = true` in the configuration file.

## Customization
You can customize weather types, chances, intervals, and more in the `config.lua` file. The script also supports custom sounds for various weather events, which can be added to the `html/sounds/` directory.

## Dependencies
- FiveM server
- b2_vehicleEssentials (optional, for enhanced NPC driving behavior)

## Support
For support, join our Discord server: [B2Scripts](https://discord.gg/KZRBA6H5kR)

## License
MIT License

## Changelog
- 1.3.0: Fixed an issue causing vehicle lights to be effected & version control
- 1.2.0: Added time scale customization and real-time server clock synchronization.
- 1.1.0: Added regional weather system, extreme weather events & voting system.
- 1.0.0: Initial release with basic weather