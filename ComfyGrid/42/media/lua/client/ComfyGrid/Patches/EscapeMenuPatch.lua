--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Patches = ComfyGrid.Patches or {}
local EscapeMenuPatch = {}
ComfyGrid.Patches.EscapeMenuPatch = EscapeMenuPatch

local Log = ComfyGrid.Core.Log

local seats = {}
local menuWasVisible = false

local watchFailLogged = false

local function comfyPage(page)
    local pane = page ~= nil and page.inventoryPane or nil
    return pane ~= nil and pane.mode == "comfy"
end

local function sampleSeat(playerNum)
    local inv = getPlayerInventory(playerNum)
    local loot = getPlayerLoot(playerNum)
    if inv == nil or loot == nil or not comfyPage(inv) then
        seats[playerNum] = nil
        return
    end
    local s = seats[playerNum]
    if s == nil then
        s = {}
        seats[playerNum] = s
    end
    s.inv = inv
    s.loot = loot
    s.invVisible = inv:getIsVisible()
    s.lootVisible = loot:getIsVisible()
    s.invCollapsed = inv.isCollapsed
    s.lootCollapsed = loot.isCollapsed
    s.invPin = inv.pin
    s.lootPin = loot.pin
    local focused = getFocusForPlayer(playerNum)
    s.focusPage = (focused == inv or focused == loot) and focused or nil
end

local function restoreCollapsed(page, collapsed)
    if collapsed then
        page:collapseNow()
    elseif page.isCollapsed then
        page.isCollapsed = false
        page:clearMaxDrawHeight()
    end
end

local function restorePin(page, pinned)
    if pinned then
        page:setPinned()
    else

        page:collapse()
    end
end

local function restoreSeat(playerNum, s)

    if s.inv ~= getPlayerInventory(playerNum)
            or s.loot ~= getPlayerLoot(playerNum) then
        return
    end
    s.inv:setVisible(s.invVisible)
    s.loot:setVisible(s.lootVisible)
    restoreCollapsed(s.inv, s.invCollapsed)
    restoreCollapsed(s.loot, s.lootCollapsed)
    restorePin(s.inv, s.invPin)
    restorePin(s.loot, s.lootPin)

    if s.focusPage ~= nil and getFocusForPlayer(playerNum) == nil then
        setJoypadFocus(playerNum, s.focusPage)
    end
end

function EscapeMenuPatch._onRenderTick()
    local ms = MainScreen ~= nil and MainScreen.instance or nil
    local visible = ms ~= nil and ms.inGame == true and ms:isVisible() or false
    if visible == menuWasVisible then
        if not visible then

            for i = 0, getNumActivePlayers() - 1 do
                sampleSeat(i)
            end
        end
        return
    end
    menuWasVisible = visible
    if not visible then

        for i = 0, getNumActivePlayers() - 1 do
            if seats[i] ~= nil then
                restoreSeat(i, seats[i])
            end
        end
    end

end

function EscapeMenuPatch._toggle(og, key)
    return og(key)
end

if not ComfyGrid._escapeMenuTickHooked then
    ComfyGrid._escapeMenuTickHooked = true
    Events.OnRenderTick.Add(function()
        local Patches = ComfyGrid.Patches
        local patch = Patches ~= nil and Patches.EscapeMenuPatch or nil
        if patch == nil then return end
        local ok, err = pcall(patch._onRenderTick)
        if not ok and not watchFailLogged then
            watchFailLogged = true
            Log.error("EscapeMenuPatch watcher failed (logged once): "
                .. tostring(err))
        end
    end)
end
