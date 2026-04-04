Config = {}

-- =============================================================================
--  WEATHER
-- =============================================================================

-- Lookup table for all valid weather type strings.
-- Used by the voting system and season weight tables — do not remove entries.
Config.WeatherTypes = {
    CLEAR      = "CLEAR",     EXTRASUNNY = "EXTRASUNNY", CLOUDS    = "CLOUDS",
    OVERCAST   = "OVERCAST",  RAIN       = "RAIN",       CLEARING  = "CLEARING",
    THUNDER    = "THUNDER",   SMOG       = "SMOG",       FOGGY     = "FOGGY",
    XMAS       = "XMAS",      SNOWLIGHT  = "SNOWLIGHT",  BLIZZARD  = "BLIZZARD",
}

-- Base probability weights for random weather selection (values do not need to
-- sum to 100 — they are normalised automatically).
-- NOTE: When EnableSeasons = true these weights are multiplied by the matching
--       SeasonWeights entry before the draw, so treat these as a neutral baseline.
-- NOTE: When UseLiveWeather = true these weights are not used at all; the API
--       result is mapped directly to a weather type.
Config.WeatherChances = {
    CLEAR      = 20, EXTRASUNNY = 15, CLOUDS    = 10, OVERCAST = 10, RAIN     = 10,
    CLEARING   =  5, THUNDER    =  5, SMOG      =  5, FOGGY    =  5, XMAS     =  5,
    SNOWLIGHT  =  5, BLIZZARD   =  5,
}

-- How often the weather changes (minutes).
Config.WeatherChangeInterval = 30

-- =============================================================================
--  TIME
--  ⚠  TimeScale and UseRealTime are mutually exclusive.
--     Set UseRealTime = true to mirror the server's real-world clock.
--     Set UseRealTime = false to use the accelerated in-game clock (TimeScale).
-- =============================================================================

-- Duration of one in-game 24-hour day, expressed in real-world minutes.
-- Only active when UseRealTime = false.
Config.TimeScale = 60

-- Mirror the real-world clock instead of running an accelerated in-game day.
-- When true, TimeScale is ignored.
Config.UseRealTime = false

-- =============================================================================
--  LIVE WEATHER (Open-Meteo API)
--  ⚠  When UseLiveWeather = true:
--       • WeatherChances is bypassed — weather comes from the API response.
--       • SeasonWeights is bypassed — the API already reflects real conditions.
--       • The season system still tracks the current season for UI display and
--         for the fallback random draw (used if the API call fails).
-- =============================================================================

Config.UseLiveWeather = false
Config.Latitude       = "your_latitude"
Config.Longitude      = "your_longitude"

-- =============================================================================
--  REGIONAL WEATHER
-- =============================================================================

-- When true, each region can have independent weather.
Config.UseRegionalWeather = true
Config.Regions = {
    City   = { x =     0, y =    0, radius = 2000 },
    Sandy  = { x =  2000, y = 2000, radius = 1000 },
    Paleto = { x = -3000, y = 3000, radius = 1000 },
}

-- =============================================================================
--  BLACKOUT
-- =============================================================================

Config.BlackoutEnabled = true

-- =============================================================================
--  VOTING
-- =============================================================================

Config.EnableVotingSystem = true
Config.VotingDuration     = 1  -- minutes a vote stays open
Config.VotingInterval     = 30 -- minutes between automatic votes

-- Weather types excluded from votes when EnableSeasons = false (or as a fallback).
-- ⚠  When EnableSeasons = true this list is ignored — SeasonVotingBlacklist
--    (defined in the Seasons section below) takes effect instead, allowing
--    per-season exclusions (e.g. no XMAS in summer).
Config.WeatherBlacklist = { "XMAS", "SNOWLIGHT", "BLIZZARD" }

-- =============================================================================
--  EXTREME EVENTS
-- =============================================================================

-- Enable or disable individual extreme events.
Config.ExtremeEvents = {
    EARTHQUAKE    = true,
    STORM         = true,
    EXTREME_COLD  = true,
    EXTREME_HEAT  = true,
    TSUNAMI       = true,
    METEOR_SHOWER = true,
    HURRICANE     = true,
}

