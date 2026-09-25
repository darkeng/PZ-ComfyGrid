--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.9
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
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
    local ok2, found = pcall(mods.contains, mods, modId)
    if ok2 and found then return true end
    local ok3, found2 = pcall(mods.contains, mods, "\\" .. modId)
    return ok3 and found2 or false
end

local function warningText(entry)
    return Text.tr(entry.key, entry.text)
end

function Warnings.check()
    for i = 1, #INCOMPATIBLE do
        local entry = INCOMPATIBLE[i]
        if isModActive(entry.id) then
            local msg = warningText(entry)
            Log.warn("incompatible mod active: " .. entry.id)

            local Confirm = ComfyGrid.UI and ComfyGrid.UI.Chrome
                and ComfyGrid.UI.Chrome.Confirm
            if Confirm ~= nil and Confirm.open ~= nil then
                local ok, err = pcall(Confirm.open,
                    { text = msg, yesno = false })
                if not ok then
                    Log.error("Warnings: dialog failed: " .. tostring(err))
                end
            end
            return true
        end
    end
    return false
end

if not ComfyGrid._compatWarningsHooked then
    ComfyGrid._compatWarningsHooked = true
    Events.OnGameStart.Add(function()
        local dd = ComfyGrid.Compat and ComfyGrid.Compat.Warnings
        if dd ~= nil then
            pcall(dd.check)
        end
    end)
end
