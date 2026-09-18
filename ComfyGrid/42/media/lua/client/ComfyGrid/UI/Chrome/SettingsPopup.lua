--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.5
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
require "ComfyGrid/UI/Chrome/KeyCapture"
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
local KeyCapture = ComfyGrid.UI.Chrome.KeyCapture
local KeyBinds = ComfyGrid.Interact ~= nil
    and ComfyGrid.Interact.KeyBinds or nil

local instance = nil

local lastClosedMs = 0

local REOPEN_GUARD_MS = 250

local lastTab = 1

local PAD = 12
local ROW_GAP = 4

local COL_GAP = 14

local TAB_PAD = 10

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
    if row.kind == "keybind" then

        return measure("SHIFT + BACKSPACE") + PAD * 2
    end
    return 0
end

local versionText = nil
local function versionLabel()
    if versionText == nil then
        versionText = "v" .. tostring(ComfyGrid.VERSION or "?")
    end
    return versionText
end

local function panelWidth(tabs, resetRow)
    local labelMax, ctrlMax, fullMax = 0, 0, 0
    local barMin = 0
    for t = 1, #tabs do
        local tab = tabs[t]
        barMin = barMin + measure(tab.label) + TAB_PAD * 2
        local rows = tab.rows
        for i = 1, #rows do
            local row = rows[i]
            local lw = measure(row.label)
            if lw > labelMax then labelMax = lw end
            local cw = controlWidth(row)
            if cw > ctrlMax then ctrlMax = cw end
        end
    end
    if barMin > fullMax then fullMax = barMin end
    if resetRow ~= nil then

        local rw = measure(resetRow.label) + COL_GAP + measure(versionLabel())
            + PAD * 2
        if rw > fullMax then fullMax = rw end
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

local function tabHeight()
    return math.max(20, Style.FONT_H + 9)
end

local function keyLabelFor(def)
    if KeyBinds == nil or KeyBinds.labelFor == nil then return "?" end
    local ok, label = pcall(KeyBinds.labelFor, def.bind)
    if ok and type(label) == "string" and label ~= "" then return label end
    return "?"
end

