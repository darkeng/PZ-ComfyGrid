--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Input"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
require "ComfyGrid/UI/HotbarGhosts"
require "ComfyGrid/UI/Icons"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/UI/StackRenderer"

local Input = ComfyGrid.Core.Input

local lastError = nil

local ammoWidths = {}

local function vanillaHidesBar(self)
    return (self.playerNum ~= nil and self.playerNum > 0)
        or Input.padOwns(self.playerNum)
end

local function barEnabled()
    local Settings = ComfyGrid.Settings
    if Settings == nil or Settings.get == nil then return true end
    return Settings.get("HOTBAR_BAR") ~= false
end

local function snapshotVanillaMetrics(self)
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
    local vanillaMetrics = self._comfyHotbarOg
    if vanillaMetrics == nil then return false end
    if self.slotWidth == vanillaMetrics.slotWidth
            and self.slotHeight == vanillaMetrics.slotHeight
            and self.slotPad == vanillaMetrics.slotPad
            and self.margins == vanillaMetrics.margins then
        return false
    end
    self.slotWidth = vanillaMetrics.slotWidth
    self.slotHeight = vanillaMetrics.slotHeight
    self.slotPad = vanillaMetrics.slotPad
    self.margins = vanillaMetrics.margins
    if vanillaMetrics.height ~= nil then
        self:setHeight(vanillaMetrics.height)
    end
    return true
end

local function applyMetrics(self)

    snapshotVanillaMetrics(self)
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

local socketCtx = { view = false, x = 0, y = 0 }
local SLOT_NUMBER_TEXT = {}

local ATTACHMENT_NAMES = {}

local attachmentNameWidths = {}

local function drawSlotBody(self, x, y, size, item, hot, refused, slot)
    local Style = ComfyGrid.UI.Style
    local SlotRenderer = ComfyGrid.UI.SlotRenderer
    local colors = Style.COLORS
    local tex = SlotRenderer ~= nil and SlotRenderer.getTileTexture ~= nil
        and SlotRenderer.getTileTexture() or nil

    if item == nil and SlotRenderer ~= nil and SlotRenderer.drawSocket ~= nil then
        socketCtx.view, socketCtx.x, socketCtx.y = self, x, y
        SlotRenderer.drawSocket(socketCtx, size)
        local Ghosts = ComfyGrid.UI.HotbarGhosts
        if slot ~= nil and Ghosts ~= nil and Ghosts.texFor ~= nil then
            local ghostTex = Ghosts.texFor(slot)
            if ghostTex ~= nil then
                SlotRenderer.drawGhost(self, ghostTex, x, y, size)
            end
        end
    else
        local fill = colors.EMPTY_CELL
        if tex ~= nil then
            self:drawTextureScaled(tex, x, y, size, size,
                fill.a or 1, fill.r, fill.g, fill.b)
        else
            self:drawRect(x, y, size, size, fill.a or 1, fill.r, fill.g, fill.b)
        end
    end

    if hot then
        local wash = refused and colors.REFUSED_WASH or colors.HOVER
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
    ComfyGrid.UI.Icons.draw(self, item, x + pad, y + pad, 1, box, box)
end

local function drawReadouts(self, x, y, size, item)
    local StackRenderer = ComfyGrid.UI and ComfyGrid.UI.StackRenderer
    if StackRenderer == nil or StackRenderer.overlayInfo == nil then return end

    if item.isBroken and item:isBroken()
            and StackRenderer.drawBrokenMark ~= nil then
        StackRenderer.drawBrokenMark(self, x, y, size)
    end
    local frac, col, ammoText = StackRenderer.overlayInfo(item)
    if frac ~= nil and col ~= nil then
        StackRenderer.drawStatusCapsule(self, x, y, size, frac, col)
    end
    if ammoText == nil then return end
    local Style = ComfyGrid.UI.Style
    local fontHgt = Style ~= nil and Style.FONT_H or 16
    local byFont = ammoWidths[fontHgt]
    if byFont == nil then
        byFont = {}
        ammoWidths[fontHgt] = byFont
    end
    local ammoWidth = byFont[ammoText]
    if ammoWidth == nil then
        ammoWidth = getTextManager():MeasureStringX(UIFont.Small, ammoText)
        byFont[ammoText] = ammoWidth
    end
    local ax = x + size - 9 - ammoWidth
    if ax < x + 2 then return end
    local ty = y + size - fontHgt - 1
    self:drawText(ammoText, ax + 1, ty + 1, 0, 0, 0, 1, UIFont.Small)
    self:drawText(ammoText, ax, ty, 1, 1, 1, 1, UIFont.Small)
