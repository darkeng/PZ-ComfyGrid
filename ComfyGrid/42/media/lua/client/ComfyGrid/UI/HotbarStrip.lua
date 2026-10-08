--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Core/Input"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/UI/HotbarGhosts"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/Model/ItemSearch"
require "ComfyGrid/UI/StackRenderer"
require "ComfyGrid/UI/StripGestures"
require "ComfyGrid/Interact/DragAndDrop"
require "ComfyGrid/Interact/Unequip"
require "ComfyGrid/Interact/HotbarAttach"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local Style = ComfyGrid.UI.Style
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local ItemSearch = ComfyGrid.Model.ItemSearch
local StackRenderer = ComfyGrid.UI.StackRenderer
local StripGestures = ComfyGrid.UI.StripGestures
local DragAndDrop = ComfyGrid.Interact.DragAndDrop
local Unequip = ComfyGrid.Interact.Unequip
local HotbarAttach = ComfyGrid.Interact.HotbarAttach

local HotbarStrip = ISUIElement:derive("ComfyHotbarStrip")
ComfyGrid.UI.HotbarStrip = HotbarStrip

local MIN_COLS = 2

local ctx = { view = false, stack = false, item = false, slot = 0, x = 0, y = 0, playerNum = 0 }

local NO_ATTACHED = {}

local labelCache = {}
local function labelFor(slot)
    if slot == nil then return "?" end
    local key = tostring(slot.slotType or slot.name or "?")
    local label = labelCache[key]
    if label == nil then
        if slot.slotType ~= nil then
            label = getTextOrNull("IGUI_HotbarAttachment_"
                .. tostring(slot.slotType))
        end
        if label == nil then label = tostring(slot.name or "?") end
        label = Text.fit(label, Style.FONT, Style.CELL - 6, 6)
        labelCache[key] = label
    end
    return label
end

local hoverLabelCache = {}
local function hoverLabelFor(slot)
    if slot == nil then return nil end
    local key = tostring(slot.slotType or slot.name or "?")
    local info = hoverLabelCache[key]
    if info == nil then
        local label = nil
        if slot.slotType ~= nil then
            label = getTextOrNull("IGUI_HotbarAttachment_"
                .. tostring(slot.slotType))
        end
        if label == nil then label = tostring(slot.name or "?") end
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

Style.onScaleChanged(function()
    for key in pairs(labelCache) do labelCache[key] = nil end
    for key in pairs(hoverLabelCache) do hoverLabelCache[key] = nil end
end)

local synths = {}
local function synthFor(index, item)
    local synth = synths[index]
    if synth == nil then
        synth = { itemIDs = {}, count = 1, slot = 0, itemType = "?",
            bucket = "", category = nil, _lastId = nil }
        synths[index] = synth
    end
    local id = item:getID()
    if synth._lastId ~= id then
        if synth._lastId ~= nil then synth.itemIDs[synth._lastId] = nil end
        synth.itemIDs[id] = true
        synth._lastId = id
    end
    synth.slot = index - 1
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
        Log.error("HotbarStrip mouse handling failed: " .. tostring(err))
    end
end

function HotbarStrip:new(x, y, playerNum)
    local o = ISUIElement:new(x, y, 1, 1)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum or 0
    o.entryCount = 0
    o.cols = MIN_COLS
    o.rows = 1
    o.availWidth = nil
    o.hoverIdx = nil
    o.pressedIdx = nil
    o.pressedId = nil
    o.dragDidStart = false
    o.isComfyDragSource = true
    return o
end

function HotbarStrip:setAvailableWidth(px)
    self.availWidth = px
end

local InputHotbarOf = ComfyGrid.Core.Input.hotbarOf
local function hotbarOf(self)
    return InputHotbarOf(self.playerNum)
end

local function tileAt(self, x, y)
    local idx = Style.slotAtPixel(x, y, self.cols, self.rows)
    if idx == nil or idx >= self.entryCount then return nil end
    return idx
end

local function updateHover(self)
    self.hoverIdx = tileAt(self, self:getMouseX(), self:getMouseY())
end

local function tileXY(self, idx)
    return Style.pixelForSlot(idx, self.cols)
end

local function itemAt(self, x, y)
    local idx = tileAt(self, x, y)
    if idx == nil then return nil end
    local hotbar = hotbarOf(self)
    local item = hotbar ~= nil and hotbar.attachedItems ~= nil
        and hotbar.attachedItems[idx + 1] or nil
    return item, idx
end

function HotbarStrip:hoveredItem()
    local idx = self.hoverIdx
    if idx == nil or not self:isMouseOver() then return nil end
    local hotbar = hotbarOf(self)
    if hotbar == nil or hotbar.attachedItems == nil then return nil end
    return hotbar.attachedItems[idx + 1]
end

