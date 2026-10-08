--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Chrome/PopupRegistry"
require "ComfyGrid/UI/Chrome/InspectorChrome"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/Model/ItemSearch"
require "ComfyGrid/UI/StackRenderer"
require "ComfyGrid/Interact/DragAndDrop"
require "ComfyGrid/Interact/Transfer"
require "ComfyGrid/Interact/TransferJobs"
require "ComfyGrid/Interact/QuickMove"
require "ComfyGrid/Interact/ContextMenu"
require "ComfyGrid/Interact/Pad/PadPopup"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local VanillaStacks = ComfyGrid.Core.VanillaStacks
local ItemStack = ComfyGrid.Model.ItemStack
local Style = ComfyGrid.UI.Style
local InspectorChrome = ComfyGrid.UI.Chrome.InspectorChrome
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local ItemSearch = ComfyGrid.Model.ItemSearch
local StackRenderer = ComfyGrid.UI.StackRenderer
local DragAndDrop = ComfyGrid.Interact.DragAndDrop
local Transfer = ComfyGrid.Interact.Transfer
local TransferJobs = ComfyGrid.Interact.TransferJobs
local QuickMove = ComfyGrid.Interact.QuickMove
local ContextMenu = ComfyGrid.Interact.ContextMenu
local PadPopup = ComfyGrid.Interact.PadPopup

local StackPopup = ISPanel:derive("ComfyStackPopup")
ComfyGrid.UI.StackPopup = StackPopup

local instance = nil

local MIN_COLS = 2
local MAX_COLS = 6
local MAX_VISIBLE_ROWS = 6

local MARQUEE_THRESHOLD = 6
local DRAG_SOURCE_WASH_ALPHA = 0.6

local ctx = { view = false, stack = false, item = false, slot = 0, x = 0, y = 0,
    playerNum = 0, skipWeightMark = true, freshnessBar = true }

local errors = InspectorChrome.newErrorLatch("StackPopup")
local function reportMouseError(err)
    InspectorChrome.reportError(errors, "mouse handling", err)
end

local boardOrigin = InspectorChrome.boardOrigin
local tileAt = InspectorChrome.tileAt
local updateHover = InspectorChrome.updateHover

