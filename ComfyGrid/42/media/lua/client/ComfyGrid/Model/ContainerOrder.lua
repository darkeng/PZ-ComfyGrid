--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.9
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Prefs"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ContainerOrder = {}
ComfyGrid.Model.ContainerOrder = ContainerOrder

local Log = ComfyGrid.Core.Log
local Prefs = ComfyGrid.Core.Prefs

local UNPLACED = 100000

ContainerOrder.SELF_KEY = "self"

function ContainerOrder.keyFor(inventory, playerObj)
    if inventory == nil then return nil end
    if playerObj ~= nil then
        local okI, own = pcall(playerObj.getInventory, playerObj)
        if okI and own == inventory then return ContainerOrder.SELF_KEY end
    end
    local okC, item = pcall(inventory.getContainingItem, inventory)
    if not okC or item == nil then return nil end
    local okT, full = pcall(item.getFullType, item)
    if not okT or full == nil then return nil end
    return full
end

local function seedClass(inventory, playerObj)
    if playerObj == nil then return 1 end
    local okI, own = pcall(playerObj.getInventory, playerObj)
    if okI and own == inventory then return 0 end
    if playerObj.isHandItem == nil then return 1 end
    local okC, item = pcall(inventory.getContainingItem, inventory)
    if not okC or item == nil then return 1 end
    local okH, held = pcall(playerObj.isHandItem, playerObj, item)
    if okH and held == true then return 2 end
    return 1
end

function ContainerOrder.isMain(inventory, playerObj)
    return seedClass(inventory, playerObj) == 0
end

function ContainerOrder.isPinned(inventory, playerObj, playerNum)
    if inventory == nil then return false end
    local Settings = ComfyGrid.Settings
    local layout = Settings ~= nil and Settings.get ~= nil
        and Settings.get("PLAYER_LAYOUT") or nil
    if layout ~= "compact" then return false end

    if ContainerOrder.isMain(inventory, playerObj) then return false end
    local Capacity = ComfyGrid.Model and ComfyGrid.Model.Capacity
    local Plan = ComfyGrid.Model and ComfyGrid.Model.SectionPlan
    if Capacity == nil or Plan == nil then return false end
    local ok, slots = pcall(Capacity.slotsFor, inventory, playerNum)
    if not ok or slots == nil then return false end
    return slots <= Plan.POCKET_MAX_SLOTS
end

local memo = {}

local function prefKey(playerNum)
    return "ComfyOrder" .. tostring(playerNum or 0)
end

