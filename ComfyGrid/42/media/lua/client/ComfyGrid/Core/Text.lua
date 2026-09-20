--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.6
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Core = ComfyGrid.Core or {}
local Text = {}
ComfyGrid.Core.Text = Text

function Text.tr(key, fallback)
    if type(getText) ~= "function" then return fallback end
    local ok, value = pcall(getText, key)
    if not ok or value == nil or value == key then
        return fallback
    end
    return value
end

local function utf8Ends(s)
    local ends, n = {}, #s
    for i = 1, n do
        local b = string.byte(s, i)
        if (b < 0x80 or b >= 0xC0) and i > 1 then
            ends[#ends + 1] = i - 1
        end
    end
    ends[#ends + 1] = n
    return ends
end

function Text.fit(s, font, maxPx, maxCp)
    if type(s) ~= "string" or s == "" then return s end
    local ends = utf8Ends(s)
    local count = #ends
    local cap = maxCp or count
    if cap > count then cap = count end
    local tm = getTextManager and getTextManager() or nil
    if tm == nil or font == nil or maxPx == nil then
        return s:sub(1, ends[cap])
    end
    for cp = cap, 1, -1 do
        local candidate = s:sub(1, ends[cp])
        local ok, w = pcall(tm.MeasureStringX, tm, font, candidate)
        if not ok then return candidate end
        if w <= maxPx then return candidate end
    end
    return s:sub(1, ends[1])
end

function Text.fitEllipsis(s, font, maxPx, maxCp)
    if type(s) ~= "string" or s == "" then return s end
    local tm = getTextManager and getTextManager() or nil
    if tm == nil or font == nil or maxPx == nil then
        return Text.fit(s, font, maxPx, maxCp)
    end
    local ok, w = pcall(tm.MeasureStringX, tm, font, s)
    if ok and w <= maxPx then
        return Text.fit(s, font, maxPx, maxCp)
    end
    local okE, ew = pcall(tm.MeasureStringX, tm, font, "...")
    local budget = maxPx - (okE and ew or 12)
    if budget < 1 then budget = 1 end
    local trimmed = Text.fit(s, font, budget, maxCp)
    if trimmed == s then return s end
    return trimmed .. "..."
end
