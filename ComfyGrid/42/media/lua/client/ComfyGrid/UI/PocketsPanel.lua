--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.4.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Model/Capacity"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/GridView"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local PocketsPanel = ISPanel:derive("ComfyPocketsPanel")
ComfyGrid.UI.PocketsPanel = PocketsPanel

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local Capacity = ComfyGrid.Model.Capacity
local ContainerModel = ComfyGrid.Model.ContainerModel
local Style = ComfyGrid.UI.Style
local GridView = ComfyGrid.UI.GridView

local SECTION_PAD = 4

local _surf = Style.COLORS and Style.COLORS.SURFACE
local SECTION_TEXT = _surf
    and { r = _surf.accent.r, g = _surf.accent.g, b = _surf.accent.b, a = 0.92 }
    or { r = 0.66, g = 0.66, b = 0.72, a = 0.95 }
local SECTION_LINE = _surf
    and { r = _surf.line.r, g = _surf.line.g, b = _surf.line.b, a = 0.60 }
    or { r = 0.45, g = 0.45, b = 0.50, a = 0.55 }

local GAP_X = 6
local GAP_Y = 6
local ACCENT_H = 2
local LABEL_COLOR = { r = 0.62, g = 0.62, b = 0.68, a = 0.9 }

local function labelHeight()
    local h = Style.FONT_H - 3
    if h < 10 then h = 10 end
    return h
end

local ACCENTS = {
    { r = 0.82, g = 0.65, b = 0.38, a = 0.9 },
    { r = 0.35, g = 0.75, b = 1.00, a = 0.9 },
    { r = 0.59, g = 0.78, b = 0.47, a = 0.9 },
    { r = 0.71, g = 0.55, b = 0.86, a = 0.9 },
}

local function fmtWeight(cur, max)
    local c = string.format("%.1f", cur)
    c = c:gsub("%.0$", "")
    return c .. "/" .. tostring(math.floor(max + 0.5))
end

local titleInfo = nil
local function sectionInfo()
    if titleInfo == nil then
        local label = Text.tr("IGUI_ComfyGrid_SectionPockets", "Pockets")
        local width = 0
        local tm = getTextManager and getTextManager() or nil
        if tm ~= nil then
            local ok, w = pcall(tm.MeasureStringX, tm, UIFont.Small, label)
            width = ok and w or 0
        end
        titleInfo = { label = label, width = width }
    end
    return titleInfo
end

local metricsGen = 0
Style.onScaleChanged(function()
    metricsGen = metricsGen + 1
    titleInfo = nil
end)

local lastPrerenderError = nil
local lastRenderError = nil

function PocketsPanel:new(x, y, playerNum)
    local o = ISPanel:new(x, y, 1, Style.FONT_H + 1)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.background = false
    o.keepOnScreen = false

    o.inventories = {}

    o.islands = {}
    o.gridViews = {}
    return o
end

function PocketsPanel:setInventories(invs)
    local mine = self.inventories
    for i = #mine, 1, -1 do mine[i] = nil end
    for i = 1, #invs do mine[i] = invs[i] end
end

local function resolveLabel(inv)
    local ok, containing = pcall(inv.getContainingItem, inv)
    if ok and containing ~= nil then
        local okN, n = pcall(containing.getName, containing)
        if okN and n ~= nil then return n end
    end
    return "?"
end