-- =============================================================================
--  EARTHQUAKE
--  Multi-layered effect: camera shake + alternating lateral forces on vehicles
--  and props + random ragdolling for NPCs and the local player.
--  The server publishes parameters via GlobalState so every client runs the
--  same simulation simultaneously.
-- =============================================================================

Config.Earthquake = {
    -- Base lateral impulse applied to vehicles per physics tick (Newtons).
    -- The direction alternates each tick (left → right → left) to simulate
    -- shaking. Recommended range: 500–2000; higher = more violent jolting.
    Force = 1000.0,

    -- Physics ticks per second. Controls how rapidly forces and ragdolls fire.
    -- Tick interval = 1000 / Frequency ms. Recommended range: 2.0–6.0.
    Frequency = 3.0,

    -- Scale applied to Force for standard vehicles (cars, trucks, vans, etc.).
    -- 1.0 = full Force; reduce if vehicles are sliding off roads excessively.
    VehicleForceMultiplier = 1.0,

    -- Separate scale for motorcycles (vehicle class 8) and bicycles (class 13).
    -- Must be much lower than VehicleForceMultiplier — two-wheelers topple
    -- extremely easily and will fly across the map at full force.
    MotorcycleBicycleForceMultiplier = 0.2,

    -- Impulse applied to nearby dynamic physics props per tick (Newtons).
    -- Props are typically much lighter than vehicles; keep this value low.
    PropForce = 50.0,

    -- Maximum distance from the player within which props are affected (metres).
    PropRadius = 50.0,

    -- Probability per tick (0.0–1.0) that the local player stumbles and ragdolls.
    -- Only fires when the player is on foot. 0.01 ≈ 1 % chance per tick.
    PlayerRagdollChance = 0.01,

    -- Probability per tick (0.0–1.0) that each nearby NPC stumbles.
    -- 0.02 ≈ 2 % chance per NPC per tick.
    NpcRagdollChance = 0.02,

    -- Intensity of the ROAD_VIBRATION_SHAKE camera effect (0.0–1.0).
    -- Automatically suppressed when the player is airborne or in water so
    -- they do not feel ground tremors while flying or swimming.
    CameraShakeIntensity = 0.5,
}

-- =============================================================================
--  TSUNAMI
--  The tsunami is a staged flood event controlled entirely by server-side
--  timing so all players see an identical water level at all times.
--
--  Phase flow:
--    1. TRIGGER  — warning chat messages play on all clients.
--    2. WARNING  — server waits WarningDuration seconds before water moves.
--    3. RISE     — water climbs by RiseSpeed metres every TickRate ms until
--                  MaxWaterHeight is reached.
--    4. HOLD     — water stays at peak for PeakHoldDuration seconds.
--    5. DRAIN    — water drops by DrainSpeed metres every TickRate ms back to 0.
--    6. AUTO-CLEAR — event clears itself once fully drained.
--
--  An admin /clearextremeevent or NUI "Clear Active Event" will abort the
--  event immediately and force-reset water to 0 on all clients.
--
--  ⚠  Requires water.xml and flood_initial.xml in your fxmanifest.lua files{}.
--     See those files and the fxmanifest note at the bottom for details.
-- =============================================================================

Config.Tsunami = {
    -- Maximum water level in metres above sea level.
    -- 50–80 floods coastal Los Santos; 150+ submerges most of the map.
    MaxWaterHeight   = 80.0,

    -- Metres added to the water level per tick during the rise phase.
    -- Lower = slower, more dramatic flood. Recommended range: 0.02–0.2.
    RiseSpeed        = 0.05,

    -- Metres removed per tick during the drain phase.
    -- Set higher than RiseSpeed for a quick recede after the peak.
    DrainSpeed       = 0.10,

    -- Milliseconds between each water-height update broadcast.
    -- Lower = smoother animation; higher = less network traffic.
    TickRate         = 100,

    -- Seconds to hold at MaxWaterHeight before draining begins.
    PeakHoldDuration = 60,

    -- Seconds of warning (chat messages, no water movement) before the
    -- rise phase starts. Should be long enough for players to react.
    WarningDuration  = 15,

    -- When true, triggering a tsunami when the resource stops (e.g. on a
    -- planned server restart via `restart b2_weatherEssentials`) will fire
    -- the event as a dramatic restart warning for all connected players.
    -- ⚠  Reliable only for resource restarts; full server shutdowns may not
    --    deliver client events before the process exits.
    TriggerOnResourceStop = false,
}

