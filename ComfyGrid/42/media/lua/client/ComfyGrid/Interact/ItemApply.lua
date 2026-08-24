--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Model/StackRules"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/Interact/Transfer"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local ItemApply = {}
ComfyGrid.Interact.ItemApply = ItemApply

local Log = ComfyGrid.Core.Log
local ItemStack = ComfyGrid.Model.ItemStack
local ContainerModel = ComfyGrid.Model.ContainerModel

ItemApply.KIND_FLUID = "fluid"
ItemApply.KIND_AMMO_MAG = "ammoMag"
ItemApply.KIND_AMMO_GUN = "ammoGun"
ItemApply.KIND_MAG_GUN = "magGun"
ItemApply.KIND_PART_GUN = "partGun"

local function fluidOf(item)
    if item.getFluidContainer == nil then return nil end
    local ok, fc = pcall(item.getFluidContainer, item)
    if ok then return fc end
    return nil
end

local function ammoKeyOf(item)
    if item.getAmmoType == nil then return nil end
    local ok, ammo = pcall(item.getAmmoType, item)
    if not ok or ammo == nil then return nil end
    if ammo.getItemKey == nil then return nil end
    local okK, key = pcall(ammo.getItemKey, ammo)
    if okK then return key end
    return nil
end

local function hasRoomForAmmo(item)
    if item.getCurrentAmmoCount == nil or item.getMaxAmmo == nil then
        return false
    end
    return item:getCurrentAmmoCount() < item:getMaxAmmo()
end

local function isFirearm(item)
    return instanceof(item, "HandWeapon") and item.getAmmoType ~= nil
        and ammoKeyOf(item) ~= nil
end

local function partFits(part, weapon, playerObj)
    if not instanceof(part, "WeaponPart") then return false end
    if part.isBroken ~= nil and part:isBroken() then return false end
    if part.canAttach == nil or weapon.getWeaponPart == nil then return false end
    local ok, can = pcall(part.canAttach, part, playerObj, weapon)
    if not ok or not can then return false end
    local okP, mounted = pcall(weapon.getWeaponPart, weapon, part:getPartType())
    return okP and mounted == nil
end

function ItemApply.classify(src, dst, playerObj)
    if src == nil or dst == nil or src == dst then return nil end
    if playerObj == nil then return nil end

    local srcType = src:getFullType()
    if srcType == dst:getFullType() then
        local StackRules = ComfyGrid.Model.StackRules
        if StackRules == nil
                or StackRules.bucketOf(src) == StackRules.bucketOf(dst) then
            return nil
        end
    end

    if instanceof(dst, "HandWeapon") then
        local magType = dst.getMagazineType ~= nil and dst:getMagazineType() or nil
        local firearm = (magType ~= nil and magType ~= "") or isFirearm(dst)
        if magType ~= nil and magType ~= "" then
            if srcType == magType then
                return ItemApply.KIND_MAG_GUN
            end
        elseif firearm then

            if ammoKeyOf(dst) == srcType and hasRoomForAmmo(dst) then
                return ItemApply.KIND_AMMO_GUN
            end
        end
        if partFits(src, dst, playerObj) then
            return ItemApply.KIND_PART_GUN
        end
        if firearm then return nil end
    else

        local dstAmmo = ammoKeyOf(dst)
        if dstAmmo ~= nil then
            if dstAmmo == srcType and hasRoomForAmmo(dst) then
                return ItemApply.KIND_AMMO_MAG
            end
            return nil
        end
    end

    local srcFc = fluidOf(src)
    local dstFc = fluidOf(dst)
    if srcFc ~= nil and dstFc ~= nil then
        if srcFc.canPlayerEmpty ~= nil and not srcFc:canPlayerEmpty() then
            return nil
        end
        if dstFc.canPlayerEmpty ~= nil and not dstFc:canPlayerEmpty() then
            return nil
        end
        if srcFc:isEmpty() and dstFc:isEmpty() then return nil end

        local receiver = srcFc:isEmpty() and srcFc or dstFc
        if receiver.isFull ~= nil and receiver:isFull() then return nil end
        return ItemApply.KIND_FLUID
    end
    return nil
