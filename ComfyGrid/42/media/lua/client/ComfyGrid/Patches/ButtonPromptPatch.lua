--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.3
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
    local yRow = self.y1 - ROW_H * 2
    local l3 = Input.promptFor(focus, "L3")
    if l3 ~= nil then
        local tex = Joypad.ButtonTextures[Joypad.LStickButton]
        if tex ~= nil then
            local x = self.x1 + self.lmargin
            local bh = tex:getHeight()
            self:drawTexture(tex, x + SHIFT, yRow + (ROW_H - bh) / 2,
                0.9, 1, 1, 1)
            self:drawText(l3, x + BUTTON_W + TEXT_PAD_X + SHIFT,
                yRow + (ROW_H - fontHgt) / 2, 1, 1, 1, 0.9, UIFont.NewLarge)
        end
    end
    local r3 = Input.promptFor(focus, "R3")
    if r3 ~= nil then
        local tex = Joypad.ButtonTextures[Joypad.RStickButton]
        if tex ~= nil then
            local x = self.x2 + self.w2 - self.rmargin - BUTTON_W
            local bh = tex:getHeight()
            self:drawTexture(tex, x, yRow + (ROW_H - bh) / 2, 0.9, 1, 1, 1)
            self:drawTextRight(r3, x - TEXT_PAD_X,
                yRow + (ROW_H - fontHgt) / 2, 1, 1, 1, 0.9, UIFont.NewLarge)
        end
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
