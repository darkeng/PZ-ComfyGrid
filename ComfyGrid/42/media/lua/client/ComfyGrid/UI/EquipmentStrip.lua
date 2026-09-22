--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.8
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Model/Equipment"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Chrome/SectionRule"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/UI/StackRenderer"
require "ComfyGrid/Interact/DragAndDrop"
require "ComfyGrid/Interact/Transfer"
require "ComfyGrid/Interact/Unequip"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local VanillaStacks = ComfyGrid.Core.VanillaStacks
local Equipment = ComfyGrid.Model.Equipment
local Style = ComfyGrid.UI.Style
local SectionRule = ComfyGrid.UI.Chrome.SectionRule
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local StackRenderer = ComfyGrid.UI.StackRenderer
local DragAndDrop = ComfyGrid.Interact.DragAndDrop
local Transfer = ComfyGrid.Interact.Transfer
local Unequip = ComfyGrid.Interact.Unequip

local EquipmentStrip = ISUIElement:derive("ComfyEquipStrip")
ComfyGrid.UI.EquipmentStrip = EquipmentStrip

local MIN_COLS = 2

local ROW_GAP = 4

local ANCHORS = {
    { key = "Face",      col = "l", y = 0.00, dy = -1 },
    { key = "Neck",      col = "l", y = 0.18 },
    { key = "Primary",   col = "l", y = 0.57 },
    { key = "Head",      col = "c", y = 0.00, dy = -1 },
    { key = "Torso",     col = "c", y = 0.21 },
    { key = "Legs",      col = "c", y = 0.50 },
    { key = "Feet",      col = "c", y = 0.80 },
    { key = "Back",      col = "r", y = 0.00, dy = -1 },
    { key = "Hands",     col = "r", y = 0.36 },
    { key = "Secondary", col = "r", y = 0.57 },
}

local POPUP_SIDE = { l = "right", c = "right", r = "left" }

local DRAWER_ROWS = 2

local DEFAULT_BG = { r = 0.09, g = 0.09, b = 0.11, a = 0.85 }
local LABEL = { r = 0.62, g = 0.62, b = 0.68, a = 0.9 }

local ctx = { view = false, stack = false, item = false, slot = 0, x = 0, y = 0, playerNum = 0 }

local labelCache = {}
local function labelFor(key)
    key = tostring(key)
    local label = labelCache[key]
    if label == nil then

        label = Text.tr("IGUI_ComfyGrid_Slot" .. key,
            Equipment.displayNameFor(key) or key)
        label = Text.fit(label, Style.FONT, Style.CELL - 6, 6)
        labelCache[key] = label
    end
    return label
end

local hoverLabelCache = {}
local function hoverLabelFor(key)
    key = tostring(key)
    local info = hoverLabelCache[key]
    if info == nil then
        local label = Text.tr("IGUI_ComfyGrid_Slot" .. key,
            Equipment.displayNameFor(key) or key)
        local width = 0
        local tm = getTextManager and getTextManager() or nil
        if tm ~= nil and Style.FONT ~= nil then
            local ok, w = pcall(tm.MeasureStringX, tm, Style.FONT, label)
            width = ok and w or 0
        end
        info = { label = label, width = width }
        hoverLabelCache[key] = info
    end
    return info
end

Style.onScaleChanged(function()
    for k in pairs(labelCache) do labelCache[k] = nil end
    for k in pairs(hoverLabelCache) do hoverLabelCache[k] = nil end
end)

local GHOST_ITEMS = {
    Primary = "Base.HuntingKnife",
    Secondary = "Base.HandTorch",
    Head = "Base.Hat_BaseballCap",
    Face = "Base.Glasses_Sun",
    Neck = "Base.Scarf_White",
    Torso = "Base.Tshirt_ArmyGreen",
    Hands = "Base.Gloves_LeatherGloves",
    Legs = "Base.Trousers",
    Feet = "Base.Shoes_Black",
    Back = "Base.Bag_Schoolbag",
}
local ghostTexCache = {}
local function ghostTexFor(key)
    local cached = ghostTexCache[key]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local fullType = GHOST_ITEMS[key]
    local tex = nil
    if fullType ~= nil and instanceItem ~= nil then
        local ok, item = pcall(instanceItem, fullType)
        if ok and item ~= nil and item.getTex ~= nil then
            local okT, t = pcall(item.getTex, item)
            if okT then tex = t end
        end
    end
    ghostTexCache[key] = tex or false
    return tex
