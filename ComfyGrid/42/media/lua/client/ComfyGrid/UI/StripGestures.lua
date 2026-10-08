--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/Model/ItemSearch"
require "ComfyGrid/Interact/DragAndDrop"
require "ComfyGrid/Interact/Transfer"
require "ComfyGrid/Interact/Unequip"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local VanillaStacks = ComfyGrid.Core.VanillaStacks
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local ItemSearch = ComfyGrid.Model.ItemSearch
local DragAndDrop = ComfyGrid.Interact.DragAndDrop
local Transfer = ComfyGrid.Interact.Transfer
local Unequip = ComfyGrid.Interact.Unequip

local StripGestures = {}
ComfyGrid.UI.StripGestures = StripGestures

local Style = ComfyGrid.UI.Style

local function clearPress(strip)
    strip.pressedIdx = nil
    strip.pressedId = nil
end

function StripGestures.beginPress(strip)
    if DragAndDrop.isDragOwner(strip) and not DragAndDrop.isDragging() then
        DragAndDrop.endDrag()
    end
    clearPress(strip)
    strip.dragDidStart = false
end

function StripGestures.armItemDrag(strip, idx, item, x, y)
    local payload = { VanillaStacks.fromItems({ item }) }
    if payload[1] == nil then return end
    DragAndDrop.prepareDrag(strip, payload, x, y)
    strip.pressedIdx = idx
    strip.pressedId = item:getID()
end

function StripGestures.releaseClaimed(strip, item, verb)
    if item == nil
            or not Unequip.releaseClaims(strip, item, strip.playerNum, verb) then
        return false
    end
    if DragAndDrop.isDragOwner(strip) then DragAndDrop.endDrag() end
    clearPress(strip)
    return true
end

function StripGestures.promoteDrag(strip)
    if DragAndDrop == nil then return end
    DragAndDrop.startDrag(strip)
    if not strip.dragDidStart and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(strip) then
        strip.dragDidStart = true
    end
end

function StripGestures.sourceGridSlotOf(entry, playerNum)
    local tag = entry.comfyStacks or entry.comfyStack
    if type(tag) == "table" and tag.itemIDs == nil then tag = tag[1] end
    if type(tag) ~= "table" or tag.itemIDs == nil
            or type(tag.slot) ~= "number" then
        return nil, nil
    end
    local ContainerModel = ComfyGrid.Model and ComfyGrid.Model.ContainerModel
    local model = ContainerModel ~= nil and ContainerModel.getPlayerMain ~= nil
        and ContainerModel.getPlayerMain(playerNum) or nil
    local grid = model ~= nil and model.grid or nil
    if grid == nil or grid.claimSlotForItem == nil then return nil, nil end
    local stacks = grid.data.stacks
    for i = 1, #stacks do
        if stacks[i] == tag then return tag.slot, grid end
    end
    return nil, nil
end

function StripGestures.dropPressedToFloor(strip)
    local id = strip.pressedId
    clearPress(strip)
    if id == nil then return end

    if not DragAndDrop.releaseDropsToFloor(strip.playerNum) then return end
    local playerObj = getSpecificPlayer(strip.playerNum)
    if playerObj == nil then return end
    local item = playerObj:getInventory():getItemWithID(id)
    if item ~= nil then
        Transfer.dropToFloor({ item }, playerObj)
    end
end

function StripGestures.releaseOutside(strip)
    if not DragAndDrop.isDragOwner(strip) then return end
    if DragAndDrop.isDragging() then
        DragAndDrop.cancelDrag(strip, strip.onComfyDragCancelled)
    else
        DragAndDrop.endDrag()
        clearPress(strip)
    end
end

function StripGestures.openMenuAt(strip, x, y, itemAt)
    if DragAndDrop.isDragging() then return end
    if DragAndDrop.isDragOwner(strip) then
        DragAndDrop.endDrag()
        clearPress(strip)
    end
    local item = itemAt(strip, x, y)
    if item == nil then return end
    ISInventoryPaneContextMenu.createMenu(strip.playerNum, true, { item },
        getMouseX(), getMouseY())
end

function StripGestures.tileHints(playerNum)
    local ItemApply = ComfyGrid.Interact.ItemApply
    local applySrc = ItemApply ~= nil and ItemApply.dragSource() or nil
    local applyPlayer = nil
    local applyPulse = 1
    if applySrc ~= nil then
        applyPlayer = getSpecificPlayer(playerNum)
        if applyPlayer == nil then applySrc = nil end
        applyPulse = SlotRenderer.applyPulse()
    end
    local searchMarks = ItemSearch.marksFor(playerNum)
    local searchPulse = 1
    if searchMarks ~= nil then searchPulse = SlotRenderer.applyPulse() end
    return ItemApply, applySrc, applyPlayer, applyPulse, searchMarks,
        searchPulse
end

function StripGestures.drawEmptySocket(strip, ctx, idx, tx, ty, socketKey,
        ghostOf, labelOf, font, cell)
    ctx.stack = nil
    ctx.item = nil
    ctx.slot = idx
    ctx.x = tx
    ctx.y = ty
    SlotRenderer.drawSocket(ctx)
    local tex = ghostOf(socketKey)
    if tex ~= nil then
        SlotRenderer.drawGhost(strip, tex, tx, ty)
    elseif font ~= nil then
        local label = Style.COLORS.EMPTY_SLOT_LABEL
        strip:drawTextCentre(labelOf(socketKey), tx + cell / 2,
            ty + math.floor(cell / 2) - 7, label.r, label.g, label.b,
            label.a, font)
    end
end

local function drawCursorTile(strip, ctx, idx, tx, ty, chip, font)
    ctx.stack = nil
    ctx.item = nil
    ctx.slot = idx
    ctx.x = tx
    ctx.y = ty
    SlotRenderer.drawHover(ctx)
    if chip ~= nil then
        SlotRenderer.drawNameChip(strip, chip, tx, ty, font)
    end
end

function StripGestures.drawCursors(strip, ctx, font, tileXYOf, emptyChipOf,
        extraA, extraB)
    local hover = strip.hoverIdx
    if hover ~= nil and hover < strip.entryCount and strip:isMouseOver() then
        local hx, hy = tileXYOf(strip, hover)
        drawCursorTile(strip, ctx, hover, hx, hy,
            emptyChipOf(strip, hover, extraA, extraB), font)
    end

    local Pad = ComfyGrid.Interact and ComfyGrid.Interact.PadFocus
    local padIdx = Pad ~= nil and Pad.cursorFor ~= nil and Pad.cursorFor(strip)
        or nil
    if padIdx ~= nil and padIdx < strip.entryCount then
        local px, py = tileXYOf(strip, padIdx)
        SlotRenderer.drawSelection(strip, px, py)
        drawCursorTile(strip, ctx, padIdx, px, py,
            emptyChipOf(strip, padIdx, extraA, extraB), font)
        local Carry = ComfyGrid.Interact.PadCarry
        if Carry ~= nil and Carry.renderAt ~= nil then
            Carry.renderAt(strip, px, py)
        end
    end
end

return StripGestures
