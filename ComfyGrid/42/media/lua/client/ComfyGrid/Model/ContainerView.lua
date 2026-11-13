--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/ActionQueue"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ContainerView = {}
ComfyGrid.Model.ContainerView = ContainerView

function ContainerView.isView(container)
    if container == nil then return false end
    local okType, kind = pcall(container.getType, container)
    if not okType or tostring(kind) == "floor" then return false end
    local okParent, parent = pcall(container.getParent, container)
    if not okParent or parent ~= nil then return false end
    local okHolder, holder = pcall(container.getContainingItem, container)
    if not okHolder or holder ~= nil then return false end
    if container.getVehiclePart ~= nil then
        local okPart, part = pcall(container.getVehiclePart, container)
        if not okPart or part ~= nil then return false end
    end
    return true
end

function ContainerView.buttonFor(container, playerNum)
    if container == nil or playerNum == nil then return nil end
    for _, pageOf in ipairs({ getPlayerLoot, getPlayerInventory }) do
        local okPage, page = pcall(pageOf, playerNum)
        local buttons = okPage and page ~= nil and page.backpacks or nil
        if type(buttons) == "table" then
            for i = 1, #buttons do
                if buttons[i] ~= nil and buttons[i].inventory == container then
                    return buttons[i], page
                end
            end
        end
    end
    return nil
end

function ContainerView.buttonName(view, playerNum)
    local button = ContainerView.buttonFor(view, playerNum)
    local name = button ~= nil and button.name or nil
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

function ContainerView.sourcesOf(view, playerNum, out)
    out = out or {}
    for container in pairs(out) do out[container] = nil end
    local _, page = ContainerView.buttonFor(view, playerNum)
    local buttons = page ~= nil and page.backpacks or nil
    if type(buttons) ~= "table" then return out end
    for i = 1, #buttons do
        local container = buttons[i] ~= nil and buttons[i].inventory or nil
        if container ~= nil and container ~= view
                and not ContainerView.isView(container) then
            out[container] = true
        end
    end
    return out
end

local VIEW_TRANSFER_GRACE_MS = 1500
local lastViewTransferAt = {}

function ContainerView.pageShows(page, item)
    if page == nil or item == nil or type(page.backpacks) ~= "table" then return false end
    for i = 1, #page.backpacks do
        local container = page.backpacks[i] ~= nil and page.backpacks[i].inventory or nil
        if container ~= nil and ContainerView.isView(container) then
            local okContains, shown = pcall(container.contains, container, item)
            if okContains and shown == true then return true end
        end
    end
    return false
end

function ContainerView.transferShownByView(action, loot)
    local shown = action.comfyShownByView
    if shown == nil then
        shown = ContainerView.pageShows(loot, action.item)
        action.comfyShownByView = shown
    end
    return shown
end

function ContainerView.noteViewTransfer(playerNum)
    lastViewTransferAt[playerNum or 0] = getTimestampMs()
end

function ContainerView.forgetViewTransfers(playerNum)
    lastViewTransferAt[playerNum or 0] = nil
end

function ContainerView.viewTransferUnderway(playerNum)
    playerNum = playerNum or 0
    local at = lastViewTransferAt[playerNum]
    if at ~= nil and getTimestampMs() - at < VIEW_TRANSFER_GRACE_MS then return true end
    local actions = ComfyGrid.Core.ActionQueue.queuedActions(getSpecificPlayer(playerNum))
    if type(actions) ~= "table" then return false end
    local loot = getPlayerLoot(playerNum)
    for i = 1, #actions do
        local action = actions[i]
        if action ~= nil and action.Type == "ISInventoryTransferAction"
                and ContainerView.transferShownByView(action, loot) then
            return true
        end
    end
    return false
end

return ContainerView
