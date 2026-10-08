--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Icons"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/UI/StackRenderer"
require "ComfyGrid/Interact/DragAndDrop"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local Style = ComfyGrid.UI.Style
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local Icons = ComfyGrid.UI.Icons
local StackRenderer = ComfyGrid.UI.StackRenderer
local DragAndDrop = ComfyGrid.Interact.DragAndDrop

local DragGhost = ISUIElement:derive("ComfyDragGhost")
ComfyGrid.UI.DragGhost = DragGhost

local floor = math.floor

local GHOST_ALPHA = 0.7

local LIFT_SHADOW_ALPHA = 0.35

local countStrings = {}

local lastRenderError = nil

function DragGhost:new()
    local ghost = ISUIElement:new(0, 0, 0, 0)
    setmetatable(ghost, self)
    self.__index = self
    return ghost
end

function DragGhost.ensure()
    local instance = ComfyGrid.UI._dragGhostInstance
    if instance ~= nil then

        if getmetatable(instance) ~= DragGhost then
            DragGhost.__index = DragGhost
            setmetatable(instance, DragGhost)
        end
        return instance
    end
    instance = DragGhost:new()
    instance:initialise()
    instance:addToUIManager()
    ComfyGrid.UI._dragGhostInstance = instance
    return instance
end

function DragGhost:prerender()
    if not DragAndDrop.isComfyDrag() then return end

    self:bringToTop()
end

local function renderImpl(self)
    if not DragAndDrop.isComfyDrag() then return end
    local stacks = DragAndDrop.getDraggedStacks()
    if stacks == nil or #stacks == 0 then return end
    local items = stacks[1].items
    if items == nil then return end

    local front = items[1] or items[2]
    if front == nil then return end

    local total = 0
    for i = 1, #stacks do
        local stackItems = stacks[i].items
        if stackItems ~= nil and #stackItems > 1 then
            total = total + #stackItems - 1
        end
    end

    local size = floor(Style.TEXTURE_SIZE * 1.05)

    local mx = getMouseX()
    local my = getMouseY()
    local x = floor(mx - size * 0.5)
    local y = floor(my - size * 0.5)

    self:suspendStencil()

    local colors = Style.COLORS
    local tileTex = SlotRenderer.getTileTexture()
    if tileTex ~= nil then
        local cell = floor((Style.CELL - 2) * 1.05)
        local tileX = floor(mx - cell * 0.5)
        local tileY = floor(my - cell * 0.5)

        local shadowInk = colors.SHADOW
        self:drawTextureScaled(tileTex, tileX + 3, tileY + 4, cell, cell,
            LIFT_SHADOW_ALPHA, shadowInk.r, shadowInk.g, shadowInk.b)
        local category = front.getDisplayCategory and front:getDisplayCategory()
            or nil

        local tint = Style.tintForCategory(category)
        self:drawTextureScaled(tileTex, tileX, tileY, cell, cell,
            0.85, tint.r, tint.g, tint.b)
    end

    local tex = front.getTex and front:getTex() or nil
    local drew = false
    if tex ~= nil then
        local texW = tex:getWidth()
        local texH = tex:getHeight()
        if texW and texH and texW > 0 and texH > 0 then

            Icons.draw(self, front, x, y, GHOST_ALPHA, size, size)
            drew = true
        end
    end
    if not drew then

        local placeholder = colors.PLACEHOLDER_TEXT
        self:drawTextCentre("?", mx, floor(y + (size - Style.FONT_H) * 0.5),
            placeholder.r, placeholder.g, placeholder.b, GHOST_ALPHA, Style.FONT)
    end

    if total > 1 then
        local text = countStrings[total]
        if not text then
            text = tostring(total)
            countStrings[total] = text
        end
        StackRenderer.drawShadowedText(self, text, x + 2, y, colors.COUNT_TEXT,
            colors.COUNT_SHADOW)
    end

    self:resumeStencil()
end

function DragGhost:render()
    local ok, err = pcall(renderImpl, self)
    if not ok then

        pcall(ISUIElement.resumeStencil, self)
        if err ~= lastRenderError then
            lastRenderError = err
            Log.error("DragGhost render failed: " .. tostring(err))
        end
    end
end
