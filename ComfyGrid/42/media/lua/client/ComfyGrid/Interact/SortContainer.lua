--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.7
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Model/SortPlan"
require "ComfyGrid/Model/Persistence"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local SortContainer = {}
ComfyGrid.Interact.SortContainer = SortContainer

local Log = ComfyGrid.Core.Log
local SortPlan = ComfyGrid.Model.SortPlan
local Persistence = ComfyGrid.Model.Persistence

local COOLDOWN_MS = 1000

local lastSortMs = setmetatable({}, { __mode = "k" })

SortContainer.OK        = "ok"
SortContainer.NO_CHANGE = "nochange"
SortContainer.BUSY      = "busy"
SortContainer.FAILED    = "failed"

function SortContainer.run(model)
    if model == nil or model.grid == nil or model.inventory == nil then
        return SortContainer.FAILED
    end
    local grid = model.grid
    local inventory = model.inventory

    if grid.pendingClaims ~= nil then
        return SortContainer.BUSY
    end

    local now = 0
    if type(getTimestampMs) == "function" then
        local okT, t = pcall(getTimestampMs)
        if okT and type(t) == "number" then now = t end
    end
    local last = lastSortMs[inventory]
    if now > 0 and last ~= nil and (now - last) < COOLDOWN_MS then
        return SortContainer.BUSY
    end

    local okMerge, merged = pcall(grid.consolidateLoose, grid)
    if not okMerge then
        Log.warn("SortContainer: consolidateLoose raised: " .. tostring(merged))
        merged = false
    end

    local Settings = ComfyGrid.Settings
    local orderName = Settings ~= nil and Settings.get("SORT_ORDER") or nil

    local function publishMerge()
        if merged ~= true then return end
        if now > 0 then lastSortMs[inventory] = now end
        model.needsImmediateRefresh = true
        pcall(Persistence.queueSync, inventory)
    end

    local okPlan, plan = pcall(SortPlan.build, grid, orderName)
    if not okPlan then
        Log.warn("SortContainer: plan failed: " .. tostring(plan))
        publishMerge()
        return SortContainer.FAILED
    end

    if plan == nil then

        if merged ~= true then
            return SortContainer.NO_CHANGE
        end
        publishMerge()
        return SortContainer.OK
    end

    local okApply, applied = pcall(grid.applyLayout, grid, plan)
    if not okApply then
        Log.warn("SortContainer: applyLayout raised: " .. tostring(applied))
        publishMerge()
        return SortContainer.FAILED
    end
    if applied ~= true then

        publishMerge()
        return SortContainer.FAILED
    end

    if now > 0 then lastSortMs[inventory] = now end

    model.needsImmediateRefresh = true
    pcall(Persistence.queueSync, inventory)
    return SortContainer.OK
end
