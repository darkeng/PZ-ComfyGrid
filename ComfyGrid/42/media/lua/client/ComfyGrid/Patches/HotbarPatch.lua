--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.7.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
require "ComfyGrid/UI/HotbarGhosts"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/UI/StackRenderer"

local lastError = nil

local ammoWidths = {}

local function hidden(self)
    return (self.playerNum ~= nil and self.playerNum > 0)
        or (JoypadState.players ~= nil
            and JoypadState.players[(self.playerNum or 0) + 1] ~= nil)
end

local function barEnabled()
    local S = ComfyGrid.Settings
    if S == nil or S.get == nil then return true end
    return S.get("HOTBAR_BAR") ~= false
end

local function snapshot(self)
    if self._comfyHotbarOg ~= nil then return end
    self._comfyHotbarOg = {
        slotWidth = self.slotWidth,
        slotHeight = self.slotHeight,
        slotPad = self.slotPad,
        margins = self.margins,
        height = self.height,
    }
end

local function restoreMetrics(self)
    local og = self._comfyHotbarOg
    if og == nil then return false end
    if self.slotWidth == og.slotWidth and self.slotHeight == og.slotHeight
            and self.slotPad == og.slotPad and self.margins == og.margins then
        return false
    end
    self.slotWidth = og.slotWidth
    self.slotHeight = og.slotHeight
    self.slotPad = og.slotPad
    self.margins = og.margins
    if og.height ~= nil then self:setHeight(og.height) end
    return true
end

local function applyMetrics(self)

    snapshot(self)
    if not barEnabled() then return restoreMetrics(self) end
    local Style = ComfyGrid.UI.Style
    local cell = Style ~= nil and Style.CELL or nil
    if cell == nil or cell < 8 then return false end
    local pad = math.max(2, math.floor(cell * 0.12 + 0.5))
    if self.slotWidth == cell and self.slotHeight == cell
            and self.slotPad == pad and self.margins == pad then
        return false
    end
    self.slotWidth = cell
    self.slotHeight = cell
    self.slotPad = pad
    self.margins = pad
    self:setHeight(cell + pad * 2 + 2)
    return true
end

local function drawSlotBody(self, x, y, size, item, hot, refused, slot)
    local Style = ComfyGrid.UI.Style
    local SlotRenderer = ComfyGrid.UI.SlotRenderer
    local colors = Style.COLORS
    local tex = SlotRenderer ~= nil and SlotRenderer.getTileTexture ~= nil
        and SlotRenderer.getTileTexture() or nil

    if item == nil and SlotRenderer ~= nil and SlotRenderer.drawSocket ~= nil then
        SlotRenderer.drawSocket({ view = self, x = x, y = y }, size)
        local Ghosts = ComfyGrid.UI.HotbarGhosts
        if slot ~= nil and Ghosts ~= nil and Ghosts.texFor ~= nil then
            local g = Ghosts.texFor(slot)
            if g ~= nil then SlotRenderer.drawGhost(self, g, x, y, size) end
        end
    else
        local fill = (colors and colors.EMPTY_CELL)
            or { r = 0.148, g = 0.135, b = 0.116, a = 1 }
        if tex ~= nil then
            self:drawTextureScaled(tex, x, y, size, size,
                fill.a or 1, fill.r, fill.g, fill.b)
        else
            self:drawRect(x, y, size, size, fill.a or 1, fill.r, fill.g, fill.b)
        end
    end

    if hot then
        local wash = refused and { r = 1, g = 0.25, b = 0.2, a = 0.28 }
            or (colors and colors.HOVER) or { r = 1, g = 1, b = 1, a = 0.12 }
        if tex ~= nil then
            self:drawTextureScaled(tex, x, y, size, size,
                wash.a, wash.r, wash.g, wash.b)
        else
            self:drawRect(x, y, size, size, wash.a, wash.r, wash.g, wash.b)
        end
    end

    if item == nil then return end

    local pad = math.max(2, math.floor(size * 0.14 + 0.5))
    local box = size - pad * 2
    self:drawItemIcon(item, x + pad, y + pad, 1, box, box)
end

local function drawReadouts(self, x, y, size, item)
    local sr = ComfyGrid.UI and ComfyGrid.UI.StackRenderer
    if sr == nil or sr.overlayInfo == nil then return end

    if item.isBroken and item:isBroken() and sr.drawBrokenMark ~= nil then
        sr.drawBrokenMark(self, x, y, size)
    end
    local frac, col, ammoText = sr.overlayInfo(item)
    if frac ~= nil and col ~= nil then

        local area = size - 10
        local barH = math.floor(area * frac + 0.5)
        if barH < 2 and frac > 0 then barH = 2 end

        if barH > 0 then
            local bx = x + size - 7
            local by = y + 5 + (area - barH)
            self:drawRect(bx + 1, by, 1, 1, 1, col.r, col.g, col.b)
            if barH > 2 then
                self:drawRect(bx, by + 1, 3, barH - 2, 1, col.r, col.g, col.b)
            end
            self:drawRect(bx + 1, by + barH - 1, 1, 1, 1, col.r, col.g, col.b)
        end
    end
    if ammoText == nil then return end
    local Style = ComfyGrid.UI.Style
    local fontHgt = Style ~= nil and Style.FONT_H or 16
    local byFont = ammoWidths[fontHgt]
    if byFont == nil then
        byFont = {}
        ammoWidths[fontHgt] = byFont
    end
    local tw = byFont[ammoText]
    if tw == nil then
        tw = getTextManager():MeasureStringX(UIFont.Small, ammoText)
        byFont[ammoText] = tw
    end
    local ax = x + size - 9 - tw
    if ax < x + 2 then return end
    local ty = y + size - fontHgt - 1
    self:drawText(ammoText, ax + 1, ty + 1, 0, 0, 0, 1, UIFont.Small)
    self:drawText(ammoText, ax, ty, 1, 1, 1, 1, UIFont.Small)
