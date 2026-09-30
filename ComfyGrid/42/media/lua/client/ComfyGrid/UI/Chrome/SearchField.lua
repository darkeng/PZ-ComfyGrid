--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Text"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
require "ComfyGrid/Model/ItemSearch"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local SearchField = ISTextEntryBox:derive("ComfySearchField")
ComfyGrid.UI.Chrome.SearchField = SearchField

local Text = ComfyGrid.Core.Text
local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw
local ItemSearch = ComfyGrid.Model.ItemSearch

local WIDTH_SHARE = 0.5

local TYPING_PAUSE_MS = 200

local MAX_FIELD_SLOTS = 8

local function scaledPixels(basePixels)
    return math.max(2, math.floor(basePixels * (Style.SCALE or 1) + 0.5))
end

local placeholderString = nil
local function placeholder()
    if placeholderString == nil then
        placeholderString = Text.tr("IGUI_FilterSearch", "Search...")
    end
    return placeholderString
end

local placeholderWidth, placeholderWidthFontHeight = 0, nil
local function placeholderPixels()
    if placeholderWidthFontHeight ~= Style.FONT_H then
        local textManager = getTextManager()
        local measured, width = pcall(textManager.MeasureStringX, textManager,
            Style.FONT or UIFont.Small, placeholder())
        placeholderWidth = measured and width or 60
        placeholderWidthFontHeight = Style.FONT_H
    end
    return placeholderWidth
end

function SearchField:new(page)
    local o = ISTextEntryBox.new(self, "", 0, 0, 1, 1)
    o.page = page
    o.font = Style.FONT or UIFont.Small
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.placed = false
    o.plateX, o.plateY, o.plateW, o.plateH = 0, 0, 0, 0
    o.clearX, o.clearY, o.clearSize = 0, 0, 0
    return o
end

function SearchField:instantiate()
    ISTextEntryBox.instantiate(self)
    self:setPlaceholderText(placeholder())
    local surface = Style.COLORS and Style.COLORS.SURFACE or nil
    if surface ~= nil then
        self:setPlaceholderTextRGBA(surface.line.r, surface.line.g, surface.line.b, 1)
    end
end

function SearchField.prerender(_self)
end

function SearchField:onTextChange()
    if ItemSearch.isSearchable(self:getInternalText()) then
        self.pendingSinceMs = getTimestampMs()
    else
        self:commitTerm()
    end
end

function SearchField:commitTerm()
    self.pendingSinceMs = nil
    ItemSearch.setTerm(self.page, self:getInternalText())
end

function SearchField:applyPendingTerm()
    local pendingSinceMs = self.pendingSinceMs
    if pendingSinceMs == nil then return end
    if getTimestampMs() - pendingSinceMs >= TYPING_PAUSE_MS then self:commitTerm() end
end

function SearchField:onCommandEntered()
    self:commitTerm()
    self:unfocus()
end

function SearchField:onOtherKey(key)
    if key == Keyboard.KEY_ESCAPE then
        self:clearSearch()
        self:unfocus()
    end
end

function SearchField:hasText()
    if self.javaObject == nil then return false end
    local text = self:getInternalText()
    return text ~= nil and text ~= ""
end

function SearchField:clearSearch()
    self:setText("")
    self:commitTerm()
end

local function hideForRoom(self)
    self.placed = false
    if self.javaObject ~= nil and self:isFocused() then self:unfocus() end
    if self:getIsVisible() then self:setVisible(false) end
end

local function moveTo(self, x, y, width, height)
    if self.x ~= x then self:setX(x) end
    if self.y ~= y then self:setY(y) end
    if self.width ~= width then self:setWidth(width) end
    if self.height ~= height then self:setHeight(height) end
end

local function layoutInputsChanged(self, band, width, leftEdge, rightEdge)
    if self.layoutBand == band and self.layoutWidth == width
            and self.layoutLeft == leftEdge and self.layoutRight == rightEdge
            and self.layoutScale == Style.SCALE
            and self.layoutFont == Style.FONT
            and self.layoutFontHeight == Style.FONT_H then
        return false
    end
    self.layoutBand, self.layoutWidth = band, width
    self.layoutLeft, self.layoutRight = leftEdge, rightEdge
    self.layoutScale, self.layoutFont = Style.SCALE, Style.FONT
    self.layoutFontHeight = Style.FONT_H
    return true
end

local ENGINE_TEXT_INSET = 2

local function lineHeightOf(font)
    local measured, lineHeight = pcall(function()
        return getTextManager():getFontFromEnum(font):getLineHeight()
    end)
    if measured and type(lineHeight) == "number" and lineHeight > 0 then return lineHeight end
    return Style.FONT_H or 16
end

function SearchField:layoutIn(strip, leftEdge, rightEdge)
    if layoutInputsChanged(self, strip.height, strip.width, leftEdge, rightEdge) then
        self:computeLayout(strip, leftEdge, rightEdge)
    end
    if self.placed then self:drawPlate(strip) end
end

