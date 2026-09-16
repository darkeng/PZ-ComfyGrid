--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Style"
require "ComfyGrid/Interact/QuickMove"
require "ComfyGrid/Interact/ContextMenu"
require "ComfyGrid/Interact/Pad/PadCarry"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local PadPopup = {}
ComfyGrid.Interact.PadPopup = PadPopup

local Style = ComfyGrid.UI.Style
local QuickMove = ComfyGrid.Interact.QuickMove
local ContextMenu = ComfyGrid.Interact.ContextMenu
local PadCarry = ComfyGrid.Interact.PadCarry

local BOARD_X = 4

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

function PadPopup._dir(popup, dx, dy)
    local n = popup.tiles ~= nil and #popup.tiles or 0
    if n < 1 then return end
    local cols = popup.cols or 1
    local rows = popup.rowsTotal or 1
    local slot = popup.padTile or 0
    if slot >= n then slot = n - 1 end
    if slot < 0 then slot = 0 end
    local col = slot % cols
    local row = math.floor(slot / cols)
    local ncol = col + dx
    local nrow = row + dy
    if ncol < 0 then ncol = 0 end
    if ncol > cols - 1 then ncol = cols - 1 end
    if nrow < 0 then nrow = 0 end
    if nrow > rows - 1 then nrow = rows - 1 end
    local nslot = nrow * cols + ncol
    if nslot >= n then nslot = n - 1 end
    popup.padTile = nslot

    if popup.yOffset ~= nil then
        local stride = Style.CELL_STRIDE or 46
        local cell = Style.CELL or 45
        local rowTop = math.floor(nslot / cols) * stride
        local bh = (popup.height or 0) - (popup.titleH or 0) - 4
        local off = popup.yOffset
        if rowTop < off then
            off = rowTop
        elseif rowTop + cell > off + bh then
            off = rowTop + cell - bh
        end
        if off < 0 then off = 0 end
        popup.yOffset = off
    end
end

function PadPopup._button(popup, button)
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
        local cols = popup.cols or 1
        local px, py = Style.pixelForSlot(idx, cols)
        local cell = Style.CELL or 45
        local off = popup.yOffset or 0
        ContextMenu.openForItems(seat, { item },
            popup:getAbsoluteX() + BOARD_X + px + cell,
            popup:getAbsoluteY() + (popup.titleH or 18) + py - off + cell,
            popup)
    end
end

function PadPopup.attach(popupClass)

    popupClass.disableJoypadNavigation = true
    function popupClass:onJoypadDown(button, _joypadData)
        PadPopup._button(self, button)
    end
    function popupClass:onJoypadDirUp(_joypadData)
        PadPopup._dir(self, 0, -1)
    end
    function popupClass:onJoypadDirDown(_joypadData)
        PadPopup._dir(self, 0, 1)
    end
    function popupClass:onJoypadDirLeft(_joypadData)
        PadPopup._dir(self, -1, 0)
    end
    function popupClass:onJoypadDirRight(_joypadData)
        PadPopup._dir(self, 1, 0)
    end
end

return PadPopup