end

local function transferIfNeeded(playerObj, item)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
end

local function bringRounds(playerObj, rounds, wanted)
    local moved = 0
    local fromOutside = 0
    for i = 1, #rounds do
        if moved >= wanted then break end
        local r = rounds[i]
        local c = r ~= nil and r:getContainer() or nil
        if c ~= nil then
            if not c:isInCharacterInventory(playerObj) then
                fromOutside = fromOutside + 1
            end
            transferIfNeeded(playerObj, r)
            moved = moved + 1
        end
    end
    return moved, fromOutside
end

local function roundsToLoad(playerObj, ammoKey, room, fromOutside)
    local inv = playerObj:getInventory()
    local okC, owned = pcall(inv.getItemCountRecurse, inv, ammoKey)
    if not okC or type(owned) ~= "number" then owned = 0 end
    local n = owned + fromOutside
    if n > room then n = room end
    return n
end

local FluidPairAction = nil
local function fluidPairActionClass()
    if FluidPairAction ~= nil then return FluidPairAction end
    if ISFluidPanelAction == nil or ISFluidPanelAction.derive == nil then
        return nil
    end
    FluidPairAction = ISFluidPanelAction:derive("ComfyFluidPairAction")
    function FluidPairAction:perform()
        ISFluidPanelAction.perform(self)
        local ok, err = pcall(function()
            local playerNum = self.character:getPlayerNum()
            local slot = ISFluidTransferUI.players
                and ISFluidTransferUI.players[playerNum]
            local ui = slot and slot.instance
            local other = self.comfyOther
            if ui == nil or other == nil or ui.panelRight == nil then return end
            if other:getContainer() == nil then return end
            if ui.panelRight:verifyItem(other) then
                ui.panelRight:addItemAux(other)
            end
        end)
        if not ok then
            Log.warn("ItemApply: seating the fluid target failed: " .. tostring(err))
        end
    end
    return FluidPairAction
end

local function performFluid(src, dst, playerObj)
    local srcFc = fluidOf(src)
    local dstFc = fluidOf(dst)
    if srcFc == nil or dstFc == nil then return false end

    local from, to = src, dst
    if srcFc:isEmpty() and not dstFc:isEmpty() then
        from, to = dst, src
    end
    local cls = fluidPairActionClass()
    if cls == nil then return false end

    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, from, true)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, to, true)
    local action = cls:new(playerObj, ISFluidContainer:new(from:getFluidContainer()),
        ISFluidTransferUI, true)
    action.comfyOther = to
    ISTimedActionQueue.add(action)
    return true
