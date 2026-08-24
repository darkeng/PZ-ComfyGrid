--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/UI/StackRenderer"
require "ComfyGrid/Interact/DragAndDrop"
require "ComfyGrid/Interact/Transfer"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local VanillaStacks = ComfyGrid.Core.VanillaStacks
local Style = ComfyGrid.UI.Style
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local StackRenderer = ComfyGrid.UI.StackRenderer
local DragAndDrop = ComfyGrid.Interact.DragAndDrop
local Transfer = ComfyGrid.Interact.Transfer

local HotbarStrip = ISUIElement:derive("ComfyHotbarStrip")
ComfyGrid.UI.HotbarStrip = HotbarStrip

local MIN_COLS = 2

local DEFAULT_BG = { r = 0.09, g = 0.09, b = 0.11, a = 0.85 }
local LABEL = { r = 0.62, g = 0.62, b = 0.68, a = 0.9 }

local ctx = { view = false, stack = false, item = false, slot = 0, x = 0, y = 0, playerNum = 0 }

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
    SmallBeltLeft = "Base.HuntingKnife",
    SmallBeltRight = "Base.HuntingKnife",
    WebbingLeft = "Base.HuntingKnife",
    WebbingRight = "Base.HuntingKnife",
    HolsterLeft = "Base.Pistol",
    HolsterRight = "Base.Pistol",
    HolsterShoulder = "Base.Pistol",
    HolsterAnkle = "Base.Pistol",
    Back = "Base.BaseballBat",
    Bag = "Base.Bag_Schoolbag",

    BedrollBottom = "Base.SleepingBag_Green_Packed",
    BedrollBottomBig = "Base.SleepingBag_Green_Packed",
    BedrollBottomALICE = "Base.SleepingBag_Green_Packed",
}

local ATTACH_ITEMS = {
    Bedroll = "Base.SleepingBag_Green_Packed",
    Holster = "Base.Pistol",
    HolsterSmall = "Base.Pistol",
    Knife = "Base.HuntingKnife",
    BigBlade = "Base.HuntingKnife",
    Rifle = "Base.HuntingRifle",
    BigWeapon = "Base.HuntingRifle",
    Hammer = "Base.Hammer",
}
local ghostTexCache = {}
local function ghostTexFor(slot)
    if slot == nil then return nil end
    local key = tostring(slot.slotType or slot.name or "?")
    local cached = ghostTexCache[key]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local fullType = GHOST_ITEMS[key]
    if fullType == nil and slot.def ~= nil
            and type(slot.def.attachments) == "table" then
        for attachType in pairs(slot.def.attachments) do
            if ATTACH_ITEMS[attachType] ~= nil then
                fullType = ATTACH_ITEMS[attachType]
                break
            end
        end
    end
    if fullType == nil then
        if key:find("Holster") ~= nil then
            fullType = "Base.Pistol"
        elseif key:find("Belt") ~= nil or key:find("Webbing") ~= nil then
            fullType = "Base.HuntingKnife"
        end
    end
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
    o.sizeDirty = false
    o.pressedIdx = nil
    o.pressedId = nil
    o.dragDidStart = false
    o.isComfyDragSource = true
    return o
end

function HotbarStrip:setAvailableWidth(px)
    self.availWidth = px
end

local function hotbarOf(self)
    local ok, hotbar = pcall(getPlayerHotbar, self.playerNum)
    if ok then return hotbar end
    return nil
end

local function tileAt(self, x, y)
    local idx = Style.slotAtPixel(x, y, self.cols, self.rows)
    if idx == nil or idx >= self.entryCount then return nil end
    return idx
end

local function updateHover(self)
    self.hoverIdx = tileAt(self, self:getMouseX(), self:getMouseY())
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
            self.sizeDirty = true
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
    local w, h = Style.gridPixelSize(self.cols, self.rows)
    if w ~= self.width or h ~= self.height then
        self:setWidth(w)
        self:setHeight(h)
        self.sizeDirty = true
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

local function renderImpl(self)
    if self.entryCount == 0 then return end
    local hotbar = hotbarOf(self)
    if hotbar == nil then return end
    local slots = hotbar.availableSlot
    local attached = hotbar.attachedItems or {}
    local cols = self.cols
    local rows = self.rows
    local w, h = Style.gridPixelSize(cols, rows)
    local colors = Style.COLORS
    local bg = colors and colors.BOARD_BG or DEFAULT_BG

    self:drawRect(0, 0, w, h, bg.a or 1, bg.r or 0, bg.g or 0, bg.b or 0)

    local pixelForSlot = Style.pixelForSlot
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
            if applySrc ~= nil
                    and ItemApply.hintFor(applySrc, item, applyPlayer) then
                SlotRenderer.drawApplyHint(ctx, applyPulse)
            end

            local jd = StackRenderer.jobDeltaOf(item, currentAction)
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
            local tex = ghostTexFor(slots[i])
            if tex ~= nil then
                SlotRenderer.drawGhost(self, tex, tx, ty)
            elseif font ~= nil then
                local name = labelFor(slots[i])
                self:drawTextCentre(name, tx + cell / 2,
                    ty + math.floor(cell / 2) - 7, LABEL.r, LABEL.g, LABEL.b,
                    LABEL.a, font)
            end
        end
    end

    local hover = self.hoverIdx
    if hover ~= nil and hover < self.entryCount and self:isMouseOver() then
        local hx, hy = pixelForSlot(hover, cols)
        ctx.stack = nil
        ctx.item = nil
        ctx.slot = hover
        ctx.x = hx
        ctx.y = hy
        SlotRenderer.drawHover(ctx)

        if attached[hover + 1] == nil then
            SlotRenderer.drawNameChip(self, hoverLabelFor(slots[hover + 1]),
                hx, hy, font)
        end
    end

    local Pad = ComfyGrid.Interact and ComfyGrid.Interact.PadFocus
    local padIdx = Pad ~= nil and Pad.cursorFor ~= nil and Pad.cursorFor(self)
        or nil
    if padIdx ~= nil and padIdx < self.entryCount then
        local px, py = pixelForSlot(padIdx, cols)
        SlotRenderer.drawSelection(self, px, py)
        ctx.stack = nil
        ctx.item = nil
        ctx.slot = padIdx
        ctx.x = px
        ctx.y = py
        SlotRenderer.drawHover(ctx)
        if attached[padIdx + 1] == nil then
            SlotRenderer.drawNameChip(self, hoverLabelFor(slots[padIdx + 1]),
                px, py, font)
        end
        local Carry = ComfyGrid.Interact.PadCarry
        if Carry ~= nil and Carry.renderAt ~= nil then
            Carry.renderAt(self, px, py)
        end
    end
