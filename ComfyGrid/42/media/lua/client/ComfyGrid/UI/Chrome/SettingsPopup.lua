--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Settings"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
require "ComfyGrid/UI/Chrome/PopupRegistry"
require "ComfyGrid/UI/Chrome/HoverTip"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local SettingsPopup = ISPanel:derive("ComfySettingsPopup")
ComfyGrid.UI.Chrome.SettingsPopup = SettingsPopup

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local Settings = ComfyGrid.Settings
local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw
local PopupRegistry = ComfyGrid.UI.Chrome.PopupRegistry
local HoverTip = ComfyGrid.UI.Chrome.HoverTip

local instance = nil

local lastClosedMs = 0
local REOPEN_GUARD_MS = 250

local PAD = 12
local ROW_GAP = 4
local GROUP_GAP = 12

local COL_GAP = 14

local function measure(s)
    if s == nil or s == "" then return 0 end
    local tm = getTextManager ~= nil and getTextManager() or nil
    if tm == nil then return 0 end
    local ok, w = pcall(tm.MeasureStringX, tm, Style.FONT, s)
    return ok and w or 0
end

local function controlWidth(row)
    local def = row.def
    if def == nil then return 0 end
    if row.kind == "choice" then
        local w = 0
        local values = def.values or {}
        for i = 1, #values do
            local m = measure(Settings.choiceLabel(def, i))
            if m > w then w = m end
        end

        return w + 26
    end
    if row.kind == "slider" then

        return math.max(110, math.floor(Style.FONT_H * 7))
    end
    if row.kind == "tickbox" then
        return math.max(12, math.floor(Style.FONT_H * 0.8))
    end
    return 0
end

local function panelWidth(rows)
    local labelMax, ctrlMax, fullMax = 0, 0, 0
    for i = 1, #rows do
        local row = rows[i]
        if row.kind == "group" then

            local gw = measure(row.label) + PAD * 2
            if gw > fullMax then fullMax = gw end
        else
            local lw = measure(row.label)
            if lw > labelMax then labelMax = lw end
            local cw = controlWidth(row)
            if cw > ctrlMax then ctrlMax = cw end
        end
    end
    local w = PAD + labelMax + COL_GAP + ctrlMax + PAD
    if fullMax > w then w = fullMax end
    local screenW = getCore ~= nil and getCore():getScreenWidth() or 1920
    local maxW = math.floor(screenW * 0.55)
    if w > maxW then w = maxW end
    local minW = math.max(280, math.floor(Style.FONT_H * 18))
    if w < minW then w = minW end
    return math.floor(w), ctrlMax
end

local function rowHeight()
    return math.max(22, Style.FONT_H + 10)
end

local function titleHeight()
    return math.max(18, Style.FONT_H + 8)
end