end

local synths = {}
local function synthFor(key, item, layerCount, slot)
    local synth = synths[key]
    if synth == nil then
        synth = { itemIDs = {}, count = 1, slot = 0, itemType = "?",
            bucket = "", category = nil, _lastId = nil }
        synths[key] = synth
    end
    local id = item:getID()
    if synth._lastId ~= id then
        if synth._lastId ~= nil then synth.itemIDs[synth._lastId] = nil end
        synth.itemIDs[id] = true
        synth._lastId = id
    end
    synth.count = layerCount
    synth.slot = slot
    synth.itemType = item:getFullType()
    synth.category = item:getDisplayCategory() or item:getCategory()
    return synth
end

local lastPrerenderError = nil
local lastRenderError = nil
local lastMouseError = nil
local function reportMouseError(err)
    if err ~= lastMouseError then
        lastMouseError = err
        Log.error("EquipmentStrip mouse handling failed: " .. tostring(err))
    end
end

function EquipmentStrip:new(x, y, playerNum)
    local o = ISUIElement:new(x, y, 1, Style.CELL)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum or 0
    o.entries = {}
    o.entryCount = 0
    o.availWidth = nil
    o.cols = MIN_COLS
    o.rows = 1
    o.layout = "flow"
    o.padRagged = false
    o.groups = {}
    o.groupCount = 0
    o.tilePos = {}
    o.figure = nil
    o.drawerKey = nil
    o.drawerPool = {}
    o.drawerY = 0
    o.drawerCount = 0
    o.hoverIdx = nil
    o.sizeDirty = false
    o.pressedIdx = nil
    o.pressedId = nil
    o.dragDidStart = false
    o.isComfyDragSource = true
    return o
end

function EquipmentStrip:setAvailableWidth(px)
    self.availWidth = px
end

function EquipmentStrip:setLayout(mode)
    self.layout = mode == "anchors" and "anchors" or "flow"

    self.padRagged = self.layout == "anchors"
end

function EquipmentStrip:setFigureBox(x, y, w, h)
    local f = self.figure
    if f == nil then
        f = {}
        self.figure = f
    end
    f.x, f.y, f.w, f.h = x, y, w, h
end

function EquipmentStrip.anchorsTop()
    return Style.CELL_STRIDE
end

function EquipmentStrip.anchorsHeight(figureH, trayRows)
    trayRows = trayRows or 0
    local tray = trayRows * Style.CELL_STRIDE
    if trayRows > 0 then tray = tray + ROW_GAP end
    return EquipmentStrip.anchorsTop() + figureH + ROW_GAP + tray
        + Style.FONT_H + DRAWER_ROWS * Style.CELL_STRIDE + 1
end

local function tileXY(self, idx)
    if self.layout == "anchors" then
        local p = self.tilePos[idx + 1]
        if p == nil then return 0, 0 end
        return p.x, p.y
    end
    return Style.pixelForSlot(idx, self.cols)
end

local function tileAt(self, x, y)
    if self.layout == "anchors" then
        if x < 0 or y < 0 then return nil end
        local stride = Style.CELL_STRIDE
        for i = 1, self.entryCount do
            local pos = self.tilePos[i]
            if pos ~= nil and x >= pos.x and x < pos.x + stride
                    and y >= pos.y and y < pos.y + stride then
                return i - 1
            end
        end
        return nil
    end
    local idx = Style.slotAtPixel(x, y, self.cols, self.rows)
    if idx == nil or idx >= self.entryCount then return nil end
    return idx
end

function EquipmentStrip:tileAnchor(groupKey)
    for i = 1, self.entryCount do
        local e = self.entries[i]
        if e ~= nil and e.key == groupKey then
            local x, y = tileXY(self, i - 1)
            local side = "below"
            if self.layout == "anchors" then
                side = "right"
                for j = 1, #ANCHORS do
                    if ANCHORS[j].key == groupKey then
                        side = POPUP_SIDE[ANCHORS[j].col] or "right"
                        break
                    end
                end
            end
            return self:getAbsoluteX() + x, self:getAbsoluteY() + y,
                Style.CELL, side
        end
    end
    return nil
