--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"

require "ComfyGrid/Core/Log"
require "ComfyGrid/UI/Icons"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local IconWarmup = {}
ComfyGrid.UI.IconWarmup = IconWarmup

local Log = ComfyGrid.Core.Log
local Icons = ComfyGrid.UI.Icons

local PER_FRAME = 256

local state = nil

local done = false

local function collect()
    local scriptManager = getScriptManager and getScriptManager() or nil
    if scriptManager == nil or scriptManager.getAllItems == nil then return nil end
    local allItems = scriptManager:getAllItems()
    if allItems == nil then return nil end
    local list, seen = {}, {}
    for i = 0, allItems:size() - 1 do
        local scriptItem = allItems:get(i)
        local tex = scriptItem ~= nil and scriptItem.getNormalTexture ~= nil
            and scriptItem:getNormalTexture() or nil
        if tex ~= nil and not seen[tex] then
            seen[tex] = true
            local hiRes = Icons.hiRes(tex)
            if hiRes then list[#list + 1] = hiRes end
        end
    end

    local buttonArt = { getTexture("media/ui/Icon_InventoryBasic.png") }
    if ContainerButtonIcons ~= nil then
        for _, tex in pairs(ContainerButtonIcons) do buttonArt[#buttonArt + 1] = tex end
    end

    for i = 1, #buttonArt do
        local tex = buttonArt[i]
        if tex ~= nil and not seen[tex] then
            seen[tex] = true
            local hiRes = Icons.gameArt(tex)
            if hiRes then list[#list + 1] = hiRes end
        end
    end
    return list
end

local Runner = ISUIElement:derive("ComfyGridIconWarmup")

function Runner:render()
    if state == nil then
        self:removeFromUIManager()
        return
    end
    local list = state.list
    local textureCount = #list
    local from = state.at
    local to = from + PER_FRAME - 1
    if to > textureCount then to = textureCount end
    for textureIndex = from, to do

        self:drawTextureScaled(list[textureIndex], 0, 0, 1, 1, 0.004, 1, 1, 1)
    end
    state.at = to + 1
    if state.at > textureCount then
        state = nil
        done = true
        self:removeFromUIManager()
        Log.info("icon pack warmed (" .. tostring(textureCount) .. " textures)")
    end
end

function IconWarmup.start()
    if done or state ~= nil then return false end
    local ok, list = pcall(collect)
    if not ok or list == nil or #list == 0 then

        return false
    end
    state = { list = list, at = 1 }
    local runner = Runner:new(0, 0, 1, 1)
    runner:initialise()
    runner:setVisible(true)
    runner:addToUIManager()
    return true
end

function IconWarmup.progress()
    if state == nil then return 0, 0, done end
    return #state.list - state.at + 1, #state.list, done
end

return IconWarmup
