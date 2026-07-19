--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.2.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Compat/Warnings"
require "ComfyGrid/Networking/ComfyClient"
require "ComfyGrid/Interact/SpringLoad"
require "ComfyGrid/Patches/InventoryPanePatch"
require "ComfyGrid/Patches/InventoryPagePatch"
require "ComfyGrid/Patches/TransferActionPatch"
require "ComfyGrid/Patches/HotbarOverlayPatch"
require "ComfyGrid/Patches/ButtonPromptPatch"
require "ComfyGrid/Patches/EscapeMenuPatch"
require "ComfyGrid/Interact/QuickEquip"

local Log = ComfyGrid.Core.Log

if not ComfyGrid._bootHooked then
    ComfyGrid._bootHooked = true

    Events.OnGameBoot.Add(function()
        Log.info("Comfy Grid " .. ComfyGrid.VERSION .. " loaded (OnGameBoot)")
    end)

    Events.OnGameStart.Add(function()
        Log.info("Comfy Grid active in this session (OnGameStart)")
    end)
end
