--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.4.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Model/Capacity"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/GridView"
require "ComfyGrid/UI/EquipmentStrip"
require "ComfyGrid/UI/HotbarStrip"
require "ComfyGrid/UI/PocketsPanel"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local ContainerPanel = ISPanel:derive("ComfyContainerPanel")
ComfyGrid.UI.ContainerPanel = ContainerPanel

local Capacity = ComfyGrid.Model.Capacity
local Style = ComfyGrid.UI.Style
local GridView = ComfyGrid.UI.GridView
local EquipmentStrip = ComfyGrid.UI.EquipmentStrip
local HotbarStrip = ComfyGrid.UI.HotbarStrip
local PocketsPanel = ComfyGrid.UI.PocketsPanel

local STRIP_GAP = 2

local SECTION_PAD = 4

local _surf = Style.COLORS and Style.COLORS.SURFACE
local SECTION_TEXT = _surf
    and { r = _surf.accent.r, g = _surf.accent.g, b = _surf.accent.b, a = 0.92 }
    or { r = 0.66, g = 0.66, b = 0.72, a = 0.95 }
local SECTION_LINE = _surf
    and { r = _surf.line.r, g = _surf.line.g, b = _surf.line.b, a = 0.60 }
    or { r = 0.45, g = 0.45, b = 0.50, a = 0.55 }

local Text = ComfyGrid.Core.Text

local sectionCache = {}
local function sectionInfo(key, fallback)
    local info = sectionCache[key]
    if info == nil then
        local label = Text.tr(key, fallback)
        local width = 0
        local tm = getTextManager and getTextManager() or nil
        if tm ~= nil then
            local ok, w = pcall(tm.MeasureStringX, tm, UIFont.Small, label)
            width = ok and w or 0
        end
        info = { label = label, width = width }
        sectionCache[key] = info
    end
    return info
end

local metricsGen = 0
Style.onScaleChanged(function()
    metricsGen = metricsGen + 1
    for k in pairs(sectionCache) do sectionCache[k] = nil end
end)

local function drawSection(self, info, y, rightText, rightW)
    self:drawText(info.label, SECTION_PAD, y + 1,
        SECTION_TEXT.r, SECTION_TEXT.g, SECTION_TEXT.b, SECTION_TEXT.a,
        UIFont.Small)
    local rightPad = 0
    if rightText ~= nil then
        self:drawTextRight(rightText, self.width - SECTION_PAD, y + 1,
            SECTION_TEXT.r, SECTION_TEXT.g, SECTION_TEXT.b, SECTION_TEXT.a,
            UIFont.Small)
        rightPad = (rightW or 0) + 6
    end
    local lineX = SECTION_PAD + info.width + 6
    local lineW = self.width - SECTION_PAD - lineX - rightPad
    if lineW > 0 then
        self:drawRect(lineX, y + math.floor(Style.FONT_H / 2), lineW, 1,
            SECTION_LINE.a, SECTION_LINE.r, SECTION_LINE.g, SECTION_LINE.b)
    end
end

local HEADER_PAD = 4

local function fmtWeight(cur, max)
    local c = string.format("%.1f", cur)
    c = c:gsub("%.0$", "")
    return c .. "/" .. tostring(math.floor(max + 0.5))
end

local function headerHeight()
    return math.max(18, Style.FONT_H + 4, math.floor(Style.CELL / 2))
end

local function resolveDisplayName(inventory, playerNum)
    if not inventory then return "?" end

    local containing = inventory:getContainingItem()
    if containing then
        local name = containing:getName()
        if name then return name end
    end

    local playerObj = playerNum ~= nil and getSpecificPlayer(playerNum) or nil
    if playerObj and inventory == playerObj:getInventory() then
        return getText("IGUI_InventoryTooltip")
    end

    local invType = inventory:getType()
    return getTextOrNull("IGUI_ContainerTitle_" .. invType) or invType
end

local function applyModel(self, model)
    self.model = model
    self.headerName = nil
    self._wtKey = nil
    self._wtText = nil
    self._wtW = nil
    self._nameFitKey = nil
    self._nameFit = nil
    if model then

        local ok, name = pcall(resolveDisplayName, model.inventory, self.playerNum)
        self.headerName = (ok and name) or "?"
    end
