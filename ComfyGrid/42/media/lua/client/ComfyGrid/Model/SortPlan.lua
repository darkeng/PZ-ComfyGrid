--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Model/Categories"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local SortPlan = {}
ComfyGrid.Model.SortPlan = SortPlan

local Categories = ComfyGrid.Model.Categories

local function quantisedTileWeight(stack, inventory)
    if inventory == nil or stack == nil then return 0 end
    local ItemStack = ComfyGrid.Model and ComfyGrid.Model.ItemStack
    if ItemStack == nil or ItemStack.weightOf == nil then return 0 end
    local ok, total = pcall(ItemStack.weightOf, stack, inventory)
    if not ok or type(total) ~= "number" then return 0 end
    return math.floor(total * 100 + 0.5)
end

local COMPARATORS = {}

COMPARATORS.category = function(sortKeysByStack)
    return function(stackA, stackB)
        local keysA, keysB = sortKeysByStack[stackA], sortKeysByStack[stackB]
        if keysA.rank ~= keysB.rank then return keysA.rank < keysB.rank end
        if keysA.sub ~= keysB.sub then return keysA.sub < keysB.sub end
        if keysA.category ~= keysB.category then
            return keysA.category < keysB.category
        end
        if keysA.identity ~= keysB.identity then
            return keysA.identity < keysB.identity
        end
        return keysA.index < keysB.index
    end
end

COMPARATORS.categoryWeight = function(sortKeysByStack)
    return function(stackA, stackB)
        local keysA, keysB = sortKeysByStack[stackA], sortKeysByStack[stackB]
        if keysA.rank ~= keysB.rank then return keysA.rank < keysB.rank end
        if keysA.sub ~= keysB.sub then return keysA.sub < keysB.sub end
        if keysA.weight ~= keysB.weight then return keysA.weight > keysB.weight end
        if keysA.category ~= keysB.category then
            return keysA.category < keysB.category
        end
        if keysA.identity ~= keysB.identity then
            return keysA.identity < keysB.identity
        end
        return keysA.index < keysB.index
    end
end

COMPARATORS.weight = function(sortKeysByStack)
    return function(stackA, stackB)
        local keysA, keysB = sortKeysByStack[stackA], sortKeysByStack[stackB]
        if keysA.weight ~= keysB.weight then return keysA.weight > keysB.weight end
        if keysA.category ~= keysB.category then
            return keysA.category < keysB.category
        end
        if keysA.identity ~= keysB.identity then
            return keysA.identity < keysB.identity
        end
        return keysA.index < keysB.index
    end
end

function SortPlan.comparatorFor(name)
    return COMPARATORS[name] or COMPARATORS.category
end

function SortPlan.build(grid, orderName)
    if grid == nil or grid.data == nil then return nil end
    local stacks = grid.data.stacks
    if type(stacks) ~= "table" then return nil end

    local inventory = grid.inventory

    local needWeight = orderName == "weight" or orderName == "categoryWeight"
    local sortedStacks, sortKeysByStack = {}, {}
    for i = 1, #stacks do
        local stack = stacks[i]
        if type(stack) == "table" then
            sortedStacks[#sortedStacks + 1] = stack
            local bucketRank, subIndex = Categories.rankPairOf(stack, inventory)
            sortKeysByStack[stack] = {
                rank = bucketRank,
                sub = subIndex or 0,

                category = tostring(stack.category),
                identity = tostring(stack.itemType),
                weight = needWeight and quantisedTileWeight(stack, inventory) or 0,
                index = i,
            }
        end
    end
    local stackCount = #sortedStacks
    if stackCount == 0 then return nil end

    table.sort(sortedStacks, SortPlan.comparatorFor(orderName)(sortKeysByStack))

    local plan = { n = stackCount }
    local changed = false
    for i = 1, stackCount do
        local stack = sortedStacks[i]
        local slot = i - 1
        plan[i] = { stack = stack, slot = slot }
        if stack.slot ~= slot then changed = true end
    end

    if not changed then return nil end
    return plan
end
