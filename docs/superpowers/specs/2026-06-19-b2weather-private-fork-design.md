# b2weather — Private Suite Fork · Design / Handoff Spec

**Date:** 2026-06-19
**Source:** `B2_WeatherEssentials` (public product, v2.1.0). **Target:** `b2weather` (private B2-suite resource). Namespace `B2WE`.
**Status:** Design approved, not built. Self-contained for a fresh implementation chat.

> Apply `b2-fivem-standards` (Lua), `b2-nui-style` (admin dashboard + the app UIs), `b2-integration-docs` (the `b2weather_reference.md` this owes once built). Present-state comments, EmmyLua on the public surface.

> **Scope:** fork the released product into the suite — **rebrand + standards pass + NUI rewrite + player lb-phone/lb-tablet app + suite integration**. Preserve the proven engine (weather/seasons/extreme events/live weather/forecast/blackout/voting/full-state sync). Do **not** regress any existing feature.

---

## 1. What this is

`B2_WeatherEssentials` is B2DevUK's publicly-released weather resource (server-authoritative weather, regional zones, 4 seasons, 7 extreme events, Open-Meteo live weather, forecast, blackout, voting, full-state join sync). It's already **React + esbuild** (`src/app.jsx` → `html/app.js`, two roots: `#player-root` F5, `#admin-root` F6), no DB, 14 server exports.

The private fork brings it into Project INDIGO: rebrands it suite-native, aligns it to B2 standards, **rewrites the UI** (kills the runtime Tailwind/font CDNs), replaces the player panel with a **phone/tablet app**, replaces the admin drawer with a **new B2-style dashboard**, and **wires weather into the suite** as a systemic input.

## 2. Decisions locked (this session)

- **Rebrand suite-native.** Folder `b2weather`, namespace `B2WE`, `exports.b2weather:*`. The public product diverges from here (upstream fixes ported by hand).
- **Players → lb-phone + lb-tablet app** (retire the F5 player panel). **Player-only** content: current weather, forecast (ETAs), season, cast a vote.
- **Admins → a new B2-style dashboard NUI** (replace the F6 drawer outright — a fresh dashboard, not a restyle). ACE-gated, command-opened.
- **Wire into the suite:** b2vehicles driving styles (native, b2vehicles API optional), b2status cold/heat exposure (via `RegisterDrainModifier` + b2health, no new stat), clean weather/season read for b2drugs grow-sim.
- **Kill runtime CDNs.** Drop `cdn.tailwindcss.com` + Google Fonts CDN; b2-nui-style tokens + self-hosted woff2 (the suite-wide CEF-liability fix).
- Deliverable: handoff spec.

## 3. Rebrand & standards pass (preserve the engine)

The engine logic is good — **port it, don't rewrite it.** This is a rename + namespace + standards alignment, keeping behaviour identical.

- **Folder/resource:** `B2_WeatherEssentials` → `b2weather`. Update `fxmanifest.lua` (`name`/manifest), keep `provide 'cd_easytime' / 'qb-weathersync' / 'vSync'` (drop-in compatibility for other weather consumers is still wanted).
- **Namespace:** introduce `B2WE` properly per standards — bare globals (`SetWeather`, `GetCurrentWeather`, …) become `B2WE.setWeather` internal + PascalCase export wrappers in `sv_exports.lua`. `B2WE = B2WE or {}` init-guarded in `sh_constants.lua`/`sh_utils.lua` only.
- **Exports:** keep the **same 14 export names** but under the new path: `exports.b2weather:SetWeather(...)`, `GetCurrentWeather`, `TriggerBlackout`, `ClearBlackout`, `TriggerExtremeEvent`, `ClearExtremeEvent`, `EnableWeatherSync`, `DisableWeatherSync`, `EnableTimeSync`, `DisableTimeSync`, `GetCurrentExtremeWeather`, `GetCurrentSeason`, `SetCurrentSeason`, `GetForecast`. Add the new ones in §6.
- **Consumer repoint:** grep the suite for `b2_weatherEssentials` and repoint every hit to `b2weather` (the only candidate, `b2properties/client/cl_main.lua`, appears incidental — verify and fix if real). Update `server.cfg`: `ensure b2weather` (after b2core/b2ui; before consumers that read weather).
- **Commands preserved:** `/weathervote` (player), `/setweather`, `/settime`, `/blackout`, `/clearblackout`, `/extremeevent`, `/clearextremeevent`, `/forcevote` (admin, ACE). Keep the ACE names or migrate to `b2weather.admin` ACE — pick one and document; ACE check is the first line of every admin command + re-validated on every admin net event.
- **Config preserved:** keep `config.lua` structure/keys (WeatherChances, Regions, SeasonWeights, ExtremeEvents, Voting, live-weather lat/long, driving-style maps). Drop only the `UsingVehicleEssentials` external toggle (§5.1). Comments → B2 present-state standard.
- **Logging/feedback:** route debug through `B2WE.debugPrint`; player-facing feedback through b2ui (`Notify`/`NotifyPlayer`), `£`-free domain so no currency concerns.

## 4. NUI rewrite

