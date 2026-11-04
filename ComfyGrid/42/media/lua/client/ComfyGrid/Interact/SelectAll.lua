--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.11
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local SelectAll = {}
ComfyGrid.Interact.SelectAll = SelectAll

local aWasDown = {}

local movingBeforeA = {}

local pageScratch = {}

local function hoveredBoard(playerNum)
    local UI = ComfyGrid.UI
    local StackPopup = UI ~= nil and UI.StackPopup or nil
    local popup = StackPopup ~= nil and StackPopup.current() or nil
    if popup ~= nil and popup.playerNum == playerNum and popup:isMouseOver() then
        return popup
    end
    local ContainerWindow = UI ~= nil and UI.ContainerWindow or nil
    if ContainerWindow ~= nil and ContainerWindow.isMouseOverIt(playerNum) then
        local bagBoard = ContainerWindow.gridFor(playerNum)
        if bagBoard ~= nil and bagBoard:isMouseOver() then return bagBoard end
        return nil
    end
    local Tooltip = ComfyGrid.Interact.Tooltip
    if Tooltip == nil or Tooltip.hoveredBoardOf == nil then return nil end
    pageScratch[1] = getPlayerInventory(playerNum)
    pageScratch[2] = getPlayerLoot(playerNum)
    for i = 1, 2 do
        local page = pageScratch[i]
        if page ~= nil and page:isVisible() and not page.isCollapsed
                and page:isMouseOver() and page.inventoryPane ~= nil then
            local board = Tooltip.hoveredBoardOf(page.inventoryPane)
            if board ~= nil then return board end
        end
    end
    return nil
end

function SelectAll.characterMoving(playerNum)
    local player = getSpecificPlayer(playerNum)
    if player == nil then return false end
    return player:isPlayerMoving() == true
end

function SelectAll.onPaneUpdate(pane)
    if pane.doController then return end
    local playerNum = pane.player or 0
    local aDown = isKeyDown(Keyboard.KEY_A)
    local pressedNow = aDown and not aWasDown[playerNum]
    aWasDown[playerNum] = aDown
    if not aDown then
        movingBeforeA[playerNum] = SelectAll.characterMoving(playerNum)
        return
    end
    if not pressedNow or movingBeforeA[playerNum] then return end
    if not isCtrlKeyDown() or not ComfyGrid.Settings.selectAllShortcutActive() then
        return
    end
    local board = hoveredBoard(playerNum)
    if board ~= nil and board.toggleAllStacks ~= nil then
        board:toggleAllStacks()
    end
end

return SelectAll
