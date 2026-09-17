--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local Highlight = {}
ComfyGrid.Interact.Highlight = Highlight

local cachedSource = nil
local cachedIds = nil

local function sweep(pane)
    if pane == nil or pane.itemsToHighlight == nil then return nil end
    local owner = pane.itemsToHighlightOwner
    if owner == nil or owner.isReallyVisible == nil
            or not owner:isReallyVisible() then
        pane.itemsToHighlightOwner = nil
        pane.itemsToHighlight = nil
        return nil
    end
    return pane.itemsToHighlight
end

local function paneOf(page)
    if page == nil then return nil end
    return page.inventoryPane
end

function Highlight.idsFor(playerNum)
    if playerNum == nil then return nil end
    local fromPlayer = nil
    local fromLoot = nil
    if getPlayerInventory ~= nil then
        fromPlayer = sweep(paneOf(getPlayerInventory(playerNum)))
    end
    if getPlayerLoot ~= nil then
        fromLoot = sweep(paneOf(getPlayerLoot(playerNum)))
    end

    local map = fromPlayer or fromLoot
    if map == nil then
        cachedSource, cachedIds = nil, nil
        return nil
    end
    if map ~= cachedSource then
        local ids = {}
        for item in pairs(map) do

            local ok, id = pcall(item.getID, item)
            if ok and id ~= nil then ids[id] = true end
        end
        cachedSource, cachedIds = map, ids
    end
    return cachedIds
end

local pubPane = nil
local pubOwner = nil

local function releaseCurrent()
    local pane, owner = pubPane, pubOwner
    pubPane, pubOwner = nil, nil
    if pane == nil or owner == nil then return end

    pcall(pane.setItemsToHighlight, pane, owner, nil)
end

function Highlight.publish(pane, owner, map)
    if pane == nil or owner == nil or map == nil then return end
    if pubOwner ~= nil and (pubOwner ~= owner or pubPane ~= pane) then
        releaseCurrent()
    end
    pubPane, pubOwner = pane, owner
    pcall(pane.setItemsToHighlight, pane, owner, map)
end

function Highlight.release(owner)
    if owner == nil or pubOwner ~= owner then return end
    releaseCurrent()
end

function Highlight.hasStack(ids, stack)
    if ids == nil or stack == nil then return false end
    local itemIDs = stack.itemIDs
    if itemIDs == nil then return false end
    for id in pairs(itemIDs) do
        if ids[id] then return true end
    end
    return false
end
