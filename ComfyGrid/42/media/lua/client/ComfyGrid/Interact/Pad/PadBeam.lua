--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local PadBeam = {}
ComfyGrid.Interact.PadBeam = PadBeam

local EDGE_TOLERANCE = 2

local CONE_SLOPE = 0.7

local DOUBLE_DISTANCE = 2

local function aheadDistance(cursor, rect, dx, dy)
    local gap
    if dx > 0 then gap = rect.x0 - cursor.x1
    elseif dx < 0 then gap = cursor.x0 - rect.x1
    elseif dy > 0 then gap = rect.y0 - cursor.y1
    else gap = cursor.y0 - rect.y1 end
    if gap < -EDGE_TOLERANCE then return nil end
    return gap > 0 and gap or 0
end

local function across(cursor, rect, dx)
    local low, high, bandLow, bandHigh
    if dx ~= 0 then
        low, high, bandLow, bandHigh = rect.y0, rect.y1, cursor.y0, cursor.y1
    else
        low, high, bandLow, bandHigh = rect.x0, rect.x1, cursor.x0, cursor.x1
    end
    local middle, bandMiddle = (low + high) / 2, (bandLow + bandHigh) / 2
    local inCentre = (middle >= bandLow and middle <= bandHigh)
        or (bandMiddle >= low and bandMiddle <= high)
    local offset = middle - bandMiddle
    if offset < 0 then offset = -offset end
    local aside = 0
    if low > bandHigh then aside = low - bandHigh
    elseif high < bandLow then aside = bandLow - high end
    return inCentre, offset, aside
end

local function depthOf(cursor, rect, dx, dy)
    if dx ~= 0 then
        return ((rect.x0 + rect.x1) - (cursor.x0 + cursor.x1)) / 2 * dx
    end
    return ((rect.y0 + rect.y1) - (cursor.y0 + cursor.y1)) / 2 * dy
end

function PadBeam.mayLand(cursor, rect, dx, dy)
    if aheadDistance(cursor, rect, dx, dy) == nil then return false end
    if not rect.far then return true end
    local inCentre = across(cursor, rect, dx)
    return inCentre
end

function PadBeam.nearest(rects, x, y)
    local best, bestScore = nil, nil
    for i = 1, #rects do
        local rect = rects[i]
        local score = -1
        if x < rect.x0 or x >= rect.x1 or y < rect.y0 or y >= rect.y1 then
            local offX = (rect.x0 + rect.x1) / 2 - x
            local offY = (rect.y0 + rect.y1) / 2 - y
            score = offX * offX + offY * offY
        end
        if best == nil or score < bestScore then best, bestScore = i, score end
    end
    return best
end

function PadBeam.pick(cursor, candidates, dx, dy)
    if dx == 0 and dy == 0 then return nil end
    local centre, centreAhead, centreOffset, centreDepth, centreFar = nil, nil, nil, nil, false
    local off, offAhead, offOffset, offDepth = nil, nil, nil, nil
    for i = 1, #candidates do
        local rect = candidates[i]
        local ahead = aheadDistance(cursor, rect, dx, dy)
        if ahead ~= nil then
            local inCentre, offset, aside = across(cursor, rect, dx)
            if inCentre then
                if centre == nil or ahead < centreAhead
                        or (ahead == centreAhead and offset < centreOffset) then
                    centre, centreAhead, centreOffset = i, ahead, offset
                    centreDepth, centreFar = depthOf(cursor, rect, dx, dy), rect.far == true
                end
            elseif not rect.far and aside <= ahead * CONE_SLOPE then
                if off == nil or offset < offOffset
                        or (offset == offOffset and ahead < offAhead) then
                    off, offAhead, offOffset = i, ahead, offset
                    offDepth = depthOf(cursor, rect, dx, dy)
                end
            end
        end
    end
    if centre == nil or off == nil then return centre or off end
    if centreFar then
        if offAhead < centreAhead then return off end
        return centre
    end
    if centreDepth >= DOUBLE_DISTANCE * offDepth then return off end
    return centre
end

return PadBeam
