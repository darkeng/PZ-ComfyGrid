--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.5
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Core/Prefs"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Compat = ComfyGrid.Compat or {}
local Warnings = {}
ComfyGrid.Compat.Warnings = Warnings

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text

local INCOMPATIBLE = {
    {
        id = "INVENTORY_TETRIS",
        key = "IGUI_ComfyGrid_IncompatibleTetris",
        text = "Comfy Grid: Inventory Tetris is enabled. Both replace the "
            .. "inventory UI - disable one.",
    },
    {
        id = "CleanUI",
        key = "IGUI_ComfyGrid_IncompatibleCleanUI",
        text = "Comfy Grid: CleanUI is enabled. Both replace the inventory UI "
            .. "- disable one.",
    },
}

local function isModActive(modId)
    if type(getActivatedMods) ~= "function" then return false end
    local ok, mods = pcall(getActivatedMods)
    if not ok or mods == nil then return false end
    local okPlain, foundPlain = pcall(mods.contains, mods, modId)
    if okPlain and foundPlain then return true end
    local okSlashed, foundSlashed = pcall(mods.contains, mods, "\\" .. modId)
    return okSlashed and foundSlashed or false
end

local function warningText(entry)
    return Text.tr(entry.key, entry.text)
end

local function showWarning(msg)
    local Confirm = ComfyGrid.UI and ComfyGrid.UI.Chrome
        and ComfyGrid.UI.Chrome.Confirm
    if Confirm ~= nil and Confirm.open ~= nil then
        local ok, err = pcall(Confirm.open, { text = msg, yesno = false })
        if not ok then
            Log.error("Warnings: dialog failed: " .. tostring(err))
        end
    end
end

function Warnings.check()
    for i = 1, #INCOMPATIBLE do
        local entry = INCOMPATIBLE[i]
        if isModActive(entry.id) then
            Log.warn("incompatible mod active: " .. entry.id)
            showWarning(warningText(entry))
            return true
        end
    end
    return false
end

local HOTBAR_WARNED_KEY = "hotbarSharedWarned"

function Warnings.hotbarShared()
    if ComfyGrid._hotbarSharedWarned then return end
    ComfyGrid._hotbarSharedWarned = true
    local Prefs = ComfyGrid.Core.Prefs
    if Prefs ~= nil and Prefs.get ~= nil then
        if Prefs.get(HOTBAR_WARNED_KEY) == "1" then return end
        Prefs.set(HOTBAR_WARNED_KEY, "1")
    end
    Log.warn("another mod sizes the hotbar too: it may blink")
    showWarning(Text.tr("IGUI_ComfyGrid_HotbarShared",
        "Comfy Grid: another mod also restyles the hotbar, so it may blink. To "
            .. "keep the other mod's hotbar, turn off “Restyle the on-screen hotbar” "
            .. "in Comfy Grid settings."))
end

if not ComfyGrid._compatWarningsHooked then
    ComfyGrid._compatWarningsHooked = true
    Events.OnGameStart.Add(function()
        local warningsModule = ComfyGrid.Compat and ComfyGrid.Compat.Warnings
        if warningsModule ~= nil then
            pcall(warningsModule.check)
        end
    end)
end
