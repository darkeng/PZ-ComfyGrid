--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/Interact/Transfer"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local ApplyRestore = {}
ComfyGrid.Interact.ApplyRestore = ApplyRestore

local Log = ComfyGrid.Core.Log
local ItemStack = ComfyGrid.Model.ItemStack
local ContainerModel = ComfyGrid.Model.ContainerModel
local Transfer = ComfyGrid.Interact.Transfer

local function originOf(item, playerNum)
    local inv = item:getContainer()
    if inv == nil then return nil end
    local slot = nil
    local ok, model = pcall(ContainerModel.getOrCreate, inv, playerNum)
    if ok and model ~= nil and model.grid ~= nil then
        local id = item:getID()
        local stacks = model.grid.data.stacks
        for i = 1, #stacks do
            if ItemStack.containsId(stacks[i], id) then
                slot = stacks[i].slot
                break
            end
        end
    end
    return { id = item:getID(), inventory = inv, slot = slot }
end

local function predicateNotBroken(item)
    return not item:isBroken()
end

local RESTORE_TYPE = "ComfyApplyRestoreAction"

local function pendingRestores(playerObj)
    local restores = nil
    local okQ, queue = pcall(ISTimedActionQueue.getTimedActionQueue, playerObj)
    if not okQ or queue == nil or type(queue.queue) ~= "table" then return nil end
    for i = 1, #queue.queue do
        local queuedAction = queue.queue[i]
        if type(queuedAction) == "table" and queuedAction.Type == RESTORE_TYPE
                and queuedAction.comfyPlan ~= nil then
            restores = restores or {}
            restores[#restores + 1] = queuedAction
        end
    end
    return restores
end

local function claimHome(tracked, playerObj)
    if tracked.slot == nil or tracked.inventory == nil then return end
    local ok, model = pcall(ContainerModel.getOrCreate, tracked.inventory,
        playerObj:getPlayerNum())
    if ok and model ~= nil and model.grid ~= nil
            and model.grid.claimSlotForItem ~= nil then
        model.grid:claimSlotForItem(tracked.id, tracked.slot)
    end
end

local function releaseHome(tracked, playerObj)
    if tracked.inventory == nil then return end
    local ok, model = pcall(ContainerModel.getOrCreate, tracked.inventory,
        playerObj:getPlayerNum())
    if ok and model ~= nil and model.grid ~= nil
            and model.grid.releaseClaim ~= nil then
        model.grid:releaseClaim(tracked.id)
    end
end

local function adoptedOrigin(item, pending)
    if pending == nil then return nil end
    local id = item:getID()
    for i = 1, #pending do
        local targets = pending[i].comfyPlan.targets
        for j = 1, #targets do
            if targets[j].id == id then
                local origin = table.remove(targets, j)
                return origin
            end
        end
    end
    return nil
end

function ApplyRestore.snapshot(dst, playerObj, extraItems, trackScrewdriver)
    local playerNum = playerObj:getPlayerNum()
    local primaryItem = playerObj:getPrimaryHandItem()
    local secondaryItem = playerObj:getSecondaryHandItem()
    local plan = {
        playerNum = playerNum,
        primaryId = primaryItem ~= nil and primaryItem:getID() or nil,
        secondaryId = secondaryItem ~= nil and secondaryItem:getID() or nil,
        targets = {},
    }
    local pending = pendingRestores(playerObj)
    if pending ~= nil then
        local first = pending[1].comfyPlan
        plan.primaryId = first.primaryId
        plan.secondaryId = first.secondaryId
    end
    local function track(item)
        if item == nil or playerObj:isEquipped(item) then return end
        local origin = adoptedOrigin(item, pending) or originOf(item, playerNum)
        if origin ~= nil then plan.targets[#plan.targets + 1] = origin end
    end
    track(dst)

    if extraItems ~= nil then
        for i = 1, #extraItems do
            local sourceItem = extraItems[i]
            if sourceItem ~= dst then track(sourceItem) end
        end
    end
    if trackScrewdriver then
        local inv = playerObj:getInventory()
        local okS, tool = pcall(inv.getFirstTagEvalRecurse, inv,
            ItemTag.SCREWDRIVER, predicateNotBroken)
        if okS and tool ~= nil and not playerObj:isEquipped(tool) then
            local origin = originOf(tool, playerNum)
            if origin ~= nil then plan.targets[#plan.targets + 1] = origin end
        end
    end
    for i = 1, #plan.targets do
        claimHome(plan.targets[i], playerObj)
    end
    return plan
end

local function resolveItem(id, playerObj, originInv)
    if id == nil then return nil end
    local inv = playerObj:getInventory()
    local ok, item = pcall(inv.getItemById, inv, id)
    if ok and item ~= nil then return item end
    if originInv ~= nil and originInv.getItemById ~= nil then
        local okO, itemO = pcall(originInv.getItemById, originInv, id)
        if okO and itemO ~= nil then return itemO end
    end
    return nil
end
ApplyRestore.resolveItem = resolveItem

local function alive(item)
    return item ~= nil and item:getContainer() ~= nil
end
ApplyRestore.alive = alive

local function reachableNow(inv, playerObj)
    if inv == nil then return false end
    if Transfer.isFloor(inv) then return true end
    local okC, carried = pcall(inv.isInCharacterInventory, inv, playerObj)
    if okC and carried then return true end
    local okP, parent = pcall(inv.getParent, inv)
    if not okP or parent == nil then return true end
    local okS, square = pcall(parent.getSquare, parent)
    if not okS or square == nil then return true end
    if instanceof(parent, "IsoDeadBody") then return true end
    if instanceof(parent, "BaseVehicle") then
        if playerObj:getVehicle() == parent then return true end
        if playerObj:getVehicle() ~= nil then return false end
        local okV, part = pcall(inv.getVehiclePart, inv)
        if okV and part ~= nil and part.getArea ~= nil and part:getArea() ~= nil then
            local veh = part:getVehicle()
            local okA, can = pcall(veh.canAccessContainer, veh, part:getIndex(), playerObj)
            return okA and can == true
        end
        return false
    end
    local okV, part = pcall(inv.getVehiclePart, inv)
    if okV and part ~= nil then return false end
    local mine = playerObj:getCurrentSquare()
    if mine == nil then return false end
    local okD, dist = pcall(square.DistToProper, square, mine)
    return okD and type(dist) == "number" and dist < 2
end
ApplyRestore.reachableNow = reachableNow

local function restore(plan)
    local playerObj = getSpecificPlayer(plan.playerNum)
    if playerObj == nil then return end
    local playerNum = plan.playerNum
    local mainInv = playerObj:getInventory()
    local primaryBefore = resolveItem(plan.primaryId, playerObj, nil)
    local secondaryBefore = resolveItem(plan.secondaryId, playerObj, nil)
    local primaryNow = playerObj:getPrimaryHandItem()
    local secondaryNow = playerObj:getSecondaryHandItem()
    local function wasInHand(item)
        return item ~= nil and (item == primaryBefore or item == secondaryBefore)
    end

    for i = 1, #plan.targets do
        local tracked = plan.targets[i]
        if alive(resolveItem(tracked.id, playerObj, tracked.inventory)) then
            claimHome(tracked, playerObj)
        else
            releaseHome(tracked, playerObj)
        end
    end

    if primaryNow ~= nil and not wasInHand(primaryNow) and alive(primaryNow) then
        ISInventoryPaneContextMenu.unequipItem(primaryNow, playerNum)
    end
    if secondaryNow ~= nil and secondaryNow ~= primaryNow
            and not wasInHand(secondaryNow) and alive(secondaryNow) then
        ISInventoryPaneContextMenu.unequipItem(secondaryNow, playerNum)
    end

    if alive(primaryBefore) and primaryBefore ~= primaryNow then
        if primaryBefore == secondaryBefore then
            ISInventoryPaneContextMenu.equipWeapon(primaryBefore, true, true,
                playerNum)
        else
            ISInventoryPaneContextMenu.equipWeapon(primaryBefore, true, false,
                playerNum)
        end
    end
    if alive(secondaryBefore) and secondaryBefore ~= primaryBefore
            and secondaryBefore ~= secondaryNow then
        ISInventoryPaneContextMenu.equipWeapon(secondaryBefore, false, false,
            playerNum)
    end

    if Transfer ~= nil then
        for i = 1, #plan.targets do
            local tracked = plan.targets[i]
            local item = resolveItem(tracked.id, playerObj, tracked.inventory)
            if alive(item) and item:getContainer() ~= tracked.inventory
                    and tracked.inventory ~= mainInv
                    and reachableNow(tracked.inventory, playerObj) then
                Transfer.moveItems({ item }, tracked.inventory, playerObj,
                    tracked.slot, true)
            end
        end
    end
end

local RestoreAction = nil
local function restoreActionClass()
    if RestoreAction ~= nil then return RestoreAction end
    if ISBaseTimedAction == nil or ISBaseTimedAction.derive == nil then
        return nil
    end

    RestoreAction = ISBaseTimedAction:derive(RESTORE_TYPE)
    RestoreAction.isValid = function() return true end
    RestoreAction.waitToStart = function() return false end
    function RestoreAction:update()

        self:forceStop()
    end
    function RestoreAction:start()
        self:beginAddingActions()
        local ok, err = pcall(restore, self.comfyPlan)
        if not ok then
            Log.warn("ItemApply: restore failed: " .. tostring(err))
        end
        self:endAddingActions()
        self:forceComplete()
    end
    function RestoreAction:stop() ISBaseTimedAction.stop(self) end
    function RestoreAction:perform() ISBaseTimedAction.perform(self) end
    function RestoreAction:new(character, plan)
        local action = ISBaseTimedAction.new(self, character)
        action.comfyPlan = plan
        action.maxTime = -1
        action.stopOnWalk = false
        action.stopOnRun = false

        action.stopOnAim = false
        return action
    end
    return RestoreAction
end

function ApplyRestore.queue(plan, playerObj)
    local actionClass = restoreActionClass()
    if actionClass == nil or plan == nil then return end
    ISTimedActionQueue.add(actionClass:new(playerObj, plan))
end

return ApplyRestore
