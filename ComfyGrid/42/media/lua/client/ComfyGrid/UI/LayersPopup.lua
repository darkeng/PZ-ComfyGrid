--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Model/Equipment"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Chrome/PopupRegistry"
require "ComfyGrid/UI/Chrome/InspectorChrome"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/Model/ItemSearch"
require "ComfyGrid/UI/StackRenderer"
require "ComfyGrid/Interact/DragAndDrop"
require "ComfyGrid/Interact/Transfer"
require "ComfyGrid/Interact/Unequip"
require "ComfyGrid/Interact/Pad/PadPopup"
require "ComfyGrid/UI/StripGestures"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Text = ComfyGrid.Core.Text
local VanillaStacks = ComfyGrid.Core.VanillaStacks
local Equipment = ComfyGrid.Model.Equipment
local Style = ComfyGrid.UI.Style
local InspectorChrome = ComfyGrid.UI.Chrome.InspectorChrome
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local ItemSearch = ComfyGrid.Model.ItemSearch
local StackRenderer = ComfyGrid.UI.StackRenderer
local DragAndDrop = ComfyGrid.Interact.DragAndDrop
local StripGestures = ComfyGrid.UI.StripGestures
local Unequip = ComfyGrid.Interact.Unequip
local PadPopup = ComfyGrid.Interact.PadPopup

local LayersPopup = ISPanel:derive("ComfyLayersPopup")
ComfyGrid.UI.LayersPopup = LayersPopup

local instance = nil

local MIN_COLS = 2
local MAX_COLS = 4

local GAP = 4

local ctx = { view = false, stack = false, item = false, slot = 0, x = 0, y = 0, playerNum = 0 }

local errors = InspectorChrome.newErrorLatch("LayersPopup")
local function reportMouseError(err)
    InspectorChrome.reportError(errors, "mouse handling", err)
end

local boardOrigin = InspectorChrome.boardOrigin
local tileAt = InspectorChrome.tileAt
local updateHover = InspectorChrome.updateHover

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

    o.hostPane = InspectorChrome.hostPaneOf(strip, o.playerNum)
    o.titleH = Style.headerHeight()

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
    local cols = InspectorChrome.fitColumns(self, MIN_COLS, MAX_COLS)
    local bw, bh = Style.gridPixelSize(cols, self.rowsTotal)
    local w, h = InspectorChrome.sizeToBoard(self, bw, bh)
    local screenW, screenH = InspectorChrome.screenSize()
    local x = self:getX()
    local y = self:getY()

    local anchor = self.anchor
    if anchor ~= nil then
        if anchor.side == "below" then
            x = anchor.x
            y = anchor.y + anchor.cell + 2
        else
            y = anchor.y
            local right = anchor.x + anchor.cell + GAP
            local left = anchor.x - w - GAP
            if anchor.side == "left" then

                x = (left >= 0) and left or right
            else
                x = (right + w <= screenW) and right or math.max(0, left)
            end
        end
    end
    InspectorChrome.placeOnScreen(self, x, y, w, h, screenW, screenH)
end

local function prerenderImpl(self)
    local entry = resolveEntry(self)

    if entry == nil or #entry.items < 2
            or not self.strip:isReallyVisible() then
        self:close()
        return
    end
    InspectorChrome.slideIn(self)
    if tilesStale(self, entry) then
        rebuildTiles(self, entry)
        relayout(self)
        updateHover(self)
    end

end

function LayersPopup:prerender()
    local ok, err = pcall(prerenderImpl, self)
    if not ok then InspectorChrome.reportError(errors, "prerender", err) end
end

local function groupTitle(self)
    local title = self._groupTitle
    if title == nil then

        title = Text.tr("IGUI_ComfyGrid_Slot" .. self.groupKey,
            Equipment.displayNameFor(self.groupKey) or self.groupKey)
        self._groupTitle = title
    end
    return title
end

