--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/Model/Capacity"
require "ComfyGrid/Settings"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/UI/StackRenderer"
require "ComfyGrid/Interact/DragAndDrop"
require "ComfyGrid/Interact/Transfer"
require "ComfyGrid/Interact/TransferJobs"
require "ComfyGrid/Interact/Highlight"
require "ComfyGrid/Interact/DropHandler"
require "ComfyGrid/Interact/QuickMove"
require "ComfyGrid/Interact/ContextMenu"
require "ComfyGrid/Interact/Pad/PadFocus"
require "ComfyGrid/Interact/Pad/PadCarry"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local VanillaStacks = ComfyGrid.Core.VanillaStacks
local ItemStack = ComfyGrid.Model.ItemStack
local Capacity = ComfyGrid.Model.Capacity
local Settings = ComfyGrid.Settings
local Style = ComfyGrid.UI.Style
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local StackRenderer = ComfyGrid.UI.StackRenderer
local DragAndDrop = ComfyGrid.Interact.DragAndDrop
local Transfer = ComfyGrid.Interact.Transfer
local TransferJobs = ComfyGrid.Interact.TransferJobs
local Highlight = ComfyGrid.Interact.Highlight
local DropHandler = ComfyGrid.Interact.DropHandler
local QuickMove = ComfyGrid.Interact.QuickMove
local ContextMenu = ComfyGrid.Interact.ContextMenu
local PadFocus = ComfyGrid.Interact.PadFocus
local PadCarry = ComfyGrid.Interact.PadCarry

local GridView = ISUIElement:derive("ComfyGridView")
ComfyGrid.UI.GridView = GridView

local DEFAULT_BG = { r = 0.09, g = 0.09, b = 0.11, a = 0.85 }

local DRAG_SOURCE_WASH_ALPHA = 0.6

local ctx = { view = false, stack = false, item = false, slot = 0, x = 0, y = 0, playerNum = 0, inventory = false }

local lastPrerenderError = nil
local lastRenderError = nil

local isFoodType = {}

local MIN_COLS = 2
local MAX_COLS = 32
local DEFAULT_COLS = 8

local function computeDims(self)
    local avail = self.availWidth
    local cols
    if avail == nil then
        cols = DEFAULT_COLS
    else

        cols = math.floor((avail - 1) / Style.CELL_STRIDE)
        if cols < MIN_COLS then cols = MIN_COLS end
        if cols > MAX_COLS then cols = MAX_COLS end
    end
    local grid = self.model.grid
    local rows
    if self.compactEligible and Settings.get("COMPACT_ROWS") then

        rows = math.ceil(grid:contentSlots() / cols)
        if not Capacity.isFull(self.model.inventory, self.playerNum) then
            rows = rows + 1
        end
    else
        rows = math.ceil(grid:slotCount() / cols)
    end
    if rows < 1 then rows = 1 end
    return cols, rows
end

function GridView:new(x, y, model, playerNum)
    if model == nil or model.grid == nil then
        error("ComfyGrid GridView:new requires a ContainerModel")
    end
    local o = ISUIElement:new(x, y, 1, 1)
    setmetatable(o, self)
    self.__index = self
    o.model = model

    o.playerNum = playerNum or model.playerNum

    o.compactEligible = false

    o.availWidth = nil
    o.cols, o.rows = computeDims(o)
    local w, h = Style.gridPixelSize(o.cols, o.rows)
    o:setWidth(w)
    o:setHeight(h)
    o.hoverSlot = nil
    o.lastAbsY = nil

    o.sizeDirty = false

    o.clipHost = nil

    o.pressedStack = nil
    o.pressedSlot = nil
    o.dragDidStart = false

    o.isComfyDragSource = true

    o.selection = nil
    o.selectionCount = 0
    o.selGrid = nil
    o.selStamp = -1

    o.marqueeArmed = false
    o.marqueeActive = false
    o.marqueeX0, o.marqueeY0 = 0, 0
    o.marqueeX1, o.marqueeY1 = 0, 0
    o.marqueePressStack = nil
    o.marqueeBase = nil
    return o
end

local function clearSelection(self)
    self.selection = nil
    self.selectionCount = 0
end

local function isSelected(self, stack)
    local sel = self.selection
    return sel ~= nil and sel[stack] == true
end

