--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Model/Equipment"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Chrome/SectionRule"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/Model/ItemSearch"
require "ComfyGrid/UI/StackRenderer"
require "ComfyGrid/UI/StripGestures"
require "ComfyGrid/Interact/DragAndDrop"
require "ComfyGrid/Interact/Unequip"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local Equipment = ComfyGrid.Model.Equipment
local Style = ComfyGrid.UI.Style
local SectionRule = ComfyGrid.UI.Chrome.SectionRule
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local ItemSearch = ComfyGrid.Model.ItemSearch
local StackRenderer = ComfyGrid.UI.StackRenderer
local StripGestures = ComfyGrid.UI.StripGestures
local DragAndDrop = ComfyGrid.Interact.DragAndDrop
local Unequip = ComfyGrid.Interact.Unequip

local EquipmentStrip = ISUIElement:derive("ComfyEquipStrip")
ComfyGrid.UI.EquipmentStrip = EquipmentStrip

local MIN_COLS = 2

local ROW_GAP = 4
EquipmentStrip.ROW_GAP = ROW_GAP

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
local DRAWER_SLOTS = 10

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
        local textManager = getTextManager and getTextManager() or nil
        if textManager ~= nil and Style.FONT ~= nil then
            local ok, measured = pcall(textManager.MeasureStringX, textManager,
                Style.FONT, label)
            width = ok and measured or 0
        end
        info = { label = label, width = width }
        hoverLabelCache[key] = info
    end
    return info
end

local countTextCache = {}
local countWidthCache = {}
local function countLabelFor(count)
    local text = countTextCache[count]
    if text ~= nil then return text, countWidthCache[count] end
    text = tostring(count)
    local countWidth = 0
    local textManager = getTextManager and getTextManager() or nil
    if textManager ~= nil then
        local ok, measured = pcall(textManager.MeasureStringX, textManager,
            Style.FONT, text)
        countWidth = ok and measured or 0
        countTextCache[count] = text
        countWidthCache[count] = countWidth
    end
    return text, countWidth
end

