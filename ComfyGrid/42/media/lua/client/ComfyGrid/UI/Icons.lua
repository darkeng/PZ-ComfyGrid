--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local Icons = {}
ComfyGrid.UI.Icons = Icons

local PREFIX = "ComfyGrid_"

local hiByTex = {}
local hits, misses = 0, 0

function Icons.hiRes(tex)
    if tex == nil then return false end
    local hi = hiByTex[tex]
    if hi ~= nil then return hi end
    hi = false

    if Texture ~= nil and Texture.trygetTexture ~= nil and tex.getName ~= nil then
        local name = tex:getName()
        if name ~= nil and name ~= "" then
            hi = Texture.trygetTexture(PREFIX .. name) or false
        end
    end
    hiByTex[tex] = hi
    if hi then hits = hits + 1 else misses = misses + 1 end
    return hi
end

function Icons.stats()
    return hits, misses
end

function Icons.draw(view, item, x, y, alpha, w, h, hi)
    if view == nil or item == nil then return end
    if hi == nil then
        hi = Icons.hiRes(item.getTex ~= nil and item:getTex() or nil)
    end
    local jo = view.javaObject
    if not hi or jo == nil then
        view:drawItemIcon(item, x, y, alpha, w, h)
        return
    end

    local r, g, b = item:getR(), item:getG(), item:getB()
    local colorMask = item:getTextureColorMask()

    if colorMask ~= nil then r, g, b = 1, 1, 1 end

    local fluid = item:getFluidContainer()
    if fluid == nil then
        local world = item:getWorldItem()
        if world ~= nil then fluid = world:getFluidContainer() end
    end
    local fluidMask = item:getTextureFluidMask()

    if fluid ~= nil and fluidMask ~= nil then
        local col = fluid:getColor()
        local capacity = fluid:getCapacity()

        jo:DrawTextureIcon(hi, x, y, w, h, r, g, b, alpha)
        jo:DrawTextureIconMask(fluidMask,
            capacity > 0 and (fluid:getAmount() / capacity) or 0,
            x, y, w, h,
            col:getRedFloat(), col:getGreenFloat(), col:getBlueFloat(), alpha)
    else
        jo:DrawTextureScaledAspect(hi, x, y, w, h, r, g, b, alpha)
    end

    if colorMask ~= nil then

        jo:DrawTextureIconMask(Icons.hiRes(colorMask) or colorMask, 1.0,
            x, y, w, h,
            item:getR(), item:getG(), item:getB(), alpha)
    end
end
