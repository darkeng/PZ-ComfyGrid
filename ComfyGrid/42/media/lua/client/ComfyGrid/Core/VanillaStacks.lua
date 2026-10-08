--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Model/ItemStack"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Core = ComfyGrid.Core or {}
local VanillaStacks = {}
ComfyGrid.Core.VanillaStacks = VanillaStacks

function VanillaStacks.firstRealIndex(items)
    return (#items >= 2) and 2 or 1
end

function VanillaStacks.sidePaneFor(playerNum, inPlayerInventory)
    local pageOf = inPlayerInventory and getPlayerInventory or getPlayerLoot
    local ok, page = pcall(pageOf, playerNum or 0)
    if ok and page ~= nil then return page.inventoryPane end
    return nil
end

function VanillaStacks.fromItems(items, _inventory, pane)
    if not items or #items == 0 then return nil end
    local front = items[1]
    local vanillaItems = { front }
    local weight = 0
    for i = 1, #items do
        local item = items[i]
        vanillaItems[#vanillaItems + 1] = item
        weight = weight + item:getUnequippedWeight()
    end
    return {
        items = vanillaItems,
        count = #items + 1,
        weight = weight,
        name = front:getName(),

        cat = front:getDisplayCategory() or front:getCategory(),
        invPanel = pane,
    }
end

function VanillaStacks.fromStack(stack, inventory, pane)

    local ItemStack = ComfyGrid.Model.ItemStack
    if not stack or not ItemStack then return nil end
    local items = ItemStack.getItems(stack, inventory)
    if not items or #items == 0 then return nil end
    return VanillaStacks.fromItems(items, inventory, pane)
end

function VanillaStacks.listFrom(stacks, inventory, pane)
    local vanillaStackList = {}
    if not stacks then return vanillaStackList end
    for i = 1, #stacks do
        local vanillaStack = VanillaStacks.fromStack(stacks[i], inventory, pane)
        if vanillaStack then
            vanillaStackList[#vanillaStackList + 1] = vanillaStack
        end
    end
    return vanillaStackList
end
