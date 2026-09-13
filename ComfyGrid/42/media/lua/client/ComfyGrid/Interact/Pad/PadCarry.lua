--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.7.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/UI/Style"
require "ComfyGrid/Interact/DragAndDrop"
require "ComfyGrid/Interact/DropHandler"
require "ComfyGrid/Interact/QuickMove"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local PadCarry = {}
ComfyGrid.Interact.PadCarry = PadCarry

local Log = ComfyGrid.Core.Log
local VanillaStacks = ComfyGrid.Core.VanillaStacks
local ItemStack = ComfyGrid.Model.ItemStack
local Style = ComfyGrid.UI.Style
local DragAndDrop = ComfyGrid.Interact.DragAndDrop
local DropHandler = ComfyGrid.Interact.DropHandler
local QuickMove = ComfyGrid.Interact.QuickMove

local function noop() end

local owners = {}

local function ownerFor(playerNum)
    local o = owners[playerNum]
    if o == nil then
        o = {
            playerNum = playerNum,
            onMouseUp = noop,
            stack = nil,
            sourceInventory = nil,
            renderItem = nil,
            itemId = nil,
        }
        owners[playerNum] = o
    end
    return o
end

local function clearOwner(o)
    o.stack = nil
    o.sourceInventory = nil
    o.renderItem = nil
    o.itemId = nil
end

function PadCarry.isCarrying(playerNum)
    local o = owners[playerNum]
    return o ~= nil and DragAndDrop.isDragOwner(o) and DragAndDrop.isDragging()
end

function PadCarry.pickup(playerNum, gridView, stack)
    if PadCarry.isCarrying(playerNum) then return false end
    if gridView == nil or stack == nil
            or gridView.dragPayloadFor == nil then
        return false
    end
    local payload = gridView:dragPayloadFor(stack)
    if payload == nil then return false end
    local o = ownerFor(playerNum)
    if not DragAndDrop.beginDirectDrag(o, payload) then return false end
    o.stack = stack
    o.sourceInventory = gridView.model ~= nil and gridView.model.inventory
        or nil
    o.renderItem = ItemStack.frontItem(stack, o.sourceInventory)
    o.itemId = o.renderItem ~= nil and o.renderItem:getID() or nil
    return true
end

function PadCarry.pickupPayload(playerNum, payload, renderItem)
    if PadCarry.isCarrying(playerNum) then return false end
    if payload == nil or payload[1] == nil then return false end
    local o = ownerFor(playerNum)
    if not DragAndDrop.beginDirectDrag(o, payload) then return false end
    o.stack = nil
    o.sourceInventory = renderItem ~= nil and renderItem:getContainer() or nil
    o.renderItem = renderItem
    o.itemId = renderItem ~= nil and renderItem:getID() or nil
    return true
end

function PadCarry.pickupItem(playerNum, item)
    if item == nil then return false end
    local payload = { VanillaStacks.fromItems({ item }) }
    if payload[1] == nil then return false end
    return PadCarry.pickupPayload(playerNum, payload, item)
end

function PadCarry.carriedItemId(playerNum)
    if not PadCarry.isCarrying(playerNum) then return nil end
    return owners[playerNum].itemId
end

function PadCarry.finish(playerNum)
    local o = owners[playerNum]
    if o == nil then return end
    if DragAndDrop.isDragOwner(o) then DragAndDrop.endDrag() end
    clearOwner(o)
end

function PadCarry.place(playerNum, gridView, slot)
    if not PadCarry.isCarrying(playerNum) then return false end
    if gridView == nil or slot == nil then return false end
    local px, py = Style.pixelForSlot(slot, gridView.cols or 1)

    local ok, consumed = pcall(DropHandler.resolve, gridView, px + 2, py + 2)
    if not ok then
        Log.error("PadCarry: place failed: " .. tostring(consumed))
        consumed = false
    end
    if consumed ~= true then DragAndDrop.endDrag() end
    clearOwner(owners[playerNum])
    return consumed == true
end

function PadCarry.cancel(playerNum)
    if not PadCarry.isCarrying(playerNum) then return false end
    DragAndDrop.endDrag()
    clearOwner(owners[playerNum])
    return true
end

function PadCarry.quickMoveCarried(playerNum)
    if not PadCarry.isCarrying(playerNum) then return false end
    local o = owners[playerNum]
    local payload = DragAndDrop.getDraggedStacks()
    local src = o.sourceInventory
    DragAndDrop.endDrag()
    clearOwner(o)
    if payload == nil or src == nil then return false end
    return QuickMove.run(payload, src, playerNum)
end

function PadCarry.carriedStackOn(gridView)
    local o = owners[gridView.playerNum]
    if o == nil or o.stack == nil then return nil end
    if not (DragAndDrop.isDragOwner(o) and DragAndDrop.isDragging()) then
        clearOwner(o)
        return nil
    end
    local model = gridView.model
    if model == nil or model.inventory ~= o.sourceInventory then return nil end
    return o.stack
end

function PadCarry.renderAt(view, px, py)
    local o = owners[view.playerNum]
    if o == nil or o.renderItem == nil then return end
    if not (DragAndDrop.isDragOwner(o) and DragAndDrop.isDragging()) then
        return
    end
    local tex = o.renderItem:getTex()
    if tex == nil then return end
    local cell = Style.CELL or 45

    view:drawItemIcon(o.renderItem, px + 3, py + 3, 0.85, cell - 6, cell - 6)
end

return PadCarry
