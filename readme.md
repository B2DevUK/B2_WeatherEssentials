# B2 Weather Essentials for FiveM

## Description
B2 Weather Essentials is a dynamic weather system for FiveM that allows for synchronized weather changes across all players on the server. The system includes various weather options, chances of each weather type happening, intervals for weather changes, admin commands to manually change the weather, and an option to sync in-game weather with real-world weather using the Open-Meteo API.

## Features
- **Weather Options**: Supports all possible FiveM weather types.
- **Weather Chances**: Configurable chances for each weather type.
- **Intervals of Weather Changes**: Configurable intervals for automatic weather changes.
- **Admin Commands**: Commands for admins to manually change the weather.
- **Live Local Weather**: Syncs in-game weather with real-world weather using the Open-Meteo API.

## Installation
1. **Clone the repository** or **download the files** and place them in your FiveM server resources folder.
2. **Add the resource** to your `server.cfg`:
    ```plaintext
    ensure b2_weatherEssentials
    ```

## Configuration
Modify the `config.lua` file to set up the weather types, chances, intervals, and API settings.

### `config.lua`
```lua
Config = {}

-- Define all possible weather types
Config.WeatherTypes = {
    "CLEAR", "EXTRASUNNY", "CLOUDS", "OVERCAST", "RAIN", "CLEARING",
    "THUNDER", "SMOG", "FOGGY", "XMAS", "SNOWLIGHT", "BLIZZARD"
}

-- Define chances for each weather type (sum should be 100)
Config.WeatherChances = {
    CLEAR = 20, EXTRASUNNY = 15, CLOUDS = 10, OVERCAST = 10, RAIN = 10,
    CLEARING = 5, THUNDER = 5, SMOG = 5, FOGGY = 5, XMAS = 5, SNOWLIGHT = 5, BLIZZARD = 5
}

-- Define interval for weather changes (in minutes)
Config.WeatherChangeInterval = 30

-- Live local weather API
Config.UseLiveWeather = true
Config.Latitude = "your_latitude"
Config.Longitude = "your_longitude"
```
Replace `your_latitude` and `your_longitude` with the actual coordinates of the location where your server is based.

## Commands
### Admin Commands
- **`/setweather [weather]`**: Manually sets the weather to the specified type.
    - Example: `/setweather CLEAR`
    - Requires the user to have the `command.setweather` ACE permission.

## API Exports
The dynamic weather system includes API exports that allow other scripts to change the weather and get the current active weather.

### `SetWeather(weather)`
- **Description**: Sets the weather to the specified type.
- **Parameter**: `weather` - A string representing the weather type (must be one of the defined weather types in `Config.WeatherTypes`).
- **Usage**:
    ```lua
    exports['b2_weatherEssentials']:SetWeather('RAIN')
    ```

### `GetCurrentWeather()`
- **Description**: Gets the currently active weather.
- **Returns**: A string representing the current weather type.
- **Usage**:
    ```lua
    local currentWeather = exports['b2_weatherEssentials']:GetCurrentWeather()
    print("Current Weather: " .. currentWeather)
    ```

## Example Usage
### Setting Weather from Another Script
```lua
-- Example script to set the weather to THUNDER
Citizen.CreateThread(function()
    Wait(10000) -- Wait for 10 seconds
    exports['b2_weatherEssentials']:SetWeather('THUNDER')
end)
```

### Getting Current Weather from Another Script
```lua
-- Example script to print the current weather to the console
Citizen.CreateThread(function()
    Wait(10000) -- Wait for 10 seconds
    local currentWeather = exports['b2_weatherEssentials']:GetCurrentWeather()
    print("Current Weather: " .. currentWeather)
end)
```

## License
This project is licensed under the MIT License. See the `LICENSE` file for details.

## Credits
Created by B2DevUK | B2 Scripts. Contributions and improvements are welcome.

## Support Discord: discord.gg/KZRBA6H5kR
