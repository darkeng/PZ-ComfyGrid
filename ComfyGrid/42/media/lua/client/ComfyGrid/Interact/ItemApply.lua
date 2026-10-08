--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Model/StackRules"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/Interact/ApplyRestore"
require "ComfyGrid/Interact/PourScheduler"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local ItemApply = {}
ComfyGrid.Interact.ItemApply = ItemApply

local Log = ComfyGrid.Core.Log
local VanillaStacks = ComfyGrid.Core.VanillaStacks
local ItemStack = ComfyGrid.Model.ItemStack
local ApplyRestore = ComfyGrid.Interact.ApplyRestore
local PourScheduler = ComfyGrid.Interact.PourScheduler

ItemApply.KIND_FLUID = "fluid"
ItemApply.KIND_AMMO_MAG = "ammoMag"
ItemApply.KIND_AMMO_GUN = "ammoGun"
ItemApply.KIND_MAG_GUN = "magGun"
ItemApply.KIND_PART_GUN = "partGun"
ItemApply.KIND_DRAINABLE = "drainable"

local function fluidOf(item)
    if item.getFluidContainer == nil then return nil end
    local ok, fluidContainer = pcall(item.getFluidContainer, item)
    if ok then return fluidContainer end
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

function ItemApply.classify(src, dst, playerObj, insideStack)
    if src == nil or dst == nil or src == dst then return nil end
    if playerObj == nil then return nil end
    local srcType = src:getFullType()

    if not insideStack and srcType == dst:getFullType() then
        local StackRules = ComfyGrid.Model.StackRules
        if StackRules == nil
                or StackRules.bucketOf(src) == StackRules.bucketOf(dst) then
            return nil
        end
    end

    if srcType == dst:getFullType()
            and src.canConsolidate ~= nil and src:canConsolidate()
            and src.getCurrentUsesFloat ~= nil and dst.getCurrentUsesFloat ~= nil
            and src:getCurrentUsesFloat() > 0 and dst:getCurrentUsesFloat() < 1 then
        return ItemApply.KIND_DRAINABLE
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

local function bringRounds(playerObj, rounds, wanted)
    local moved = 0
    local fromOutside = 0
    for i = 1, #rounds do
        if moved >= wanted then break end
        local round = rounds[i]
        local roundContainer = round ~= nil and round:getContainer() or nil
        if roundContainer ~= nil then
            if not roundContainer:isInCharacterInventory(playerObj) then
                fromOutside = fromOutside + 1
            end
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, round)
            moved = moved + 1
        end
    end
    return moved, fromOutside
end

local function roundsToLoad(playerObj, ammoKey, room, fromOutside)
    local inv = playerObj:getInventory()
    local okC, owned = pcall(inv.getItemCountRecurse, inv, ammoKey)
    if not okC or type(owned) ~= "number" then owned = 0 end
    local roundsToInsert = owned + fromOutside
    if roundsToInsert > room then roundsToInsert = room end
    return roundsToInsert
end

local FluidPairAction = nil
local function fluidPairActionClass()
    if FluidPairAction ~= nil then return FluidPairAction end
    if ISFluidPanelAction == nil or ISFluidPanelAction.derive == nil then
        return nil
    end

    FluidPairAction = ISFluidPanelAction:derive("ISFluidPanelAction")
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
    local actionClass = fluidPairActionClass()
    if actionClass == nil then return false end

    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, from, true)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, to, true)
    local action = actionClass:new(playerObj,
        ISFluidContainer:new(from:getFluidContainer()), ISFluidTransferUI, true)
    action.comfyOther = to
    ISTimedActionQueue.add(action)
    return true
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
    local plan = ApplyRestore.snapshot(dst, playerObj,
        kind == ItemApply.KIND_DRAINABLE and srcItems or nil,
        kind == ItemApply.KIND_PART_GUN)
    local queued = false
    if kind == ItemApply.KIND_DRAINABLE then

        queued = PourScheduler.schedule(srcItems, dst, playerObj)
    elseif kind == ItemApply.KIND_AMMO_MAG then
        local room = dst:getMaxAmmo() - dst:getCurrentAmmoCount()
        if room <= 0 then return false end
        local _, fromOutside = bringRounds(playerObj, srcItems, room)
        local roundsToInsert = roundsToLoad(playerObj, ammoKeyOf(dst), room,
            fromOutside)
        if roundsToInsert <= 0 then return false end
        ISInventoryPaneContextMenu.onLoadBulletsInMagazine(playerObj, dst,
            roundsToInsert)
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
        ApplyRestore.queue(plan, playerObj)
    end
    return queued
