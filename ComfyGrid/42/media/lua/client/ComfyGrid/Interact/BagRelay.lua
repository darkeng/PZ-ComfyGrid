--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.4
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Notify"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/Model/RelayedBags"
require "ComfyGrid/Interact/Transfer"
require "ComfyGrid/Interact/ApplyRestore"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local BagRelay = {}
ComfyGrid.Interact.BagRelay = BagRelay

local Log = ComfyGrid.Core.Log
local Notify = ComfyGrid.Core.Notify
local Text = ComfyGrid.Core.Text
local ContainerModel = ComfyGrid.Model.ContainerModel
local RelayedBags = ComfyGrid.Model.RelayedBags
local Transfer = ComfyGrid.Interact.Transfer
local ApplyRestore = ComfyGrid.Interact.ApplyRestore

local TRIP_TIMEOUT_MS = 25000

local RETURN_DELAY_MS = 2000

local lastError = nil
local function report(what, err)
    if err == lastError then return end
    lastError = err
    Log.error("BagRelay " .. what .. ": " .. tostring(err))
end

local function floorOf(playerNum)
    local ok, floor = pcall(ISInventoryPage.GetFloorContainer, playerNum)
    if ok then return floor end
    return nil
end

local function bagOnFloor(playerNum, bagId)
    local floor = floorOf(playerNum)
    if floor == nil then return nil end
    return floor:getItemWithID(bagId)
end

local function bagIdOf(container)
    if container == nil or not instanceof(container, "ItemContainer") then return nil end
    local bag = container:getContainingItem()
    if bag == nil then return nil end
    return bag:getID()
end

local function isTheBag(item, bagId)
    return item ~= nil and instanceof(item, "InventoryItem") and item:getID() == bagId
end

local function mergedInto(action, bagId)
    local merged = action.queueList
    if type(merged) ~= "table" then return false end
    for mergedIndex = 1, #merged do
        local queued = merged[mergedIndex]
        local items = type(queued) == "table" and queued.items or nil
        if type(items) == "table" then
            for itemIndex = 1, #items do
                if isTheBag(items[itemIndex], bagId) then return true end
            end
        end
    end
    return false
end

local function queueTouches(playerObj, bagId)
    local queue = ISTimedActionQueue.getTimedActionQueue(playerObj)
    local actions = queue ~= nil and queue.queue or nil
    if actions == nil then return false end
    for actionIndex = 1, #actions do
        local action = actions[actionIndex]
        if isTheBag(action.item, bagId) or mergedInto(action, bagId) then return true end
        if bagIdOf(action.srcContainer) == bagId or bagIdOf(action.destContainer) == bagId then
            return true
        end
    end
    return false
end

local function queueIsEmpty(playerObj)
    local queue = ISTimedActionQueue.getTimedActionQueue(playerObj)
    local actions = queue ~= nil and queue.queue or nil
    return actions == nil or #actions == 0
end

local function homeSlotOf(home, playerNum, bagId)
    local model = ContainerModel.getOrCreate(home, playerNum)
    local data = model ~= nil and model.grid ~= nil and model.grid.data or nil
    if data == nil or data.stacks == nil then return nil end
    for _, stack in pairs(data.stacks) do
        if stack.itemIDs ~= nil and stack.itemIDs[bagId] then return stack.slot end
    end
    return nil
end

local function windowShows(playerNum, bagId)
    local ContainerWindow = ComfyGrid.UI and ComfyGrid.UI.ContainerWindow
    if ContainerWindow == nil then return false end
    local window = ContainerWindow.windowFor(playerNum)
    if window == nil or not window:getIsVisible() or window.item == nil then return false end
    return window.item:getID() == bagId
end

local function busyWithAGesture(playerNum)
    if ISMouseDrag ~= nil and ISMouseDrag.dragging ~= nil then return true end
    local menu = getPlayerContextMenu ~= nil and getPlayerContextMenu(playerNum) or nil
    return menu ~= nil and menu.isAnyVisible ~= nil and menu:isAnyVisible() == true
end

local function homeWithinReach(home, playerObj)
    return ApplyRestore.reachableNow(home, playerObj) == true
end

local function stillLiesOnTheFloor(entry)
    local bag = entry.floorBag
    if bag == nil then return false end
    local ok, worldItem = pcall(bag.getWorldItem, bag)
    return ok and worldItem ~= nil
end

local function tell(playerNum, key, english)
    Notify.bad(playerNum, Text.tr(key, english))
end

function BagRelay.floorHasRoomFor(playerObj, bagItem, floor, home)
    local probe = setmetatable({
        character = playerObj, item = bagItem, srcContainer = home, destContainer = floor,
    }, { __index = ISInventoryTransferAction })
    local ok, square = pcall(ISInventoryTransferAction.getNotFullFloorSquare, probe, bagItem)
    if not ok then
        report("floor probe", square)
        return true
    end
    return square ~= nil
end

