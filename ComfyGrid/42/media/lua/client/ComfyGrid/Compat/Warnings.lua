--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.0
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

            if ISModalDialog ~= nil then
                local core = getCore and getCore() or nil
                local sw = core and core:getScreenWidth() or 1920
                local sh = core and core:getScreenHeight() or 1080
                local w, h = 380, 120
                local ok, dialog = pcall(function()
                    local d = ISModalDialog:new((sw - w) / 2, (sh - h) / 2,
                        w, h, msg, false, nil, nil)
                    d:initialise()
                    d:addToUIManager()
                    return d
                end)
                if not ok then
                    Log.error("Warnings: modal failed: " .. tostring(dialog))
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
