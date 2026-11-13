--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/GameMode"
require "ComfyGrid/Interact/Pad/PadFocus"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local PadShoulder = {}
ComfyGrid.Interact.PadShoulder = PadShoulder

local PadFocus = ComfyGrid.Interact.PadFocus
local GameMode = ComfyGrid.Core.GameMode

local SWITCH_FROM_AFAR, STEP_HERE, FOCUS_ONLY = 1, 2, 3

local function pressMode()
    if GameMode.isTutorial() then return SWITCH_FROM_AFAR end
    return getCore():getOptionShoulderButtonContainerSwitch()
end

function PadShoulder.isHeld(button, joypadData)
    return button:isDown(joypadData.id)
end

local function switchContainer(target, step)
    if step > 0 then target:selectNextContainer() else target:selectPrevContainer() end
    PadFocus.followSelection(target)
end

function PadShoulder.actionOf(page, toLoot)
    local mode = pressMode()
    if mode == STEP_HERE then return "switch", toLoot and 1 or -1 end
    if page.onCharacter == toLoot then return "go", 0 end
    if mode == SWITCH_FROM_AFAR then return "switch", 1 end
    return nil, 0
end

function PadShoulder.press(page, toLoot)
    local action, step = PadShoulder.actionOf(page, toLoot)
    if action == "switch" then
        switchContainer(page, step)
    elseif action == "go" then
        local target = toLoot and getPlayerLoot(page.player) or getPlayerInventory(page.player)
        PadFocus.focusWindow(page, target)
    end
    return true
end

function PadShoulder.dpad(page, joypadData, dy)
    if dy == 0 or joypadData == nil then return false end
    if getCore():getOptionShoulderButtonContainerSwitch() ~= FOCUS_ONLY then return false end
    local target = nil
    if PadShoulder.isHeld(JoypadButton.LeftBump, joypadData) then
        target = getPlayerInventory(page.player)
    elseif PadShoulder.isHeld(JoypadButton.RightBump, joypadData) then
        target = getPlayerLoot(page.player)
    end
    if target == nil then return false end
    switchContainer(target, dy)
    return true
end

return PadShoulder