local function drawLayerTiles(self, bx, by)
    local tiles = self.tiles
    local cols = self.cols
    local pixelForSlot = Style.pixelForSlot
    local currentAction = StackRenderer.currentActionOf(self.playerNum)

    local searchMarks = ItemSearch.marksFor(self.playerNum)
    local searchPulse = 1
    if searchMarks ~= nil then searchPulse = SlotRenderer.applyPulse() end
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
            if searchMarks ~= nil and ItemSearch.marksItem(searchMarks, item) then
                SlotRenderer.drawSearchHint(ctx, searchPulse)
            end
            local jobDelta = StackRenderer.jobDeltaOf(item, currentAction)
            if jobDelta ~= nil then
                StackRenderer.drawJobOverlay(self, bx + tx, by + ty, jobDelta)
            end
        end
    end
end

local function renderImpl(self)
    local bg = InspectorChrome.boardBackground()
    InspectorChrome.drawFrame(self, bg)

    InspectorChrome.drawTitleBar(self, groupTitle(self), #self.tiles)

    local bx, by = boardOrigin(self)
    local bw, bh = Style.gridPixelSize(self.cols, self.rowsTotal)

    self:drawRect(bx, by, bw, bh, bg.a or 1, bg.r or 0, bg.g or 0, bg.b or 0)

    ctx.view = self
    ctx.playerNum = self.playerNum
    drawLayerTiles(self, bx, by)
    InspectorChrome.drawTrailingCells(self, ctx, bx, by)
    InspectorChrome.drawHoverAndPadCursor(self, ctx, bx, by)
end

function LayersPopup:render()
    local ok, err = pcall(renderImpl, self)
    if not ok then InspectorChrome.reportError(errors, "render", err) end
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
    return InspectorChrome.hoveredItem(self, liveTileItem)
end

function LayersPopup:padTileItem(idx)
    return liveTileItem(self, idx)
end

function LayersPopup:padTileXY(idx)
    return InspectorChrome.tileXY(self, idx)
end

function LayersPopup:padVisibleBoardHeight()
    return InspectorChrome.visibleBoardHeight(self)
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

        if InspectorChrome.isCloseHit(self, x, y) then
            self:close()
        end
    end
    self.pressedId = nil
end

function LayersPopup:onComfyDragCancelled()
    local ok, err = pcall(StripGestures.dropPressedToFloor, self)
    if not ok then reportMouseError(err) end
end

local function layerItemAt(self, x, y)
    local idx = tileAt(self, x, y)
    if idx == nil then return nil end
    return liveTileItem(self, idx)
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

function LayersPopup:onMouseUpOutside(_x, _y)
    local ok, err = pcall(StripGestures.releaseOutside, self)
    if not ok then reportMouseError(err) end
end

function LayersPopup:onMouseMove(_dx, _dy)
    InspectorChrome.pointerMoved(self)
end

function LayersPopup:onMouseMoveOutside(_dx, _dy)
    InspectorChrome.pointerMovedOutside(self)
end

function LayersPopup:onRightMouseUp(x, y)
    local ok, err = pcall(StripGestures.openMenuAt, self, x, y, layerItemAt)
    if not ok then reportMouseError(err) end
    return true
end

function LayersPopup:close()
    InspectorChrome.dismantle(self)
    if instance == self then
        instance = nil
    end
end

function LayersPopup.openFor(strip, groupKey)
    if strip == nil or groupKey == nil then return end
    if instance ~= nil then
        instance:close()
    end
    InspectorChrome.standDownOthers()

    local ax, ay, cell, side = strip:tileAnchor(groupKey)
    if ax == nil then
        ax, ay, cell, side = strip:getAbsoluteX(), strip:getAbsoluteY(),
            Style.CELL, "below"
    end
    local popup = LayersPopup:new(ax, ay, strip, groupKey)
    popup.anchor = { x = ax, y = ay, cell = cell, side = side }
    InspectorChrome.show(popup)
    instance = popup
    return popup
end

function LayersPopup.current()
    return instance
end

PadPopup.attach(LayersPopup)

InspectorChrome.installDismissHandlers(LayersPopup)

ComfyGrid.UI.Chrome.PopupRegistry.register("LayersPopup", LayersPopup.current)
