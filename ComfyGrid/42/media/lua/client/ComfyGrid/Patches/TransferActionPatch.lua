--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.4
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Settings"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/Model/Persistence"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/Interact/TransferJobs"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Patches = ComfyGrid.Patches or {}
local TransferActionPatch = {}
ComfyGrid.Patches.TransferActionPatch = TransferActionPatch

local Log = ComfyGrid.Core.Log

local agingFailLogged = false
local bookkeepFailLogged = false

local function playerNumFor(character)
    if character ~= nil and instanceof(character, "IsoPlayer") then
        return character:getPlayerNum()
    end
    return nil
end

Events.OnGameBoot.Add(function()

    if ISInventoryTransferAction._comfyPatched then return end

    local ContainerModel = ComfyGrid.Model and ComfyGrid.Model.ContainerModel
    local ItemStack = ComfyGrid.Model and ComfyGrid.Model.ItemStack
    local Persistence = ComfyGrid.Model and ComfyGrid.Model.Persistence
    local TransferJobs = ComfyGrid.Interact and ComfyGrid.Interact.TransferJobs
    local Settings = ComfyGrid.Settings
    if not (ContainerModel and ItemStack and Persistence and TransferJobs) then
        Log.error("TransferActionPatch: model modules missing; vanilla transfer action left untouched")
        return
    end
    ISInventoryTransferAction._comfyPatched = true

    function ISInventoryTransferAction:setComfyTarget(slot)
        self.comfySlot = slot
        self.comfyEnforce = true
    end

    local og_new = ISInventoryTransferAction.new
    function ISInventoryTransferAction:new(character, item, srcContainer, destContainer, time, ...)
        local o = og_new(self, character, item, srcContainer, destContainer, time, ...)

        if srcContainer and destContainer and not isClient()
                and Settings and Settings.get("INSTANT_TRANSFER") then
            o.maxTime = 0
            o.stopOnWalk = false
            o.stopOnRun = false
        end
        return o
    end

    local og_canMergeAction = ISInventoryTransferAction.canMergeAction
    function ISInventoryTransferAction:canMergeAction(action)

        if not og_canMergeAction(self, action) then return false end

        return self.comfySlot == action.comfySlot
    end

    local function ageItem(item)
        item:updateAge()
        if item:IsClothing() then
            item:updateWetness()
        end
    end

    local function parkPendingClaim(action, moved)
        local playerNum = playerNumFor(action.character)
        local destModel = ContainerModel.getOrCreate(action.destContainer, playerNum)
        if destModel == nil or destModel.grid == nil then return end
        if action.comfySlot ~= nil
                and destModel.grid.claimSlotForItem ~= nil then
            destModel.grid:claimSlotForItem(moved:getID(), action.comfySlot)
        end

        destModel.publishOnArrival = { id = moved:getID(), ms = getTimestampMs() }
        destModel.needsImmediateRefresh = true
    end

    local function publishContainerLayout(action, moved)
        if not isClient() then return end

        if moved.getInventory == nil then return end
        local okInv, ownInv = pcall(moved.getInventory, moved)
        if not okInv or ownInv == nil then return end
        local dest = action.destContainer
        if dest == nil then return end

        local okIn, inChar = pcall(dest.isInCharacterInventory, dest,
            action.character)
        if okIn and inChar then return end
        Persistence.queueItemSync(moved)
    end

    local function bookkeepTransfer(action, moved, allowPending)
        if moved == nil then return end
        local okPub, errPub = pcall(publishContainerLayout, action, moved)
        if not okPub and not bookkeepFailLogged then
            bookkeepFailLogged = true
            Log.error("TransferActionPatch: container layout publish failed "
                .. "(logged once): " .. tostring(errPub))
        end

        local okType, destType = pcall(action.destContainer.getType,
            action.destContainer)
        local destIsFloor = okType and tostring(destType) == "floor"
        if destIsFloor then
            if moved:getContainer() == action.srcContainer then
                if allowPending then parkPendingClaim(action, moved) end
                return
            end
        elseif moved:getContainer() ~= action.destContainer then
            if allowPending then parkPendingClaim(action, moved) end
            return
        end
        local playerNum = playerNumFor(action.character)

        local srcModel = ContainerModel.getOrCreate(action.srcContainer, playerNum)
        if srcModel then
            srcModel.grid:removeItem(moved)
            Persistence.queueSync(action.srcContainer)
        end

        local destModel = ContainerModel.getOrCreate(action.destContainer, playerNum)
        if destModel then
            local grid = destModel.grid
            if destIsFloor then

                if action.comfySlot ~= nil then
                    if moved:getContainer() == action.destContainer then

                        grid:removeItem(moved)
                        if not grid:insertItem(moved, action.comfySlot)
                                and grid.claimSlotForItem ~= nil then
                            grid:claimSlotForItem(moved:getID(), action.comfySlot)
                            destModel.needsImmediateRefresh = true
                        end
                    else
                        grid:claimSlotForItem(moved:getID(), action.comfySlot)
                    end
                end
            else

                grid:removeItem(moved)

                if not grid:insertItem(moved, action.comfySlot) then
                    if action.comfySlot ~= nil
                            and grid.claimSlotForItem ~= nil then
                        grid:claimSlotForItem(moved:getID(), action.comfySlot)
                        destModel.needsImmediateRefresh = true
                    else
                        grid:insertItem(moved)
                    end
                end
            end
            Persistence.queueSync(action.destContainer)
        end
    end

    local og_transferItem = ISInventoryTransferAction.transferItem
    function ISInventoryTransferAction:transferItem(item)
        og_transferItem(self, item)

        local ok, err = pcall(ageItem, self.item or item)
        if not ok and not agingFailLogged then
            agingFailLogged = true
            Log.error("TransferActionPatch: JIT aging failed (logged once): "
                .. tostring(err))
        end

        ok, err = pcall(bookkeepTransfer, self, self.item or item, isClient())
        if not ok and not bookkeepFailLogged then
            bookkeepFailLogged = true
            Log.error("TransferActionPatch: grid bookkeeping failed (logged once): "
                .. tostring(err))
        end

        TransferJobs.unregister(self.srcContainer, item)
        if self.item ~= nil and self.item ~= item then
            TransferJobs.unregister(self.srcContainer, self.item)
        end
    end

    local og_perform = ISInventoryTransferAction.perform
    function ISInventoryTransferAction:perform()
        local group = nil
        if isClient() then
            local queueList = self.queueList
            group = type(queueList) == "table" and queueList[1] or nil
        end
        og_perform(self)
        if group == nil then return end
        local items = type(group) == "table" and group.items or nil
        if type(items) ~= "table" then return end
        for i = 1, #items do
            local item = items[i]
            if item ~= nil then

                if item:getContainer() ~= self.srcContainer then
                    local okAge, errAge = pcall(ageItem, item)
                    if not okAge and not agingFailLogged then
                        agingFailLogged = true
                        Log.error("TransferActionPatch: MP JIT aging failed (logged once): "
                            .. tostring(errAge))
                    end
                end
                local ok, err = pcall(bookkeepTransfer, self, item, true)
                if not ok and not bookkeepFailLogged then
                    bookkeepFailLogged = true
                    Log.error("TransferActionPatch: MP grid bookkeeping failed (logged once): "
                        .. tostring(err))
                end
                TransferJobs.unregister(self.srcContainer, item)
            end
        end
    end

    local function clearActionJobs(action)
        TransferJobs.unregister(action.srcContainer, action.item)
        local queueList = action.queueList
        if type(queueList) ~= "table" then return end
        for i = 1, #queueList do
            local group = queueList[i]
            local items = type(group) == "table" and group.items or nil
            if type(items) == "table" then
                for j = 1, #items do
                    TransferJobs.unregister(action.srcContainer, items[j])
                end
            end
        end
    end

    local og_stop = ISInventoryTransferAction.stop
    function ISInventoryTransferAction:stop()
        og_stop(self)
        pcall(clearActionJobs, self)
    end

    local og_forceCancel = ISInventoryTransferAction.forceCancel
    function ISInventoryTransferAction:forceCancel()
        if og_forceCancel ~= nil then og_forceCancel(self) end
        pcall(clearActionJobs, self)
    end

    Log.info("TransferActionPatch applied (ISInventoryTransferAction comfy-aware)")
end)
