--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.8
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Interact/KeyBinds"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local KeyCapture = ISPanel:derive("ComfyKeyCapture")
ComfyGrid.UI.Chrome.KeyCapture = KeyCapture

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw
local KeyBinds = ComfyGrid.Interact.KeyBinds

local instance = nil

local PAD = 14
local BTN_GAP = 10

function KeyCapture.isOpen()
    return instance ~= nil
end

local function measure(s)
    if s == nil or s == "" then return 0 end
    local tm = getTextManager ~= nil and getTextManager() or nil
    if tm == nil then return 0 end
    local ok, w = pcall(tm.MeasureStringX, tm, Style.FONT, s)
    if ok then return w end
    return 0
end

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

local function buttonAt(self, x, y)
    for _, b in ipairs(self.buttons) do
        if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
            return b
        end
    end
    return nil
end

function KeyCapture:onMouseDown(_x, _y)
    return true
end

function KeyCapture:onMouseUp(x, y)
    local b = buttonAt(self, x, y)
    if b ~= nil then b.act(self) end
    return true
end

function KeyCapture:onRightMouseDown(_x, _y) return true end
function KeyCapture:onRightMouseUp(_x, _y) return true end

function KeyCapture:prerender()
    local sf = Style.COLORS.SURFACE
    Draw.shadow(self, 0, 0, self.width, self.height, 16, 0.55)
    Draw.roundFrame(self, 0, 0, self.width, self.height, 6, 0.98, sf.line,
        sf.bg, 0.98)

    local fh = Style.FONT_H
    local y = PAD
    self:drawTextCentre(self.actionLabel, self.width / 2, y,
        sf.accent.r, sf.accent.g, sf.accent.b, 1, Style.FONT)
    y = y + fh + 8
    self:drawTextCentre(self.prompt, self.width / 2, y,
        0.86, 0.84, 0.80, 1, Style.FONT)

    local over = nil
    if self:isMouseOver() then
        over = buttonAt(self, self:getMouseX(), self:getMouseY())
    end
    for _, b in ipairs(self.buttons) do
        local hot = over == b
        Draw.roundFrame(self, b.x, b.y, b.w, b.h, 3, 1,
            hot and sf.accent or sf.line, hot and sf.cardHi or sf.card, 1)
        self:drawTextCentre(b.label, b.x + b.w / 2,
            b.y + math.floor((b.h - fh) / 2),
            sf.accent.r, sf.accent.g, sf.accent.b, hot and 1 or 0.85,
            Style.FONT)
    end
end

function KeyCapture:render()
end

function KeyCapture.open(bindName, onAssigned)
    if instance ~= nil then instance:close() end
    local actionLabel = KeyBinds.actionName(bindName)
    local prompt = Text.tr("IGUI_ComfyGrid_PressAKey", "Press a key")
    local clearLabel = Text.tr("IGUI_ComfyGrid_KeyClear", "No key")
    local cancelLabel = Text.tr("IGUI_ComfyGrid_KeyCancel", "Cancel")

    local fh = Style.FONT_H
    local btnH = math.max(22, fh + 10)
    local btnW = math.max(90, measure(clearLabel) + PAD * 2,
        measure(cancelLabel) + PAD * 2)
    local width = math.max(320, measure(actionLabel) + PAD * 4,
        measure(prompt) + PAD * 4, btnW * 2 + BTN_GAP + PAD * 2)
    local height = PAD + fh + 8 + fh + PAD + btnH + PAD

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

    local by = height - PAD - btnH
    local bx = math.floor((width - (btnW * 2 + BTN_GAP)) / 2)
    o.buttons = {
        { label = clearLabel, x = bx, y = by, w = btnW, h = btnH,
          act = KeyCapture.onClear },
        { label = cancelLabel, x = bx + btnW + BTN_GAP, y = by, w = btnW,
          h = btnH, act = KeyCapture.onCancel },
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
