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