end

function HotbarStrip:render()
    local ok, err = pcall(renderImpl, self)
    if not ok and err ~= lastRenderError then
        lastRenderError = err
        Log.error("HotbarStrip render failed: " .. tostring(err))
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
            local first = (#items >= 2) and 2 or 1
            for j = first, #items do
                local item = items[j]
                if item ~= nil and item:getContainer() ~= nil then
                    local ok, can = pcall(hotbar.canBeAttached, hotbar,
                        slot, item)
                    if ok and can then
                        local displaced = hotbar.attachedItems[idx + 1]

                        local okA, err = pcall(hotbar.attachItem, hotbar,
                            item,
                            slot.def.attachments[item:getAttachmentType()],
                            idx + 1, slot.def, true)
                        if not okA then
                            Log.warn("HotbarStrip attach failed: "
                                .. tostring(err))
                        elseif displaced ~= nil and displaced ~= item then

                            local srcSlot, mainGrid =
                                sourceGridSlotOf(dragged[i], self.playerNum)
                            if srcSlot ~= nil then
                                mainGrid:claimSlotForItem(
                                    displaced:getID(), srcSlot)
                            end
                        end
                        return
                    end
                end
            end
        end
    end
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
    local hotbar = hotbarOf(self)
    local item = hotbar ~= nil and hotbar.attachedItems ~= nil
        and hotbar.attachedItems[idx + 1] or nil
    if item == nil then return end

    local payload = { VanillaStacks.fromItems({ item }) }
    if payload[1] == nil then return end
    DragAndDrop.prepareDrag(self, payload, x, y)
    self.pressedIdx = idx
    self.pressedId = item:getID()
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
    local okC, can = pcall(hotbar.canBeAttached, hotbar, toSlot, item)
    if not okC or not can then return end
    local other = hotbar.attachedItems[toIdx + 1]
    local swapBack = false
    if other ~= nil then
        local okO, canO = pcall(hotbar.canBeAttached, hotbar, fromSlot, other)
        swapBack = okO and canO == true
    end
    hotbar:removeItem(item, false)
    if other ~= nil then
        hotbar:removeItem(other, false)
    end
    hotbar:attachItem(item, toSlot.def.attachments[item:getAttachmentType()],
        toIdx + 1, toSlot.def, false)
    if swapBack then
        hotbar:attachItem(other,
            fromSlot.def.attachments[other:getAttachmentType()],
            fromIdx + 1, fromSlot.def, false)
    end
end

function HotbarStrip:resolvePadDrop(idx)
    resolveAttachDrop(self, idx)
end

function HotbarStrip:resolvePadReslot(fromIdx, toIdx, itemId)
    local prev = self.pressedId
    self.pressedId = itemId
    local ok, err = pcall(resolveReslotDrop, self, fromIdx, toIdx)
    self.pressedId = prev
    if not ok then reportMouseError(err) end
end

local function mouseUpImpl(self, x, y)
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

function HotbarStrip:onComfyDragCancelled()
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
    if idx == nil then return end
    local hotbar = hotbarOf(self)
    local item = hotbar ~= nil and hotbar.attachedItems ~= nil
        and hotbar.attachedItems[idx + 1] or nil
    if item == nil then return end

    ISInventoryPaneContextMenu.createMenu(self.playerNum, true, { item },
        getMouseX(), getMouseY())
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

function HotbarStrip:onMouseUpOutside(x, y)
    local ok, err = pcall(mouseUpOutsideImpl, self, x, y)
    if not ok then reportMouseError(err) end
end

function HotbarStrip:onMouseMove(_dx, _dy)
    updateHover(self)
    if DragAndDrop == nil then return end
    DragAndDrop.startDrag(self)
    if not self.dragDidStart and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(self) then
        self.dragDidStart = true
    end
end

function HotbarStrip:onMouseMoveOutside(_dx, _dy)
    self.hoverIdx = nil
    if DragAndDrop == nil then return end
    DragAndDrop.startDrag(self)
    if not self.dragDidStart and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(self) then
        self.dragDidStart = true
    end
end

function HotbarStrip.onRightMouseDown(_self, _x, _y)
    return true
end

function HotbarStrip:onRightMouseUp(x, y)
    local ok, err = pcall(rightMouseUpImpl, self, x, y)
    if not ok then reportMouseError(err) end
    return true
end
