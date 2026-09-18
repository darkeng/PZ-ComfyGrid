--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.5
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Model/Equipment"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Chrome/PopupRegistry"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/UI/StackRenderer"
require "ComfyGrid/Interact/DragAndDrop"
require "ComfyGrid/Interact/Transfer"
require "ComfyGrid/Interact/Unequip"
require "ComfyGrid/Interact/Pad/PadPopup"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local VanillaStacks = ComfyGrid.Core.VanillaStacks
local Equipment = ComfyGrid.Model.Equipment
local Style = ComfyGrid.UI.Style
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local StackRenderer = ComfyGrid.UI.StackRenderer
local DragAndDrop = ComfyGrid.Interact.DragAndDrop
local Unequip = ComfyGrid.Interact.Unequip
local PadPopup = ComfyGrid.Interact.PadPopup

local LayersPopup = ISPanel:derive("ComfyLayersPopup")
ComfyGrid.UI.LayersPopup = LayersPopup

local instance = nil

local MIN_COLS = 2
local MAX_COLS = 4
local PAD_X = 4

local function closeChip()
    return math.max(14, math.floor(Style.FONT_H * 0.9 + 0.5))
end

local function closeZoneLeft(w)
    return w - (closeChip() + 12)
end

local GAP = 4

local DEFAULT_BG = { r = 0.07, g = 0.07, b = 0.09, a = 0.96 }
local DEFAULT_TEXT = { r = 0.9, g = 0.9, b = 0.9, a = 1 }

local ctx = { view = false, stack = false, item = false, slot = 0, x = 0, y = 0, playerNum = 0 }

local lastPrerenderError = nil
local lastRenderError = nil
local lastMouseError = nil
local function reportMouseError(err)
    if err ~= lastMouseError then
        lastMouseError = err
        Log.error("LayersPopup mouse handling failed: " .. tostring(err))
    end
end

local function resolveEntry(self)
    local strip = self.strip
    if strip == nil or strip.entries == nil then return nil end
    for i = 1, strip.entryCount do
        local entry = strip.entries[i]
        if entry.key == self.groupKey then
            return entry
        end
    end
    return nil
end

