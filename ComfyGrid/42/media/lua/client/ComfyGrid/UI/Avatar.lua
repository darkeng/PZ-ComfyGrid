--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.7.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ISUI/ISUI3DModel"
require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local Style = ComfyGrid.UI.Style

local Avatar = ISUIElement:derive("ComfyAvatar")
ComfyGrid.UI.Avatar = Avatar

local ART_W, ART_H = 123, 302
local ASPECT = ART_W / ART_H

local ZOOM = 2

local SIL_PATH = "media/ui/defense/"
local silCache = {}
local function silhouetteFor(female)
    local key = female and "female_base" or "male_base"
    local tex = silCache[key]
    if tex == nil then
        local ok, t = pcall(getTexture, SIL_PATH .. key .. ".png")
        tex = (ok and t) or false
        silCache[key] = tex
    end
    if tex == false then return nil end
    return tex
end

local dirty = {}

function Avatar.markDirty(playerNum)
    if type(playerNum) == "number" then dirty[playerNum] = true end
end

function Avatar._onClothingUpdated(character)
    if character == nil or character.getPlayerNum == nil then return end
    local ok, n = pcall(character.getPlayerNum, character)
    if ok and type(n) == "number" then dirty[n] = true end
end

local lastError = nil
local function report(where, err)
    local key = where .. tostring(err)
    if key ~= lastError then
        lastError = key
        Log.error("Avatar " .. where .. " failed: " .. tostring(err))
    end
end

local function wantsModel()
    local S = ComfyGrid.Settings
    if S == nil or S.get == nil then return true end
    return S.get("EQUIPMENT_AVATAR") ~= "silhouette"
end

function Avatar:new(x, y, w, h, playerNum)
    local o = ISUIElement:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum or 0
    o.model = nil
    o.modelChar = nil
    o.keepOnScreen = false
    return o
end

function Avatar.widthFor(h)
    return math.floor(h * ASPECT + 0.5)
end

function Avatar.heightFor(w)
    return math.floor(w / ASPECT + 0.5)
end

function Avatar:figureBox()
    local w = self.width
    local h = math.floor(w / ASPECT + 0.5)
    if h > self.height then
        h = self.height
        w = math.floor(h * ASPECT + 0.5)
    end
    return w, h
end

local function ensureModel(self)
    local playerObj = getSpecificPlayer(self.playerNum)
    if playerObj == nil then return nil end
    local m = self.model
    if m == nil then
        m = ISUI3DModel:new(0, 0, self.width, self.height)
        self:addChild(m)
        m:setState("idle")
        m:setDirection(IsoDirections.S)
        m:setIsometric(false)
        m:setZoom(ZOOM)
        self.model = m
    end

    if self.modelChar ~= playerObj or dirty[self.playerNum] then
        m:setCharacter(playerObj)
        self.modelChar = playerObj
        dirty[self.playerNum] = nil
    end
    return m
end

function Avatar:hideModel()
    local m = self.model
    if m ~= nil and m:getIsVisible() then m:setVisible(false) end
end

local function prerenderImpl(self)
    local useModel = wantsModel()
    if not useModel then
        self:hideModel()
        return
    end
    local m = ensureModel(self)
    if m == nil then return end
    if not m:getIsVisible() then m:setVisible(true) end
    local w, h = self:figureBox()
    if m.width ~= w then m:setWidth(w) end
    if m.height ~= h then m:setHeight(h) end
end

function Avatar:prerender()
    local ok, err = pcall(prerenderImpl, self)
    if not ok then report("prerender", err) end
end

local function renderImpl(self)
    if wantsModel() then return end
    local playerObj = getSpecificPlayer(self.playerNum)
    local female = playerObj ~= nil and playerObj.isFemale ~= nil
        and playerObj:isFemale() == true
    local tex = silhouetteFor(female)
    if tex == nil then return end

    local w, h = self:figureBox()
    local x = math.floor((self.width - w) / 2)
    local y = 0
    local sf = Style.COLORS and Style.COLORS.SURFACE
    local c = sf ~= nil and sf.cardHi or { r = 0.19, g = 0.17, b = 0.15 }
    self:drawTextureScaled(tex, x, y, w, h, 0.85, c.r, c.g, c.b)
end

function Avatar:render()
    local ok, err = pcall(renderImpl, self)
    if not ok then report("render", err) end
end

if not ComfyGrid._avatarClothingHooked then
    ComfyGrid._avatarClothingHooked = true
    if Events ~= nil and Events.OnClothingUpdated ~= nil then
        Events.OnClothingUpdated.Add(function(character)
            local A = ComfyGrid.UI and ComfyGrid.UI.Avatar
            if A ~= nil and A._onClothingUpdated ~= nil then
                A._onClothingUpdated(character)
            end
        end)
    end
end
