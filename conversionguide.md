### Guide to Converting from vSync to b2_weatherEssentials

Welcome to the b2_weatherEssentials conversion guide. This guide will help you transition from using vSync to our advanced weather and time synchronization system. We'll cover how to use the exports provided by b2_weatherEssentials and explain why each step is necessary for a smooth transition.

### Why Convert to b2_weatherEssentials?

b2_weatherEssentials offers more flexibility and control over your server's weather and time settings, including:
- Synchronizing weather and time across all players.
- Support for regional weather conditions.
- Integration with real-time weather data.
- Advanced weather events and voting systems.
- Easy to use exports for enabling and disabling synchronization.

### Step-by-Step Conversion Guide

#### 1. Remove vSync References

First, you need to remove all references to vSync from your existing scripts. Look for any `vSync` functions or events and remove them.

#### 2. Enable Weather and Time Synchronization

Replace vSync's weather and time synchronization functions with b2_weatherEssentials exports. This ensures that your server uses b2_weatherEssentials for synchronization.

##### Example: Enabling Weather and Time Sync

**Old vSync Method:**
```lua
TriggerEvent('vSync:toggleWeatherSync', true)
TriggerEvent('vSync:toggleTimeSync', true)
```

**New b2_weatherEssentials Method:**
```lua
exports.b2_weatherEssentials:EnableWeatherSync()
exports.b2_weatherEssentials:EnableTimeSync()
```

#### 3. Setting Weather Conditions

To set weather conditions, use the `SetWeather` export provided by b2_weatherEssentials.

##### Example: Setting Weather

**Old vSync Method:**
```lua
TriggerEvent('vSync:setWeather', 'EXTRASUNNY')
```

**New b2_weatherEssentials Method:**
```lua
exports.b2_weatherEssentials:SetWeather('EXTRASUNNY')
```

If you need to set weather for a specific region, pass the region name as the second argument:

```lua
exports.b2_weatherEssentials:SetWeather('EXTRASUNNY', 'City')
```

#### 4. Getting Current Weather

To get the current weather conditions, use the `GetCurrentWeather` export.

##### Example: Getting Current Weather

**Old vSync Method:**
```lua
local weather = exports['vSync']:getWeather()
```

**New b2_weatherEssentials Method:**
```lua
local weather = exports.b2_weatherEssentials:GetCurrentWeather()
```

For regional weather, pass the region name as an argument:

```lua
local cityWeather = exports.b2_weatherEssentials:GetCurrentWeather('City')
```

#### 5. Controlling Blackouts

b2_weatherEssentials allows you to trigger and clear blackouts using the provided exports.

##### Example: Triggering and Clearing Blackouts

**Old vSync Method:**
```lua
TriggerEvent('vSync:toggleBlackout', true)
TriggerEvent('vSync:toggleBlackout', false)
```

**New b2_weatherEssentials Method:**
```lua
exports.b2_weatherEssentials:TriggerBlackout()
exports.b2_weatherEssentials:ClearBlackout()
```

#### 6. Extreme Weather Events

b2_weatherEssentials supports triggering extreme weather events such as storms, earthquakes, and more.

##### Example: Triggering an Extreme Weather Event

To trigger an extreme weather event, use the `TriggerExtremeEvent` export:

```lua
exports.b2_weatherEssentials:TriggerExtremeEvent('STORM')
```

To clear an extreme weather event, use the `ClearExtremeEvent` export:

```lua
exports.b2_weatherEssentials:ClearExtremeEvent()
```

#### 7. Time Synchronization

To synchronize in-game time with real-world time, ensure `Config.UseRealTime` is set to `true` in the `config.lua` file.

### Summary

By following these steps, you can successfully convert your scripts from vSync to b2_weatherEssentials. The new system provides greater control and flexibility over weather and time synchronization, enhancing the overall experience for players on your server.

For detailed documentation and further customization options, refer to the b2_weatherEssentials documentation or reach out to the support community. Happy scripting!