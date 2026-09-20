--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.6
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Settings"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Chrome/SectionRule"
require "ComfyGrid/UI/EquipmentStrip"
require "ComfyGrid/UI/HotbarStrip"
require "ComfyGrid/UI/PocketsPanel"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local PlayerStrips = ISUIElement:derive("ComfyPlayerStrips")
ComfyGrid.UI.PlayerStrips = PlayerStrips

local Style = ComfyGrid.UI.Style
local SectionRule = ComfyGrid.UI.Chrome.SectionRule
local EquipmentStrip = ComfyGrid.UI.EquipmentStrip
local HotbarStrip = ComfyGrid.UI.HotbarStrip
local PocketsPanel = ComfyGrid.UI.PocketsPanel

local STRIP_GAP = 4

function PlayerStrips:new(x, y, playerNum)
    local o = ISUIElement:new(x, y, 1, 1)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.equipStrip = nil
    o.hotbarStrip = nil
    o.pocketsPanel = nil

    o.keepOnScreen = false
    return o
end

function PlayerStrips:createChildren()
    self:_sync()
end

function PlayerStrips:_sync()
    if self.equipStrip == nil then
        local strip = EquipmentStrip:new(0, 0, self.playerNum)
        strip:initialise()
        self:addChild(strip)
        self.equipStrip = strip
    end
    if self.hotbarStrip == nil then
        local strip = HotbarStrip:new(0, 0, self.playerNum)
        strip:initialise()
        self:addChild(strip)
        self.hotbarStrip = strip
    end
end

function PlayerStrips:setPocketInventories(invs)
    local pp = self.pocketsPanel
    if invs == nil or #invs == 0 then
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

function PlayerStrips:prerender()

    self:_sync()
    local w = self.width
    local sectionH = Style.FONT_H
    local y = 0

    local Settings = ComfyGrid.Settings
    local wantStrip = Settings == nil or Settings.get == nil
        or Settings.get("EQUIPMENT_VIEW") == "strip"
    local strip = self.equipStrip
    if strip ~= nil and strip:getIsVisible() ~= wantStrip then
        strip:setVisible(wantStrip)
    end
    if strip ~= nil and wantStrip then
        SectionRule.draw(self, SectionRule.info(
            "IGUI_ComfyGrid_SectionEquipment", "Equipment"), y, sectionH)
        y = y + sectionH
        strip:setAvailableWidth(w)
        if strip.x ~= 0 then strip:setX(0) end
        if strip.y ~= y then strip:setY(y) end
        y = y + strip.height + STRIP_GAP
    end

    local wantHotbar = Settings == nil or Settings.get == nil
        or Settings.get("HOTBAR_SECTION") ~= false
    local hotbar = self.hotbarStrip
    if hotbar ~= nil and hotbar:getIsVisible() ~= wantHotbar then
        hotbar:setVisible(wantHotbar)
    end
    if hotbar ~= nil and wantHotbar then
        hotbar:setAvailableWidth(w)
        if hotbar.x ~= 0 then hotbar:setX(0) end
        if hotbar.entryCount > 0 then
            SectionRule.draw(self, SectionRule.info(
                "IGUI_ComfyGrid_SectionHotbar", "Hotbar"), y, sectionH)
            y = y + sectionH
            if hotbar.y ~= y then hotbar:setY(y) end
            y = y + hotbar.height + STRIP_GAP
        end
    end

    local pp = self.pocketsPanel
    if pp ~= nil then
        if pp.width ~= w then pp:setWidth(w) end
        if pp.x ~= 0 then pp:setX(0) end
        if pp.y ~= y then pp:setY(y) end
        y = y + pp.height + STRIP_GAP
    end

    if self.height ~= y then self:setHeight(y) end
end
