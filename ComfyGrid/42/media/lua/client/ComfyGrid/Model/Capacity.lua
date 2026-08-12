--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Util"
require "ComfyGrid/Settings"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local Capacity = {}
ComfyGrid.Model.Capacity = Capacity

local Util = ComfyGrid.Core.Util
local Settings = ComfyGrid.Settings

local MAX_SLOTS = 200

local MIN_SLOTS = 2
local FLOOR_SLOTS = 80
local FALLBACK_CAPACITY = 20

function Capacity.slotsFor(inventory)
    if inventory and inventory:getType() == "floor" then
        return FLOOR_SLOTS
    end

    local capacity = FALLBACK_CAPACITY
    if inventory then

        local ok, value = pcall(inventory.getCapacity, inventory)
        if ok and type(value) == "number" then
            capacity = value
        end

        local okP, parent = pcall(inventory.getParent, inventory)
        if okP and parent ~= nil and instanceof(parent, "IsoGameCharacter")
                and parent.getMaxWeight ~= nil then
            local okW, wmax = pcall(parent.getMaxWeight, parent)
            if okW and type(wmax) == "number" and wmax > 0 then
                capacity = wmax
            end
        end
    end

    return Util.clamp(
        math.ceil(capacity * Settings.get("SLOTS_PER_CAPACITY")),
        MIN_SLOTS, MAX_SLOTS)
end
