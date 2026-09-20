--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.6
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Chrome/PopupRegistry"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/UI/StackRenderer"
require "ComfyGrid/Interact/DragAndDrop"
require "ComfyGrid/Interact/Transfer"
require "ComfyGrid/Interact/TransferJobs"
require "ComfyGrid/Interact/QuickMove"
require "ComfyGrid/Interact/ContextMenu"
require "ComfyGrid/Interact/Pad/PadPopup"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local VanillaStacks = ComfyGrid.Core.VanillaStacks
local Text = ComfyGrid.Core.Text
local ItemStack = ComfyGrid.Model.ItemStack
local Style = ComfyGrid.UI.Style
local SlotRenderer = ComfyGrid.UI.SlotRenderer
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
local PAD_X = 4

local function closeChip()
    return math.max(14, math.floor(Style.FONT_H * 0.9 + 0.5))
end

local function closeZoneLeft(w)
    return w - (closeChip() + 12)
end

local MARQUEE_THRESHOLD = 6
local DRAG_SOURCE_WASH_ALPHA = 0.6

local DEFAULT_BG = { r = 0.07, g = 0.07, b = 0.09, a = 0.96 }
local DEFAULT_TEXT = { r = 0.9, g = 0.9, b = 0.9, a = 1 }

local CHROME = { r = 0.44, g = 0.39, b = 0.29, a = 0.8 }

local ctx = { view = false, stack = false, item = false, slot = 0, x = 0, y = 0, playerNum = 0, skipWeightMark = true }

local lastPrerenderError = nil
local lastRenderError = nil
local lastMouseError = nil
local function reportMouseError(err)
    if err ~= lastMouseError then
        lastMouseError = err
        Log.error("StackPopup mouse handling failed: " .. tostring(err))
    end
end

local function freshFracFor(item)
    if not instanceof(item, "Food") then return nil end
    if item.isRotten and item:isRotten() then return 0 end
    if item.getAge and item.getOffAgeMax then
        local ok, age = pcall(item.getAge, item)
        local ok2, offMax = pcall(item.getOffAgeMax, item)
        if ok and ok2 and type(age) == "number" and type(offMax) == "number"
                and offMax > 0 and age >= 0 then
            local frac = 1 - age / offMax
            if frac < 0 then frac = 0 end
            if frac > 1 then frac = 1 end
            return frac
        end
    end
    return nil
end

local function paneOf(gridView)
    local node = gridView ~= nil and gridView.parent or nil
    while node ~= nil do
        if node.pane ~= nil then return node.pane end
        node = node.parent
    end
    return nil
end

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

    o.hostPane = paneOf(gridView)

    o.selection = nil
    o.selectionCount = 0
    o.draggedIds = nil

    o.marqueeArmed = false
    o.marqueeActive = false
    o.marqueeX0, o.marqueeY0 = 0, 0
    o.marqueeX1, o.marqueeY1 = 0, 0
    o.marqueePressId = nil
    o.marqueeBase = nil
    o.titleH = math.max(18, Style.FONT_H + 4, math.floor(Style.CELL / 2))
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
    local n = #self.tiles
    if n < 1 then n = 1 end
    local cols = math.ceil(math.sqrt(n))
    if cols < MIN_COLS then cols = MIN_COLS end
    if cols > MAX_COLS then cols = MAX_COLS end
    self.cols = cols
    self.rowsTotal = math.ceil(n / cols)
    local visRows = math.min(self.rowsTotal, MAX_VISIBLE_ROWS)
    local bw, bh = Style.gridPixelSize(cols, visRows)
    local w = bw + PAD_X * 2
    local h = self.titleH + bh + 4
    if self.width ~= w then self:setWidth(w) end
    if self.height ~= h then self:setHeight(h) end

    local core = getCore()
    local screenW = core and core:getScreenWidth() or 1920
    local screenH = core and core:getScreenHeight() or 1080
    local x = self:getX()
    local y = self:getY()
    if x + w > screenW then x = math.max(0, screenW - w) end
    if y + h > screenH then y = math.max(0, screenH - h) end
    if x ~= self:getX() then self:setX(x) end
    if y ~= self:getY() then self:setY(y) end

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

local function boardOrigin(self)
    return PAD_X, self.titleH
end

local function tileAt(self, x, y)
    local bx, by = boardOrigin(self)
    local idx = Style.slotAtPixel(x - bx, y - by + self.yOffset,
        self.cols, self.rowsTotal)
    if idx == nil or idx >= #self.tiles then return nil end
    return idx