end

function ContainerPanel:new(x, y, model, playerNum)

    local o = ISPanel:new(x, y, 1, headerHeight() + 1)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.gridView = nil

    o.showStrips = false

    o.background = false

    o.keepOnScreen = false
    applyModel(o, model)
    return o
end

function ContainerPanel:createChildren()
    if not self.gridView then
        self:_buildGridView()
    end
    self:_syncEquipStrip()
end

function ContainerPanel:setShowStrips(want)
    want = want and true or false
    if self.showStrips ~= want then
        self.showStrips = want
        self:_syncEquipStrip()
    end
end

function ContainerPanel:setPocketInventories(invs)
    local pp = self.pocketsPanel
    if invs == nil or #invs == 0 or not self.showStrips then
        if pp ~= nil then
            self:removeChild(pp)
            self.pocketsPanel = nil
        end
        return
    end
    if pp == nil then
        pp = PocketsPanel:new(0, 0, self.playerNum)
        pp:initialise()
        self:addChild(pp)
        self.pocketsPanel = pp
    end
    pp:setInventories(invs)
end

function ContainerPanel:_syncEquipStrip()
    local wantStrip = self.showStrips
    if wantStrip and self.equipStrip == nil then
        local strip = EquipmentStrip:new(0, headerHeight(), self.playerNum)
        strip:initialise()
        self:addChild(strip)
        self.equipStrip = strip
    elseif not wantStrip and self.equipStrip ~= nil then
        self:removeChild(self.equipStrip)
        self.equipStrip = nil
    end
    if wantStrip and self.hotbarStrip == nil then
        local strip = HotbarStrip:new(0, headerHeight(), self.playerNum)
        strip:initialise()
        self:addChild(strip)
        self.hotbarStrip = strip
    elseif not wantStrip and self.hotbarStrip ~= nil then
        self:removeChild(self.hotbarStrip)
        self.hotbarStrip = nil
    end
end

function ContainerPanel:_buildGridView()
    if not self.model then return end
    local gv = GridView:new(0, headerHeight(), self.model, self.playerNum)
    gv.compactEligible = true
    gv:initialise()
    self:addChild(gv)
    self.gridView = gv
end

function ContainerPanel:setModel(model)
    if model == self.model then return end
    applyModel(self, model)
    if self.gridView then
        self:removeChild(self.gridView)
        self.gridView = nil
    end
    self:_buildGridView()
    self:_syncEquipStrip()
end

