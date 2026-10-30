--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.7
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Model/Categories"
require "ComfyGrid/Model/ItemSearch"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local SortPlan = {}
ComfyGrid.Model.SortPlan = SortPlan

local Categories = ComfyGrid.Model.Categories
local ItemSearch = ComfyGrid.Model.ItemSearch

local function quantisedTileWeight(stack, inventory)
    if inventory == nil or stack == nil then return 0 end
    local ItemStack = ComfyGrid.Model and ComfyGrid.Model.ItemStack
    if ItemStack == nil or ItemStack.weightOf == nil then return 0 end
    local ok, total = pcall(ItemStack.weightOf, stack, inventory)
    if not ok or type(total) ~= "number" then return 0 end
    return math.floor(total * 100 + 0.5)
end

local function displayNameOf(stack, inventory)
    local ItemStack = ComfyGrid.Model and ComfyGrid.Model.ItemStack
    if inventory ~= nil and ItemStack ~= nil and ItemStack.frontItem ~= nil then
        local ok, item = pcall(ItemStack.frontItem, stack, inventory)
        if ok and item ~= nil and item.getName ~= nil then
            local okName, name = pcall(item.getName, item)
            if okName and name ~= nil then return tostring(name) end
        end
    end
    return tostring(stack.itemType)
end

local SORT_PUNCTUATION = {}
local function markRange(firstCode, lastCode, replacement)
    for code = firstCode, lastCode do SORT_PUNCTUATION[string.char(code)] = replacement end
end
markRange(33, 47, "")
markRange(58, 64, "")
markRange(91, 96, "")
markRange(123, 126, "")
markRange(160, 191, "")
markRange(8192, 8303, "")
markRange(12288, 12351, "")
markRange(65281, 65295, "")
markRange(65306, 65312, "")
markRange(65339, 65344, "")
markRange(65371, 65381, "")

for _, letterCode in ipairs({ 170, 178, 179, 181, 185, 186, 188, 189, 190,
        12293, 12294, 12295 }) do
    SORT_PUNCTUATION[string.char(letterCode)] = nil
end

for _, separatorCode in ipairs({ 45, 47, 95, 160, 183, 8208, 8209, 8210, 8211, 8212,
        8213, 8239, 8287, 12288, 12539, 65293, 65381 }) do
    SORT_PUNCTUATION[string.char(separatorCode)] = " "
end
markRange(8192, 8202, " ")

local function alphabeticalKeyOf(name)
    local key = string.gsub(ItemSearch.fold(name), ".", SORT_PUNCTUATION)
    key = string.gsub(key, " +", " ")
    key = string.gsub(key, "^ ", "")
    key = string.gsub(key, " $", "")
    return key
end

local function tailBefore(keysA, keysB)
    if keysA.category ~= keysB.category then return keysA.category < keysB.category end
    if keysA.nameKey ~= keysB.nameKey then return keysA.nameKey < keysB.nameKey end
    if keysA.name ~= keysB.name then return keysA.name < keysB.name end
    if keysA.identity ~= keysB.identity then return keysA.identity < keysB.identity end
    return keysA.index < keysB.index
end

local COMPARATORS = {}

COMPARATORS.category = function(sortKeysByStack)
    return function(stackA, stackB)
        local keysA, keysB = sortKeysByStack[stackA], sortKeysByStack[stackB]
        if keysA.rank ~= keysB.rank then return keysA.rank < keysB.rank end
        if keysA.sub ~= keysB.sub then return keysA.sub < keysB.sub end
        return tailBefore(keysA, keysB)
    end
end

COMPARATORS.categoryWeight = function(sortKeysByStack)
    return function(stackA, stackB)
        local keysA, keysB = sortKeysByStack[stackA], sortKeysByStack[stackB]
        if keysA.rank ~= keysB.rank then return keysA.rank < keysB.rank end
        if keysA.sub ~= keysB.sub then return keysA.sub < keysB.sub end
        if keysA.weight ~= keysB.weight then return keysA.weight > keysB.weight end
        return tailBefore(keysA, keysB)
    end
end

COMPARATORS.weight = function(sortKeysByStack)
    return function(stackA, stackB)
        local keysA, keysB = sortKeysByStack[stackA], sortKeysByStack[stackB]
        if keysA.weight ~= keysB.weight then return keysA.weight > keysB.weight end
        return tailBefore(keysA, keysB)
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
            local displayName = displayNameOf(stack, inventory)
            sortKeysByStack[stack] = {
                rank = bucketRank,
                sub = subIndex or 0,

                category = tostring(stack.category),
                identity = tostring(stack.itemType),
                name = displayName,
                nameKey = alphabeticalKeyOf(displayName),
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