end

local function updateHover(self)
    self.hoverTile = tileAt(self, self:getMouseX(), self:getMouseY())
end

local function clearSelection(self)
    self.selection = nil
    self.selectionCount = 0
end

local function gestureIsDoubleClick()
    local S = ComfyGrid.Settings
    if S == nil or S.transferIsDoubleClick == nil then return false end
    local ok, v = pcall(S.transferIsDoubleClick)
    return ok and v == true
end

local function clickWindowMs()
    local GV = ComfyGrid.UI and ComfyGrid.UI.GridView
    return (GV ~= nil and GV.CLICK_DELAY_MS) or 260
end

local function isSelected(self, id)
    local sel = self.selection
    return sel ~= nil and sel[id] == true
end

local function toggleSelected(self, id)
    if id == nil then return end
    local sel = self.selection
    if sel == nil then sel = {}; self.selection = sel end
    if sel[id] then
        sel[id] = nil
        self.selectionCount = self.selectionCount - 1
        if self.selectionCount <= 0 then clearSelection(self) end
    else
        sel[id] = true
        self.selectionCount = self.selectionCount + 1
    end
end

local function syncSelection(self, stack)
    local sel = self.selection
    if sel == nil then return end
    for id in pairs(sel) do
        if stack.itemIDs[id] == nil then
            sel[id] = nil
            self.selectionCount = self.selectionCount - 1
        end
    end
    if self.selectionCount <= 0 then clearSelection(self) end
end

local function stillOnScreen(self)
    local inv = self.model ~= nil and self.model.inventory or nil
    if inv == nil then return false end
    local seat = self.playerNum or 0
    for _, get in ipairs({ getPlayerInventory, getPlayerLoot }) do
        local okP, page = pcall(get, seat)
        local pane = okP and page ~= nil and page.inventoryPane or nil
        local host = pane ~= nil and pane.comfyHost or nil
        if host ~= nil and host.showsInventory ~= nil then
            local okS, shown = pcall(host.showsInventory, host, inv)
            if okS and shown then return true end
        end
    end
    local CW = ComfyGrid.UI ~= nil and ComfyGrid.UI.ContainerWindow or nil
    if CW ~= nil and CW.showsInventory ~= nil then
        local okC, shown = pcall(CW.showsInventory, seat, inv)
        if okC and shown then return true end
    end
    return false
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
    syncSelection(self, stack)

    local cc = self.model.grid.changeCount
    if cc ~= self.lastChangeCount then
        self.lastChangeCount = cc
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
    if not ok and err ~= lastPrerenderError then
        lastPrerenderError = err
        Log.error("StackPopup prerender failed: " .. tostring(err))
    end
