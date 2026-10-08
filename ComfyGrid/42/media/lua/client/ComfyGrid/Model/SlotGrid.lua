--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Input"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Util"
require "ComfyGrid/Model/StackRules"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/Model/Capacity"
require "ComfyGrid/Model/Persistence"
require "ComfyGrid/Model/ReflowPlan"

local Log = ComfyGrid.Core.Log
local Util = ComfyGrid.Core.Util
local StackRules = ComfyGrid.Model.StackRules
local ItemStack = ComfyGrid.Model.ItemStack
local Capacity = ComfyGrid.Model.Capacity
local Persistence = ComfyGrid.Model.Persistence
local ReflowPlan = ComfyGrid.Model.ReflowPlan

local SlotGrid = {}
SlotGrid.__index = SlotGrid
ComfyGrid.Model.SlotGrid = SlotGrid

local MAX_RECONCILE_INSERTS = 10

local PENDING_CLAIM_TTL_MS = 10000

local PENDING_CLAIM_RETRY_MS = 2500
local PENDING_CLAIM_RETRY_MS_MP = 5000

local scratchSeen = {}
local scratchMigrated = {}

local scratchHome = {}

local scratchIdentityClaims = {}

local wipe = Util.wipe

local getHotbar = ComfyGrid.Core.Input.hotbarOf

local function isItemExcluded(item, hotbar, excludeEquipped)
    if item:isHidden() then
        return true
    end
    if not excludeEquipped then
        return false
    end
    if item:isEquipped() then
        return true
    end
    if hotbar then
        local ok, inBar = pcall(hotbar.isInHotbar, hotbar, item)
        if ok and inBar then
            return true
        end
    end
    return false
end

local function isOwnMainInventory(self)
    if self.playerNum == nil then return false end
    local ok, player = pcall(getSpecificPlayer, self.playerNum)
    if not ok or player == nil then return false end
    return player:getInventory() == self.inventory
end

local RUNG_LABEL = { player = "IsoPlayer", vehicle = "BaseVehicle", object = "IsoObject" }

local MOVER_CLASSES = { "IsoAnimal", "IsoPlayer", "IsoZombie", "IsoDeadBody" }

local function moverClassOf(owner)
    for i = 1, #MOVER_CLASSES do
        if instanceof(owner, MOVER_CLASSES[i]) then return MOVER_CLASSES[i] end
    end
    return "IsoMovingObject"
end

local function describeContainer(inventory, playerNum)
    if inventory == nil then return "?" end
    local okType, invType = pcall(inventory.getType, inventory)
    local name = (okType and invType ~= nil) and tostring(invType) or "?"

    local okOwner, owner, rung = pcall(Persistence.ownerOf, inventory, playerNum)
    if not okOwner then return name end

    if rung == "bag" then

        local okFullType, fullType = pcall(owner.getFullType, owner)
        if okFullType and fullType ~= nil then
            fullType = tostring(fullType)
            if fullType ~= name and fullType ~= ("Base." .. name) then
                return name .. "/" .. fullType
            end
        end
        return name
    end

    if rung == "mover" then
        local okClass, className = pcall(moverClassOf, owner)
        if okClass then return name .. "/" .. className end
        return name
    end

    local label = RUNG_LABEL[rung]
    if label ~= nil then return name .. "/" .. label end
    return name
end

function SlotGrid:_snapshotItems()
    local firstItemById = self.itemById
    local snapshotItems = self.snapItems
    local snapshotIds = self.snapIds
    if firstItemById == nil then
        firstItemById, snapshotItems, snapshotIds = {}, {}, {}
        self.itemById, self.snapItems, self.snapIds =
            firstItemById, snapshotItems, snapshotIds
    else
        wipe(firstItemById)
    end
    local entryCount = 0
    local items = self.inventory ~= nil and self.inventory:getItems() or nil
    if items ~= nil then
        for i = 0, items:size() - 1 do
            local item = items:get(i)

            if item ~= nil and instanceof(item, "InventoryItem") then
                local id = item:getID()
                entryCount = entryCount + 1
                snapshotItems[entryCount] = item
                snapshotIds[entryCount] = id
                if firstItemById[id] == nil then firstItemById[id] = item end
            end
        end
    end

    for staleIndex = entryCount + 1, self.snapCount or 0 do
        snapshotItems[staleIndex] = nil
        snapshotIds[staleIndex] = nil
    end
    self.snapCount = entryCount
