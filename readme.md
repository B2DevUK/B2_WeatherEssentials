# b2_weatherEssentials

**Dynamic Weather, Seasons, Extreme Events & More for FiveM**

[![Version](https://img.shields.io/badge/version-2.0.0-blue)](https://github.com/B2DevUK/B2_WeatherEssentials/releases/tag/v2.0.0)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Discord](https://img.shields.io/badge/discord-B2Scripts-7289da)](https://discord.gg/KZRBA6H5kR)

---

## Overview

b2_weatherEssentials is a fully server-authoritative weather and environment system for FiveM. Every client sees the same weather, time, water level, and extreme event state at all times — including players who join mid-session.

V2.0.0 is a complete rewrite with a new modular architecture, seven extreme events, a season system, live weather API support, and a fully redesigned NUI.

---

## Features

- **Regional Weather** — Independent weather zones per configurable region with smooth client-side transitions
- **Season System** — Spring, Summer, Autumn, Winter with per-season probability weights and voting blacklists. Supports `real`, `cycle`, and `manual` modes
- **Extreme Events** — Earthquake, Storm, Extreme Cold, Extreme Heat, Tsunami, Meteor Shower, Hurricane
- **Live Weather** — Optional Open-Meteo API integration; maps real-world WMO codes to GTA weather types automatically
- **Voting System** — Player and admin-triggered weather votes, filtered by season blacklist
- **Forecast Panel** — Displays upcoming weather with ETAs; regenerated on every weather and season change
- **Blackout** — Server-wide blackout with 3-second electrical flicker phase
- **Full-State Sync** — Client-initiated pull on join; no missed events for late-joining players
- **Redesigned NUI** — Player panel (F5) and full-height admin drawer (F6), all ACE-gated server-side
- **Export API** — 14 server-side exports for integration with other resources
- **b2_vehicleEssentials Integration** — Optional per-weather and per-event NPC driving style overrides

---

## Requirements

- FiveM server (game build 2944 or later recommended)
- No database dependency — `oxmysql` is not required

---

## Installation

1. Download the [latest release](https://github.com/B2DevUK/B2_WeatherEssentials/releases/latest)
2. Extract to your server's `resources` folder as `b2_weatherEssentials`
3. Add to `server.cfg`:
   ```
   ensure b2_weatherEssentials
   ```
4. Configure `config.lua` to your preferences
5. Grant ACE permissions:
   ```
   add_ace group.admin command.setweather allow
   add_ace group.admin command.settime allow
   ```

---

## Commands

### Player
| Command | Description |
|---|---|
| `/weathervote [type]` | Vote for a weather type during an active voting session |

### Admin
| Command | Permission | Description |
|---|---|---|
| `/setweather [type] [region?]` | `command.setweather` | Set weather globally or per region |
| `/settime [hours] [minutes?]` | `command.settime` | Set the in-game time |
| `/blackout` | `command.setweather` | Trigger a blackout |
| `/clearblackout` | `command.setweather` | Clear the active blackout |
| `/extremeevent [type]` | `command.setweather` | Trigger an extreme event |
| `/clearextremeevent` | `command.setweather` | Clear the active extreme event |
| `/forcevote` | `command.setweather` | Force-start a weather vote |

---

## Exports

All exports are server-side. Full documentation is available in the [GitBook](YOUR_GITBOOK_URL).

```lua
exports['b2_weatherEssentials']:SetWeather(weather, region?)
exports['b2_weatherEssentials']:GetCurrentWeather(region?)
exports['b2_weatherEssentials']:TriggerBlackout()
exports['b2_weatherEssentials']:ClearBlackout()
exports['b2_weatherEssentials']:TriggerExtremeEvent(event)
exports['b2_weatherEssentials']:ClearExtremeEvent()
exports['b2_weatherEssentials']:GetCurrentExtremeWeather()
exports['b2_weatherEssentials']:EnableWeatherSync()
exports['b2_weatherEssentials']:DisableWeatherSync()
exports['b2_weatherEssentials']:EnableTimeSync()
exports['b2_weatherEssentials']:DisableTimeSync()
exports['b2_weatherEssentials']:GetCurrentSeason()
exports['b2_weatherEssentials']:SetCurrentSeason(season)
exports['b2_weatherEssentials']:GetForecast()
```

---

## Configuration

All options are documented inline in `config.lua`. Key areas:

| Section | Key options |
|---|---|
| Weather | `WeatherChances`, `WeatherChangeInterval`, `WeatherBlacklist` |
| Time | `TimeScale`, `UseRealTime` |
| Live Weather | `UseLiveWeather`, `Latitude`, `Longitude` |
| Regional | `UseRegionalWeather`, `Regions` |
| Seasons | `EnableSeasons`, `SeasonMode`, `SeasonWeights`, `SeasonVotingBlacklist` |
| Extreme Events | `ExtremeEvents`, per-event config blocks |
| Voting | `EnableVotingSystem`, `VotingDuration`, `VotingInterval` |
| UI | `PlayerPanelKey`, `AdminPanelKey`, `AutoShowVotingPanel` |
| Integration | `UsingVehicleEssentials`, `WeatherDrivingStyles`, `ExtremeEventDrivingStyles` |

---

## Links

- 📥 [Download — GitHub Releases](https://github.com/B2DevUK/B2_WeatherEssentials/releases)
- 📖 [Documentation — GitBook](https://b2-scripts.gitbook.io/help/free-product-guides/b2-weather-essentials)
- 🎥 [Preview — YouTube](https://youtu.be/8QLLaxzaoOY)
- 🐛 [Bug Reports — GitHub Issues](https://github.com/B2DevUK/B2_WeatherEssentials/issues)
- 💬 [Discord — B2Scripts](https://discord.gg/KZRBA6H5kR)

---

## Changelog

### 2.0.0
> ⚠️ Breaking changes from V1.x — complete reinstall and re-configuration required.

- Full resource rewrite — new modular architecture
- Added: Regional weather system
- Added: Season system with three modes and per-season weights
- Added: Tsunami extreme event with server-driven water controller
- Added: Hurricane extreme event with `GlobalState` direction sync
- Added: Meteor Shower extreme event
- Added: Live weather via Open-Meteo API
- Added: Weather forecast panel
- Added: Full-state sync on player join (no missed events for late joiners)
- Added: `GetCurrentSeason`, `SetCurrentSeason`, `GetForecast` exports
- Redesigned: NUI — player panel and full-height admin drawer
- Redesigned: Admin panel NUI callback → server ACE re-validation pipeline

### 1.3.5
- Fixed an issue related to clients not syncing correctly

### 1.3.0
- Fixed an issue causing vehicle lights to be affected & version control

### 1.2.0
- Added time scale customization and real-time server clock synchronization

### 1.1.0
- Added regional weather system, extreme weather events & voting system

### 1.0.0
- Initial release

---

## License

[MIT](LICENSE) — B2DevUK | B2 Scripts