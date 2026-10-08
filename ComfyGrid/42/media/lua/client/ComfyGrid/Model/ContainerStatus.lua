--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ContainerStatus = {}
ComfyGrid.Model.ContainerStatus = ContainerStatus

local REFRESH_MS = 1000

local MAX_ENTRIES = 256
local statusByContainer = {}
local entryCount = 0

local function fireStatus(parent)
    if parent == nil then return nil end
    local okSq, square = pcall(parent.getSquare, parent)
    if not okSq or square == nil then return nil end

    if CCampfireSystem ~= nil and CCampfireSystem.instance ~= nil then
        local okCampfire, campfire = pcall(
            CCampfireSystem.instance.getLuaObjectOnSquare,
            CCampfireSystem.instance, square)
        if okCampfire and campfire ~= nil and campfire.fuelAmt ~= nil then
            local okTime, timeText = pcall(ISCampingMenu.timeString,
                luautils.round(campfire.fuelAmt))
            if okTime and timeText ~= nil then return timeText end
            return nil
        end
    end

    local okFire, isFire = pcall(parent.isFireInteractionObject, parent)
    if not okFire or not isFire then return nil end

    local okBBQ, isBBQ = pcall(parent.isPropaneBBQ, parent)
    if okBBQ and isBBQ then
        local okTank, hasTank = pcall(parent.hasPropaneTank, parent)
        if okTank and not hasTank then
            return getText("IGUI_BBQ_NeedsPropaneTank")
        end
    end
    local okAmount, amount = pcall(parent.getFuelAmount, parent)
    if not okAmount or amount == nil then return nil end
    local okFuelTime, fuelTimeText = pcall(ISCampingMenu.timeString, amount)
    return okFuelTime and fuelTimeText or nil
end

local function computeStatus(inventory)
    local statusText = nil
    local okParent, parent = pcall(inventory.getParent, inventory)
    if okParent and parent ~= nil then
        local fire = fireStatus(parent)
        if fire ~= nil then statusText = fire end
    end

    local okOccupied, occupied = pcall(inventory.isOccupiedVehicleSeat, inventory)
    if okOccupied and occupied then
        local note = getText("IGUI_invpage_Occupied")
        statusText = statusText ~= nil and (statusText .. " " .. note) or note
    end
    return statusText
end

function ContainerStatus.of(inventory)
    if inventory == nil then return nil end
    local now = getTimestampMs ~= nil and getTimestampMs() or 0
    local entry = statusByContainer[inventory]
    if entry ~= nil and now - entry.stamp < REFRESH_MS then
        return entry.text
    end
    local ok, text = pcall(computeStatus, inventory)
    if not ok then text = nil end
    if entry == nil then
        if entryCount >= MAX_ENTRIES then
            statusByContainer = {}
            entryCount = 0
        end
        entry = {}
        statusByContainer[inventory] = entry
        entryCount = entryCount + 1
    end

    entry.stamp = now
    entry.text = text
    return text
end

function ContainerStatus.cachedCount()
    return entryCount, MAX_ENTRIES
end