end

function SlotGrid:new(inventory, persistentGridData, playerNum)
    local grid = setmetatable({}, self)
    grid.inventory = inventory
    grid.data = persistentGridData
    grid.data.stacks = grid.data.stacks or {}
    grid.playerNum = playerNum
    grid.slotMap = {}
    grid.pendingClaims = nil
    grid.claimLanded = false
    grid.needsMoreReconcile = false

    grid.refusalLogged = false
    grid.refusalPasses = 0

    grid.changeCount = 0
    grid:_rebuildSlotMap()
    grid:_recomputeSlotCount()
    return grid
end

function SlotGrid:rebindData(newData)
    if newData == nil or newData == self.data then return end
    self.data = newData
    self.data.stacks = self.data.stacks or {}
    self:_rebuildSlotMap()
    self:_recomputeSlotCount()
end

function SlotGrid:slotCount()
    return self.slots
end

function SlotGrid:contentSlots()
    return self:_highestOccupiedSlot() + 1
end

function SlotGrid:stackAt(slot)
    return self.slotMap[slot]
end

function SlotGrid:findStackFor(item)
    local stacks = self.data.stacks
    if #stacks == 0 then return nil end
    local identity = StackRules.identityOf(item)
    local bucket = StackRules.bucketOf(item)
    local maxStack = StackRules.maxStackOf(item)
    for i = 1, #stacks do
        local stack = stacks[i]
        if ItemStack.canAddPrecomputed(stack, identity, bucket, maxStack) then
            return stack
        end
    end
    return nil
end

function SlotGrid:firstFreeSlot(forId)
    local total = Capacity.slotsFor(self.inventory, self.playerNum)
    local highest = self:_highestOccupiedSlot()
    if highest + 1 > total then total = highest + 1 end
    local slotMap = self.slotMap
    local reserved = nil
    local claims = self.pendingClaims
    if claims ~= nil then
        local now = getTimestampMs()

        local ownClaim = forId ~= nil and claims[forId] or nil
        if ownClaim ~= nil and now - ownClaim.ms <= PENDING_CLAIM_TTL_MS
                and slotMap[ownClaim.slot] == nil then
            return ownClaim.slot
        end
        for id, claim in pairs(claims) do
            if id ~= forId and now - claim.ms <= PENDING_CLAIM_TTL_MS then
                reserved = reserved or {}
                reserved[claim.slot] = true
            end
        end
    end
    for slot = 0, total - 1 do
        if slotMap[slot] == nil and (reserved == nil or not reserved[slot]) then
            return slot
        end
    end
    return total
end

local function noteMutation(self)
    self.changeCount = self.changeCount + 1
    self:_recomputeSlotCount()
end

