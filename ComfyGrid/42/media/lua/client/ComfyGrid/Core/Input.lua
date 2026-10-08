--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Core = ComfyGrid.Core or {}
local Input = {}
ComfyGrid.Core.Input = Input

function Input.padOwns(playerNum)
    if JoypadState == nil or JoypadState.players == nil then return false end
    return JoypadState.players[(playerNum or 0) + 1] ~= nil
end

function Input.modifierHeld(name)
    if name == "shift" then
        return isShiftKeyDown ~= nil and isShiftKeyDown() == true
    end
    if name == "ctrl" then
        return isCtrlKeyDown ~= nil and isCtrlKeyDown() == true
    end
    if name == "alt" then
        if Keyboard == nil or Keyboard.isKeyDown == nil then return false end
        return Keyboard.isKeyDown(Keyboard.KEY_LMENU) == true
            or Keyboard.isKeyDown(Keyboard.KEY_RMENU) == true
    end
    return false
end

function Input.multiSelectHeld(mine, other)
    if not Input.modifierHeld(mine) then return false end
    if other ~= nil and other ~= mine and Input.modifierHeld(other) then
        return false
    end
    return true
end

function Input.transferModifierHeld(mine)
    if mine == nil then return false end
    return Input.modifierHeld(mine)
end

function Input.hotbarOf(playerNum)
    local ok, hotbar = pcall(getPlayerHotbar, playerNum)
    if ok then return hotbar end
    return nil
end

return Input
