--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.7
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

local function depthOf(uis, el)
    local java = el ~= nil and el.javaObject or nil
    if java == nil then return nil end
    for i = 0, uis:size() - 1 do
        if uis:get(i) == java then return i end
    end
    return nil
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
    local floor = -1
    for i = 1, pageCount do
        local d = depthOf(uis, pages[i])
        if d ~= nil and d > floor then floor = d end
    end

    local wrong = false
    local prev = floor
    for i = 1, n do
        local d = depthOf(uis, order[i])
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