function ContainerOrder.get(playerNum)
    local list = memo[playerNum or 0]
    if list == nil then
        list = {}
        local raw = Prefs.get(prefKey(playerNum))
        if type(raw) == "string" and raw ~= "" then
            for part in string.gmatch(raw, "[^|]+") do
                list[#list + 1] = part
            end
        end
        memo[playerNum or 0] = list
    end
    return list
end

function ContainerOrder.set(playerNum, keys)
    local copy, seen = {}, {}
    for i = 1, #keys do
        local k = keys[i]

        if type(k) == "string" and k ~= "" and not seen[k] then
            seen[k] = true
            copy[#copy + 1] = k
        end
    end
    memo[playerNum or 0] = copy
    Prefs.set(prefKey(playerNum), table.concat(copy, "|"))
end

function ContainerOrder.clear(playerNum)
    ContainerOrder.set(playerNum, {})
end

local seq = setmetatable({}, { __mode = "k" })

local scratch = {}

function ContainerOrder.sequenceFor(page)
    if page == nil then return nil end
    local s = seq[page]
    if s == nil then return nil end

    if type(page.backpacks) ~= "table" or #s ~= #page.backpacks then
        return nil
    end
    return s
end

function ContainerOrder.layout(page, floatIndex, floatY)
    local s = seq[page]
    local size = page.buttonSize or 0
    if s == nil or size <= 0 then return end
    for i = 1, #s do
        local button = s[i]
        if button ~= nil then

            local y = (i == floatIndex) and floatY or (((i - 1) * size) - 1)
            if button:getY() ~= y then button:setY(y) end
        end
    end

    local panel = page.containerButtonPanel
    if panel ~= nil and panel.setScrollHeight ~= nil then
        panel:setScrollHeight(#s * size - 1)
    end
end

function ContainerOrder.apply(page)
    if page == nil then return false end
    local list = page.backpacks
    local pane = page.inventoryPane

    if page.onCharacter ~= true or type(list) ~= "table" or #list < 2
            or pane == nil or pane.mode ~= "comfy" then
        seq[page] = nil
        return false
    end

    local playerObj = getSpecificPlayer(page.player)
    local placed = ContainerOrder.get(page.player)
    local pos = nil
    if #placed > 0 then
        pos = {}
        for i = 1, #placed do
            if pos[placed[i]] == nil then pos[placed[i]] = i end
        end
    end

    local n = #list
    for i = n + 1, #scratch do scratch[i] = nil end
    for i = 1, n do
        local button = list[i]
        local inv = button ~= nil and button.inventory or nil
        local rank = UNPLACED + 1
        if inv ~= nil then
            if ContainerOrder.isPinned(inv, playerObj, page.player) then

                rank = -1
            else
                rank = UNPLACED + seedClass(inv, playerObj)
                if pos ~= nil then
                    local key = ContainerOrder.keyFor(inv, playerObj)
                    local at = key ~= nil and pos[key] or nil
                    if at ~= nil then rank = at end
                end
            end
        end
        local e = scratch[i]
        if e == nil then
            e = {}
            scratch[i] = e
        end
        e.button, e.rank, e.index = button, rank, i
    end

    table.sort(scratch, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.index < b.index
    end)

    local s = seq[page]
    if s == nil then
        s = {}
        seq[page] = s
    end
    for i = #s, n + 1, -1 do s[i] = nil end
    local moved = false
    for i = 1, n do
        s[i] = scratch[i].button
        if scratch[i].index ~= i then moved = true end
    end
    ContainerOrder.layout(page)
    return moved
end

function ContainerOrder.preview(page, inv, target)
    local s = ContainerOrder.sequenceFor(page)
    if s == nil then return nil end
    local at = nil
    for i = 1, #s do
        if s[i] ~= nil and s[i].inventory == inv then
            at = i
            break
        end
    end
    if at == nil then return nil end

    local playerObj = getSpecificPlayer(page.player)
    local lo = 1
    while lo <= #s and s[lo] ~= nil
            and ContainerOrder.isPinned(s[lo].inventory, playerObj,
                page.player) do
        lo = lo + 1
    end
    if target < lo then target = lo end
    if target > #s then target = #s end
    if target ~= at then
        table.insert(s, target, table.remove(s, at))
        at = target
    end
    return at
end

function ContainerOrder.commit(page)
    ContainerOrder.set(page.player, ContainerOrder.keysOf(page))

    ContainerOrder.apply(page)
end

function ContainerOrder.indexOf(page, inv)
    local s = ContainerOrder.sequenceFor(page)
    if s == nil then return nil end
    for i = 1, #s do
        if s[i] ~= nil and s[i].inventory == inv then return i end
    end
    return nil
end

function ContainerOrder.keysOf(page)
    local out = {}
    local s = ContainerOrder.sequenceFor(page)
    if s == nil then return out end
    local playerObj = getSpecificPlayer(page.player)
    for i = 1, #s do
        local b = s[i]
        local key = b ~= nil and ContainerOrder.keyFor(b.inventory, playerObj)
            or nil
        if key ~= nil then out[#out + 1] = key end
    end
    return out
end

Events.OnRefreshInventoryWindowContainers.Add(function(page, stage)
    if stage ~= "end" then return end
    local ok, err = pcall(ContainerOrder.apply, page)
    if not ok then
        Log.warn("ContainerOrder: apply failed: " .. tostring(err))
    end
end)
