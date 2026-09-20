--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.6
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ISUI/ISPanel"
require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}

local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw

local Confirm = ISPanel:derive("ComfyConfirm")
ComfyGrid.UI.Chrome.Confirm = Confirm

local PAD = 16
local GAP = 10

local function measure(s)
    local tm = getTextManager()
    if tm == nil then return 0 end
    return tm:MeasureStringX(Style.FONT, s or "")
end

local function lineHeight()
    return math.max(Style.FONT_H or 14, 14) + 3
end

local function wrap(text, maxW)
    local out = {}
    for paragraph in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
        if paragraph == "" then
            out[#out + 1] = ""
        else
            local line = nil
            for word in paragraph:gmatch("%S+") do
                local candidate = line == nil and word or (line .. " " .. word)
                if measure(candidate) <= maxW or line == nil then
                    line = candidate
                else
                    out[#out + 1] = line
                    line = word
                end
            end
            if line ~= nil then out[#out + 1] = line end
        end
    end
    return out
end

local function buttonRects(self)
    local h = lineHeight() + 8
    local w = math.max(78, measure(self.yesText) + 28, measure(self.noText) + 28)
    local y = self.height - PAD - h
    if not self.yesno then
        return { { x = math.floor((self.width - w) / 2), y = y, w = w, h = h,
                   label = self.yesText, yes = true } }
    end
    local total = w * 2 + GAP
    local x0 = math.floor((self.width - total) / 2)
    return {
        { x = x0, y = y, w = w, h = h, label = self.yesText, yes = true },
        { x = x0 + w + GAP, y = y, w = w, h = h, label = self.noText, yes = false },
    }
end

function Confirm:close()

    if self._padReturn ~= nil and getFocusForPlayer ~= nil then
        local ok, cur = pcall(getFocusForPlayer, self.playerNum or 0)
        if ok and cur == self and setJoypadFocus ~= nil then
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
    local sf = Style.COLORS.SURFACE
    Draw.shadow(self, 0, 0, self.width, self.height, 16, 0.55)
    Draw.roundFrame(self, 0, 0, self.width, self.height, 6, 0.98, sf.line,
        sf.bg, 0.98)

    local lh = lineHeight()
    local y = PAD
    for i = 1, #self.lines do
        if self.lines[i] ~= "" then
            self:drawText(self.lines[i], PAD, y, 0.86, 0.84, 0.80, 1, Style.FONT)
        end
        y = y + lh
    end

    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    self._hot = nil
    local rects = buttonRects(self)
    for i = 1, #rects do
        local r = rects[i]
        local hot = over and mx >= r.x and mx < r.x + r.w
            and my >= r.y and my < r.y + r.h
        if hot then self._hot = i end
        Draw.roundFrame(self, r.x, r.y, r.w, r.h, 4, 1,
            hot and sf.accent or sf.line, hot and sf.cardHi or sf.card, 1)
        local tw = measure(r.label)
        self:drawText(r.label, r.x + math.floor((r.w - tw) / 2),
            r.y + math.floor((r.h - Style.FONT_H) / 2),
            sf.accent.r, sf.accent.g, sf.accent.b, hot and 1 or 0.85, Style.FONT)
    end
    self._rects = rects
end

function Confirm:render()
end

function Confirm:onMouseDown(_x, _y)
    return true
end

function Confirm:onMouseUp(x, y)
    local rects = self._rects
    if rects ~= nil then
        for i = 1, #rects do
            local r = rects[i]
            if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then
                answer(self, r.yes)
                return true
            end
        end
    end
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

    local w = math.max(340, math.floor((Style.FONT_H or 14) * 26))
    o.lines = wrap(opts.text, w - PAD * 2)
    local btnH = lineHeight() + 8
    o.width = w
    o.height = PAD * 2 + #o.lines * lineHeight() + GAP + btnH
    o:setWidth(o.width)
    o:setHeight(o.height)

    local px, py, pw, ph
    if getPlayerScreenLeft ~= nil then
        px = getPlayerScreenLeft(o.playerNum)
        py = getPlayerScreenTop(o.playerNum)
        pw = getPlayerScreenWidth(o.playerNum)
        ph = getPlayerScreenHeight(o.playerNum)
    end
    if px == nil then
        local core = getCore()
        px, py = 0, 0
        pw = core ~= nil and core:getScreenWidth() or 1920
        ph = core ~= nil and core:getScreenHeight() or 1080
    end
    o:setX(math.floor(px + (pw - o.width) / 2))
    o:setY(math.floor(py + (ph - o.height) / 2))

    o:initialise()
    o:addToUIManager()
    if opts.onTop then o:setAlwaysOnTop(true) end
    o:bringToTop()

    local Input = ComfyGrid.Core and ComfyGrid.Core.Input
    local padOwns = Input ~= nil and Input.padOwns ~= nil
        and Input.padOwns(o.playerNum) or false
    if padOwns and setJoypadFocus ~= nil then
        if getFocusForPlayer ~= nil then
            local okF, cur = pcall(getFocusForPlayer, o.playerNum)
            if okF then o._padReturn = cur end
        end
        pcall(setJoypadFocus, o.playerNum, o)
    end
    return o
end

return Confirm
