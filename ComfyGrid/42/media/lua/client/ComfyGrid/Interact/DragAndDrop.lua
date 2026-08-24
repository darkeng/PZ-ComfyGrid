--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/VanillaStacks"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local DragAndDrop = {}
ComfyGrid.Interact.DragAndDrop = DragAndDrop

local Log = ComfyGrid.Core.Log
local VanillaStacks = ComfyGrid.Core.VanillaStacks

local abs = math.abs

DragAndDrop.DRAG_THRESHOLD_PX = 8

local pendingCancelOwner = nil
local pendingCancelCallback = nil

local normalizedSource = nil
local normalizedList = nil

local function clearNormalized()
    normalizedSource = nil
    normalizedList = nil
end

local function clearPendingCancel()
    pendingCancelOwner = nil
    pendingCancelCallback = nil
end

local ghostFailLogged = false

local function ensureGhost()
    local ghost = ComfyGrid.UI and ComfyGrid.UI.DragGhost
    if ghost == nil or ghost.ensure == nil then return end
    local ok, err = pcall(ghost.ensure)
    if not ok and not ghostFailLogged then
        ghostFailLogged = true
        Log.error("DragAndDrop: DragGhost.ensure failed (logged once): "
            .. tostring(err))
    end
end

function DragAndDrop.prepareDrag(owner, vanillaStacks, x, y)

    clearPendingCancel()
    ISMouseDrag.dragOwner = owner
    ISMouseDrag.itemsToDrag = vanillaStacks
    ISMouseDrag.localXStart = x
    ISMouseDrag.localYStart = y
end

function DragAndDrop.startDrag(owner)
    if ISMouseDrag.dragOwner ~= owner then return end
    if ISMouseDrag.dragging ~= nil or ISMouseDrag.itemsToDrag == nil then return end
    local limit = DragAndDrop.DRAG_THRESHOLD_PX
    if abs(owner:getMouseX() - ISMouseDrag.localXStart) > limit
            or abs(owner:getMouseY() - ISMouseDrag.localYStart) > limit then
        ISMouseDrag.dragging = ISMouseDrag.itemsToDrag
        ISMouseDrag.itemsToDrag = nil

        ISMouseDrag.draggingFocus = owner

        ensureGhost()
    end
end

function DragAndDrop.beginDirectDrag(owner, vanillaStacks)
    if owner == nil or vanillaStacks == nil or #vanillaStacks == 0 then
        return false
    end
    clearPendingCancel()
    ISMouseDrag.dragOwner = owner
    ISMouseDrag.itemsToDrag = nil
    ISMouseDrag.localXStart = 0
    ISMouseDrag.localYStart = 0
    ISMouseDrag.dragging = vanillaStacks
    ISMouseDrag.draggingFocus = owner
    return true
end

function DragAndDrop.isDragging()
    return ISMouseDrag.dragging ~= nil
end

function DragAndDrop.isComfyDrag()
    local focus = ISMouseDrag.draggingFocus
    return ISMouseDrag.dragging ~= nil and focus ~= nil
        and (focus.isComfyDragSource == true or focus.Type == "ComfyGridView")
end

function DragAndDrop.isDragOwner(owner)
    return ISMouseDrag.dragOwner == owner
end

function DragAndDrop.wasDragStarted(owner)
    return ISMouseDrag.dragging ~= nil and ISMouseDrag.dragOwner == owner
end

function DragAndDrop.getDraggedStacks()
    local dragging = ISMouseDrag.dragging
    if dragging == nil then

        clearNormalized()
        return nil
    end
    if dragging == normalizedSource then
        return normalizedList
    end
    local list
    if instanceof(dragging, "InventoryItem") then
        list = { VanillaStacks.fromItems({ dragging }) }
    elseif type(dragging) == "table" then
        if dragging.items ~= nil then
            list = { dragging }
        else
            list = {}
            for i = 1, #dragging do
                local entry = dragging[i]
                if type(entry) == "table" then
                    if entry.items ~= nil then
                        list[#list + 1] = entry
                    end
                elseif instanceof(entry, "InventoryItem") then
                    local wrapped = VanillaStacks.fromItems({ entry })
                    if wrapped ~= nil then
                        list[#list + 1] = wrapped
                    end
                end
            end
        end
    else

        list = {}
    end
    normalizedSource = dragging
    normalizedList = list
    return list
end

function DragAndDrop.endDrag()
    ISMouseDrag.dragging = nil
    ISMouseDrag.draggingFocus = nil
    ISMouseDrag.dragOwner = nil
    ISMouseDrag.itemsToDrag = nil
    clearPendingCancel()
    clearNormalized()
end

function DragAndDrop.releaseDropsToFloor(playerNum)
    local mx = getMouseX()
    local my = getMouseY()
    local uis = UIManager.getUI()
    local overAny = false
    for i = 0, uis:size() - 1 do
        if uis:get(i):isPointOver(mx, my) then
            overAny = true
            break
        end
    end
    if not overAny then return true end
    if playerNum == nil then return false end
    local okI, page = pcall(getPlayerInventory, playerNum)
    if okI and page ~= nil and page.isPointOver ~= nil
            and page:isPointOver(mx, my) then
        return true
    end
    local okL, loot = pcall(getPlayerLoot, playerNum)
    if okL and loot ~= nil and loot.isPointOver ~= nil
            and loot:isPointOver(mx, my) then
        return true
    end
    return false
end

function DragAndDrop.cancelDrag(owner, cb)
    if ISMouseDrag.dragOwner ~= owner then return end
    pendingCancelOwner = owner
    pendingCancelCallback = cb
end

function DragAndDrop._onTick()

    if normalizedSource ~= nil and ISMouseDrag.dragging == nil then
        clearNormalized()
    end
    local owner = pendingCancelOwner
    if owner ~= nil then
        local cb = pendingCancelCallback
        clearPendingCancel()

        if ISMouseDrag.dragOwner ~= owner then return end
        if cb ~= nil then

            local ok, err = pcall(cb, owner)
            if not ok then
                Log.error("DragAndDrop cancel callback failed: " .. tostring(err))
            end
        end
        DragAndDrop.endDrag()
        return
    end

    local stale = ISMouseDrag.dragOwner
    if stale == nil or stale.onComfyDragCancelled == nil then return end
    if isMouseButtonDown(0) then return end
    pendingCancelOwner = stale
    pendingCancelCallback = stale.onComfyDragCancelled
end

if not ComfyGrid._dragCancelTickHooked then
    ComfyGrid._dragCancelTickHooked = true
    Events.OnTick.Add(function()
        local dd = ComfyGrid.Interact and ComfyGrid.Interact.DragAndDrop
        if dd ~= nil then
            dd._onTick()
        end
    end)
end
