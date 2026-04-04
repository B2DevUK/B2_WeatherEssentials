-- ===============================================
-- Module: client/cl_nui.lua
-- Description: NUI gateway — panel key bindings,
--              NUI callbacks, season/forecast handlers,
--              and admin-mode initialisation.
-- Depends on: sh_constants, sh_utils, config
-- ===============================================

-- -----------------------------------------------
-- Panel visibility state (module-local)
-- -----------------------------------------------
local playerPanelVisible = false
local adminPanelVisible  = false

-- -----------------------------------------------
-- updateNuiFocus()
-- Grants mouse cursor + NUI focus when any panel is
-- open; releases it when all panels are closed so
-- the player regains normal game input.
-- -----------------------------------------------
local function updateNuiFocus()
    local anyOpen = playerPanelVisible or adminPanelVisible
    SetNuiFocus(anyOpen, anyOpen)
end

-- -----------------------------------------------
-- isAdmin() → boolean
-- Client-side ACE check for the local player.
-- Used only for UI gating; all server actions are
-- re-validated server-side.
-- -----------------------------------------------
local function isAdmin()
    return IsAceAllowed("command.setweather")
end

-- -----------------------------------------------
-- Key binding: toggle player weather panel (F5)
-- -----------------------------------------------
RegisterCommand("b2we_togglePanel", function()
    playerPanelVisible = not playerPanelVisible
    SendNUIMessage({
        action = "showPanel",
        panel  = playerPanelVisible and "player" or "none",
    })
    updateNuiFocus()
end, false)

RegisterKeyMapping(
    "b2we_togglePanel",
    "Toggle Weather Panel",
    "keyboard",
    Config.UI and Config.UI.PlayerPanelKey or "F5"
)

-- -----------------------------------------------
-- Key binding: toggle admin panel (F6)
-- Only opens if the local player passes the ACE check.
-- -----------------------------------------------
RegisterCommand("b2we_toggleAdmin", function()
    B2WE.debugPrint("b2we_toggleAdmin fired — isAdmin=" .. tostring(isAdmin()))
    if not isAdmin() then return end

    adminPanelVisible = not adminPanelVisible
    SendNUIMessage({
        action = "showPanel",
        panel  = adminPanelVisible and "admin" or "none",
    })
    updateNuiFocus()
end, false)

RegisterKeyMapping(
    "b2we_toggleAdmin",
    "Toggle Admin Weather Panel",
    "keyboard",
    Config.UI and Config.UI.AdminPanelKey or "F6"
)

-- -----------------------------------------------
-- NUI callback: closePanel
-- Fired when the user clicks the close button inside
-- the NUI panel.
-- -----------------------------------------------
RegisterNUICallback("closePanel", function(data, cb)
    local panel = data and data.panel or "all"
    if panel == "player" or panel == "all" then
        playerPanelVisible = false
    end
    if panel == "admin" or panel == "all" then
        adminPanelVisible = false
    end
    SendNUIMessage({ action = "showPanel", panel = "none" })
    updateNuiFocus()
    cb({})
end)

-- -----------------------------------------------
-- NUI callback: adminAction
-- Forwards admin panel actions to the server for
-- ACE validation and dispatch.  The server rejects
-- requests from non-admins, so the client does not
-- need to re-check permissions here.
-- -----------------------------------------------
RegisterNUICallback("adminAction", function(data, cb)
    TriggerServerEvent(B2WE.Events.ADMIN_ACTION, data)
    cb({})
end)

-- -----------------------------------------------
-- Event: UPDATE_SEASON
-- Keeps B2WE.currentSeason in sync and updates the
-- NUI display.
-- -----------------------------------------------
AddEventHandler(B2WE.Events.UPDATE_SEASON, function(season)
    B2WE.currentSeason = season
    B2WE.debugPrint("Season updated: " .. tostring(season))
    SendNUIMessage({ action = "updateSeason", season = season })
end)

-- -----------------------------------------------
-- Event: UPDATE_FORECAST
-- Passes the new forecast queue straight through
-- to the NUI player panel.
-- -----------------------------------------------
AddEventHandler(B2WE.Events.UPDATE_FORECAST, function(forecast)
    SendNUIMessage({ action = "updateForecast", forecast = forecast })
end)

-- -----------------------------------------------
-- Resource start: send initial admin-mode flag so
-- the NUI knows whether to render admin controls.
-- -----------------------------------------------
AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    SendNUIMessage({ action = "setAdminMode", isAdmin = isAdmin() })
end)
