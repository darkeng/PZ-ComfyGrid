--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Util"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/Model/SectionPlan"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/ContainerPanel"
require "ComfyGrid/UI/PlayerStrips"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local PaneHost = ISUIElement:derive("ComfyPaneHost")
ComfyGrid.UI.PaneHost = PaneHost

local Log = ComfyGrid.Core.Log
local Util = ComfyGrid.Core.Util
local ContainerModel = ComfyGrid.Model.ContainerModel
local SectionPlan = ComfyGrid.Model.SectionPlan
local Style = ComfyGrid.UI.Style
local ContainerPanel = ComfyGrid.UI.ContainerPanel
local PlayerStrips = ComfyGrid.UI.PlayerStrips

local SCROLLBAR_ALLOWANCE = 17

local SECTION_GAP = 6

function PaneHost:new(pane)
    local w = math.max(1, (pane.width or 1) - SCROLLBAR_ALLOWANCE)
    local h = math.max(1, pane.height or 1)
    local o = ISUIElement:new(0, 0, w, h)
    setmetatable(o, self)
    self.__index = self
    o.pane = pane

    o.yOffset = 0

    o.shownInventory = nil

    o.panels = {}

    o.strips = nil
    o.containerPanel = nil
    o.panelShown = false
    o.contentHeight = 0

    o.plan = SectionPlan.newPlan()
    o._layoutFailLogged = false

    o.keepOnScreen = false
    return o
end

local function stripsHeight(self)
    local strips = self.strips
    if strips == nil then return 0 end
    return (strips.height or 0) + SECTION_GAP
end

local function layout(self)
    local pane = self.pane
    if not pane then return end

    local w = (pane.width or 1) - SCROLLBAR_ALLOWANCE
    if w < 1 then w = 1 end
    local h = pane.height or 1
    if h < 1 then h = 1 end
    if self.width ~= w then self:setWidth(w) end
    if self.height ~= h then self:setHeight(h) end

    local page = pane.inventoryPage
    local plan = SectionPlan.build(self.plan, page, pane)

    local strips = self.strips
    if plan.playerStrips and strips == nil then
        strips = PlayerStrips:new(0, 0, pane.player)
        strips:initialise()
        self:addChild(strips)
        self.strips = strips
    elseif not plan.playerStrips and strips ~= nil then
        strips:setVisible(false)
        self:removeChild(strips)
        self.strips = nil
        strips = nil
    end
    if strips ~= nil then
        if strips.width ~= w then strips:setWidth(w) end
        strips:setPocketInventories(plan.pockets)
    end

    local panels = self.panels
    local shown = 0
    for i = 1, plan.count do
        local model = ContainerModel.getOrCreate(plan.sections[i], pane.player)
        if model ~= nil then
            shown = shown + 1
            local panel = panels[shown]
            if panel == nil then
                panel = ContainerPanel:new(0, 0, model, pane.player)
                panel:initialise()
                self:addChild(panel)
                panels[shown] = panel
            elseif panel.model ~= model then
                panel:setModel(model)
            end
        end
    end

    for i = #panels, shown + 1, -1 do
        panels[i]:setVisible(false)
        self:removeChild(panels[i])
        panels[i] = nil
    end
    self.containerPanel = panels[1]
    self.panelShown = shown > 0

    local function ownsInventory(panel, inv)
        return panel.model ~= nil and panel.model.inventory == inv
    end

    if pane.inventory ~= self.shownInventory then
        self.shownInventory = pane.inventory
        if not plan.stacked then
            self.yOffset = 0
        else
            local y = stripsHeight(self)
            for i = 1, shown do
                if ownsInventory(panels[i], pane.inventory) then
                    self.yOffset = y
                    break
                end
                y = y + panels[i].height + SECTION_GAP
            end
        end
    end

    local contentH = stripsHeight(self)
    for i = 1, shown do
        if i > 1 then contentH = contentH + SECTION_GAP end
        contentH = contentH + panels[i].height
    end
    self.contentHeight = contentH

    local maxOffset = contentH - self:viewportHeight()
    if maxOffset < 0 then maxOffset = 0 end
    if self.yOffset > maxOffset then self.yOffset = maxOffset end
    if self.yOffset < 0 then self.yOffset = 0 end

    local y = 0
    if strips ~= nil then
        if strips.x ~= 0 then strips:setX(0) end
        local sy = -self.yOffset
        if strips.y ~= sy then strips:setY(sy) end
        y = strips.height + SECTION_GAP
    end
    for i = 1, shown do
        local panel = panels[i]
        if panel.width ~= w then panel:setWidth(w) end
        if panel.x ~= 0 then panel:setX(0) end
        if i > 1 then y = y + SECTION_GAP end
        local py = y - self.yOffset
        if panel.y ~= py then panel:setY(py) end
        y = y + panel.height
    end
end

function PaneHost:viewportHeight()
    local h = self.height or 0
    return h > 0 and h or 0
end

function PaneHost:refreshLayout()
    local ok, err = pcall(layout, self)
    if not ok and not self._layoutFailLogged then
        self._layoutFailLogged = true
        Log.error("PaneHost layout failed: " .. tostring(err))
    end
end

function PaneHost:prerender()

    self:refreshLayout()

    pcall(self.setStencilRect, self, 0, 0, self.width, self.height)
end

function PaneHost:render()

    pcall(self.clearStencilRect, self)
end

function PaneHost:onMouseWheel(del)

    local page = self.pane and self.pane.inventoryPage
    if page and (page.isCollapsed or page:isCycleContainerKeyDown()) then
        return false
    end
    local maxOffset = (self.contentHeight or 0) - self:viewportHeight()
    if maxOffset < 0 then maxOffset = 0 end

    self.yOffset = Util.clamp(self.yOffset + del * Style.CELL_STRIDE, 0, maxOffset)
    return true
end
