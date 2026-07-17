--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.0.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/UI/Style"
require "ComfyGrid/Interact/DragAndDrop"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local Style = ComfyGrid.UI.Style
local DragAndDrop = ComfyGrid.Interact.DragAndDrop

local DragGhost = ISUIElement:derive("ComfyDragGhost")
ComfyGrid.UI.DragGhost = DragGhost

local floor = math.floor

local GHOST_ALPHA = 0.7

local countStrings = {}

local smallFontHgt = -1

local lastRenderError = nil

function DragGhost:new()
    local o = ISUIElement:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index = self
    return o
end

function DragGhost.ensure()
    local inst = ComfyGrid.UI._dragGhostInstance
    if inst ~= nil then

        if getmetatable(inst) ~= DragGhost then
            DragGhost.__index = DragGhost
            setmetatable(inst, DragGhost)
        end
        return inst
    end
    inst = DragGhost:new()
    inst:initialise()
    inst:addToUIManager()
    ComfyGrid.UI._dragGhostInstance = inst
    return inst
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
        local st = stacks[i].items
        if st ~= nil and #st > 1 then
            total = total + #st - 1
        end
    end

    local size = Style.TEXTURE_SIZE

    local mx = getMouseX()
    local my = getMouseY()
    local x = floor(mx - size * 0.5)
    local y = floor(my - size * 0.5)

    self:suspendStencil()

    local tex = front.getTex and front:getTex() or nil
    local drew = false
    if tex ~= nil then
        local texW = tex:getWidth()
        local texH = tex:getHeight()
        if texW and texH and texW > 0 and texH > 0 then

            local largest = texW
            if texH > texW then largest = texH end
            local corrective = size / largest
            local drawW = texW * corrective
            local drawH = texH * corrective

            self:drawTextureScaled(tex,
                floor(x + (size - drawW) * 0.5),
                floor(y + (size - drawH) * 0.5),
                drawW, drawH, GHOST_ALPHA, 1, 1, 1)
            drew = true
        end
    end
    if not drew then

        if smallFontHgt < 0 then
            smallFontHgt = getTextManager():getFontHeight(UIFont.Small)
        end
        self:drawTextCentre("?", mx, floor(y + (size - smallFontHgt) * 0.5),
            1, 1, 1, GHOST_ALPHA, UIFont.Small)
    end

    if total > 1 then
        local text = countStrings[total]
        if not text then
            text = tostring(total)
            countStrings[total] = text
        end
        local colors = Style.COLORS
        local cs = colors and colors.COUNT_SHADOW
        local ct = colors and colors.COUNT_TEXT
        if cs then
            local off = floor(Style.SCALE + 0.5)
            if off < 1 then off = 1 end
            self:drawText(text, x + 2 + off, y + off,
                cs.r, cs.g, cs.b, cs.a or 1, UIFont.Small)
        end
        if ct then
            self:drawText(text, x + 2, y, ct.r, ct.g, ct.b, ct.a or 1, UIFont.Small)
        else
            self:drawText(text, x + 2, y, 1, 1, 1, 1, UIFont.Small)
        end
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
