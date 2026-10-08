--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Core/GameMode"

local Log = ComfyGrid.Core.Log
local VanillaStacks = ComfyGrid.Core.VanillaStacks
local GameMode = ComfyGrid.Core.GameMode

local QuickMove = {}
ComfyGrid.Interact.QuickMove = QuickMove

local function addLiveItem(liveItems, seen, item)
    if item == nil or seen[item] then return end
    if item:getContainer() == nil then return end
    seen[item] = true
    liveItems[#liveItems + 1] = item
end
QuickMove.addLiveItem = addLiveItem

local function collectEntry(entry, sourceInventory, liveItems, seen, vanillaList)
    if type(entry) == "table" then
        if entry.itemIDs ~= nil then

            local vanillaStack = VanillaStacks.fromStack(entry, sourceInventory,
                nil)
            if vanillaStack ~= nil then

                vanillaStack.comfyStacks = entry
                local items = vanillaStack.items
                local before = #liveItems
                for j = 2, #items do
                    addLiveItem(liveItems, seen, items[j])
                end
                if #liveItems > before then
                    vanillaList[#vanillaList + 1] = vanillaStack
                end
            end
        elseif type(entry.items) == "table" then
            local items = entry.items
            local itemCount = #items

            local first = VanillaStacks.firstRealIndex(items)
            local before = #liveItems
            for j = first, itemCount do
                addLiveItem(liveItems, seen, items[j])
            end
            if #liveItems > before then
                vanillaList[#vanillaList + 1] = entry
            end
        end
    elseif instanceof(entry, "InventoryItem") then
        local before = #liveItems
        addLiveItem(liveItems, seen, entry)
        if #liveItems > before then
            local wrapped = VanillaStacks.fromItems({ entry })
            if wrapped ~= nil then
                vanillaList[#vanillaList + 1] = wrapped
            end
        end
    end
end

local function selectedContainer(page)
    if page == nil then return nil end
    local pane = page.inventoryPane
    local paneInventory = pane ~= nil and pane.inventory or nil
    if paneInventory ~= nil then return paneInventory end
    return page.inventory
end

local function isPlayerSide(inventory, playerObj)
    if inventory == nil or playerObj == nil then return false end
    if inventory == playerObj:getInventory() then return true end
    local ok, inChar = pcall(inventory.isInCharacterInventory, inventory,
        playerObj)
    return ok and inChar == true
end
QuickMove.isPlayerSide = isPlayerSide

function QuickMove.destinationFor(sourceInventory, playerObj, playerNum)
    local playerInv = playerObj:getInventory()
    if not isPlayerSide(sourceInventory, playerObj) then

        return selectedContainer(getPlayerInventory(playerNum)) or playerInv
    end

    local ContainerWindow = ComfyGrid.UI ~= nil
        and ComfyGrid.UI.ContainerWindow or nil
    if ContainerWindow ~= nil and ContainerWindow.showsInventory ~= nil then
        local ok, shown = pcall(ContainerWindow.showsInventory, playerNum,
            sourceInventory)
        if ok and shown == true then return playerInv end
    end
    return selectedContainer(getPlayerLoot(playerNum))
end

function QuickMove.otherSideContainers(sourceInventory, playerObj, playerNum,
        out)
    out = out or {}
    if sourceInventory == nil or playerObj == nil then return out end
    local other
    if isPlayerSide(sourceInventory, playerObj) then
        other = getPlayerLoot(playerNum)
    else
        other = getPlayerInventory(playerNum)
    end
    if other == nil or other.backpacks == nil then return out end
    for i = 1, #other.backpacks do
        local button = other.backpacks[i]
        local container = button ~= nil and button.inventory or nil
        if container ~= nil and container ~= sourceInventory then
            out[#out + 1] = container
        end
    end
    return out
end

function QuickMove.run(stacks, sourceInventory, playerNum)
    if stacks == nil or sourceInventory == nil then return false end
    playerNum = playerNum or 0
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil then return false end

    if GameMode.isTutorial() then return false end

    if stacks.itemIDs ~= nil or stacks.items ~= nil then
        stacks = { stacks }
    end

    local liveItems, vanillaList, seen = {}, {}, {}
    for i = 1, #stacks do
        collectEntry(stacks[i], sourceInventory, liveItems, seen, vanillaList)
    end
    if #liveItems == 0 then return false end

    local dest = QuickMove.destinationFor(sourceInventory, playerObj, playerNum)

    if dest == nil or dest == sourceInventory then return false end

    local Transfer = ComfyGrid.Interact.Transfer
    if Transfer == nil then
        Log.warn("QuickMove: Transfer module missing; nothing queued")
        return false
    end

    local carried
    liveItems, carried = Transfer.escalateHeavyItems(liveItems, dest,
        playerObj)
    if #liveItems == 0 then return carried > 0 end

    local function handTo(target)
        if carried > 0 then

            return Transfer.moveItems(liveItems, target, playerObj, nil)
        end

        return Transfer.moveStacks(vanillaList, target, playerObj, nil)
    end

    local queuedCount = handTo(dest)

    if queuedCount <= 0 and not isPlayerSide(sourceInventory, playerObj) then
        local mainInventory = playerObj:getInventory()
        if mainInventory ~= nil and dest ~= mainInventory
                and mainInventory ~= sourceInventory then
            queuedCount = handTo(mainInventory)
        end
    end
    return queuedCount > 0
end
