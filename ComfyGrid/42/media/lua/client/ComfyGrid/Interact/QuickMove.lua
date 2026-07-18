--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.1.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/VanillaStacks"

local Log = ComfyGrid.Core.Log
local VanillaStacks = ComfyGrid.Core.VanillaStacks

local QuickMove = {}
ComfyGrid.Interact.QuickMove = QuickMove

local function addLive(liveItems, seen, item)
    if item == nil or seen[item] then return end
    if item:getContainer() == nil then return end
    seen[item] = true
    liveItems[#liveItems + 1] = item
end

local function collectEntry(entry, sourceInventory, liveItems, seen, vanillaList)
    if type(entry) == "table" then
        if entry.itemIDs ~= nil then

            local vs = VanillaStacks.fromStack(entry, sourceInventory, nil)
            if vs ~= nil then

                vs.comfyStacks = entry
                local items = vs.items
                local before = #liveItems
                for j = 2, #items do
                    addLive(liveItems, seen, items[j])
                end
                if #liveItems > before then
                    vanillaList[#vanillaList + 1] = vs
                end
            end
        elseif type(entry.items) == "table" then
            local items = entry.items
            local n = #items

            local first = (n >= 2) and 2 or 1
            local before = #liveItems
            for j = first, n do
                addLive(liveItems, seen, items[j])
            end
            if #liveItems > before then
                vanillaList[#vanillaList + 1] = entry
            end
        end
    elseif instanceof(entry, "InventoryItem") then
        local before = #liveItems
        addLive(liveItems, seen, entry)
        if #liveItems > before then
            local vs = VanillaStacks.fromItems({ entry })
            if vs ~= nil then
                vanillaList[#vanillaList + 1] = vs
            end
        end
    end
end

local function destinationFor(sourceInventory, playerObj, playerNum)
    local playerInv = playerObj:getInventory()
    local playerSide = (sourceInventory == playerInv)
    if not playerSide then

        local ok, inChar = pcall(sourceInventory.isInCharacterInventory,
            sourceInventory, playerObj)
        playerSide = ok and inChar == true
    end
    if not playerSide then
        return playerInv
    end

    local lootPage = getPlayerLoot(playerNum)
    local pane = lootPage ~= nil and lootPage.inventoryPane or nil
    if pane == nil then return nil end
    return pane.inventory
end

function QuickMove.run(stacks, sourceInventory, playerNum)
    if stacks == nil or sourceInventory == nil then return false end
    playerNum = playerNum or 0
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil then return false end

    if stacks.itemIDs ~= nil or stacks.items ~= nil then
        stacks = { stacks }
    end

    local liveItems, vanillaList, seen = {}, {}, {}
    for i = 1, #stacks do
        collectEntry(stacks[i], sourceInventory, liveItems, seen, vanillaList)
    end
    if #liveItems == 0 then return false end

    local dest = destinationFor(sourceInventory, playerObj, playerNum)

    if dest == nil or dest == sourceInventory then return false end

    local Transfer = ComfyGrid.Interact.Transfer
    if Transfer == nil then
        Log.warn("QuickMove: Transfer module missing; nothing queued")
        return false
    end
    local queued
    if Transfer.moveStacks ~= nil then

        queued = Transfer.moveStacks(vanillaList, dest, playerObj, nil)
    else

        queued = Transfer.moveItems(liveItems, dest, playerObj, nil)
    end

    if type(queued) == "number" then return queued > 0 end
    return queued ~= false
end
