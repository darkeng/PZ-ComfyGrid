--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
require "ComfyGrid/UI/Chrome/HoverTip"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local Chip = {}
ComfyGrid.UI.Chrome.Chip = Chip

local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw
local HoverTip = ComfyGrid.UI.Chrome.HoverTip

local function gap()
    return math.max(3, math.floor(6 * (Style.SCALE or 1) + 0.5))
end

function Chip.size()
    return math.max(12, math.floor(16 * (Style.SCALE or 1) + 0.5))
end

function Chip.sizeIn(bandHeight)
    local diameter = Chip.size()
    if bandHeight ~= nil and bandHeight > 0 then
        diameter = math.min(diameter, math.max(10, math.floor(bandHeight) - 4))
    end
    return diameter
end

function Chip.groupWidth(chipCount, bandHeight)
    if chipCount == nil or chipCount < 1 then return 0 end
    return chipCount * Chip.sizeIn(bandHeight) + (chipCount - 1) * gap()
end

local function showTip(row, text, x, y, diameter)
    local owner = row.owner
    if owner == nil or owner.getAbsoluteX == nil then return end
    HoverTip.show(row, owner, text, owner:getAbsoluteX() + x,
        owner:getAbsoluteY() + y + diameter + 8)
end

local function hideTip(row)
    HoverTip.hide(row)
end

local Row = {}
Row.__index = Row
Chip.Row = Row

function Chip.newRow(owner)
    return setmetatable({
        owner = owner,
        _rects = {},
        count = 0,
        consumed = 0,
        _rightX = 0,
        _leftX = nil,
        _y = 0,
        _h = 0,
        _tipped = false,
        hotId = nil,

        padHot = nil,
        _over = false,
        _mx = 0,
        _my = 0,
    }, Row)
end

local function clearRects(self)
    self.count = 0
    self.consumed = 0

    self.hotId = nil
end

function Row:clear()
    clearRects(self)
    if not self._tipped then hideTip(self) end
    self._tipped = false
end

local function probeCursor(row)
    local owner = row.owner
    row._over = owner ~= nil and owner.isMouseOver ~= nil
        and owner:isMouseOver() == true
    if row._over then
        row._mx, row._my = owner:getMouseX(), owner:getMouseY()
    end
end

function Row:reset(rightX, y, h)
    clearRects(self)
    self._leftX = nil
    self._rightX = rightX
    self._y = y
    self._h = h
    probeCursor(self)
end

function Row:resetLeft(leftX, y, h)
    clearRects(self)
    self._leftX = leftX
    self._y = y
    self._h = h
    probeCursor(self)
end

function Row:add(id, tex, tip, active)
    local owner = self.owner
    local surface = Style.COLORS and Style.COLORS.SURFACE
    if owner == nil or surface == nil or tex == nil then return 0 end

    local diameter = Chip.sizeIn(self._h)
    local x
    if self._leftX ~= nil then
        x = self._leftX + self.consumed
    else
        x = self._rightX - self.consumed - diameter
    end
    local y = self._y + math.floor((self._h - diameter) / 2)

    local hitY, hitHeight = self._y, self._h
    local hot = false
    if self._over then
        local mx, my = self._mx, self._my
        hot = mx >= x and mx < x + diameter
            and my >= hitY and my < hitY + hitHeight
    end

    if not hot and self.padHot ~= nil and self.padHot == id then hot = true end
    if hot then self.hotId = id end

    if hot and tip ~= nil then
        self._tipped = true
        showTip(self, tip, x, y, diameter)
    end

    Draw.disc(owner, x, y, diameter, 1, hot and surface.accent or surface.line)

    local fill = surface.card
    if active then
        fill = surface.accent
    elseif hot then
        fill = surface.cardHi
    end
    Draw.disc(owner, x + 1, y + 1, diameter - 2, 1, fill)

    local glyphSize = math.floor(diameter * 0.68 + 0.5)
    local glyphInset = math.floor((diameter - glyphSize) * 0.5)
    local glyphR, glyphG, glyphB = surface.accent.r, surface.accent.g,
        surface.accent.b
    if active then
        glyphR, glyphG, glyphB = surface.bg.r, surface.bg.g, surface.bg.b
    end
    owner:drawTextureScaled(tex, x + glyphInset, y + glyphInset, glyphSize,
        glyphSize, (hot or active) and 1 or 0.85, glyphR, glyphG, glyphB)

    local slot = self.count + 1
    self.count = slot
    local rect = self._rects[slot]
    if rect == nil then
        rect = {}
        self._rects[slot] = rect
    end

    rect.id, rect.x, rect.y, rect.s = id, x, y, diameter
    rect.hy, rect.hh = hitY, hitHeight

    local used = diameter + gap()
    self.consumed = self.consumed + used
    return used
end

function Row:rectOf(id)
    for i = 1, self.count do
        local rect = self._rects[i]
        if rect.id == id then return rect end
    end
    return nil
end

function Row:idAt(i)
    if i < 1 or i > self.count then return nil end
    local rect = self._rects[i]
    return rect ~= nil and rect.id or nil
end

function Row:hit(x, y)
    for i = 1, self.count do
        local rect = self._rects[i]
        if x >= rect.x and x < rect.x + rect.s
                and y >= rect.hy and y < rect.hy + rect.hh then
            return rect.id
        end
    end
    return nil
end