function ContainerPanel:prerender()

    if (self.equipStrip == nil or self.hotbarStrip == nil)
            and self.showStrips then
        self:_syncEquipStrip()
    end

    local strip = self.equipStrip
    local hotbar = self.hotbarStrip
    local headerH = strip and 0 or headerHeight()
    local sectionH = Style.FONT_H

    local gridTop = headerH
    local hotbarTitleY = nil
    if strip then
        local stripY = headerH + sectionH
        strip:setAvailableWidth(self.width)
        if strip.x ~= 0 then strip:setX(0) end
        if strip.y ~= stripY then strip:setY(stripY) end
        gridTop = stripY + strip.height + STRIP_GAP

        if hotbar then
            hotbar:setAvailableWidth(self.width)
            if hotbar.x ~= 0 then hotbar:setX(0) end
            if hotbar.entryCount > 0 then
                hotbarTitleY = gridTop
                local hotbarY = hotbarTitleY + sectionH
                if hotbar.y ~= hotbarY then hotbar:setY(hotbarY) end
                gridTop = hotbarY + hotbar.height + STRIP_GAP
            end
        end

        local pocketsPanel = self.pocketsPanel
        if pocketsPanel ~= nil then
            if pocketsPanel.width ~= self.width then
                pocketsPanel:setWidth(self.width)
            end
            if pocketsPanel.x ~= 0 then pocketsPanel:setX(0) end
            if pocketsPanel.y ~= gridTop then pocketsPanel:setY(gridTop) end
            gridTop = gridTop + pocketsPanel.height + STRIP_GAP
        end
        gridTop = gridTop + sectionH
    end
    self._hotbarTitleY = hotbarTitleY
    local gv = self.gridView
    if gv then

        gv:setAvailableWidth(self.width)
        if gv.x ~= 0 then gv:setX(0) end
        if gv.y ~= gridTop then gv:setY(gridTop) end
        local h = gridTop + gv.height
        if self.height ~= h then self:setHeight(h) end
    end

    local tm = getTextManager()
    local wtText = nil
    local inv = self.model ~= nil and self.model.inventory or nil
    if inv ~= nil then
        local cur, cmax = nil, nil
        local okC, c = pcall(inv.getCapacityWeight, inv)
        if okC and type(c) == "number" then cur = c end
        local playerObj = self.playerNum ~= nil
            and getSpecificPlayer(self.playerNum) or nil
        if playerObj ~= nil and inv == playerObj:getInventory() then
            local okM, m = pcall(playerObj.getMaxWeight, playerObj)
            if okM and type(m) == "number" then cmax = m end
        else

            cmax = Capacity.effectiveFor(inv, self.playerNum)
        end
        if cur ~= nil and cmax ~= nil then
            local key = math.floor(cur * 10 + 0.5) * 1000 + cmax
            if self._wtKey ~= key or self._wtGen ~= metricsGen then
                self._wtKey = key
                self._wtGen = metricsGen
                self._wtText = fmtWeight(cur, cmax)
                local okW, wpx = pcall(tm.MeasureStringX, tm, UIFont.Small,
                    self._wtText)
                self._wtW = okW and wpx or 0
                self._nameFitKey = nil
            end
            wtText = self._wtText
        end
    end
    if not strip then

        local fontHgt = tm:getFontHeight(UIFont.Small)
        local textY = math.floor((headerH - fontHgt) / 2)
        if wtText ~= nil then
            self:drawTextRight(wtText, self.width - HEADER_PAD, textY,
                SECTION_TEXT.r, SECTION_TEXT.g, SECTION_TEXT.b,
                SECTION_TEXT.a, UIFont.Small)
        end
        local nameW = 0
        if self.headerName then
            local wtW = wtText ~= nil and ((self._wtW or 0) + 6) or 0
            local fitKey = self.width * 10000 + wtW
            if self._nameFitKey ~= fitKey or self._nameFitGen ~= metricsGen then
                self._nameFitKey = fitKey
                self._nameFitGen = metricsGen
                self._nameFit = Text.fitEllipsis(self.headerName, UIFont.Small,
                    self.width - HEADER_PAD * 2 - wtW, 60)
                local okW, npx = pcall(tm.MeasureStringX, tm, UIFont.Small,
                    self._nameFit)
                self._nameFitW = okW and npx or 0
            end
            self:drawText(self._nameFit, HEADER_PAD, textY,
                SECTION_TEXT.r, SECTION_TEXT.g, SECTION_TEXT.b,
                SECTION_TEXT.a, UIFont.Small)
            nameW = self._nameFitW or 0
        end
        local lineX = HEADER_PAD + nameW + 6
        local lineW = self.width - HEADER_PAD - lineX
            - (wtText ~= nil and ((self._wtW or 0) + 6) or 0)
        if lineW > 0 then
            self:drawRect(lineX, textY + math.floor(fontHgt / 2), lineW, 1,
                SECTION_LINE.a, SECTION_LINE.r, SECTION_LINE.g,
                SECTION_LINE.b)
        end
    else

        drawSection(self, sectionInfo("IGUI_ComfyGrid_SectionEquipment",
            "Equipment"), headerH)
        if self._hotbarTitleY then
            drawSection(self, sectionInfo("IGUI_ComfyGrid_SectionHotbar",
                "Hotbar"), self._hotbarTitleY)
        end
        if gridTop then
            drawSection(self, sectionInfo("IGUI_ComfyGrid_SectionInventory",
                "Inventory"), gridTop - sectionH, wtText, self._wtW)
        end
    end
end