-- =============================================================================
--  METEOR SHOWER
--  A client-side object spawner — rocks are created high above the player,
--  forced downward with physics velocity, and deleted on impact with a
--  dirt/fire explosion.  No server-side water controller needed; the only
--  server→client data is SpawnInterval so all clients honour the same
--  intensity setting.
--
--  Performance notes:
--   • Each meteor gets one lightweight tracking thread (~10ms sleep).
--   • SpawnInterval controls max live-meteor count indirectly; keep it at
--     least 200ms to avoid saturating the entity budget.
--   • The 8-second failsafe ensures rocks that miss the ground (e.g. fall
--     into the sea) are still deleted.
-- =============================================================================

Config.MeteorShower = {
    -- Milliseconds between each meteor spawn.
    -- 300 = heavy shower; 800 = light shower.
    SpawnInterval = 800,

    -- Horizontal scatter radius around the player (metres).
    -- Larger = wider spread, fewer direct hits.
    SpawnRadius = 80,

    -- How far above the player meteors are created (metres).
    SpawnHeight = 150,

    -- Downward Z velocity applied at spawn (negative = down).
    -- -100 is dramatic and trackable; -500 outruns collision detection.
    FallSpeed = -100.0,

    -- Random lateral drift range (metres/s). Set to 0 for perfectly vertical.
    LateralDrift = 15,

    -- Explosion type on impact.
    -- 29 = dirt/debris; 5 = large; 0 = grenade. See FiveM explosion list.
    ExplosionType = 29,

    -- Explosion damage radius.
    ExplosionRadius = 8.0,

    -- Seconds before a meteor is force-deleted (failsafe for sea/roof impacts).
    Timeout = 8,

    -- GTA V prop used for meteors.
    Model = "prop_test_boulder_04",
}

-- =============================================================================
--  HURRICANE
--  A directional wind event — no vortex, no eye position. The server
--  publishes a force scalar and a random XY unit vector via GlobalState;
--  clients apply that vector as wind natives and as per-entity physics
--  forces so all players experience an identical hurricane simultaneously.
--
--  Phase flow:
--    1. TRIGGER  — GlobalState.hurricane set; all clients activate instantly
--                  via AddStateBagChangeHandler, including late joiners.
--    2. SHIFT    — server re-randomises direction every DirectionShiftMin–
--                  DirectionShiftMax seconds; clients update wind and forces
--                  automatically on the next state-bag fire.
--    3. CLEAR    — admin command or export nils GlobalState.hurricane;
--                  clients reset wind speed, weather, and stop both threads.
--
--  Client threads:
--    Cache   (~1000ms) — scans CVehicle/CPed pools, filters by PullRadius
--                        and GetInteriorFromEntity so only outdoor entities
--                        within range are pushed.
--    Physics (~50ms)   — applies directional force to cached vehicles
--                        (scaled by current speed) and randomly ragdolls
--                        cached peds, sliding them along the ground while down.
-- =============================================================================
Config.Hurricane = {
    Force             = 3.0,     -- force scalar stored in GlobalState
    WindSpeed         = 90.0,   -- passed to SetWindSpeed
    WeatherType       = "THUNDER",
    PullRadius        = 100.0,   -- entity cache radius from player (metres)
    DirectionShiftMin = 10,      -- seconds between wind direction shifts
    DirectionShiftMax = 30,
    VehicleForce      = 200.0,  -- base Newtons applied per 50ms tick
    VehicleSpeedScale = 0.15,    -- extra force per m/s of vehicle speed
    PedRagdollChance  = 0.01,    -- probability per tick a cached ped ragdolls
    PedSlideForce     = 350.0,    -- directional push applied while ped is ragdolled
}

-- =============================================================================
--  VEHICLE ESSENTIALS INTEGRATION  (b2_vehicleEssentials)
--  ⚠  WeatherDrivingStyles and ExtremeEventDrivingStyles are only applied
--     when UsingVehicleEssentials = true. If you do not have the resource,
--     leave this false — the tables below are ignored entirely.
-- =============================================================================

Config.UsingVehicleEssentials = false

