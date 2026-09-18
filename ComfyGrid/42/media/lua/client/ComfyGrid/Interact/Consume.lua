--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.5
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local Consume = {}
ComfyGrid.Interact.Consume = Consume

local NEED_FLOOR = 0.1

local MIN_PORTION = 0.1

local function amountIn(fc)
    if fc == nil then return nil end
    if fc.getAmount ~= nil then
        local ok, v = pcall(fc.getAmount, fc)
        if ok and type(v) == "number" then return v end
    end
    if fc.getFilledRatio ~= nil and fc.getCapacity ~= nil then
        local okR, ratio = pcall(fc.getFilledRatio, fc)
        local okC, cap = pcall(fc.getCapacity, fc)
        if okR and okC and type(ratio) == "number" and type(cap) == "number" then
            return ratio * cap
        end
    end
    return nil
end

local function statOf(playerObj, stat)
    if playerObj == nil or CharacterStat == nil then return nil end
    local ok, stats = pcall(playerObj.getStats, playerObj)
    if not ok or stats == nil or stats.get == nil then return nil end
    local okV, v = pcall(stats.get, stats, stat)
    if not okV or type(v) ~= "number" then return nil end
    return v
end

local function clampPortion(p)
    if p ~= p then return MIN_PORTION end
    if p < MIN_PORTION then return MIN_PORTION end
    if p > 1 then return 1 end
    return p
end

local function drinkableFluid(item)
    if item == nil or item.getFluidContainer == nil then return nil end
    local ok, fc = pcall(item.getFluidContainer, item)
    if not ok or fc == nil then return nil end
    if fc:isEmpty() then return nil end
    if fc:isTaintedStatusKnown() then return nil end
    local pf = fc:getPrimaryFluid()
    if pf == nil then return nil end
    if pf:isCategory(FluidCategory.Beverage) then return fc end
    local okT, t = pcall(pf.getFluidTypeString, pf)
    if okT and (t == "Water" or t == "CarbonatedWater") then return fc end
    local okW, isWater = pcall(item.isWaterSource, item)
    if okW and isWater then return fc end
    return nil
end

local function vanillaSaysEdible(playerObj, item)
    if item == nil or not instanceof(item, "Food") then return false end
    local okH, hung = pcall(item.getHungChange, item)
    if not okH or type(hung) ~= "number" or hung >= 0 then return false end
    local okS, script = pcall(item.getScriptItem, item)
    if okS and script ~= nil and script:isCantEat() then return false end
    if item:isBurnt() or item:isRotten() then return false end
    local okP, poison = pcall(playerObj.isKnownPoison, playerObj, item)
    if okP and poison then return false end
    if item:isbDangerousUncooked() and not item:isCooked() then return false end
    return true
end

local function isSealed(item)
    local ok, sealed = pcall(item.isSealed, item)
    if ok and sealed then return true end
    return false
end

function Consume.tryUse(playerObj, item, playerNum)
    if playerObj == nil or item == nil then return false end
    if ISInventoryPaneContextMenu == nil then return false end

    local fc = drinkableFluid(item)
    if fc ~= nil then
        if isSealed(item) then return false end
        local thirst = statOf(playerObj, CharacterStat.THIRST)
        if thirst == nil or thirst <= NEED_FLOOR then return true end
        local amount = amountIn(fc)
        if amount == nil or amount <= 0 then return true end

        local percent = clampPortion(math.min(thirst * 2, amount) / amount)
        pcall(ISInventoryPaneContextMenu.onDrinkFluid, item, percent, playerObj)
        return true
    end

    if vanillaSaysEdible(playerObj, item) then
        if isSealed(item) then return false end
        local hunger = statOf(playerObj, CharacterStat.HUNGER)
        if hunger == nil or hunger <= NEED_FLOOR then return true end

        local worth = -item:getHungChange()
        local percent = 1
        if worth > 0 then percent = clampPortion(hunger / worth) end
        pcall(ISInventoryPaneContextMenu.onEatItems, { item }, percent, playerNum)
        return true
    end

    return false
end
