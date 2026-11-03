--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.9
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local FishingRig = {}
ComfyGrid.Interact.FishingRig = FishingRig

function FishingRig.hasTag(item, tagName)
    local tag = ItemTag ~= nil and ItemTag[tagName] or nil
    if item == nil or tag == nil or item.hasTag == nil then return false end
    local ok, tagged = pcall(item.hasTag, item, tag)
    return ok and tagged == true
end

function FishingRig.isRod(item)
    return FishingRig.hasTag(item, "FISHING_ROD")
end

function FishingRig.isBait(item)
    if item == nil or Fishing == nil or Fishing.IsLure == nil then return false end
    if not Fishing.IsLure(item:getFullType()) then return false end
    return not (instanceof(item, "Food") and item:isCooked())
end

function FishingRig.managerOf(playerObj)
    local managers = Fishing ~= nil and Fishing.ManagerInstances or nil
    if managers == nil or playerObj == nil then return nil end
    if isMultiplayer() then return managers[playerObj:getUsername()] end
    return managers[playerObj:getPlayerNum()]
end

local function stateOf(playerObj)
    local manager = FishingRig.managerOf(playerObj)
    if manager == nil or manager.states == nil then return nil, nil end
    return manager, manager.state
end

function FishingRig.isCasting(playerObj)
    local manager, state = stateOf(playerObj)
    return manager ~= nil and state ~= manager.states["None"]
        and state ~= manager.states["Idle"]
end

function FishingRig.isFishing(playerObj)
    local manager, state = stateOf(playerObj)
    return manager ~= nil and state ~= manager.states["None"]
end

return FishingRig