end

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

    local stack = resolveStack(self)
    if stack == nil then return end
    local inventory = self.model.inventory
    local font = Style.FONT

    local front = ItemStack.frontItem(stack, inventory)
    local name = front ~= nil and front:getName() or self.itemType
    local suffix = " x" .. tostring(stack.count)
    if font ~= nil then

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
                or self._titleFitSrc ~= name or self._titleFitSuffix ~= suffix
                then
            self._titleFitGen = fitGen
            self._titleFitSrc = name
            self._titleFitSuffix = suffix
            self._titleFit = Text.fitEllipsis(name, font, budget, 60) .. suffix
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
    local visRows = math.min(self.rowsTotal, MAX_VISIBLE_ROWS)
    local bw, bh = Style.gridPixelSize(cols, visRows)
    self:setStencilRect(bx, by, bw, bh)

    local _, fullH = Style.gridPixelSize(cols, self.rowsTotal)
    local stride = Style.CELL_STRIDE
    local boardTop = by - self.yOffset
    self:drawRect(bx, boardTop, bw, fullH, bg.a or 1, bg.r or 0, bg.g or 0, bg.b or 0)

    local tiles = self.tiles
    local pixelForSlot = Style.pixelForSlot
    local cell = Style.CELL
    ctx.view = self
    ctx.playerNum = self.playerNum

    local jobs = TransferJobs.itemsFor and TransferJobs.itemsFor(inventory) or nil
    local currentAction = StackRenderer.currentActionOf(self.playerNum)
    local draggedId = nil
    if self.pressedId ~= nil and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(self) then
        draggedId = self.pressedId
    end
    local draggingSel = draggedId ~= nil and isSelected(self, draggedId)
    local selC = colors and colors.SELECTED
    local selR = selC and selC.r or 0.35
    local selG = selC and selC.g or 0.75
    local selB = selC and selC.b or 1.0
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

            local frac = freshFracFor(item)
            if frac ~= nil then
                local bc = StackRenderer.rampColor(frac)
                local bx0 = tx + 5
                local by0 = ty + cell - 8
                local trackW = cell - 13
                self:drawRect(bx0 + 1, by0, trackW - 2, 3,
                    0.3, 0.05, 0.05, 0.05)
                local fillW = math.floor(trackW * frac + 0.5)
                if fillW < 2 and frac > 0 then fillW = 2 end
                if fillW > 0 then
                    self:drawRect(bx0, by0 + 1, 1, 1, 0.95, bc.r, bc.g, bc.b)
                    if fillW > 2 then
                        self:drawRect(bx0 + 1, by0, fillW - 2, 3,
                            0.95, bc.r, bc.g, bc.b)
                    end
                    self:drawRect(bx0 + fillW - 1, by0 + 1, 1, 1,
                        0.95, bc.r, bc.g, bc.b)
                end
            end

            if isSelected(self, tile.id) then
                SlotRenderer.drawSelection(self, tx, ty)
            end
        end
    end

    for i = #tiles + 1, cols * self.rowsTotal do
        local ex, ey = pixelForSlot(i - 1, cols)
        ctx.stack = nil
        ctx.item = nil
        ctx.slot = i - 1
        ctx.x = bx + ex
        ctx.y = boardTop + ey
        SlotRenderer.drawCell(ctx, nil)
    end

    if self.marqueeActive then
        local m0x = math.min(self.marqueeX0, self.marqueeX1)
        local m0y = math.min(self.marqueeY0, self.marqueeY1)
        local m1x = math.max(self.marqueeX0, self.marqueeX1)
        local m1y = math.max(self.marqueeY0, self.marqueeY1)
        self:drawRect(bx + m0x, boardTop + m0y, m1x - m0x, m1y - m0y,
            0.18, selR, selG, selB)
        self:drawRectBorder(bx + m0x, boardTop + m0y, m1x - m0x, m1y - m0y,
            0.9, selR, selG, selB)
    end

    local hover = self.hoverTile
    if hover ~= nil and hover < #tiles and self:isMouseOver() then
        local hx, hy = pixelForSlot(hover, cols)
        ctx.stack = tiles[hover + 1].synth
        ctx.item = nil
        ctx.slot = hover
        ctx.x = bx + hx
        ctx.y = boardTop + hy
        SlotRenderer.drawHover(ctx)
    end

    local padIdx = PadPopup.cursorFor(self)
    if padIdx ~= nil and padIdx < #tiles then
        local px, py = pixelForSlot(padIdx, cols)
        SlotRenderer.drawSelection(self, bx + px, boardTop + py)
        ctx.stack = tiles[padIdx + 1].synth
        ctx.item = nil
        ctx.slot = padIdx
        ctx.x = bx + px
        ctx.y = boardTop + py
        SlotRenderer.drawHover(ctx)
    end

    self:clearStencilRect()
end

function StackPopup:render()
    local ok, err = pcall(renderImpl, self)
    if not ok and err ~= lastRenderError then
        lastRenderError = err
        Log.error("StackPopup render failed: " .. tostring(err))
    end
end

local function liveTileItem(self, idx)
    local tile = self.tiles[idx + 1]
    if tile == nil then return nil end
    return self.model.inventory:getItemWithID(tile.id)
end

function StackPopup:hoveredItem()
    local idx = self.hoverTile
    if idx == nil or not self:isMouseOver() then return nil end
    return liveTileItem(self, idx)
end