end

function EquipmentStrip:padTileXY(idx)
    return tileXY(self, idx)
end

local function pointDrawerAt(self, idx)
    if self.layout ~= "anchors" or idx == nil then return end
    local e = self.entries[idx + 1]
    if e ~= nil and e.key ~= nil then self.drawerKey = e.key end
end

local function updateHover(self)
    self.hoverIdx = tileAt(self, self:getMouseX(), self:getMouseY())
    pointDrawerAt(self, self.hoverIdx)
end

function EquipmentStrip:padFocusChanged(idx)
    pointDrawerAt(self, idx)
end

function EquipmentStrip:hoveredItem()
    local idx = self.hoverIdx
    if idx == nil or not self:isMouseOver() then return nil end
    local entry = self.entries[idx + 1]
    if entry == nil or entry.items == nil then return nil end
    return entry.items[1]
end

local function drawerEntry(self, group, slot, item)
    local pool = self.drawerPool
    local e = pool[slot]
    if e == nil then
        e = { items = {} }
        pool[slot] = e
    end
    local items = e.items
    for j = #items, 1, -1 do items[j] = nil end
    items[1] = item
    e.key = group.key
    e.hand = group.hand
    e.dynamic = group.dynamic
    return e
end

local function anchorEntry(self, n, group)
    self.entries[n] = group
    return group
end

local function groupFor(self, key)
    for i = 1, self.groupCount do
        local g = self.groups[i]
        if g.key == key then return g end
    end
    return nil
end

local function placeTile(self, n, x, y)
    local pos = self.tilePos[n]
    if pos == nil then
        pos = {}
        self.tilePos[n] = pos
    end
    pos.x, pos.y = x, y
end

local function layoutAnchors(self, playerObj)
    self.groupCount = Equipment.collect(playerObj, self.groups)
    local stride = Style.CELL_STRIDE
    local cell = Style.CELL
    local f = self.figure
    local w = self.availWidth or self.width
    if f == nil then

        f = { x = 0, y = 0, w = 0, h = math.max(cell, self.height) }
    end

    local colL = 0
    local colR = w - cell
    local colC = math.floor((w - cell) / 2)

    if colR < colL then colR = colL end
    if colC < colL then colC = colL end
    if colC > colR then colC = colR end

    local n = 0
    for i = 1, #ANCHORS do
        local a = ANCHORS[i]
        local g = groupFor(self, a.key)

        if g ~= nil then
            n = n + 1
            anchorEntry(self, n, g)
            local x = colC
            if a.col == "l" then x = colL elseif a.col == "r" then x = colR end
            local dy = (a.dy or 0) * stride
            placeTile(self, n, x, f.y + math.floor(f.h * a.y + 0.5) + dy)
        end
    end
    self.anchorCount = n

    local trayY = f.y + f.h + ROW_GAP
    local trayCols = math.max(1, math.floor((w - 1) / stride))
    local tray = 0
    for i = 1, self.groupCount do
        local g = self.groups[i]
        if g.dynamic then
            n = n + 1
            anchorEntry(self, n, g)
            placeTile(self, n, (tray % trayCols) * stride,
                trayY + math.floor(tray / trayCols) * stride)
            tray = tray + 1
        end
    end
    local trayRows = tray > 0 and math.ceil(tray / trayCols) or 0

    self.trayRows = trayRows
    self.drawerY = trayY + trayRows * stride + (tray > 0 and ROW_GAP or 0)

    local shown = self.drawerKey ~= nil and groupFor(self, self.drawerKey)
        or nil
    if shown == nil then

        local best, bestN = nil, 1
        for i = 1, self.groupCount do
            local g = self.groups[i]
            if #g.items > bestN then best, bestN = g, #g.items end
        end
        shown = best
        self.drawerKey = best ~= nil and best.key or nil
    end
    self.drawerCount = 0
    if shown ~= nil then
        local cols = math.max(1, math.floor((w - 1) / stride))
        local top = self.drawerY + Style.FONT_H
        local max = cols * DRAWER_ROWS
        for j = 1, #shown.items do
            if j > max then break end
            n = n + 1
            self.entries[n] = drawerEntry(self, shown, j, shown.items[j])
            placeTile(self, n, ((j - 1) % cols) * stride,
                top + math.floor((j - 1) / cols) * stride)
            self.drawerCount = self.drawerCount + 1
        end
    end

    self.entryCount = n
    self.cols = math.max(1, math.floor((w - 1) / stride))
    self.rows = 1
    local h = self.drawerY + Style.FONT_H + DRAWER_ROWS * stride + 1

    if self.width ~= w or self.height ~= h then
        self:setWidth(w)
        self:setHeight(h)
        self.sizeDirty = true
        updateHover(self)
    end
