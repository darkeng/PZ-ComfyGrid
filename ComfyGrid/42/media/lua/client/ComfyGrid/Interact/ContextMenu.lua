--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Interact/Tooltip"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local ContextMenu = {}
ComfyGrid.Interact.ContextMenu = ContextMenu

local Log = ComfyGrid.Core.Log
local VanillaStacks = ComfyGrid.Core.VanillaStacks

local MAX_ANCESTOR_DEPTH = 8
local function paneOf(gridView)
    local node = gridView ~= nil and gridView.parent or nil
    local depth = 0
    while node ~= nil and depth < MAX_ANCESTOR_DEPTH do
        if node.pane ~= nil then return node.pane end
        node = node.parent
        depth = depth + 1
    end
    return nil
end

function ContextMenu.handOff(playerNum, menu, origin)
    if menu == nil or origin == nil then return false end
    if menu.numOptions == nil or menu.numOptions <= 1 then return false end
    if JoypadState == nil or not JoypadState.players[playerNum + 1] then
        return false
    end
    menu.origin = origin
    menu.mouseOver = 1
    setJoypadFocus(playerNum, menu)
    return true
end

function ContextMenu.open(playerNum, stacks, gridView, absX, absY)

    if absX == nil and playerNum ~= 0 then return false end
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil then return false end
    local model = gridView ~= nil and gridView.model or nil
    local inventory = model ~= nil and model.inventory or nil
    if inventory == nil then return false end

    local pane = paneOf(gridView)
    local stackList = VanillaStacks.listFrom(stacks, inventory, pane)

    if #stackList == 0 then return false end

    local Tooltip = ComfyGrid.Interact.Tooltip
    if Tooltip ~= nil then Tooltip.hideForPane(pane) end

    local isInPlayerInventory = inventory:isInCharacterInventory(playerObj)

    local menu = ISInventoryPaneContextMenu.createMenu(
        playerNum, isInPlayerInventory, stackList,
        absX or getMouseX(), absY or getMouseY())

    ContextMenu.handOff(playerNum, menu,
        pane ~= nil and pane.inventoryPage or nil)

    if menu == nil then

        Log.info("ContextMenu: createMenu returned nil (paused or suppressed)")
        return false
    end
    return true
end

function ContextMenu.openForItems(playerNum, items, absX, absY, origin)
    if items == nil or #items == 0 then return false end
    if getSpecificPlayer(playerNum) == nil then return false end
    local menu = ISInventoryPaneContextMenu.createMenu(
        playerNum, true, items, absX or getMouseX(), absY or getMouseY())
    if menu == nil then return false end
    ContextMenu.handOff(playerNum, menu, origin)
    return true
end
