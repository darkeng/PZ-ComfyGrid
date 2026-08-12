--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/Model/Equipment"
require "ComfyGrid/Interact/Tooltip"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local QuickEquip = {}
ComfyGrid.Interact.QuickEquip = QuickEquip

local Log = ComfyGrid.Core.Log
local ItemStack = ComfyGrid.Model.ItemStack
local ContainerModel = ComfyGrid.Model.ContainerModel
local Equipment = ComfyGrid.Model.Equipment

local lastError = nil

local function isWearable(item)
    if instanceof(item, "Clothing") then return true end
    if item.canBeEquipped ~= nil then
        local ok, loc = pcall(item.canBeEquipped, item)
        if ok and type(loc) == "string" and loc ~= "" then return true end
    end
    return false
end

local function equipHovered()
    local playerObj = getSpecificPlayer(0)
    if playerObj == nil then return end

    local dd = ComfyGrid.Interact.DragAndDrop
    if dd ~= nil and dd.isDragging ~= nil and dd.isDragging() then return end
    local Tooltip = ComfyGrid.Interact.Tooltip
    if Tooltip == nil or Tooltip.hoveredStackOf == nil then return end

    local stack, inventory
    local page = getPlayerInventory(0)
    local pane = page ~= nil and page.inventoryPane or nil
    if pane ~= nil then
        stack, inventory = Tooltip.hoveredStackOf(pane)
    end
    if stack == nil then
        page = getPlayerLoot(0)
        pane = page ~= nil and page.inventoryPane or nil
        if pane ~= nil then
            stack, inventory = Tooltip.hoveredStackOf(pane)
        end
    end
    if stack == nil or inventory == nil then return end
    local front = ItemStack.frontItem(stack, inventory)
    if front == nil then return end

    local displaced
    if isWearable(front) then
        displaced = Equipment.findDisplacedWorn(playerObj, front)
        ISInventoryPaneContextMenu.onWearItems({ front }, 0)
    elseif instanceof(front, "HandWeapon") then
        local okH, held = pcall(playerObj.getPrimaryHandItem, playerObj)
        displaced = okH and held or nil
        local twoHands = front.isTwoHandWeapon ~= nil
            and front:isTwoHandWeapon() or false
        ISInventoryPaneContextMenu.equipWeapon(front, true, twoHands, 0)
    else
        return
    end

    if displaced ~= nil and displaced ~= front
            and inventory == playerObj:getInventory()
            and type(stack.slot) == "number" then
        local model = ContainerModel.getOrCreate(inventory, 0)
        local grid = model ~= nil and model.grid or nil
        if grid ~= nil and grid.claimSlotForItem ~= nil then
            grid:claimSlotForItem(displaced:getID(), stack.slot)
        end
    end
end

function QuickEquip._onKey(key)
    local target = nil
    local core = getCore and getCore() or nil
    if core ~= nil and core.getKey ~= nil then
        local ok, k = pcall(core.getKey, core, "Interact")
        if ok and type(k) == "number" then target = k end
    end
    if target == nil and Keyboard ~= nil then target = Keyboard.KEY_E end
    if key ~= target then return end
    local ok, err = pcall(equipHovered)
    if not ok and err ~= lastError then
        lastError = err
        Log.error("QuickEquip failed: " .. tostring(err))
    end
end

if not ComfyGrid._quickEquipHooked then
    ComfyGrid._quickEquipHooked = true
    Events.OnKeyStartPressed.Add(function(key)
        local qe = ComfyGrid.Interact and ComfyGrid.Interact.QuickEquip
        if qe ~= nil and qe._onKey ~= nil then
            qe._onKey(key)
        end
    end)
end
