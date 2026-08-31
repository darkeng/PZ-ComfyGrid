--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.4.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Util"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/Model/Capacity"
require "ComfyGrid/Settings"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/ContainerPanel"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local PaneHost = ISUIElement:derive("ComfyPaneHost")
ComfyGrid.UI.PaneHost = PaneHost

local Log = ComfyGrid.Core.Log
local Util = ComfyGrid.Core.Util
local ContainerModel = ComfyGrid.Model.ContainerModel
local Capacity = ComfyGrid.Model.Capacity
local Settings = ComfyGrid.Settings
local Style = ComfyGrid.UI.Style
local ContainerPanel = ComfyGrid.UI.ContainerPanel

local SCROLLBAR_ALLOWANCE = 17

local SECTION_GAP = 6

local POCKET_MAX_SLOTS = 6

local function lootSectionAllowed(page, inv, playerObj)
    local okP, parent = pcall(inv.getParent, inv)
    if okP and parent ~= nil and instanceof(parent, "IsoThumpable")
            and parent.isLockedToCharacter ~= nil then
        local okL, locked = pcall(parent.isLockedToCharacter, parent, playerObj)
        if okL and locked then return false end
    end
    if page.checkExplored ~= nil then
        pcall(page.checkExplored, page, inv, playerObj)
    end
    return true
end

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
    o.containerPanel = nil
    o.panelShown = false
    o.contentHeight = 0
    o._invList = {}
    o._bigList = {}
    o._handList = {}
    o._pocketList = {}
    o._layoutFailLogged = false

    o.keepOnScreen = false
    return o
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
    local sectioned = page ~= nil and page.onCharacter == true
    local lootSectioned = page ~= nil and page.onCharacter == false
        and Settings.get("LOOT_SECTIONS") == true
    local lootPlayer = lootSectioned and getSpecificPlayer(pane.player) or nil
    local invs = self._invList
    for i = #invs, 1, -1 do invs[i] = nil end
    if (sectioned or lootSectioned) and type(page.backpacks) == "table" then
        for i = 1, #page.backpacks do
            local inv = page.backpacks[i].inventory
            if inv ~= nil and (not lootSectioned
                    or lootSectionAllowed(page, inv, lootPlayer)) then
                local dup = false
                for j = 1, #invs do
                    if invs[j] == inv then
                        dup = true
                        break
                    end
                end
                if not dup then invs[#invs + 1] = inv end
            end
        end
    end
    if #invs == 0 and pane.inventory ~= nil then
        invs[1] = pane.inventory
    end

    local bigs = self._bigList
    local hands = self._handList
    local pockets = self._pocketList
    for i = #bigs, 1, -1 do bigs[i] = nil end
    for i = #hands, 1, -1 do hands[i] = nil end
    for i = #pockets, 1, -1 do pockets[i] = nil end
    local playerObj = sectioned and getSpecificPlayer(pane.player) or nil
    for i = 1, #invs do
        local inv = invs[i]
        if not sectioned or i == 1 then
            bigs[#bigs + 1] = inv
        elseif Capacity.slotsFor(inv, pane.player) <= POCKET_MAX_SLOTS then
            pockets[#pockets + 1] = inv
        else

            local held = false
            if playerObj ~= nil and playerObj.isHandItem ~= nil then
                local ok, containing = pcall(inv.getContainingItem, inv)
                if ok and containing ~= nil then
                    local okH, h2 = pcall(playerObj.isHandItem, playerObj,
                        containing)
                    held = okH and h2 == true
                end
            end
            if held then
                hands[#hands + 1] = inv
            else
                bigs[#bigs + 1] = inv
            end
        end
    end
    for i = 1, #hands do
        bigs[#bigs + 1] = hands[i]
    end

    local panels = self.panels
    local shown = 0
    for i = 1, #bigs do
        local model = ContainerModel.getOrCreate(bigs[i], pane.player)
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

            panel:setShowStrips(sectioned and shown == 1)
        end
    end

    for i = #panels, shown + 1, -1 do
        self:removeChild(panels[i])
        panels[i] = nil
    end
    self.containerPanel = panels[1]
    self.panelShown = shown > 0

    if panels[1] ~= nil and panels[1].setPocketInventories ~= nil then
        panels[1]:setPocketInventories(pockets)
    end

    local function ownsInventory(panel, inv)
        if panel.model ~= nil and panel.model.inventory == inv then
            return true
        end
        local pp = panel.pocketsPanel
        local list = pp ~= nil and pp.inventories or nil
        if list ~= nil then
            for i = 1, #list do
                if list[i] == inv then return true end
            end
        end
        return false
    end

    if pane.inventory ~= self.shownInventory then
        self.shownInventory = pane.inventory
        if not (sectioned or lootSectioned) then
            self.yOffset = 0
        else
            local y = 0
            for i = 1, shown do
                if ownsInventory(panels[i], pane.inventory) then
                    self.yOffset = y
                    break
                end
                y = y + panels[i].height + SECTION_GAP
            end
        end
    end

    local contentH = 0
    for i = 1, shown do
        if i > 1 then contentH = contentH + SECTION_GAP end
        contentH = contentH + panels[i].height
    end
    self.contentHeight = contentH
    local maxOffset = contentH - self.height
    if maxOffset < 0 then maxOffset = 0 end
    if self.yOffset > maxOffset then self.yOffset = maxOffset end
    if self.yOffset < 0 then self.yOffset = 0 end

    local y = 0
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
    local maxOffset = (self.contentHeight or 0) - self.height
    if maxOffset < 0 then maxOffset = 0 end

    self.yOffset = Util.clamp(self.yOffset + del * Style.CELL_STRIDE, 0, maxOffset)
    return true
end
