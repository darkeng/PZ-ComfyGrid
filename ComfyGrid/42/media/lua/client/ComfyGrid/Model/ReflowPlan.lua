--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Util"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ReflowPlan = {}
ComfyGrid.Model.ReflowPlan = ReflowPlan

local floor = math.floor

local bySlot = {}
local taken = {}
local orphans = {}
local plan = {}
local planHigh = 0

local wipe = ComfyGrid.Core.Util.wipe

function ReflowPlan.homeFor(occupied, cols, row, col, limit)
    if type(cols) ~= "number" or cols < 1 then return nil end
    if row < 0 then row = 0 end
    while row <= limit do
        local bestSlot, bestDist = nil, nil
        for candidateCol = 0, cols - 1 do
            local slot = row * cols + candidateCol
            if not occupied[slot] then
                local distance = candidateCol - col
                if distance < 0 then distance = -distance end

                if bestDist == nil or distance < bestDist then
                    bestSlot, bestDist = slot, distance
                end
            end
        end
        if bestSlot ~= nil then return bestSlot end
        row = row + 1
    end
    return nil
end

local function writePlanEntry(planIndex, stack, slot)
    local entry = plan[planIndex]
    if entry == nil then
        entry = {}
        plan[planIndex] = entry
    end
    entry.stack = stack
    entry.slot = slot
    return entry
end

function ReflowPlan.build(stacks, oldCols, newCols)
    if type(stacks) ~= "table" then return nil end
    if type(oldCols) ~= "number" or type(newCols) ~= "number" then return nil end
    if oldCols < 1 or newCols < 1 or oldCols == newCols then return nil end
    local stackCount = #stacks
    if stackCount == 0 then return nil end

    wipe(bySlot)
    local maxSlot = -1
    for i = 1, stackCount do
        local stack = stacks[i]
        local slot = type(stack) == "table" and stack.slot or nil
        if type(slot) ~= "number" or slot < 0 or slot ~= floor(slot) then
            return nil
        end
        if bySlot[slot] ~= nil then

            return nil
        end
        bySlot[slot] = stack
        if slot > maxSlot then maxSlot = slot end
    end

    wipe(taken)
    wipe(orphans)
    local planCount, orphanCount, maxRow = 0, 0, 0
    for slot = 0, maxSlot do
        local stack = bySlot[slot]
        if stack ~= nil then
            local row = floor(slot / oldCols)
            local col = slot - row * oldCols
            if col < newCols then

                local target = row * newCols + col
                planCount = planCount + 1
                writePlanEntry(planCount, stack, target)
                taken[target] = true
                if row > maxRow then maxRow = row end
            else
                orphanCount = orphanCount + 1
                orphans[orphanCount] = stack
            end
        end
    end

    for i = 1, orphanCount do
        local stack = orphans[i]
        orphans[i] = nil
        local row = floor(stack.slot / oldCols)

        local col = stack.slot - row * oldCols

        local target = ReflowPlan.homeFor(taken, newCols, row, col,
            maxRow + orphanCount + 1)
        if target == nil then return nil end
        planCount = planCount + 1
        writePlanEntry(planCount, stack, target)
        taken[target] = true
    end

    for i = planCount + 1, planHigh do
        local entry = plan[i]
        if entry ~= nil then
            entry.stack = nil
            entry.slot = nil
        end
    end
    planHigh = planCount
    plan.n = planCount
    return plan
end
