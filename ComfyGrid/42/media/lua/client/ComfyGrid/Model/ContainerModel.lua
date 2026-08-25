--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.5
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Model/Persistence"
require "ComfyGrid/Model/SlotGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ContainerModel = {}
ContainerModel.__index = ContainerModel
ComfyGrid.Model.ContainerModel = ContainerModel

local Log = ComfyGrid.Core.Log
local Persistence = ComfyGrid.Model.Persistence
local SlotGrid = ComfyGrid.Model.SlotGrid

local PLAYER_REFRESH_MS = 100
local OTHER_REFRESH_MS = 600

local modelCache = {}
local modelCacheLastAccess = {}
local CACHE_IDLE_EVICT_MS = 10000
local CACHE_SWEEP_MS = 1000
local lastSweepMs = 0

local playerMainModels = {}

local function newModel(inventory, playerNum, isPlayerMain)
    local self = setmetatable({
        inventory = inventory,
        playerNum = playerNum,
        isPlayerMain = isPlayerMain == true,
        grid = SlotGrid:new(inventory, Persistence.gridDataFor(inventory, playerNum), playerNum),

        needsImmediateRefresh = false,
        lastRefreshMs = 0,
    }, ContainerModel)

    self:refresh(true)
    return self
end

function ContainerModel:shouldRefresh()
    if self.needsImmediateRefresh then return true end
    if self.grid.needsMoreReconcile then return true end
    local interval = self.isPlayerMain and PLAYER_REFRESH_MS or OTHER_REFRESH_MS
    return (getTimestampMs() - self.lastRefreshMs) >= interval
end

function ContainerModel:refresh(force)
    if not force and not self:shouldRefresh() then return end

    if isClient() and self.grid.pendingClaims == nil
            and Persistence.resolveSyncOwner(self.inventory) ~= nil then
        local fresh = Persistence.gridDataFor(self.inventory, self.playerNum)
        if fresh ~= nil and fresh ~= self.grid.data then
            self.grid:rebindData(fresh)
        end
    end
    self.grid:validate()
    self.grid:reconcile()
    self.needsImmediateRefresh = false
    self.lastRefreshMs = getTimestampMs()
end

function ContainerModel.getOrCreate(inventory, playerNum)
    if not inventory then return nil end

    local player = playerNum ~= nil and getSpecificPlayer(playerNum) or nil
    if player and player:getInventory() == inventory then
        local mainModel = ContainerModel.getPlayerMain(playerNum)
        if mainModel then return mainModel end
    end
    local model = modelCache[inventory]
    if not model then
        model = newModel(inventory, playerNum, false)
        modelCache[inventory] = model
    else

        model:refresh()
    end
    modelCacheLastAccess[inventory] = getTimestampMs()
    return model
end

function ContainerModel.getPlayerMain(playerNum)
    local player = playerNum ~= nil and getSpecificPlayer(playerNum) or nil
    local inventory = player and player:getInventory() or nil
    if not inventory then return nil end
    local model = playerMainModels[playerNum]
    if not model or model.inventory ~= inventory then
        model = newModel(inventory, playerNum, true)
        playerMainModels[playerNum] = model
    end
    return model
end

local function onTick()
    local now = getTimestampMs()
    if now - lastSweepMs >= CACHE_SWEEP_MS then
        lastSweepMs = now

        for inventory in pairs(modelCache) do
            if now - (modelCacheLastAccess[inventory] or 0) >= CACHE_IDLE_EVICT_MS then
                modelCache[inventory] = nil
                modelCacheLastAccess[inventory] = nil
            end
        end
    end
    for playerNum in pairs(playerMainModels) do

        local model = ContainerModel.getPlayerMain(playerNum)
        if model then
            model:refresh()
        else

            playerMainModels[playerNum] = nil
        end
    end
end

if not ComfyGrid.Model._containerModelTickHooked then
    ComfyGrid.Model._containerModelTickHooked = true
    Events.OnTick.Add(function()

        local ok, err = pcall(onTick)
        if not ok then
            Log.error("ContainerModel tick failed: " .. tostring(err))
        end
    end)
end
