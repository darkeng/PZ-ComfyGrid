--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
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

local function amountIn(fluidContainer)
    if fluidContainer == nil then return nil end
    if fluidContainer.getAmount ~= nil then
        local ok, amount = pcall(fluidContainer.getAmount, fluidContainer)
        if ok and type(amount) == "number" then return amount end
    end
    if fluidContainer.getFilledRatio ~= nil
            and fluidContainer.getCapacity ~= nil then
        local okR, ratio = pcall(fluidContainer.getFilledRatio, fluidContainer)
        local okC, cap = pcall(fluidContainer.getCapacity, fluidContainer)
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
    local okV, statValue = pcall(stats.get, stats, stat)
    if not okV or type(statValue) ~= "number" then return nil end
    return statValue
end

local function clampPortion(portion)
    if portion ~= portion then return MIN_PORTION end
    if portion < MIN_PORTION then return MIN_PORTION end
    if portion > 1 then return 1 end
    return portion
end

local function drinkableFluid(item)
    if item == nil or item.getFluidContainer == nil then return nil end
    local ok, fluidContainer = pcall(item.getFluidContainer, item)
    if not ok or fluidContainer == nil then return nil end
    if fluidContainer:isEmpty() then return nil end
    if fluidContainer:isTaintedStatusKnown() then return nil end
    local primaryFluid = fluidContainer:getPrimaryFluid()
    if primaryFluid == nil then return nil end
    if primaryFluid:isCategory(FluidCategory.Beverage) then
        return fluidContainer
    end
    local okT, fluidTypeName = pcall(primaryFluid.getFluidTypeString,
        primaryFluid)
    if okT and (fluidTypeName == "Water" or fluidTypeName == "CarbonatedWater") then
        return fluidContainer
    end
    local okW, isWater = pcall(item.isWaterSource, item)
    if okW and isWater then return fluidContainer end
    return nil
end

local function isSealed(item)
    local ok, sealed = pcall(item.isSealed, item)
    if ok and sealed then return true end
    return false
end

function Consume.tryUse(playerObj, item)
    if playerObj == nil or item == nil then return false end
    if ISInventoryPaneContextMenu == nil then return false end

    local fluidContainer = drinkableFluid(item)
    if fluidContainer == nil then return false end
    if isSealed(item) then return false end
    local thirst = statOf(playerObj, CharacterStat.THIRST)
    if thirst == nil or thirst <= NEED_FLOOR then return true, false end
    local amount = amountIn(fluidContainer)
    if amount == nil or amount <= 0 then return true, false end

    local percent = clampPortion(math.min(thirst * 2, amount) / amount)

    local poured = pcall(ISInventoryPaneContextMenu.onDrinkFluid, item, percent,
        playerObj)
    return true, poured
end
