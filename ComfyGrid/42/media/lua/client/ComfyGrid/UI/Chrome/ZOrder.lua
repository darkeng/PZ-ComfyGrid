--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Chrome/PopupRegistry"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local ZOrder = {}
ComfyGrid.UI.Chrome.ZOrder = ZOrder

local PopupRegistry = ComfyGrid.UI.Chrome.PopupRegistry

local order = {}
local pages = {}

local PAGE_GETTERS = { getPlayerInventory, getPlayerLoot }

local targets = {}

local want = {}
local depths = {}

local function javaOf(el)
    return el ~= nil and el.javaObject or nil
end

local function depthsOf(uis, list, count)
    local wanted = 0
    for k = 1, count do
        depths[k] = nil
        local java = javaOf(list[k])
        if java ~= nil and want[java] == nil then
            want[java] = k
            wanted = wanted + 1
        end
    end
    local i = uis:size() - 1
    while wanted > 0 and i >= 0 do
        local k = want[uis:get(i)]
        if k ~= nil and depths[k] == nil then
            depths[k] = i
            wanted = wanted - 1
        end
        i = i - 1
    end

    for k = 1, count do
        local java = javaOf(list[k])
        local first = java ~= nil and want[java] or nil
        if first ~= nil and first ~= k then depths[k] = depths[first] end
    end
    for k = 1, count do
        local java = javaOf(list[k])
        if java ~= nil then want[java] = nil end
    end
    return depths
end

local function pagesOf(playerNum, out)
    local n = 0
    for _, get in ipairs(PAGE_GETTERS) do
        local ok, page = pcall(get, playerNum)
        if ok and page ~= nil and page:getIsVisible() then
            n = n + 1
            out[n] = page
        end
    end
    return n
end

local collected = 0
local function takePopup(popup)
    if popup == nil or popup.getIsVisible == nil then return end
    if not popup:getIsVisible() then return end
    collected = collected + 1
    order[collected] = popup
end

local function collect(playerNum)
    collected = 0
    local CW = ComfyGrid.UI.ContainerWindow
    local win = (CW ~= nil and CW.windowFor ~= nil) and CW.windowFor(playerNum)
        or nil
    if win ~= nil and win:getIsVisible() then
        collected = 1
        order[1] = win
    end

    if PopupRegistry ~= nil and PopupRegistry.forEach ~= nil then
        PopupRegistry.forEach(takePopup)
    end
    for i = #order, collected + 1, -1 do order[i] = nil end
    return collected
end

function ZOrder.enforce(playerNum)
    playerNum = playerNum or 0
    local n = collect(playerNum)
    if n == 0 then return false end

    local uis = UIManager.getUI()
    if uis == nil then return false end

    local pageCount = pagesOf(playerNum, pages)

    for i = 1, pageCount do targets[i] = pages[i] end
    for i = 1, n do targets[pageCount + i] = order[i] end
    local total = pageCount + n
    for i = #targets, total + 1, -1 do targets[i] = nil end
    local depth = depthsOf(uis, targets, total)
    local floor = -1
    for i = 1, pageCount do
        local d = depth[i]
        if d ~= nil and d > floor then floor = d end
    end

    local wrong = false
    local prev = floor
    for i = 1, n do
        local d = depth[pageCount + i]
        if d == nil or d < prev then wrong = true break end
        prev = d
    end
    if not wrong then return false end

    for i = 1, n do
        local el = order[i]
        if el.bringToTop ~= nil then pcall(el.bringToTop, el) end
    end
    return true
end
