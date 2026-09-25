--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.9
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
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

local tableWipe = table.wipe
local function wipe(t)
    if tableWipe then
        tableWipe(t)
    else
        for k in pairs(t) do t[k] = nil end
    end
end

function ReflowPlan.homeFor(occupied, cols, row, col, limit)
    if type(cols) ~= "number" or cols < 1 then return nil end
    if row < 0 then row = 0 end
    while row <= limit do
        local bestSlot, bestDist = nil, nil
        for c = 0, cols - 1 do
            local slot = row * cols + c
            if not occupied[slot] then
                local d = c - col
                if d < 0 then d = -d end

                if bestDist == nil or d < bestDist then
                    bestSlot, bestDist = slot, d
                end
            end
        end
        if bestSlot ~= nil then return bestSlot end
        row = row + 1
    end
    return nil
end

local function put(i, stack, slot)
    local e = plan[i]
    if e == nil then
        e = {}
        plan[i] = e
    end
    e.stack = stack
    e.slot = slot
    return e
end

function ReflowPlan.build(stacks, oldCols, newCols)
    if type(stacks) ~= "table" then return nil end
    if type(oldCols) ~= "number" or type(newCols) ~= "number" then return nil end
    if oldCols < 1 or newCols < 1 or oldCols == newCols then return nil end
    local n = #stacks
    if n == 0 then return nil end

    wipe(bySlot)
    local maxSlot = -1
    for i = 1, n do
        local st = stacks[i]
        local slot = type(st) == "table" and st.slot or nil
        if type(slot) ~= "number" or slot < 0 or slot ~= floor(slot) then
            return nil
        end
        if bySlot[slot] ~= nil then

            return nil
        end
        bySlot[slot] = st
        if slot > maxSlot then maxSlot = slot end
    end

    wipe(taken)
    wipe(orphans)
    local k, orphanCount, maxRow = 0, 0, 0
    for slot = 0, maxSlot do
        local st = bySlot[slot]
        if st ~= nil then
            local row = floor(slot / oldCols)
            local col = slot - row * oldCols
            if col < newCols then

                local target = row * newCols + col
                k = k + 1
                put(k, st, target)
                taken[target] = true
                if row > maxRow then maxRow = row end
            else
                orphanCount = orphanCount + 1
                orphans[orphanCount] = st
            end
        end
    end

    for i = 1, orphanCount do
        local st = orphans[i]
        orphans[i] = nil
        local row = floor(st.slot / oldCols)

        local col = st.slot - row * oldCols

        local target = ReflowPlan.homeFor(taken, newCols, row, col,
            maxRow + orphanCount + 1)
        if target == nil then return nil end
        k = k + 1
        put(k, st, target)
        taken[target] = true
    end

    for i = k + 1, planHigh do
        local e = plan[i]
        if e ~= nil then
            e.stack = nil
            e.slot = nil
        end
    end
    planHigh = k
    plan.n = k
    return plan
end