Kill the CDNs first: remove `<script src="https://cdn.tailwindcss.com">` and the Google Fonts `<link>`; self-host the fonts as woff2 under `html/fonts/` with `@font-face` paths relative to the **output** `app.css` (the esbuild font-path gotcha). Rebuild styling on b2-nui-style tokens (dark glass, gold accent, 1px borders, `clamp()` type, no `backdrop-filter`).

### 4.1 Admin dashboard NUI (replaces the F6 drawer)
A fresh B2-style **admin dashboard** (React/esbuild, b2-nui-style), opened by `/weatheradmin` (ACE `b2weather.admin`; optional keybind). Not a restyle of the old drawer — a redesigned control surface. Sections mirror the full control set, every action an ACE-revalidated server callback:
- **Weather** — set per region (region picker when `UseRegionalWeather`), current-state readout, transitions.
- **Time** — set hour/minute, time-scale, real-time toggle.
- **Season** — mode (real/cycle/manual) + manual set + weights readout.
- **Extreme events** — trigger/clear each of the 7 (Earthquake, Storm, Extreme Cold, Extreme Heat, Tsunami, Meteor Shower, Hurricane).
- **Blackout** — trigger/clear.
- **Voting** — force-start a vote, live tally readout.
- **Live weather** — Open-Meteo on/off, lat/long, current mapped WMO code.
- **Sync** — weather/time sync enable/disable.
- **Exposure** — read/tune the new environmental-exposure level (§5.2).

NUI callback contract: `cb({})` first line; gated behind an "is open" flag; admin strings validated against a known registry before relay; never relay a raw NUI string into an event without validation. Single source of truth for action strings in `B2WE.NuiActions`, mirrored in the bundle.

### 4.2 Retire the F5 player panel
The `#player-root` panel is removed — all player-facing weather/forecast/season/voting moves to the app (§5). `html/index.html` keeps only the admin root.

## 5. Player app (lb-phone + lb-tablet)

A **player-only** app on both devices, built on the **b2financial app pattern** (React/esbuild from mockups over a `sv_app` snapshot/action bridge — see `project_b2financial_bills_and_apps`). Server pushes a state snapshot; the app sends actions back; no business logic in the NUI.

- **Surfaces:**
  - **Now** — current weather (icon + label), temperature/exposure hint, region (if regional), time/season.
  - **Forecast** — upcoming weather with ETAs (the existing forecast model; regenerated on weather/season change).
  - **Season** — current season + mode.
  - **Vote** — during an active voting session, list the season-filtered weather options and cast a vote (`/weathervote` equivalent via an app action). Outside a session, show "no active vote".
- **Bridge:** `b2weather/server/sv_app.lua` builds the per-player snapshot and handles app actions (vote), reusing the existing voting/forecast/season state. Push on app open, on weather/season/extreme change, and on vote start/end.
- **lb-device gotchas (project memory `reference_lb_device_app_gotchas`):** icon field = **relative path**, not `nui://` (host prepends `cfx-nui-`); `SendCustomAppMessage` only works if the app was created at runtime via `AddCustomApp` (not static `Config.CustomApps`); don't `#root{height:100%}` on lb-phone (collapses → blank; use `100vw/vh`); lb-tablet needs ~44px top status-bar buffer.
- **Build:** esbuild bundles per device (`src/app_phone.jsx` / `src/app_tablet.jsx` → device `html/`), self-hosted fonts, b2-nui-style. Bundles committed.

## 6. Suite integration (weather as a systemic input)

### 6.1 b2vehicles — NPC driving styles
The old build delegated driving-style overrides to the external `b2_vehicleEssentials` (the `UsingVehicleEssentials` flag). **b2vehicles exposes no driving-style API** (verified — no such export), so b2weather **applies the overrides itself natively**, client-side, from `Config.WeatherDrivingStyles` / `Config.ExtremeEventDrivingStyles` (set on the current weather/event). The external dependency and toggle are removed.
- *Optional (flagged):* if a central driving-style authority is later wanted, add a `SetTrafficDrivingStyle`/`SetNpcDrivingProfile` export to b2vehicles and have b2weather call it instead. Not required for this fork.

### 6.2 b2status / b2health — cold/heat exposure
b2status has **no temperature stat** today. Rather than add one, b2weather owns an **environmental exposure model** and drives effects through existing hooks:
- Compute an **exposure level** each weather/season/event change: e.g. Extreme Cold / Winter / storms → cold severity; Extreme Heat / Summer → heat severity (config-tunable bands, region-aware). Expose `exports.b2weather:GetEnvironmentExposure()` → `{ kind = "cold"|"heat"|"none", severity = 0..100 }`.
- Apply via `exports.b2status:RegisterDrainModifier(id, "b2weather", expName)` so severe cold/heat **modifies hunger/thirst/stamina drain** (b2weather provides the modifier export b2status calls). Severe exposure damage routes through **b2health** (HP tick), config-gated, all `pcall`'d.
- Mitigation hooks (clothing/shelter/indoors) read as config-tunable reductions; being inside a b2properties interior zeroes exposure. *(A dedicated `temperature` stat in b2status is an optional follow-up on the b2status side — not built here.)*

