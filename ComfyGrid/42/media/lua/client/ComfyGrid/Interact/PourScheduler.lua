--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Interact/Transfer"
require "ComfyGrid/Interact/ApplyRestore"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local PourScheduler = {}
ComfyGrid.Interact.PourScheduler = PourScheduler

local Log = ComfyGrid.Core.Log
local Transfer = ComfyGrid.Interact.Transfer
local ApplyRestore = ComfyGrid.Interact.ApplyRestore
local resolveItem = ApplyRestore.resolveItem
local alive = ApplyRestore.alive
local reachableNow = ApplyRestore.reachableNow

local ConsolidateOne = nil
local function consolidateOneClass()
    if ConsolidateOne ~= nil then return ConsolidateOne end
    if ISConsolidateDrainable == nil or ISConsolidateDrainable.derive == nil then
        return nil
    end

    ConsolidateOne = ISConsolidateDrainable:derive("ISConsolidateDrainable")
    ConsolidateOne.complete = ISConsolidateDrainable.complete
    function ConsolidateOne:isValid()
        local inv = self.character:getInventory()
        if self.intoItem == nil then return false end
        if isClient() then return inv:containsID(self.intoItem:getID()) end
        return inv:contains(self.intoItem)
    end
    function ConsolidateOne:perform()
        self.intoItem:setJobDelta(0.0)
        if self.drainable ~= nil then self.drainable:setJobDelta(0.0) end
        ISBaseTimedAction.perform(self)
    end
    function ConsolidateOne:new(character, drainable, intoItem)
        local action = ISConsolidateDrainable.new(self, character, drainable,
            intoItem, nil)
        return action
    end
    return ConsolidateOne
end

local PourAction = nil
local function pourActionClass()
    if PourAction ~= nil then return PourAction end
    if ISBaseTimedAction == nil or ISBaseTimedAction.derive == nil then
        return nil
    end
    PourAction = ISBaseTimedAction:derive("ComfyPourAction")
    PourAction.isValid = function() return true end
    PourAction.waitToStart = function() return false end
    function PourAction:update() self:forceStop() end
    function PourAction:stop() ISBaseTimedAction.stop(self) end
    function PourAction:perform() ISBaseTimedAction.perform(self) end
    function PourAction:new(character, plan)
        local action = ISBaseTimedAction.new(self, character)
        action.comfyPour = plan
        action.maxTime = -1
        action.stopOnWalk = false
        action.stopOnRun = false
        action.stopOnAim = false
        return action
    end
    function PourAction:start()
        self:beginAddingActions()
        local ok, err = pcall(function()
            local playerObj = self.character
            local pour = self.comfyPour
            local mainInv = playerObj:getInventory()
            local dst = resolveItem(pour.dstId, playerObj, pour.dstInv)
            if not alive(dst) then return end
            local function bringAndRetry(item)
                ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(
                    playerObj, item, item:getContainer(), mainInv))
                ISTimedActionQueue.add(PourAction:new(playerObj, pour))
            end
            if dst:getContainer() ~= mainInv then
                bringAndRetry(dst)
                return
            end
            if dst:getCurrentUsesFloat() >= 1 then return end

            local src = nil
            while src == nil and #pour.srcIds > 0 do
                local id = table.remove(pour.srcIds, 1)
                local candidate = resolveItem(id, playerObj, pour.srcInv[id])
                if alive(candidate) and candidate ~= dst
                        and candidate.getCurrentUsesFloat ~= nil
                        and candidate:getCurrentUsesFloat() > 0 then
                    src = candidate
                    if src:getContainer() ~= mainInv then

                        table.insert(pour.srcIds, 1, id)
                        bringAndRetry(src)
                        return
                    end
                end
            end
            if src == nil then return end
            local actionClass = consolidateOneClass()
            if actionClass == nil then return end
            ISTimedActionQueue.add(actionClass:new(playerObj, src, dst))
            if #pour.srcIds > 0 then
                ISTimedActionQueue.add(PourAction:new(playerObj, pour))
            end
        end)
        if not ok then
            Log.warn("ItemApply: pour scheduling failed: " .. tostring(err))
        end
        self:endAddingActions()
        self:forceComplete()
    end
    return PourAction
end

function PourScheduler.schedule(srcItems, dst, playerObj)
    if ISConsolidateDrainable == nil or pourActionClass() == nil
            or consolidateOneClass() == nil then
        return false
    end
    local mainInv = playerObj:getInventory()
    local playerNum = playerObj:getPlayerNum()
    local containers, seen = {}, {}
    local function note(item)
        local container = item ~= nil and item:getContainer() or nil
        if container ~= nil and container ~= mainInv and not seen[container] then
            seen[container] = true
            containers[#containers + 1] = container
        end
    end
    note(dst)
    for i = 1, #srcItems do note(srcItems[i]) end
    local farCount = 0
    for i = 1, #containers do
        if not reachableNow(containers[i], playerObj) then
            farCount = farCount + 1
        end
    end
    if farCount > 1 then return false end
    for i = 1, #containers do
        if not luautils.walkToContainer(containers[i], playerNum) then
            return false
        end
    end
    local pour = { dstId = dst:getID(), dstInv = dst:getContainer(),
        srcIds = {}, srcInv = {} }
    for i = 1, #srcItems do
        local sourceItem = srcItems[i]
        if sourceItem ~= nil and sourceItem ~= dst
                and sourceItem:getContainer() ~= nil then
            local id = sourceItem:getID()
            pour.srcIds[#pour.srcIds + 1] = id
            pour.srcInv[id] = sourceItem:getContainer()
        end
    end
    if #pour.srcIds == 0 then return false end
    ISTimedActionQueue.add(PourAction:new(playerObj, pour))
    return true
end

local function collectPourable(container, src, out, seen, skip)
    if container == nil then return end
    local ok, sameTypeItems = pcall(container.getItemsFromType, container,
        src:getType(), true)
    if not ok or sameTypeItems == nil then return end
    local srcType = src:getFullType()
    for i = 0, sameTypeItems:size() - 1 do
        local candidate = sameTypeItems:get(i)
        if candidate ~= nil and candidate ~= src and not seen[candidate]
                and candidate:getFullType() == srcType
                and candidate:getContainer() ~= nil
                and candidate.getCurrentUsesFloat ~= nil
                and candidate:getCurrentUsesFloat() < 1 then
            local skipped = false
            if skip ~= nil then
                for j = 1, #skip do
                    if skip[j] == candidate then skipped = true break end
                end
            end
            if not skipped then
                seen[candidate] = true
                out[#out + 1] = candidate
            end
        end
    end
end

function PourScheduler.pourCandidates(src, playerObj, skip)
    local out = {}
    if src == nil or playerObj == nil then return out end
    if src.canConsolidate == nil or not src:canConsolidate() then return out end
    if src.getCurrentUsesFloat == nil or src:getCurrentUsesFloat() <= 0 then
        return out
    end
    local seen = {}
    collectPourable(playerObj:getInventory(), src, out, seen, skip)
    local okL, loot = pcall(getPlayerLoot, playerObj:getPlayerNum())
    if okL and loot ~= nil and type(loot.backpacks) == "table" then
        for i = 1, #loot.backpacks do
            local container = loot.backpacks[i].inventory

            if not Transfer.isFloor(container) then
                collectPourable(container, src, out, seen, skip)
            end
        end
    end

    table.sort(out, function(a, b)
        return a:getCurrentUsesFloat() > b:getCurrentUsesFloat()
    end)
    return out
end

return PourScheduler
