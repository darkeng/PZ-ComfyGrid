--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Patches = ComfyGrid.Patches or {}
local ControlsStripPatch = {}
ComfyGrid.Patches.ControlsStripPatch = ControlsStripPatch

local Log = ComfyGrid.Core.Log

local TRANSFER_HANDLERS = {

    "ISInventoryWindowControlHandler_TransferAll",
    "ISInventoryWindowControlHandler_TransferSameType",
    "ISInventoryWindowControlHandler_TransferSameTypeMultiContainer",

    "ISLootWindowObjectControlHandler_TakeAll",
    "ISLootWindowObjectControlHandler_TakeSameType",
    "ISLootWindowObjectControlHandler_MoveToFloor",
    "ISLootWindowObjectControlHandler_RemoveAll",

    "ISLootWindowFloorControlHandler_TakeAll",
    "ISLootWindowFloorControlHandler_TakeSameType",
}

local rightScanned = 0

local drawing = false

local function comfyMode(page)
    if page == nil then return false end
    local pane = page.inventoryPane
    return pane ~= nil and pane.mode == "comfy"
end

local function mute(class)
    if class == nil or rawget(class, "_comfyMuted") then return false end
    class._comfyMuted = true
    local og_shouldBeVisible = class.shouldBeVisible
    class.shouldBeVisible = function(self)
        if drawing then return false end
        return og_shouldBeVisible(self)
    end
    return true
end

local function muteTransfer()
    local missing = 0
    for i = 1, #TRANSFER_HANDLERS do
        local name = TRANSFER_HANDLERS[i]
        local class = _G[name]
        if class == nil then
            missing = missing + 1
            Log.warn("ControlsStripPatch: no handler class " .. name)
        else
            mute(class)
        end
    end
    return #TRANSFER_HANDLERS - missing
end

local function muteObjectVerbs()
    local handlerList = ISLootWindowContainerControls_HandlerList
    if type(handlerList) ~= "table" then return 0 end
    local mutedCount = 0
    for i = 1, #handlerList do
        local class = handlerList[i]
        if class ~= nil and class.displayToRight then
            if mute(class) then mutedCount = mutedCount + 1 end
        end
    end
    rightScanned = #handlerList
    return mutedCount
end

local function wrapArrange(class, pageOf)
    if class == nil or class.arrange == nil then return false end
    local og_arrange = class.arrange
    function class:arrange()
        local drawingBefore = drawing
        drawing = comfyMode(pageOf(self))

        local handlerList = ISLootWindowContainerControls_HandlerList
        if type(handlerList) == "table" and #handlerList ~= rightScanned then
            muteObjectVerbs()
        end

        local ok, err = pcall(og_arrange, self)
        drawing = drawingBefore
        if not ok then error(err) end
    end
    return true
end

Events.OnGameBoot.Add(function()

    if ISLootWindowContainerControls == nil then
        Log.warn("ControlsStripPatch: no loot controls class, skipped")
        return
    end
    if ISLootWindowContainerControls._comfyPatched then return end
    ISLootWindowContainerControls._comfyPatched = true

    local muted = muteTransfer()
    local objects = muteObjectVerbs()
    local playerStripWrapped = wrapArrange(ISInventoryWindowContainerControls,
        function(self) return self.inventoryWindow end)
    local lootStripWrapped = wrapArrange(ISLootWindowContainerControls,
        function(self) return self.lootWindow end)

    Log.info("ControlsStripPatch applied (" .. tostring(muted)
        .. " transfer + " .. tostring(objects) .. " object verbs muted"
        .. ", strips: " .. tostring(playerStripWrapped) .. "/"
        .. tostring(lootStripWrapped) .. ")")
end)
