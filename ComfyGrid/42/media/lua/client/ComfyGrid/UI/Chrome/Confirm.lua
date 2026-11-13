--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ISUI/ISPanel"
require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Chrome/ModalButtons"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}

local Style = ComfyGrid.UI.Style
local ModalButtons = ComfyGrid.UI.Chrome.ModalButtons

local Confirm = ISPanel:derive("ComfyConfirm")
ComfyGrid.UI.Chrome.Confirm = Confirm

local PAD = 16
local GAP = 10

local BUTTON_RADIUS = 4

local measure = ModalButtons.measure

local function lineHeight()
    return math.max(Style.FONT_H or 14, 14) + 3
end

local function breaksAnywhere(code)
    if code >= 0x3130 and code <= 0x318F then return false end
    return (code >= 0x2E80 and code <= 0x9FFF)
        or (code >= 0xF900 and code <= 0xFAFF)
        or (code >= 0xFF00 and code <= 0xFFEF)
end

local NO_LINE_START = {}
for _, code in ipairs({
    0x3001, 0x3002, 0xFF0C, 0xFF0E, 0x30FB, 0xFF1A, 0xFF1B, 0xFF1F, 0xFF01,
    0x30FC, 0x300D, 0x300F, 0xFF09, 0x3011, 0x3015, 0x3009, 0x300B,
    0x3041, 0x3043, 0x3045, 0x3047, 0x3049, 0x3063, 0x3083, 0x3085, 0x3087,
    0x308E, 0x30A1, 0x30A3, 0x30A5, 0x30A7, 0x30A9, 0x30C3, 0x30E3, 0x30E5,
    0x30E7, 0x30EE, 0x30F5, 0x30F6,
    0x21, 0x29, 0x2C, 0x2E, 0x3A, 0x3B, 0x3F, 0x5D, 0x7D,
}) do NO_LINE_START[code] = true end
local NO_LINE_END = {}
for _, code in ipairs({
    0x300C, 0x300E, 0xFF08, 0x3010, 0x3014, 0x3008, 0x300A, 0x28, 0x5B,
}) do NO_LINE_END[code] = true end