local function prerenderImpl(self)
    local invs = self.inventories
    local islands = self.islands
    local gridViews = self.gridViews

    local liveInv = {}
    local liveModel = {}
    for i = 1, #invs do
        local model = ContainerModel.getOrCreate(invs[i], self.playerNum)
        if model ~= nil then
            liveInv[#liveInv + 1] = invs[i]
            liveModel[#liveModel + 1] = model
        end
    end

    local mismatch = #islands ~= #liveInv
    if not mismatch then
        for i = 1, #islands do
            if islands[i].inv ~= liveInv[i]
                    or islands[i].gv.model ~= liveModel[i] then
                mismatch = true
                break
            end
        end
    end
    if mismatch then
        for i = 1, #islands do
            self:removeChild(islands[i].gv)
            islands[i] = nil
            gridViews[i] = nil
        end
        for i = 1, #liveInv do
            local gv = GridView:new(0, 0, liveModel[i], self.playerNum)
            gv:initialise()
            self:addChild(gv)
            islands[i] = { inv = liveInv[i], gv = gv,
                label = resolveLabel(liveInv[i]), fitFor = nil, fitName = nil }
            gridViews[i] = gv
        end
    end

    local w = self.width
    local stride = Style.CELL_STRIDE
    local sectionH = Style.FONT_H
    local labelH = labelHeight()
    local x = 0
    local y = sectionH
    local lineH = 0
    for i = 1, #islands do
        local gv = islands[i].gv
        local grid = gv.model ~= nil and gv.model.grid or nil
        local sc = grid ~= nil and grid:slotCount() or 2
        local natural = sc * stride + 1
        gv:setAvailableWidth(natural <= w and natural or w)
        local gw = gv.width
        local gh = gv.height
        if x > 0 and x + gw > w then
            x = 0
            y = y + lineH + GAP_Y
            lineH = 0
        end

        local boardY = y + labelH + ACCENT_H + 1
        if gv.x ~= x then gv:setX(x) end
        if gv.y ~= boardY then gv:setY(boardY) end
        x = x + gw + GAP_X
        local hh = labelH + ACCENT_H + 1 + gh
        if hh > lineH then lineH = hh end
    end
    local h = y + lineH
    if h < sectionH + 1 then h = sectionH + 1 end
    if self.height ~= h then self:setHeight(h) end

    local Draw = ComfyGrid.UI.Draw
    local surf = Style.COLORS and Style.COLORS.SURFACE
    if Draw ~= nil and surf ~= nil then
        local labelHp = labelHeight()
        for i = 1, #islands do
            local gv = islands[i].gv
            local px = gv.x - 3
            local py = gv.y - ACCENT_H - 1 - labelHp - 2
            local pw = gv.width + 6
            local ph = labelHp + ACCENT_H + 1 + gv.height + 5
            Draw.roundFrame(self, px, py, pw, ph, 6, 0.45, surf.line,
                surf.panel, 0.55)
        end
    end

    local info = sectionInfo()
    self:drawText(info.label, SECTION_PAD, 1,
        SECTION_TEXT.r, SECTION_TEXT.g, SECTION_TEXT.b, SECTION_TEXT.a,
        UIFont.Small)
    local lineX = SECTION_PAD + info.width + 6
    local lineW = self.width - SECTION_PAD - lineX
    if lineW > 0 then
        self:drawRect(lineX, math.floor(sectionH / 2), lineW, 1,
            SECTION_LINE.a, SECTION_LINE.r, SECTION_LINE.g, SECTION_LINE.b)
    end
end

function PocketsPanel:prerender()
    local ok, err = pcall(prerenderImpl, self)
    if not ok and err ~= lastPrerenderError then
        lastPrerenderError = err
        Log.error("PocketsPanel prerender failed: " .. tostring(err))
    end
end

local function renderImpl(self)
    local islands = self.islands
    local font = Style.FONT
    local labelH = labelHeight()
    local tm = getTextManager and getTextManager() or nil
    for i = 1, #islands do
        local isl = islands[i]
        local gv = isl.gv
        local gw = gv.width
        local accentY = gv.y - ACCENT_H - 1
        local capY = accentY - labelH
        local a = ACCENTS[(i - 1) % #ACCENTS + 1]
        self:drawRect(gv.x, accentY, gw, ACCENT_H, a.a, a.r, a.g, a.b)
        if font ~= nil then

            local cur, max = 0, 0
            local okC, c = pcall(isl.inv.getCapacityWeight, isl.inv)
            if okC and type(c) == "number" then cur = c end

            local m = Capacity.effectiveFor(isl.inv, self.playerNum)
            if type(m) == "number" then max = m end
            local key = math.floor(cur * 10 + 0.5) * 1000 + max
            if isl.wtKey ~= key or isl.gen ~= metricsGen then
                isl.wtKey = key
                isl.gen = metricsGen
                isl.wtText = fmtWeight(cur, max)
                isl.wtW = 0
                if tm ~= nil then
                    local okW, wpx = pcall(tm.MeasureStringX, tm, font,
                        isl.wtText)
                    if okW then isl.wtW = wpx end
                end
                isl.fitFor = nil
            end

            if isl.fitFor ~= gw then
                isl.fitFor = gw
                isl.fitName = Text.fitEllipsis(isl.label, font,
                    gw - isl.wtW - 8, 24)
            end
            self:drawText(isl.fitName, gv.x + 1, capY,
                LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, LABEL_COLOR.a,
                font)
            self:drawTextRight(isl.wtText, gv.x + gw - 1, capY,
                LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, LABEL_COLOR.a,
                font)
        end
    end
end

function PocketsPanel:render()
    local ok, err = pcall(renderImpl, self)
    if not ok and err ~= lastRenderError then
        lastRenderError = err
        Log.error("PocketsPanel render failed: " .. tostring(err))
    end
end
