--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.8
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/VanillaStacks"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/Model/Persistence"

local Log = ComfyGrid.Core.Log
local ItemStack = ComfyGrid.Model.ItemStack
local VanillaStacks = ComfyGrid.Core.VanillaStacks
local Persistence = ComfyGrid.Model.Persistence

local DropHandler = {}
ComfyGrid.Interact.DropHandler = DropHandler

local function addLiveItem(liveItems, seen, item)
    if item == nil or seen[item] then return end
    if item:getContainer() == nil then return end
    seen[item] = true
    liveItems[#liveItems + 1] = item
end

local function addComfyStacks(list, seen, tag)
    if type(tag) ~= "table" then return end
    if tag.itemIDs ~= nil then
        if not seen[tag] then
            seen[tag] = true
            list[#list + 1] = tag
        end
        return
    end
    for i = 1, #tag do
        local s = tag[i]
        if type(s) == "table" and s.itemIDs ~= nil and not seen[s] then
            seen[s] = true
            list[#list + 1] = s
        end
    end
end

local function collectDragged(dragged)
    local liveItems, comfyStacks, normalized = {}, {}, {}
    local seenItems, seenStacks = {}, {}
    for i = 1, #dragged do
        local entry = dragged[i]
        if type(entry) == "table" then
            local items = entry.items
            if type(items) == "table" then
                local n = #items

                local first = (n >= 2) and 2 or 1
                local before = #liveItems
                for j = first, n do
                    addLiveItem(liveItems, seenItems, items[j])
                end
                if #liveItems > before then
                    normalized[#normalized + 1] = entry
                end
            end
            addComfyStacks(comfyStacks, seenStacks,
                entry.comfyStacks or entry.comfyStack)
        elseif instanceof(entry, "InventoryItem") then
            local before = #liveItems
            addLiveItem(liveItems, seenItems, entry)
            if #liveItems > before then
                local vs = VanillaStacks.fromItems({ entry })
                if vs ~= nil then
                    normalized[#normalized + 1] = vs
                end
            end
        end
    end
    return liveItems, comfyStacks, normalized
end

local function gridOwnsStack(grid, stack)
    local stacks = grid.data.stacks
    for i = 1, #stacks do
        if stacks[i] == stack then return true end
    end
    return false
end

local function resolveSameContainer(grid, liveItems, taggedStacks, targetSlot,
        playerNum)

    local stacksToMove = {}
    local coveredIds = {}
    for i = 1, #taggedStacks do
        local s = taggedStacks[i]
        if gridOwnsStack(grid, s) then
            stacksToMove[#stacksToMove + 1] = s
            for id in pairs(s.itemIDs) do
                coveredIds[id] = true
            end
        end
    end

    local dragIds = nil
    local loose = {}
    local worn = nil
    local attached = nil

    local okHb, hotbar = pcall(getPlayerHotbar, playerNum)
    if not okHb then hotbar = nil end
    local stacks = grid.data.stacks
    for i = 1, #liveItems do
        local item = liveItems[i]
        local id = item:getID()
        if not coveredIds[id] then
            local owner = nil
            for j = 1, #stacks do
                if ItemStack.containsId(stacks[j], id) then
                    owner = stacks[j]
                    break
                end
            end
            if owner ~= nil then
                dragIds = dragIds or {}
                local list = dragIds[owner]
                if list == nil then
                    list = {}
                    dragIds[owner] = list
                end
                list[#list + 1] = id
            elseif item:isEquipped() then

                worn = worn or {}
                worn[#worn + 1] = item
            elseif hotbar ~= nil and hotbar:isInHotbar(item) then

                attached = attached or {}
                attached[#attached + 1] = item
            elseif not item:isHidden() then
                loose[#loose + 1] = item
            end
        end
    end
    local splits = nil
    if dragIds ~= nil then
        for stack, list in pairs(dragIds) do
            if #list >= stack.count then
                stacksToMove[#stacksToMove + 1] = stack
            else
                splits = splits or {}
                splits[#splits + 1] = { stack = stack, ids = list }
            end
        end
    end

    local changed = false
    if #stacksToMove == 1 and #loose == 0 and splits == nil then

        local s = stacksToMove[1]
        changed = grid:moveStack(s, targetSlot)
        if not changed and grid.swapStacks ~= nil then
            local occupant = grid:stackAt(targetSlot)
            if occupant ~= nil and occupant ~= s then
                changed = grid:swapStacks(s, occupant)
            end
        end
    else
        for i = 1, #stacksToMove do
            local s = stacksToMove[i]

            if grid:moveStack(s, targetSlot) then
                changed = true
            elseif grid:moveStack(s, grid:firstFreeSlot()) then
                changed = true
            end
        end
        for i = 1, #loose do

            if grid:insertItem(loose[i], targetSlot)
                    or grid:insertItem(loose[i]) then
                changed = true
            end
        end
        if splits ~= nil then
            for i = 1, #splits do
                local s = splits[i]

                if grid:splitToSlot(s.stack, s.ids, targetSlot)
                        or grid:splitToSlot(s.stack, s.ids,
                            grid:firstFreeSlot()) then
                    changed = true
                end
            end
        end
    end

    if worn ~= nil then
        for i = 1, #worn do
            local ok, err = pcall(ISInventoryPaneContextMenu.unequipItem,
                worn[i], playerNum)
            if not ok then
                Log.warn("DropHandler: unequip failed: " .. tostring(err))
            elseif grid.claimSlotForItem ~= nil then
                grid:claimSlotForItem(worn[i]:getID(), targetSlot)
            end
        end
        changed = true
    end
    if attached ~= nil and hotbar ~= nil then
        for i = 1, #attached do

            local ok, err = pcall(hotbar.removeItem, hotbar, attached[i], true)
            if not ok then
                Log.warn("DropHandler: detach failed: " .. tostring(err))
            elseif grid.claimSlotForItem ~= nil then
                grid:claimSlotForItem(attached[i]:getID(), targetSlot)
            end
        end
        changed = true
    end
    return changed
end

local function finishDrag(gridView, DragAndDrop)
    local focus = ISMouseDrag.draggingFocus
    DragAndDrop.endDrag()

    if focus ~= nil and focus ~= gridView and focus.Type ~= "ComfyGridView"
            and focus.isComfyDragSource ~= true
            and type(focus.onMouseUp) == "function" then

        pcall(focus.onMouseUp, focus, 0, 0)
    end
end

local function assignOrderedSlots(grid, startSlot, n)
    local slots = {}
    local slot = (type(startSlot) == "number" and startSlot >= 0)
        and startSlot or 0
    for k = 1, n do
        while grid:stackAt(slot) ~= nil do slot = slot + 1 end
        slots[k] = slot
        slot = slot + 1
    end
    return slots
end

function DropHandler.resolve(gridView, localX, localY)
    if gridView == nil or gridView.model == nil
            or gridView.model.grid == nil then
        return false
    end
    if localX == nil or localY == nil then return false end
    local targetSlot = gridView:slotAt(localX, localY)
    if targetSlot == nil then return false end

    local DragAndDrop = ComfyGrid.Interact.DragAndDrop
    if DragAndDrop == nil or DragAndDrop.getDraggedStacks == nil then
        return false
    end
    local dragged = DragAndDrop.getDraggedStacks()
    if dragged == nil then return false end

    local liveItems, comfyStacks, normalized = collectDragged(dragged)
    if #liveItems == 0 then

        finishDrag(gridView, DragAndDrop)
        return true
    end

    local model = gridView.model
    local inventory = model.inventory

    local ItemApply = ComfyGrid.Interact.ItemApply
    if ItemApply ~= nil and #normalized == 1 then
        local occupant = model.grid:stackAt(targetSlot)
        local oneKind = occupant ~= nil and ItemApply.sameTypeList(liveItems)
        if oneKind ~= nil and oneKind ~= false then
            local dst = ItemStack.frontItem(occupant, inventory)
            if ItemApply.pickTarget ~= nil then
                dst = ItemApply.pickTarget(occupant, inventory, oneKind, dst)
            end
            local playerObj = getSpecificPlayer(gridView.playerNum
                or model.playerNum or 0)
            if dst ~= nil and playerObj ~= nil
                    and not ItemStack.containsId(occupant, oneKind[1]:getID())
                    and ItemApply.tryApply(oneKind, dst, playerObj) then
                finishDrag(gridView, DragAndDrop)
                return true
            end
        end
    end

    local sameContainer = true
    for i = 1, #liveItems do
        if liveItems[i]:getContainer() ~= inventory then
            sameContainer = false
            break
        end
    end

    if sameContainer then
        if resolveSameContainer(model.grid, liveItems, comfyStacks,
                targetSlot, gridView.playerNum or model.playerNum or 0) then

            model.needsImmediateRefresh = true

            Persistence.queueSync(inventory)
        end
    else
        local playerObj = getSpecificPlayer(gridView.playerNum
            or model.playerNum or 0)
        local Transfer = ComfyGrid.Interact.Transfer
        if playerObj == nil or Transfer == nil then

            Log.warn("DropHandler: cannot queue transfer (missing "
                .. (playerObj == nil and "player object" or "Transfer module")
                .. "); drop consumed as no-op")
        elseif #normalized >= 2 and Transfer.moveStacksOrdered ~= nil then

            local srcInv = liveItems[1] and liveItems[1]:getContainer() or nil
            local slots = assignOrderedSlots(model.grid, targetSlot, #normalized)
            Transfer.moveStacksOrdered(normalized, inventory, playerObj, slots,
                srcInv)
        elseif Transfer.moveStacks ~= nil then
            Transfer.moveStacks(normalized, inventory, playerObj, targetSlot)

            if #comfyStacks == 1 and #normalized == 1 then
                local tag = comfyStacks[1]
                local occupant = model.grid:stackAt(targetSlot)
                if occupant ~= nil and type(tag.slot) == "number" then
                    local srcInv = liveItems[1]:getContainer()
                    local uniform = srcInv ~= nil and srcInv ~= inventory
                    for i = 2, #liveItems do
                        if liveItems[i]:getContainer() ~= srcInv then
                            uniform = false
                            break
                        end
                    end
                    if uniform then
                        local front = ItemStack.frontItem(tag, srcInv)
                        if front ~= nil
                                and not ItemStack.canAdd(occupant, front) then
                            Transfer.moveStacks({ occupant }, srcInv,
                                playerObj, tag.slot, inventory)
                        end
                    end
                end
            end
        else

            Transfer.moveItems(liveItems, inventory, playerObj, targetSlot)
        end
    end

    finishDrag(gridView, DragAndDrop)
    return true
end
