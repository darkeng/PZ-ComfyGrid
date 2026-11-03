--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.8
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local SelectAll = {}
ComfyGrid.Interact.SelectAll = SelectAll

local aHeld = {}

local pageScratch = {}

local function hoveredBoard(playerNum)
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

function SelectAll.onPaneUpdate(pane)
    if pane.doController then return end
    local playerNum = pane.player or 0
    local board = nil
    if isCtrlKeyDown() then board = hoveredBoard(playerNum) end
    if board == nil then
        aHeld[playerNum] = false
        return
    end
    getCore():setIsSelectingAll(true)
    local aDown = isKeyDown(Keyboard.KEY_A)
    if aDown and not aHeld[playerNum] and board.selectAllStacks ~= nil then
        board:selectAllStacks()
    end
    aHeld[playerNum] = aDown
end

return SelectAll
