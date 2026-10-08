--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
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
        local okInventory, ownInventory = pcall(playerObj.getInventory, playerObj)
        if okInventory and ownInventory == inventory then
            return ContainerOrder.SELF_KEY
        end
    end
    local okContaining, item = pcall(inventory.getContainingItem, inventory)
    if not okContaining or item == nil then return nil end
    local okFullType, fullType = pcall(item.getFullType, item)
    if not okFullType or fullType == nil then return nil end
    return fullType
end

local function seedClass(inventory, playerObj)
    if playerObj == nil then return 1 end
    local okInventory, ownInventory = pcall(playerObj.getInventory, playerObj)
    if okInventory and ownInventory == inventory then return 0 end
    if playerObj.isHandItem == nil then return 1 end
    local okContaining, item = pcall(inventory.getContainingItem, inventory)
    if not okContaining or item == nil then return 1 end
    local okHeld, held = pcall(playerObj.isHandItem, playerObj, item)
    if okHeld and held == true then return 2 end
    return 1
end

function ContainerOrder.isMain(inventory, playerObj)
    return seedClass(inventory, playerObj) == 0
end

function ContainerOrder.isPinned(inventory, playerObj, playerNum)
    if inventory == nil then return false end
    local Plan = ComfyGrid.Model and ComfyGrid.Model.SectionPlan
    if Plan == nil or Plan.isPocket == nil then return false end
    return Plan.isPocket(inventory, playerObj, playerNum)
end

local storedKeysByPlayer = {}

local function prefKey(playerNum)
    return "ComfyOrder" .. tostring(playerNum or 0)
end

