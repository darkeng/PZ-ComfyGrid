--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.8
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
    local og = class.shouldBeVisible
    class.shouldBeVisible = function(self)
        if drawing then return false end
        return og(self)
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
    local list = ISLootWindowContainerControls_HandlerList
    if type(list) ~= "table" then return 0 end
    local n = 0
    for i = 1, #list do
        local class = list[i]
        if class ~= nil and class.displayToRight then
            if mute(class) then n = n + 1 end
        end
    end
    rightScanned = #list
    return n
end

local function wrapArrange(class, pageOf)
    if class == nil or class.arrange == nil then return false end
    local og_arrange = class.arrange
    function class:arrange()
        local was = drawing
        drawing = comfyMode(pageOf(self))

        local list = ISLootWindowContainerControls_HandlerList
        if type(list) == "table" and #list ~= rightScanned then
            muteObjectVerbs()
        end

        local ok, err = pcall(og_arrange, self)
        drawing = was
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
    local a = wrapArrange(ISInventoryWindowContainerControls,
        function(self) return self.inventoryWindow end)
    local b = wrapArrange(ISLootWindowContainerControls,
        function(self) return self.lootWindow end)

    Log.info("ControlsStripPatch applied (" .. tostring(muted)
        .. " transfer + " .. tostring(objects) .. " object verbs muted"
        .. ", strips: " .. tostring(a) .. "/" .. tostring(b) .. ")")
end)
