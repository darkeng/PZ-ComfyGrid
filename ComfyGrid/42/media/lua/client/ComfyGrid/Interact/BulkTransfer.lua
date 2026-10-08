--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Core/Notify"
require "ComfyGrid/Core/GameMode"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/Interact/TransferJobs"
require "ComfyGrid/Interact/Transfer"
require "ComfyGrid/Interact/QuickMove"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local BulkTransfer = {}
ComfyGrid.Interact.BulkTransfer = BulkTransfer

local Text = ComfyGrid.Core.Text
local Notify = ComfyGrid.Core.Notify
local GameMode = ComfyGrid.Core.GameMode
local ContainerModel = ComfyGrid.Model.ContainerModel
local Transfer = ComfyGrid.Interact.Transfer
local QuickMove = ComfyGrid.Interact.QuickMove
local TransferJobs = ComfyGrid.Interact.TransferJobs

BulkTransfer.OK      = "ok"
BulkTransfer.NOTHING = "nothing"
BulkTransfer.BUSY    = "busy"
BulkTransfer.NO_DEST = "nodest"
BulkTransfer.REFUSED = "refused"
BulkTransfer.HERE    = "here"

local function transferQueued(playerObj)
    local actions = TransferJobs.queuedActions(playerObj)
    if actions == nil then return false end
    for i = 1, #actions do
        local action = actions[i]
        if action ~= nil and action.Type == "ISInventoryTransferAction" then
            return true
        end
    end
    return false
end

