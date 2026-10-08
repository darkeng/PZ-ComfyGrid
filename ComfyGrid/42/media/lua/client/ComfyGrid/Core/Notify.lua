--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
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

local HALO_SENDERS = {
    say  = function(playerObj, text) HaloTextHelper.addText(playerObj, text) end,
    good = function(playerObj, text) HaloTextHelper.addGoodText(playerObj, text) end,
    bad  = function(playerObj, text) HaloTextHelper.addBadText(playerObj, text) end,
}

local function showHaloText(kind, playerNum, text)
    if text == nil or text == "" then return false end
    if HaloTextHelper == nil or getSpecificPlayer == nil then return false end
    local playerObj = getSpecificPlayer(playerNum or 0)
    if playerObj == nil then return false end
    local ok, err = pcall(HALO_SENDERS[kind], playerObj, text)
    if not ok then
        Log.warn("Notify: " .. kind .. " failed: " .. tostring(err))
        return false
    end
    return true
end

function Notify.say(playerNum, text)
    return showHaloText("say", playerNum, text)
end

function Notify.good(playerNum, text)
    return showHaloText("good", playerNum, text)
end

function Notify.bad(playerNum, text)
    return showHaloText("bad", playerNum, text)
end