end

local function render(self)
    if hidden(self) then
        self:setVisible(false)
        return
    end
    local Style = ComfyGrid.UI.Style
    local Draw = ComfyGrid.UI.Draw
    local slots = self.availableSlot
    if Style == nil or Draw == nil or slots == nil then return end
    applyMetrics(self)

    local colors = Style.COLORS
    local surf = colors and colors.SURFACE or nil
    local board = (colors and colors.BOARD_BG)
        or { r = 0.082, g = 0.074, b = 0.062, a = 0.95 }
    local radius = math.max(3, math.floor(self.height * 0.16 + 0.5))

    Draw.shadow(self, 0, 0, self.width, self.height, 6, 0.35)
    Draw.roundFrame(self, 0, 0, self.width, self.height, radius,
        board.a or 0.95, surf and surf.line or board, board, board.a or 0.95)

    local mouseOver = self:getSlotIndexAt(self:getMouseX(), self:getMouseY())

    local dragged = nil
    if ISMouseDrag.dragging and mouseOver ~= -1 then
        local carrying = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
        local slot = slots[mouseOver]
        for _, it in ipairs(carrying) do
            if self:canBeAttached(slot, it) then
                dragged = it
                break
            end
        end
    end

    local size = self.slotWidth
    local x = self.margins + 1
    local y = self.margins + 1
    local accent = surf and surf.accent or { r = 0.85, g = 0.74, b = 0.51 }
    for i, slot in pairs(slots) do
        local item = self.attachedItems[i]
        local hot = (i == mouseOver)
        local refused = false
        if hot then
            if dragged ~= nil then
                item = dragged
            elseif ISMouseDrag.dragging then
                refused = true
            end
        elseif item == dragged and dragged ~= nil then

            item = nil
        end

        drawSlotBody(self, x, y, size, item, hot, refused, slot)
        self:drawText(tostring(i), x + 3, y + 1,
            accent.r, accent.g, accent.b, 0.75, self.font)
        if item ~= nil then
            drawReadouts(self, x, y, size, item)
            if item:isEquipped() and self.equippedItemIcon ~= nil then
                local t = self.equippedItemIcon
                local s = math.max(8, math.floor(size * 0.28 + 0.5))
                self:drawTextureScaled(t, x + size - s - 3, y + size - s - 3,
                    s, s, 1, 1, 1, 1)
            end
        else

            local ghosts = ComfyGrid.UI and ComfyGrid.UI.HotbarGhosts
            local tex = ghosts ~= nil and ghosts.texFor(slot) or nil
            if tex == nil then tex = slot.texture end
            if tex ~= nil then
                local s = math.floor(size * 0.55 + 0.5)
                local off = math.floor((size - s) * 0.5)
                self:drawTextureScaled(tex, x + off, y + off, s, s,
                    0.25, 1, 1, 1)
            end
        end

        if hot then
            local label = getTextOrNull("IGUI_HotbarAttachment_"
                .. slot.slotType) or slot.name
            if label ~= nil then
                local fh = Style.FONT_H
                local tw = getTextManager():MeasureStringX(Style.FONT, label)
                local lx = x + (size - tw) * 0.5
                Draw.roundRect(self, lx - 5, -fh - 3, tw + 10, fh + 2, 3,
                    0.85, board)
                self:drawText(label, lx, -fh - 2,
                    accent.r, accent.g, accent.b, 1, Style.FONT)
            end
        end
        x = x + size + self.slotPad
    end
end

ComfyGrid._hotbarRender = render

if not ComfyGrid._hotbarPatched then
    ComfyGrid._hotbarPatched = true

    local og_render = ISHotbar.render
    function ISHotbar:render()

        if not barEnabled() then return og_render(self) end
        local fn = ComfyGrid._hotbarRender
        if fn == nil then return og_render(self) end
        local ok, err = pcall(fn, self)
        if not ok then

            if err ~= lastError then
                lastError = err
                local Log = ComfyGrid.Core and ComfyGrid.Core.Log
                if Log ~= nil then
                    Log.error("Hotbar render failed: " .. tostring(err))
                end
            end
            return og_render(self)
        end
    end

    local og_size = ISHotbar.setSizeAndPosition
    function ISHotbar:setSizeAndPosition()
        pcall(applyMetrics, self)
        return og_size(self)
    end
end
