--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.7
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "Foraging/forageSystem"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Patches = ComfyGrid.Patches or {}
local ForageDropPatch = {}
ComfyGrid.Patches.ForageDropPatch = ForageDropPatch

local PREFIX = "[ComfyGrid] "

local function staleEntriesIn(container)
    local okItems, items = pcall(container.getItems, container)
    if not okItems or items == nil then return nil end
    local okSize, size = pcall(items.size, items)
    if not okSize or type(size) ~= "number" then return nil end
    local out = nil
    for i = 0, size - 1 do
        local okGet, item = pcall(items.get, items, i)
        if okGet and item ~= nil and item.getContainer ~= nil then
            local okOwner, owner = pcall(item.getContainer, item)
            local okWorld, world = pcall(item.getWorldItem, item)
            if okOwner and owner == nil and okWorld and world ~= nil then
                out = out or {}
                out[#out + 1] = item
            end
        end
    end
    return out
end

function ForageDropPatch.sweep(container)
    if container == nil then return 0 end
    local stale = staleEntriesIn(container)
    if stale == nil then return 0 end
    local evicted = 0
    for i = 1, #stale do

        local okRemove = pcall(container.Remove, container, stale[i])
        if okRemove then
            evicted = evicted + 1

            pcall(sendRemoveItemFromContainer, container, stale[i])
        end
    end
    if evicted > 0 then
        print(PREFIX .. "forage repair: dropped " .. tostring(evicted)
            .. " stale inventory entries (vanilla forageSystem:1667-1671)")
    end
    return evicted
end

function ForageDropPatch.afterDrop(character, target)
    local main = nil
    if character ~= nil then
        local okInv, inventory = pcall(character.getInventory, character)
        if okInv then main = inventory end
    end
    local evicted = ForageDropPatch.sweep(main)
    if target ~= nil and target ~= main then
        evicted = evicted + ForageDropPatch.sweep(target)
    end
    return evicted
end

function ForageDropPatch.apply()
    if forageSystem == nil or forageSystem.addOrDropItems == nil then
        return false
    end
    if forageSystem._comfyForageDropPatched then return false end
    forageSystem._comfyForageDropPatched = true

    local og_addOrDropItems = forageSystem.addOrDropItems

    forageSystem.addOrDropItems = function(character, inventory, items)

        local result = og_addOrDropItems(character, inventory, items)
        pcall(ForageDropPatch.afterDrop, character, inventory)
        return result
    end
    return true
end

ForageDropPatch.apply()

Events.OnGameBoot.Add(function() ForageDropPatch.apply() end)