function SearchField:computeLayout(strip, leftEdge, rightEdge)

    local headerFont = Style.FONT or UIFont.Small
    if self.font ~= headerFont then self:setFont(headerFont) end
    local band = strip.height
    local sideMargin = scaledPixels(6)
    local textInset = scaledPixels(8)
    local lineHeight = lineHeightOf(self.font)
    local plateHeight = math.min(band - 2,
        math.max(lineHeight + 2, band - 2 * scaledPixels(4)))
    local clearSize = math.max(8, plateHeight - scaledPixels(8))
    local minimumWidth = placeholderPixels() + 2 * textInset + clearSize
    local freeLeft = leftEdge + sideMargin
    local freeRight = rightEdge - sideMargin
    local wantedWidth = math.floor(strip.width * WIDTH_SHARE)
    local centre = math.floor(strip.width / 2)
    local halfRoom = math.min(centre - freeLeft, freeRight - centre)
    local plateWidth, plateX
    if 2 * halfRoom >= minimumWidth then
        plateWidth = math.max(minimumWidth, math.min(wantedWidth, 2 * halfRoom))
        plateX = centre - math.floor(plateWidth / 2)
    elseif freeRight - freeLeft >= minimumWidth then
        plateWidth = math.max(minimumWidth, math.min(wantedWidth, freeRight - freeLeft))
        plateX = freeLeft + math.floor((freeRight - freeLeft - plateWidth) / 2)
    else
        hideForRoom(self)
        return
    end
    local plateY = math.floor((band - plateHeight) / 2)
    self.plateX, self.plateY, self.plateW, self.plateH = plateX, plateY,
        plateWidth, plateHeight
    self.clearSize = clearSize
    self.clearX = plateX + plateWidth - scaledPixels(4) - clearSize
    self.clearY = plateY + math.floor((plateHeight - clearSize) / 2)
    self.placed = true
    if not self:getIsVisible() then self:setVisible(true) end

    local entryHeight = lineHeight + 2 * ENGINE_TEXT_INSET
    moveTo(self, plateX + textInset,
        plateY + math.floor((plateHeight - entryHeight) / 2),
        self.clearX - scaledPixels(2) - (plateX + textInset), entryHeight)
end

function SearchField:drawPlate(strip)
    local surface = Style.COLORS and Style.COLORS.SURFACE or nil
    if surface == nil then return end
    local focused = self.javaObject ~= nil and self:isFocused()

    Draw.pillFrame(strip, self.plateX, self.plateY, self.plateW, self.plateH, 1,
        focused and surface.accent or surface.line, surface.card)
    if self:hasText() then
        local clearTexture = Draw.closeTexture()
        if clearTexture ~= nil then
            local hot = strip:isMouseOver()
                and self:clearContains(strip:getMouseX(), strip:getMouseY())
            strip:drawTextureScaled(clearTexture, self.clearX, self.clearY,
                self.clearSize, self.clearSize, hot and 1 or 0.7,
                surface.accent.r, surface.accent.g, surface.accent.b)
        end
    end
end

function SearchField:plateContains(x, y)
    return self.placed and x >= self.plateX and x < self.plateX + self.plateW
        and y >= self.plateY and y < self.plateY + self.plateH
end

function SearchField:clearContains(x, y)
    if not self.placed or not self:hasText() then return false end
    local slack = scaledPixels(3)
    return x >= self.clearX - slack and x < self.clearX + self.clearSize + slack
        and y >= self.plateY and y < self.plateY + self.plateH
end

local registeredFields = {}

local function slotOf(page)
    local seat = page.player or 0
    return seat * 2 + (page.onCharacter and 1 or 2)
end

function SearchField.register(page, field)
    local slot = slotOf(page)
    if slot < 1 or slot > MAX_FIELD_SLOTS then return end
    local previous = registeredFields[slot]
    if previous ~= nil and previous ~= field and previous.javaObject ~= nil
            and previous:isFocused() then
        previous:unfocus()
    end
    registeredFields[slot] = field
end

function SearchField.onPageClosed(page)
    local strip = page._comfyStrip
    local field = strip ~= nil and strip.searchField or nil
    if field == nil or field.javaObject == nil then
        ItemSearch.setTerm(page, "")
        return
    end
    if field:isFocused() then field:unfocus() end
    field:clearSearch()
end

function SearchField._onTick()
    for slot = 1, MAX_FIELD_SLOTS do
        local field = registeredFields[slot]
        if field ~= nil and field.javaObject ~= nil and field:isFocused()
                and not field:isReallyVisible() then
            field:unfocus()
        end
    end
end

if not ComfyGrid._searchFieldHooked then
    ComfyGrid._searchFieldHooked = true
    Events.OnTick.Add(function()
        local chrome = ComfyGrid.UI and ComfyGrid.UI.Chrome
        local searchFieldModule = chrome ~= nil and chrome.SearchField or nil
        if searchFieldModule ~= nil and searchFieldModule._onTick ~= nil then
            searchFieldModule._onTick()
        end
    end)
end