end

function ItemApply.tryApply(srcItems, dst, playerObj, insideStack)
    if srcItems == nil or #srcItems == 0 or dst == nil then return false end
    local src = srcItems[1]
    local okC, kind = pcall(ItemApply.classify, src, dst, playerObj, insideStack)
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
    local itemCount = #liveItems
    if itemCount == 0 then return nil end
    local fullType = liveItems[1]:getFullType()
    for i = 2, itemCount do
        if liveItems[i]:getFullType() ~= fullType then return nil end
    end
    return liveItems
end
ItemApply.sameTypeList = sameTypeList

function ItemApply.liveItemsOf(dragged, allowMany)
    if dragged == nil or (#dragged ~= 1 and not allowMany) then return nil end
    local liveItems = {}
    for i = 1, #dragged do
        local entry = dragged[i]
        local items = type(entry) == "table" and entry.items or nil
        if type(items) == "table" then
            local first = VanillaStacks.firstRealIndex(items)
            for j = first, #items do
                local item = items[j]
                if item ~= nil and item:getContainer() ~= nil then
                    liveItems[#liveItems + 1] = item
                end
            end
        elseif instanceof(entry, "InventoryItem") and entry:getContainer() ~= nil then
            liveItems[#liveItems + 1] = entry
        end
    end
    return sameTypeList(liveItems)
end

ItemApply.pourCandidates = PourScheduler.pourCandidates

function ItemApply.pickTarget(stack, inventory, srcItems, front)
    if stack == nil or inventory == nil or srcItems == nil or #srcItems == 0 then
        return front
    end
    if stack.count == nil or stack.count < 2 then return front end
    local src = srcItems[1]
    if src == nil or src.canConsolidate == nil or not src:canConsolidate() then
        return front
    end
    if front ~= nil and front:getFullType() ~= src:getFullType() then return front end
    local payload = {}
    for i = 1, #srcItems do payload[srcItems[i]:getID()] = true end
    local members = ItemStack.getItems(stack, inventory)
    for i = 1, #members do
        local member = members[i]
        if not payload[member:getID()] and member.getCurrentUsesFloat ~= nil
                and member:getCurrentUsesFloat() < 1 then
            return member
        end
    end
    return front
end

local hintList = nil
local hintSrc = nil
local hintMemo = {}
local hintMemoInside = {}

local function resetHints()
    hintList = nil
    hintSrc = nil

    hintMemo = {}
    hintMemoInside = {}
end

function ItemApply.dragSource()
    local DragAndDrop = ComfyGrid.Interact.DragAndDrop
    if DragAndDrop == nil or not DragAndDrop.isDragging() then
        if hintList ~= nil then resetHints() end
        return nil
    end
    local draggedStacks = DragAndDrop.getDraggedStacks()
    if draggedStacks == nil then
        if hintList ~= nil then resetHints() end
        return nil
    end
    if draggedStacks ~= hintList then
        resetHints()
        hintList = draggedStacks

        local items = ItemApply.liveItemsOf(draggedStacks, true)
        hintSrc = items and items[1] or false
    end
    if hintSrc == false then return nil end
    return hintSrc
end

function ItemApply.hintFor(src, dst, playerObj, insideStack)
    if src == nil or dst == nil then return nil end

    local memo = insideStack and hintMemoInside or hintMemo
    local cached = memo[dst]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local ok, kind = pcall(ItemApply.classify, src, dst, playerObj, insideStack)
    if not ok then kind = nil end
    memo[dst] = kind or false
    return kind
end

return ItemApply
