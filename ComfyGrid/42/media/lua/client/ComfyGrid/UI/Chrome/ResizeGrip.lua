--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Style"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}

local Style = ComfyGrid.UI.Style

local ResizeGrip = ISUIElement:derive("ComfyResizeGrip")
ComfyGrid.UI.Chrome.ResizeGrip = ResizeGrip

function ResizeGrip:new(owner)
    local o = ISUIElement:new(0, 0, 1, 1)
    setmetatable(o, self)
    self.__index = self
    o.owner = owner
    o.side = "right"
    return o
end

function ResizeGrip.defaultSize()
    return math.max(12, math.floor(Style.headerHeight() * 0.55))
end

function ResizeGrip:onMouseDown(_x, _y)
    self.owner:beginResize()
    return true
end

function ResizeGrip:onMouseUp(_x, _y)
    self.owner:endResize()
    return true
end

function ResizeGrip:onMouseUpOutside(_x, _y)
    self.owner:endResize()
end

function ResizeGrip:render()
    local surface = Style.COLORS and Style.COLORS.SURFACE
    if surface == nil then return end

    local hot = self.owner.resize ~= nil or self:isMouseOver()
    local alpha = hot and 1 or 0.85
    local ink = surface.accent or surface.line
    local dotSize, dotPitch = 2, 4
    local span = 2 * dotPitch + dotSize
    local originY = self.height - 2 - span
    local originX = self.side == "left" and 2 or (self.width - 2 - span)
    for row = 0, 2 do
        for col = 0, 2 do
            if col + row >= 2 then
                local mirroredColumn = self.side == "left" and (2 - col) or col
                self:drawRect(originX + mirroredColumn * dotPitch,
                    originY + row * dotPitch, dotSize, dotSize, alpha,
                    ink.r, ink.g, ink.b)
            end
        end
    end
end

function ResizeGrip.poll(owner)
    if owner.resize == nil then return end
    if isMouseButtonDown == nil or not isMouseButtonDown(0) then
        owner:endResize()
    else
        owner:updateResize()
    end
end

function ResizeGrip.seat(grip, show, side, size)
    if grip:getIsVisible() ~= show then grip:setVisible(show) end
    if grip.width ~= size then
        grip:setWidth(size)
        grip:setHeight(size)
    end
    grip.side = side
    local owner = grip.owner
    local gx = side == "left" and 1 or (owner.width - size - 1)
    local gy = owner.height - size - 1
    if grip.x ~= gx then grip:setX(gx) end
    if grip.y ~= gy then grip:setY(gy) end
end

return ResizeGrip
