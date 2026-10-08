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
require "ComfyGrid/Settings"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local Unequip = {}
ComfyGrid.Interact.Unequip = Unequip

local Log = ComfyGrid.Core.Log

local unequipFailLogged = false
local detachFailLogged = false

local function modifierHeld()
    local Settings = ComfyGrid.Settings
    if Settings == nil or Settings.transferModifierHeld == nil then
        return false
    end
    local ok, isHeld = pcall(Settings.transferModifierHeld)
    return ok and isHeld == true
end

local function gestureIsDoubleClick()
    local Settings = ComfyGrid.Settings
    if Settings == nil or Settings.transferIsDoubleClick == nil then
        return false
    end
    local ok, isDoubleClick = pcall(Settings.transferIsDoubleClick)
    return ok and isDoubleClick == true
end

local function clickWindowMs()
    local GridView = ComfyGrid.UI and ComfyGrid.UI.GridView
    return (GridView ~= nil and GridView.CLICK_DELAY_MS) or 260
end

local hotbarOf = ComfyGrid.Core.Input.hotbarOf

function Unequip.sendBack(items, playerNum, how)
    if items == nil then return 0 end
    local playerObj = playerNum ~= nil and getSpecificPlayer(playerNum) or nil
    if playerObj == nil then return 0 end
    local hotbar = how == "detach" and hotbarOf(playerNum) or nil
    local acted = 0
    for i = 1, #items do
        local item = items[i]
        if item ~= nil then
            if how == "detach" then

                if hotbar ~= nil and hotbar.removeItem ~= nil then
                    local ok, err = pcall(hotbar.removeItem, hotbar, item, true)
                    if ok then
                        acted = acted + 1
                    elseif not detachFailLogged then
                        detachFailLogged = true
                        Log.warn("Unequip: detach failed (logged once): "
                            .. tostring(err))
                    end
                end
            else

                local okE, equipped = pcall(playerObj.isEquipped, playerObj, item)
                if okE and equipped then
                    local ok, err = pcall(
                        ISInventoryPaneContextMenu.unequipItem, item, playerNum)
                    if ok then
                        acted = acted + 1
                    elseif not unequipFailLogged then
                        unequipFailLogged = true
                        Log.warn("Unequip: unequip failed (logged once): "
                            .. tostring(err))
                    end
                end
            end
        end
    end
    return acted
end

function Unequip.pressClaims(item, playerNum, how)
    if item == nil or not modifierHeld() then return false end
    return Unequip.sendBack({ item }, playerNum, how) > 0
end

function Unequip.releaseClaims(element, item, playerNum, how)
    if element == nil then return false end
    if not gestureIsDoubleClick() then
        element._comfyUnequipClick = nil
        return false
    end
    if item == nil then return false end
    local id = item:getID()
    local now = getTimestampMs()
    local pending = element._comfyUnequipClick
    if pending ~= nil and pending.id == id
            and now - pending.atMs <= clickWindowMs() then
        element._comfyUnequipClick = nil
        return Unequip.sendBack({ item }, playerNum, how) > 0
    end
    element._comfyUnequipClick = { id = id, atMs = now }
    return false
end