local function buildTabRows(groupKey, defs)
    for i = #defs, 1, -1 do defs[i] = nil end
    Settings.defsInGroup(groupKey, defs)
    local rows = {}
    for i = 1, #defs do
        local def = defs[i]
        local row = {
            kind = def.kind,
            def = def,
            label = Settings.labelFor(def),
            tip = Settings.tipFor(def),
        }
        if def.kind == "keybind" then row.keyLabel = keyLabelFor(def) end
        rows[#rows + 1] = row
    end
    return rows
end

local function buildTabs(out)
    for i = #out, 1, -1 do out[i] = nil end
    local groups = Settings.GROUPS or {}
    local defs = {}
    for g = 1, #groups do
        local key = groups[g].key
        local rows = buildTabRows(key, defs)
        if #rows > 0 then
            out[#out + 1] = {
                key = key,
                label = Settings.groupLabel(key),
                rows = rows,
            }
        end
    end
    return out
end

local function relayout(self)
    self.titleH = titleHeight()
    self.rowH = rowHeight()
    self.tabH = tabHeight()

    local w, ctrlW = panelWidth(self.tabs, self.resetRow)
    self.ctrlW = ctrlW

    self.versionW = measure(versionLabel())
    local h = self.titleH + self.tabH + PAD
    h = h + #self.rows * (self.rowH + ROW_GAP)

    h = h + ROW_GAP + 1 + ROW_GAP + self.rowH
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
    o.resetRow = { kind = "reset",
        label = Text.tr("IGUI_ComfyGrid_ResetDefaults", "Reset this tab") }
    o.tabs = buildTabs({})

    o.tab = (lastTab <= #o.tabs) and lastTab or 1
    o.rows = o.tabs[o.tab] ~= nil and o.tabs[o.tab].rows or {}
    o.hotRow = nil
    o.hotTab = nil
    o.hotReset = false
    o.dragRow = nil

    o.moving = false
    o.moved = false
    o.pendingKey = nil
    o.pendingValue = nil
    relayout(o)
    return o
end

local function rowBounds(self, i)
    if i < 1 or i > #self.rows then return nil, nil end
    local top = self.titleH + self.tabH + PAD
    return top + (i - 1) * (self.rowH + ROW_GAP), self.rowH
end

local function tabBounds(self, i)
    local n = #self.tabs
    if n == 0 or i < 1 or i > n then return nil, nil end
    local total = self.width - 2
    local x = 1 + math.floor(total * (i - 1) / n)
    return x, 1 + math.floor(total * i / n) - x
end

local function resetBounds(self)
    local y = self.height - PAD - self.rowH
    return y, self.rowH, y - ROW_GAP - 1
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

local function drawTabs(self, sf)
    self:drawRect(1, self.titleH, self.width - 2, self.tabH, 0.55,
        sf.panel.r, sf.panel.g, sf.panel.b)
    for i = 1, #self.tabs do
        local x, w = tabBounds(self, i)
        if x ~= nil then
            local active = self.tab == i
            local hot = self.hotTab == i
            if active then
                self:drawRect(x, self.titleH, w, self.tabH, 0.95,
                    sf.bg.r, sf.bg.g, sf.bg.b)
                self:drawRect(x, self.titleH + self.tabH - 2, w, 2, 1,
                    sf.accent.r, sf.accent.g, sf.accent.b)
            elseif hot then
                self:drawRect(x, self.titleH, w, self.tabH, 0.5,
                    sf.card.r, sf.card.g, sf.card.b)
            end

            local label = Text.fitEllipsis(self.tabs[i].label, Style.FONT,
                w - TAB_PAD, 24)
            local tx = x + math.floor((w - measure(label)) / 2)
            local ty = self.titleH + math.floor((self.tabH - Style.FONT_H) / 2)
            if active then
                self:drawText(label, tx, ty, sf.accent.r, sf.accent.g,
                    sf.accent.b, 1, Style.FONT)
            else
                self:drawText(label, tx, ty, 0.86, 0.84, 0.80,
                    hot and 0.95 or 0.62, Style.FONT)
            end
        end
    end
end

local function drawKeybind(self, row, x, y, w, h, hot)
    local sf = Style.COLORS.SURFACE
    local label = row.keyLabel or "?"

    local bw = measure(label) + PAD * 2
    local floor = math.max(48, math.floor(Style.FONT_H * 2.6))
    if bw < floor then bw = floor end
    if bw > w then bw = w end
    local bx = x + w - bw
    Draw.roundFrame(self, bx, y, bw, h, 3, 1,
        hot and sf.accent or sf.line, hot and sf.cardHi or sf.card, 1)
    local fit = Text.fitEllipsis(label, Style.FONT, bw - 10, 40)
    self:drawTextCentre(fit, bx + bw / 2, y + math.floor((h - Style.FONT_H) / 2),
        sf.accent.r, sf.accent.g, sf.accent.b, 1, Style.FONT)
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

    self.hotRow = nil
    self.hotTab = nil
    self.hotReset = false
    if self:isMouseOver() then
        local mx, my = self:getMouseX(), self:getMouseY()
        if my >= self.titleH and my < self.titleH + self.tabH then
            for i = 1, #self.tabs do
                local tx, tw = tabBounds(self, i)
                if tx ~= nil and mx >= tx and mx < tx + tw then
                    self.hotTab = i
                    break
                end
            end
        else
            local ry, rh = resetBounds(self)
            if my >= ry and my < ry + rh then
                self.hotReset = true
            else
                for i = 1, #self.rows do
                    local y, h = rowBounds(self, i)
                    if y ~= nil and my >= y and my < y + h then
                        self.hotRow = i
                        break
                    end
                end
            end
        end
    end

    if self._padReturnPage ~= nil and getFocusForPlayer ~= nil then
        local okF, cur = pcall(getFocusForPlayer, self.playerNum or 0)
        if okF and cur == self then
            local last = #self.rows + 1
            local r = self.padRow
            self.hotRow = nil
            if r ~= nil and r >= 1 and r <= #self.rows then self.hotRow = r end
            self.hotTab = nil
            if r == 0 then self.hotTab = self.tab end
            self.hotReset = r == last
        end
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

    drawTabs(self, sf)
    Draw.headerLine(self, 1, self.titleH + self.tabH - 1, self.width - 2, 4,
        Style.COLORS)

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

            local applies = Settings.appliesNow(row.def, self.playerNum)

            local hot = self.hotRow == i and applies
            if hot then
                self:drawRect(PAD - 4, y, self.width - (PAD - 4) * 2, h,
                    0.35, sf.card.r, sf.card.g, sf.card.b)
            end
            local cbx, cby, cbw, cbh = controlBox(self, y, h)
            local fit = Text.fitEllipsis(row.label, Style.FONT,
                cbx - PAD - 8, 60)
            self:drawText(fit, PAD, y + math.floor((h - Style.FONT_H) / 2),
                0.86, 0.84, 0.80, applies and 1 or 0.4, Style.FONT)
            if not applies then

                local note = Settings.padNoteFor(row.def)
                if note ~= nil then
                    self:drawText(Text.fitEllipsis(note, Style.FONT, cbw, 40),
                        cbx, cby + math.floor((cbh - Style.FONT_H) / 2),
                        0.86, 0.84, 0.80, 0.45, Style.FONT)
                end
            elseif row.kind == "slider" then
                drawSlider(self, row, cbx, cby, cbw, cbh, hot)
            elseif row.kind == "tickbox" then
                drawTickbox(self, row, cbx, cby, cbw, cbh, hot)
            elseif row.kind == "choice" then
                drawChoice(self, row, cbx, cby, cbw, cbh, hot)
            elseif row.kind == "keybind" then
                drawKeybind(self, row, cbx, cby, cbw, cbh, hot)
            end
        end
    end

    local ry, rh, sepY = resetBounds(self)
    self:drawRect(PAD, sepY, self.width - PAD * 2, 1, 0.4,
        sf.line.r, sf.line.g, sf.line.b)
    if self.hotReset then
        self:drawRect(PAD - 4, ry, self.width - (PAD - 4) * 2, rh, 0.35,
            sf.card.r, sf.card.g, sf.card.b)
    end
    local footerTextY = ry + math.floor((rh - Style.FONT_H) / 2)
    self:drawText(self.resetRow.label, PAD, footerTextY,
        sf.accent.r, sf.accent.g, sf.accent.b, self.hotReset and 1 or 0.8,
        Style.FONT)

    self:drawText(versionLabel(), self.width - PAD - (self.versionW or 0),
        footerTextY, sf.line.r, sf.line.g, sf.line.b, 1, Style.FONT)

    local hotTip = nil
    if self.hotRow ~= nil and self.dragRow == nil then
        local row = self.rows[self.hotRow]
        if row ~= nil then
            hotTip = row.tip

            if not Settings.appliesNow(row.def, self.playerNum) then
                hotTip = Settings.padTipFor(row.def) or hotTip
            end
        end
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

local function resetTab(self)
    local rows = self.rows or {}
    for i = 1, #rows do
        local def = rows[i].def
        if def ~= nil then
            if def.kind == "keybind" and KeyBinds ~= nil
                    and KeyBinds.defaultKeyFor ~= nil then
                local key = KeyBinds.defaultKeyFor(def.bind)
                if key ~= nil and KeyBinds.assign ~= nil then
                    pcall(KeyBinds.assign, def.bind, key, false, false, false)
                end
            else
                local d = Settings.defaults[def.key]
                if d ~= nil then pcall(Settings.set, def.key, d) end
            end
        end
    end
    Settings.save()
    SettingsPopup.refreshKeybinds()
end

local function activateRow(self, i)
    local row = self.rows[i]
    if row == nil then return end
    local def = row.def
    if def == nil then return end

    if not Settings.appliesNow(def, self.playerNum) then return end
    if row.kind == "keybind" then

        if KeyCapture ~= nil and KeyCapture.open ~= nil then
            KeyCapture.open(def.bind, function()
                SettingsPopup.refreshKeybinds()
            end)
        end
        return
    end
    if row.kind == "tickbox" then
        pcall(Settings.set, def.key, not (Settings.get(def.key) == true))
    elseif row.kind == "choice" then

        local idx = Settings.choiceIndexOf(def, Settings.get(def.key)) or 1
        local nxt = idx % #def.values + 1
        pcall(Settings.set, def.key, def.values[nxt])
    end
end

function SettingsPopup:selectTab(i)
    if i == nil or i == self.tab then return end
    local tab = self.tabs[i]
    if tab == nil then return end
    self.tab = i
    lastTab = i
    self.rows = tab.rows
    self.hotRow = nil
    self.dragRow = nil
    self.pendingKey = nil
    self.pendingValue = nil
    HoverTip.hide(self)
    relayout(self)
end

function SettingsPopup:onMouseDown(x, y)

    self:bringToTop()

    if y < self.titleH then
        local cs = self._closeS
        local onClose = cs ~= nil and x >= self._closeX and x < self._closeX + cs
            and y >= self._closeY and y < self._closeY + cs
        if not onClose then
            self.moving = true
            self.moved = false
        end
    end

    if y > self.titleH + self.tabH then
        for i = 1, #self.rows do
            local ry, rh = rowBounds(self, i)
            if ry ~= nil and y >= ry and y < ry + rh
                    and self.rows[i].kind == "slider"
                    and Settings.appliesNow(self.rows[i].def, self.playerNum) then
                self.dragRow = i
                self:updateDrag()
                break
            end
        end
    end
    return true
end

function SettingsPopup:onMouseMove(dx, dy)
    if not self.moving then return true end
    if dx ~= 0 or dy ~= 0 then self.moved = true end
    self:setX(self.x + dx)
    self:setY(self.y + dy)
    self:clampToScreen()
    return true
end

function SettingsPopup:onMouseUp(x, y)

    if self.moving then
        local travelled = self.moved
        self.moving = false
        self.moved = false
        if travelled then return true end
    end
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
    if y >= self.titleH and y < self.titleH + self.tabH then
        for i = 1, #self.tabs do
            local tx, tw = tabBounds(self, i)
            if tx ~= nil and x >= tx and x < tx + tw then
                self:selectTab(i)
                break
            end
        end
        return true
    end
    local fy, fh = resetBounds(self)
    if y >= fy and y < fy + fh then
        resetTab(self)
        return true
    end
    if y > self.titleH + self.tabH then
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
    self.moving = false
    self.moved = false
    if self.dragRow ~= nil then self:commitDrag() end
end

function SettingsPopup.onMouseDownOutside(_self, _x, _y)
end

function SettingsPopup.onRightMouseDownOutside(_self, _x, _y)
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

function SettingsPopup.refreshKeybinds()
    local self = instance
    if self == nil or self.tabs == nil then return end
    for t = 1, #self.tabs do
        local rows = self.tabs[t].rows
        for i = 1, #rows do
            local row = rows[i]
            if row.kind == "keybind" and row.def ~= nil then
                row.keyLabel = keyLabelFor(row.def)
            end
        end
    end
    relayout(self)
end

local function sinceClose()
    if lastClosedMs == 0 then return math.huge end
    return getTimestampMs() - lastClosedMs
end

local PAD_TABS = 0

local function padRowUsable(self, i)
    if i == PAD_TABS then return true end
    if i == #self.rows + 1 then return true end
    local row = self.rows[i]
    if row == nil then return false end
    return Settings.appliesNow(row.def, self.playerNum)
end

local function padMove(self, delta)
    local last = #self.rows + 1
    local i = self.padRow or PAD_TABS
    for _ = 1, last + 1 do
        i = i + delta
        if i < PAD_TABS then i = last elseif i > last then i = PAD_TABS end
        if padRowUsable(self, i) then
            self.padRow = i
            return
        end
    end
end

local function padAdjust(self, dir)
    local row = self.rows[self.padRow or -1]
    if row == nil or row.def == nil then return end
    if not Settings.appliesNow(row.def, self.playerNum) then return end
    local def = row.def
    if def.kind == "choice" then
        local idx = Settings.choiceIndexOf(def, Settings.get(def.key)) or 1
        local n = #def.values
        local nxt = (idx - 1 + dir) % n + 1
        pcall(Settings.set, def.key, def.values[nxt])
    elseif def.kind == "slider" then
        local v = (Settings.get(def.key) or def.min) + dir * (def.step or 1)
        if v < def.min then v = def.min elseif v > def.max then v = def.max end
        pcall(Settings.set, def.key, v)
    elseif def.kind == "tickbox" then
        pcall(Settings.set, def.key, dir > 0)
    end
end

function SettingsPopup.padFocus(popup, page)
    if popup == nil then return end
    local Input = ComfyGrid.Core and ComfyGrid.Core.Input
    if Input == nil or not Input.padOwns(popup.playerNum) then return end
    popup._padReturnPage = page
    popup.padRow = PAD_TABS
    if setJoypadFocus ~= nil then
        pcall(setJoypadFocus, popup.playerNum or 0, popup)
    end
end

local function padRelease(popup)
    if popup._padReturnPage == nil then return end
    local seat = popup.playerNum or 0
    if getFocusForPlayer ~= nil then
        local ok, cur = pcall(getFocusForPlayer, seat)
        if ok and cur ~= popup then return end
    end
    if setJoypadFocus ~= nil then
        pcall(setJoypadFocus, seat, popup._padReturnPage)
    end
end

SettingsPopup.disableJoypadNavigation = true

function SettingsPopup:onJoypadDown(button, _joypadData)
    if Joypad == nil then return end
    if button == Joypad.BButton then
        self:close()
    elseif button == Joypad.AButton then
        local last = #self.rows + 1
        if self.padRow == last then
            resetTab(self)
        elseif self.padRow ~= nil and self.padRow >= 1 then
            activateRow(self, self.padRow)
        end
    end
end

function SettingsPopup:onJoypadDirUp(_joypadData)
    padMove(self, -1)
end

function SettingsPopup:onJoypadDirDown(_joypadData)
    padMove(self, 1)
end

function SettingsPopup:onJoypadDirLeft(_joypadData)
    if self.padRow == PAD_TABS then
        self:selectTab(((self.tab or 1) - 2) % #self.tabs + 1)
    else
        padAdjust(self, -1)
    end
end

function SettingsPopup:onJoypadDirRight(_joypadData)
    if self.padRow == PAD_TABS then
        self:selectTab((self.tab or 1) % #self.tabs + 1)
    else
        padAdjust(self, 1)
    end
end

function SettingsPopup:close()

    if KeyCapture ~= nil and KeyCapture.closeAny ~= nil then
        pcall(KeyCapture.closeAny)
    end

    pcall(Settings.save)

    HoverTip.hide(self)
    self:setVisible(false)
    self:removeFromUIManager()
    padRelease(self)
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

    SettingsPopup.padFocus(popup, host.parent or host)
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

PopupRegistry.register("SettingsPopup", SettingsPopup.current,
    { dismissable = false })