local function prerenderImpl(self)
    local hotbar = hotbarOf(self)
    local slots = hotbar ~= nil and hotbar.availableSlot or nil
    self.entryCount = slots ~= nil and #slots or 0
    if self.entryCount == 0 then

        if self.height ~= 0 then
            self:setWidth(1)
            self:setHeight(0)
        end
        return
    end
    local avail = self.availWidth
    local cols
    if avail == nil then
        cols = self.entryCount
    else
        cols = math.floor((avail - 1) / Style.CELL_STRIDE)
        if cols < MIN_COLS then cols = MIN_COLS end
    end
    if cols > self.entryCount then cols = self.entryCount end
    self.cols = cols
    self.rows = math.max(1, math.ceil(self.entryCount / cols))
    local stripWidth, stripHeight = Style.gridPixelSize(self.cols, self.rows)
    if stripWidth ~= self.width or stripHeight ~= self.height then
        self:setWidth(stripWidth)
        self:setHeight(stripHeight)
        updateHover(self)
    end
end

function HotbarStrip:prerender()
    local ok, err = pcall(prerenderImpl, self)
    if not ok and err ~= lastPrerenderError then
        lastPrerenderError = err
        Log.error("HotbarStrip prerender failed: " .. tostring(err))
    end
end

local function washBoard(self, cols, rows)
    local stripWidth, stripHeight = Style.gridPixelSize(cols, rows)
    local colors = Style.COLORS
    local bg = colors.BOARD_BG
    self:drawRect(0, 0, stripWidth, stripHeight, bg.a or 1, bg.r or 0,
        bg.g or 0, bg.b or 0)
end

local function emptyChipAt(_self, idx, attached, slots)
    if attached[idx + 1] == nil then
        return hoverLabelFor(slots[idx + 1])
    end
    return nil
end

local function renderImpl(self)
    if self.entryCount == 0 then return end
    local hotbar = hotbarOf(self)
    if hotbar == nil then return end
    local slots = hotbar.availableSlot
    local attached = hotbar.attachedItems or NO_ATTACHED
    local cols = self.cols
    washBoard(self, cols, self.rows)

    local pixelForSlot = Style.pixelForSlot
    local font = Style.FONT
    local cell = Style.CELL

    local currentAction = StackRenderer.currentActionOf(self.playerNum)

    local ItemApply, applySrc, applyPlayer, applyPulse, searchMarks,
        searchPulse = StripGestures.tileHints(self.playerNum)
    ctx.view = self
    ctx.playerNum = self.playerNum
    for i = 1, self.entryCount do
        local tx, ty = pixelForSlot(i - 1, cols)
        local item = attached[i]
        if item ~= nil then

            StackRenderer.updateItem(item)
            ctx.stack = synthFor(i, item)
            ctx.item = item
            ctx.slot = i - 1
            ctx.x = tx
            ctx.y = ty
            StackRenderer.draw(ctx)

            if searchMarks ~= nil and ItemSearch.marksItem(searchMarks, item) then
                SlotRenderer.drawSearchHint(ctx, searchPulse)
            end
            if applySrc ~= nil
                    and ItemApply.hintFor(applySrc, item, applyPlayer) then
                SlotRenderer.drawApplyHint(ctx, applyPulse)
            end

            local jobDelta = StackRenderer.jobDeltaOf(item, currentAction)
            if jobDelta ~= nil then
                StackRenderer.drawJobOverlay(self, tx, ty, jobDelta)
            end
        else

            StripGestures.drawEmptySocket(self, ctx, i - 1, tx, ty, slots[i],
                ComfyGrid.UI.HotbarGhosts.texFor, labelFor, font, cell)
        end
    end

    StripGestures.drawCursors(self, ctx, font, tileXY, emptyChipAt, attached,
        slots)
end

function HotbarStrip:render()
    local ok, err = pcall(renderImpl, self)
    if not ok and err ~= lastRenderError then
        lastRenderError = err
        Log.error("HotbarStrip render failed: " .. tostring(err))
    end
end

local function resolveAttachDrop(self, idx)
    local hotbar = hotbarOf(self)
    if hotbar == nil or hotbar.availableSlot == nil then return end
    local slot = hotbar.availableSlot[idx + 1]
    if slot == nil then return end
    local dragged = DragAndDrop.getDraggedStacks()
    if dragged == nil then return end

    local ItemApply = ComfyGrid.Interact.ItemApply
    local attachedItem = hotbar.attachedItems and hotbar.attachedItems[idx + 1]
    if ItemApply ~= nil and attachedItem ~= nil then
        local playerObj = getSpecificPlayer(self.playerNum)
        local srcItems = ItemApply.liveItemsOf(dragged)
        if playerObj ~= nil and srcItems ~= nil
                and ItemApply.tryApply(srcItems, attachedItem, playerObj) then
            return
        end
    end
    for i = 1, #dragged do
        local items = dragged[i].items
        if type(items) == "table" then
            local first = ComfyGrid.Core.VanillaStacks.firstRealIndex(items)
            for j = first, #items do
                local item = items[j]
                if item ~= nil and item:getContainer() ~= nil then
                    local ok, can = pcall(hotbar.canBeAttached, hotbar,
                        slot, item)
                    if ok and can then

                        local srcSlot, mainGrid =
                            StripGestures.sourceGridSlotOf(dragged[i],
                                self.playerNum)
                        local onDisplaced = nil
                        if srcSlot ~= nil and mainGrid ~= nil then
                            onDisplaced = function(evicted)
                                mainGrid:claimSlotForItem(evicted:getID(), srcSlot)
                            end
                        end

                        HotbarAttach.attach(self.playerNum, item, idx + 1,
                            slot.def, onDisplaced)
                        return
                    end
                end
            end
        end
    end
