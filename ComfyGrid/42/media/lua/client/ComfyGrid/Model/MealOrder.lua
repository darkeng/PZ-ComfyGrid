--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.5
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local MealOrder = {}
ComfyGrid.Model.MealOrder = MealOrder

local RANK_FRESH = 1
local RANK_STALE = 2
local RANK_BURNT = 3
local RANK_SPOILED = 4
local RANK_KNOWN_POISON = 5

function MealOrder.isMeal(item)
    if item == nil or not instanceof(item, "Food") then return false end
    if item:getHungChange() >= 0 then return false end
    local script = item:getScriptItem()
    return script == nil or not script:isCantEat()
end

local function rankOf(playerObj, food)
    if playerObj:isKnownPoison(food) then return RANK_KNOWN_POISON end
    if food:isRotten() then return RANK_SPOILED end
    if food:isbDangerousUncooked() and not food:isCooked() then return RANK_SPOILED end
    if food:isBurnt() then return RANK_BURNT end
    if not food:isFresh() then return RANK_STALE end
    return RANK_FRESH
end

local function daysLeft(food)
    local limit = food:isFresh() and food:getOffAge() or food:getOffAgeMax()
    return limit - food:getAge()
end

local function eatsBefore(playerObj, food, other)
    local rank, otherRank = rankOf(playerObj, food), rankOf(playerObj, other)
    if rank ~= otherRank then return rank < otherRank end
    return daysLeft(food) < daysLeft(other)
end

function MealOrder.bestToEat(playerObj, items)
    local best = nil
    for i = 1, #items do
        local food = items[i]
        if instanceof(food, "Food") and rankOf(playerObj, food) <= RANK_STALE
                and (best == nil or eatsBefore(playerObj, food, best)) then
            best = food
        end
    end
    return best
end

function MealOrder.sortForMenu(playerObj, items)
    if playerObj == nil or not MealOrder.isMeal(items[1]) then return end
    local positionOf = {}
    for i = 1, #items do positionOf[items[i]] = i end
    table.sort(items, function(food, other)
        if eatsBefore(playerObj, food, other) then return true end
        if eatsBefore(playerObj, other, food) then return false end
        return positionOf[food] < positionOf[other]
    end)
end
