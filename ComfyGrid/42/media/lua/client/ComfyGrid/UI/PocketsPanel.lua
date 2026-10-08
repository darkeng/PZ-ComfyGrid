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
require "ComfyGrid/Model/Capacity"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/Model/ContainerName"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Chrome/SectionRule"
require "ComfyGrid/UI/GridView"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local PocketsPanel = ISPanel:derive("ComfyPocketsPanel")
ComfyGrid.UI.PocketsPanel = PocketsPanel

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local Capacity = ComfyGrid.Model.Capacity
local ContainerModel = ComfyGrid.Model.ContainerModel
local ContainerName = ComfyGrid.Model.ContainerName
local Style = ComfyGrid.UI.Style
local SectionRule = ComfyGrid.UI.Chrome.SectionRule
local GridView = ComfyGrid.UI.GridView

local PLATE_BLEED = 3

local GAP_X = 6
local GAP_Y = 6
local ACCENT_H = 2

local function labelHeight()
    local h = Style.FONT_H - 3
    if h < 10 then h = 10 end
    return h
end

local metricsGen = 0
Style.onScaleChanged(function()
    metricsGen = metricsGen + 1
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

    o._liveInventories = {}
    o._liveModels = {}
    return o
end

function PocketsPanel:setInventories(inventories)
    local stored = self.inventories
    for i = #stored, 1, -1 do stored[i] = nil end
    for i = 1, #inventories do stored[i] = inventories[i] end
end

local function resolveLabel(inv)
    local ok, containing = pcall(inv.getContainingItem, inv)
    if ok and containing ~= nil then
        local okName, name = pcall(containing.getName, containing)
        if okName and name ~= nil then return name end
    end
    return "?"
end

local function prerenderImpl(self)
    local inventories = self.inventories
    local islands = self.islands
    local gridViews = self.gridViews

    local liveInv = self._liveInventories
    local liveModel = self._liveModels
    for i = #liveInv, 1, -1 do liveInv[i] = nil end
    for i = #liveModel, 1, -1 do liveModel[i] = nil end
    for i = 1, #inventories do
        local model = ContainerModel.getOrCreate(inventories[i], self.playerNum)
        if model ~= nil then
            liveInv[#liveInv + 1] = inventories[i]
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

    local nameGen = ContainerName.renameGeneration()
    if self._nameGen ~= nameGen then
        self._nameGen = nameGen
        for i = 1, #islands do
            local island = islands[i]
            if island ~= nil and island.inv ~= nil then
                local fresh = resolveLabel(island.inv)
                if fresh ~= nil and fresh ~= island.label then
                    island.label = fresh
                    island.fitFor = nil
                end
            end
        end
    end

    local w = self.width
    local stride = Style.CELL_STRIDE
    local sectionH = Style.FONT_H
    local labelH = labelHeight()

    local x = PLATE_BLEED
    local y = sectionH
    local lineH = 0
    for i = 1, #islands do
        local gv = islands[i].gv
        local grid = gv.model ~= nil and gv.model.grid or nil
        local slotCount = grid ~= nil and grid:slotCount() or 2
        local natural = slotCount * stride + 1
        local room = w - PLATE_BLEED * 2
        if room < 1 then room = 1 end
        gv:setAvailableWidth(natural <= room and natural or room)
        local boardW = gv.width
        local boardH = gv.height

        if x > PLATE_BLEED and x + boardW + PLATE_BLEED > w then
            x = PLATE_BLEED
            y = y + lineH + GAP_Y
            lineH = 0
        end

        local boardY = y + labelH + ACCENT_H + 1
        if gv.x ~= x then gv:setX(x) end
        if gv.y ~= boardY then gv:setY(boardY) end
        x = x + boardW + GAP_X
        local islandH = labelH + ACCENT_H + 1 + boardH
        if islandH > lineH then lineH = islandH end
    end
    local h = y + lineH
    if h < sectionH + 1 then h = sectionH + 1 end
    if self.height ~= h then self:setHeight(h) end

    local Draw = ComfyGrid.UI.Draw
    local surface = Style.COLORS and Style.COLORS.SURFACE
    if Draw ~= nil and surface ~= nil then
        for i = 1, #islands do
            local gv = islands[i].gv
            local px = gv.x - PLATE_BLEED
            local py = gv.y - ACCENT_H - 1 - labelH - 2
            local pw = gv.width + PLATE_BLEED * 2
            local ph = labelH + ACCENT_H + 1 + gv.height + 5
            Draw.roundFrame(self, px, py, pw, ph, 6, 0.45, surface.line,
                surface.panel, 0.55)
        end
    end

    SectionRule.draw(self, SectionRule.info("IGUI_ComfyGrid_SectionPockets",
        "Pockets"), 0, sectionH)
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
    local textManager = getTextManager and getTextManager() or nil
    local accents = Style.COLORS.POCKET_ACCENTS
    local labelColor = Style.COLORS.POCKET_LABEL
    for i = 1, #islands do
        local island = islands[i]
        local gv = island.gv
        local boardW = gv.width
        local accentY = gv.y - ACCENT_H - 1
        local capY = accentY - labelH
        local accent = accents[(i - 1) % #accents + 1]
        self:drawRect(gv.x, accentY, boardW, ACCENT_H,
            accent.a, accent.r, accent.g, accent.b)
        if font ~= nil then

            local load, capacity = 0, 0

            local islandGrid = gv.model ~= nil and gv.model.grid or nil
            local weight = Capacity.weightOf(island.inv,
                islandGrid ~= nil and islandGrid.changeCount or nil)
            if type(weight) == "number" then load = weight end

            local effectiveCapacity = Capacity.effectiveFor(island.inv,
                self.playerNum)
            if type(effectiveCapacity) == "number" then
                capacity = effectiveCapacity
            end
            local key = math.floor(load * 10 + 0.5) * 1000 + capacity
            if island.wtKey ~= key or island.gen ~= metricsGen then
                island.wtKey = key
                island.gen = metricsGen
                island.wtText = Text.formatLoad(load, capacity)
                island.wtW = 0
                if textManager ~= nil then
                    local okWidth, weightW = pcall(textManager.MeasureStringX,
                        textManager, font, island.wtText)
                    if okWidth then island.wtW = weightW end
                end
                island.fitFor = nil
            end

            if island.fitFor ~= boardW then
                island.fitFor = boardW
                island.fitName = Text.fitEllipsis(island.label, font,
                    boardW - island.wtW - 8, 24)
            end
            self:drawText(island.fitName, gv.x + 1, capY,
                labelColor.r, labelColor.g, labelColor.b, labelColor.a, font)
            self:drawTextRight(island.wtText, gv.x + boardW - 1, capY,
                labelColor.r, labelColor.g, labelColor.b, labelColor.a, font)
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
