--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.5
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/UI/Icons"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local Warmup = {}
ComfyGrid.UI.IconWarmup = Warmup

local Log = ComfyGrid.Core.Log
local Icons = ComfyGrid.UI.Icons

local PER_FRAME = 256

local state = nil

local done = false

local function collect()
    local sm = getScriptManager and getScriptManager() or nil
    if sm == nil or sm.getAllItems == nil then return nil end
    local all = sm:getAllItems()
    if all == nil then return nil end
    local list, seen = {}, {}
    for i = 0, all:size() - 1 do
        local si = all:get(i)
        local tex = si ~= nil and si.getNormalTexture ~= nil
            and si:getNormalTexture() or nil
        if tex ~= nil and not seen[tex] then
            seen[tex] = true
            local hi = Icons.hiRes(tex)
            if hi then list[#list + 1] = hi end
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
    local n = #list
    local from = state.at
    local to = from + PER_FRAME - 1
    if to > n then to = n end
    for k = from, to do

        self:drawTextureScaled(list[k], 0, 0, 1, 1, 0.004, 1, 1, 1)
    end
    state.at = to + 1
    if state.at > n then
        state = nil
        done = true
        self:removeFromUIManager()
        Log.info("icon pack warmed (" .. tostring(n) .. " textures)")
    end
end

function Warmup.start()
    if done or state ~= nil then return false end
    if ISUIElement == nil then return false end
    local ok, list = pcall(collect)
    if not ok or list == nil or #list == 0 then

        return false
    end
    state = { list = list, at = 1 }
    local el = Runner:new(0, 0, 1, 1)
    el:initialise()
    el:setVisible(true)
    el:addToUIManager()
    return true
end

function Warmup.progress()
    if state == nil then return 0, 0, done end
    return #state.list - state.at + 1, #state.list, done
end

return Warmup
