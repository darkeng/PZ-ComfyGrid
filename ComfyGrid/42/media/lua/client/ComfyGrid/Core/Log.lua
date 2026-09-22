--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.8
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"

local Log = {}
ComfyGrid.Core.Log = Log

local PREFIX = "[ComfyGrid] "

function Log.info(msg)
    print(PREFIX .. tostring(msg))
end

function Log.warn(msg)
    print(PREFIX .. "WARN: " .. tostring(msg))
end

function Log.error(msg)
    print(PREFIX .. "ERROR: " .. tostring(msg))
end

ComfyGrid.log = Log.info
