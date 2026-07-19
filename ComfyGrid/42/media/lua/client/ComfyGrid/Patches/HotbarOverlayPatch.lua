--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.2.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/UI/StackRenderer"

local lastOverlayError = nil

local smallFontHgt = -1

local function overlay(self)

    if (self.playerNum ~= nil and self.playerNum > 0)
            or (JoypadState.players ~= nil
                and JoypadState.players[(self.playerNum or 0) + 1] ~= nil) then
        return
    end
    local slots = self.availableSlot
    local attached = self.attachedItems
    if slots == nil or attached == nil then return end

    local sr = ComfyGrid.UI and ComfyGrid.UI.StackRenderer
    if sr == nil or sr.overlayInfo == nil then return end
    if smallFontHgt < 0 then
        smallFontHgt = getTextManager():getFontHeight(UIFont.Small)
    end
    local slotY = self.margins + 1
    local slotH = self.slotHeight
    local slotW = self.slotWidth
    local slotX = self.margins + 1
    for i = 1, #slots do
        local item = attached[i]
        if item ~= nil then
            local frac, col, ammoText = sr.overlayInfo(item)
            if frac ~= nil and col ~= nil then

                local area = slotH - 10
                local barH = math.floor(area * frac + 0.5)
                if barH < 2 and frac > 0 then barH = 2 end
                local bx = slotX + slotW - 7
                local by = slotY + 5 + (area - barH)
                self:drawRect(bx + 1, by, 1, 1, 1, col.r, col.g, col.b)
                if barH > 2 then
                    self:drawRect(bx, by + 1, 3, barH - 2, 1,
                        col.r, col.g, col.b)
                end
                self:drawRect(bx + 1, by + barH - 1, 1, 1, 1,
                    col.r, col.g, col.b)
            end
            if ammoText ~= nil then
                local ty = slotY + slotH - smallFontHgt - 1
                self:drawText(ammoText, slotX + 4, ty + 1, 0, 0, 0, 1,
                    UIFont.Small)
                self:drawText(ammoText, slotX + 3, ty, 1, 1, 1, 1,
                    UIFont.Small)
            end
        end
        slotX = slotX + slotW + self.slotPad
    end
end

ComfyGrid._hotbarOverlay = overlay

if not ComfyGrid._hotbarOverlayWrapped then
    ComfyGrid._hotbarOverlayWrapped = true
    local base = ISHotbar.render
    function ISHotbar:render()
        base(self)
        local fn = ComfyGrid._hotbarOverlay
        if fn ~= nil then
            local ok, err = pcall(fn, self)
            if not ok and err ~= lastOverlayError then
                lastOverlayError = err
                local Log = ComfyGrid.Core and ComfyGrid.Core.Log
                if Log ~= nil then
                    Log.error("Hotbar overlay failed: " .. tostring(err))
                end
            end
        end
    end
end