local function toggleSelected(self, stack)
    local sel = self.selection
    if sel == nil then
        sel = {}
        self.selection = sel
    end
    if sel[stack] then
        sel[stack] = nil
        self.selectionCount = self.selectionCount - 1
        if self.selectionCount <= 0 then clearSelection(self) end
    else
        sel[stack] = true
        self.selectionCount = self.selectionCount + 1
    end
end

local function syncSelection(self)
    local grid = self.model ~= nil and self.model.grid or nil
    if grid ~= self.selGrid then
        clearSelection(self)
        self.selGrid = grid
        self.selStamp = grid ~= nil and grid.changeCount or -1
        return
    end
    local sel = self.selection
    if sel == nil or grid == nil then return end
    if grid.changeCount == self.selStamp then return end
    self.selStamp = grid.changeCount
    local stacks = grid.data.stacks

    for stack in pairs(sel) do
        local owned = false
        for i = 1, #stacks do
            if stacks[i] == stack then
                owned = true
                break
            end
        end
        if not owned then
            sel[stack] = nil
            self.selectionCount = self.selectionCount - 1
        end
    end
    if self.selectionCount <= 0 then clearSelection(self) end
end

local function updateHover(self)
    if self.model == nil or self.model.grid == nil then
        self.hoverSlot = nil
        return
    end
    self.hoverSlot = Style.slotAtPixel(self:getMouseX(), self:getMouseY(),
        self.cols, self.rows)
end

function GridView:setAvailableWidth(px)
    self.availWidth = px
end

local function prerenderImpl(self)
    local model = self.model
    local inventory = model.inventory
    local drawDirty = inventory ~= nil and inventory:isDrawDirty()
    if drawDirty or model:shouldRefresh() then

        model:refresh(true)
        if drawDirty then
            inventory:setDrawDirty(false)
        end
    end

    local cols, rows = computeDims(self)
    self.cols = cols
    self.rows = rows
    local w, h = Style.gridPixelSize(cols, rows)
    if w ~= self.width or h ~= self.height then
        self:setWidth(w)
        self:setHeight(h)
        self.sizeDirty = true

        updateHover(self)
    end

    local absY = self:getAbsoluteY()
    if absY ~= self.lastAbsY then
        self.lastAbsY = absY
        updateHover(self)
    end
    syncSelection(self)
end

function GridView:prerender()
    if self.model == nil or self.model.grid == nil then return end

    local ok, err = pcall(prerenderImpl, self)
    if not ok and err ~= lastPrerenderError then
        lastPrerenderError = err
        Log.error("GridView prerender failed: " .. tostring(err))
    end
end

local MAX_CLIP_SEARCH_DEPTH = 8
function GridView:visibleBand()
    local host = self.clipHost
    local offY = self:getY()
    local node = self.parent
    if host ~= nil then
        while node ~= nil and node ~= host do
            offY = offY + node:getY()
            node = node.parent
        end
        if node == nil then return nil end
    else
        local depth = 0
        while node ~= nil and depth < MAX_CLIP_SEARCH_DEPTH do
            if node.vscroll ~= nil or node:getYScroll() ~= 0 then
                host = node
                break
            end
            offY = offY + node:getY()
            node = node.parent
            depth = depth + 1
        end
        if host == nil then return nil end
    end

    local top = -(offY + host:getYScroll())
    return top, top + host:getHeight()
end

local boardCtx = { view = false, x = 0, y = 0 }

function GridView:renderBoard()
    local cols = self.cols
    local rows = self.rows
    local w, h = Style.gridPixelSize(cols, rows)
    local colors = Style.COLORS
    local bg = colors and colors.BOARD_BG or DEFAULT_BG

    self:drawRect(0, 0, w, h, bg.a or 1, bg.r or 0, bg.g or 0, bg.b or 0)

    local cullTop, cullBottom = self:visibleBand()
    local stride = Style.CELL_STRIDE
    local cell = Style.CELL
    boardCtx.view = self
    for row = 0, rows - 1 do
        local y = row * stride
        if cullTop == nil or (y + cell > cullTop and y < cullBottom) then
            for col = 0, cols - 1 do
                boardCtx.x = col * stride
                boardCtx.y = y
                SlotRenderer.drawCell(boardCtx, nil)
            end
        end
    end
end

