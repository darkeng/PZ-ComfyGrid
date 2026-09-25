--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.9
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Core = ComfyGrid.Core or {}
local Notify = {}
ComfyGrid.Core.Notify = Notify

local Log = ComfyGrid.Core.Log

local EMIT = {
    say  = function(p, t) HaloTextHelper.addText(p, t) end,
    good = function(p, t) HaloTextHelper.addGoodText(p, t) end,
    bad  = function(p, t) HaloTextHelper.addBadText(p, t) end,
}

local function emit(kind, playerNum, text)
    if text == nil or text == "" then return false end
    if HaloTextHelper == nil or getSpecificPlayer == nil then return false end
    local playerObj = getSpecificPlayer(playerNum or 0)
    if playerObj == nil then return false end
    local ok, err = pcall(EMIT[kind], playerObj, text)
    if not ok then
        Log.warn("Notify: " .. kind .. " failed: " .. tostring(err))
        return false
    end
    return true
end

function Notify.say(playerNum, text)
    return emit("say", playerNum, text)
end

function Notify.good(playerNum, text)
    return emit("good", playerNum, text)
end

function Notify.bad(playerNum, text)
    return emit("bad", playerNum, text)
end