### 6.3 b2drugs — grow-sim read
b2drugs' grow simulation can modify outdoor grow rate by weather/season. b2weather just guarantees a **clean, cheap read** (`GetCurrentWeather` / `GetCurrentSeason` / `GetForecast`, already exported, now under `b2weather`) and fires change events consumers can cache off (never poll-in-tick — push pattern). The actual grow-rate consumption is a **b2drugs-side** change (flagged follow-up), not built here.

> Integration golden rule (b2-fivem-standards): consumers cache the weather/season on a **push event**, never call the export inside a tick/poll. b2weather fires `B2WE.Events.WEATHER_CHANGED` / `SEASON_CHANGED` / `EXTREME_CHANGED` (server, relayed to clients) for exactly this.

## 7. Preserved feature set (regression guard)

Must survive the fork unchanged in behaviour: regional weather + smooth transitions; 4 seasons (real/cycle/manual) + weights + voting blacklist; the 7 extreme events (incl. Tsunami water controller, Hurricane GlobalState direction, Meteor Shower); Open-Meteo live weather (WMO→GTA mapping); forecast panel data; blackout (3s flicker); voting (player + admin, season-filtered); full-state pull on join; the `provide` shims. The water `data_file`s (`flood_initial.xml` / `water.xml`) carry over.

## 8. New exports / events

- `exports.b2weather:GetEnvironmentExposure()` → `{ kind, severity }`.
- `B2WE.Events` (server, in `b2weather_sv_shared.lua`, pure data): `WEATHER_CHANGED { weather, region }`, `SEASON_CHANGED { season }`, `EXTREME_CHANGED { event|nil }`, `BLACKOUT_CHANGED { active }`, `VOTE_STARTED` / `VOTE_ENDED { winner }`. Relayed to clients for cache-on-push consumers.

## 9. Build phases

1. **P1 — Fork + rebrand + standards.** Copy to `b2weather`; rename manifest/namespace (`B2WE`), wrap exports under `exports.b2weather` (same 14 names), keep `provide` shims + commands + config; repoint suite consumers + `server.cfg`; comment/standards pass. *Verifiable: `ensure b2weather` clean; every old export works under the new path; weather/season/events behave identically; no consumer breakage.*
2. **P2 — NUI rewrite.** Kill Tailwind/font CDNs + self-host fonts; build the new admin dashboard NUI (all control sections, ACE-revalidated); retire the F5 player root. *Verifiable: admin dashboard drives every weather/time/season/event/blackout/vote/live/sync control; no runtime CDN requests; focus/camera released on close.*
3. **P3 — Player app (lb-phone + lb-tablet).** `sv_app` snapshot/action bridge; Now/Forecast/Season/Vote surfaces on both devices; runtime `AddCustomApp` registration; push on state change. *Verifiable: app shows live weather/forecast/season on phone + tablet; a vote cast from the app counts; icons resolve (no doubled cfx-nui 404).*
4. **P4 — Suite integration.** Native b2vehicles driving styles (drop external dep); `GetEnvironmentExposure` + b2status `RegisterDrainModifier` + b2health exposure damage (config-gated, pcall'd); change-events for b2drugs. *Verifiable: extreme cold modifies status drain + (severe) ticks HP; interiors zero exposure; b2drugs/others can cache weather off the change event.*

Commit per phase.

## 10. Verification

- No runtime CDN (DevTools/headless network shows zero `cdn.tailwindcss.com` / `fonts.googleapis.com`).
- All 14 legacy exports resolve under `exports.b2weather`; `provide` shims still satisfy weather consumers.
- Admin dashboard: every section actuates + reflects live state; ACE enforced server-side on every action.
- App: phone + tablet show live data; voting round-trips; lb-device gotchas clear.
- Integration: exposure modifies b2status drain + b2health under severe events, zeroed indoors; driving styles apply without `b2_vehicleEssentials`; change-events fire for consumers.
- Regression: regional/seasons/7 events/live/forecast/blackout/voting/join-sync all intact.

## 11. Out of scope

A dedicated `temperature` stat in b2status (optional follow-up). b2drugs grow-rate consumption of weather (b2drugs-side). A b2vehicles central driving-style API (optional). Admin controls inside the player app (admin lives in the dashboard). New extreme events / weather types. Keeping the public product in lockstep (this is a hard fork).

## 12. Assumptions (defaulted — change freely)

- Folder `b2weather`, namespace `B2WE`, `exports.b2weather:*`; export **names** unchanged for an easy consumer repoint. `provide` shims retained.
- Admin = command-opened dashboard (`/weatheradmin`, ACE `b2weather.admin`); player = device app only. No F5/F6 keybind panels survive (a keybind to open the app/dashboard is fine).
- Exposure is a b2weather-owned model surfaced via `GetEnvironmentExposure` + a b2status drain modifier + b2health damage; b2status gains no new stat.
- Driving styles are applied natively by b2weather (no external vehicle resource).
- App stack = b2financial app pattern (sv_app snapshot/action bridge, React/esbuild, runtime `AddCustomApp`) on lb-phone + lb-tablet.
