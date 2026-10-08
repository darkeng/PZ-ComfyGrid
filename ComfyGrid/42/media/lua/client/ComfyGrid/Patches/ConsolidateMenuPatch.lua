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
require "ComfyGrid/Model/ContainerName"
require "ComfyGrid/Interact/ItemApply"

ComfyGrid = ComfyGrid or {}
local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local ContainerName = ComfyGrid.Model.ContainerName

local function containerLabel(inv, playerObj)
    if inv == nil then return nil end
    if playerObj ~= nil and inv == playerObj:getInventory() then return nil end
    local okC, containing = pcall(inv.getContainingItem, inv)
    if okC and containing ~= nil then
        local okN, name = pcall(containing.getName, containing)
        if okN and name ~= nil then return name end
    end
    return ContainerName.titleFor(inv)
end

local function entryLabel(item, playerObj)
    local pct = math.floor(item:getCurrentUsesFloat() * 100)
    local entryText = item:getName() .. " (" .. pct
        .. getText("ContextMenu_FullPercent") .. ")"
    local where = containerLabel(item:getContainer(), playerObj)
    if where ~= nil then
        entryText = entryText .. " - " .. where
    end
    return entryText
end

local function pourOptionText(item)
    local optionText = getText("ContextMenu_Pour_into")
    if item.getConsolidateOption ~= nil and item:getConsolidateOption() then
        optionText = getText(item:getConsolidateOption())
    end
    return optionText
end

local function pourAllInto(playerObj, target, sources, logTag)
    local ItemApply = ComfyGrid.Interact and ComfyGrid.Interact.ItemApply
    if ItemApply == nil then return end
    local ok, err = pcall(ItemApply.tryApply, sources, target, playerObj, true)
    if not ok then
        Log.warn("ConsolidateMenu: " .. logTag .. " failed: " .. tostring(err))
    end
end

local function onPourInto(playerObj, sourceItem, target)
    pourAllInto(playerObj, target, { sourceItem }, "pour")
end

local function onPourAll(playerObj, sourceItem, candidates)
    if #candidates == 0 then return end

    local sources = { sourceItem }
    for i = 2, #candidates do
        sources[#sources + 1] = candidates[i]
    end
    pourAllInto(playerObj, candidates[1], sources, "merge-all")
end

local function mergeableMembers(entry)
    if entry == nil or instanceof(entry, "InventoryItem") then return nil end
    local items = entry.items
    if type(items) ~= "table" or #items < 3 then return nil end
    local seen, out = {}, {}
    for i = 1, #items do
        local member = items[i]
        local id = (member ~= nil and member.getID ~= nil) and member:getID()
            or nil
        if id ~= nil and not seen[id] then
            seen[id] = true

            if member.canConsolidate ~= nil and member:canConsolidate()
                    and member.getCurrentUsesFloat ~= nil then
                local uses = member:getCurrentUsesFloat()

                if uses > 0 and uses < 1 then out[#out + 1] = member end
            end
        end
    end
    if #out < 2 then return nil end
    table.sort(out, function(a, b)
        return a:getCurrentUsesFloat() > b:getCurrentUsesFloat()
    end)
    return out
end

local function onMergeStack(playerObj, members)
    if members == nil or #members < 2 then return end
    local sources = {}
    for i = 2, #members do
        sources[#sources + 1] = members[i]
    end
    pourAllInto(playerObj, members[1], sources, "tile merge")
end

local function fillMergeOption(playerNum, context, items)
    if context == nil or type(items) ~= "table" or #items ~= 1 then return end
    if ComfyGrid.Interact == nil or ComfyGrid.Interact.ItemApply == nil then
        return
    end
    local members = mergeableMembers(items[1])
    if members == nil then return end
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil then return end

    context:insertOptionBefore(pourOptionText(members[1]),
        Text.tr("IGUI_ComfyGrid_MergeStack", "Consolidate this tile"),
        playerObj, onMergeStack, members)
end

Events.OnGameBoot.Add(function()
    if ISInventoryPaneContextMenu == nil then return end

    if ISInventoryPaneContextMenu._comfyConsolidatePatched then return end
    ISInventoryPaneContextMenu._comfyConsolidatePatched = true

    local og_checkConsolidate = ISInventoryPaneContextMenu.checkConsolidate

    ISInventoryPaneContextMenu.checkConsolidate = function(drainable, playerObj,
            context, previousPourInto)
        local ItemApply = ComfyGrid.Interact and ComfyGrid.Interact.ItemApply
        if ItemApply == nil or ItemApply.pourCandidates == nil
                or drainable == nil or playerObj == nil or context == nil then
            return og_checkConsolidate(drainable, playerObj, context,
                previousPourInto)
        end
        local ok, candidates = pcall(ItemApply.pourCandidates, drainable,
            playerObj, previousPourInto)
        if not ok then
            Log.warn("ConsolidateMenu: candidate scan failed: "
                .. tostring(candidates))
            return og_checkConsolidate(drainable, playerObj, context,
                previousPourInto)
        end
        if candidates == nil or #candidates == 0 then return end

        local parent = context:addOption(pourOptionText(drainable), nil, nil)
        local subMenu = context:getNew(context)
        context:addSubMenu(parent, subMenu)
        if #candidates > 1 then
            subMenu:addOption(getText("ContextMenu_MergeAll"), playerObj,
                onPourAll, drainable, candidates)
        end
        for i = 1, #candidates do
            local target = candidates[i]
            subMenu:addOption(entryLabel(target, playerObj), playerObj,
                onPourInto, drainable, target)
        end
    end

    if not ComfyGrid._consolidateMergeHooked then
        ComfyGrid._consolidateMergeHooked = true
        Events.OnFillInventoryObjectContextMenu.Add(fillMergeOption)
    end
end)