function StackPopup:padTileItem(idx)
    return liveTileItem(self, idx)
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
    local sel, count = {}, 0
    local base = self.marqueeBase
    if base ~= nil then
        for id in pairs(base) do sel[id] = true; count = count + 1 end
    end
    local cols = self.cols
    local cell = Style.CELL
    local tiles = self.tiles
    for i = 1, #tiles do
        local tile = tiles[i]
        if not sel[tile.id] then
            local cx, cy = Style.pixelForSlot(tile.synth.slot, cols)
            if x0 < cx + cell and x1 > cx and y0 < cy + cell and y1 > cy then
                sel[tile.id] = true
                count = count + 1
            end
        end
    end
    self.selection = count > 0 and sel or nil
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
        local p = buildPayload(self, id)
        return p ~= nil and { p } or nil
    end
    local out = {}
    local first = buildPayload(self, id)
    if first ~= nil then out[#out + 1] = first end
    for sid in pairs(self.selection) do
        if sid ~= id then
            local p = buildPayload(self, sid)
            if p ~= nil then out[#out + 1] = p end
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
            local p = buildPayload(self, id)
            if p ~= nil then out[#out + 1] = p end
        end
    end
    if #out == 0 then return nil end
    return out
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

    local S = ComfyGrid.Settings
    local markHeld = false
    if S ~= nil and S.multiSelectHeld ~= nil then
        local okM, v = pcall(S.multiSelectHeld)
        markHeld = okM and v == true
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
    if S ~= nil and S.transferModifierHeld ~= nil then
        local okG, v = pcall(S.transferModifierHeld)
        transferHeld = okG and v == true
    end
    if transferHeld then
        local payload = payloadFor(self, id)
        if payload ~= nil then
            QuickMove.run(payload, self.model.inventory, self.playerNum)
        end
        clearSelection(self)
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
        local payload = payloadFor(self, id)
        if payload ~= nil and QuickMove ~= nil then
            QuickMove.run(payload, self.model.inventory, self.playerNum)
        end
        clearSelection(self)
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
    local payload = payloadFor(self, id)
    if payload ~= nil and QuickMove ~= nil and self.model ~= nil then
        QuickMove.run(payload, self.model.inventory, self.playerNum)
    end
    clearSelection(self)

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

        if not self.dragDidStart and y < self.titleH
                and x > closeZoneLeft(self.width) then
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
        local list = { tile.synth }
        local tiles = self.tiles
        for i = 1, #tiles do
            local t = tiles[i]
            if t.id ~= tile.id and isSelected(self, t.id) then
                list[#list + 1] = t.synth
            end
        end
        ContextMenu.open(self.playerNum, list, self.gridView)
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
    updateHover(self)
    if DragAndDrop == nil then return end
    DragAndDrop.startDrag(self)
    if not self.dragDidStart and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(self) then
        self.dragDidStart = true
    end
end

function StackPopup:onMouseMoveOutside(_dx, _dy)
    if self.marqueeArmed then
        updateMarquee(self, self:getMouseX(), self:getMouseY())
        return
    end
    self.hoverTile = nil

    if DragAndDrop ~= nil then
        DragAndDrop.startDrag(self)
        if not self.dragDidStart and DragAndDrop.isDragging()
                and DragAndDrop.isDragOwner(self) then
            self.dragDidStart = true
        end
    end
end

function StackPopup:onMouseDownOutside(_x, _y)
    self:close()
end

function StackPopup:onRightMouseDownOutside(_x, _y)
    self:close()
end

function StackPopup.onRightMouseDown(_self, _x, _y)
    return true
end

function StackPopup:onRightMouseUp(x, y)
    local ok, err = pcall(rightMouseUpImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end

function StackPopup:onMouseWheel(del)
    local visRows = math.min(self.rowsTotal, MAX_VISIBLE_ROWS)
    local _, bh = Style.gridPixelSize(self.cols, visRows)
    local _, fullH = Style.gridPixelSize(self.cols, self.rowsTotal)
    local maxOff = math.max(0, fullH - bh)

    self.yOffset = math.max(0, math.min(maxOff,
        self.yOffset + del * Style.CELL_STRIDE))
    updateHover(self)
    return true
end

function StackPopup:close()

    self.pendingClick = nil

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

function StackPopup.openFor(gridView, stack)
    if gridView == nil or stack == nil or gridView.model == nil then return end
    if instance ~= nil then
        instance:close()
    end

    local Chrome = ComfyGrid.UI and ComfyGrid.UI.Chrome
    local Registry = Chrome ~= nil and Chrome.PopupRegistry or nil
    if Registry ~= nil then Registry.closeOthers(nil) end

    local cx, cy = Style.pixelForSlot(stack.slot, gridView.cols or 1)

    local x = gridView:getAbsoluteX() + cx + Style.CELL + 2
    local y = gridView:getAbsoluteY() + cy
    local popup = StackPopup:new(x, y, gridView, stack)
    popup:initialise()
    popup:addToUIManager()
    popup:bringToTop()
    instance = popup
    return popup
end

function StackPopup.current()
    return instance
end

PadPopup.attach(StackPopup)

ComfyGrid.UI.Chrome.PopupRegistry.register("StackPopup", StackPopup.current)