function BagRelay.open(playerNum, bagItem, home, anchorX, anchorY)
    playerNum = playerNum or 0
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil or bagItem == nil or home == nil then return false end
    local bagId = bagItem:getID()
    if RelayedBags.get(bagId) ~= nil then return true end
    local floor = floorOf(playerNum)
    if floor == nil then return false end
    if not BagRelay.floorHasRoomFor(playerObj, bagItem, floor, home) then
        tell(playerNum, "IGUI_ComfyGrid_BagNoFloorRoom",
            "No room on the floor to set the bag down.")
        return false
    end
    local homeSlot = homeSlotOf(home, playerNum, bagId)
    if (Transfer.moveItems({ bagItem }, floor, playerObj, nil) or 0) <= 0 then

        tell(playerNum, "IGUI_ComfyGrid_BagCantSetDown",
            "This bag can't be set down on the floor.")
        return false
    end
    RelayedBags.add({
        bagId = bagId, playerNum = playerNum, home = home, homeSlot = homeSlot,
        anchorX = anchorX, anchorY = anchorY,
    })
    return true
end

local function advanceLowering(entry, playerObj, nowMs)
    local landed = bagOnFloor(entry.playerNum, entry.bagId)
    if landed ~= nil then
        entry.floorBag = landed
        RelayedBags.setPhase(entry, RelayedBags.OUT)
        local ContainerWindow = ComfyGrid.UI and ComfyGrid.UI.ContainerWindow
        if ContainerWindow ~= nil then
            ContainerWindow.openFor(entry.playerNum, landed, entry.anchorX, entry.anchorY)
        end
        return
    end
    if queueTouches(playerObj, entry.bagId) then

        entry.phaseSinceMs = nowMs
        return
    end

    if entry.home:getItemWithID(entry.bagId) ~= nil then
        RelayedBags.remove(entry.bagId)
        return
    end

    if not entry.refreshAsked then
        entry.refreshAsked = true
        ISInventoryPage.dirtyUI()
    end
    if nowMs - entry.phaseSinceMs > TRIP_TIMEOUT_MS then
        RelayedBags.remove(entry.bagId)
    end
end

local function failReturn(entry, nowMs)
    if entry.retried then

        if stillLiesOnTheFloor(entry) then
            tell(entry.playerNum, "IGUI_ComfyGrid_BagLeftOnFloor",
                "The bag was left on the floor.")
        end
        RelayedBags.remove(entry.bagId)
        return
    end
    entry.retried = true
    RelayedBags.setPhase(entry, RelayedBags.OUT)
    entry.closedSinceMs = nowMs - RETURN_DELAY_MS
end

local function advanceOut(entry, playerObj, nowMs)
    local bag = bagOnFloor(entry.playerNum, entry.bagId)
    if bag == nil then
        if stillLiesOnTheFloor(entry) then
            tell(entry.playerNum, "IGUI_ComfyGrid_BagLeftOnFloor",
                "The bag was left on the floor.")
        end
        RelayedBags.remove(entry.bagId)
        return
    end
    entry.floorBag = bag
    if windowShows(entry.playerNum, entry.bagId) then
        entry.closedSinceMs = nil
        return
    end
    entry.closedSinceMs = entry.closedSinceMs or nowMs
    if nowMs - entry.closedSinceMs < RETURN_DELAY_MS then return end
    if not queueIsEmpty(playerObj) then return end
    if playerObj:isPlayerMoving() then return end
    if busyWithAGesture(entry.playerNum) then return end
    if not homeWithinReach(entry.home, playerObj) then return end
    if (Transfer.moveItems({ bag }, entry.home, playerObj, entry.homeSlot) or 0) > 0 then
        RelayedBags.setPhase(entry, RelayedBags.RETURNING)
    else
        failReturn(entry, nowMs)
    end
end

local function advanceReturning(entry, playerObj, nowMs)
    if entry.home:getItemWithID(entry.bagId) ~= nil then
        RelayedBags.remove(entry.bagId)
        return
    end
    if queueTouches(playerObj, entry.bagId)
            and nowMs - entry.phaseSinceMs <= TRIP_TIMEOUT_MS then
        return
    end
    failReturn(entry, nowMs)
end

local ADVANCE_BY_PHASE = {
    [RelayedBags.LOWERING] = advanceLowering,
    [RelayedBags.OUT] = advanceOut,
    [RelayedBags.RETURNING] = advanceReturning,
}

function BagRelay._onTick()
    if RelayedBags.count() == 0 then return end
    local nowMs = getTimestampMs()
    for bagId, entry in RelayedBags.each() do
        local playerObj = getSpecificPlayer(entry.playerNum)
        if playerObj == nil or playerObj:isDead() then
            RelayedBags.remove(bagId)
        else
            local advance = ADVANCE_BY_PHASE[entry.phase]
            if advance ~= nil then
                local ok, err = pcall(advance, entry, playerObj, nowMs)
                if not ok then report(entry.phase, err) end
            end
        end
    end
end

if not ComfyGrid._bagRelayTickHooked then
    ComfyGrid._bagRelayTickHooked = true
    Events.OnTick.Add(function()
        local relay = ComfyGrid.Interact and ComfyGrid.Interact.BagRelay
        if relay ~= nil then relay._onTick() end
    end)
end
