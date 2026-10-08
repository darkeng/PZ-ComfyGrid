--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local PadMove = {}
ComfyGrid.Interact.PadMove = PadMove

local carriedInv = {}
local orderAtPickup = {}

local function orderModel()
    return ComfyGrid.Model and ComfyGrid.Model.ContainerOrder or nil
end

local function padFocus()
    return ComfyGrid.Interact.PadFocus
end

function PadMove.movingInv(page)
    return carriedInv[page]
end

function PadMove.canMove(page)
    local Order = orderModel()
    if Order == nil then return nil end
    local kind, el = padFocus().peek(page)

    if kind ~= "grid" and kind ~= "chip" then return nil end
    local inv = el.model ~= nil and el.model.inventory or nil
    if inv == nil or Order.indexOf(page, inv) == nil then return nil end
    if Order.isPinned(inv, getSpecificPlayer(page.player), page.player) then
        return nil
    end
    return inv
end

function PadMove.beginMove(page)
    local Order = orderModel()
    local inv = PadMove.canMove(page)
    if Order == nil or inv == nil then return nil end
    carriedInv[page] = inv

    orderAtPickup[page] = Order.keysOf(page)
    return inv
end

function PadMove.endMove(page, cancel)
    if carriedInv[page] == nil then return false end
    local orderBeforeMove = orderAtPickup[page]
    carriedInv[page], orderAtPickup[page] = nil, nil
    local Order = orderModel()
    if Order == nil then return true end
    if cancel and orderBeforeMove ~= nil then
        Order.set(page.player, orderBeforeMove)
        pcall(Order.apply, page)
    else
        pcall(Order.commit, page)
    end
    return true
end

function PadMove.press(page, inv, dx, dy)
    local Order = orderModel()
    if Order == nil then return true end
    local PadFocus = padFocus()
    if dx ~= 0 or dy == 0 then
        PadMove.endMove(page)
        PadFocus.focusInventory(page, inv)
        return true
    end
    local at = Order.indexOf(page, inv)
    if at == nil then
        PadMove.endMove(page)
        return true
    end
    Order.preview(page, inv, at + dy)
    Order.layout(page)
    PadFocus.focusInventory(page, inv)
    return true
end

return PadMove
