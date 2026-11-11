--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Core/Notify"
require "ComfyGrid/Settings"
require "ComfyGrid/Interact/FishingRig"
require "ComfyGrid/Interact/ItemApply"
require "ComfyGrid/Interact/TransferJobs"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local Rebait = {}
ComfyGrid.Interact.Rebait = Rebait

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local Notify = ComfyGrid.Core.Notify
local Settings = ComfyGrid.Settings
local FishingRig = ComfyGrid.Interact.FishingRig
local TransferJobs = ComfyGrid.Interact.TransferJobs

local seenBait = {}

local pending = {}

local handSeen, handIsRod = {}, {}

local function enabled()
    return Settings.get("AUTO_REBAIT") == true
end

function Rebait.noteLost(playerObj, rodId, lure)
    if playerObj == nil or not enabled() then return end
    if playerObj.isLocalPlayer ~= nil and not playerObj:isLocalPlayer() then return end
    local playerNum = playerObj:getPlayerNum()
    local seen = seenBait[playerNum]
    if lure == nil and seen ~= nil and seen.rodId == rodId then lure = seen.lure end
    if lure == nil then return end
    pending[playerNum] = { rodId = rodId, lure = lure }
end

function Rebait._onPlayerUpdate(playerObj)
    if not enabled() then return end
    local playerNum = playerObj:getPlayerNum()
    local hand = playerObj:getPrimaryHandItem()
    if hand ~= handSeen[playerNum] then
        handSeen[playerNum] = hand
        handIsRod[playerNum] = hand ~= nil and FishingRig.isRod(hand)
    end
    if not handIsRod[playerNum] then
        pending[playerNum] = nil
        return
    end
    local rod = hand
    local rodId = rod:getID()
    local lure = rod:getModData().fishing_Lure
    if lure ~= nil then
        local seen = seenBait[playerNum]
        if seen == nil then
            seen = {}
            seenBait[playerNum] = seen
        end
        seen.rodId, seen.lure = rodId, lure

        pending[playerNum] = nil
        return
    end
    local want = pending[playerNum]
    if want == nil then return end
    if want.rodId ~= rodId then
        pending[playerNum] = nil
        return
    end
    if FishingRig.isCasting(playerObj) then return end
    local actions = TransferJobs.queuedActions(playerObj)
    if actions ~= nil and #actions > 0 then return end
    pending[playerNum] = nil

    if rod:isBroken() then return end

    local inv = playerObj:getInventory()
    local okFind, bait = pcall(inv.getFirstTypeEvalRecurse, inv, want.lure,
        FishingRig.isBait)
    if not okFind or bait == nil then return end
    local ItemApply = ComfyGrid.Interact.ItemApply
    local okRefill, queued = pcall(ItemApply.perform, ItemApply.KIND_BAIT_ROD, { bait },
        rod, playerObj)
    if not okRefill then
        Log.warn("Rebait: refill failed: " .. tostring(queued))
        return
    end
    if queued then
        Notify.say(playerNum, Text.tr("IGUI_ComfyGrid_Rebaiting", "Putting on new bait"))
    end
end

function Rebait._onServerCommand(module, command, args)
    if module ~= "fishing" or command ~= "consumeLure" or type(args) ~= "table" then
        return
    end
    local playerObj = getPlayerByOnlineID(args.playerOnlineId)
    if playerObj == nil then return end
    Rebait.noteLost(playerObj, args.rodId, nil)
end

local function wrapRemoveLure()
    local rodClass = Fishing ~= nil and Fishing.FishingRod or nil
    if rodClass == nil or rodClass.removeLure == nil or rodClass._comfyRebaitWrapped then
        return
    end
    local original = rodClass.removeLure
    rodClass.removeLure = function(self, ...)
        local rodItem = self ~= nil and self.rodItem or nil
        local lure = nil
        if rodItem ~= nil and rodItem:hasModData() then
            lure = rodItem:getModData().fishing_Lure
        end
        local result = original(self, ...)
        if rodItem ~= nil and lure ~= nil and not isServer() then
            local ok, err = pcall(Rebait.noteLost, self.player, rodItem:getID(), lure)
            if not ok then Log.warn("Rebait: noteLost failed: " .. tostring(err)) end
        end
        return result
    end
    rodClass._comfyRebaitWrapped = true
end

if not ComfyGrid._rebaitHooked then
    ComfyGrid._rebaitHooked = true
    Events.OnGameStart.Add(wrapRemoveLure)
    Events.OnServerCommand.Add(function(module, command, args)
        local rebait = ComfyGrid.Interact and ComfyGrid.Interact.Rebait
        if rebait ~= nil then rebait._onServerCommand(module, command, args) end
    end)
    Events.OnPlayerUpdate.Add(function(playerObj)
        local rebait = ComfyGrid.Interact and ComfyGrid.Interact.Rebait
        if rebait ~= nil then rebait._onPlayerUpdate(playerObj) end
    end)
end

return Rebait
