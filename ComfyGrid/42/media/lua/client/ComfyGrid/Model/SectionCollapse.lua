--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.5
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Prefs"
require "ComfyGrid/Model/ContainerOrder"
require "ComfyGrid/Model/SectionPlan"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local SectionCollapse = {}
ComfyGrid.Model.SectionCollapse = SectionCollapse

local Prefs = ComfyGrid.Core.Prefs
local ContainerOrder = ComfyGrid.Model.ContainerOrder
local SectionPlan = ComfyGrid.Model.SectionPlan

SectionCollapse.POCKETS_KEY = "pockets"

local foldedKeysBySeat = {}

local function prefNameFor(seat)
    return "ComfyCollapsed" .. tostring(seat)
end

local function foldedKeysOf(playerNum)
    local seat = playerNum or 0
    local foldedKeys = foldedKeysBySeat[seat]
    if foldedKeys == nil then
        foldedKeys = {}
        local storedLine = Prefs.get(prefNameFor(seat))
        if type(storedLine) == "string" then
            for storedKey in string.gmatch(storedLine, "[^|]+") do
                foldedKeys[storedKey] = true
            end
        end
        foldedKeysBySeat[seat] = foldedKeys
    end
    return foldedKeys
end

local function storeFoldedKeys(playerNum, foldedKeys)
    local keyList = {}
    for foldedKey in pairs(foldedKeys) do keyList[#keyList + 1] = foldedKey end
    table.sort(keyList)
    Prefs.set(prefNameFor(playerNum or 0), table.concat(keyList, "|"))
end

function SectionCollapse.keyForInventory(inventory, playerNum)
    return ContainerOrder.keyFor(inventory, getSpecificPlayer(playerNum or 0))
end

function SectionCollapse.isCollapsed(playerNum, key)
    if key == nil then return false end
    return foldedKeysOf(playerNum)[key] == true
end

function SectionCollapse.setCollapsed(playerNum, key, collapsed)
    if key == nil then return end
    local foldedKeys = foldedKeysOf(playerNum)
    local storedValue = nil
    if collapsed == true then storedValue = true end
    if foldedKeys[key] == storedValue then return end
    foldedKeys[key] = storedValue
    storeFoldedKeys(playerNum, foldedKeys)
end

function SectionCollapse.toggle(playerNum, key)
    if key == nil then return false end
    local nowCollapsed = not SectionCollapse.isCollapsed(playerNum, key)
    SectionCollapse.setCollapsed(playerNum, key, nowCollapsed)
    return nowCollapsed
end

function SectionCollapse.expandInventory(playerNum, inventory)
    if inventory == nil then return end
    local playerObj = getSpecificPlayer(playerNum or 0)
    if SectionPlan.isPocket(inventory, playerObj, playerNum) then
        SectionCollapse.setCollapsed(playerNum, SectionCollapse.POCKETS_KEY,
            false)
        return
    end
    SectionCollapse.setCollapsed(playerNum,
        ContainerOrder.keyFor(inventory, playerObj), false)
end
