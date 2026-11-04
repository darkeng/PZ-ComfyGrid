--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.11
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Text"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Chrome/SectionRule"
require "ComfyGrid/UI/Chrome/HoverTip"
require "ComfyGrid/Model/Capacity"
require "ComfyGrid/Model/ContainerModel"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local CarryWeight = {}
ComfyGrid.UI.Chrome.CarryWeight = CarryWeight

local Text = ComfyGrid.Core.Text
local Style = ComfyGrid.UI.Style
local SectionRule = ComfyGrid.UI.Chrome.SectionRule
local HoverTip = ComfyGrid.UI.Chrome.HoverTip
local Capacity = ComfyGrid.Model.Capacity
local ContainerModel = ComfyGrid.Model.ContainerModel

local GLYPH_GAP = 4
local GEAR_GAP = 6
local GLYPH_SHARE = 0.7

local function scaledPixels(basePixels)
    return math.max(2, math.floor(basePixels * (Style.SCALE or 1) + 0.5))
end

local tipText = nil
local function tip()
    if tipText == nil then
        tipText = Text.tr("IGUI_ComfyGrid_CarryWeightTip",
            "The total weight you carry, out of the most you can carry before you're weighed down.")
    end
    return tipText
end

local function measure(text)
    local textManager = getTextManager()
    local ok, width = pcall(textManager.MeasureStringX, textManager, Style.FONT, text)
    if ok and type(width) == "number" then return width end
    return 0
end

local function readLoad(playerNum)
    local playerObj = playerNum ~= nil and getSpecificPlayer(playerNum) or nil
    if playerObj == nil then return nil end
    local model = ContainerModel.getPlayerMain(playerNum)
    local grid = model ~= nil and model.grid or nil
    local load = Capacity.weightOf(playerObj:getInventory(),
        grid ~= nil and grid.changeCount or nil)
    local okMax, maxWeight = pcall(playerObj.getMaxWeight, playerObj)
    if type(load) ~= "number" or not okMax or type(maxWeight) ~= "number" then
        return nil
    end
    return load, maxWeight
end

local function refresh(strip, load, maxWeight)
    local capacity = math.floor(maxWeight + 0.5)
    local key = math.floor(load * 10 + 0.5) * 1000 + capacity
    if strip.carryKey == key and strip.carryFont == Style.FONT
            and strip.carryFontHeight == Style.FONT_H then
        return
    end
    strip.carryKey, strip.carryFont = key, Style.FONT
    strip.carryFontHeight = Style.FONT_H
    strip.carryFull = Text.formatLoad(load, maxWeight)
    strip.carryShort = Text.formatWeight(load)
    strip.carryFullWidth = measure(strip.carryFull)
    strip.carryShortWidth = measure(strip.carryShort)

    local loadDigits = #tostring(math.floor(load + 0.05))
    local templateKey = loadDigits * 100 + #tostring(capacity)
    if strip.carryTemplateKey ~= templateKey or strip.carryTemplateFont ~= Style.FONT
            or strip.carryTemplateFontHeight ~= Style.FONT_H then
        strip.carryTemplateKey = templateKey
        strip.carryTemplateFont, strip.carryTemplateFontHeight = Style.FONT, Style.FONT_H
        local loadTemplate = string.rep("9", loadDigits) .. ".9"
        strip.carryShortReserve = measure(loadTemplate)
        strip.carryFullReserve = measure(loadTemplate .. "/"
            .. string.rep("9", #tostring(capacity)))
    end
end

local function hideTip(strip)
    if strip.carryClaim ~= nil then HoverTip.hide(strip.carryClaim) end
    strip.carryShown = nil
    strip.carryLeft = nil
end

function CarryWeight.place(strip, leftEdge, rightEdge, searchNeeds)
    local page = strip.page
    local Settings = ComfyGrid.Settings
    if page == nil or page.onCharacter ~= true or Settings == nil
            or Settings.get("TITLE_WEIGHT") ~= true then
        hideTip(strip)
        return rightEdge
    end
    local load, maxWeight = readLoad(strip.playerNum)
    if load == nil then
        hideTip(strip)
        return rightEdge
    end
    refresh(strip, load, maxWeight)

    local StackRenderer = ComfyGrid.UI.StackRenderer
    local glyph = StackRenderer ~= nil and StackRenderer.weightTexture ~= nil
        and StackRenderer.weightTexture() or nil
    local fontHeight = Style.FONT_H or 16
    local glyphSize = math.floor(fontHeight * GLYPH_SHARE + 0.5)
    local glyphGap = scaledPixels(GLYPH_GAP)
    local glyphRun = glyph ~= nil and (glyphSize + glyphGap) or 0
    local gearGap = scaledPixels(GEAR_GAP)
    local room = rightEdge - leftEdge - (searchNeeds or 0)

    local text, textWidth, reserve
    if glyphRun + strip.carryFullReserve + gearGap <= room then
        text, textWidth, reserve = strip.carryFull, strip.carryFullWidth, strip.carryFullReserve
    elseif glyphRun + strip.carryShortReserve + gearGap <= room then
        text, textWidth, reserve = strip.carryShort, strip.carryShortWidth, strip.carryShortReserve
    else
        hideTip(strip)
        return rightEdge
    end

    local band = strip.height
    local textRight = rightEdge - gearGap
    local textX = textRight - textWidth
    local color = SectionRule.TEXT
    if glyph ~= nil then
        local glyphX = textX - glyphGap - glyphSize
        strip:drawTextureScaled(glyph, glyphX, math.floor((band - glyphSize) / 2),
            glyphSize, glyphSize, color.a, color.r, color.g, color.b)
    end
    strip:drawText(text, textX, math.floor((band - fontHeight) / 2),
        color.r, color.g, color.b, color.a, Style.FONT)

    local figureLeft = textRight - reserve - glyphRun

    strip.carryShown, strip.carryLeft = text, figureLeft
    if strip.carryClaim == nil then strip.carryClaim = {} end
    local hovered = strip:isMouseOver()
    if hovered then
        local mouseX, mouseY = strip:getMouseX(), strip:getMouseY()
        hovered = mouseX >= figureLeft and mouseX < textRight
            and mouseY >= 0 and mouseY < band
    end
    if hovered then
        HoverTip.show(strip.carryClaim, strip, tip())
    else
        HoverTip.hide(strip.carryClaim)
    end
    return figureLeft
end

return CarryWeight
