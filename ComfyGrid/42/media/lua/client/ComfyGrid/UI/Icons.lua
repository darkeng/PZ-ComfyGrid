--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.9
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
        local okP, p = pcall(tex.getPath, tex)
        if okP and p ~= nil then
            local pack = tostring(p):match("@pack/([^/]+)/")
            if pack ~= nil and not GAME_PACKS[pack] then return nil end
        end
    end
    return name
end

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

local gameArtByTex = {}

function Icons.gameArt(tex)
    if tex == nil then return false end
    local hi = gameArtByTex[tex]
    if hi ~= nil then return hi end
    hi = false
    if Texture ~= nil and Texture.trygetTexture ~= nil and tex.getName ~= nil then
        local okN, name = pcall(gameNameOf, tex)
        if okN and name ~= nil then
            hi = Texture.trygetTexture(PREFIX .. name) or false
        end
    end
    gameArtByTex[tex] = hi
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