local function renderAll(self)
    self:renderBoard()
    local model = self.model
    local grid = model.grid
    local inventory = model.inventory
    local cols = self.cols
    local rows = self.rows
    local cell = Style.CELL
    local cullTop, cullBottom = self:visibleBand()
    local pixelForSlot = Style.pixelForSlot
    local frontItem = ItemStack.frontItem
    local updateItem = StackRenderer.updateItem
    local drawStack = StackRenderer.draw
    local stacks = grid.data.stacks
    ctx.view = self
    ctx.playerNum = self.playerNum
    ctx.inventory = inventory

    local draggedStack = nil
    local washR, washG, washB = 0, 0, 0
    if self.pressedStack ~= nil and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(self) then
        draggedStack = self.pressedStack
        local colors = Style.COLORS
        local bg = colors and colors.BOARD_BG or DEFAULT_BG
        washR = bg.r or 0
        washG = bg.g or 0
        washB = bg.b or 0
    end

    local padCarried = PadCarry.carriedStackOn(self)
    if padCarried ~= nil and draggedStack == nil then
        local colors = Style.COLORS
        local bg = colors and colors.BOARD_BG or DEFAULT_BG
        washR = bg.r or 0
        washG = bg.g or 0
        washB = bg.b or 0
    end

    local selection = self.selection
    local draggingSelection = draggedStack ~= nil and selection ~= nil
        and selection[draggedStack] == true

    local jobs = TransferJobs.itemsFor(inventory)
    local currentAction = StackRenderer.currentActionOf(self.playerNum)

    local highlightIds = Highlight.idsFor(self.playerNum)

    local ItemApply = ComfyGrid.Interact.ItemApply
    local applySrc = ItemApply ~= nil and ItemApply.dragSource() or nil
    local applyPlayer = nil
    local applyPulse = 1
    if applySrc ~= nil then
        applyPlayer = getSpecificPlayer(self.playerNum)
        if applyPlayer == nil then applySrc = nil end
        applyPulse = SlotRenderer.applyPulse()
    end
    for i = 1, #stacks do
        local stack = stacks[i]
        local sx, sy = pixelForSlot(stack.slot, cols)

        if cullTop == nil or (sy + cell > cullTop and sy < cullBottom) then
            local front = frontItem(stack, inventory)

            if front ~= nil then

                updateItem(front)
                local isFood = isFoodType[stack.itemType]
                if isFood == nil then
                    isFood = instanceof(front, "Food") or false
                    if stack.itemType ~= nil then
                        isFoodType[stack.itemType] = isFood
                    end
                end
                if isFood and stack.count > 1 then

                    for id in pairs(stack.itemIDs) do
                        local it = inventory:getItemWithID(id)
                        if it ~= nil and it ~= front then updateItem(it) end
                    end
                end
                ctx.stack = stack
                ctx.item = front
                ctx.slot = stack.slot
                ctx.x = sx
                ctx.y = sy
                drawStack(ctx)
                if applySrc ~= nil
                        and ItemApply.hintFor(applySrc, front, applyPlayer) then
                    SlotRenderer.drawApplyHint(ctx, applyPulse)
                end
                if highlightIds ~= nil
                        and Highlight.hasStack(highlightIds, stack) then
                    SlotRenderer.drawHighlight(ctx)
                end

                if stack == draggedStack or stack == padCarried
                        or (draggingSelection and selection[stack]) then
                    self:drawRect(sx + 1, sy + 1, cell - 2, cell - 2,
                        DRAG_SOURCE_WASH_ALPHA, washR, washG, washB)
                end

                if selection ~= nil and selection[stack] then
                    SlotRenderer.drawSelection(self, sx, sy)
                end

                local hit, best = StackRenderer.jobOverlayFor(stack, front, jobs, currentAction)
                if hit then
                    StackRenderer.drawJobOverlay(self, sx, sy, best)
                end
            end
        end
    end

    local hoverSlot = self.hoverSlot
    if hoverSlot ~= nil and (hoverSlot < 0 or hoverSlot >= cols * rows
            or not self:isMouseOver()) then
        hoverSlot = nil
    end
    local Draw = ComfyGrid.UI.Draw
    if Draw ~= nil then
        local ht = self.hoverT
        if ht == nil then
            ht = {}
            self.hoverT = ht
        end
        if hoverSlot ~= nil and ht[hoverSlot] == nil then
            ht[hoverSlot] = 0
        end
        for slot, heat in pairs(ht) do
            heat = Draw.glide(heat, slot == hoverSlot and 1 or 0, 0.45)
            if heat <= 0 then
                ht[slot] = nil
            else
                ht[slot] = heat
                if slot < cols * rows then
                    local hx, hy = pixelForSlot(slot, cols)
                    ctx.stack = grid:stackAt(slot)
                    ctx.item = nil
                    ctx.slot = slot
                    ctx.x = hx
                    ctx.y = hy
                    SlotRenderer.drawHover(ctx, heat)
                end
            end
        end
    elseif hoverSlot ~= nil then
        local hx, hy = pixelForSlot(hoverSlot, cols)
        ctx.stack = grid:stackAt(hoverSlot)
        ctx.item = nil
        ctx.slot = hoverSlot
        ctx.x = hx
        ctx.y = hy
        SlotRenderer.drawHover(ctx)
    end

    local padSlot = PadFocus.cursorFor(self)
    if padSlot ~= nil and padSlot < cols * rows then
        local px, py = pixelForSlot(padSlot, cols)
        SlotRenderer.drawSelection(self, px, py)
        ctx.stack = grid:stackAt(padSlot)
        ctx.item = nil
        ctx.slot = padSlot
        ctx.x = px
        ctx.y = py
        SlotRenderer.drawHover(ctx)

        PadCarry.renderAt(self, px, py)
    end

    if self.marqueeActive then
        local mx0 = math.min(self.marqueeX0, self.marqueeX1)
        local my0 = math.min(self.marqueeY0, self.marqueeY1)
        local mw = math.abs(self.marqueeX1 - self.marqueeX0)
        local mh = math.abs(self.marqueeY1 - self.marqueeY0)
        local sc = Style.COLORS and Style.COLORS.SELECTED
        local sr, sg, sb = sc and sc.r or 0.35, sc and sc.g or 0.75, sc and sc.b or 1.0
        self:drawRect(mx0, my0, mw, mh, 0.18, sr, sg, sb)
        self:drawRectBorder(mx0, my0, mw, mh, 0.9, sr, sg, sb)
    end
