--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Settings"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Icons"
require "ComfyGrid/UI/StackRenderer"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local TileCache = {}
ComfyGrid.UI.TileCache = TileCache

local Style = ComfyGrid.UI.Style
local Icons = ComfyGrid.UI.Icons
local StackRenderer = ComfyGrid.UI.StackRenderer
local floor = math.floor

TileCache.enabled = true

local BASE_LIFETIME_MS = 80
local RECORD_BUDGET = 12
local MAX_RECORDINGS = 1024
local MAX_ARGS = 10
local GOLDEN_FRACTION = 0.6180339887498949

local NEAREST_FILTER_CALL = "__nearest"

local POSITION_ARG_INDEX = {
    DrawTextureScaledColor = 2,
    DrawTextureScaled = 2,
    DrawTextureScaledAspect = 2,
    DrawTextureIcon = 2,
    DrawTextureIconMask = 3,
    DrawItemIcon = 2,
    DrawText = 3,
    DrawTextCentre = 3,
}

local currentBoardRecordings = {}
local recordingEpoch = 0
local recordingCount = 0
local globalGeneration = 0
local recordingSerial = 0

local replayCount, recordCount, liveCount = 0, 0, 0

function TileCache.stats()
    return replayCount, recordCount, liveCount, globalGeneration, recordingCount
end

local function invalidateAll()
    globalGeneration = globalGeneration + 1
    local Capacity = ComfyGrid.Model and ComfyGrid.Model.Capacity
    if Capacity ~= nil and Capacity.flushWeights ~= nil then Capacity.flushWeights() end
end
Style.onScaleChanged(invalidateAll)
for key in pairs(ComfyGrid.Settings.defaults) do
    ComfyGrid.Settings.onChanged(key, invalidateAll)
end

function TileCache.flush()
    invalidateAll()
end

local recordBudgetLeft = 0
local currentBoardView, currentBoardGeneration, currentBoardChangeCount = nil, 0, 0
local mouseWasDown = false
local menuWasVisible = {}

function TileCache.beginBoard(view, viewGeneration, changeCount)
    recordBudgetLeft = RECORD_BUDGET
    currentBoardView = view
    if view ~= nil then
        local recordings = view.tileRecordings
        if recordings == nil or view.tileRecordingsEpoch ~= recordingEpoch then
            recordings = {}
            view.tileRecordings = recordings
            view.tileRecordingsEpoch = recordingEpoch
        end
        currentBoardRecordings = recordings
    end
    currentBoardGeneration = viewGeneration or 0
    currentBoardChangeCount = changeCount or 0
    local anyButtonDown = isMouseButtonDown(0) or isMouseButtonDown(1)
    if mouseWasDown and not anyButtonDown then invalidateAll() end
    mouseWasDown = anyButtonDown
    local playerNum = view ~= nil and view.playerNum or 0
    local menu = getPlayerContextMenu ~= nil and getPlayerContextMenu(playerNum) or nil
    local menuJavaObject = menu ~= nil and menu.javaObject or nil
    local menuVisible = false
    if menuJavaObject ~= nil and menuJavaObject:isVisible() then menuVisible = true end
    if menuWasVisible[playerNum] and not menuVisible then invalidateAll() end
    menuWasVisible[playerNum] = menuVisible
end

local recordingEntry = nil
local recordingTarget = nil

local function appendCall(recording, methodName, javaMethod, argCount, ...)
    local xArgIndex = POSITION_ARG_INDEX[methodName]
    if xArgIndex == nil or argCount > MAX_ARGS then recording.uncacheable = true return end
    local callIndex = recording.callCount + 1
    local call = recording.calls[callIndex]
    if call == nil then
        call = {}
        recording.calls[callIndex] = call
    end
    call.methodName, call.javaMethod = methodName, javaMethod
    call.argCount, call.xArgIndex = argCount, xArgIndex
    for i = 1, argCount do call[i] = (select(i, ...)) end
    if type(call[xArgIndex]) ~= "number" or type(call[xArgIndex + 1]) ~= "number" then
        recording.uncacheable = true
        return
    end
    recording.callCount = callIndex
end

local recordingProxy = setmetatable({}, { __index = function(proxyTable, methodName)
    local forwarder = function(_, ...)
        local target = recordingTarget
        local javaMethod = target[methodName]
        if recordingEntry ~= nil then
            appendCall(recordingEntry, methodName, javaMethod, select("#", ...), ...)
        end
        return javaMethod(target, ...)
    end
    rawset(proxyTable, methodName, forwarder)
    return forwarder
end })

