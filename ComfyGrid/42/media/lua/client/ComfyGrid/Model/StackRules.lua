--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Settings"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}

local StackRules = {}
ComfyGrid.Model.StackRules = StackRules

local Settings = ComfyGrid.Settings

local floor = math.floor
local concat = table.concat

local tokenBuffer = {}

function StackRules.bucketOf(item)
    local tokenCount = 0

    if item.getInventory ~= nil then
        local held = item:getInventory()
        if held ~= nil and held:getItems():size() > 0 then
            tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "bag:" .. tostring(item:getID())
        end
    end
    if Settings.get("STACK_BY_TYPE") == true then
        if item.isFavorite and item:isFavorite() then
            tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "fav"
        end
        if item.getFluidContainer then
            local fluidContainer = item:getFluidContainer()
            if fluidContainer and not (fluidContainer.isEmpty and fluidContainer:isEmpty()) then
                local fluid = fluidContainer.getPrimaryFluid and fluidContainer:getPrimaryFluid()
                tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "fl:" .. tostring(fluid)
            end
        end
        if tokenCount == 0 then return "" end
        if tokenCount == 1 then return tokenBuffer[1] end
        return concat(tokenBuffer, "|", 1, tokenCount)
    end

    if item.IsFood and item:IsFood() then
        if item.isRotten and item:isRotten() then
            tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "rotten"
        elseif item.isFresh and item:isFresh() then
            tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "fresh"
        else
            tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "stale"
        end
        if item.isBurnt and item:isBurnt() then
            tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "burnt"
        elseif item.isCooked and item:isCooked() then
            tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "cooked"
        else
            tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "raw"
        end
        if item.isFrozen and item:isFrozen() then
            tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "frozen"
        end

        if item.getHungChange and item.getBaseHunger then
            local base = item:getBaseHunger()
            if base ~= 0 then
                local eatenQuarter = floor((item:getHungChange() / base) * 4 + 0.5)
                if eatenQuarter < 4 then
                    if eatenQuarter < 0 then eatenQuarter = 0 end
                    tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "eaten:" .. eatenQuarter
                end
            end
        end
    end

    if item.IsDrainable and item:IsDrainable() and item.getCurrentUses then
        tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "uses:" .. item:getCurrentUses()
    end

    if item.getFluidContainer then
        local fluidContainer = item:getFluidContainer()
        if fluidContainer then
            if fluidContainer.isEmpty and fluidContainer:isEmpty() then
                tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "fl:empty"
            else

                local fluid = fluidContainer.getPrimaryFluid and fluidContainer:getPrimaryFluid()
                local amount = (fluidContainer.getAmount and fluidContainer:getAmount()) or 0
                tokenCount = tokenCount + 1
                tokenBuffer[tokenCount] = "fl:" .. tostring(fluid) .. ":"
                    .. floor(amount * 10 + 0.5)
            end
        end
    end

    if item.getCondition and item.getConditionMax then
        local conditionMax = item:getConditionMax()
        if conditionMax and conditionMax > 0 then
            local band = floor(4 * item:getCondition() / conditionMax)
            if band < 4 then
                if band < 0 then band = 0 end
                tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "cond:" .. band
            end
        end
    end
    if item.isBroken and item:isBroken() then
        tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "broken"
    end

    if item.isFavorite and item:isFavorite() then
        tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "fav"
    end
    if item.isActivated and item:isActivated() then
        tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "on"
    end
    if item.isWet and item:isWet() then
        tokenCount = tokenCount + 1; tokenBuffer[tokenCount] = "wet"
    end

    if tokenCount == 0 then return "" end
    if tokenCount == 1 then return tokenBuffer[1] end
    return concat(tokenBuffer, "|", 1, tokenCount)
end

StackRules.HEAVY_WEIGHT = 5

StackRules.MATERIAL_WEAPON_CATEGORY = "MaterialWeapon"

local function isThrowable(item)
    if item.isExplosive == nil then return false end
    local ok, explosive = pcall(item.isExplosive, item)
    if not ok or explosive ~= true then return false end
    if item.isRanged ~= nil then
        local okRanged, ranged = pcall(item.isRanged, item)
        if okRanged and ranged == true then return false end
    end
    return true
end

StackRules.NEVER_STACK_TYPES = {
    ["Base.44Clip"] = true,
    ["Base.45Clip"] = true,
    ["Base.556Clip"] = true,
    ["Base.9mmClip"] = true,
    ["Base.M14Clip"] = true,
    ["Base.JS14_Clip"] = true,
}

local classFactsByType = {}

local function classFactsOf(item, fullType)
    local typeFacts = fullType ~= nil and classFactsByType[fullType] or nil
    if typeFacts ~= nil then return typeFacts end
    typeFacts = {
        container = instanceof(item, "InventoryContainer") == true,
        keyring = instanceof(item, "KeyRing") == true,
        moveable = instanceof(item, "Moveable") == true,
        weapon = instanceof(item, "HandWeapon") == true,
    }
    if fullType ~= nil then classFactsByType[fullType] = typeFacts end
    return typeFacts
end

function StackRules.isStackable(item)
    if not item then return false end

    local fullType = item.getFullType ~= nil and item:getFullType() or nil
    local facts = classFactsOf(item, fullType)

    if facts.container then
        if item.canBeEquipped == nil then return false end
        local okEquip, wornAt = pcall(item.canBeEquipped, item)
        if not okEquip then return false end
        if wornAt ~= nil and tostring(wornAt) ~= "" then return false end
    end

    if facts.keyring then return false end

    if facts.moveable then return false end
    if item.getDisplayCategory and item:getDisplayCategory() == "Moveable" then
        return false
    end

    if facts.weapon then
        local displayCategory = item.getDisplayCategory ~= nil
            and item:getDisplayCategory() or nil
        if displayCategory ~= StackRules.MATERIAL_WEAPON_CATEGORY
                and not isThrowable(item) then
            return false
        end
    end

    if item.getWeight ~= nil then
        local ok, scriptWeight = pcall(item.getWeight, item)
        if ok and type(scriptWeight) == "number"
                and scriptWeight >= StackRules.HEAVY_WEIGHT then
            return false
        end
    end

    if fullType ~= nil and StackRules.NEVER_STACK_TYPES[fullType] then
        return false
    end
    return true
end

function StackRules.identityOf(item)
    if item == nil then return nil end

    local fullType = item.getFullType and item:getFullType() or nil
    local Herbalist = ComfyGrid.Model and ComfyGrid.Model.Herbalist
    if Herbalist ~= nil then
        local masked = Herbalist.groupNameOf(item, fullType)
        if masked ~= nil then return masked end
    end
    if fullType == nil then return nil end
    if item.getRecordedMediaIndex ~= nil then
        local ok, mediaIndex = pcall(item.getRecordedMediaIndex, item)
        if ok and type(mediaIndex) == "number" and mediaIndex >= 0 then
            return fullType .. "@" .. tostring(mediaIndex)
        end
    end
    return fullType
end

function StackRules.isSameStack(stack, item)
    if not stack or not item then return false end
    if stack.itemType ~= StackRules.identityOf(item) then
        return false
    end
    return stack.bucket == StackRules.bucketOf(item)
end

function StackRules.maxStackOf(item)
    if StackRules.isStackable(item) then return math.huge end
    return 1
end
