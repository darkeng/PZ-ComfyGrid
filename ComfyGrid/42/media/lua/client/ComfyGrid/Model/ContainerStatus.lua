--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ContainerStatus = {}
ComfyGrid.Model.ContainerStatus = ContainerStatus

local REFRESH_MS = 1000

local cache = setmetatable({}, { __mode = "k" })

local function fireStatus(parent)
    if parent == nil then return nil end
    local okSq, square = pcall(parent.getSquare, parent)
    if not okSq or square == nil then return nil end

    if CCampfireSystem ~= nil and CCampfireSystem.instance ~= nil then
        local okC, campfire = pcall(
            CCampfireSystem.instance.getLuaObjectOnSquare,
            CCampfireSystem.instance, square)
        if okC and campfire ~= nil and campfire.fuelAmt ~= nil then
            local okT, txt = pcall(ISCampingMenu.timeString,
                luautils.round(campfire.fuelAmt))
            if okT and txt ~= nil then return txt end
            return nil
        end
    end

    local okF, isFire = pcall(parent.isFireInteractionObject, parent)
    if not okF or not isFire then return nil end

    local okB, isBBQ = pcall(parent.isPropaneBBQ, parent)
    if okB and isBBQ then
        local okT, hasTank = pcall(parent.hasPropaneTank, parent)
        if okT and not hasTank then
            return getText("IGUI_BBQ_NeedsPropaneTank")
        end
    end
    local okA, amount = pcall(parent.getFuelAmount, parent)
    if not okA or amount == nil then return nil end
    local okT, txt = pcall(ISCampingMenu.timeString, amount)
    return okT and txt or nil
end

local function compute(inventory)
    local parts = nil
    local okP, parent = pcall(inventory.getParent, inventory)
    if okP and parent ~= nil then
        local fire = fireStatus(parent)
        if fire ~= nil then parts = fire end
    end

    local okO, occupied = pcall(inventory.isOccupiedVehicleSeat, inventory)
    if okO and occupied then
        local note = getText("IGUI_invpage_Occupied")
        parts = parts ~= nil and (parts .. " " .. note) or note
    end
    return parts
end

function ContainerStatus.of(inventory)
    if inventory == nil then return nil end
    local now = getTimestampMs ~= nil and getTimestampMs() or 0
    local entry = cache[inventory]
    if entry ~= nil and now - entry.stamp < REFRESH_MS then
        return entry.text
    end
    local ok, text = pcall(compute, inventory)
    if not ok then text = nil end
    cache[inventory] = { stamp = now, text = text }
    return text
end
