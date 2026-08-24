--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}

local StackRules = {}
ComfyGrid.Model.StackRules = StackRules

local floor = math.floor
local concat = table.concat

local parts = {}

function StackRules.bucketOf(item)
    local n = 0

    if item.IsFood and item:IsFood() then
        if item.isRotten and item:isRotten() then
            n = n + 1; parts[n] = "rotten"
        elseif item.isFresh and item:isFresh() then
            n = n + 1; parts[n] = "fresh"
        else
            n = n + 1; parts[n] = "stale"
        end
        if item.isBurnt and item:isBurnt() then
            n = n + 1; parts[n] = "burnt"
        elseif item.isCooked and item:isCooked() then
            n = n + 1; parts[n] = "cooked"
        else
            n = n + 1; parts[n] = "raw"
        end
        if item.isFrozen and item:isFrozen() then
            n = n + 1; parts[n] = "frozen"
        end

        if item.getHungChange and item.getBaseHunger then
            local base = item:getBaseHunger()
            if base ~= 0 then
                local q = floor((item:getHungChange() / base) * 4 + 0.5)
                if q < 4 then
                    if q < 0 then q = 0 end
                    n = n + 1; parts[n] = "eaten:" .. q
                end
            end
        end
    end

    if item.IsDrainable and item:IsDrainable() and item.getCurrentUses then
        n = n + 1; parts[n] = "uses:" .. item:getCurrentUses()
    end

    if item.getFluidContainer then
        local fc = item:getFluidContainer()
        if fc then
            if fc.isEmpty and fc:isEmpty() then
                n = n + 1; parts[n] = "fl:empty"
            else

                local fluid = fc.getPrimaryFluid and fc:getPrimaryFluid()
                local amount = (fc.getAmount and fc:getAmount()) or 0
                n = n + 1
                parts[n] = "fl:" .. tostring(fluid) .. ":"
                    .. floor(amount * 10 + 0.5)
            end
        end
    end

    if item.getCondition and item.getConditionMax then
        local max = item:getConditionMax()
        if max and max > 0 then
            local band = floor(4 * item:getCondition() / max)
            if band < 4 then
                if band < 0 then band = 0 end
                n = n + 1; parts[n] = "cond:" .. band
            end
        end
    end
    if item.isBroken and item:isBroken() then
        n = n + 1; parts[n] = "broken"
    end

    if item.isFavorite and item:isFavorite() then
        n = n + 1; parts[n] = "fav"
    end
    if item.isActivated and item:isActivated() then
        n = n + 1; parts[n] = "on"
    end
    if item.isWet and item:isWet() then
        n = n + 1; parts[n] = "wet"
    end

    if n == 0 then return "" end
    if n == 1 then return parts[1] end
    return concat(parts, "|", 1, n)
end

StackRules.NEVER_STACK_TYPES = {
    ["Base.44Clip"] = true,
    ["Base.45Clip"] = true,
    ["Base.556Clip"] = true,
    ["Base.9mmClip"] = true,
    ["Base.M14Clip"] = true,
    ["Base.JS14_Clip"] = true,
}

function StackRules.isStackable(item)
    if not item then return false end

    if instanceof(item, "InventoryContainer") then return false end

    if instanceof(item, "Key") then return false end
    if instanceof(item, "KeyRing") then return false end

    if instanceof(item, "Moveable") then return false end
    if item.getDisplayCategory and item:getDisplayCategory() == "Moveable" then
        return false
    end

    if instanceof(item, "HandWeapon") and item.isRanged and item:isRanged() then
        return false
    end

    if item.getFullType and StackRules.NEVER_STACK_TYPES[item:getFullType()] then
        return false
    end
    return true
end

function StackRules.isSameStack(stack, item)
    if not stack or not item then return false end
    if stack.itemType ~= (item.getFullType and item:getFullType()) then
        return false
    end
    return stack.bucket == StackRules.bucketOf(item)
end

function StackRules.maxStackOf(item)
    if StackRules.isStackable(item) then return math.huge end
    return 1
end