end

local function resolveReslotDrop(self, fromIdx, toIdx)
    if fromIdx == nil or toIdx == nil or fromIdx == toIdx then return end
    local hotbar = hotbarOf(self)
    if hotbar == nil or hotbar.availableSlot == nil then return end
    local fromSlot = hotbar.availableSlot[fromIdx + 1]
    local toSlot = hotbar.availableSlot[toIdx + 1]
    if fromSlot == nil or toSlot == nil then return end
    local item = hotbar.attachedItems[fromIdx + 1]
    if item == nil or item:getID() ~= self.pressedId then return end
    local fitRead, fits = pcall(hotbar.canBeAttached, hotbar, toSlot, item)
    if not fitRead or not fits then return end
    local occupant = hotbar.attachedItems[toIdx + 1]
    local swapBack = false
    if occupant ~= nil then
        local backFitRead, backFits = pcall(hotbar.canBeAttached, hotbar,
            fromSlot, occupant)
        swapBack = backFitRead and backFits == true
    end
    hotbar:removeItem(item, false)
    if occupant ~= nil then
        hotbar:removeItem(occupant, false)
    end
    hotbar:attachItem(item, toSlot.def.attachments[item:getAttachmentType()],
        toIdx + 1, toSlot.def, false)
    if swapBack then
        hotbar:attachItem(occupant,
            fromSlot.def.attachments[occupant:getAttachmentType()],
            fromIdx + 1, fromSlot.def, false)
    end

    if syncItemFields ~= nil then
        local playerObj = getSpecificPlayer(self.playerNum)
        if playerObj ~= nil then
            pcall(syncItemFields, playerObj, item)
            if occupant ~= nil then pcall(syncItemFields, playerObj, occupant) end
        end
    end
end

function HotbarStrip:resolvePadDrop(idx)
    resolveAttachDrop(self, idx)
end

function HotbarStrip:resolvePadReslot(fromIdx, toIdx, itemId)
    local armedIdBefore = self.pressedId
    self.pressedId = itemId
    local ok, err = pcall(resolveReslotDrop, self, fromIdx, toIdx)
    self.pressedId = armedIdBefore
    if not ok then reportMouseError(err) end
end

local function mouseDownImpl(self, x, y)
    StripGestures.beginPress(self)
    local item, idx = itemAt(self, x, y)
    if item == nil then return end

    if Unequip.pressClaims(item, self.playerNum, "detach") then return end

    StripGestures.armItemDrag(self, idx, item, x, y)
end

local function mouseUpImpl(self, x, y)

    if not DragAndDrop.isDragging() then
        local upItem = itemAt(self, x, y)
        if StripGestures.releaseClaimed(self, upItem, "detach") then return end
    end
    if DragAndDrop.isDragging() then
        local poked = x == 0 and y == 0 and DragAndDrop.isDragOwner(self)
            and (self:getMouseX() ~= 0 or self:getMouseY() ~= 0)
        if not poked and self:isMouseOver() then
            if not DragAndDrop.isDragOwner(self) then
                local idx = tileAt(self, x, y)
                if idx ~= nil then
                    resolveAttachDrop(self, idx)
                end
            else

                local idx = tileAt(self, x, y)
                if idx ~= nil then
                    local ok, err = pcall(resolveReslotDrop, self,
                        self.pressedIdx, idx)
                    if not ok then reportMouseError(err) end
                end
            end
            DragAndDrop.endDrag()
        elseif DragAndDrop.isDragOwner(self) then
            DragAndDrop.endDrag()
        end
    elseif DragAndDrop.isDragOwner(self) then
        DragAndDrop.endDrag()

    end
    self.pressedIdx = nil
    self.pressedId = nil
end

function HotbarStrip:onComfyDragCancelled()
    local ok, err = pcall(StripGestures.dropPressedToFloor, self)
    if not ok then reportMouseError(err) end
end

function HotbarStrip:onMouseDown(x, y)
    local ok, err = pcall(mouseDownImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end

function HotbarStrip:onMouseUp(x, y)
    local ok, err = pcall(mouseUpImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end

function HotbarStrip:onMouseUpOutside(_x, _y)
    local ok, err = pcall(StripGestures.releaseOutside, self)
    if not ok then reportMouseError(err) end
end

function HotbarStrip:onMouseMove(_dx, _dy)
    updateHover(self)
    StripGestures.promoteDrag(self)
end

function HotbarStrip:onMouseMoveOutside(_dx, _dy)
    self.hoverIdx = nil
    StripGestures.promoteDrag(self)
end

function HotbarStrip.onRightMouseDown(_self, _x, _y)
    return true
end

function HotbarStrip:onRightMouseUp(x, y)
    local ok, err = pcall(StripGestures.openMenuAt, self, x, y, itemAt)
    if not ok then reportMouseError(err) end
    return true
end
