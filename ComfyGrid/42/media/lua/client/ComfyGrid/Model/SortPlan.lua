--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.1
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

local function makeComparator(order)
    return function(a, b)
        local oa, ob = order[a], order[b]
        if oa.rank ~= ob.rank then return oa.rank < ob.rank end
        if oa.sub ~= ob.sub then return oa.sub < ob.sub end
        if oa.cat ~= ob.cat then return oa.cat < ob.cat end
        if oa.id ~= ob.id then return oa.id < ob.id end
        return oa.index < ob.index
    end
end

function SortPlan.build(grid)
    if grid == nil or grid.data == nil then return nil end
    local stacks = grid.data.stacks
    if type(stacks) ~= "table" then return nil end

    local inventory = grid.inventory
    local list, order = {}, {}
    for i = 1, #stacks do
        local stack = stacks[i]
        if type(stack) == "table" then
            list[#list + 1] = stack
            local bucketRank, sub = Categories.rankPairOf(stack, inventory)
            order[stack] = {
                rank = bucketRank,
                sub = sub or 0,

                cat = tostring(stack.category),
                id = tostring(stack.itemType),
                index = i,
            }
        end
    end
    local n = #list
    if n == 0 then return nil end

    table.sort(list, makeComparator(order))

    local plan = { n = n }
    local changed = false
    for i = 1, n do
        local stack = list[i]
        local slot = i - 1
        plan[i] = { stack = stack, slot = slot }
        if stack.slot ~= slot then changed = true end
    end

    if not changed then return nil end
    return plan
end
