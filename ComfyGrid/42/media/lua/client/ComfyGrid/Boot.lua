--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Prefs"
require "ComfyGrid/Compat/Warnings"
require "ComfyGrid/UI/Draw"
require "ComfyGrid/UI/Chrome/PopupRegistry"
require "ComfyGrid/UI/Chrome/HoverTip"
require "ComfyGrid/UI/Chrome/WindowChrome"
require "ComfyGrid/UI/Chrome/WindowStrip"
require "ComfyGrid/UI/Chrome/SettingsPopup"
require "ComfyGrid/UI/Avatar"
require "ComfyGrid/UI/EquipWindow"
require "ComfyGrid/Networking/ComfyClient"
require "ComfyGrid/Interact/SpringLoad"
require "ComfyGrid/Patches/InventoryPanePatch"
require "ComfyGrid/Patches/InventoryPagePatch"
require "ComfyGrid/Patches/TransferActionPatch"
require "ComfyGrid/Patches/HotbarPatch"
require "ComfyGrid/Patches/ButtonPromptPatch"
require "ComfyGrid/Patches/EscapeMenuPatch"
require "ComfyGrid/Patches/ConsolidateMenuPatch"
require "ComfyGrid/Patches/ControlsStripPatch"
require "ComfyGrid/Interact/QuickEquip"
require "ComfyGrid/Interact/ItemApply"

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