Style.onScaleChanged(function()
    for key in pairs(labelCache) do labelCache[key] = nil end
    for key in pairs(hoverLabelCache) do hoverLabelCache[key] = nil end
    for count in pairs(countTextCache) do countTextCache[count] = nil end
    for count in pairs(countWidthCache) do countWidthCache[count] = nil end
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
            local textureRead, texture = pcall(item.getTex, item)
            if textureRead then tex = texture end
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
    o.hoverIdx = nil
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
    local figureBox = self.figure
    if figureBox == nil then
        figureBox = {}
        self.figure = figureBox
    end
    figureBox.x, figureBox.y, figureBox.w, figureBox.h = x, y, w, h
end

function EquipmentStrip.anchorsTop()
    return Style.CELL_STRIDE
end

local function columnsFor(width)
    return math.max(1, math.floor((width - 1) / Style.CELL_STRIDE))
end

function EquipmentStrip.drawerRows(width)
    if width == nil then return DRAWER_ROWS end
    return math.max(DRAWER_ROWS, math.ceil(DRAWER_SLOTS / columnsFor(width)))
end

function EquipmentStrip.anchorsHeight(figureH, trayRows, width)
    trayRows = trayRows or 0
    local tray = trayRows * Style.CELL_STRIDE
    if trayRows > 0 then tray = tray + ROW_GAP end
    return EquipmentStrip.anchorsTop() + figureH + ROW_GAP + tray
        + Style.FONT_H + EquipmentStrip.drawerRows(width) * Style.CELL_STRIDE + 1
end

local minFigureHeightStride = false
local minFigureHeightAnswer = nil
function EquipmentStrip.minFigureHeight()
    local stride = Style.CELL_STRIDE
    if stride == minFigureHeightStride then return minFigureHeightAnswer end
    local requiredHeight = 0
    for i = 1, #ANCHORS do
        for j = 1, #ANCHORS do
            local upper, lower = ANCHORS[i], ANCHORS[j]
            if upper.col == lower.col and lower.y > upper.y then
                local tiles = (lower.dy or 0) - (upper.dy or 0)
                if tiles < 1 then
                    local height = stride * (1 - tiles) / (lower.y - upper.y)
                    if height > requiredHeight then requiredHeight = height end
                end
            end
        end
    end

    minFigureHeightStride = stride
    minFigureHeightAnswer = math.ceil(requiredHeight) + 1
    return minFigureHeightAnswer
end

local function tileXY(self, idx)
    if self.layout == "anchors" then
        local pos = self.tilePos[idx + 1]
        if pos == nil then return 0, 0 end
        return pos.x, pos.y
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
        local entry = self.entries[i]
        if entry ~= nil and entry.key == groupKey then
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
    local entry = self.entries[idx + 1]
    if entry ~= nil and entry.key ~= nil then self.drawerKey = entry.key end
end

local function updateHover(self)
    self.hoverIdx = tileAt(self, self:getMouseX(), self:getMouseY())
    pointDrawerAt(self, self.hoverIdx)
end

local function itemAt(self, x, y)
    local idx = tileAt(self, x, y)
    if idx == nil then return nil end
    local entry = self.entries[idx + 1]
    local top = entry ~= nil and entry.items[1] or nil
    return top, idx
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
    local drawerSlotEntry = pool[slot]
    if drawerSlotEntry == nil then
        drawerSlotEntry = { items = {} }
        pool[slot] = drawerSlotEntry
    end
    local items = drawerSlotEntry.items
    for j = #items, 1, -1 do items[j] = nil end
    items[1] = item
    drawerSlotEntry.key = group.key
    drawerSlotEntry.hand = group.hand
    drawerSlotEntry.dynamic = group.dynamic
    return drawerSlotEntry
end

local function anchorEntry(self, tileCount, group)
    self.entries[tileCount] = group
    return group
end

local function groupFor(self, key)
    for i = 1, self.groupCount do
        local group = self.groups[i]
        if group.key == key then return group end
    end
    return nil
end

local function placeTile(self, tileCount, x, y)
    local pos = self.tilePos[tileCount]
    if pos == nil then
        pos = {}
        self.tilePos[tileCount] = pos
    end
    pos.x, pos.y = x, y
end

local FALLBACK_FIGURE = { x = 0, y = 0, w = 0, h = 0 }

local function anchorColumns(stripWidth, cell)
    local leftColumnX = 0
    local rightColumnX = stripWidth - cell
    local centreColumnX = math.floor((stripWidth - cell) / 2)

    if rightColumnX < leftColumnX then rightColumnX = leftColumnX end
    if centreColumnX < leftColumnX then centreColumnX = leftColumnX end
    if centreColumnX > rightColumnX then centreColumnX = rightColumnX end
    return leftColumnX, centreColumnX, rightColumnX
end

local function placeAnchorTiles(self, figureBox, stripWidth, stride, cell)
    local leftColumnX, centreColumnX, rightColumnX =
        anchorColumns(stripWidth, cell)
    local tileCount = 0
    for i = 1, #ANCHORS do
        local anchor = ANCHORS[i]
        local group = groupFor(self, anchor.key)

        if group ~= nil then
            tileCount = tileCount + 1
            anchorEntry(self, tileCount, group)
            local x = centreColumnX
            if anchor.col == "l" then
                x = leftColumnX
            elseif anchor.col == "r" then
                x = rightColumnX
            end
            local dy = (anchor.dy or 0) * stride
            placeTile(self, tileCount, x,
                figureBox.y + math.floor(figureBox.h * anchor.y + 0.5) + dy)
        end
    end
    self.anchorCount = tileCount
    return tileCount
end

local function placeTrayTiles(self, tileCount, figureBox, stripWidth, stride)
    local trayY = figureBox.y + figureBox.h + ROW_GAP
    local trayCols = columnsFor(stripWidth)
    local tray = 0
    for i = 1, self.groupCount do
        local group = self.groups[i]
        if group.dynamic then
            tileCount = tileCount + 1
            anchorEntry(self, tileCount, group)
            placeTile(self, tileCount, (tray % trayCols) * stride,
                trayY + math.floor(tray / trayCols) * stride)
            tray = tray + 1
        end
    end
    local trayRows = tray > 0 and math.ceil(tray / trayCols) or 0

    self.trayRows = trayRows
    self.drawerY = trayY + trayRows * stride + (tray > 0 and ROW_GAP or 0)
    return tileCount
end

local function drawerGroupOf(self)
    local drawerGroup = self.drawerKey ~= nil and groupFor(self, self.drawerKey)
        or nil
    if drawerGroup == nil then

        local deepestGroup, deepestLayerCount = nil, 1
        for i = 1, self.groupCount do
            local group = self.groups[i]
            if #group.items > deepestLayerCount then
                deepestGroup, deepestLayerCount = group, #group.items
            end
        end
        drawerGroup = deepestGroup
        self.drawerKey = deepestGroup ~= nil and deepestGroup.key or nil
    end
    return drawerGroup
end

local function placeDrawerTiles(self, tileCount, drawerGroup, stripWidth,
        stride)
    if drawerGroup == nil then return tileCount end
    local cols = columnsFor(stripWidth)
    local top = self.drawerY + Style.FONT_H
    local drawerCapacity = cols * EquipmentStrip.drawerRows(stripWidth)
    for j = 1, #drawerGroup.items do
        if j > drawerCapacity then break end
        tileCount = tileCount + 1
        self.entries[tileCount] = drawerEntry(self, drawerGroup, j,
            drawerGroup.items[j])
        placeTile(self, tileCount, ((j - 1) % cols) * stride,
            top + math.floor((j - 1) / cols) * stride)
    end
    return tileCount
end

local function layoutAnchors(self, playerObj)
    self.groupCount = Equipment.collect(playerObj, self.groups)
    local stride = Style.CELL_STRIDE
    local cell = Style.CELL
    local figureBox = self.figure
    local stripWidth = self.availWidth or self.width
    if figureBox == nil then

        figureBox = FALLBACK_FIGURE
        figureBox.h = math.max(cell, self.height)
    end

    local tileCount = placeAnchorTiles(self, figureBox, stripWidth, stride,
        cell)
    tileCount = placeTrayTiles(self, tileCount, figureBox, stripWidth, stride)
    tileCount = placeDrawerTiles(self, tileCount, drawerGroupOf(self),
        stripWidth, stride)

    self.entryCount = tileCount
    self.cols = columnsFor(stripWidth)
    self.rows = 1
    local stripHeight = self.drawerY + Style.FONT_H
        + EquipmentStrip.drawerRows(stripWidth) * stride + 1

    if self.width ~= stripWidth or self.height ~= stripHeight then
        self:setWidth(stripWidth)
        self:setHeight(stripHeight)
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
    local stripWidth, stripHeight = Style.gridPixelSize(self.cols, self.rows)
    if stripWidth ~= self.width or stripHeight ~= self.height then
        self:setWidth(stripWidth)
        self:setHeight(stripHeight)
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
    local group = groupFor(self, self.drawerKey)
    local count = group ~= nil and #group.items or 0
    local rightPad = 0
    if count > 1 then

        local text, countWidth = countLabelFor(count)
        local textColor = SectionRule.TEXT
        self:drawText(text, self.width - SectionRule.PAD - countWidth,
            self.drawerY + 1, textColor.r, textColor.g, textColor.b,
            textColor.a, Style.FONT)
        rightPad = countWidth + 6
    end
    SectionRule.draw(self, hoverLabelFor(self.drawerKey), self.drawerY,
        band, rightPad)
end

local function paintBackdrop(self, anchors)
    if anchors then
        drawDrawerRule(self)
        return
    end
    local stripWidth, stripHeight = Style.gridPixelSize(self.cols, self.rows)
    local colors = Style.COLORS
    local bg = colors.BOARD_BG
    self:drawRect(0, 0, stripWidth, stripHeight, bg.a or 1, bg.r or 0,
        bg.g or 0, bg.b or 0)
end

local function emptyChipAt(self, idx)
    local entry = self.entries[idx + 1]
    if entry ~= nil and entry.items[1] == nil then
        return hoverLabelFor(entry.key)
    end
    return nil
end

local function renderImpl(self)
    paintBackdrop(self, self.layout == "anchors")

    local entries = self.entries
    local font = Style.FONT
    local cell = Style.CELL

    local currentAction = StackRenderer.currentActionOf(self.playerNum)

    local ItemApply, applySrc, applyPlayer, applyPulse, searchMarks,
        searchPulse = StripGestures.tileHints(self.playerNum)
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

            if searchMarks ~= nil then
                for layerIndex = 1, #items do
                    if ItemSearch.marksItem(searchMarks, items[layerIndex]) then
                        SlotRenderer.drawSearchHint(ctx, searchPulse)
                        break
                    end
                end
            end
            if applySrc ~= nil
                    and ItemApply.hintFor(applySrc, top, applyPlayer) then
                SlotRenderer.drawApplyHint(ctx, applyPulse)
            end

            local jobDelta = StackRenderer.jobDeltaOf(top, currentAction)
            if jobDelta ~= nil then
                StackRenderer.drawJobOverlay(self, tx, ty, jobDelta)
            end
        else

            StripGestures.drawEmptySocket(self, ctx, i - 1, tx, ty, entry.key,
                ghostTexFor, labelFor, font, cell)
        end
    end

    StripGestures.drawCursors(self, ctx, font, tileXY, emptyChipAt)
end

function EquipmentStrip:render()
    local ok, err = pcall(renderImpl, self)
    if not ok and err ~= lastRenderError then
        lastRenderError = err
        Log.error("EquipmentStrip render failed: " .. tostring(err))
    end
end

local function isTwoHanded(item)
    return item.isTwoHandWeapon ~= nil and item:isTwoHandWeapon() or false
end

local function applyOntoTile(entry, dragged, playerObj)
    local ItemApply = ComfyGrid.Interact.ItemApply
    local top = entry.items[1]
    if ItemApply == nil or top == nil then return false end
    local srcItems = ItemApply.liveItemsOf(dragged)
    if srcItems ~= nil and ItemApply.tryApply(srcItems, top, playerObj) then
        return true
    end
    return false
end

local function firstEquippable(dragged, groupKey)
    for i = 1, #dragged do
        local items = dragged[i].items
        if type(items) == "table" then
            local first = ComfyGrid.Core.VanillaStacks.firstRealIndex(items)
            for j = first, #items do
                local item = items[j]
                if item ~= nil and item:getContainer() ~= nil
                        and Equipment.itemMatchesGroup(item, groupKey) then
                    return item, dragged[i]
                end
            end
        end
    end
    return nil, nil
end

local function equipIntoHand(self, entry, item, playerObj)

    if isForceDropHeavyItem(item) then
        ISInventoryPaneContextMenu.equipHeavyItem(playerObj, item)
        return nil
    end
    local getter = entry.hand == "primary"
        and playerObj.getPrimaryHandItem
        or playerObj.getSecondaryHandItem
    local heldRead, heldItem = pcall(getter, playerObj)
    local displaced = heldRead and heldItem or nil
    ISInventoryPaneContextMenu.equipWeapon(item, entry.hand == "primary",
        isTwoHanded(item), self.playerNum)
    return displaced
end

local function seatDisplaced(self, entry, fromIdx, displaced, draggedEntry)
    local fromEntry = fromIdx ~= nil and self.entries[fromIdx + 1] or nil
    if fromEntry ~= nil and fromEntry.hand ~= nil and entry.hand ~= nil then

        ISInventoryPaneContextMenu.equipWeapon(displaced,
            fromEntry.hand == "primary", isTwoHanded(displaced),
            self.playerNum)
        return
    end
    local srcSlot, mainGrid =
        StripGestures.sourceGridSlotOf(draggedEntry, self.playerNum)
    if srcSlot ~= nil then
        mainGrid:claimSlotForItem(displaced:getID(), srcSlot)
    end
end

local function resolveEquipDrop(self, idx, fromIdx)
    local entry = self.entries[idx + 1]
    if entry == nil then return end
    local dragged = DragAndDrop.getDraggedStacks()
    if dragged == nil then return end
    local playerObj = getSpecificPlayer(self.playerNum)
    if playerObj == nil then return end
    if applyOntoTile(entry, dragged, playerObj) then return end
    local item, draggedEntry = firstEquippable(dragged, entry.key)
    if item == nil then return end
    local displaced
    if entry.hand ~= nil then
        displaced = equipIntoHand(self, entry, item, playerObj)
    else
        displaced = Equipment.findDisplacedWorn(playerObj, item)
        ISInventoryPaneContextMenu.onWearItems({ item }, self.playerNum)
    end
    if displaced ~= nil and displaced ~= item then
        seatDisplaced(self, entry, fromIdx, displaced, draggedEntry)
    end
end

function EquipmentStrip:resolvePadDrop(idx)
    resolveEquipDrop(self, idx)
end

local function mouseDownImpl(self, x, y)
    StripGestures.beginPress(self)
    local top, idx = itemAt(self, x, y)
    if top == nil then return end

    if Unequip.pressClaims(top, self.playerNum, "unequip") then return end

    StripGestures.armItemDrag(self, idx, top, x, y)
end

local function mouseUpImpl(self, x, y)

    if not DragAndDrop.isDragging() then
        local upTop = itemAt(self, x, y)
        if StripGestures.releaseClaimed(self, upTop, "unequip") then return end
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

function EquipmentStrip:onComfyDragCancelled()
    local ok, err = pcall(StripGestures.dropPressedToFloor, self)
    if not ok then reportMouseError(err) end
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

function EquipmentStrip:onMouseUpOutside(_x, _y)
    local ok, err = pcall(StripGestures.releaseOutside, self)
    if not ok then reportMouseError(err) end
end

function EquipmentStrip:onMouseMove(_dx, _dy)
    updateHover(self)
    StripGestures.promoteDrag(self)
end

function EquipmentStrip:onMouseMoveOutside(_dx, _dy)
    self.hoverIdx = nil
    StripGestures.promoteDrag(self)
end

function EquipmentStrip.onRightMouseDown(_self, _x, _y)
    return true
end

function EquipmentStrip:onRightMouseUp(x, y)
    local ok, err = pcall(StripGestures.openMenuAt, self, x, y, itemAt)
    if not ok then reportMouseError(err) end
    return true
end
