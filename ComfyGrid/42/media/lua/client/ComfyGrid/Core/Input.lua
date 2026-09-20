--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.6
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

return Input