end

local function prerenderImpl(self)
    local playerObj = getSpecificPlayer(self.playerNum)
    if self.layout == "anchors" then
        layoutAnchors(self, playerObj)
        return
    end
    self.entryCount = Equipment.collect(playerObj, self.entries)

    local avail = self.availWidth
    local cols
    if avail == nil then
        cols = self.entryCount > 0 and self.entryCount or MIN_COLS
    else
        cols = math.floor((avail - 1) / Style.CELL_STRIDE)
        if cols < MIN_COLS then cols = MIN_COLS end
    end
    if self.entryCount > 0 and cols > self.entryCount then
        cols = self.entryCount
    end
    self.cols = cols
    self.rows = math.max(1, math.ceil(self.entryCount / cols))
    local w, h = Style.gridPixelSize(self.cols, self.rows)
    if w ~= self.width or h ~= self.height then
        self:setWidth(w)
        self:setHeight(h)
        self.sizeDirty = true
        updateHover(self)
    end
end

function EquipmentStrip:prerender()
    local ok, err = pcall(prerenderImpl, self)
    if not ok and err ~= lastPrerenderError then
        lastPrerenderError = err
        Log.error("EquipmentStrip prerender failed: " .. tostring(err))
    end
end

local function drawDrawerRule(self)
    if self.drawerKey == nil then return end
    local band = Style.FONT_H
    local g = nil
    for i = 1, self.groupCount do
        if self.groups[i].key == self.drawerKey then g = self.groups[i] break end
    end
    local count = g ~= nil and #g.items or 0
    local rightPad = 0
    if count > 1 then

        local text = tostring(count)
        local tm = getTextManager and getTextManager() or nil
        local tw = 0
        if tm ~= nil then
            local ok, m = pcall(tm.MeasureStringX, tm, Style.FONT, text)
            tw = ok and m or 0
        end
        local c = SectionRule.TEXT
        self:drawText(text, self.width - SectionRule.PAD - tw,
            self.drawerY + 1, c.r, c.g, c.b, c.a, Style.FONT)
        rightPad = tw + 6
    end
    SectionRule.draw(self, hoverLabelFor(self.drawerKey), self.drawerY,
        band, rightPad)
end

