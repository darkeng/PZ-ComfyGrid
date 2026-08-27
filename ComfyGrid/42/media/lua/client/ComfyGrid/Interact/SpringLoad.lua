--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.4.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local SpringLoad = {}
ComfyGrid.Interact.SpringLoad = SpringLoad

local Log = ComfyGrid.Core.Log

local HOLD_MS = 400

local hoverButton = nil
local hoverPage = nil
local hoverSinceMs = 0

local selectFailLogged = false

local function reset()
    hoverButton = nil
    hoverPage = nil
end

local function buttonOn(page)
    if page == nil or page.backpacks == nil then return nil end
    if not page:isReallyVisible() then return nil end
    for i = 1, #page.backpacks do
        local button = page.backpacks[i]
        if button ~= nil and button:isMouseOver() then
            return button
        end
    end
    return nil
end

function SpringLoad._onTick()
    local dd = ComfyGrid.Interact and ComfyGrid.Interact.DragAndDrop
    if dd == nil or not dd.isComfyDrag() then
        if hoverButton ~= nil then reset() end
        return
    end
    local button, page = nil, nil
    local seats = getNumActivePlayers and getNumActivePlayers() or 1
    for playerNum = 0, seats - 1 do
        local okI, invPage = pcall(getPlayerInventory, playerNum)
        button = okI and buttonOn(invPage) or nil
        if button ~= nil then
            page = invPage
            break
        end
        local okL, lootPage = pcall(getPlayerLoot, playerNum)
        button = okL and buttonOn(lootPage) or nil
        if button ~= nil then
            page = lootPage
            break
        end
    end
    if button == nil then
        if hoverButton ~= nil then reset() end
        return
    end
    if button ~= hoverButton then

        hoverButton = button
        hoverPage = page
        hoverSinceMs = getTimestampMs()
        return
    end
    if getTimestampMs() - hoverSinceMs < HOLD_MS then return end
    local pane = hoverPage ~= nil and hoverPage.inventoryPane or nil
    if pane == nil or pane.inventory == button.inventory then return end

    local ok, err = pcall(hoverPage.selectButtonForContainer, hoverPage,
        button.inventory)
    if not ok and not selectFailLogged then
        selectFailLogged = true
        Log.error("SpringLoad: container select failed (logged once): "
            .. tostring(err))
    end
end

if not ComfyGrid._springLoadTickHooked then
    ComfyGrid._springLoadTickHooked = true
    Events.OnTick.Add(function()
        local sl = ComfyGrid.Interact and ComfyGrid.Interact.SpringLoad
        if sl ~= nil then
            sl._onTick()
        end
    end)
end
