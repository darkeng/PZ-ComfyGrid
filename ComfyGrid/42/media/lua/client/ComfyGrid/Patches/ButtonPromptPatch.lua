--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Patches = ComfyGrid.Patches or {}
local ButtonPromptPatch = {}
ComfyGrid.Patches.ButtonPromptPatch = ButtonPromptPatch

local Log = ComfyGrid.Core.Log

local ROW_H = 32
local BUTTON_W = 32
local TEXT_PAD_X = 11
local SHIFT = 16

local BUTTONS = nil
local function buttonOf(key)
    if BUTTONS == nil then
        BUTTONS = {
            L3 = Joypad.LStickButton,
            R3 = Joypad.RStickButton,
            Back = Joypad.Back,
        }
    end
    return BUTTONS[key]
end

local function drawExtraRow(self, key, text, level, fontHgt, onRight)
    local tex = Joypad.ButtonTextures[buttonOf(key)]
    if tex == nil then return false end
    local yRow = self.y1 - ROW_H * (level + 1)
    local bh = tex:getHeight()
    if onRight then
        local x = self.x2 + self.w2 - self.rmargin - BUTTON_W
        self:drawTexture(tex, x, yRow + (ROW_H - bh) / 2, 0.9, 1, 1, 1)
        self:drawTextRight(text, x - TEXT_PAD_X,
            yRow + (ROW_H - fontHgt) / 2, 1, 1, 1, 0.9, UIFont.NewLarge)
    else
        local x = self.x1 + self.lmargin
        self:drawTexture(tex, x + SHIFT, yRow + (ROW_H - bh) / 2,
            0.9, 1, 1, 1)
        self:drawText(text, x + BUTTON_W + TEXT_PAD_X + SHIFT,
            yRow + (ROW_H - fontHgt) / 2, 1, 1, 1, 0.9, UIFont.NewLarge)
    end
    return true
end

local LEFT_EXTRA = { "L3", "Back" }

local function drawStickRows(self)
    local joypadData = JoypadState.players[self.player + 1]
    if joypadData == nil or not joypadData.player then return end
    if joypadData.id == nil or not isJoypadConnected(joypadData.id) then
        return
    end
    local focus = getFocusForPlayer(self.player)

    if focus == nil or focus.overrideBPrompt ~= true then return end
    local Interact = ComfyGrid.Interact
    local Input = Interact ~= nil and Interact.PadInput or nil
    if Input == nil or Input.promptFor == nil then return end

    local fontHgt = getTextManager():getFontFromEnum(UIFont.NewLarge)
        :getLineHeight()
    local level = 1
    for i = 1, #LEFT_EXTRA do
        local key = LEFT_EXTRA[i]
        local text = Input.promptFor(focus, key)
        if text ~= nil and drawExtraRow(self, key, text, level, fontHgt) then
            level = level + 1
        end
    end
    local r3 = Input.promptFor(focus, "R3")
    if r3 ~= nil then
        drawExtraRow(self, "R3", r3, 1, fontHgt, true)
    end
end

function ButtonPromptPatch._overlay(promptBar)
    drawStickRows(promptBar)
end

Events.OnGameBoot.Add(function()

    if ISButtonPrompt._comfyPatched then return end
    ISButtonPrompt._comfyPatched = true

    local og_prerender = ISButtonPrompt.prerender
    function ISButtonPrompt:prerender()
        og_prerender(self)
        local Patches = ComfyGrid.Patches
        local patch = Patches ~= nil and Patches.ButtonPromptPatch or nil
        if patch ~= nil then
            pcall(patch._overlay, self)
        end
    end

    Log.info("ButtonPromptPatch applied")
end)
