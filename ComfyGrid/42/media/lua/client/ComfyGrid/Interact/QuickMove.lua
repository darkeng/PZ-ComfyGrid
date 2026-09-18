--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.3
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

local function selectedContainer(page)
    if page == nil then return nil end
    local pane = page.inventoryPane
    local inv = pane ~= nil and pane.inventory or nil
    if inv ~= nil then return inv end
    return page.inventory
end

local function isPlayerSide(sourceInventory, playerObj)
    if sourceInventory == playerObj:getInventory() then return true end
    local ok, inChar = pcall(sourceInventory.isInCharacterInventory,
        sourceInventory, playerObj)
    return ok and inChar == true
end

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

function QuickMove.otherSideContainers(sourceInventory, playerObj, playerNum)
    local out = {}
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
        local inv = button ~= nil and button.inventory or nil
        if inv ~= nil and inv ~= sourceInventory then
            out[#out + 1] = inv
        end
    end
    return out
end

local function tutorialMode()
    local okCore, core = pcall(getCore)
    if not okCore or core == nil or core.getGameMode == nil then
        return false
    end
    local okMode, mode = pcall(core.getGameMode, core)
    return okMode and tostring(mode) == "Tutorial"
end

function QuickMove.run(stacks, sourceInventory, playerNum)
    if stacks == nil or sourceInventory == nil then return false end
    playerNum = playerNum or 0
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil then return false end
    if tutorialMode() then return false end

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

    local carried = 0
    if Transfer.escalateHeavyItems ~= nil then
        liveItems, carried = Transfer.escalateHeavyItems(liveItems, dest,
            playerObj)
        if #liveItems == 0 then return carried > 0 end
    end
    local function handTo(target)
        if carried > 0 then

            return Transfer.moveItems(liveItems, target, playerObj, nil)
        elseif Transfer.moveStacks ~= nil then

            return Transfer.moveStacks(vanillaList, target, playerObj, nil)
        end

        return Transfer.moveItems(liveItems, target, playerObj, nil)
    end

    local function movedAny(q)
        if type(q) == "number" then return q > 0 end
        return q ~= false
    end

    local queued = handTo(dest)

    if not movedAny(queued) and not isPlayerSide(sourceInventory, playerObj) then
        local main = playerObj:getInventory()
        if main ~= nil and dest ~= main and main ~= sourceInventory then
            queued = handTo(main)
        end
    end
    return movedAny(queued)
end