end

function GridView:render()
    if self.model == nil or self.model.grid == nil then return end
    local ok, err = pcall(renderAll, self)
    if not ok and err ~= lastRenderError then
        lastRenderError = err
        Log.error("GridView render failed: " .. tostring(err))
    end
end

function GridView:slotAt(x, y)
    if self.model == nil or self.model.grid == nil then return nil end
    return Style.slotAtPixel(x, y, self.cols, self.rows)
end

function GridView:isMouseOverSlot(slot)
    if slot == nil or not self:isMouseOver() then return false end
    return self:slotAt(self:getMouseX(), self:getMouseY()) == slot
end

local lastMouseError = nil
local function reportMouseError(err)
    if err ~= lastMouseError then
        lastMouseError = err
        Log.error("GridView mouse handling failed: " .. tostring(err))
    end
end

local function hostPane(self)
    local node = self.parent
    while node ~= nil do
        if node.pane ~= nil then return node.pane end
        node = node.parent
    end
    return nil
end

local function stackAtPixel(self, x, y)
    local model = self.model
    if model == nil or model.grid == nil then return nil end
    local slot = self:slotAt(x, y)
    if slot == nil then return nil end
    return model.grid:stackAt(slot), slot
end

local function buildPayload(self, stack)
    local payload = VanillaStacks.listFrom({ stack }, self.model.inventory,
        hostPane(self))
    if #payload == 0 then return nil end
    payload[1].comfyStacks = stack
    return payload
end