end

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
    local list = nil
    local okQ, queue = pcall(ISTimedActionQueue.getTimedActionQueue, playerObj)
    if not okQ or queue == nil or type(queue.queue) ~= "table" then return nil end
    for i = 1, #queue.queue do
        local a = queue.queue[i]
        if type(a) == "table" and a.Type == RESTORE_TYPE and a.comfyPlan ~= nil then
            list = list or {}
            list[#list + 1] = a
        end
    end
    return list
end

local function claimHome(t, playerObj)
    if t.slot == nil then return end
    local mainInv = playerObj:getInventory()
    if t.inventory ~= mainInv then return end
    local ok, model = pcall(ContainerModel.getOrCreate, mainInv, playerObj:getPlayerNum())
    if ok and model ~= nil and model.grid ~= nil
            and model.grid.claimSlotForItem ~= nil then
        model.grid:claimSlotForItem(t.id, t.slot)
    end
end

local function snapshot(kind, dst, playerObj)
    local playerNum = playerObj:getPlayerNum()
    local p, s = playerObj:getPrimaryHandItem(), playerObj:getSecondaryHandItem()
    local plan = {
        playerNum = playerNum,
        primaryId = p ~= nil and p:getID() or nil,
        secondaryId = s ~= nil and s:getID() or nil,
        targets = {},
    }
    local pending = pendingRestores(playerObj)
    if pending ~= nil then
        local first = pending[1].comfyPlan
        plan.primaryId = first.primaryId
        plan.secondaryId = first.secondaryId
    end
    if not playerObj:isEquipped(dst) then
        local o = originOf(dst, playerNum)
        if o ~= nil then plan.targets[#plan.targets + 1] = o end
    end
    if kind == ItemApply.KIND_PART_GUN then
        local inv = playerObj:getInventory()
        local okS, tool = pcall(inv.getFirstTagEvalRecurse, inv,
            ItemTag.SCREWDRIVER, predicateNotBroken)
        if okS and tool ~= nil and not playerObj:isEquipped(tool) then
            local o = originOf(tool, playerNum)
            if o ~= nil then plan.targets[#plan.targets + 1] = o end
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

local function alive(item)
    return item ~= nil and item:getContainer() ~= nil
end

local function reachableNow(inv, playerObj)
    if inv == nil then return false end
    local okT, t = pcall(inv.getType, inv)
    if okT and t == "floor" then return true end
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

local function restore(plan)
    local playerObj = getSpecificPlayer(plan.playerNum)
    if playerObj == nil then return end
    local playerNum = plan.playerNum
    local mainInv = playerObj:getInventory()
    local p0 = resolveItem(plan.primaryId, playerObj, nil)
    local s0 = resolveItem(plan.secondaryId, playerObj, nil)
    local p1 = playerObj:getPrimaryHandItem()
    local s1 = playerObj:getSecondaryHandItem()
    local function wasInHand(item)
        return item ~= nil and (item == p0 or item == s0)
    end

    for i = 1, #plan.targets do
        claimHome(plan.targets[i], playerObj)
    end

    if p1 ~= nil and not wasInHand(p1) and alive(p1) then
        ISInventoryPaneContextMenu.unequipItem(p1, playerNum)
    end
    if s1 ~= nil and s1 ~= p1 and not wasInHand(s1) and alive(s1) then
        ISInventoryPaneContextMenu.unequipItem(s1, playerNum)
    end

    if alive(p0) and p0 ~= p1 then
        if p0 == s0 then
            ISInventoryPaneContextMenu.equipWeapon(p0, true, true, playerNum)
        else
            ISInventoryPaneContextMenu.equipWeapon(p0, true, false, playerNum)
        end
    end
    if alive(s0) and s0 ~= p0 and s0 ~= s1 then
        ISInventoryPaneContextMenu.equipWeapon(s0, false, false, playerNum)
    end

    local Transfer = ComfyGrid.Interact.Transfer
    if Transfer ~= nil then
        for i = 1, #plan.targets do
            local t = plan.targets[i]
            local item = resolveItem(t.id, playerObj, t.inventory)
            if alive(item) and item:getContainer() ~= t.inventory
                    and t.inventory ~= mainInv
                    and reachableNow(t.inventory, playerObj) then
                Transfer.moveItems({ item }, t.inventory, playerObj, t.slot, true)
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
        local o = ISBaseTimedAction.new(self, character)
        o.comfyPlan = plan
        o.maxTime = -1
        o.stopOnWalk = false
        o.stopOnRun = false

        o.stopOnAim = false
        return o
    end
    return RestoreAction
end

local function queueRestore(plan, playerObj)
    local cls = restoreActionClass()
    if cls == nil or plan == nil then return end
    ISTimedActionQueue.add(cls:new(playerObj, plan))
end

function ItemApply.perform(kind, srcItems, dst, playerObj)
    if kind == nil or srcItems == nil or #srcItems == 0 or dst == nil
            or playerObj == nil then
        return false
    end
    local src = srcItems[1]
    if kind == ItemApply.KIND_FLUID then
        return performFluid(src, dst, playerObj)
    end
    local plan = snapshot(kind, dst, playerObj)
    local queued = false
    if kind == ItemApply.KIND_AMMO_MAG then
        local room = dst:getMaxAmmo() - dst:getCurrentAmmoCount()
        if room <= 0 then return false end
        local _, fromOutside = bringRounds(playerObj, srcItems, room)
        local n = roundsToLoad(playerObj, ammoKeyOf(dst), room, fromOutside)
        if n <= 0 then return false end
        ISInventoryPaneContextMenu.onLoadBulletsInMagazine(playerObj, dst, n)
        queued = true
    elseif kind == ItemApply.KIND_AMMO_GUN then
        local room = dst:getMaxAmmo() - dst:getCurrentAmmoCount()
        if room <= 0 then return false end
        bringRounds(playerObj, srcItems, room)

        ISInventoryPaneContextMenu.onLoadBulletsIntoFirearm(playerObj, dst)
        queued = true
    elseif kind == ItemApply.KIND_MAG_GUN then

        if dst.isContainsClip ~= nil and dst:isContainsClip() then
            ISInventoryPaneContextMenu.onEjectMagazine(playerObj, dst)
        end
        ISInventoryPaneContextMenu.onInsertMagazine(playerObj, dst, src)
        queued = true
    elseif kind == ItemApply.KIND_PART_GUN then
        ISInventoryPaneContextMenu.onUpgradeWeapon(dst, src, playerObj)
        queued = true
    end
    if queued then
        queueRestore(plan, playerObj)
    end
    return queued
end

function ItemApply.tryApply(srcItems, dst, playerObj)
    if srcItems == nil or #srcItems == 0 or dst == nil then return false end
    local src = srcItems[1]
    local okC, kind = pcall(ItemApply.classify, src, dst, playerObj)
    if not okC then
        Log.warn("ItemApply: classify failed: " .. tostring(kind))
        return false
    end
    if kind == nil then return false end
    local okP, done = pcall(ItemApply.perform, kind, srcItems, dst, playerObj)
    if not okP then
        Log.warn("ItemApply: " .. tostring(kind) .. " failed: " .. tostring(done))
        return false
    end
    return done == true
end

local function sameTypeList(liveItems)
    local n = #liveItems
    if n == 0 then return nil end
    local t = liveItems[1]:getFullType()
    for i = 2, n do
        if liveItems[i]:getFullType() ~= t then return nil end
    end
    return liveItems
end
ItemApply.sameTypeList = sameTypeList

function ItemApply.liveItemsOf(dragged)
    if dragged == nil or #dragged ~= 1 then return nil end
    local list = {}
    for i = 1, #dragged do
        local entry = dragged[i]
        local items = type(entry) == "table" and entry.items or nil
        if type(items) == "table" then
            local first = (#items >= 2) and 2 or 1
            for j = first, #items do
                local item = items[j]
                if item ~= nil and item:getContainer() ~= nil then
                    list[#list + 1] = item
                end
            end
        elseif instanceof(entry, "InventoryItem") and entry:getContainer() ~= nil then
            list[#list + 1] = entry
        end
    end
    return sameTypeList(list)
end

local hintList = nil
local hintSrc = nil
local hintMemo = {}

local function resetHints()
    hintList = nil
    hintSrc = nil

    hintMemo = {}
end

function ItemApply.dragSource()
    local DragAndDrop = ComfyGrid.Interact.DragAndDrop
    if DragAndDrop == nil or not DragAndDrop.isDragging() then
        if hintList ~= nil then resetHints() end
        return nil
    end
    local list = DragAndDrop.getDraggedStacks()
    if list == nil then
        if hintList ~= nil then resetHints() end
        return nil
    end
    if list ~= hintList then
        resetHints()
        hintList = list
        local items = ItemApply.liveItemsOf(list)
        hintSrc = items and items[1] or false
    end
    if hintSrc == false then return nil end
    return hintSrc
end

function ItemApply.hintFor(src, dst, playerObj)
    if src == nil or dst == nil then return nil end
    local cached = hintMemo[dst]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local ok, kind = pcall(ItemApply.classify, src, dst, playerObj)
    if not ok then kind = nil end
    hintMemo[dst] = kind or false
    return kind
end

return ItemApply
