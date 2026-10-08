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

local openPanel = nil

local lastClosedMs = 0
local REOPEN_GUARD_MS = 250

local lastTab = 1

local PAD = 12
local ROW_GAP = 4

local COL_GAP = 14

local TAB_PAD = 10

local function textWidth(text)
    if text == nil or text == "" then return 0 end
    local tm = getTextManager ~= nil and getTextManager() or nil
    if tm == nil then return 0 end
    local ok, w = pcall(tm.MeasureStringX, tm, Style.FONT, text)
    return ok and w or 0
end

local function wrapStep(index, delta, low, high)
    local nextIndex = index + delta
    if nextIndex < low then
        nextIndex = high
    elseif nextIndex > high then
        nextIndex = low
    end
    return nextIndex
end

local function stepChoice(def, dir)
    local idx = Settings.choiceIndexOf(def, Settings.get(def.key)) or 1
    return def.values[wrapStep(idx, dir, 1, #def.values)]
end

local function controlWidthFor(row)
    local def = row.def
    if def == nil then return 0 end
    if row.kind == "choice" then
        local widest = 0
        local choiceValues = def.values or {}
        for i = 1, #choiceValues do
            local optionWidth = textWidth(Settings.choiceLabel(def, i))
            if optionWidth > widest then widest = optionWidth end
        end

        return widest + 26
    end
    if row.kind == "slider" then

        return math.max(110, math.floor(Style.FONT_H * 7))
    end
    if row.kind == "tickbox" then
        return math.max(12, math.floor(Style.FONT_H * 0.8))
    end
    if row.kind == "keybind" then

        return textWidth("SHIFT + BACKSPACE") + PAD * 2
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
        barMin = barMin + textWidth(tab.label) + TAB_PAD * 2
        local rows = tab.rows
        for i = 1, #rows do
            local row = rows[i]
            local labelWidth = textWidth(row.label)
            if labelWidth > labelMax then labelMax = labelWidth end
            local controlWidth = controlWidthFor(row)
            if controlWidth > ctrlMax then ctrlMax = controlWidth end
        end
    end
    if barMin > fullMax then fullMax = barMin end
    if resetRow ~= nil then

        local footerWidth = textWidth(resetRow.label) + COL_GAP
            + textWidth(versionLabel()) + PAD * 2
        if footerWidth > fullMax then fullMax = footerWidth end
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
    table.wipe(defs)
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
    table.wipe(out)
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

local refreshTextFits

local function relayout(self)
    self.titleH = titleHeight()
    self.rowH = rowHeight()
    self.tabH = tabHeight()

    local w, ctrlW = panelWidth(self.tabs, self.resetRow)
    self.ctrlW = ctrlW

    self.versionW = textWidth(versionLabel())
    local h = self.titleH + self.tabH + PAD
    h = h + #self.rows * (self.rowH + ROW_GAP)

    h = h + ROW_GAP + 1 + ROW_GAP + self.rowH
    h = h + PAD
    if self.width ~= w then self:setWidth(w) end
    if self.height ~= h then self:setHeight(h) end
    self.metricsGen = Style.SCALE
    self.metricsFont = Style.FONT_H
    refreshTextFits(self)
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
    local popup = ISPanel:new(x, y, 10, 10)
    setmetatable(popup, self)
    self.__index = self
    popup.host = host

    popup.playerNum = nil
    if host ~= nil then
        popup.playerNum = host.player
        if popup.playerNum == nil and host.pane ~= nil then
            popup.playerNum = host.pane.player
        end
    end

    popup.background = false

    popup.resetRow = { kind = "reset",
        label = Text.tr("IGUI_ComfyGrid_ResetDefaults", "Reset this tab") }
    popup.tabs = buildTabs({})

    popup.tab = (lastTab <= #popup.tabs) and lastTab or 1
    popup.rows = popup.tabs[popup.tab] ~= nil and popup.tabs[popup.tab].rows
        or {}
    popup.hotRow = nil
    popup.hotTab = nil
    popup.hotReset = false
    popup.dragRow = nil

    popup.moving = false
    popup.moved = false
    popup.pendingKey = nil
    popup.pendingValue = nil
    relayout(popup)
    return popup
end

local function rowBounds(self, rowIndex)
    if rowIndex < 1 or rowIndex > #self.rows then return nil, nil end
    local top = self.titleH + self.tabH + PAD
    return top + (rowIndex - 1) * (self.rowH + ROW_GAP), self.rowH
end

local function tabBounds(self, tabIndex)
    local tabCount = #self.tabs
    if tabCount == 0 or tabIndex < 1 or tabIndex > tabCount then
        return nil, nil
    end
    local total = self.width - 2
    local x = 1 + math.floor(total * (tabIndex - 1) / tabCount)
    return x, 1 + math.floor(total * tabIndex / tabCount) - x
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

function refreshTextFits(self)
    local font = Style.FONT
    self.textFitFont = font
    self.titleText = Text.tr("IGUI_ComfyGrid_SettingsTitle",
        "Comfy Grid settings")

    local cbx, _, cbw = controlBox(self, 0, self.rowH)
    for t = 1, #self.tabs do
        local tab = self.tabs[t]
        local x, w = tabBounds(self, t)
        if x ~= nil then
            tab.captionText = Text.fitEllipsis(tab.label, font, w - TAB_PAD, 24)
            tab.captionW = textWidth(tab.captionText)
        end
        local rows = tab.rows
        for i = 1, #rows do
            local row = rows[i]
            row.labelText = Text.fitEllipsis(row.label, font,
                cbx - PAD - 8, 60)
            row.padNoteText = nil
            local note = Settings.padNoteFor(row.def)
            if note ~= nil then
                row.padNoteText = Text.fitEllipsis(note, font, cbw, 40)
            end
            row.choiceTexts = nil
            if row.kind == "choice" then row.choiceTexts = {} end
            row.keyTextFor = nil
        end
    end
end

local function rowValue(self, def)
    if self.pendingKey == def.key then return self.pendingValue end
    return Settings.get(def.key)
end

local function formatSliderValue(value)
    local text = string.format("%.1f", value)
    return (text:gsub("%.0$", ""))
end

local function drawSlider(self, row, x, y, w, h, hot)
    local surface = Style.COLORS.SURFACE
    local def = row.def
    local value = rowValue(self, def)
    local fraction = (value - def.min) / (def.max - def.min)
    if fraction < 0 then fraction = 0 elseif fraction > 1 then fraction = 1 end
    local trackY = y + math.floor(h / 2) - 1
    local labelW = 34
    local trackW = w - labelW
    self:drawRect(x, trackY, trackW, 2, 0.9,
        surface.card.r, surface.card.g, surface.card.b)
    self:drawRect(x, trackY, math.floor(trackW * fraction), 2, 1,
        surface.accent.r, surface.accent.g, surface.accent.b)
    local knob = math.max(8, math.floor(Style.FONT_H * 0.55))
    local kx = x + math.floor(trackW * fraction) - math.floor(knob / 2)
    Draw.disc(self, kx, trackY + 1 - math.floor(knob / 2), knob, 1,
        hot and surface.accent or surface.line)
    Draw.disc(self, kx + 1, trackY + 2 - math.floor(knob / 2), knob - 2, 1,
        hot and surface.cardHi or surface.card)

    if row.valueTextFor ~= value then
        row.valueText = formatSliderValue(value)
        row.valueTextFor = value
    end
    self:drawTextRight(row.valueText, x + w,
        y + math.floor((h - Style.FONT_H) / 2),
        surface.accent.r, surface.accent.g, surface.accent.b, 1, Style.FONT)
end

local function drawTickbox(self, row, x, y, w, h, hot)
    local surface = Style.COLORS.SURFACE
    local on = rowValue(self, row.def) == true
    local box = math.max(12, math.floor(Style.FONT_H * 0.8))
    local bx = x + w - box
    local by = y + math.floor((h - box) / 2)

    Draw.roundFrame(self, bx, by, box, box, 3, 1,
        hot and surface.accent or surface.line,
        on and surface.accent or surface.card, 1)
end

local function drawChoice(self, row, x, y, w, h, hot)
    local surface = Style.COLORS.SURFACE
    local def = row.def
    local idx = Settings.choiceIndexOf(def, rowValue(self, def)) or 1
    Draw.roundFrame(self, x, y, w, h, 3, 1,
        hot and surface.accent or surface.line,
        hot and surface.cardHi or surface.card, 1)

    local choiceTexts = row.choiceTexts
    local choiceText = choiceTexts ~= nil and choiceTexts[idx] or nil
    if choiceText == nil then
        choiceText = Text.fitEllipsis(Settings.choiceLabel(def, idx),
            Style.FONT, w - 20, 40)
        if choiceTexts ~= nil then choiceTexts[idx] = choiceText end
    end
    self:drawText(choiceText, x + 6, y + math.floor((h - Style.FONT_H) / 2),
        surface.accent.r, surface.accent.g, surface.accent.b, 1, Style.FONT)

    local cx = x + w - 10
    local cy = y + math.floor(h / 2)
    local accent = surface.accent
    self:drawRect(cx, cy - 3, 2, 2, 0.9, accent.r, accent.g, accent.b)
    self:drawRect(cx + 2, cy - 1, 2, 2, 0.9, accent.r, accent.g, accent.b)
    self:drawRect(cx, cy + 1, 2, 2, 0.9, accent.r, accent.g, accent.b)
end

local function drawTabs(self, surface)
    self:drawRect(1, self.titleH, self.width - 2, self.tabH, 0.55,
        surface.panel.r, surface.panel.g, surface.panel.b)
    for tabIndex = 1, #self.tabs do
        local x, w = tabBounds(self, tabIndex)
        if x ~= nil then
            local active = self.tab == tabIndex
            local hot = self.hotTab == tabIndex
            if active then
                self:drawRect(x, self.titleH, w, self.tabH, 0.95,
                    surface.bg.r, surface.bg.g, surface.bg.b)
                self:drawRect(x, self.titleH + self.tabH - 2, w, 2, 1,
                    surface.accent.r, surface.accent.g, surface.accent.b)
            elseif hot then
                self:drawRect(x, self.titleH, w, self.tabH, 0.5,
                    surface.card.r, surface.card.g, surface.card.b)
            end

            local tab = self.tabs[tabIndex]
            local tabCaption = tab.captionText
            local tx = x + math.floor((w - tab.captionW) / 2)
            local ty = self.titleH + math.floor((self.tabH - Style.FONT_H) / 2)
            if active then
                self:drawText(tabCaption, tx, ty, surface.accent.r,
                    surface.accent.g, surface.accent.b, 1, Style.FONT)
            else
                local bodyText = Style.COLORS.BODY_TEXT
                self:drawText(tabCaption, tx, ty, bodyText.r, bodyText.g,
                    bodyText.b, hot and 0.95 or 0.62, Style.FONT)
            end
        end
    end
end

local function drawKeybind(self, row, x, y, w, h, hot)
    local surface = Style.COLORS.SURFACE
    local keyText = row.keyLabel or "?"

    if row.keyTextFor ~= keyText then
        local boxWidth = textWidth(keyText) + PAD * 2
        local minBoxWidth = math.max(48, math.floor(Style.FONT_H * 2.6))
        if boxWidth < minBoxWidth then boxWidth = minBoxWidth end
        if boxWidth > w then boxWidth = w end
        row.keyBoxW = boxWidth
        row.keyBoxText = Text.fitEllipsis(keyText, Style.FONT, boxWidth - 10, 40)
        row.keyTextFor = keyText
    end
    local bw = row.keyBoxW
    local bx = x + w - bw
    Draw.roundFrame(self, bx, y, bw, h, 3, 1,
        hot and surface.accent or surface.line,
        hot and surface.cardHi or surface.card, 1)
    self:drawTextCentre(row.keyBoxText, bx + bw / 2,
        y + math.floor((h - Style.FONT_H) / 2),
        surface.accent.r, surface.accent.g, surface.accent.b, 1, Style.FONT)
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

    if self.textFitFont ~= Style.FONT then refreshTextFits(self) end

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
            local padRowIndex = self.padRow
            self.hotRow = nil
            if padRowIndex ~= nil and padRowIndex >= 1
                    and padRowIndex <= #self.rows then
                self.hotRow = padRowIndex
            end
            self.hotTab = nil
            if padRowIndex == 0 then self.hotTab = self.tab end
            self.hotReset = padRowIndex == last
        end
    end

    local surface = Style.COLORS.SURFACE
    Draw.shadow(self, 0, 0, self.width, self.height, 14, 0.5)
    Draw.roundFrame(self, 0, 0, self.width, self.height, 6, 0.98, surface.line,
        surface.bg, 0.98)

    self:drawRect(1, 1, self.width - 2, self.titleH - 1, 0.9,
        surface.panel.r, surface.panel.g, surface.panel.b)
    self:drawText(self.titleText, PAD,
        math.floor((self.titleH - Style.FONT_H) / 2),
        surface.accent.r, surface.accent.g, surface.accent.b, 1, Style.FONT)

    drawTabs(self, surface)
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
    Draw.disc(self, cx, cy, chip, 1,
        overClose and surface.accent or surface.line)
    Draw.disc(self, cx + 1, cy + 1, chip - 2, 1,
        overClose and surface.cardHi or surface.card)
    local closeTex = Draw.closeTexture()
    local glyphSize = math.floor(chip * 0.5 + 0.5)
    local glyphInset = math.floor((chip - glyphSize) * 0.5)
    if closeTex ~= nil then
        self:drawTextureScaled(closeTex, cx + glyphInset, cy + glyphInset,
            glyphSize, glyphSize, overClose and 1 or 0.85,
            surface.accent.r, surface.accent.g, surface.accent.b)
    else
        self:drawText("X", cx + glyphInset, cy, surface.accent.r,
            surface.accent.g, surface.accent.b, 1, Style.FONT)
    end
    self._closeX, self._closeY, self._closeS = cx, cy, chip

    if self.dragRow ~= nil then
        if isMouseButtonDown ~= nil and not isMouseButtonDown(0) then
            self:commitDrag()
        else
            self:updateDrag()
        end
    end

    if self.textFitFont ~= Style.FONT then refreshTextFits(self) end

    for i = 1, #self.rows do
        local row = self.rows[i]
        local y, h = rowBounds(self, i)
        if y ~= nil then

            local applies = Settings.appliesNow(row.def, self.playerNum)

            local hot = self.hotRow == i and applies
            if hot then
                self:drawRect(PAD - 4, y, self.width - (PAD - 4) * 2, h,
                    0.35, surface.card.r, surface.card.g, surface.card.b)
            end
            local cbx, cby, cbw, cbh = controlBox(self, y, h)

            local bodyText = Style.COLORS.BODY_TEXT
            self:drawText(row.labelText, PAD,
                y + math.floor((h - Style.FONT_H) / 2),
                bodyText.r, bodyText.g, bodyText.b, applies and 1 or 0.4,
                Style.FONT)
            if not applies then

                local note = row.padNoteText
                if note ~= nil then
                    self:drawText(note, cbx,
                        cby + math.floor((cbh - Style.FONT_H) / 2),
                        bodyText.r, bodyText.g, bodyText.b, 0.45, Style.FONT)
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
        surface.line.r, surface.line.g, surface.line.b)
    if self.hotReset then
        self:drawRect(PAD - 4, ry, self.width - (PAD - 4) * 2, rh, 0.35,
            surface.card.r, surface.card.g, surface.card.b)
    end
    local footerTextY = ry + math.floor((rh - Style.FONT_H) / 2)
    self:drawText(self.resetRow.label, PAD, footerTextY,
        surface.accent.r, surface.accent.g, surface.accent.b,
        self.hotReset and 1 or 0.8, Style.FONT)

    self:drawText(versionLabel(), self.width - PAD - (self.versionW or 0),
        footerTextY, surface.line.r, surface.line.g, surface.line.b, 1,
        Style.FONT)

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

function SettingsPopup.render(_self)
end

function SettingsPopup:updateDrag()
    local rowIndex = self.dragRow
    local row = self.rows[rowIndex]
    if row == nil or row.def == nil then return end
    local y, h = rowBounds(self, rowIndex)
    if y == nil then return end
    local x, _, w = controlBox(self, y, h)
    local trackW = w - 34
    if trackW < 1 then return end
    local fraction = (self:getMouseX() - x) / trackW
    if fraction < 0 then fraction = 0 elseif fraction > 1 then fraction = 1 end
    local def = row.def
    local raw = def.min + fraction * (def.max - def.min)

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
                local defaultValue = Settings.defaults[def.key]
                if defaultValue ~= nil then
                    pcall(Settings.set, def.key, defaultValue)
                end
            end
        end
    end
    Settings.save()
    SettingsPopup.refreshKeybinds()
end

local function activateRow(self, rowIndex)
    local row = self.rows[rowIndex]
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
        pcall(Settings.set, def.key, Settings.get(def.key) ~= true)
    elseif row.kind == "choice" then

        pcall(Settings.set, def.key, stepChoice(def, 1))
    end
end

function SettingsPopup:selectTab(tabIndex)
    if tabIndex == nil or tabIndex == self.tab then return end
    local tab = self.tabs[tabIndex]
    if tab == nil then return end
    self.tab = tabIndex
    lastTab = tabIndex
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
    local closeSize = self._closeS
    if closeSize ~= nil and x >= self._closeX
            and x < self._closeX + closeSize
            and y >= self._closeY and y < self._closeY + closeSize then
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

function SettingsPopup.onRightMouseDown(_self, _x, _y)
    return true
end

function SettingsPopup.onRightMouseUp(_self, _x, _y)
    return true
end

function SettingsPopup.onMouseWheel(_self, _del)
    return true
end

function SettingsPopup.current()
    return openPanel
end

function SettingsPopup.refreshKeybinds()
    local self = openPanel
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

local function padRowUsable(self, rowIndex)
    if rowIndex == PAD_TABS then return true end
    if rowIndex == #self.rows + 1 then return true end
    local row = self.rows[rowIndex]
    if row == nil then return false end
    return Settings.appliesNow(row.def, self.playerNum)
end

local function padMove(self, delta)
    local last = #self.rows + 1
    local rowIndex = self.padRow or PAD_TABS
    for _ = 1, last + 1 do
        rowIndex = wrapStep(rowIndex, delta, PAD_TABS, last)
        if padRowUsable(self, rowIndex) then
            self.padRow = rowIndex
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

        pcall(Settings.set, def.key, stepChoice(def, dir))
    elseif def.kind == "slider" then
        local value = (Settings.get(def.key) or def.min) + dir * (def.step or 1)
        if value < def.min then
            value = def.min
        elseif value > def.max then
            value = def.max
        end
        pcall(Settings.set, def.key, value)
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
        self:selectTab(wrapStep(self.tab or 1, -1, 1, #self.tabs))
    else
        padAdjust(self, -1)
    end
end

function SettingsPopup:onJoypadDirRight(_joypadData)
    if self.padRow == PAD_TABS then
        self:selectTab(wrapStep(self.tab or 1, 1, 1, #self.tabs))
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
    if openPanel == self then openPanel = nil end
    lastClosedMs = getTimestampMs()
end

function SettingsPopup.openFor(windowStrip)
    if windowStrip == nil then return nil end
    local host = windowStrip.parent
    if host == nil then return nil end

    PopupRegistry.closeOthers(nil)
    if openPanel ~= nil then openPanel:close() end

    local ax = (windowStrip:getAbsoluteX() or 0) + windowStrip.width
    local rect = windowStrip.chips ~= nil and windowStrip.chips.rectOf ~= nil
        and windowStrip.chips:rectOf("settings") or nil
    if rect ~= nil then
        ax = (windowStrip:getAbsoluteX() or 0) + rect.x + rect.s
    end
    local ay = (windowStrip:getAbsoluteY() or 0) + windowStrip.height + 2
    local popup = SettingsPopup:new(0, ay, host)

    popup:setX(ax - popup.width)
    popup:initialise()
    popup:addToUIManager()
    popup:bringToTop()
    popup:clampToScreen()
    openPanel = popup

    SettingsPopup.padFocus(popup, host.parent or host)
    return popup
end

function SettingsPopup.toggleFor(windowStrip)
    if openPanel ~= nil then
        openPanel:close()
        return nil
    end
    if sinceClose() < REOPEN_GUARD_MS then return nil end
    local ok, popup = pcall(SettingsPopup.openFor, windowStrip)
    if not ok then
        Log.error("SettingsPopup: open failed: " .. tostring(popup))
        return nil
    end
    return popup
end

PopupRegistry.register("SettingsPopup", SettingsPopup.current,
    { dismissable = false })