local function recordNearestFilter(texture)
    local recording = recordingEntry
    if recording == nil then return end
    local callIndex = recording.callCount + 1
    local call = recording.calls[callIndex]
    if call == nil then
        call = {}
        recording.calls[callIndex] = call
    end
    call.methodName, call.javaMethod = NEAREST_FILTER_CALL, nil
    call.argCount, call.xArgIndex = 1, nil
    call[1] = texture
    recording.callCount = callIndex
end

local function recordTile(recording, ctx, view, javaObject, now)
    recording.callCount = 0
    recording.uncacheable = false
    recordingEntry, recordingTarget = recording, javaObject
    view.javaObject = recordingProxy
    StackRenderer.setNearestTap(recordNearestFilter)
    local ok, err = pcall(StackRenderer.draw, ctx)
    view.javaObject = javaObject
    StackRenderer.setNearestTap(nil)
    recordingEntry, recordingTarget = nil, nil
    if not ok then
        recording.uncacheable = true
        error(err, 0)
    end
    local item = ctx.item
    recording.front, recording.count = item, ctx.stack.count
    recording.generation, recording.view = globalGeneration, view
    recording.javaObject = javaObject
    recording.viewGen = currentBoardGeneration
    recording.changeCount = currentBoardChangeCount
    recording.cellSize, recording.player = Style.CELL, ctx.playerNum
    recording.skipWeightMark = ctx.skipWeightMark
    recording.originX, recording.originY = ctx.x, ctx.y

    local fluidContainer = Icons.fluidContainerOf(item)
    recording.fluid = fluidContainer
    recording.fluidAmount = fluidContainer ~= nil and fluidContainer:getAmount() or nil
    recordingSerial = recordingSerial + 1
    recording.expires = now + BASE_LIFETIME_MS
        + floor(((recordingSerial * GOLDEN_FRACTION) % 1) * BASE_LIFETIME_MS)
end

local function isRecordingValid(recording, ctx, view, javaObject, now)
    return not recording.uncacheable and recording.generation == globalGeneration
        and now < recording.expires
        and recording.front == ctx.item and recording.count == ctx.stack.count
        and recording.view == view and recording.javaObject == javaObject
        and recording.viewGen == currentBoardGeneration
        and recording.changeCount == currentBoardChangeCount
        and recording.cellSize == Style.CELL and recording.player == ctx.playerNum
        and recording.skipWeightMark == ctx.skipWeightMark
        and (recording.fluid == nil
            or recording.fluid:getAmount() == recording.fluidAmount)
end

local function replayRecording(recording, javaObject, offsetX, offsetY)
    local calls = recording.calls
    for callIndex = 1, recording.callCount do
        local call = calls[callIndex]
        if call.methodName == NEAREST_FILTER_CALL then
            StackRenderer.applyNearestTo(call[1])
        else
            local xArgIndex = call.xArgIndex
            local x, y = call[xArgIndex], call[xArgIndex + 1]
            if offsetX ~= 0 or offsetY ~= 0 then
                call[xArgIndex], call[xArgIndex + 1] = x + offsetX, y + offsetY
                call.javaMethod(javaObject, unpack(call, 1, call.argCount))
                call[xArgIndex], call[xArgIndex + 1] = x, y
            else
                call.javaMethod(javaObject, unpack(call, 1, call.argCount))
            end
        end
    end
end

function TileCache.draw(ctx, now, live)
    local view = ctx.view
    local stack = ctx.stack
    local javaObject = view ~= nil and view.javaObject or nil
    if not TileCache.enabled or javaObject == nil or stack == nil or ctx.item == nil
            or view ~= currentBoardView then
        liveCount = liveCount + 1
        return StackRenderer.draw(ctx)
    end
    local recording = currentBoardRecordings[stack]
    if recording ~= nil and not live
            and isRecordingValid(recording, ctx, view, javaObject, now) then
        replayCount = replayCount + 1
        replayRecording(recording, javaObject,
            ctx.x - recording.originX, ctx.y - recording.originY)
        return
    end
    if recordBudgetLeft <= 0 then

        if recording ~= nil then recording.expires = 0 end
        liveCount = liveCount + 1
        return StackRenderer.draw(ctx)
    end
    recordBudgetLeft = recordBudgetLeft - 1
    recordCount = recordCount + 1
    if recording == nil then
        if recordingCount >= MAX_RECORDINGS then
            recordingEpoch = recordingEpoch + 1
            recordingCount = 0
            currentBoardRecordings = {}
            view.tileRecordings = currentBoardRecordings
            view.tileRecordingsEpoch = recordingEpoch
        end
        recording = { calls = {}, callCount = 0 }
        currentBoardRecordings[stack] = recording
        recordingCount = recordingCount + 1
    end
    recordTile(recording, ctx, view, javaObject, now)
end
