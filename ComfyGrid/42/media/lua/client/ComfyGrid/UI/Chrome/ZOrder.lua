--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
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

local floatingSurfaces = {}
local pages = {}

local PAGE_GETTERS = { getPlayerInventory, getPlayerLoot }

local depthQuery = {}

local slotByJavaObject = {}
local depthScratch = {}

local function javaObjectOf(element)
    return element ~= nil and element.javaObject or nil
end

local function depthsOf(engineList, elements, elementCount)
    local unresolvedCount = 0
    for slot = 1, elementCount do
        depthScratch[slot] = nil
        local javaObject = javaObjectOf(elements[slot])
        if javaObject ~= nil and slotByJavaObject[javaObject] == nil then
            slotByJavaObject[javaObject] = slot
            unresolvedCount = unresolvedCount + 1
        end
    end
    local listIndex = engineList:size() - 1
    while unresolvedCount > 0 and listIndex >= 0 do
        local slot = slotByJavaObject[engineList:get(listIndex)]
        if slot ~= nil and depthScratch[slot] == nil then
            depthScratch[slot] = listIndex
            unresolvedCount = unresolvedCount - 1
        end
        listIndex = listIndex - 1
    end

    for slot = 1, elementCount do
        local javaObject = javaObjectOf(elements[slot])
        local firstSlot = javaObject ~= nil and slotByJavaObject[javaObject] or nil
        if firstSlot ~= nil and firstSlot ~= slot then
            depthScratch[slot] = depthScratch[firstSlot]
        end
    end
    for slot = 1, elementCount do
        local javaObject = javaObjectOf(elements[slot])
        if javaObject ~= nil then slotByJavaObject[javaObject] = nil end
    end
    return depthScratch
end

local function pagesOf(playerNum, pagesOut)
    local pageCount = 0
    for _, getPage in ipairs(PAGE_GETTERS) do
        local ok, page = pcall(getPage, playerNum)
        if ok and page ~= nil and page:getIsVisible() then
            pageCount = pageCount + 1
            pagesOut[pageCount] = page
        end
    end
    return pageCount
end

local collected = 0
local function takePopup(popup)
    if popup == nil or popup.getIsVisible == nil then return end
    if not popup:getIsVisible() then return end
    collected = collected + 1
    floatingSurfaces[collected] = popup
end

local function collect(playerNum)
    collected = 0
    local ContainerWindow = ComfyGrid.UI.ContainerWindow
    local win = (ContainerWindow ~= nil and ContainerWindow.windowFor ~= nil)
        and ContainerWindow.windowFor(playerNum) or nil
    if win ~= nil and win:getIsVisible() then
        collected = 1
        floatingSurfaces[1] = win
    end

    if PopupRegistry ~= nil and PopupRegistry.forEach ~= nil then
        PopupRegistry.forEach(takePopup)
    end
    for i = #floatingSurfaces, collected + 1, -1 do floatingSurfaces[i] = nil end
    return collected
end

function ZOrder.enforce(playerNum)
    playerNum = playerNum or 0
    local floatCount = collect(playerNum)
    if floatCount == 0 then return false end

    local engineList = UIManager.getUI()
    if engineList == nil then return false end

    local pageCount = pagesOf(playerNum, pages)

    for i = 1, pageCount do depthQuery[i] = pages[i] end
    for i = 1, floatCount do depthQuery[pageCount + i] = floatingSurfaces[i] end
    local total = pageCount + floatCount
    for i = #depthQuery, total + 1, -1 do depthQuery[i] = nil end
    local depthBySlot = depthsOf(engineList, depthQuery, total)
    local pageFloorDepth = -1
    for i = 1, pageCount do
        local pageDepth = depthBySlot[i]
        if pageDepth ~= nil and pageDepth > pageFloorDepth then
            pageFloorDepth = pageDepth
        end
    end

    local wrong = false
    local previousDepth = pageFloorDepth
    for i = 1, floatCount do
        local floatDepth = depthBySlot[pageCount + i]
        if floatDepth == nil or floatDepth < previousDepth then wrong = true break end
        previousDepth = floatDepth
    end
    if not wrong then return false end

    for i = 1, floatCount do
        local surface = floatingSurfaces[i]
        if surface.bringToTop ~= nil then pcall(surface.bringToTop, surface) end
    end
    return true
end