function ContainerOrder.get(playerNum)
    local storedKeys = storedKeysByPlayer[playerNum or 0]
    if storedKeys == nil then
        storedKeys = {}
        local raw = Prefs.get(prefKey(playerNum))
        if type(raw) == "string" and raw ~= "" then
            for storedKey in string.gmatch(raw, "[^|]+") do
                storedKeys[#storedKeys + 1] = storedKey
            end
        end
        storedKeysByPlayer[playerNum or 0] = storedKeys
    end
    return storedKeys
end

function ContainerOrder.set(playerNum, keys)
    local uniqueKeys, seen = {}, {}
    for i = 1, #keys do
        local key = keys[i]

        if type(key) == "string" and key ~= "" and not seen[key] then
            seen[key] = true
            uniqueKeys[#uniqueKeys + 1] = key
        end
    end
    storedKeysByPlayer[playerNum or 0] = uniqueKeys
    Prefs.set(prefKey(playerNum), table.concat(uniqueKeys, "|"))
end

local sequenceByPage = setmetatable({}, { __mode = "k" })

local rankScratch = {}

local function byRankThenIndex(entryA, entryB)
    if entryA.rank ~= entryB.rank then return entryA.rank < entryB.rank end
    return entryA.index < entryB.index
end

function ContainerOrder.sequenceFor(page)
    if page == nil then return nil end
    local sequence = sequenceByPage[page]
    if sequence == nil then return nil end

    if type(page.backpacks) ~= "table" or #sequence ~= #page.backpacks then
        return nil
    end
    return sequence
end

function ContainerOrder.layout(page, floatIndex, floatY)
    local sequence = sequenceByPage[page]
    local size = page.buttonSize or 0
    if sequence == nil or size <= 0 then return end
    for i = 1, #sequence do
        local button = sequence[i]
        if button ~= nil then

            local y = (i == floatIndex) and floatY or (((i - 1) * size) - 1)
            if button:getY() ~= y then button:setY(y) end
        end
    end

    local panel = page.containerButtonPanel
    if panel ~= nil and panel.setScrollHeight ~= nil then
        panel:setScrollHeight(#sequence * size - 1)
    end
end

function ContainerOrder.apply(page)
    if page == nil then return false end
    local buttons = page.backpacks
    local pane = page.inventoryPane

    if page.onCharacter ~= true or type(buttons) ~= "table" or #buttons < 2
            or pane == nil or pane.mode ~= "comfy" then
        sequenceByPage[page] = nil
        return false
    end

    local playerObj = getSpecificPlayer(page.player)
    local placed = ContainerOrder.get(page.player)
    local storedIndexByKey = nil
    if #placed > 0 then
        storedIndexByKey = {}
        for i = 1, #placed do
            if storedIndexByKey[placed[i]] == nil then
                storedIndexByKey[placed[i]] = i
            end
        end
    end

    local buttonCount = #buttons
    for i = buttonCount + 1, #rankScratch do rankScratch[i] = nil end
    for i = 1, buttonCount do
        local button = buttons[i]
        local inv = button ~= nil and button.inventory or nil
        local rank = UNPLACED + 1
        if inv ~= nil then
            if ContainerOrder.isPinned(inv, playerObj, page.player) then

                rank = -1
            else
                rank = UNPLACED + seedClass(inv, playerObj)
                if storedIndexByKey ~= nil then
                    local key = ContainerOrder.keyFor(inv, playerObj)
                    local storedIndex = key ~= nil and storedIndexByKey[key] or nil
                    if storedIndex ~= nil then rank = storedIndex end
                end
            end
        end
        local rankEntry = rankScratch[i]
        if rankEntry == nil then
            rankEntry = {}
            rankScratch[i] = rankEntry
        end
        rankEntry.button, rankEntry.rank, rankEntry.index = button, rank, i
    end

    table.sort(rankScratch, byRankThenIndex)

    local sequence = sequenceByPage[page]
    if sequence == nil then
        sequence = {}
        sequenceByPage[page] = sequence
    end
    for i = #sequence, buttonCount + 1, -1 do sequence[i] = nil end
    local moved = false
    for i = 1, buttonCount do
        sequence[i] = rankScratch[i].button
        if rankScratch[i].index ~= i then moved = true end
    end
    ContainerOrder.layout(page)
    return moved
end

function ContainerOrder.preview(page, inv, target)
    local sequence = ContainerOrder.sequenceFor(page)
    if sequence == nil then return nil end
    local currentIndex = nil
    for i = 1, #sequence do
        if sequence[i] ~= nil and sequence[i].inventory == inv then
            currentIndex = i
            break
        end
    end
    if currentIndex == nil then return nil end

    local playerObj = getSpecificPlayer(page.player)
    local firstMovable = 1
    while firstMovable <= #sequence and sequence[firstMovable] ~= nil
            and ContainerOrder.isPinned(sequence[firstMovable].inventory,
                playerObj, page.player) do
        firstMovable = firstMovable + 1
    end
    if target < firstMovable then target = firstMovable end
    if target > #sequence then target = #sequence end
    if target ~= currentIndex then
        table.insert(sequence, target, table.remove(sequence, currentIndex))
        currentIndex = target
    end
    return currentIndex
end

function ContainerOrder.commit(page)
    ContainerOrder.set(page.player, ContainerOrder.keysOf(page))

    ContainerOrder.apply(page)
end

function ContainerOrder.indexOf(page, inv)
    local sequence = ContainerOrder.sequenceFor(page)
    if sequence == nil then return nil end
    for i = 1, #sequence do
        if sequence[i] ~= nil and sequence[i].inventory == inv then return i end
    end
    return nil
end

function ContainerOrder.keysOf(page)
    local keys = {}
    local sequence = ContainerOrder.sequenceFor(page)
    if sequence == nil then return keys end
    local playerObj = getSpecificPlayer(page.player)
    for i = 1, #sequence do
        local button = sequence[i]
        local key = button ~= nil
            and ContainerOrder.keyFor(button.inventory, playerObj) or nil
        if key ~= nil then keys[#keys + 1] = key end
    end
    return keys
end

Events.OnRefreshInventoryWindowContainers.Add(function(page, stage)
    if stage ~= "end" then return end
    local ok, err = pcall(ContainerOrder.apply, page)
    if not ok then
        Log.warn("ContainerOrder: apply failed: " .. tostring(err))
    end
end)
