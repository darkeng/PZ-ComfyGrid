--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.1
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
        local ok, s = pcall(getText, "ContextMenu_Turn_Off")
        turnOffLabel = (ok and s) or false
    end
    return turnOffLabel
end

local anchor = { _x = 0, _y = 0, _h = 0 }
function anchor:getX() return self._x end
function anchor:getY() return self._y end
function anchor:getHeight() return self._h end

local function objectFor(inventory)
    local okT, ctype = pcall(inventory.getType, inventory)
    if okT and ctype ~= nil and SKIP_TYPES[ctype] then return nil end

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

local cache = setmetatable({}, { __mode = "k" })

local function entryFor(inventory)
    local e = cache[inventory]
    if e == nil then
        e = { stamp = -1, list = {}, handlers = {}, slots = {} }
        cache[inventory] = e
    end
    return e
end

local function handlerFor(e, class, object, inventory, playerObj, playerNum)
    local h = e.handlers[class]
    if h == false then return nil end
    if h == nil then
        local ok, made = pcall(class.new, class)
        if not ok or made == nil then
            Log.warn("ObjectVerbs: cannot instantiate "
                .. tostring(class.Type))

            e.handlers[class] = false
            return nil
        end
        h = made
        e.handlers[class] = h
    end

    h.object = object
    h.container = inventory
    h.playerObj = playerObj
    h.playerNum = playerNum
    h.lootWindow = anchor
    return h
end

local function slotFor(e, class)
    local s = e.slots[class]
    if s == nil then
        s = {}
        e.slots[class] = s
    end
    return s
end

local function rebuild(e, inventory, playerNum)
    local list = e.list
    for i = #list, 1, -1 do list[i] = nil end

    local classes = ISLootWindowContainerControls_HandlerList
    if type(classes) ~= "table" then return list end
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil then return list end
    local object = objectFor(inventory)

    if object == nil then return list end

    local off = offLabel()
    for i = 1, #classes do
        local class = classes[i]

        if class ~= nil and class.displayToRight then
            local h = handlerFor(e, class, object, inventory, playerObj,
                playerNum)
            if h ~= nil then
                local okV, visible = pcall(h.shouldBeVisible, h)
                if okV and visible then

                    local label = nil
                    local okC, control = pcall(h.getControl, h)
                    if okC and control ~= nil then
                        local okL, title = pcall(control.getTitle, control)
                        label = okL and title or nil
                    end
                    if label ~= nil then
                        local s = slotFor(e, class)
                        s.key = class.Type
                        s.label = label
                        s.active = off ~= false and label == off
                        s.handler = h
                        list[#list + 1] = s
                    end
                end
            end
        end
    end
    return list
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
    local e = entryFor(inventory)
    local now = getTimestampMs ~= nil and getTimestampMs() or 0
    if now - e.stamp >= REFRESH_MS then
        e.stamp = now
        local ok, err = pcall(rebuild, e, inventory, playerNum)
        if not ok then
            Log.warn("ObjectVerbs: rebuild failed: " .. tostring(err))
            for i = #e.list, 1, -1 do e.list[i] = nil end
        end
    end
    if #e.list == 0 then return nil end
    return e.list
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

function ObjectVerbs.fillMenu(list, context)
    if list == nil or context == nil then return 0 end
    local n = 0
    for i = 1, #list do
        local h = list[i].handler
        if h ~= nil and h.handleJoypadContextMenu ~= nil then
            local ok, err = pcall(h.handleJoypadContextMenu, h, context)
            if ok then
                n = n + 1
            else
                Log.warn("ObjectVerbs: menu entry " .. tostring(list[i].key)
                    .. " failed: " .. tostring(err))
            end
        end
    end
    return n
end
