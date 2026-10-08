--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
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

local CONTENT_INSET = 6

function PaneHost:showsInventory(inv)
    if inv == nil then return false end
    local panels = self.panels
    if panels ~= nil then
        for i = 1, #panels do
            local panel = panels[i]
            if panel ~= nil and panel.model ~= nil and panel.model.inventory == inv
                    and panel:getIsVisible() then
                return true
            end
        end
    end
    local strips = self.strips
    local pockets = strips ~= nil and strips.pocketsPanel or nil
    local views = pockets ~= nil and pockets.gridViews or nil
    if views ~= nil then
        for i = 1, #views do
            local gridView = views[i]
            if gridView ~= nil and gridView.model ~= nil
                    and gridView.model.inventory == inv then
                return true
            end
        end
    end
    return false
end

function PaneHost.paneOf(element, playerNum)
    local node = element ~= nil and element.parent or nil
    while node ~= nil do
        if node.pane ~= nil then return node.pane end
        node = node.parent
    end
    local okPage, page = pcall(getPlayerInventory, playerNum or 0)
    if okPage and page ~= nil then return page.inventoryPane end
    return nil
end

local SECTION_GAP = 6

function PaneHost:new(pane)
    local w = math.max(1,
        (pane.width or 1) - SCROLLBAR_ALLOWANCE - CONTENT_INSET)
    local h = math.max(1, pane.height or 1)
    local o = ISUIElement:new(CONTENT_INSET, 0, w, h)
    setmetatable(o, self)
    self.__index = self
    o.pane = pane

    o.yOffset = 0

    o.shownInventory = nil

    o.panels = {}

    o.strips = nil
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

local function panelShowsInventory(panel, inv)
    return panel.model ~= nil and panel.model.inventory == inv
end

local function layout(self)
    local pane = self.pane
    if not pane then return end

    local w = (pane.width or 1) - SCROLLBAR_ALLOWANCE - CONTENT_INSET
    if w < 1 then w = 1 end
    local h = pane.height or 1
    if h < 1 then h = 1 end
    if self.x ~= CONTENT_INSET then self:setX(CONTENT_INSET) end
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
    local panelCount = 0
    for i = 1, plan.count do
        local model = ContainerModel.getOrCreate(plan.sections[i], pane.player)
        if model ~= nil then
            panelCount = panelCount + 1
            local panel = panels[panelCount]
            if panel == nil then
                panel = ContainerPanel:new(0, 0, model, pane.player)
                panel:initialise()
                self:addChild(panel)
                panels[panelCount] = panel
            elseif panel.model ~= model then
                panel:setModel(model)
            end
        end
    end

    for i = #panels, panelCount + 1, -1 do
        panels[i]:setVisible(false)
        self:removeChild(panels[i])
        panels[i] = nil
    end
    self.panelShown = panelCount > 0

    if pane.inventory ~= self.shownInventory then
        self.shownInventory = pane.inventory
        if not plan.stacked then
            self.yOffset = 0
        else
            local y = stripsHeight(self)
            for i = 1, panelCount do
                if panelShowsInventory(panels[i], pane.inventory) then
                    self.yOffset = y
                    break
                end
                y = y + panels[i].height + SECTION_GAP
            end
        end
    end

    local contentH = stripsHeight(self)
    for i = 1, panelCount do
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
        local stripsY = -self.yOffset
        if strips.y ~= stripsY then strips:setY(stripsY) end
        y = strips.height + SECTION_GAP
    end
    for i = 1, panelCount do
        local panel = panels[i]
        if panel.width ~= w then panel:setWidth(w) end
        if panel.x ~= 0 then panel:setX(0) end
        if i > 1 then y = y + SECTION_GAP end
        local panelY = y - self.yOffset
        if panel.y ~= panelY then panel:setY(panelY) end
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

function PaneHost:onMouseWheel(wheelDelta)

    local page = self.pane and self.pane.inventoryPage
    if page and (page.isCollapsed or page:isCycleContainerKeyDown()) then
        return false
    end
    local maxOffset = (self.contentHeight or 0) - self:viewportHeight()
    if maxOffset < 0 then maxOffset = 0 end

    self.yOffset = Util.clamp(self.yOffset + wheelDelta * Style.CELL_STRIDE,
        0, maxOffset)
    return true
end