local function piecesOf(paragraph, out)
    local current, currentSpaced = nil, false
    local pendingSpace = false
    local breakAfter, holdNext = false, false
    for i = 1, #paragraph do
        local char = string.sub(paragraph, i, i)
        if char == " " or char == "\t" then
            if current ~= nil then
                out[#out + 1] = { text = current, spaced = currentSpaced }
                current = nil
            end
            pendingSpace, holdNext = true, false
        else
            local code = string.byte(char)
            local anywhere = breaksAnywhere(code)
            local startsNew = current == nil or pendingSpace
                or (not holdNext and not NO_LINE_START[code]
                    and (breakAfter or anywhere))
            if startsNew then
                if current ~= nil then
                    out[#out + 1] = { text = current, spaced = currentSpaced }
                end
                current, currentSpaced = char, pendingSpace
            else
                current = current .. char
            end
            pendingSpace = false
            breakAfter = anywhere and not NO_LINE_END[code]
            holdNext = NO_LINE_END[code] == true
        end
    end
    if current ~= nil then out[#out + 1] = { text = current, spaced = currentSpaced } end
    return out
end

local function wrap(text, maxW)
    local out = {}
    for paragraph in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
        if paragraph == "" then
            out[#out + 1] = ""
        else
            local line = nil
            local pieces = piecesOf(paragraph, {})
            for i = 1, #pieces do
                local piece = pieces[i]
                local candidate = piece.text
                if line ~= nil then
                    candidate = line .. (piece.spaced and " " or "") .. piece.text
                end
                if line == nil or measure(candidate) <= maxW then
                    line = candidate
                else
                    out[#out + 1] = line
                    line = piece.text
                end
            end
            if line ~= nil then out[#out + 1] = line end
        end
    end
    return out
end

local function layoutButtons(self)
    local buttonHeight = lineHeight() + 8
    local buttonWidth = math.max(78, measure(self.yesText) + 28,
        measure(self.noText) + 28)
    local y = self.height - PAD - buttonHeight
    local buttons = self._buttons
    if buttons == nil then
        buttons = { { label = self.yesText, yes = true } }
        if self.yesno then
            buttons[2] = { label = self.noText, yes = false }
        end
        self._buttons = buttons
    end
    local x
    if self.yesno then
        x = math.floor((self.width - (buttonWidth * 2 + GAP)) / 2)
    else
        x = math.floor((self.width - buttonWidth) / 2)
    end
    for i = 1, #buttons do
        local rect = buttons[i]
        rect.x, rect.y, rect.w, rect.h = x, y, buttonWidth, buttonHeight
        rect.labelWidth = measure(rect.label)
        x = x + buttonWidth + GAP
    end
    self._buttonsFont = Style.FONT
    self._buttonsFontHeight = Style.FONT_H
end

function Confirm:close()

    if self._padReturn ~= nil and getFocusForPlayer ~= nil then
        local ok, currentFocus = pcall(getFocusForPlayer, self.playerNum or 0)
        if ok and currentFocus == self and setJoypadFocus ~= nil then
            pcall(setJoypadFocus, self.playerNum or 0, self._padReturn)
        end
    end
    self:setVisible(false)
    self:removeFromUIManager()
end

local function answer(self, yes)
    self:close()
    if yes then
        if self.onYes ~= nil then pcall(self.onYes) end
    elseif self.onNo ~= nil then
        pcall(self.onNo)
    end
end

function Confirm:prerender()
    ModalButtons.drawShell(self)

    local lineStep = lineHeight()
    local y = PAD
    local bodyText = Style.COLORS.BODY_TEXT
    for i = 1, #self.lines do
        if self.lines[i] ~= "" then
            self:drawText(self.lines[i], PAD, y, bodyText.r, bodyText.g,
                bodyText.b, 1, Style.FONT)
        end
        y = y + lineStep
    end

    if self._buttons == nil or self._buttonsFont ~= Style.FONT
            or self._buttonsFontHeight ~= Style.FONT_H then
        layoutButtons(self)
    end

    local rects = self._buttons
    ModalButtons.drawButtons(self, rects, BUTTON_RADIUS)

    self._rects = rects
end

function Confirm:render()
end

function Confirm:onMouseDown(_x, _y)
    return true
end

function Confirm:onMouseUp(x, y)
    local rect = ModalButtons.buttonAt(self._rects, x, y)
    if rect ~= nil then answer(self, rect.yes) end
    return true
end

function Confirm:onRightMouseDown(_x, _y) return true end
function Confirm:onRightMouseUp(_x, _y) return true end
function Confirm:onMouseWheel(_del) return true end

Confirm.disableJoypadNavigation = true

function Confirm:onJoypadDown(button, _joypadData)
    if Joypad == nil then return end
    if button == Joypad.AButton then
        answer(self, true)
    elseif button == Joypad.BButton then
        answer(self, not self.yesno)
    end
end

function Confirm.open(opts)
    if opts == nil or opts.text == nil then return nil end
    local o = Confirm:new(0, 0, 10, 10)
    o.playerNum = opts.playerNum or 0
    o.yesno = opts.yesno ~= false
    o.onYes = opts.onYes
    o.onNo = opts.onNo
    o.yesText = o.yesno and getText("UI_Yes") or getText("UI_Ok")
    o.noText = getText("UI_No")

    local dialogWidth = math.max(340, math.floor((Style.FONT_H or 14) * 26))
    o.lines = wrap(opts.text, dialogWidth - PAD * 2)
    local btnH = lineHeight() + 8
    o.width = dialogWidth
    o.height = PAD * 2 + #o.lines * lineHeight() + GAP + btnH
    o:setWidth(o.width)
    o:setHeight(o.height)

    local screenLeft, screenTop, screenWidth, screenHeight
    if getPlayerScreenLeft ~= nil then
        screenLeft = getPlayerScreenLeft(o.playerNum)
        screenTop = getPlayerScreenTop(o.playerNum)
        screenWidth = getPlayerScreenWidth(o.playerNum)
        screenHeight = getPlayerScreenHeight(o.playerNum)
    end
    if screenLeft == nil then
        local core = getCore()
        screenLeft, screenTop = 0, 0
        screenWidth = core ~= nil and core:getScreenWidth() or 1920
        screenHeight = core ~= nil and core:getScreenHeight() or 1080
    end
    o:setX(math.floor(screenLeft + (screenWidth - o.width) / 2))
    o:setY(math.floor(screenTop + (screenHeight - o.height) / 2))

    o:initialise()
    o:addToUIManager()
    if opts.onTop then o:setAlwaysOnTop(true) end
    o:bringToTop()

    local Input = ComfyGrid.Core and ComfyGrid.Core.Input
    local padOwns = Input ~= nil and Input.padOwns ~= nil
        and Input.padOwns(o.playerNum) or false
    if padOwns and setJoypadFocus ~= nil then
        if getFocusForPlayer ~= nil then
            local focusRead, currentFocus = pcall(getFocusForPlayer, o.playerNum)
            if focusRead then o._padReturn = currentFocus end
        end
        pcall(setJoypadFocus, o.playerNum, o)
    end
    return o
end

return Confirm