local function renderImpl(self)
    local anchors = self.layout == "anchors"
    local cols = self.cols
    local rows = self.rows
    local w, h
    if anchors then
        w, h = self.width, self.height
    else
        w, h = Style.gridPixelSize(cols, rows)
    end
    local colors = Style.COLORS
    local bg = colors and colors.BOARD_BG or DEFAULT_BG

    if not anchors then
        self:drawRect(0, 0, w, h, bg.a or 1, bg.r or 0, bg.g or 0, bg.b or 0)
    else
        drawDrawerRule(self)
    end

    local entries = self.entries
    local font = Style.FONT
    local cell = Style.CELL

    local currentAction = StackRenderer.currentActionOf(self.playerNum)

    local ItemApply = ComfyGrid.Interact.ItemApply
    local applySrc = ItemApply ~= nil and ItemApply.dragSource() or nil
    local applyPlayer = nil
    local applyPulse = 1
    if applySrc ~= nil then
        applyPlayer = getSpecificPlayer(self.playerNum)
        if applyPlayer == nil then applySrc = nil end
        applyPulse = SlotRenderer.applyPulse()
    end
    ctx.view = self
    ctx.playerNum = self.playerNum
    for i = 1, self.entryCount do
        local entry = entries[i]
        local items = entry.items
        local top = items[1]
        local tx, ty = tileXY(self, i - 1)
        if top ~= nil then

            for j = 1, #items do
                StackRenderer.updateItem(items[j])
            end
            ctx.stack = synthFor(entry.key, top, #items, i - 1)
            ctx.item = top
            ctx.slot = i - 1
            ctx.x = tx
            ctx.y = ty
            StackRenderer.draw(ctx)
            if applySrc ~= nil
                    and ItemApply.hintFor(applySrc, top, applyPlayer) then
                SlotRenderer.drawApplyHint(ctx, applyPulse)
            end

            local jd = StackRenderer.jobDeltaOf(top, currentAction)
            if jd ~= nil then
                StackRenderer.drawJobOverlay(self, tx, ty, jd)
            end
        else

            ctx.stack = nil
            ctx.item = nil
            ctx.slot = i - 1
            ctx.x = tx
            ctx.y = ty
            SlotRenderer.drawSocket(ctx)
            local tex = ghostTexFor(entry.key)
            if tex ~= nil then
                SlotRenderer.drawGhost(self, tex, tx, ty)
            elseif font ~= nil then
                self:drawTextCentre(labelFor(entry.key), tx + cell / 2,
                    ty + math.floor(cell / 2) - 7, LABEL.r, LABEL.g, LABEL.b,
                    LABEL.a, font)
            end
        end
    end

    local hover = self.hoverIdx
    if hover ~= nil and hover < self.entryCount and self:isMouseOver() then
        local hx, hy = tileXY(self, hover)
        ctx.stack = nil
        ctx.item = nil
        ctx.slot = hover
        ctx.x = hx
        ctx.y = hy
        SlotRenderer.drawHover(ctx)

        local entry = entries[hover + 1]
        if entry ~= nil and entry.items[1] == nil then
            SlotRenderer.drawNameChip(self, hoverLabelFor(entry.key), hx, hy, font)
        end
    end

    local Pad = ComfyGrid.Interact and ComfyGrid.Interact.PadFocus
    local padIdx = Pad ~= nil and Pad.cursorFor ~= nil and Pad.cursorFor(self)
        or nil
    if padIdx ~= nil and padIdx < self.entryCount then
        local px, py = tileXY(self, padIdx)
        SlotRenderer.drawSelection(self, px, py)
        ctx.stack = nil
        ctx.item = nil
        ctx.slot = padIdx
        ctx.x = px
        ctx.y = py
        SlotRenderer.drawHover(ctx)
        local entry = entries[padIdx + 1]
        if entry ~= nil and entry.items[1] == nil then
            SlotRenderer.drawNameChip(self, hoverLabelFor(entry.key), px, py,
                font)
        end
        local Carry = ComfyGrid.Interact.PadCarry
        if Carry ~= nil and Carry.renderAt ~= nil then
            Carry.renderAt(self, px, py)
        end
    end
end

function EquipmentStrip:render()
    local ok, err = pcall(renderImpl, self)
    if not ok and err ~= lastRenderError then
        lastRenderError = err
        Log.error("EquipmentStrip render failed: " .. tostring(err))
    end
end

local function sourceGridSlotOf(entry, playerNum)
    local tag = entry.comfyStacks or entry.comfyStack
    if type(tag) == "table" and tag.itemIDs == nil then tag = tag[1] end
    if type(tag) ~= "table" or tag.itemIDs == nil
            or type(tag.slot) ~= "number" then
        return nil, nil
    end
    local CM = ComfyGrid.Model and ComfyGrid.Model.ContainerModel
    local model = CM ~= nil and CM.getPlayerMain ~= nil
        and CM.getPlayerMain(playerNum) or nil
    local grid = model ~= nil and model.grid or nil
    if grid == nil or grid.claimSlotForItem == nil then return nil, nil end
    local stacks = grid.data.stacks
    for i = 1, #stacks do
        if stacks[i] == tag then return tag.slot, grid end
    end
    return nil, nil
end

local function resolveEquipDrop(self, idx, fromIdx)
    local entry = self.entries[idx + 1]
    if entry == nil then return end
    local dragged = DragAndDrop.getDraggedStacks()
    if dragged == nil then return end
    local playerObj = getSpecificPlayer(self.playerNum)
    if playerObj == nil then return end

    local ItemApply = ComfyGrid.Interact.ItemApply
    local top = entry.items[1]
    if ItemApply ~= nil and top ~= nil then
        local srcItems = ItemApply.liveItemsOf(dragged)
        if srcItems ~= nil and ItemApply.tryApply(srcItems, top, playerObj) then
            return
        end
    end
    for i = 1, #dragged do
        local items = dragged[i].items
        if type(items) == "table" then
            local first = (#items >= 2) and 2 or 1
            for j = first, #items do
                local item = items[j]
                if item ~= nil and item:getContainer() ~= nil
                        and Equipment.itemMatchesGroup(item, entry.key) then
                    local displaced
                    if entry.hand ~= nil then

                        if isForceDropHeavyItem(item) then
                            ISInventoryPaneContextMenu.equipHeavyItem(
                                playerObj, item)
                            return
                        end
                        local getter = entry.hand == "primary"
                            and playerObj.getPrimaryHandItem
                            or playerObj.getSecondaryHandItem
                        local okH, held = pcall(getter, playerObj)
                        displaced = okH and held or nil

                        local twoHands = item.isTwoHandWeapon ~= nil
                            and item:isTwoHandWeapon() or false
                        ISInventoryPaneContextMenu.equipWeapon(item,
                            entry.hand == "primary", twoHands, self.playerNum)
                    else
                        displaced = Equipment.findDisplacedWorn(playerObj, item)
                        ISInventoryPaneContextMenu.onWearItems({ item },
                            self.playerNum)
                    end
                    if displaced ~= nil and displaced ~= item then
                        local fromEntry = fromIdx ~= nil
                            and self.entries[fromIdx + 1] or nil
                        if fromEntry ~= nil and fromEntry.hand ~= nil
                                and entry.hand ~= nil then

                            local dTwo = displaced.isTwoHandWeapon ~= nil
                                and displaced:isTwoHandWeapon() or false
                            ISInventoryPaneContextMenu.equipWeapon(displaced,
                                fromEntry.hand == "primary", dTwo, self.playerNum)
                        else
                            local srcSlot, mainGrid =
                                sourceGridSlotOf(dragged[i], self.playerNum)
                            if srcSlot ~= nil then
                                mainGrid:claimSlotForItem(displaced:getID(), srcSlot)
                            end
                        end
                    end
                    return
                end
            end
        end
    end
end

function EquipmentStrip:resolvePadDrop(idx)
    resolveEquipDrop(self, idx)
end

local function mouseDownImpl(self, x, y)
    if DragAndDrop.isDragOwner(self) and not DragAndDrop.isDragging() then
        DragAndDrop.endDrag()
    end
    self.pressedIdx = nil
    self.pressedId = nil
    self.dragDidStart = false
    local idx = tileAt(self, x, y)
    if idx == nil then return end
    local entry = self.entries[idx + 1]
    local top = entry ~= nil and entry.items[1] or nil
    if top == nil then return end

    if Unequip.pressClaims(top, self.playerNum, "unequip") then return end

    local payload = { VanillaStacks.fromItems({ top }) }
    if payload[1] == nil then return end
    DragAndDrop.prepareDrag(self, payload, x, y)
    self.pressedIdx = idx
    self.pressedId = top:getID()
end

local function mouseUpImpl(self, x, y)

    if not DragAndDrop.isDragging() then
        local upIdx = tileAt(self, x, y)
        local upEntry = upIdx ~= nil and self.entries[upIdx + 1] or nil
        local upTop = upEntry ~= nil and upEntry.items[1] or nil
        if upTop ~= nil
                and Unequip.releaseClaims(self, upTop, self.playerNum, "unequip") then
            if DragAndDrop.isDragOwner(self) then DragAndDrop.endDrag() end
            self.pressedIdx = nil
            self.pressedId = nil
            return
        end
    end
    if DragAndDrop.isDragging() then
        local poked = x == 0 and y == 0 and DragAndDrop.isDragOwner(self)
            and (self:getMouseX() ~= 0 or self:getMouseY() ~= 0)
        if not poked and self:isMouseOver() then
            local idx = tileAt(self, x, y)
            if not DragAndDrop.isDragOwner(self) then

                if idx ~= nil then
                    resolveEquipDrop(self, idx)
                end
            elseif idx ~= nil and idx ~= self.pressedIdx then

                resolveEquipDrop(self, idx, self.pressedIdx)
            end
            DragAndDrop.endDrag()
        elseif DragAndDrop.isDragOwner(self) then
            DragAndDrop.endDrag()
        end
    elseif DragAndDrop.isDragOwner(self) then
        local idx = self.pressedIdx
        DragAndDrop.endDrag()
        if idx ~= nil and not self.dragDidStart then

            local entry = self.entries[idx + 1]
            if entry ~= nil and #entry.items > 1 then
                local LayersPopup = ComfyGrid.UI.LayersPopup
                if LayersPopup ~= nil and LayersPopup.openFor ~= nil then
                    local ok, err = pcall(LayersPopup.openFor, self, entry.key)
                    if not ok then reportMouseError(err) end
                end
            end
        end
    end
    self.pressedIdx = nil
    self.pressedId = nil
end

local function dragCancelImpl(self)
    local id = self.pressedId
    self.pressedIdx = nil
    self.pressedId = nil
    if id == nil then return end

    if not DragAndDrop.releaseDropsToFloor(self.playerNum) then return end
    local playerObj = getSpecificPlayer(self.playerNum)
    if playerObj == nil then return end
    local item = playerObj:getInventory():getItemWithID(id)
    if item ~= nil then
        Transfer.dropToFloor({ item }, playerObj)
    end
end

function EquipmentStrip:onComfyDragCancelled()
    local ok, err = pcall(dragCancelImpl, self)
    if not ok then reportMouseError(err) end
end

local function mouseUpOutsideImpl(self, _x, _y)
    if not DragAndDrop.isDragOwner(self) then return end
    if DragAndDrop.isDragging() then
        DragAndDrop.cancelDrag(self, self.onComfyDragCancelled)
    else
        DragAndDrop.endDrag()
        self.pressedIdx = nil
        self.pressedId = nil
    end
end

local function rightMouseUpImpl(self, x, y)
    if DragAndDrop.isDragging() then return end
    if DragAndDrop.isDragOwner(self) then
        DragAndDrop.endDrag()
        self.pressedIdx = nil
        self.pressedId = nil
    end
    local idx = tileAt(self, x, y)
    local entry = idx ~= nil and self.entries[idx + 1] or nil
    local top = entry ~= nil and entry.items[1] or nil
    if top == nil then return end

    ISInventoryPaneContextMenu.createMenu(self.playerNum, true, { top },
        getMouseX(), getMouseY())
end

function EquipmentStrip:onMouseDown(x, y)
    local ok, err = pcall(mouseDownImpl, self, x, y)
    if not ok then reportMouseError(err) end

    if self.layout == "anchors" then
        return tileAt(self, x, y) ~= nil
    end
    return true
end

function EquipmentStrip:onMouseUp(x, y)
    local ok, err = pcall(mouseUpImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end

function EquipmentStrip:onMouseUpOutside(x, y)
    local ok, err = pcall(mouseUpOutsideImpl, self, x, y)
    if not ok then reportMouseError(err) end
end

function EquipmentStrip:onMouseMove(_dx, _dy)
    updateHover(self)
    if DragAndDrop == nil then return end
    DragAndDrop.startDrag(self)
    if not self.dragDidStart and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(self) then
        self.dragDidStart = true
    end
end

function EquipmentStrip:onMouseMoveOutside(_dx, _dy)
    self.hoverIdx = nil
    if DragAndDrop == nil then return end
    DragAndDrop.startDrag(self)
    if not self.dragDidStart and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(self) then
        self.dragDidStart = true
    end
end

function EquipmentStrip.onRightMouseDown(_self, _x, _y)
    return true
end

function EquipmentStrip:onRightMouseUp(x, y)
    local ok, err = pcall(rightMouseUpImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end