local function buildRows(out)
    for i = #out, 1, -1 do out[i] = nil end
    local defs = Settings.OPTION_DEFS or {}
    local lastGroup = nil
    for i = 1, #defs do
        local def = defs[i]
        if def.group ~= lastGroup then
            lastGroup = def.group
            out[#out + 1] = { kind = "group", label = Settings.groupLabel(def.group) }
        end
        out[#out + 1] = {
            kind = def.kind,
            def = def,
            label = Settings.labelFor(def),
            tip = Settings.tipFor(def),
        }
    end
    out[#out + 1] = { kind = "reset",
        label = Text.tr("IGUI_ComfyGrid_ResetDefaults", "Reset to defaults") }
    return out
end

local function relayout(self)
    self.titleH = titleHeight()
    self.rowH = rowHeight()
    local w, ctrlW = panelWidth(self.rows)
    self.ctrlW = ctrlW
    local h = self.titleH + PAD
    for i = 1, #self.rows do
        local row = self.rows[i]
        if row.kind == "group" then
            h = h + (i > 1 and GROUP_GAP or 0) + Style.FONT_H + 2
        else
            h = h + self.rowH + ROW_GAP
        end
    end
    h = h + PAD
    if self.width ~= w then self:setWidth(w) end
    if self.height ~= h then self:setHeight(h) end
    self.metricsGen = Style.SCALE
    self.metricsFont = Style.FONT_H
    self:clampToScreen()
end

function SettingsPopup:clampToScreen()
    local core = getCore and getCore() or nil
    local sw = core and core:getScreenWidth() or 1920
    local sh = core and core:getScreenHeight() or 1080
    local x = self.x or 0
    local y = self.y or 0
    if x + self.width > sw then x = sw - self.width end
    if y + self.height > sh then y = sh - self.height end
    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    if self.x ~= x then self:setX(x) end
    if self.y ~= y then self:setY(y) end
end

function SettingsPopup:new(x, y, host)
    local o = ISPanel:new(x, y, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.host = host
    o.playerNum = host ~= nil and host.pane ~= nil and host.pane.player or nil

    o.background = false

    o.disableJoypadNavigation = true
    o.rows = buildRows({})
    o.hotRow = nil
    o.dragRow = nil
    o.pendingKey = nil
    o.pendingValue = nil
    relayout(o)
    return o
end

local function rowBounds(self, i)
    local y = self.titleH + PAD
    for k = 1, #self.rows do
        local row = self.rows[k]
        local h
        if row.kind == "group" then
            y = y + (k > 1 and GROUP_GAP or 0)
            h = Style.FONT_H + 2
        else
            h = self.rowH
        end
        if k == i then return y, h end
        y = y + h + (row.kind == "group" and 0 or ROW_GAP)
    end
    return nil, nil
end

local function controlBox(self, y, h)
    local cw = self.ctrlW
    if cw == nil or cw <= 0 then cw = math.floor(self.width * 0.42) end
    return self.width - PAD - cw, y + 2, cw, h - 4
end

local function rowValue(self, def)
    if self.pendingKey == def.key then return self.pendingValue end
    return Settings.get(def.key)
end

local function fmtNumber(v)
    local s = string.format("%.1f", v)
    return (s:gsub("%.0$", ""))
end

local function drawSlider(self, row, x, y, w, h, hot)
    local sf = Style.COLORS.SURFACE
    local def = row.def
    local v = rowValue(self, def)
    local t = (v - def.min) / (def.max - def.min)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local trackY = y + math.floor(h / 2) - 1
    local labelW = 34
    local trackW = w - labelW
    self:drawRect(x, trackY, trackW, 2, 0.9, sf.card.r, sf.card.g, sf.card.b)
    self:drawRect(x, trackY, math.floor(trackW * t), 2, 1,
        sf.accent.r, sf.accent.g, sf.accent.b)
    local knob = math.max(8, math.floor(Style.FONT_H * 0.55))
    local kx = x + math.floor(trackW * t) - math.floor(knob / 2)
    Draw.disc(self, kx, trackY + 1 - math.floor(knob / 2), knob, 1,
        hot and sf.accent or sf.line)
    Draw.disc(self, kx + 1, trackY + 2 - math.floor(knob / 2), knob - 2, 1,
        hot and sf.cardHi or sf.card)
    self:drawTextRight(fmtNumber(v), x + w, y + math.floor((h - Style.FONT_H) / 2),
        sf.accent.r, sf.accent.g, sf.accent.b, 1, Style.FONT)
end

local function drawTickbox(self, row, x, y, w, h, hot)
    local sf = Style.COLORS.SURFACE
    local on = rowValue(self, row.def) == true
    local box = math.max(12, math.floor(Style.FONT_H * 0.8))
    local bx = x + w - box
    local by = y + math.floor((h - box) / 2)

    Draw.roundFrame(self, bx, by, box, box, 3, 1,
        hot and sf.accent or sf.line, on and sf.accent or sf.card, 1)
end

local function drawChoice(self, row, x, y, w, h, hot)
    local sf = Style.COLORS.SURFACE
    local def = row.def
    local idx = Settings.choiceIndexOf(def, rowValue(self, def)) or 1
    local label = Settings.choiceLabel(def, idx)
    Draw.roundFrame(self, x, y, w, h, 3, 1,
        hot and sf.accent or sf.line, hot and sf.cardHi or sf.card, 1)
    local fit = Text.fitEllipsis(label, Style.FONT, w - 20, 40)
    self:drawText(fit, x + 6, y + math.floor((h - Style.FONT_H) / 2),
        sf.accent.r, sf.accent.g, sf.accent.b, 1, Style.FONT)

    local cx = x + w - 10
    local cy = y + math.floor(h / 2)
    self:drawRect(cx, cy - 3, 2, 2, 0.9, sf.accent.r, sf.accent.g, sf.accent.b)
    self:drawRect(cx + 2, cy - 1, 2, 2, 0.9, sf.accent.r, sf.accent.g, sf.accent.b)
    self:drawRect(cx, cy + 1, 2, 2, 0.9, sf.accent.r, sf.accent.g, sf.accent.b)
end

function SettingsPopup:prerender()

    local host = self.host
    if host == nil or host.isReallyVisible == nil or not host:isReallyVisible() then
        self:close()
        return
    end

    if self.metricsGen ~= Style.SCALE or self.metricsFont ~= Style.FONT_H then
        relayout(self)
    end

    local sf = Style.COLORS.SURFACE
    Draw.shadow(self, 0, 0, self.width, self.height, 14, 0.5)
    Draw.roundFrame(self, 0, 0, self.width, self.height, 6, 0.98, sf.line,
        sf.bg, 0.98)

    self:drawRect(1, 1, self.width - 2, self.titleH - 1, 0.9,
        sf.panel.r, sf.panel.g, sf.panel.b)
    local title = Text.tr("IGUI_ComfyGrid_SettingsTitle", "Comfy Grid settings")
    self:drawText(title, PAD, math.floor((self.titleH - Style.FONT_H) / 2),
        sf.accent.r, sf.accent.g, sf.accent.b, 1, Style.FONT)
    Draw.headerLine(self, 1, self.titleH - 1, self.width - 2, 4, sf)

    local chip = math.max(14, math.floor(Style.FONT_H * 0.9 + 0.5))
    local cx = self.width - PAD - chip
    local cy = math.floor((self.titleH - chip) * 0.5)
    if cy < 1 then cy = 1 end
    local overClose = false
    if self:isMouseOver() then
        local mx, my = self:getMouseX(), self:getMouseY()
        overClose = mx >= cx and mx < cx + chip and my >= cy and my < cy + chip
    end
    Draw.disc(self, cx, cy, chip, 1, overClose and sf.accent or sf.line)
    Draw.disc(self, cx + 1, cy + 1, chip - 2, 1,
        overClose and sf.cardHi or sf.card)
    local closeTex = Draw.closeTexture()
    local g = math.floor(chip * 0.5 + 0.5)
    local off = math.floor((chip - g) * 0.5)
    if closeTex ~= nil then
        self:drawTextureScaled(closeTex, cx + off, cy + off, g, g,
            overClose and 1 or 0.85, sf.accent.r, sf.accent.g, sf.accent.b)
    else
        self:drawText("X", cx + off, cy, sf.accent.r, sf.accent.g, sf.accent.b,
            1, Style.FONT)
    end
    self._closeX, self._closeY, self._closeS = cx, cy, chip

    self.hotRow = nil
    if self:isMouseOver() then
        local my = self:getMouseY()
        for i = 1, #self.rows do
            local y, h = rowBounds(self, i)
            if y ~= nil and my >= y and my < y + h then
                self.hotRow = i
                break
            end
        end
    end

    if self.dragRow ~= nil then
        if isMouseButtonDown ~= nil and not isMouseButtonDown(0) then
            self:commitDrag()
        else
            self:updateDrag()
        end
    end

    for i = 1, #self.rows do
        local row = self.rows[i]
        local y, h = rowBounds(self, i)
        if y ~= nil then
            local hot = self.hotRow == i
            if row.kind == "group" then
                self:drawText(row.label, PAD, y, sf.accent.r, sf.accent.g,
                    sf.accent.b, 0.75, Style.FONT)
                self:drawRect(PAD, y + Style.FONT_H, self.width - PAD * 2, 1,
                    0.4, sf.line.r, sf.line.g, sf.line.b)
            elseif row.kind == "reset" then
                if hot then
                    self:drawRect(PAD - 4, y, self.width - (PAD - 4) * 2, h,
                        0.35, sf.card.r, sf.card.g, sf.card.b)
                end
                self:drawText(row.label, PAD, y + math.floor((h - Style.FONT_H) / 2),
                    sf.accent.r, sf.accent.g, sf.accent.b, hot and 1 or 0.8,
                    Style.FONT)
            else
                if hot then
                    self:drawRect(PAD - 4, y, self.width - (PAD - 4) * 2, h,
                        0.35, sf.card.r, sf.card.g, sf.card.b)
                end
                local cbx, cby, cbw, cbh = controlBox(self, y, h)
                local fit = Text.fitEllipsis(row.label, Style.FONT,
                    cbx - PAD - 8, 60)
                self:drawText(fit, PAD, y + math.floor((h - Style.FONT_H) / 2),
                    0.86, 0.84, 0.80, 1, Style.FONT)
                if row.kind == "slider" then
                    drawSlider(self, row, cbx, cby, cbw, cbh, hot)
                elseif row.kind == "tickbox" then
                    drawTickbox(self, row, cbx, cby, cbw, cbh, hot)
                elseif row.kind == "choice" then
                    drawChoice(self, row, cbx, cby, cbw, cbh, hot)
                end
            end
        end
    end

    local hotTip = nil
    if self.hotRow ~= nil and self.dragRow == nil then
        local row = self.rows[self.hotRow]
        hotTip = row ~= nil and row.tip or nil
    end
    if hotTip ~= nil then
        HoverTip.show(self, self, hotTip)
    else
        HoverTip.hide(self)
    end
end

function SettingsPopup:render()
end

function SettingsPopup:updateDrag()
    local i = self.dragRow
    local row = self.rows[i]
    if row == nil or row.def == nil then return end
    local y, h = rowBounds(self, i)
    if y == nil then return end
    local x, _, w = controlBox(self, y, h)
    local trackW = w - 34
    if trackW < 1 then return end
    local t = (self:getMouseX() - x) / trackW
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local def = row.def
    local raw = def.min + t * (def.max - def.min)

    local step = def.step or 1
    local snapped = def.min + math.floor((raw - def.min) / step + 0.5) * step
    if snapped < def.min then snapped = def.min end
    if snapped > def.max then snapped = def.max end
    self.pendingKey = def.key
    self.pendingValue = snapped
end

function SettingsPopup:commitDrag()
    local key, value = self.pendingKey, self.pendingValue
    self.dragRow = nil
    self.pendingKey = nil
    self.pendingValue = nil
    if key ~= nil and value ~= nil then
        pcall(Settings.set, key, value)
    end
end

local function activateRow(self, i)
    local row = self.rows[i]
    if row == nil then return end
    if row.kind == "reset" then
        for k, v in pairs(Settings.defaults) do
            pcall(Settings.set, k, v)
        end
        Settings.save()
        return
    end
    local def = row.def
    if def == nil then return end
    if row.kind == "tickbox" then
        pcall(Settings.set, def.key, not (Settings.get(def.key) == true))
    elseif row.kind == "choice" then

        local idx = Settings.choiceIndexOf(def, Settings.get(def.key)) or 1
        local nxt = idx % #def.values + 1
        pcall(Settings.set, def.key, def.values[nxt])
    end
end

function SettingsPopup:onMouseDown(x, y)

    self:bringToTop()

    if y > self.titleH then
        for i = 1, #self.rows do
            local ry, rh = rowBounds(self, i)
            if ry ~= nil and y >= ry and y < ry + rh
                    and self.rows[i].kind == "slider" then
                self.dragRow = i
                self:updateDrag()
                break
            end
        end
    end
    return true
end

function SettingsPopup:onMouseUp(x, y)
    if self.dragRow ~= nil then
        self:commitDrag()
        return true
    end
    local s = self._closeS
    if s ~= nil and x >= self._closeX and x < self._closeX + s
            and y >= self._closeY and y < self._closeY + s then
        self:close()
        return true
    end
    if y > self.titleH then
        for i = 1, #self.rows do
            local ry, rh = rowBounds(self, i)
            if ry ~= nil and y >= ry and y < ry + rh then
                activateRow(self, i)
                break
            end
        end
    end
    return true
end

function SettingsPopup:onMouseUpOutside(_x, _y)
    if self.dragRow ~= nil then self:commitDrag() end
end

function SettingsPopup:onMouseDownOutside(_x, _y)
    self:close()
end

function SettingsPopup:onRightMouseDownOutside(_x, _y)
    self:close()
end

function SettingsPopup:onRightMouseDown(_x, _y)
    return true
end

function SettingsPopup:onRightMouseUp(_x, _y)
    return true
end

function SettingsPopup:onMouseWheel(_del)
    return true
end

function SettingsPopup.current()
    return instance
end

local function sinceClose()
    if lastClosedMs == 0 then return math.huge end
    return getTimestampMs() - lastClosedMs
end

function SettingsPopup:close()

    pcall(Settings.save)

    HoverTip.hide(self)
    self:setVisible(false)
    self:removeFromUIManager()
    if instance == self then instance = nil end
    lastClosedMs = getTimestampMs()
end

function SettingsPopup.openFor(toolbar)
    if toolbar == nil then return nil end
    local host = toolbar.parent
    if host == nil then return nil end

    PopupRegistry.closeOthers(nil)
    if instance ~= nil then instance:close() end

    local ax = (toolbar:getAbsoluteX() or 0) + toolbar.width
    local rect = toolbar.chips ~= nil and toolbar.chips.rectOf ~= nil
        and toolbar.chips:rectOf("settings") or nil
    if rect ~= nil then
        ax = (toolbar:getAbsoluteX() or 0) + rect.x + rect.s
    end
    local ay = (toolbar:getAbsoluteY() or 0) + toolbar.height + 2
    local popup = SettingsPopup:new(0, ay, host)

    popup:setX(ax - popup.width)
    popup:initialise()
    popup:addToUIManager()
    popup:bringToTop()
    popup:clampToScreen()
    instance = popup
    return popup
end

function SettingsPopup.toggleFor(toolbar)
    if instance ~= nil then
        instance:close()
        return nil
    end
    if sinceClose() < REOPEN_GUARD_MS then return nil end
    local ok, popup = pcall(SettingsPopup.openFor, toolbar)
    if not ok then
        Log.error("SettingsPopup: open failed: " .. tostring(popup))
        return nil
    end
    return popup
end

PopupRegistry.register("SettingsPopup", SettingsPopup.current)