function BulkTransfer.typeMap(container)
    if container == nil then return nil end
    local ok, items = pcall(container.getItems, container)
    if not ok or items == nil then return nil end
    local result = {}
    for i = 1, items:size() do
        local item = items:get(i - 1)
        if item ~= nil then
            local okT, itemType = pcall(item.getFullType, item)
            if okT and itemType ~= nil then
                local bucket = result[itemType]
                if bucket == nil then
                    bucket = {}
                    result[itemType] = bucket
                end
                bucket[#bucket + 1] = item
            end

            local okX, extra = pcall(item.getClothingItemExtra, item)
            if okX and extra ~= nil and moduleDotType ~= nil then
                for j = 1, extra:size() do
                    local okA, alias = pcall(moduleDotType,
                        item:getModule(), extra:get(j - 1))
                    if okA and alias ~= nil then
                        local bucket = result[alias]
                        if bucket == nil then
                            bucket = {}
                            result[alias] = bucket
                        end
                        bucket[#bucket + 1] = item
                    end
                end
            end
        end
    end
    return result
end

function BulkTransfer.planStow(src, dest)
    local list, map = {}, {}
    if src == nil or dest == nil or src == dest then return list, map end
    local destTypes = BulkTransfer.typeMap(dest)
    local srcTypes = BulkTransfer.typeMap(src)
    if destTypes == nil or srcTypes == nil then return list, map end
    for itemType in pairs(destTypes) do
        local candidates = srcTypes[itemType]
        if candidates ~= nil then
            for i = 1, #candidates do
                local item = candidates[i]

                if map[item] == nil then
                    local okF, favorite = pcall(item.isFavorite, item)
                    local okE, equipped = pcall(item.isEquipped, item)
                    if okF and okE and not favorite and not equipped then
                        map[item] = true
                        list[#list + 1] = item
                    end
                end
            end
        end
    end
    return list, map
end

function BulkTransfer.planEmpty(src, dest, playerObj, playerNum)
    local list, map = {}, {}
    if src == nil or dest == nil or src == dest or playerObj == nil then
        return list, map, nil, 0
    end
    local ok, items = pcall(src.getItems, src)
    if not ok or items == nil then return list, map, nil, 0 end
    local total = items:size()

    local fromPlayer = QuickMove.isPlayerSide(src, playerObj)

    local toFloor = Transfer.isFloor(dest)

    local hotBar, ownMain
    if fromPlayer then
        hotBar = getPlayerHotbar ~= nil and getPlayerHotbar(playerNum) or nil
        ownMain = src == playerObj:getInventory()
    end

    local heavy = nil
    for i = 1, total do
        local item = items:get(i - 1)
        if item ~= nil then
            local keep = true
            if fromPlayer then
                if item:isEquipped() then keep = false end
                if keep and ownMain
                        and (item:isItemType(ItemType.KEY_RING)
                            or item:hasTag(ItemTag.KEY_RING)) then
                    keep = false
                end
                if keep and hotBar ~= nil and hotBar:isInHotbar(item) then
                    keep = false
                end
                if keep and item:isFavorite() then keep = false end
                if keep and toFloor and instanceof(item, "Moveable")
                        and item:getSpriteGrid() == nil
                        and not item:CanBeDroppedOnFloor() then
                    keep = false
                end
            else
                if item:isUnwanted(playerObj) then keep = false end

                if keep and not toFloor and isForceDropHeavyItem ~= nil
                        and isForceDropHeavyItem(item) then
                    heavy = item
                    keep = false
                end
            end
            if keep and map[item] == nil then
                map[item] = true
                list[#list + 1] = item
            end
        end
    end
    return list, map, heavy, total
end

local function sortLikeVanilla(items, playerNum)
    local page = getPlayerInventory(playerNum)
    local pane = page ~= nil and page.inventoryPane or nil
    if pane ~= nil and pane.sortItemsByTypeAndWeight ~= nil then
        pcall(pane.sortItemsByTypeAndWeight, pane, items)
    end
end

function BulkTransfer.planSpread(src, dests, playerObj, playerNum)
    local groups, list, map = {}, {}, {}
    if src == nil or dests == nil or playerObj == nil then
        return groups, map, list
    end
    local pool = BulkTransfer.typeMap(src)
    if pool == nil then return groups, map, list end

    local taken = {}
    for d = 1, #dests do
        local dest = dests[d]
        local destMap = dest ~= nil and BulkTransfer.typeMap(dest) or nil
        if destMap ~= nil then

            local candidates, seen = {}, {}
            for itemType in pairs(destMap) do
                local items = pool[itemType]
                if items ~= nil then
                    for i = 1, #items do
                        local item = items[i]
                        if not taken[item] and not seen[item]
                                and not item:isFavorite()
                                and not item:isEquipped() then
                            seen[item] = true
                            candidates[#candidates + 1] = item
                        end
                    end
                end
            end
            sortLikeVanilla(candidates, playerNum)

            local picked, weight = {}, 0.0
            for i = 1, #candidates do
                local item = candidates[i]
                local okW, itemWeight = pcall(item.getUnequippedWeight, item)
                if not okW or itemWeight == nil then itemWeight = 0 end
                local okR, room = pcall(dest.hasRoomFor, dest, playerObj,
                    weight + itemWeight)
                if not (okR and room) then break end
                picked[#picked + 1] = item
                taken[item] = true
                map[item] = true
                list[#list + 1] = item
                weight = weight + itemWeight
            end
            if #picked > 0 then
                groups[#groups + 1] = { dest = dest, items = picked }
            end
        end
    end
    return groups, map, list
end

local MAX_PLANS = 64
local planCache = {}
local planCount = 0

function BulkTransfer.cachedPlanCount()
    return planCount, MAX_PLANS
end

local KINDS = { stow = true, empty = true, floor = true, spread = true }

local spreadDests = {}

local function changeStampOf(inventory, playerNum)
    if inventory == nil or ContainerModel == nil then return -1 end
    local ok, model = pcall(ContainerModel.getOrCreate, inventory, playerNum)
    if not ok or model == nil or model.grid == nil then return -1 end
    return model.grid.changeCount or -1
end

function BulkTransfer.plan(kind, own, playerNum)
    if own == nil or KINDS[kind] == nil then return nil end
    playerNum = playerNum or 0
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil then return nil end

    local other, dests
    if kind == "floor" then

        if Transfer.isFloor(own) then
            return nil, nil, nil, nil, playerObj
        end
        other = ISInventoryPage.GetFloorContainer(playerNum)
    elseif kind == "spread" then
        if QuickMove == nil or QuickMove.otherSideContainers == nil then
            return nil, nil, nil, nil, playerObj
        end
        for i = #spreadDests, 1, -1 do spreadDests[i] = nil end
        dests = QuickMove.otherSideContainers(own, playerObj, playerNum,
            spreadDests)

        other = dests[1]
    else
        if QuickMove == nil or QuickMove.destinationFor == nil then
            return nil, nil, nil, nil, playerObj
        end
        other = QuickMove.destinationFor(own, playerObj, playerNum)
    end
    if other == nil or other == own then
        return nil, nil, nil, nil, playerObj
    end
    local src, dest
    if kind == "stow" then src, dest = other, own else src, dest = own, other end

    local ownStamp = changeStampOf(own, playerNum)

    local destCount = dests ~= nil and #dests or 1
    local otherStamp = 0
    if dests ~= nil then
        for i = 1, destCount do
            otherStamp = otherStamp + changeStampOf(dests[i], playerNum)
        end
    else
        otherStamp = changeStampOf(other, playerNum)
    end
    local entry = planCache[own]
    if entry ~= nil and entry.kind == kind and entry.other == other
            and entry.destCount == destCount
            and entry.ownStamp == ownStamp
            and entry.otherStamp == otherStamp then
        return entry.list, entry.map, src, dest, playerObj, entry.extra
    end
    local list, map, extra
    if kind == "stow" then
        list, map = BulkTransfer.planStow(src, dest)
    elseif kind == "spread" then
        local groups
        groups, map, list = BulkTransfer.planSpread(src, dests, playerObj,
            playerNum)
        extra = { groups = groups }
    else
        local heavy, total
        list, map, heavy, total = BulkTransfer.planEmpty(src, dest, playerObj,
            playerNum)
        extra = { heavy = heavy, total = total }
    end
    if planCache[own] == nil then
        if planCount >= MAX_PLANS then
            planCache = {}
            planCount = 0
        end
        planCount = planCount + 1
    end
    planCache[own] = {
        kind = kind, other = other, destCount = destCount,
        ownStamp = ownStamp, otherStamp = otherStamp,
        list = list, map = map, extra = extra,
    }
    return list, map, src, dest, playerObj, extra
end

local function refuse(model, playerObj)
    if model == nil or model.inventory == nil then
        return BulkTransfer.REFUSED
    end

    if GameMode.isTutorial() then return BulkTransfer.REFUSED end

    if isGamePaused ~= nil and isGamePaused() then
        return BulkTransfer.REFUSED
    end
    if playerObj == nil then return BulkTransfer.REFUSED end
    if transferQueued(playerObj) then return BulkTransfer.BUSY end
    return nil
end

local function run(kind, model, playerNum)
    playerNum = playerNum or 0
    local playerObj = getSpecificPlayer(playerNum)
    local refusal = refuse(model, playerObj)
    if refusal ~= nil then return refusal end

    if kind == "floor" then
        if Transfer.isFloor(model.inventory) then return BulkTransfer.HERE end
    end

    local planned, _, src, dest, _, extra =
        BulkTransfer.plan(kind, model.inventory, playerNum)
    if src == nil or dest == nil then return BulkTransfer.NO_DEST end

    if Transfer.isFloor(dest)
            and not Transfer.canDropOutsideVehicle(playerObj) then
        return BulkTransfer.NO_DEST
    end

    if planned == nil or #planned == 0 then

        if kind == "empty" and extra ~= nil and extra.heavy ~= nil
                and extra.total == 1 then
            local _, carried = Transfer.escalateHeavyItems({ extra.heavy },
                dest, playerObj)
            if carried > 0 then return BulkTransfer.OK end
        end
        return BulkTransfer.NOTHING
    end

    local toMove = {}
    for i = 1, #planned do toMove[i] = planned[i] end

    sortLikeVanilla(toMove, playerNum)

    local queued = Transfer.moveItems(toMove, dest, playerObj)
    if queued == 0 then return BulkTransfer.NOTHING end
    return BulkTransfer.OK
end

function BulkTransfer.stow(model, playerNum)
    return run("stow", model, playerNum)
end

function BulkTransfer.empty(model, playerNum)
    return run("empty", model, playerNum)
end

function BulkTransfer.trashObjectFor(inventory)
    if inventory == nil then return nil end

    if isClient() then
        local okO, opts = pcall(getServerOptions)
        if not okO or opts == nil then return nil end
        local okB, allowed = pcall(opts.getBoolean, opts, "TrashDeleteAll")
        if not okB or not allowed then return nil end
    end
    local ok, parent = pcall(inventory.getParent, inventory)
    if not ok or parent == nil then return nil end
    if not instanceof(parent, "IsoObject") then return nil end
    local okS, sprite = pcall(parent.getSprite, parent)
    if not okS or sprite == nil then return nil end
    local okP, props = pcall(sprite.getProperties, sprite)
    if not okP or props == nil then return nil end
    local okH, has = pcall(props.has, props, "IsTrashCan")
    return (okH and has) and parent or nil
end

local function onConfirmTrash(_target, button, object, playerNum)
    if button.internal ~= "YES" then return end
    local playerObj = getSpecificPlayer(playerNum or 0)
    if playerObj == nil or object == nil then return end
    sendClientCommand(playerObj, "object", "emptyTrash", {
        x = object:getX(), y = object:getY(), z = object:getZ(),
        index = object:getObjectIndex(),
    })
end

function BulkTransfer.emptyTrash(model, playerNum)
    playerNum = playerNum or 0
    local playerObj = getSpecificPlayer(playerNum)
    local refusal = refuse(model, playerObj)
    if refusal ~= nil then return refusal end

    local object = BulkTransfer.trashObjectFor(model.inventory)
    if object == nil then return BulkTransfer.NO_DEST end
    local okE, empty = pcall(model.inventory.isEmpty, model.inventory)
    if okE and empty then return BulkTransfer.NOTHING end

    local Confirm = ComfyGrid.UI and ComfyGrid.UI.Chrome
        and ComfyGrid.UI.Chrome.Confirm
    if Confirm == nil or Confirm.open == nil then return BulkTransfer.NO_DEST end
    Confirm.open({
        text = getText("IGUI_ConfirmDeleteItems"),
        playerNum = playerNum,
        onYes = function()
            onConfirmTrash(nil, { internal = "YES" }, object, playerNum)
        end,
    })

    return BulkTransfer.OK
end

function BulkTransfer.spread(model, playerNum)
    playerNum = playerNum or 0
    local playerObj = getSpecificPlayer(playerNum)
    local refusal = refuse(model, playerObj)
    if refusal ~= nil then return refusal end

    local _, _, src, dest, _, extra =
        BulkTransfer.plan("spread", model.inventory, playerNum)
    if src == nil or dest == nil then return BulkTransfer.NO_DEST end
    local groups = extra ~= nil and extra.groups or nil
    if groups == nil or #groups == 0 then return BulkTransfer.NOTHING end

    local queued = 0
    for i = 1, #groups do
        local group = groups[i]

        local items = {}
        for j = 1, #group.items do items[j] = group.items[j] end

        queued = queued + (Transfer.moveItems(items, group.dest, playerObj) or 0)
    end
    if queued == 0 then return BulkTransfer.NOTHING end
    return BulkTransfer.OK
end

function BulkTransfer.dropToFloor(model, playerNum)
    return run("floor", model, playerNum)
end

local WORDS = {
    [BulkTransfer.NOTHING] = {
        stow  = { "IGUI_ComfyGrid_ChipNothingToStow",
                  "Nothing of these kinds to bring." },
        empty = { "IGUI_ComfyGrid_ChipNothingToSend",
                  "Nothing to send: the rest is worn, favourited or in the hotbar." },
        trash = { "IGUI_ComfyGrid_ChipBinEmpty", "This bin is already empty." },
        spread = { "IGUI_ComfyGrid_ChipNothingToSpread",
                  "Nothing here has a container that already keeps it." },
        floor = { "IGUI_ComfyGrid_ChipNothingToDrop",
                  "Nothing to drop: the rest is worn, favourited or in the hotbar." },
    },
    [BulkTransfer.NO_DEST] = {
        stow  = { "IGUI_ComfyGrid_ChipNoOtherSide",
                  "Nothing open to bring from." },
        empty = { "IGUI_ComfyGrid_ChipNowhereToSend",
                  "Nowhere to send it." },
        spread = { "IGUI_ComfyGrid_ChipNothingOpen",
                  "Open the containers to put these away in." },

        floor = { "IGUI_ComfyGrid_ChipNoFloorReach",
                  "Can't reach the floor from here." },
    },
    [BulkTransfer.HERE] = {
        floor = { "IGUI_ComfyGrid_ChipAlreadyFloor",
                  "This is already on the floor." },
    },
}

function BulkTransfer.report(outcome, playerNum, kind)
    if outcome == BulkTransfer.BUSY then
        Notify.say(playerNum,
            Text.tr("IGUI_ComfyGrid_ChipBusy",
                "Still moving things - try again in a moment."))
        return
    end

    local byKind = WORDS[outcome]
    local words = byKind ~= nil and byKind[kind] or nil
    if words == nil then return end
    Notify.say(playerNum, Text.tr(words[1], words[2]))
end