function SlotGrid:insertItem(item, slot)
    if item == nil then return false end

    if item:getContainer() ~= self.inventory then return false end

    local explicit = slot ~= nil
    if slot == nil then
        local stack = self:findStackFor(item)
        if stack ~= nil then
            ItemStack.add(stack, item)
            noteMutation(self)
            return true
        end
        slot = self:firstFreeSlot(item:getID())
    elseif slot < 0 then
        return false
    end

    local occupant = self.slotMap[slot]

    local alreadyThere = occupant ~= nil
        and ItemStack.containsId(occupant, item:getID())
    if occupant ~= nil and not alreadyThere
            and not ItemStack.canAdd(occupant, item) then
        return false
    end

    if explicit then
        self:removeItem(item)

        occupant = self.slotMap[slot]
    end

    if occupant ~= nil then
        ItemStack.add(occupant, item)
        noteMutation(self)
        return true
    end

    local stack = ItemStack.create(item, slot)
    local stacks = self.data.stacks
    stacks[#stacks + 1] = stack
    self.slotMap[slot] = stack
    noteMutation(self)
    return true
end

function SlotGrid:removeItem(item)
    if item == nil then return false end
    local id = item:getID()
    local stacks = self.data.stacks
    for i = 1, #stacks do
        local stack = stacks[i]
        if ItemStack.containsId(stack, id) then
            if ItemStack.removeId(stack, id) then
                table.remove(stacks, i)
                if self.slotMap[stack.slot] == stack then
                    self.slotMap[stack.slot] = nil
                end
            end
            noteMutation(self)
            return true
        end
    end
    return false
end

function SlotGrid:moveStack(stack, slot)
    if stack == nil or slot == nil or slot < 0 then return false end
    local slotMap = self.slotMap
    local target = slotMap[slot]
    if target == stack or stack.slot == slot then
        return true
    end

    if target == nil then
        if slotMap[stack.slot] == stack then
            slotMap[stack.slot] = nil
        end
        stack.slot = slot
        slotMap[slot] = stack

        self:_recomputeSlotCount()
        return true
    end

    local front = ItemStack.frontItem(stack, self.inventory)
    if front == nil or not ItemStack.canAdd(target, front) then
        return false
    end

    local targetIds = target.itemIDs
    local added = 0
    for id in pairs(stack.itemIDs) do
        if not targetIds[id] then
            targetIds[id] = true
            added = added + 1
        end
    end
    target.count = target.count + added

    ItemStack.invalidateFront(target)
    ItemStack.invalidateFront(stack)

    local stacks = self.data.stacks
    for i = 1, #stacks do
        if stacks[i] == stack then
            table.remove(stacks, i)
            break
        end
    end
    if slotMap[stack.slot] == stack then
        slotMap[stack.slot] = nil
    end

    self:_recomputeSlotCount()
    return true
end

function SlotGrid:swapStacks(firstStack, secondStack)
    if firstStack == nil or secondStack == nil or firstStack == secondStack then
        return false
    end
    local slotMap = self.slotMap
    if slotMap[firstStack.slot] ~= firstStack
            or slotMap[secondStack.slot] ~= secondStack then
        return false
    end
    local firstSlot, secondSlot = firstStack.slot, secondStack.slot
    firstStack.slot, secondStack.slot = secondSlot, firstSlot
    slotMap[firstSlot], slotMap[secondSlot] = secondStack, firstStack
    self:_recomputeSlotCount()
    return true
end

local APPLY_LAYOUT_WORDING = {
    malformed = "SlotGrid.applyLayout: malformed plan entry ",
    duplicateBefore = "SlotGrid.applyLayout: plan assigns slot ",
    duplicateAfter = " twice",
    stale = "SlotGrid.applyLayout: stale plan (stack no longer at its slot)",
    refused = "; layout refused",
}
local PLACE_STACKS_WORDING = {
    malformed = "SlotGrid.placeStacks: malformed entry ",
    duplicateBefore = "SlotGrid.placeStacks: two stacks on slot ",
    duplicateAfter = "",
    stale = "SlotGrid.placeStacks: stale plan (stack no longer at its slot)",
    refused = "; placement refused",
}

local function verifyPlanEntries(slotMap, plan, wording)
    local bySlot, planned = {}, {}
    for i = 1, plan.n do
        local entry = plan[i]
        local stack = type(entry) == "table" and entry.stack or nil
        local slot = type(entry) == "table" and entry.slot or nil
        if type(stack) ~= "table" or type(slot) ~= "number"
                or slot < 0 or slot ~= math.floor(slot) then
            Log.warn(wording.malformed .. tostring(i) .. wording.refused)
            return nil
        end
        if bySlot[slot] ~= nil then
            Log.warn(wording.duplicateBefore .. tostring(slot)
                .. wording.duplicateAfter .. wording.refused)
            return nil
        end
        if slotMap[stack.slot] ~= stack then
            Log.warn(wording.stale .. wording.refused)
            return nil
        end
        bySlot[slot] = stack
        planned[stack] = true
    end
    return bySlot, planned
end

function SlotGrid:applyLayout(plan)
    if plan == nil or type(plan.n) ~= "number" or plan.n <= 0 then
        return false
    end
    if self.pendingClaims ~= nil then

        return false
    end
    local stacks = self.data.stacks
    if type(stacks) ~= "table" then return false end

    local _, planned = verifyPlanEntries(self.slotMap, plan, APPLY_LAYOUT_WORDING)
    if planned == nil then return false end

    for i = 1, #stacks do
        local stack = stacks[i]
        if type(stack) == "table" and not planned[stack] then
            Log.warn("SlotGrid.applyLayout: plan does not cover every stack;"
                .. " layout refused")
            return false
        end
    end

    for i = 1, plan.n do
        plan[i].stack.slot = plan[i].slot
    end
    self:_rebuildSlotMap()
    self:_recomputeSlotCount()
    return true
end

function SlotGrid:placeStacks(plan)
    if plan == nil or type(plan.n) ~= "number" or plan.n <= 0 then
        return false
    end
    if self.pendingClaims ~= nil then return false end
    local stacks = self.data.stacks
    if type(stacks) ~= "table" then return false end

    local bySlot, planned = verifyPlanEntries(self.slotMap, plan,
        PLACE_STACKS_WORDING)
    if bySlot == nil then return false end

    for i = 1, #stacks do
        local stack = stacks[i]
        if type(stack) == "table" and not planned[stack]
                and bySlot[stack.slot] ~= nil then
            Log.warn("SlotGrid.placeStacks: slot " .. tostring(stack.slot)
                .. " is held by a stack outside the plan; placement refused")
            return false
        end
    end

    for i = 1, plan.n do
        plan[i].stack.slot = plan[i].slot
    end
    self:_rebuildSlotMap()
    self:_recomputeSlotCount()
    return true
end

function SlotGrid:reflowColumns(oldCols, newCols)
    local plan = ReflowPlan.build(self.data.stacks, oldCols, newCols)
    if plan == nil then return true end
    return self:applyLayout(plan) == true
end

function SlotGrid:splitToSlot(stack, subsetIds, slot)
    if stack == nil or subsetIds == nil or slot == nil or slot < 0 then
        return false
    end
    local subsetCount = #subsetIds
    if subsetCount == 0 then return false end
    for i = 1, subsetCount do
        if not stack.itemIDs[subsetIds[i]] then return false end
    end
    if subsetCount >= stack.count then
        return self:moveStack(stack, slot)
    end

    if slot == stack.slot then return true end

    local slotMap = self.slotMap
    local target = slotMap[slot]
    if target ~= nil then

        local front = ItemStack.frontItem(stack, self.inventory)
        if front == nil or not ItemStack.canAdd(target, front) then
            return false
        end
        local targetIds = target.itemIDs
        local moved = 0
        for i = 1, subsetCount do
            local id = subsetIds[i]
            stack.itemIDs[id] = nil
            if not targetIds[id] then
                targetIds[id] = true
                moved = moved + 1
            end
        end
        target.count = target.count + moved
        stack.count = stack.count - subsetCount
        ItemStack.invalidateFront(target)
        ItemStack.invalidateFront(stack)
        noteMutation(self)
        return true
    end

    local newStack = nil
    local dropped = 0
    for i = 1, subsetCount do
        local id = subsetIds[i]
        stack.itemIDs[id] = nil
        if newStack == nil then
            local item = self.inventory:getItemWithID(id)
            if item ~= nil then
                newStack = ItemStack.create(item, slot)
            else
                dropped = dropped + 1
            end
        else
            newStack.itemIDs[id] = true
            newStack.count = newStack.count + 1
        end
    end
    stack.count = stack.count - subsetCount
    ItemStack.invalidateFront(stack)
    if newStack == nil then

        if dropped > 0 then noteMutation(self) end
        return false
    end
    local stacks = self.data.stacks
    stacks[#stacks + 1] = newStack
    slotMap[slot] = newStack
    noteMutation(self)
    return true
end

function SlotGrid:claimSlotForItem(id, slot)
    if id == nil or slot == nil or slot < 0 then return end
    local claims = self.pendingClaims
    if claims == nil then
        claims = {}
        self.pendingClaims = claims
    end
    claims[id] = { slot = slot, ms = getTimestampMs() }
end

function SlotGrid:releaseClaim(id)
    local claims = self.pendingClaims
    if claims == nil or id == nil then return end
    claims[id] = nil

    for _ in pairs(claims) do return end
    self.pendingClaims = nil
end

function SlotGrid:validate()

    local identityClaims = scratchIdentityClaims
    local identityClaimCount = 0
    local stacks = self.data.stacks
    local inventory = self.inventory

    local excludeEquipped = isOwnMainInventory(self)
    local hotbar = excludeEquipped and getHotbar(self.playerNum) or nil

    local emptyRead = false
    if not excludeEquipped and type(stacks) == "table" and #stacks > 0
            and inventory ~= nil then
        local okItems, items = pcall(inventory.getItems, inventory)
        if okItems and items ~= nil and items:size() == 0 then
            local okPersisted, persisted = pcall(Persistence.isPersistent,
                inventory, self.playerNum)
            emptyRead = okPersisted and persisted == true
        end
    end
    local seen = scratchSeen
    local migrated = scratchMigrated
    wipe(seen)
    wipe(migrated)

    self:_snapshotItems()
    local itemById = self.itemById

    local changed = false
    local stackIndex = 1
    while stackIndex <= #stacks do
        local stack = stacks[stackIndex]
        local stackIds = type(stack) == "table" and stack.itemIDs or nil
        if type(stackIds) ~= "table" then

            Log.warn("validate: dropping malformed stack entry (bad itemIDs)")
            table.remove(stacks, stackIndex)
            changed = true
        else
            local kept = 0

            local migratedHere = 0
            local lastMigrant = nil
            for id in pairs(stackIds) do
                local drop = false
                if seen[id] then
                    drop = true
                else
                    local item = itemById[id]
                    if item == nil then

                        drop = not emptyRead
                    elseif isItemExcluded(item, hotbar, excludeEquipped) then
                        drop = true

                    elseif kept > 0 and kept >= StackRules.maxStackOf(item) then

                        drop = true
                        seen[id] = true
                        migrated[#migrated + 1] = item
                        migratedHere = migratedHere + 1
                        lastMigrant = item
                    elseif StackRules.bucketOf(item) ~= stack.bucket
                            or StackRules.identityOf(item) ~= stack.itemType then

                        drop = true

                        seen[id] = true
                        migrated[#migrated + 1] = item
                        migratedHere = migratedHere + 1
                        lastMigrant = item
                    end
                end
                if drop then
                    stackIds[id] = nil
                    changed = true

                    ItemStack.invalidateFront(stack)
                else
                    seen[id] = true
                    kept = kept + 1
                end
            end
            stack.count = kept
            if kept == 0 then

                if migratedHere == 1 and lastMigrant ~= nil then
                    self:claimSlotForItem(lastMigrant:getID(), stack.slot)
                    identityClaimCount = identityClaimCount + 1
                    identityClaims[identityClaimCount] = lastMigrant:getID()
                end
                table.remove(stacks, stackIndex)
            else
                stackIndex = stackIndex + 1
            end
        end
    end

    self:_rebuildSlotMap()

    for j = 1, #migrated do
        self:insertItem(migrated[j])
    end

    for j = 1, identityClaimCount do
        self:releaseClaim(identityClaims[j])
        identityClaims[j] = nil
    end
    wipe(migrated)

    if changed then
        noteMutation(self)
    end
end

function SlotGrid:consolidateLoose()
    local stacks = self.data.stacks
    local inventory = self.inventory
    if type(stacks) ~= "table" or inventory == nil then return false end

    local homeByKey = scratchHome
    wipe(homeByKey)
    for i = 1, #stacks do
        local stack = stacks[i]
        if type(stack) == "table" and type(stack.itemIDs) == "table" then
            local key = tostring(stack.itemType) .. "|" .. tostring(stack.bucket)
            local best = homeByKey[key]
            if best == nil or (stack.count or 0) > (best.count or 0) then
                homeByKey[key] = stack
            end
        end
    end

    local moved = false
    local stackIndex = 1
    while stackIndex <= #stacks do
        local stack = stacks[stackIndex]
        local absorbed = false
        if type(stack) == "table" and type(stack.itemIDs) == "table"
                and stack.count == 1 then
            local key = tostring(stack.itemType) .. "|" .. tostring(stack.bucket)
            local target = homeByKey[key]
            if target ~= nil and target ~= stack then
                local item = ItemStack.frontItem(stack, inventory)

                if item ~= nil and ItemStack.canAdd(target, item) then
                    ItemStack.add(target, item)

                    if self.slotMap[stack.slot] == stack then
                        self.slotMap[stack.slot] = nil
                    end
                    table.remove(stacks, stackIndex)
                    moved = true
                    absorbed = true
                end
            end
        end
        if not absorbed then stackIndex = stackIndex + 1 end
    end
    wipe(homeByKey)

    if moved then
        self:_rebuildSlotMap()
        noteMutation(self)
    end
    return moved
end

function SlotGrid:reconcile(snapshotIsCurrent)
    self.needsMoreReconcile = false

    self:_recomputeSlotCount()
    local inventory = self.inventory
    local items = inventory:getItems()
    if items == nil then return end
    if not snapshotIsCurrent or self.snapItems == nil then
        self:_snapshotItems()
    end
    local snapItems = self.snapItems
    local snapIds = self.snapIds

    local claims = self.pendingClaims
    if claims ~= nil then
        local now = getTimestampMs()
        local anyLive = false
        for id, claim in pairs(claims) do
            if now - claim.ms > PENDING_CLAIM_TTL_MS then
                claims[id] = nil
            else
                anyLive = true
            end
        end
        if not anyLive then
            self.pendingClaims = nil
            claims = nil
        end
    end

    local positioned = scratchSeen
    wipe(positioned)
    local stacks = self.data.stacks
    for i = 1, #stacks do
        for id in pairs(stacks[i].itemIDs) do
            if claims ~= nil and claims[id] ~= nil then
                positioned[id] = "claimed"
            else
                positioned[id] = true
            end
        end
    end

    local excludeEquipped = isOwnMainInventory(self)
    local hotbar = excludeEquipped and getHotbar(self.playerNum) or nil
    local inserted = 0
    local failed = 0
    local nowMs = claims ~= nil and getTimestampMs() or 0

    local retryWindow = isClient() and PENDING_CLAIM_RETRY_MS_MP
        or PENDING_CLAIM_RETRY_MS

    local outboundBusy = false
    if claims ~= nil then
        local TransferJobs = ComfyGrid.Interact
            and ComfyGrid.Interact.TransferJobs
        outboundBusy = TransferJobs ~= nil and TransferJobs.itemsFor ~= nil
            and TransferJobs.itemsFor(self.inventory) ~= nil
    end

    for snapIndex = 1, self.snapCount do
        local item = snapItems[snapIndex]
        local id = snapIds[snapIndex]

        if positioned[id] ~= true
                and not isItemExcluded(item, hotbar, excludeEquipped) then
            if inserted >= MAX_RECONCILE_INSERTS then
                self.needsMoreReconcile = true
                break
            end

            local claimed = false
            local held = false
            if claims ~= nil then
                local claim = claims[id]
                if claim ~= nil then
                    if self:insertItem(item, claim.slot) then
                        claims[id] = nil
                        claimed = true

                        self.claimLanded = true
                    elseif outboundBusy
                            or nowMs - claim.ms < retryWindow then

                        held = true
                        self.needsMoreReconcile = true
                    else
                        claims[id] = nil
                    end
                end
            end

            if not held then
                if claimed then
                    inserted = inserted + 1
                elseif positioned[id] ~= nil then

                elseif self:insertItem(item) then
                    inserted = inserted + 1
                else
                    failed = failed + 1
                end
            end
        end
    end

    if failed > 0 then
        self.refusalPasses = self.refusalPasses + 1
        if not self.refusalLogged then
            self.refusalLogged = true
            Log.warn("reconcile: " .. failed
                .. " item(s) refused insertion (container mismatch) in "
                .. describeContainer(self.inventory, self.playerNum)
                .. "; retrying every pass until they settle")
        end
    elseif self.refusalLogged then
        Log.info("reconcile: " .. describeContainer(self.inventory, self.playerNum)
            .. " settled after " .. self.refusalPasses .. " pass(es)")
        self.refusalLogged = false
        self.refusalPasses = 0
    end
end

function SlotGrid:_rebuildSlotMap()
    local slotMap = self.slotMap
    wipe(slotMap)
    local stacks = self.data.stacks
    local losers = nil
    for i = 1, #stacks do
        local stack = stacks[i]

        if type(stack) == "table" then
            local slot = stack.slot
            if type(slot) ~= "number" or slot < 0 or slotMap[slot] ~= nil then
                losers = losers or {}
                losers[#losers + 1] = stack
            else
                slotMap[slot] = stack
            end
        end
    end
    if losers then
        for i = 1, #losers do
            local stack = losers[i]
            local slot = self:firstFreeSlot()
            Log.warn("slot collision/corruption repaired; stack moved to slot "
                .. slot)
            stack.slot = slot
            slotMap[slot] = stack
        end
    end
end

function SlotGrid:_recomputeSlotCount()
    local slots = Capacity.slotsFor(self.inventory, self.playerNum)
    local occupied = self:_highestOccupiedSlot() + 1
    if occupied > slots then slots = occupied end

    local stacks = self.data.stacks
    if #stacks >= slots then
        slots = #stacks + 1
    end
    self.slots = slots
end

function SlotGrid:_highestOccupiedSlot()
    local maxSlot = -1
    local stacks = self.data.stacks
    for i = 1, #stacks do

        local stack = stacks[i]
        local slot = type(stack) == "table" and stack.slot or nil
        if type(slot) == "number" and slot > maxSlot then maxSlot = slot end
    end
    return maxSlot
end