-- NPC driving-style flags applied per weather type.
Config.WeatherDrivingStyles = {
    CLEAR      = 786603,        -- Normal
    EXTRASUNNY = 786603,        -- Normal
    CLOUDS     = 786603,        -- Normal
    OVERCAST   = 1074528293,    -- Cautious
    RAIN       = 536871299,     -- Very careful
    CLEARING   = 1074528293,    -- Cautious
    THUNDER    = 536871299,     -- Very careful
    SMOG       = 1074528293,    -- Cautious
    FOGGY      = 536871299,     -- Very careful
    XMAS       = 536871299,     -- Very careful
    SNOWLIGHT  = 536871299,     -- Very careful
    BLIZZARD   = 536871299,     -- Very careful
}

-- NPC driving-style flags applied during active extreme events.
Config.ExtremeEventDrivingStyles = {
    EARTHQUAKE    = 536871299,   -- Very careful
    STORM         = 536871299,   -- Very careful
    EXTREME_COLD  = 536871299,   -- Very careful
    EXTREME_HEAT  = 1074528293,  -- Cautious
    TSUNAMI       = 536871299,   -- Very careful
    METEOR_SHOWER = 536871299,   -- Very careful
    HURRICANE     = 536871299,   -- Very careful
}

-- =============================================================================
--  SEASONS
-- =============================================================================

Config.EnableSeasons = true

-- How the current season is determined:
--   "real"   — derived from the real-world calendar month on the server.
--   "cycle"  — rotates automatically every SeasonCycleDays in-game days.
--   "manual" — only changed via the SetCurrentSeason export or admin panel.
Config.SeasonMode = "real"

-- Number of in-game days per season. Only used when SeasonMode = "cycle".
Config.SeasonCycleDays = 7

-- Per-season multipliers applied on top of Config.WeatherChances.
-- A value of 0.0 prevents that weather type from occurring in that season.
Config.SeasonWeights = {
    SPRING = {
        CLEAR=1.4, EXTRASUNNY=1.0, CLOUDS=1.2, OVERCAST=1.2, RAIN=1.3,  CLEARING=1.5,
        THUNDER=1.0, SMOG=0.8, FOGGY=1.0, XMAS=0.0, SNOWLIGHT=0.0, BLIZZARD=0.0,
    },
    SUMMER = {
        CLEAR=2.0, EXTRASUNNY=2.5, CLOUDS=0.8, OVERCAST=0.6, RAIN=0.7,  CLEARING=1.0,
        THUNDER=0.8, SMOG=1.2, FOGGY=0.4, XMAS=0.0, SNOWLIGHT=0.0, BLIZZARD=0.0,
    },
    AUTUMN = {
        CLEAR=0.9, EXTRASUNNY=0.6, CLOUDS=1.4, OVERCAST=1.8, RAIN=1.6,  CLEARING=1.2,
        THUNDER=1.2, SMOG=1.0, FOGGY=1.5, XMAS=0.0, SNOWLIGHT=0.3, BLIZZARD=0.1,
    },
    WINTER = {
        CLEAR=0.7, EXTRASUNNY=0.5, CLOUDS=1.0, OVERCAST=1.2, RAIN=0.8,  CLEARING=0.6,
        THUNDER=0.5, SMOG=0.8, FOGGY=1.2, XMAS=2.0, SNOWLIGHT=2.5, BLIZZARD=2.0,
    },
}

-- Weather types excluded from votes per season.
Config.SeasonVotingBlacklist = {
    SPRING = { "XMAS", "SNOWLIGHT", "BLIZZARD" },
    SUMMER = { "XMAS", "SNOWLIGHT", "BLIZZARD" },
    AUTUMN = { "XMAS" },
    WINTER = {},
}

-- =============================================================================
--  FORECAST
-- =============================================================================

Config.EnableForecast = true
Config.ForecastSteps  = 3  -- number of upcoming weather steps to display

-- =============================================================================
--  UI  (keybinds and panel behaviour)
-- =============================================================================

Config.UI = {
    PlayerPanelKey      = "F5",   -- Toggle weather/forecast panel (all players)
    AdminPanelKey       = "F6",   -- Toggle admin drawer (ACE-permitted players only)
    AutoShowVotingPanel = true,   -- Auto-open player panel when a vote starts
}

-- =============================================================================
--  DEBUG
-- =============================================================================

Config.Debugging = false