function LayersPopup:new(x, y, strip, groupKey)
    local o = ISPanel:new(x, y, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.strip = strip
    o.playerNum = strip.playerNum or 0
    o.groupKey = groupKey

    o.tiles = {}
    o.cols = MIN_COLS
    o.rowsTotal = 1
    o.hoverTile = nil
    o.pressedId = nil
    o.dragDidStart = false
    o.isComfyDragSource = true

    local node = strip.parent
    while node ~= nil do
        if node.pane ~= nil then
            o.hostPane = node.pane
            break
        end
        node = node.parent
    end

    if o.hostPane == nil then
        local okP, page = pcall(getPlayerInventory, o.playerNum)
        if okP and page ~= nil then o.hostPane = page.inventoryPane end
    end
    o.titleH = math.max(18, Style.FONT_H + 4, math.floor(Style.CELL / 2))

    o.anchor = nil
    return o
end

local function rebuildTiles(self, entry)
    local tiles = self.tiles
    for i = #tiles, 1, -1 do tiles[i] = nil end
    local items = entry.items
    for i = 1, #items do
        local item = items[i]
        if item ~= nil then
            tiles[#tiles + 1] = {
                id = item:getID(),
                item = item,
                synth = {
                    itemIDs = { [item:getID()] = true },
                    count = 1,
                    slot = #tiles,
                    itemType = item:getFullType(),
                    bucket = "",
                    category = item:getDisplayCategory() or item:getCategory(),
                },
            }
        end
    end
end

local function tilesStale(self, entry)
    local tiles = self.tiles
    local items = entry.items
    if #tiles ~= #items then return true end
    for i = 1, #items do
        local item = items[i]
        if item == nil or tiles[i].id ~= item:getID() then return true end
    end
    return false
end

local function relayout(self)
    local n = #self.tiles
    if n < 1 then n = 1 end
    local cols = math.ceil(math.sqrt(n))
    if cols < MIN_COLS then cols = MIN_COLS end
    if cols > MAX_COLS then cols = MAX_COLS end
    self.cols = cols
    self.rowsTotal = math.ceil(n / cols)
    local bw, bh = Style.gridPixelSize(cols, self.rowsTotal)
    local w = bw + PAD_X * 2
    local h = self.titleH + bh + 4
    if self.width ~= w then self:setWidth(w) end
    if self.height ~= h then self:setHeight(h) end
    local core = getCore()
    local screenW = core and core:getScreenWidth() or 1920
    local screenH = core and core:getScreenHeight() or 1080
    local x = self:getX()
    local y = self:getY()

    local a = self.anchor
    if a ~= nil then
        local gap = GAP
        if a.side == "below" then
            x = a.x
            y = a.y + a.cell + 2
        else
            y = a.y
            local right = a.x + a.cell + gap
            local left = a.x - w - gap
            if a.side == "left" then

                x = (left >= 0) and left or right
            else
                x = (right + w <= screenW) and right or math.max(0, left)
            end
        end
    end
    if x + w > screenW then x = math.max(0, screenW - w) end
    if y + h > screenH then y = math.max(0, screenH - h) end
    if x ~= self:getX() then self:setX(x) end
    if y ~= self:getY() then self:setY(y) end
end

local function boardOrigin(self)
    return PAD_X, self.titleH
end

local function tileAt(self, x, y)
    local bx, by = boardOrigin(self)
    local idx = Style.slotAtPixel(x - bx, y - by, self.cols, self.rowsTotal)
    if idx == nil or idx >= #self.tiles then return nil end
    return idx
end

local function updateHover(self)
    self.hoverTile = tileAt(self, self:getMouseX(), self:getMouseY())
end

local function prerenderImpl(self)
    local entry = resolveEntry(self)

    if entry == nil or #entry.items < 2
            or not self.strip:isReallyVisible() then
        self:close()
        return
    end

    local Draw = ComfyGrid.UI.Draw
    if Draw ~= nil then
        local rem = self._comfySlide
        if rem == nil then
            rem = math.floor(10 * Style.SCALE + 0.5)
            self._comfySlide = rem
            self:setY(self:getY() + rem)
        elseif rem > 0 then
            local nr = Draw.glide(rem, 0, 0.35)
            self:setY(self:getY() - (rem - nr))
            self._comfySlide = nr
        end
    end
    if tilesStale(self, entry) then
        rebuildTiles(self, entry)
        relayout(self)
        updateHover(self)
    end

end

function LayersPopup:prerender()
    local ok, err = pcall(prerenderImpl, self)
    if not ok and err ~= lastPrerenderError then
        lastPrerenderError = err
        Log.error("LayersPopup prerender failed: " .. tostring(err))
    end
end

local CHROME = { r = 0.44, g = 0.39, b = 0.29, a = 0.8 }

local function renderImpl(self)
    local w = self.width
    local h = self.height
    local colors = Style.COLORS
    local bg = colors and colors.BOARD_BG or DEFAULT_BG
    local text = colors and colors.COUNT_TEXT or DEFAULT_TEXT

    local Draw = ComfyGrid.UI.Draw
    local sf = colors and colors.SURFACE
    local bgA = math.min(1, (bg.a or 1) + 0.12)
    if Draw ~= nil and sf ~= nil then
        local r = math.max(4, math.floor(8 * Style.SCALE + 0.5))
        Draw.shadow(self, 0, 0, w, h, math.floor(10 * Style.SCALE + 0.5), 0.5)
        Draw.roundFrame(self, 0, 0, w, h, r, CHROME.a, sf.line, bg, bgA)
    else
        self:drawRect(0, 0, w, h, bgA, bg.r or 0, bg.g or 0, bg.b or 0)
        self:drawRectBorder(0, 0, w, h, CHROME.a, CHROME.r, CHROME.g, CHROME.b)
    end

    local font = Style.FONT
    if font ~= nil then

        local title = Text.tr("IGUI_ComfyGrid_Slot" .. self.groupKey,
            Equipment.displayNameFor(self.groupKey) or self.groupKey)
        local suffix = " x" .. tostring(#self.tiles)

        local titleY = math.floor((self.titleH - 1 - Style.FONT_H) * 0.5)
        if titleY < 2 then titleY = 2 end

        local tm = getTextManager and getTextManager() or nil
        local suffixW = 0
        if tm ~= nil then
            local okm, m = pcall(tm.MeasureStringX, tm, font, suffix)
            if okm then suffixW = m end
        end
        local budget = closeZoneLeft(w) - (PAD_X + 2) - 6 - suffixW
        if budget < 1 then budget = 1 end
        local fitGen = Style.FONT_H * 100000 + math.floor(w)
        if self._titleFit == nil or self._titleFitGen ~= fitGen
                or self._titleFitSrc ~= title or self._titleFitSuffix ~= suffix
                then
            self._titleFitGen = fitGen
            self._titleFitSrc = title
            self._titleFitSuffix = suffix
            self._titleFit = Text.fitEllipsis(title, font, budget, 60) .. suffix
        end
        self:drawText(self._titleFit, PAD_X + 2, titleY, text.r, text.g, text.b,
            text.a or 1, font)

        local closeTex = Draw ~= nil and Draw.closeTexture ~= nil
            and Draw.closeTexture() or nil
        if closeTex ~= nil and sf ~= nil then
            local chip = closeChip()
            local cxr = w - 6 - chip
            local cyr = math.floor((self.titleH - 1 - chip) * 0.5)
            Draw.disc(self, cxr, cyr, chip, 1, sf.line)
            Draw.disc(self, cxr + 1, cyr + 1, chip - 2, 1, sf.card)
            local csz = math.floor(chip * 0.55 + 0.5)
            local coff = math.floor((chip - csz) * 0.5)
            self:drawTextureScaled(closeTex, cxr + coff, cyr + coff,
                csz, csz, 0.9, text.r, text.g, text.b)
        else
            self:drawTextRight("X", w - 8, titleY, text.r, text.g, text.b,
                text.a or 1, font)
        end
    end
    if Draw ~= nil and sf ~= nil then
        Draw.headerLine(self, 1, self.titleH - 1, w - 2,
            math.floor(10 * Style.SCALE + 0.5), colors)
    else
        self:drawRect(0, self.titleH - 1, w, 1, CHROME.a, CHROME.r, CHROME.g,
            CHROME.b)
    end

    local bx, by = boardOrigin(self)
    local cols = self.cols
    local bw, bh = Style.gridPixelSize(cols, self.rowsTotal)

    self:drawRect(bx, by, bw, bh, bg.a or 1, bg.r or 0, bg.g or 0, bg.b or 0)

    local tiles = self.tiles
    local pixelForSlot = Style.pixelForSlot
    ctx.view = self
    ctx.playerNum = self.playerNum

    local currentAction = StackRenderer.currentActionOf(self.playerNum)
    for i = 1, #tiles do
        local tile = tiles[i]
        local item = tile.item
        if item ~= nil then
            local tx, ty = pixelForSlot(i - 1, cols)

            ctx.stack = tile.synth
            ctx.item = item
            ctx.slot = i - 1
            ctx.x = bx + tx
            ctx.y = by + ty
            StackRenderer.draw(ctx)
            local jd = StackRenderer.jobDeltaOf(item, currentAction)
            if jd ~= nil then
                StackRenderer.drawJobOverlay(self, bx + tx, by + ty, jd)
            end
        end
    end

    for i = #tiles + 1, cols * self.rowsTotal do
        local ex, ey = pixelForSlot(i - 1, cols)
        ctx.stack = nil
        ctx.item = nil
        ctx.slot = i - 1
        ctx.x = bx + ex
        ctx.y = by + ey
        SlotRenderer.drawCell(ctx, nil)
    end

    local hover = self.hoverTile
    if hover ~= nil and hover < #tiles and self:isMouseOver() then
        local hx, hy = pixelForSlot(hover, cols)
        ctx.stack = tiles[hover + 1].synth
        ctx.item = nil
        ctx.slot = hover
        ctx.x = bx + hx
        ctx.y = by + hy
        SlotRenderer.drawHover(ctx)
    end

    local padIdx = PadPopup.cursorFor(self)
    if padIdx ~= nil and padIdx < #tiles then
        local px, py = pixelForSlot(padIdx, cols)
        SlotRenderer.drawSelection(self, bx + px, by + py)
        ctx.stack = tiles[padIdx + 1].synth
        ctx.item = nil
        ctx.slot = padIdx
        ctx.x = bx + px
        ctx.y = by + py
        SlotRenderer.drawHover(ctx)
    end
end

function LayersPopup:render()
    local ok, err = pcall(renderImpl, self)
    if not ok and err ~= lastRenderError then
        lastRenderError = err
        Log.error("LayersPopup render failed: " .. tostring(err))
    end
end

local function liveTileItem(self, idx)
    local tile = self.tiles[idx + 1]
    if tile == nil then return nil end
    local entry = resolveEntry(self)
    if entry == nil then return nil end
    local items = entry.items
    for i = 1, #items do
        local item = items[i]
        if item ~= nil and item:getID() == tile.id then return item end
    end
    return nil
end

function LayersPopup:hoveredItem()
    local idx = self.hoverTile
    if idx == nil or not self:isMouseOver() then return nil end
    return liveTileItem(self, idx)
end

function LayersPopup:padTileItem(idx)
    return liveTileItem(self, idx)
end

local function mouseDownImpl(self, x, y)
    if DragAndDrop.isDragOwner(self) and not DragAndDrop.isDragging() then
        DragAndDrop.endDrag()
    end
    self.pressedId = nil
    self.dragDidStart = false
    local idx = tileAt(self, x, y)
    if idx == nil then return end
    local item = liveTileItem(self, idx)
    if item == nil then return end

    if Unequip.pressClaims(item, self.playerNum, "unequip") then return end

    local payload = { VanillaStacks.fromItems({ item }) }
    if payload[1] == nil then return end
    DragAndDrop.prepareDrag(self, payload, x, y)
    self.pressedId = item:getID()
end

local function mouseUpImpl(self, x, y)

    if not DragAndDrop.isDragging() then
        local upIdx = tileAt(self, x, y)
        local upItem = upIdx ~= nil and liveTileItem(self, upIdx) or nil
        if upItem ~= nil
                and Unequip.releaseClaims(self, upItem, self.playerNum, "unequip") then
            if DragAndDrop.isDragOwner(self) then DragAndDrop.endDrag() end
            self.pressedId = nil
            return
        end
    end
    if DragAndDrop.isDragging() then
        if DragAndDrop.isDragOwner(self) then
            DragAndDrop.endDrag()
        end
    else
        if DragAndDrop.isDragOwner(self) then
            DragAndDrop.endDrag()
        end

        if not self.dragDidStart and y < self.titleH
                and x > closeZoneLeft(self.width) then
            self:close()
        end
    end
    self.pressedId = nil
end

local function dragCancelImpl(self)
    local id = self.pressedId
    self.pressedId = nil
    if id == nil then return end
    if not DragAndDrop.releaseDropsToFloor(self.playerNum) then return end
    local playerObj = getSpecificPlayer(self.playerNum)
    if playerObj == nil then return end
    local Transfer = ComfyGrid.Interact and ComfyGrid.Interact.Transfer
    if Transfer == nil or Transfer.dropToFloor == nil then return end
    local item = playerObj:getInventory():getItemWithID(id)
    if item ~= nil then
        Transfer.dropToFloor({ item }, playerObj)
    end
end

function LayersPopup:onComfyDragCancelled()
    local ok, err = pcall(dragCancelImpl, self)
    if not ok then reportMouseError(err) end
end

local function mouseUpOutsideImpl(self, _x, _y)
    if not DragAndDrop.isDragOwner(self) then return end
    if DragAndDrop.isDragging() then
        DragAndDrop.cancelDrag(self, self.onComfyDragCancelled)
    else
        DragAndDrop.endDrag()
        self.pressedId = nil
    end
end

local function rightMouseUpImpl(self, x, y)
    if DragAndDrop.isDragging() then return end
    if DragAndDrop.isDragOwner(self) then
        DragAndDrop.endDrag()
        self.pressedId = nil
    end
    local idx = tileAt(self, x, y)
    if idx == nil then return end
    local item = liveTileItem(self, idx)
    if item == nil then return end
    ISInventoryPaneContextMenu.createMenu(self.playerNum, true, { item },
        getMouseX(), getMouseY())
end

function LayersPopup:onMouseDown(x, y)
    self:bringToTop()
    local ok, err = pcall(mouseDownImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end

function LayersPopup:onMouseUp(x, y)
    local ok, err = pcall(mouseUpImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end

function LayersPopup:onMouseUpOutside(x, y)
    local ok, err = pcall(mouseUpOutsideImpl, self, x, y)
    if not ok then reportMouseError(err) end
end

function LayersPopup:onMouseMove(_dx, _dy)
    updateHover(self)
    if DragAndDrop == nil then return end
    DragAndDrop.startDrag(self)
    if not self.dragDidStart and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(self) then
        self.dragDidStart = true
    end
end

function LayersPopup:onMouseMoveOutside(_dx, _dy)
    self.hoverTile = nil
    if DragAndDrop == nil then return end
    DragAndDrop.startDrag(self)
    if not self.dragDidStart and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(self) then
        self.dragDidStart = true
    end
end

function LayersPopup:onMouseDownOutside(_x, _y)
    self:close()
end

function LayersPopup:onRightMouseDownOutside(_x, _y)
    self:close()
end

function LayersPopup.onRightMouseDown(_self, _x, _y)
    return true
end

function LayersPopup:onRightMouseUp(x, y)
    local ok, err = pcall(rightMouseUpImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end

function LayersPopup:close()

    PadPopup.releaseFocus(self)
    if DragAndDrop.isDragOwner(self) and not DragAndDrop.isDragging() then
        DragAndDrop.endDrag()
    end
    self:setVisible(false)
    self:removeFromUIManager()
    if instance == self then
        instance = nil
    end
end

function LayersPopup.openFor(strip, groupKey)
    if strip == nil or groupKey == nil then return end
    if instance ~= nil then
        instance:close()
    end

    local Chrome = ComfyGrid.UI and ComfyGrid.UI.Chrome
    local Registry = Chrome ~= nil and Chrome.PopupRegistry or nil
    if Registry ~= nil then Registry.closeOthers(nil) end

    local ax, ay, cell, side = strip:tileAnchor(groupKey)
    if ax == nil then
        ax, ay, cell, side = strip:getAbsoluteX(), strip:getAbsoluteY(),
            Style.CELL, "below"
    end
    local popup = LayersPopup:new(ax, ay, strip, groupKey)
    popup.anchor = { x = ax, y = ay, cell = cell, side = side }
    popup:initialise()
    popup:addToUIManager()
    popup:bringToTop()
    instance = popup
    return popup
end

function LayersPopup.current()
    return instance
end

PadPopup.attach(LayersPopup)

ComfyGrid.UI.Chrome.PopupRegistry.register("LayersPopup", LayersPopup.current)
