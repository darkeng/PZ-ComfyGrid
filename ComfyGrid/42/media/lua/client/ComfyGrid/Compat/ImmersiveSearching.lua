--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Util"
require "ComfyGrid/Compat/Warnings"
require "ComfyGrid/Model/ItemVeil"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Compat = ComfyGrid.Compat or {}
local Adapter = {}
ComfyGrid.Compat.ImmersiveSearching = Adapter

local Log = ComfyGrid.Core.Log
local Util = ComfyGrid.Core.Util
local Warnings = ComfyGrid.Compat.Warnings
local ItemVeil = ComfyGrid.Model.ItemVeil

local MOD_ID = "ImmersiveSearching"
Adapter.PROVIDER = "ImmersiveSearching"

function Adapter.isUsable(api)
    return type(api) == "table" and type(api.isSearched) == "function"
end

function Adapter.isVeiledBy(api, player, container, item)
    if api == nil or player == nil or container == nil or item == nil then return false end
    local progressByContainer = api.Items
    if api.Searched == nil or progressByContainer == nil then return false end
    if api.isSearched(player, container) then return false end
    local progress = progressByContainer[container]
    if progress == nil then return true end
    local id = item:getID()
    local initial, found = progress.Initial, progress.Searched
    if initial == nil or initial[id] ~= true then return false end
    return found == nil or found[id] ~= true
end

function Adapter.provider(container, item, playerNum)
    return Adapter.isVeiledBy(ImmersiveSearching, getSpecificPlayer(playerNum or 0),
        container, item)
end

local SEARCH_ACTION = "ImmersiveSearching_ISSearch"
local SEARCH_LEAD_IN = 0.2

function Adapter.progressBy(action, container, item)
    if action == nil or action.Type ~= SEARCH_ACTION or action.container ~= container then
        return nil
    end
    local order = action.revealOrder
    if type(order) ~= "table" or #order == 0 or type(action.getJobDelta) ~= "function" then
        return nil
    end
    local jobDelta = action:getJobDelta()
    if type(jobDelta) ~= "number" then return nil end
    local progress = Util.clamp((jobDelta - SEARCH_LEAD_IN) / (1 - SEARCH_LEAD_IN), 0, 1)
    local position = #order * progress
    local index = math.floor(position) + 1
    if order[index] ~= item then return nil end
    return position - math.floor(position)
end

local function isModIcon(texture)
    if texture == nil or texture.getName == nil then return false end
    local ok, name = pcall(texture.getName, texture)
    return ok and name ~= nil and string.find(tostring(name), MOD_ID, 1, true) ~= nil
end

function Adapter.claimButtonIcons(buttons, playerNum)
    if type(buttons) ~= "table" then return end
    for i = 1, #buttons do
        local button = buttons[i]
        if button ~= nil then
            local veiled = nil
            if isModIcon(button.textureOverride) then
                button.textureOverride = nil
                if not ItemVeil.isCarried(button.inventory, playerNum) then veiled = true end
            end
            button.comfyVeiled = veiled
        end
    end
end

function Adapter.claimPageIcons(playerNum)
    local pages = { getPlayerInventory(playerNum), getPlayerLoot(playerNum) }
    for i = 1, #pages do
        local page = pages[i]
        local pane = page ~= nil and page.inventoryPane or nil
        if pane ~= nil and pane.mode == "comfy" then
            Adapter.claimButtonIcons(page.backpacks, playerNum)
        end
    end
end

local function followButtonIcons(api)
    if ComfyGrid._immersiveSearchingButtonsFollowed then return end
    if type(api.updateButtons) ~= "function" then return end
    ComfyGrid._immersiveSearchingButtonsFollowed = true
    local original = api.updateButtons
    api.updateButtons = function(player, playerNum, ...)
        original(player, playerNum, ...)
        local ok, err = pcall(Adapter.claimPageIcons, playerNum or 0)
        if not ok then Log.warn("ImmersiveSearching button icons: " .. tostring(err)) end
    end
end

function Adapter.install()
    local api = ImmersiveSearching
    if api == nil then return false end
    if not Adapter.isUsable(api) then
        if Warnings.isModActive(MOD_ID) then
            Log.warn("ImmersiveSearching is active but its API is not the one this "
                .. "version knows: its hidden items will show on the board")
        end
        return false
    end
    followButtonIcons(api)
    return ItemVeil.register(Adapter.PROVIDER, Adapter.provider, Adapter.progressBy)
end

if not ComfyGrid._immersiveSearchingHooked then
    ComfyGrid._immersiveSearchingHooked = true
    Events.OnGameStart.Add(function()
        local adapter = ComfyGrid.Compat and ComfyGrid.Compat.ImmersiveSearching
        if adapter ~= nil then
            local ok, err = pcall(adapter.install)
            if not ok then Log.warn("ImmersiveSearching adapter: " .. tostring(err)) end
        end
    end)
end

return Adapter