end

local function renderComfyBar(self)
    if vanillaHidesBar(self) then
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
        for _, carriedItem in ipairs(carrying) do
            if self:canBeAttached(slot, carriedItem) then
                dragged = carriedItem
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
        local slotNumberText = SLOT_NUMBER_TEXT[i]
        if slotNumberText == nil then
            slotNumberText = tostring(i)
            SLOT_NUMBER_TEXT[i] = slotNumberText
        end
        self:drawText(slotNumberText, x + 3, y + 1,
            accent.r, accent.g, accent.b, 0.75, self.font)
        if item ~= nil then
            drawReadouts(self, x, y, size, item)
            if item:isEquipped() and self.equippedItemIcon ~= nil then
                local equippedIcon = self.equippedItemIcon
                local iconSize = math.max(8, math.floor(size * 0.28 + 0.5))
                self:drawTextureScaled(equippedIcon,
                    x + size - iconSize - 3, y + size - iconSize - 3,
                    iconSize, iconSize, 1, 1, 1, 1)
            end
        else

            local ghosts = ComfyGrid.UI and ComfyGrid.UI.HotbarGhosts
            local tex = ghosts ~= nil and ghosts.texFor(slot) or nil
            if tex == nil then tex = slot.texture end
            if tex ~= nil then
                local ghostSize = math.floor(size * 0.55 + 0.5)
                local ghostInset = math.floor((size - ghostSize) * 0.5)
                self:drawTextureScaled(tex, x + ghostInset, y + ghostInset,
                    ghostSize, ghostSize, 0.25, 1, 1, 1)
            end
        end

        if hot then

            local translated = ATTACHMENT_NAMES[slot.slotType]
            if translated == nil then
                translated = getTextOrNull("IGUI_HotbarAttachment_"
                    .. slot.slotType) or false
                ATTACHMENT_NAMES[slot.slotType] = translated
            end
            local attachmentName = translated or slot.name
            if attachmentName ~= nil then
                local fontH = Style.FONT_H
                local widths = attachmentNameWidths[fontH]
                if widths == nil then
                    widths = {}
                    attachmentNameWidths[fontH] = widths
                end
                local textWidth = widths[attachmentName]
                if textWidth == nil then
                    textWidth = getTextManager():MeasureStringX(Style.FONT,
                        attachmentName)
                    widths[attachmentName] = textWidth
                end
                local labelX = x + (size - textWidth) * 0.5
                Draw.roundRect(self, labelX - 5, -fontH - 3, textWidth + 10,
                    fontH + 2, 3, 0.85, board)
                self:drawText(attachmentName, labelX, -fontH - 2,
                    accent.r, accent.g, accent.b, 1, Style.FONT)
            end
        end
        x = x + size + self.slotPad
    end
end

ComfyGrid._hotbarRender = renderComfyBar

Events.OnGameBoot.Add(function()

    if ISHotbar._comfyPatched then return end
    ISHotbar._comfyPatched = true

    local og_render = ISHotbar.render
    function ISHotbar:render()

        if not barEnabled() then return og_render(self) end
        local renderImpl = ComfyGrid._hotbarRender
        if renderImpl == nil then return og_render(self) end
        local ok, err = pcall(renderImpl, self)
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
end)