function StackPopup:new(x, y, gridView, stack)
    local o = ISPanel:new(x, y, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.gridView = gridView
    o.model = gridView.model
    o.playerNum = gridView.playerNum or 0

    o.slot = stack.slot
    o.itemType = stack.itemType
    o.bucket = stack.bucket
    o.lastChangeCount = nil

    o.tiles = {}
    o.cols = MIN_COLS
    o.rowsTotal = 1
    o.yOffset = 0
    o.hoverTile = nil
    o.pressedId = nil
    o.dragDidStart = false

    o.isComfyDragSource = true

    o.hostPane = InspectorChrome.hostPaneOf(gridView, o.playerNum)

    o.selection = nil
    o.selectionCount = 0
    o.draggedIds = nil

    o.marqueeArmed = false
    o.marqueeActive = false
    o.marqueeX0, o.marqueeY0 = 0, 0
    o.marqueeX1, o.marqueeY1 = 0, 0
    o.marqueePressId = nil
    o.marqueeBase = nil
    o.titleH = Style.headerHeight()
    return o
end

local function rebuildTiles(self, stack)
    local tiles = self.tiles
    for i = #tiles, 1, -1 do tiles[i] = nil end
    local inventory = self.model.inventory
    local ids = {}
    for id in pairs(stack.itemIDs) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    for i = 1, #ids do
        local item = inventory:getItemWithID(ids[i])
        if item ~= nil then
            tiles[#tiles + 1] = {
                id = ids[i],
                item = item,
                synth = {
                    itemIDs = { [ids[i]] = true },
                    count = 1,
                    slot = #tiles,
                    itemType = stack.itemType,
                    bucket = stack.bucket,
                    category = stack.category,
                },
            }
        end
    end
end

local function relayout(self)
    local cols = InspectorChrome.fitColumns(self, MIN_COLS, MAX_COLS)
    local visRows = math.min(self.rowsTotal, MAX_VISIBLE_ROWS)
    local bw, bh = Style.gridPixelSize(cols, visRows)
    local w, h = InspectorChrome.sizeToBoard(self, bw, bh)

    local screenW, screenH = InspectorChrome.screenSize()
    InspectorChrome.placeOnScreen(self, self:getX(), self:getY(), w, h,
        screenW, screenH)

    local _, fullH = Style.gridPixelSize(cols, self.rowsTotal)
    local maxOff = math.max(0, fullH - bh)
    if self.yOffset > maxOff then self.yOffset = maxOff end
end

local function resolveStack(self)
    local model = self.model
    if model == nil or model.grid == nil then return nil end
    local stack = model.grid:stackAt(self.slot)
    if stack == nil or stack.itemType ~= self.itemType
            or stack.bucket ~= self.bucket or stack.count == 0 then
        return nil
    end
    return stack
end

local function clearSelection(self)
    self.selection = nil
    self.selectionCount = 0
end

local function gestureIsDoubleClick()
    local Settings = ComfyGrid.Settings
    if Settings == nil or Settings.transferIsDoubleClick == nil then
        return false
    end
    local ok, isDoubleClick = pcall(Settings.transferIsDoubleClick)
    return ok and isDoubleClick == true
end

local function clickWindowMs()
    local GridView = ComfyGrid.UI and ComfyGrid.UI.GridView
    return (GridView ~= nil and GridView.CLICK_DELAY_MS) or 260
end

local function isSelected(self, id)
    local selection = self.selection
    return selection ~= nil and selection[id] == true
end

local function toggleSelected(self, id)
    if id == nil then return end
    local selection = self.selection
    if selection == nil then selection = {}; self.selection = selection end
    if selection[id] then
        selection[id] = nil
        self.selectionCount = self.selectionCount - 1
        if self.selectionCount <= 0 then clearSelection(self) end
    else
        selection[id] = true
        self.selectionCount = self.selectionCount + 1
    end
end

local function syncSelection(self, stack)
    local selection = self.selection
    if selection == nil then return end
    for id in pairs(selection) do
        if stack.itemIDs[id] == nil then
            selection[id] = nil
            self.selectionCount = self.selectionCount - 1
        end
    end
    if self.selectionCount <= 0 then clearSelection(self) end
end

local function stillOnScreen(self)
    local inv = self.model ~= nil and self.model.inventory or nil
    if inv == nil then return false end
    local ContainerWindow = ComfyGrid.UI ~= nil and ComfyGrid.UI.ContainerWindow
        or nil
    if ContainerWindow == nil or ContainerWindow.boardShowing == nil then
        return false
    end
    return ContainerWindow.boardShowing(self.playerNum, inv)
end

local function prerenderImpl(self)

    self:flushPendingClick()
    local stack = resolveStack(self)
    if stack == nil then
        self:close()
        return
    end

    if (stack.count or 0) < 2 then
        self:close()
        return
    end

    if stillOnScreen(self) then
        self._offScreenFrames = nil
    else
        self._offScreenFrames = (self._offScreenFrames or 0) + 1
        if self._offScreenFrames >= 2 then
            self:close()
            return
        end
    end
    InspectorChrome.slideIn(self)
    syncSelection(self, stack)

    local changeCount = self.model.grid.changeCount
    if changeCount ~= self.lastChangeCount then
        self.lastChangeCount = changeCount
        rebuildTiles(self, stack)

        if #self.tiles < 2 then
            self:close()
            return
        end
        relayout(self)
        updateHover(self)
    end

end

function StackPopup:prerender()
    local ok, err = pcall(prerenderImpl, self)
    if not ok then InspectorChrome.reportError(errors, "prerender", err) end
end

local function drawMemberTiles(self, inventory, bx, boardTop, bh, bg)
    local tiles = self.tiles
    local cols = self.cols
    local stride = Style.CELL_STRIDE
    local pixelForSlot = Style.pixelForSlot
    local cell = Style.CELL

    local jobs = TransferJobs.itemsFor and TransferJobs.itemsFor(inventory) or nil
    local currentAction = StackRenderer.currentActionOf(self.playerNum)
    local draggedId = nil
    if self.pressedId ~= nil and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(self) then
        draggedId = self.pressedId
    end
    local draggingSel = draggedId ~= nil and isSelected(self, draggedId)
    local firstVis = math.floor(self.yOffset / stride) * cols
    local lastVis = math.min(#tiles,
        firstVis + (math.ceil(bh / stride) + 1) * cols)

    local ItemApply = ComfyGrid.Interact.ItemApply
    local applySrc = ItemApply ~= nil and ItemApply.dragSource() or nil
    local applyPlayer = nil
    local applyPulse = 1
    if applySrc ~= nil then
        applyPlayer = getSpecificPlayer(self.playerNum)
        if applyPlayer == nil then applySrc = nil end
        applyPulse = SlotRenderer.applyPulse()
    end

    local searchMarks = ItemSearch.marksFor(self.playerNum)
    local searchPulse = 1
    if searchMarks ~= nil then searchPulse = SlotRenderer.applyPulse() end
    for i = firstVis + 1, lastVis do
        local tile = tiles[i]
        local item = tile.item

        if item ~= nil and item:getContainer() == inventory then
            local tx, ty = pixelForSlot(i - 1, cols)
            tx = bx + tx
            ty = boardTop + ty
            StackRenderer.updateItem(item)
            ctx.stack = tile.synth
            ctx.item = item
            ctx.slot = i - 1
            ctx.x = tx
            ctx.y = ty
            StackRenderer.draw(ctx)

            if searchMarks ~= nil and ItemSearch.marksItem(searchMarks, item) then
                SlotRenderer.drawSearchHint(ctx, searchPulse)
            end
            if applySrc ~= nil
                    and ItemApply.hintFor(applySrc, item, applyPlayer, true) then
                SlotRenderer.drawApplyHint(ctx, applyPulse)
            end

            if tile.id == draggedId or (draggingSel and isSelected(self, tile.id)) then
                self:drawRect(tx + 1, ty + 1, cell - 2, cell - 2,
                    DRAG_SOURCE_WASH_ALPHA, bg.r or 0, bg.g or 0, bg.b or 0)
            end

            local hit, best = StackRenderer.jobOverlayFor(tile.synth, item, jobs, currentAction)
            if hit then StackRenderer.drawJobOverlay(self, tx, ty, best) end

            if isSelected(self, tile.id) then
                SlotRenderer.drawSelection(self, tx, ty)
            end
        end
    end
end

local function drawMarquee(self, bx, boardTop)
    if not self.marqueeActive then return end
    local colors = Style.COLORS
    local selectedColor = colors and colors.SELECTED
    local selectedR = selectedColor and selectedColor.r or 0.35
    local selectedG = selectedColor and selectedColor.g or 0.75
    local selectedB = selectedColor and selectedColor.b or 1.0
    local m0x = math.min(self.marqueeX0, self.marqueeX1)
    local m0y = math.min(self.marqueeY0, self.marqueeY1)
    local m1x = math.max(self.marqueeX0, self.marqueeX1)
    local m1y = math.max(self.marqueeY0, self.marqueeY1)
    self:drawRect(bx + m0x, boardTop + m0y, m1x - m0x, m1y - m0y,
        0.18, selectedR, selectedG, selectedB)
    self:drawRectBorder(bx + m0x, boardTop + m0y, m1x - m0x, m1y - m0y,
        0.9, selectedR, selectedG, selectedB)
end

local function renderImpl(self)
    local bg = InspectorChrome.boardBackground()
    InspectorChrome.drawFrame(self, bg)
    local stack = resolveStack(self)
    if stack == nil then return end
    local inventory = self.model.inventory

    local front = ItemStack.frontItem(stack, inventory)
    local name = front ~= nil and front:getName() or self.itemType
    InspectorChrome.drawTitleBar(self, name, stack.count)

    local bx, by = boardOrigin(self)
    local cols = self.cols
    local visRows = math.min(self.rowsTotal, MAX_VISIBLE_ROWS)
    local bw, bh = Style.gridPixelSize(cols, visRows)
    self:setStencilRect(bx, by, bw, bh)

    local _, fullH = Style.gridPixelSize(cols, self.rowsTotal)
    local boardTop = by - self.yOffset
    self:drawRect(bx, boardTop, bw, fullH, bg.a or 1, bg.r or 0, bg.g or 0, bg.b or 0)

    ctx.view = self
    ctx.playerNum = self.playerNum
    drawMemberTiles(self, inventory, bx, boardTop, bh, bg)
    InspectorChrome.drawTrailingCells(self, ctx, bx, boardTop)
    drawMarquee(self, bx, boardTop)
    InspectorChrome.drawHoverAndPadCursor(self, ctx, bx, boardTop)
    self:clearStencilRect()
end

function StackPopup:render()
    local ok, err = pcall(renderImpl, self)
    if not ok then InspectorChrome.reportError(errors, "render", err) end
end

local function liveTileItem(self, idx)
    local tile = self.tiles[idx + 1]
    if tile == nil then return nil end
    return self.model.inventory:getItemWithID(tile.id)
end

function StackPopup:hoveredItem()
    return InspectorChrome.hoveredItem(self, liveTileItem)
end

function StackPopup:padTileItem(idx)
    return liveTileItem(self, idx)
end

function StackPopup:padTileXY(idx)
    return InspectorChrome.tileXY(self, idx)
end

function StackPopup:padVisibleBoardHeight()
    return InspectorChrome.visibleBoardHeight(self)
end

local function toBoard(self, mx, my)
    local bx, by = boardOrigin(self)
    return mx - bx, my - by + self.yOffset
end

local function updateMarqueeSelection(self)
    local x0 = math.min(self.marqueeX0, self.marqueeX1)
    local y0 = math.min(self.marqueeY0, self.marqueeY1)
    local x1 = math.max(self.marqueeX0, self.marqueeX1)
    local y1 = math.max(self.marqueeY0, self.marqueeY1)
    local selection, count = {}, 0
    local base = self.marqueeBase
    if base ~= nil then
        for id in pairs(base) do selection[id] = true; count = count + 1 end
    end
    local cols = self.cols
    local cell = Style.CELL
    local tiles = self.tiles
    for i = 1, #tiles do
        local tile = tiles[i]
        if not selection[tile.id] then
            local cx, cy = Style.pixelForSlot(tile.synth.slot, cols)
            if x0 < cx + cell and x1 > cx and y0 < cy + cell and y1 > cy then
                selection[tile.id] = true
                count = count + 1
            end
        end
    end
    self.selection = count > 0 and selection or nil
    self.selectionCount = count
end

local function updateMarquee(self, mx, my)
    local lx, ly = toBoard(self, mx, my)
    local w, h = Style.gridPixelSize(self.cols, self.rowsTotal)
    if lx < 0 then lx = 0 elseif lx > w then lx = w end
    if ly < 0 then ly = 0 elseif ly > h then ly = h end
    self.marqueeX1, self.marqueeY1 = lx, ly
    if not self.marqueeActive then
        local dx, dy = lx - self.marqueeX0, ly - self.marqueeY0
        if dx * dx + dy * dy > MARQUEE_THRESHOLD * MARQUEE_THRESHOLD then
            self.marqueeActive = true
        end
    end
    if self.marqueeActive then updateMarqueeSelection(self) end
end

local function endMarquee(self, wasClickable)
    if wasClickable and not self.marqueeActive and self.marqueePressId ~= nil then
        toggleSelected(self, self.marqueePressId)
    end
    self.marqueeArmed = false
    self.marqueeActive = false
    self.marqueePressId = nil
    self.marqueeBase = nil
end

local function buildPayload(self, id)
    local item = self.model.inventory:getItemWithID(id)
    if item == nil then return nil end
    return VanillaStacks.fromItems({ item }, self.model.inventory, self.hostPane)
end

local function payloadFor(self, id)
    if not isSelected(self, id) or self.selectionCount < 2 then
        local payload = buildPayload(self, id)
        return payload ~= nil and { payload } or nil
    end
    local out = {}
    local first = buildPayload(self, id)
    if first ~= nil then out[#out + 1] = first end
    for sid in pairs(self.selection) do
        if sid ~= id then
            local payload = buildPayload(self, sid)
            if payload ~= nil then out[#out + 1] = payload end
        end
    end
    return #out > 0 and out or nil
end

local function dragIdSet(self, id)
    local set = { [id] = true }
    if isSelected(self, id) and self.selectionCount >= 2 then
        for sid in pairs(self.selection) do set[sid] = true end
    end
    return set
end

function StackPopup:padToggleSelect(idx)
    local tile = self.tiles[idx + 1]
    if tile ~= nil then toggleSelected(self, tile.id) end
end

function StackPopup:padDragPayloadFor(idx)
    local tile = self.tiles[idx + 1]
    if tile == nil then return nil end
    return payloadFor(self, tile.id)
end

function StackPopup:padClearSelection()
    if self.selectionCount <= 0 then return false end
    clearSelection(self)
    return true
end

function StackPopup:padIsSelected(idx)
    local tile = self.tiles[idx + 1]
    return tile ~= nil and isSelected(self, tile.id)
end

function StackPopup:padSelectionPayload()
    if self.selection == nil or self.selectionCount < 1 then return nil end
    local out = {}
    local tiles = self.tiles
    for i = 1, #tiles do
        local id = tiles[i].id
        if isSelected(self, id) then
            local payload = buildPayload(self, id)
            if payload ~= nil then out[#out + 1] = payload end
        end
    end
    if #out == 0 then return nil end
    return out
end

local function quickMoveAndCollapse(self, id)
    local payload = payloadFor(self, id)
    if payload ~= nil then
        QuickMove.run(payload, self.model.inventory, self.playerNum)
    end
    clearSelection(self)
end

local function mouseDownImpl(self, x, y)

    if DragAndDrop.isDragOwner(self) and not DragAndDrop.isDragging() then
        DragAndDrop.endDrag()
    end
    self.pressedId = nil
    self.draggedIds = nil
    self.dragDidStart = false
    local idx = tileAt(self, x, y)
    local tile = idx ~= nil and self.tiles[idx + 1] or nil
    local id = tile ~= nil and tile.id or nil

    local Settings = ComfyGrid.Settings
    local markHeld = false
    if Settings ~= nil and Settings.multiSelectHeld ~= nil then
        local okMark, held = pcall(Settings.multiSelectHeld)
        markHeld = okMark and held == true
    end
    if markHeld then
        local lx, ly = toBoard(self, x, y)
        self.marqueeArmed = true
        self.marqueeActive = false
        self.marqueeX0, self.marqueeY0 = lx, ly
        self.marqueeX1, self.marqueeY1 = lx, ly
        self.marqueePressId = id
        local base = {}
        if self.selection ~= nil then
            for sid in pairs(self.selection) do base[sid] = true end
        end
        self.marqueeBase = base
        return
    end
    if idx == nil then
        clearSelection(self)
        return
    end
    local item = liveTileItem(self, idx)
    if item == nil then return end

    local transferHeld = false
    if Settings ~= nil and Settings.transferModifierHeld ~= nil then
        local okTransfer, held = pcall(Settings.transferModifierHeld)
        transferHeld = okTransfer and held == true
    end
    if transferHeld then
        quickMoveAndCollapse(self, id)
        return
    end

    if not isSelected(self, id) then
        clearSelection(self)
    end

    local payload = payloadFor(self, id)
    if payload == nil then return end
    DragAndDrop.prepareDrag(self, payload, x, y)
    self.pressedId = id
    self.draggedIds = dragIdSet(self, id)
end

local function resolveClick(self, id)
    if not gestureIsDoubleClick() then
        clearSelection(self)
        return
    end
    local now = getTimestampMs()
    local pending = self.pendingClick
    if pending ~= nil and pending.id == id
            and now - pending.atMs <= clickWindowMs() then
        self.pendingClick = nil
        quickMoveAndCollapse(self, id)
        return
    end
    self.pendingClick = { id = id, atMs = now }
end

local function doubleClickOnRelease(self, x, y)
    if not gestureIsDoubleClick() then return false end
    local pending = self.pendingClick
    if pending == nil then return false end
    if getTimestampMs() - pending.atMs > clickWindowMs() then return false end
    local idx = tileAt(self, x, y)
    local tile = idx ~= nil and self.tiles[idx + 1] or nil
    local id = tile ~= nil and tile.id or nil
    if id == nil or id ~= pending.id then return false end
    self.pendingClick = nil
    quickMoveAndCollapse(self, id)

    if DragAndDrop.isDragOwner(self) then DragAndDrop.endDrag() end
    self.pressedId = nil
    self.draggedIds = nil
    self.dragDidStart = false
    return true
end

function StackPopup:flushPendingClick()
    local pending = self.pendingClick
    if pending == nil then return end
    if getTimestampMs() - pending.atMs < clickWindowMs() then return end
    self.pendingClick = nil
    clearSelection(self)
end

local function mouseUpImpl(self, x, y)

    if doubleClickOnRelease(self, x, y) then return end

    if self.marqueeArmed then
        endMarquee(self, true)
        self.pressedId = nil
        self.draggedIds = nil
        return
    end
    if DragAndDrop.isDragging() then
        if DragAndDrop.isDragOwner(self) then

            local idx = tileAt(self, x, y)
            local target = idx ~= nil and liveTileItem(self, idx) or nil
            local ItemApply = ComfyGrid.Interact.ItemApply
            if target ~= nil and ItemApply ~= nil then

                local srcItems = ItemApply.liveItemsOf(DragAndDrop.getDraggedStacks(), true)
                local playerObj = getSpecificPlayer(self.playerNum)
                local ownTarget = false
                if srcItems ~= nil then
                    for i = 1, #srcItems do
                        if srcItems[i] == target then ownTarget = true end
                    end
                end
                if srcItems ~= nil and not ownTarget and playerObj ~= nil then
                    local ok, err = pcall(ItemApply.tryApply, srcItems, target, playerObj, true)
                    if not ok then reportMouseError(err) end
                end
            end
            DragAndDrop.endDrag()
        end

    else
        if DragAndDrop.isDragOwner(self) then

            local clicked = self.pressedId ~= nil and not self.dragDidStart
            local clickedId = self.pressedId
            DragAndDrop.endDrag()
            if clicked then resolveClick(self, clickedId) end
        end

        if InspectorChrome.isCloseHit(self, x, y) then
            self:close()
        end
    end
    self.pressedId = nil
    self.draggedIds = nil
end

local function dragCancelImpl(self)
    local ids = self.draggedIds
    self.pressedId = nil
    self.draggedIds = nil
    if ids == nil then return end

    if not DragAndDrop.releaseDropsToFloor(self.playerNum) then return end
    local playerObj = getSpecificPlayer(self.playerNum)
    if playerObj == nil then return end
    local items = {}
    for id in pairs(ids) do
        local item = self.model.inventory:getItemWithID(id)
        if item ~= nil then items[#items + 1] = item end
    end
    if #items == 0 then return end

    local dropped, moveables = Transfer.dropToFloor(items, playerObj)
    if dropped == 0 and moveables ~= nil then
        DragAndDrop.endDrag()
        Transfer.openMoveableCursor(playerObj, moveables[1])
    end
end

local function onDragCancelled(self)
    local ok, err = pcall(dragCancelImpl, self)
    if not ok then reportMouseError(err) end
end

function StackPopup:onComfyDragCancelled()
    onDragCancelled(self)
end

local function mouseUpOutsideImpl(self, _x, _y)
    if self.marqueeArmed then endMarquee(self, false); return end
    if not DragAndDrop.isDragOwner(self) then return end
    if DragAndDrop.isDragging() then
        DragAndDrop.cancelDrag(self, onDragCancelled)
    else
        DragAndDrop.endDrag()
        self.pressedId = nil
        self.draggedIds = nil
    end
end

local function rightMouseUpImpl(self, _x, y)
    if DragAndDrop.isDragging() then return end
    if DragAndDrop.isDragOwner(self) then
        DragAndDrop.endDrag()
        self.pressedId = nil
    end
    local idx = tileAt(self, self:getMouseX(), y)
    if idx == nil then return end
    local tile = self.tiles[idx + 1]
    local item = liveTileItem(self, idx)
    if tile == nil or item == nil then return end

    if isSelected(self, tile.id) and self.selectionCount > 1 then
        local menuStacks = { tile.synth }
        local tiles = self.tiles
        for i = 1, #tiles do
            local otherTile = tiles[i]
            if otherTile.id ~= tile.id and isSelected(self, otherTile.id) then
                menuStacks[#menuStacks + 1] = otherTile.synth
            end
        end
        ContextMenu.open(self.playerNum, menuStacks, self.gridView)
        return
    end

    ContextMenu.open(self.playerNum, { tile.synth }, self.gridView)
end

function StackPopup:onMouseDown(x, y)

    self:bringToTop()
    local ok, err = pcall(mouseDownImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end

function StackPopup:onMouseUp(x, y)
    local ok, err = pcall(mouseUpImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end

function StackPopup:onMouseUpOutside(x, y)
    local ok, err = pcall(mouseUpOutsideImpl, self, x, y)
    if not ok then reportMouseError(err) end
end

function StackPopup:onMouseMove(_dx, _dy)
    if self.marqueeArmed then
        updateMarquee(self, self:getMouseX(), self:getMouseY())
        return
    end
    InspectorChrome.pointerMoved(self)
end

function StackPopup:onMouseMoveOutside(_dx, _dy)
    if self.marqueeArmed then
        updateMarquee(self, self:getMouseX(), self:getMouseY())
        return
    end
    InspectorChrome.pointerMovedOutside(self)
end

function StackPopup:onRightMouseUp(x, y)
    local ok, err = pcall(rightMouseUpImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end

function StackPopup:onMouseWheel(wheelDelta)
    local visRows = math.min(self.rowsTotal, MAX_VISIBLE_ROWS)
    local _, bh = Style.gridPixelSize(self.cols, visRows)
    local _, fullH = Style.gridPixelSize(self.cols, self.rowsTotal)
    local maxOff = math.max(0, fullH - bh)

    self.yOffset = math.max(0, math.min(maxOff,
        self.yOffset + wheelDelta * Style.CELL_STRIDE))
    updateHover(self)
    return true
end

function StackPopup:close()

    self.pendingClick = nil
    InspectorChrome.dismantle(self)
    if instance == self then
        instance = nil
    end
end

function StackPopup.openFor(gridView, stack)
    if gridView == nil or stack == nil or gridView.model == nil then return end
    if instance ~= nil then
        instance:close()
    end
    InspectorChrome.standDownOthers()

    local cx, cy = Style.pixelForSlot(stack.slot, gridView.cols or 1)

    local x = gridView:getAbsoluteX() + cx + Style.CELL + 2
    local y = gridView:getAbsoluteY() + cy
    local popup = StackPopup:new(x, y, gridView, stack)
    InspectorChrome.show(popup)
    instance = popup
    return popup
end

function StackPopup.current()
    return instance
end

PadPopup.attach(StackPopup)

InspectorChrome.installDismissHandlers(StackPopup)

ComfyGrid.UI.Chrome.PopupRegistry.register("StackPopup", StackPopup.current)
