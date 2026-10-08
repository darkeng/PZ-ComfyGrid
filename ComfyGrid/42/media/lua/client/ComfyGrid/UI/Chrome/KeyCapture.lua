--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Interact/KeyBinds"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Chrome/ModalButtons"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local KeyCapture = ISPanel:derive("ComfyKeyCapture")
ComfyGrid.UI.Chrome.KeyCapture = KeyCapture

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local Style = ComfyGrid.UI.Style
local ModalButtons = ComfyGrid.UI.Chrome.ModalButtons
local KeyBinds = ComfyGrid.Interact.KeyBinds

local instance = nil

local PAD = 14
local BTN_GAP = 10

local BUTTON_RADIUS = 3

function KeyCapture.isOpen()
    return instance ~= nil
end

local measure = ModalButtons.measure

local function confirmDuplicate(keyLabel, actionLabel, onYes)
    local Confirm = ComfyGrid.UI and ComfyGrid.UI.Chrome
        and ComfyGrid.UI.Chrome.Confirm
    if Confirm == nil or Confirm.open == nil then return onYes() end
    local text = Text.tr("IGUI_ComfyGrid_KeyTaken",
        "That key is already used by another action.")
        .. "\n\n" .. tostring(keyLabel) .. "  -  " .. tostring(actionLabel)
        .. "\n\n" .. Text.tr("IGUI_ComfyGrid_KeyTakenAsk",
            "Use it for both anyway?")

    Confirm.open({ text = text, onYes = onYes, onTop = true })
end

local function commit(self, key, shift, ctrl, alt)
    local name = self.bindName
    local function write()
        local ok = KeyBinds.assign(name, key, shift, ctrl, alt)
        if ok and self.onAssigned ~= nil then pcall(self.onAssigned, name) end
    end

    if key == 0 then return write() end
    local dupId, dupLabel = KeyBinds.duplicateOf(key, shift, ctrl, alt, name)
    if dupId == nil then return write() end
    local okName, keyName = pcall(getKeyName, key)
    confirmDuplicate(okName and keyName or "?", dupLabel, write)
end

function KeyCapture:close()

    if GameKeyboard ~= nil and GameKeyboard.setDoLuaKeyPressed ~= nil then
        pcall(GameKeyboard.setDoLuaKeyPressed, true)
    end
    self:setVisible(false)
    self:removeFromUIManager()
    if instance == self then instance = nil end
end

function KeyCapture:onCancel()
    self:close()
end

function KeyCapture.closeAny()
    if instance == nil then return false end
    instance:close()
    return true
end

function KeyCapture:onClear()
    local shift, ctrl, alt = false, false, false
    self:close()
    commit(self, 0, shift, ctrl, alt)
end

function KeyCapture:onKeyRelease(key)
    if key == nil or key <= 0 then return end
    local shift = Keyboard.isKeyDown(Keyboard.KEY_LSHIFT)
        or Keyboard.isKeyDown(Keyboard.KEY_RSHIFT)
    local ctrl = Keyboard.isKeyDown(Keyboard.KEY_LCONTROL)
        or Keyboard.isKeyDown(Keyboard.KEY_RCONTROL)
    local alt = Keyboard.isKeyDown(Keyboard.KEY_LMENU)
        or Keyboard.isKeyDown(Keyboard.KEY_RMENU)

    if shift and (ctrl or alt) then ctrl = false alt = false end
    if ctrl and alt then alt = false end

    if key == Keyboard.KEY_LSHIFT or key == Keyboard.KEY_RSHIFT
            or key == Keyboard.KEY_LCONTROL or key == Keyboard.KEY_RCONTROL
            or key == Keyboard.KEY_LMENU or key == Keyboard.KEY_RMENU then
        return
    end
    self:close()
    commit(self, key, shift, ctrl, alt)
end

function KeyCapture:isKeyConsumed(_key)
    return true
end

function KeyCapture:onMouseDown(_x, _y)
    return true
end

function KeyCapture:onMouseUp(x, y)
    local button = ModalButtons.buttonAt(self.buttons, x, y)
    if button ~= nil then button.act(self) end
    return true
end

function KeyCapture:onRightMouseDown(_x, _y) return true end
function KeyCapture:onRightMouseUp(_x, _y) return true end

function KeyCapture:prerender()
    ModalButtons.drawShell(self)

    local surface = Style.COLORS.SURFACE
    local fontHeight = Style.FONT_H
    local y = PAD
    self:drawTextCentre(self.actionLabel, self.width / 2, y,
        surface.accent.r, surface.accent.g, surface.accent.b, 1, Style.FONT)
    y = y + fontHeight + 8
    local bodyText = Style.COLORS.BODY_TEXT
    self:drawTextCentre(self.prompt, self.width / 2, y,
        bodyText.r, bodyText.g, bodyText.b, 1, Style.FONT)

    ModalButtons.drawButtons(self, self.buttons, BUTTON_RADIUS)
end

function KeyCapture:render()
end

function KeyCapture.open(bindName, onAssigned)
    if instance ~= nil then instance:close() end
    local actionLabel = KeyBinds.actionName(bindName)
    local prompt = Text.tr("IGUI_ComfyGrid_PressAKey", "Press a key")
    local clearLabel = Text.tr("IGUI_ComfyGrid_KeyClear", "No key")
    local cancelLabel = Text.tr("IGUI_ComfyGrid_KeyCancel", "Cancel")

    local fontHeight = Style.FONT_H
    local btnH = math.max(22, fontHeight + 10)
    local btnW = math.max(90, measure(clearLabel) + PAD * 2,
        measure(cancelLabel) + PAD * 2)
    local width = math.max(320, measure(actionLabel) + PAD * 4,
        measure(prompt) + PAD * 4, btnW * 2 + BTN_GAP + PAD * 2)
    local height = PAD + fontHeight + 8 + fontHeight + PAD + btnH + PAD

    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, KeyCapture)
    KeyCapture.__index = KeyCapture
    o.background = false
    o.bindName = bindName
    o.actionLabel = actionLabel
    o.prompt = prompt
    o.onAssigned = onAssigned
    o.disableJoypadNavigation = true

    local buttonY = height - PAD - btnH
    local buttonX = math.floor((width - (btnW * 2 + BTN_GAP)) / 2)
    o.buttons = {
        { label = clearLabel, x = buttonX, y = buttonY, w = btnW, h = btnH,
          act = KeyCapture.onClear },
        { label = cancelLabel, x = buttonX + btnW + BTN_GAP, y = buttonY,
          w = btnW, h = btnH, act = KeyCapture.onCancel },
    }

    o:setWantKeyEvents(true)
    o:setWantExtraMouseEvents(true)
    o:initialise()
    o:instantiate()
    o:addToUIManager()
    o:setAlwaysOnTop(true)

    if GameKeyboard ~= nil and GameKeyboard.setDoLuaKeyPressed ~= nil then
        pcall(GameKeyboard.setDoLuaKeyPressed, false)
    end
    instance = o
    Log.info("KeyCapture: capturing for " .. tostring(bindName))
    return o
end
