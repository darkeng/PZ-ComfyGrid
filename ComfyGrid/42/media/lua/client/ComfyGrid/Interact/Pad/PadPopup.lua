--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Util"
require "ComfyGrid/UI/Style"
require "ComfyGrid/Interact/QuickMove"
require "ComfyGrid/Interact/ContextMenu"
require "ComfyGrid/Interact/Pad/PadCarry"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local PadPopup = {}
ComfyGrid.Interact.PadPopup = PadPopup

local Util = ComfyGrid.Core.Util
local Style = ComfyGrid.UI.Style
local QuickMove = ComfyGrid.Interact.QuickMove
local ContextMenu = ComfyGrid.Interact.ContextMenu
local PadCarry = ComfyGrid.Interact.PadCarry

function PadPopup.focus(popup, page)
    if popup == nil then return end
    popup._padReturnPage = page
    popup.padTile = 0
    setJoypadFocus(popup.playerNum or 0, popup)
end

function PadPopup.releaseFocus(popup)
    local seat = popup.playerNum or 0
    if getFocusForPlayer(seat) ~= popup then return end
    setJoypadFocus(seat, popup._padReturnPage)
end

function PadPopup.cursorFor(popup)
    local seat = popup.playerNum or 0
    if popup.padTile == nil then return nil end
    if getFocusForPlayer(seat) ~= popup then return nil end
    return popup.padTile
end

local function onDirPress(popup, dx, dy)
    local tileCount = popup.tiles ~= nil and #popup.tiles or 0
    if tileCount < 1 then return end
    local cols = popup.cols or 1
    local rows = popup.rowsTotal or 1
    local slot = Util.clamp(popup.padTile or 0, 0, tileCount - 1)
    local col = slot % cols
    local row = math.floor(slot / cols)
    local ncol = col + dx
    local nrow = row + dy
    if ncol < 0 then ncol = 0 end
    if ncol > cols - 1 then ncol = cols - 1 end
    if nrow < 0 then nrow = 0 end
    if nrow > rows - 1 then nrow = rows - 1 end
    local nslot = nrow * cols + ncol
    if nslot >= tileCount then nslot = tileCount - 1 end
    popup.padTile = nslot

    if popup.yOffset ~= nil then
        local stride = Style.CELL_STRIDE
        local cell = Style.CELL or 45
        local rowTop = math.floor(nslot / cols) * stride
        local boardHeight = popup:padVisibleBoardHeight()
        local scrollOffset = popup.yOffset
        if rowTop < scrollOffset then
            scrollOffset = rowTop
        elseif rowTop + cell > scrollOffset + boardHeight then
            scrollOffset = rowTop + cell - boardHeight
        end
        if scrollOffset < 0 then scrollOffset = 0 end
        popup.yOffset = scrollOffset
    end
end

local function onButtonPress(popup, button)
    local seat = popup.playerNum or 0
    if button == Joypad.BButton then

        if popup.padClearSelection ~= nil and popup:padClearSelection() then
            return
        end
        popup:close()
        return
    end
    local idx = popup.padTile
    local item = idx ~= nil and popup.padTileItem ~= nil
        and popup:padTileItem(idx) or nil
    if item == nil then return end
    if button == Joypad.LStickButton then

        if popup.padToggleSelect ~= nil then
            popup:padToggleSelect(idx)
        end
        return
    end

    local payload = popup.padDragPayloadFor ~= nil
        and popup:padDragPayloadFor(idx) or nil
    if button == Joypad.AButton then

        if PadCarry.isCarrying(seat) then return end
        local taken
        if payload ~= nil then
            taken = PadCarry.pickupPayload(seat, payload, item)
        else
            taken = PadCarry.pickupItem(seat, item)
        end
        if taken then
            popup:close()
        end
    elseif button == Joypad.XButton then

        QuickMove.run(payload or { item }, item:getContainer(), seat)

        local covered = popup.padIsSelected ~= nil and popup:padIsSelected(idx)
        if not covered and popup.padSelectionPayload ~= nil then
            local selPayload = popup:padSelectionPayload()
            if selPayload ~= nil then
                QuickMove.run(selPayload, item:getContainer(), seat)
            end
        end

        local Input = ComfyGrid.Interact.PadInput
        if Input ~= nil and Input.quickMoveSeatSelections ~= nil
                and popup._padReturnPage ~= nil then
            Input.quickMoveSeatSelections(popup._padReturnPage, seat, nil)
        end
    elseif button == Joypad.YButton then

        local tileX, tileY = popup:padTileXY(idx)
        local cell = Style.CELL
        ContextMenu.openForItems(seat, { item },
            popup:getAbsoluteX() + tileX + cell,
            popup:getAbsoluteY() + tileY + cell,
            popup)
    end
end

function PadPopup.attach(popupClass)

    popupClass.disableJoypadNavigation = true
    function popupClass:onJoypadDown(button, _joypadData)
        onButtonPress(self, button)
    end
    function popupClass:onJoypadDirUp(_joypadData)
        onDirPress(self, 0, -1)
    end
    function popupClass:onJoypadDirDown(_joypadData)
        onDirPress(self, 0, 1)
    end
    function popupClass:onJoypadDirLeft(_joypadData)
        onDirPress(self, -1, 0)
    end
    function popupClass:onJoypadDirRight(_joypadData)
        onDirPress(self, 1, 0)
    end
end

return PadPopup
