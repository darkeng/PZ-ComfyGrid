--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
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

local GAME_PACKS = { UI = true, UI2 = true }

local function gameNameOf(tex)
    local name = tex:getName()
    if name == nil or name == "" then return nil end
    if name:find("[/\\]") ~= nil then
        local path = name:gsub("\\", "/")
        if path:lower():find("/mods/", 1, true) ~= nil then return nil end
        local base = path:match("([^/]+)$")
        if base == nil then return nil end
        base = base:gsub("%.[Pp][Nn][Gg]$", "")
        return base
    end
    if tex.getPath ~= nil then
        local okPath, packPath = pcall(tex.getPath, tex)
        if okPath and packPath ~= nil then
            local pack = tostring(packPath):match("@pack/([^/]+)/")
            if pack ~= nil and not GAME_PACKS[pack] then return nil end
        end
    end
    return name
end

function Icons.hiRes(tex)
    if tex == nil then return false end
    local hiRes = hiByTex[tex]
    if hiRes ~= nil then return hiRes end
    hiRes = false

    if Texture ~= nil and Texture.trygetTexture ~= nil and tex.getName ~= nil then
        local name = tex:getName()
        if name ~= nil and name ~= "" then
            hiRes = Texture.trygetTexture(PREFIX .. name) or false
        end
    end
    hiByTex[tex] = hiRes
    if hiRes then hits = hits + 1 else misses = misses + 1 end
    return hiRes
end

local gameArtByTex = {}

function Icons.gameArt(tex)
    if tex == nil then return false end
    local hiRes = gameArtByTex[tex]
    if hiRes ~= nil then return hiRes end
    hiRes = false
    if Texture ~= nil and Texture.trygetTexture ~= nil and tex.getName ~= nil then
        local okName, name = pcall(gameNameOf, tex)
        if okName and name ~= nil then
            hiRes = Texture.trygetTexture(PREFIX .. name) or false
        end
    end
    gameArtByTex[tex] = hiRes
    return hiRes
end

function Icons.stats()
    return hits, misses
end

function Icons.fluidContainerOf(item)
    local fluidContainer = item.getFluidContainer ~= nil and item:getFluidContainer() or nil
    if fluidContainer == nil and item.getWorldItem ~= nil then
        local world = item:getWorldItem()
        if world ~= nil then fluidContainer = world:getFluidContainer() end
    end
    return fluidContainer
end

function Icons.draw(view, item, x, y, alpha, w, h, hiRes)
    if view == nil or item == nil then return end
    if hiRes == nil then
        hiRes = Icons.hiRes(item.getTex ~= nil and item:getTex() or nil)
    end
    local javaObject = view.javaObject
    if not hiRes or javaObject == nil then
        view:drawItemIcon(item, x, y, alpha, w, h)
        return
    end

    local itemRed, itemGreen, itemBlue = item:getR(), item:getG(), item:getB()
    local tintRed, tintGreen, tintBlue = itemRed, itemGreen, itemBlue
    local colorMask = item:getTextureColorMask()

    if colorMask ~= nil then tintRed, tintGreen, tintBlue = 1, 1, 1 end

    local fluid = item:getFluidContainer()
    if fluid == nil then
        local world = item:getWorldItem()
        if world ~= nil then fluid = world:getFluidContainer() end
    end
    local fluidMask = item:getTextureFluidMask()

    if fluid ~= nil and fluidMask ~= nil then
        local fluidColor = fluid:getColor()
        local capacity = fluid:getCapacity()

        javaObject:DrawTextureIcon(hiRes, x, y, w, h, tintRed, tintGreen, tintBlue, alpha)
        javaObject:DrawTextureIconMask(fluidMask,
            capacity > 0 and (fluid:getAmount() / capacity) or 0,
            x, y, w, h,
            fluidColor:getRedFloat(), fluidColor:getGreenFloat(),
            fluidColor:getBlueFloat(), alpha)
    else
        javaObject:DrawTextureScaledAspect(hiRes, x, y, w, h,
            tintRed, tintGreen, tintBlue, alpha)
    end

    if colorMask ~= nil then

        javaObject:DrawTextureIconMask(Icons.hiRes(colorMask) or colorMask, 1.0,
            x, y, w, h,
            itemRed, itemGreen, itemBlue, alpha)
    end
end
