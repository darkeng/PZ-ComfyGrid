--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.3
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

local hoverTarget = nil
local hoverPage = nil
local hoverTargetIsHeader = false
local hoverSinceMs = 0

local selectFailLogged = false

local function reset()
    hoverTarget = nil
    hoverPage = nil
    hoverTargetIsHeader = false
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

local function collapsedHeaderOn(page)
    if page == nil or page.onCharacter ~= true then return nil end
    if not page:isReallyVisible() then return nil end
    local pane = page.inventoryPane
    local host = pane ~= nil and pane.comfyHost or nil
    if host == nil or host.collapsedHeaderUnderMouse == nil then return nil end
    return host:collapsedHeaderUnderMouse()
end

local function findHoverTarget()
    local seats = getNumActivePlayers and getNumActivePlayers() or 1
    for playerNum = 0, seats - 1 do
        local okInventory, inventoryPage = pcall(getPlayerInventory, playerNum)
        local button = okInventory and buttonOn(inventoryPage) or nil
        if button ~= nil then return button, inventoryPage, false end
        local okLoot, lootPage = pcall(getPlayerLoot, playerNum)
        button = okLoot and buttonOn(lootPage) or nil
        if button ~= nil then return button, lootPage, false end
        local header = okInventory and collapsedHeaderOn(inventoryPage) or nil
        if header ~= nil then return header, inventoryPage, true end
    end
    return nil, nil, false
end

local function openHoverTarget()
    if hoverTargetIsHeader then
        hoverTarget:setSectionCollapsed(false)
        return
    end
    local button = hoverTarget
    local pane = hoverPage ~= nil and hoverPage.inventoryPane or nil
    if pane ~= nil and pane.inventory ~= button.inventory then
        local ok, err = pcall(hoverPage.selectButtonForContainer, hoverPage,
            button.inventory)
        if not ok and not selectFailLogged then
            selectFailLogged = true
            Log.error("SpringLoad: container select failed (logged once): "
                .. tostring(err))
        end
    end
    local SectionCollapse = ComfyGrid.Model and ComfyGrid.Model.SectionCollapse
    if SectionCollapse ~= nil and hoverPage.onCharacter == true then
        SectionCollapse.expandInventory(hoverPage.player, button.inventory)
    end
end

function SpringLoad._onTick()
    local DragAndDrop = ComfyGrid.Interact and ComfyGrid.Interact.DragAndDrop
    if DragAndDrop == nil or not DragAndDrop.isComfyDrag() then
        if hoverTarget ~= nil then reset() end
        return
    end
    local target, page, isHeader = findHoverTarget()
    if target == nil then
        if hoverTarget ~= nil then reset() end
        return
    end
    if target ~= hoverTarget then

        hoverTarget = target
        hoverPage = page
        hoverTargetIsHeader = isHeader
        hoverSinceMs = getTimestampMs()
        return
    end
    if getTimestampMs() - hoverSinceMs < HOLD_MS then return end
    openHoverTarget()
end

if not ComfyGrid._springLoadTickHooked then
    ComfyGrid._springLoadTickHooked = true
    Events.OnTick.Add(function()
        local springLoad = ComfyGrid.Interact and ComfyGrid.Interact.SpringLoad
        if springLoad ~= nil then
            springLoad._onTick()
        end
    end)
end
