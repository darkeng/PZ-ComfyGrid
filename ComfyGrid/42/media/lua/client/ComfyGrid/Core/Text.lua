--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
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

local function utf8Ends(text)
    local codepointEnds, length = {}, #text
    for i = 1, length do
        local code = string.byte(text, i)
        if (code < 0x80 or code >= 0xC0) and i > 1 then
            codepointEnds[#codepointEnds + 1] = i - 1
        end
    end
    codepointEnds[#codepointEnds + 1] = length
    return codepointEnds
end

function Text.fit(text, font, maxPx, maxCp)
    if type(text) ~= "string" or text == "" then return text end
    local codepointEnds = utf8Ends(text)
    local codepointCount = #codepointEnds
    local cap = maxCp or codepointCount
    if cap > codepointCount then cap = codepointCount end
    local textManager = getTextManager and getTextManager() or nil
    if textManager == nil or font == nil or maxPx == nil then
        return text:sub(1, codepointEnds[cap])
    end
    for codepointIndex = cap, 1, -1 do
        local candidate = text:sub(1, codepointEnds[codepointIndex])
        local ok, widthPx = pcall(textManager.MeasureStringX, textManager, font, candidate)
        if not ok then return candidate end
        if widthPx <= maxPx then return candidate end
    end
    return text:sub(1, codepointEnds[1])
end

function Text.fitEllipsis(text, font, maxPx, maxCp)
    if type(text) ~= "string" or text == "" then return text end
    local textManager = getTextManager and getTextManager() or nil
    if textManager == nil or font == nil or maxPx == nil then
        return Text.fit(text, font, maxPx, maxCp)
    end
    local ok, widthPx = pcall(textManager.MeasureStringX, textManager, font, text)
    if ok and widthPx <= maxPx then
        return Text.fit(text, font, maxPx, maxCp)
    end
    local okEllipsis, ellipsisPx = pcall(textManager.MeasureStringX, textManager, font, "...")
    local budget = maxPx - (okEllipsis and ellipsisPx or 12)
    if budget < 1 then budget = 1 end
    local trimmed = Text.fit(text, font, budget, maxCp)
    if trimmed == text then return text end
    return trimmed .. "..."
end

function Text.formatLoad(load, capacity)
    local loadText = string.format("%.1f", load)
    loadText = loadText:gsub("%.0$", "")
    return loadText .. "/" .. tostring(math.floor(capacity + 0.5))
end