local function payloadFor(self, stack)
    if not isSelected(self, stack) or self.selectionCount < 2 then
        return buildPayload(self, stack)
    end
    local ordered = {}
    for s in pairs(self.selection) do
        ordered[#ordered + 1] = s
    end
    table.sort(ordered, function(a, b)
        return (a.slot or 0) < (b.slot or 0)
    end)
    local out = {}
    for i = 1, #ordered do
        local p = buildPayload(self, ordered[i])
        if p ~= nil then
            out[#out + 1] = p[1]
        end
    end
    if #out == 0 then return nil end
    return out
end

function GridView:dragPayloadFor(stack)
    return payloadFor(self, stack)
end

function GridView:padToggleSelect(stack)
    if stack == nil then return end
    syncSelection(self)
    toggleSelected(self, stack)
end

function GridView:padClearSelection()
    if self.selectionCount <= 0 then return false end
    clearSelection(self)
    return true
end

function GridView:padIsSelected(stack)
    syncSelection(self)
    return isSelected(self, stack)
end

function GridView:padSelectionPayload()
    syncSelection(self)
    local sel = self.selection
    if sel == nil or self.selectionCount < 1 then return nil end
    local ordered = {}
    for s in pairs(sel) do
        ordered[#ordered + 1] = s
    end
    table.sort(ordered, function(a, b)
        return (a.slot or 0) < (b.slot or 0)
    end)
    local out = {}
    for i = 1, #ordered do
        local p = buildPayload(self, ordered[i])
        if p ~= nil then
            out[#out + 1] = p[1]
        end
    end
    if #out == 0 then return nil end
    return out
end

local function dragCancelImpl(owner)
    local payload = DragAndDrop.getDraggedStacks()
    owner.pressedStack = nil
    owner.pressedSlot = nil
    if payload == nil then return end
    if not DragAndDrop.releaseDropsToFloor(owner.playerNum) then return end
    local model = owner.model
    local inventory = model ~= nil and model.inventory or nil
    if inventory == nil then return end

    local items = nil
    for i = 1, #payload do
        local tag = payload[i].comfyStacks or payload[i].comfyStack
        if type(tag) == "table" and tag.itemIDs == nil then
            tag = tag[1]
        end
        if type(tag) == "table" and tag.itemIDs ~= nil then
            local live = ItemStack.getItems(tag, inventory)
            for j = 1, #live do
                items = items or {}
                items[#items + 1] = live[j]
            end
        end
    end
    if items == nil then return end
    local playerObj = getSpecificPlayer(owner.playerNum)
    if playerObj == nil then return end
    local dropped, moveables = Transfer.dropToFloor(items, playerObj)

    if dropped == 0 and moveables ~= nil then

        DragAndDrop.endDrag()
        Transfer.openMoveableCursor(playerObj, moveables[1])
    end
end

local function onDragCancelled(owner)
    local ok, err = pcall(dragCancelImpl, owner)
    if not ok then reportMouseError(err) end
end

function GridView:onComfyDragCancelled()
    onDragCancelled(self)
end

local function promoteDrag(self)

    if DragAndDrop == nil then return end
    DragAndDrop.startDrag(self)
    if not self.dragDidStart and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(self) then
        self.dragDidStart = true
    end
end

local MARQUEE_THRESHOLD = 6

local function updateMarqueeSelection(self)
    local x0 = math.min(self.marqueeX0, self.marqueeX1)
    local y0 = math.min(self.marqueeY0, self.marqueeY1)
    local x1 = math.max(self.marqueeX0, self.marqueeX1)
    local y1 = math.max(self.marqueeY0, self.marqueeY1)
    local sel, count = {}, 0
    local base = self.marqueeBase
    if base ~= nil then
        for s in pairs(base) do sel[s] = true; count = count + 1 end
    end
    local cols = self.cols
    local cell = Style.CELL
    local stacks = self.model.grid.data.stacks
    for i = 1, #stacks do
        local s = stacks[i]
        if s ~= nil and s.slot ~= nil and not sel[s] then
            local cx, cy = Style.pixelForSlot(s.slot, cols)

            if x0 < cx + cell and x1 > cx and y0 < cy + cell and y1 > cy then
                sel[s] = true
                count = count + 1
            end
        end
    end
    self.selection = count > 0 and sel or nil
    self.selectionCount = count
end

local function updateMarquee(self, mx, my)
    local w, h = Style.gridPixelSize(self.cols, self.rows)
    if mx < 0 then mx = 0 elseif mx > w then mx = w end
    if my < 0 then my = 0 elseif my > h then my = h end
    self.marqueeX1, self.marqueeY1 = mx, my
    if not self.marqueeActive then
        local dx, dy = mx - self.marqueeX0, my - self.marqueeY0
        if dx * dx + dy * dy > MARQUEE_THRESHOLD * MARQUEE_THRESHOLD then
            self.marqueeActive = true
        end
    end
    if self.marqueeActive then updateMarqueeSelection(self) end
end

local function endMarquee(self, wasClickable)
    if wasClickable and not self.marqueeActive and self.marqueePressStack ~= nil then
        toggleSelected(self, self.marqueePressStack)
    end
    self.marqueeArmed = false
    self.marqueeActive = false
    self.marqueePressStack = nil
    self.marqueeBase = nil
end

local function mouseDownImpl(self, x, y)

    if DragAndDrop.isDragOwner(self) and not DragAndDrop.isDragging() then
        DragAndDrop.endDrag()
    end
    self.pressedStack = nil
    self.pressedSlot = nil
    self.dragDidStart = false
    local stack, slot = stackAtPixel(self, x, y)

    if isCtrlKeyDown() and not isShiftKeyDown() then
        self.marqueeArmed = true
        self.marqueeActive = false
        self.marqueeX0, self.marqueeY0 = x, y
        self.marqueeX1, self.marqueeY1 = x, y
        self.marqueePressStack = stack
        local base = {}
        if self.selection ~= nil then
            for s in pairs(self.selection) do base[s] = true end
        end
        self.marqueeBase = base
        return
    end
    if stack == nil then

        clearSelection(self)
        return
    end

    if not isSelected(self, stack) then
        clearSelection(self)
    end
    local payload = payloadFor(self, stack)
    if payload == nil then return end

    if isShiftKeyDown() then

        QuickMove.run(payload, self.model.inventory, self.playerNum)
        clearSelection(self)
        return
    end
    DragAndDrop.prepareDrag(self, payload, x, y)
    self.pressedStack = stack
    self.pressedSlot = slot
end

local function mouseUpImpl(self, x, y)

    if self.marqueeArmed then endMarquee(self, true); return end
    if DragAndDrop.isDragging() then

        local poked = x == 0 and y == 0 and DragAndDrop.isDragOwner(self)
            and (self:getMouseX() ~= 0 or self:getMouseY() ~= 0)
        if not poked and self:isMouseOver() then

            DropHandler.resolve(self, x, y)
            DragAndDrop.endDrag()
        elseif DragAndDrop.isDragOwner(self) then

            DragAndDrop.endDrag()
        end

    elseif DragAndDrop.isDragOwner(self) then
        local stack = self.pressedStack
        DragAndDrop.endDrag()
        if stack ~= nil and not self.dragDidStart then

            clearSelection(self)
            self:onStackClicked(stack, x, y)
        end
    end
    self.pressedStack = nil
    self.pressedSlot = nil
end

local function mouseUpOutsideImpl(self, _x, _y)

    if self.marqueeArmed then endMarquee(self, false); return end
    if not DragAndDrop.isDragOwner(self) then return end
    if DragAndDrop.isDragging() then

        DragAndDrop.cancelDrag(self, onDragCancelled)
    else

        DragAndDrop.endDrag()
        self.pressedStack = nil
        self.pressedSlot = nil
    end
end

local function rightMouseUpImpl(self, x, y)
    if DragAndDrop.isDragging() then return end

    if DragAndDrop.isDragOwner(self) then
        DragAndDrop.endDrag()
        self.pressedStack = nil
        self.pressedSlot = nil
    end
    local stack = stackAtPixel(self, x, y)
    if stack == nil then return end
    if isSelected(self, stack) and self.selectionCount > 1 then

        local list = { stack }
        for s in pairs(self.selection) do
            if s ~= stack then list[#list + 1] = s end
        end
        ContextMenu.open(self.playerNum, list, self)
        return
    end
    ContextMenu.open(self.playerNum, { stack }, self)
end

function GridView:onStackClicked(stack, _x, _y)
    if stack == nil or stack.count == nil or stack.count < 2 then return end
    local StackPopup = ComfyGrid.UI.StackPopup
    if StackPopup == nil or StackPopup.openFor == nil then return end
    local ok, err = pcall(StackPopup.openFor, self, stack)
    if not ok then reportMouseError(err) end
end

function GridView:onMouseMove(_dx, _dy)
    if self.marqueeArmed then
        updateMarquee(self, self:getMouseX(), self:getMouseY())
        return
    end
    updateHover(self)
    promoteDrag(self)
end

function GridView:onMouseMoveOutside(_dx, _dy)
    if self.marqueeArmed then
        updateMarquee(self, self:getMouseX(), self:getMouseY())
        return
    end
    self.hoverSlot = nil

    promoteDrag(self)
end

function GridView:onMouseDown(x, y)
    local ok, err = pcall(mouseDownImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end

function GridView:onMouseUp(x, y)
    local ok, err = pcall(mouseUpImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end

function GridView:onMouseUpOutside(x, y)
    local ok, err = pcall(mouseUpOutsideImpl, self, x, y)
    if not ok then reportMouseError(err) end
end

function GridView.onRightMouseDown(_self, _x, _y)
    return true
end

function GridView:onRightMouseUp(x, y)
    local ok, err = pcall(rightMouseUpImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end
