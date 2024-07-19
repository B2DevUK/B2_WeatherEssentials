Config = {}

-- Define all possible weather types
Config.WeatherTypes = {
    CLEAR = "CLEAR", EXTRASUNNY = "EXTRASUNNY", CLOUDS = "CLOUDS", OVERCAST = "OVERCAST",
    RAIN = "RAIN", CLEARING = "CLEARING", THUNDER = "THUNDER", SMOG = "SMOG",
    FOGGY = "FOGGY", XMAS = "XMAS", SNOWLIGHT = "SNOWLIGHT", BLIZZARD = "BLIZZARD"
}

-- Define chances for each weather type (sum should be 100)
Config.WeatherChances = {
    CLEAR = 20, EXTRASUNNY = 15, CLOUDS = 10, OVERCAST = 10, RAIN = 10,
    CLEARING = 5, THUNDER = 5, SMOG = 5, FOGGY = 5, XMAS = 5, SNOWLIGHT = 5, BLIZZARD = 5
}

-- Define interval for weather changes (in minutes)
Config.WeatherChangeInterval = 30

-- Timescale settings
Config.TimeScale = 60 -- Ingame 24-hour period duration in real-world minutes
-- OR
Config.UseRealTime = false

-- Live local weather API
Config.UseLiveWeather = false
Config.Latitude = "your_latitude"
Config.Longitude = "your_longitude"

-- Blackout configuration
Config.BlackoutEnabled = true

-- Optional: Different weather for different regions
Config.UseRegionalWeather = true
Config.Regions = {
    City = {x = 0, y = 0, radius = 2000},  -- Define center and radius for the city
    Sandy = {x = 2000, y = 2000, radius = 1000},  -- Define center and radius for Sandy Shores
    Paleto = {x = -3000, y = 3000, radius = 1000}  -- Define center and radius for Paleto Bay
}

-- Tsunami for server restart
Config.TsunamiForRestart = true

-- Voting system configuration
Config.EnableVotingSystem = true
Config.VotingDuration = 1 -- in minutes
Config.VotingInterval = 30 -- in minutes
Config.WeatherBlacklist = {"XMAS", "SNOWLIGHT", "BLIZZARD"} -- Weather types not allowed in voting

-- Define extreme events
Config.ExtremeEvents = {
    EARTHQUAKE = true,
    STORM = true,
    EXTREME_COLD = true,
    EXTREME_HEAT = true,
    TSUNAMI = true
}

Config.UsingVehicleEssentials = false  -- Set this to false if not using the b2_vehicleEssentials script

Config.WeatherDrivingStyles = {
    CLEAR = 786603,        -- Normal driving
    EXTRASUNNY = 786603,   -- Normal driving
    CLOUDS = 786603,       -- Normal driving
    OVERCAST = 1074528293, -- More cautious
    RAIN = 536871299,      -- Very careful, stops a lot
    CLEARING = 1074528293, -- More cautious
    THUNDER = 536871299,   -- Very careful, stops a lot
    SMOG = 1074528293,     -- More cautious
    FOGGY = 536871299,     -- Very careful, stops a lot
    XMAS = 536871299,      -- Very careful, stops a lot
    SNOWLIGHT = 536871299, -- Very careful, stops a lot
    BLIZZARD = 536871299   -- Very careful, stops a lot
}

Config.ExtremeEventDrivingStyles = {
    EARTHQUAKE = 536871299,    -- Very careful, stops a lot
    STORM = 536871299,         -- Very careful, stops a lot
    EXTREME_COLD = 536871299,  -- Very careful, stops a lot
    EXTREME_HEAT = 1074528293, -- More cautious
    TSUNAMI = 536871299        -- Very careful, stops a lot
}

-- Debugging configuration
Config.Debugging = true
