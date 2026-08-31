--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.0
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

function Chip.sizeIn(h)
    local s = Chip.size()
    if h ~= nil and h > 0 then
        s = math.min(s, math.max(10, math.floor(h) - 4))
    end
    return s
end

function Chip.groupWidth(n, h)
    if n == nil or n < 1 then return 0 end
    return n * Chip.sizeIn(h) + (n - 1) * gap()
end

local function showTip(row, text, x, y, s)
    local owner = row.owner
    if owner == nil or owner.getAbsoluteX == nil then return end
    HoverTip.show(row, owner, text, owner:getAbsoluteX() + x,
        owner:getAbsoluteY() + y + s + 8)
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

function Row:reset(rightX, y, h)
    clearRects(self)
    self._leftX = nil
    self._rightX = rightX
    self._y = y
    self._h = h

    local owner = self.owner
    self._over = owner ~= nil and owner.isMouseOver ~= nil
        and owner:isMouseOver() == true
    if self._over then
        self._mx, self._my = owner:getMouseX(), owner:getMouseY()
    end
end

function Row:resetLeft(leftX, y, h)
    clearRects(self)
    self._leftX = leftX
    self._y = y
    self._h = h
    local owner = self.owner
    self._over = owner ~= nil and owner.isMouseOver ~= nil
        and owner:isMouseOver() == true
    if self._over then
        self._mx, self._my = owner:getMouseX(), owner:getMouseY()
    end
end

function Row:add(id, tex, tip, active)
    local owner = self.owner
    local sf = Style.COLORS and Style.COLORS.SURFACE
    if owner == nil or sf == nil or tex == nil then return 0 end

    local s = Chip.sizeIn(self._h)
    local x
    if self._leftX ~= nil then
        x = self._leftX + self.consumed
    else
        x = self._rightX - self.consumed - s
    end
    local y = self._y + math.floor((self._h - s) / 2)

    local hy, hh = self._y, self._h
    local hot = false
    if self._over then
        local mx, my = self._mx, self._my
        hot = mx >= x and mx < x + s and my >= hy and my < hy + hh
    end

    if not hot and self.padHot ~= nil and self.padHot == id then hot = true end
    if hot then self.hotId = id end

    if hot and tip ~= nil then
        self._tipped = true
        showTip(self, tip, x, y, s)
    end

    Draw.disc(owner, x, y, s, 1, hot and sf.accent or sf.line)

    local fill = sf.card
    if active then
        fill = sf.accent
    elseif hot then
        fill = sf.cardHi
    end
    Draw.disc(owner, x + 1, y + 1, s - 2, 1, fill)

    local g = math.floor(s * 0.68 + 0.5)
    local off = math.floor((s - g) * 0.5)
    local gr, gg, gb = sf.accent.r, sf.accent.g, sf.accent.b
    if active then gr, gg, gb = sf.bg.r, sf.bg.g, sf.bg.b end
    owner:drawTextureScaled(tex, x + off, y + off, g, g,
        (hot or active) and 1 or 0.85, gr, gg, gb)

    local n = self.count + 1
    self.count = n
    local rect = self._rects[n]
    if rect == nil then
        rect = {}
        self._rects[n] = rect
    end

    rect.id, rect.x, rect.y, rect.s = id, x, y, s
    rect.hy, rect.hh = hy, hh

    local used = s + gap()
    self.consumed = self.consumed + used
    return used
end

function Row:rectOf(id)
    for i = 1, self.count do
        local r = self._rects[i]
        if r.id == id then return r end
    end
    return nil
end

function Row:idAt(i)
    if i < 1 or i > self.count then return nil end
    local r = self._rects[i]
    return r ~= nil and r.id or nil
end

function Row:hit(x, y)
    for i = 1, self.count do
        local r = self._rects[i]
        if x >= r.x and x < r.x + r.s
                and y >= r.hy and y < r.hy + r.hh then
            return r.id
        end
    end
    return nil
end
