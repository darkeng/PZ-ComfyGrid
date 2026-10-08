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
ComfyGrid.Interact = ComfyGrid.Interact or {}
local ObjectVerbs = {}
ComfyGrid.Interact.ObjectVerbs = ObjectVerbs

local Log = ComfyGrid.Core.Log

local REFRESH_MS = 500

local SKIP_TYPES = {
    floor = true,
    inventorymale = true,
    inventoryfemale = true,
}

local turnOffLabel = nil
local function offLabel()
    if turnOffLabel == nil then
        local ok, turnOffText = pcall(getText, "ContextMenu_Turn_Off")
        turnOffLabel = (ok and turnOffText) or false
    end
    return turnOffLabel
end

local anchor = { _x = 0, _y = 0, _h = 0 }
function anchor:getX() return self._x end
function anchor:getY() return self._y end
function anchor:getHeight() return self._h end

local function objectFor(inventory)
    local okT, containerType = pcall(inventory.getType, inventory)
    if okT and containerType ~= nil and SKIP_TYPES[containerType] then
        return nil
    end

    local okO, outermost = pcall(inventory.getOutermostContainer, inventory)
    if okO and outermost ~= nil then
        local okP, part = pcall(outermost.getVehiclePart, outermost)
        if okP and part ~= nil then
            local okV, vehicle = pcall(part.getVehicle, part)
            if okV and vehicle ~= nil then return vehicle end
        end
    end

    local okI, item = pcall(inventory.getContainingItem, inventory)
    if okI and item ~= nil then
        local okW, world = pcall(item.getWorldItem, item)
        if okW then return world end
        return nil
    end

    local okPa, parent = pcall(inventory.getParent, inventory)
    if okPa then return parent end
    return nil
end

local MAX_ENTRIES = 128
local cache = {}
local entryCount = 0

local function entryFor(inventory)
    local entry = cache[inventory]
    if entry == nil then
        if entryCount >= MAX_ENTRIES then
            cache = {}
            entryCount = 0
        end
        entry = { stamp = -1, list = {}, handlers = {}, slots = {} }
        cache[inventory] = entry
        entryCount = entryCount + 1
    end
    return entry
end

function ObjectVerbs.cachedCount()
    return entryCount, MAX_ENTRIES
end

local function handlerFor(entry, class, object, inventory, playerObj, playerNum)
    local handler = entry.handlers[class]
    if handler == false then return nil end
    if handler == nil then
        local ok, made = pcall(class.new, class)
        if not ok or made == nil then
            Log.warn("ObjectVerbs: cannot instantiate "
                .. tostring(class.Type))

            entry.handlers[class] = false
            return nil
        end
        handler = made
        entry.handlers[class] = handler
    end

    handler.object = object
    handler.container = inventory
    handler.playerObj = playerObj
    handler.playerNum = playerNum
    handler.lootWindow = anchor
    return handler
end

local function slotFor(entry, class)
    local verbSlot = entry.slots[class]
    if verbSlot == nil then
        verbSlot = {}
        entry.slots[class] = verbSlot
    end
    return verbSlot
end

local function rebuild(entry, inventory, playerNum)
    local verbs = entry.list
    for i = #verbs, 1, -1 do verbs[i] = nil end

    local classes = ISLootWindowContainerControls_HandlerList
    if type(classes) ~= "table" then return verbs end
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil then return verbs end
    local object = objectFor(inventory)

    if object == nil then return verbs end

    local turnOffLabelText = offLabel()
    for i = 1, #classes do
        local class = classes[i]

        if class ~= nil and class.displayToRight then
            local handler = handlerFor(entry, class, object, inventory,
                playerObj, playerNum)
            if handler ~= nil then
                local okV, visible = pcall(handler.shouldBeVisible, handler)
                if okV and visible then

                    local label = nil
                    local okC, control = pcall(handler.getControl, handler)
                    if okC and control ~= nil then
                        local okL, title = pcall(control.getTitle, control)
                        label = okL and title or nil
                    end
                    if label ~= nil then
                        local verbSlot = slotFor(entry, class)
                        verbSlot.key = class.Type
                        verbSlot.label = label
                        verbSlot.active = turnOffLabelText ~= false
                            and label == turnOffLabelText
                        verbSlot.handler = handler
                        verbs[#verbs + 1] = verbSlot
                    end
                end
            end
        end
    end
    return verbs
end

local TYPE_PREFIX = "ISLootWindowObjectControlHandler_"
local GLYPH = {}
for short, glyph in pairs({
    StoveToggle                   = "power",
    ClothingWasherToggle          = "power",
    ClothingDryerToggle           = "power",
    CombinationWasherDryerToggle  = "power",
    PropaneBarbecueToggle         = "power",
    StoveSettings                 = "dial",
    CombinationWasherDryerSetMode = "dial",
    LightFireOption               = "flame",
    PutOut                        = "douse",
    AddFuelOption                 = "fuel",
    PropaneBarbecueAddTank        = "tank",
    PropaneBarbecueRemoveTank     = "tank",
    MannequinWearAll              = "mannequin",

    MannequinSwitchOutfit         = "swap",
    VehicleLockTrunk              = "lock",
    VehicleCloseTrunk             = "close",
    RemoveCampfire                = "dismantle",

}) do
    GLYPH[TYPE_PREFIX .. short] = glyph
end

function ObjectVerbs.glyphFor(key)
    if key == nil then return nil end
    return GLYPH[key]
end

function ObjectVerbs.of(inventory, playerNum)
    if inventory == nil or playerNum == nil then return nil end
    local entry = entryFor(inventory)
    local now = getTimestampMs ~= nil and getTimestampMs() or 0
    if now - entry.stamp >= REFRESH_MS then
        entry.stamp = now
        local ok, err = pcall(rebuild, entry, inventory, playerNum)
        if not ok then
            Log.warn("ObjectVerbs: rebuild failed: " .. tostring(err))
            for i = #entry.list, 1, -1 do entry.list[i] = nil end
        end
    end
    if #entry.list == 0 then return nil end
    return entry.list
end

function ObjectVerbs.perform(entry, absX, absY, absH)
    if entry == nil or entry.handler == nil then return false end
    anchor._x = absX or 0
    anchor._y = absY or 0
    anchor._h = absH or 0
    local ok, err = pcall(entry.handler.perform, entry.handler)
    if not ok then
        Log.warn("ObjectVerbs: " .. tostring(entry.key) .. " failed: "
            .. tostring(err))
        return false
    end
    return true
end

function ObjectVerbs.fillMenu(verbs, context)
    if verbs == nil or context == nil then return 0 end
    local askedCount = 0
    for i = 1, #verbs do
        local handler = verbs[i].handler
        if handler ~= nil and handler.handleJoypadContextMenu ~= nil then
            local ok, err = pcall(handler.handleJoypadContextMenu, handler,
                context)
            if ok then
                askedCount = askedCount + 1
            else
                Log.warn("ObjectVerbs: menu entry " .. tostring(verbs[i].key)
                    .. " failed: " .. tostring(err))
            end
        end
    end
    return askedCount
end
