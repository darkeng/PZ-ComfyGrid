--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.9
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/Core/Log"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ItemStack = {}
ComfyGrid.Model.ItemStack = ItemStack

local frontItems = {}
local frontIds = {}
local frontCount = 0
local MAX_FRONT_ENTRIES = 512

local function invalidateFront(stack)
    if frontItems[stack] ~= nil then
        frontCount = frontCount - 1
    end
    frontItems[stack] = nil
    frontIds[stack] = nil
end
ItemStack.invalidateFront = invalidateFront

local function cacheFront(stack, item, id)
    if frontItems[stack] == nil then
        if frontCount >= MAX_FRONT_ENTRIES then
            frontItems = {}
            frontIds = {}
            frontCount = 0
        end
        frontCount = frontCount + 1
    end
    frontItems[stack] = item
    frontIds[stack] = id
end

function ItemStack.create(item, slot)
    local StackRules = ComfyGrid.Model.StackRules
    return {
        itemIDs = { [item:getID()] = true },
        count = 1,
        slot = slot,
        itemType = StackRules.identityOf(item),
        bucket = StackRules.bucketOf(item),

        category = item:getDisplayCategory() or item:getCategory(),
    }
end

function ItemStack.canAdd(stack, item)

    if stack.count == 0 then return false end
    local StackRules = ComfyGrid.Model.StackRules
    return StackRules.isSameStack(stack, item)
        and stack.count < StackRules.maxStackOf(item)
end

function ItemStack.canAddPrecomputed(stack, fullType, bucket, maxStack)
    if stack.count == 0 then return false end
    return stack.itemType == fullType
        and stack.bucket == bucket
        and stack.count < maxStack
end

function ItemStack.add(stack, item)
    local id = item:getID()

    if not stack.itemIDs[id] then
        stack.itemIDs[id] = true
        stack.count = stack.count + 1
    end
    invalidateFront(stack)
end

function ItemStack.removeId(stack, itemId)
    if stack.itemIDs[itemId] then
        stack.itemIDs[itemId] = nil
        stack.count = stack.count - 1
    end
    invalidateFront(stack)
    return stack.count == 0
end

function ItemStack.containsId(stack, itemId)
    return stack.itemIDs[itemId] ~= nil
end

function ItemStack.frontItem(stack, inventory)
    if not inventory then return nil end
    local cached = frontItems[stack]
    local cachedId = frontIds[stack]
    if cached and cachedId and stack.itemIDs[cachedId]
            and cached:getContainer() == inventory then
        return cached
    end
    invalidateFront(stack)
    for id in pairs(stack.itemIDs) do
        local item = inventory:getItemWithID(id)
        if item then
            cacheFront(stack, item, id)
            return item
        end
    end
    return nil
end

function ItemStack.getItems(stack, inventory)
    local items = {}
    if not inventory then return items end
    for id in pairs(stack.itemIDs) do
        local item = inventory:getItemWithID(id)
        if item then
            items[#items + 1] = item
        end
    end
    return items
end

function ItemStack.weightOf(stack, inventory)
    if not inventory or stack == nil or type(stack.itemIDs) ~= "table" then
        return 0
    end
    local total = 0
    for id in pairs(stack.itemIDs) do
        local item = inventory:getItemWithID(id)
        if item ~= nil and item.getUnequippedWeight ~= nil then
            local ok, w = pcall(item.getUnequippedWeight, item)
            if ok and type(w) == "number" then total = total + w end
        end
    end
    return total
end

function ItemStack.split(stack, n)
    local ids = {}
    if not n or n <= 0 then return ids end
    for id in pairs(stack.itemIDs) do
        ids[#ids + 1] = id
        if #ids >= n then break end
    end
    return ids
end
