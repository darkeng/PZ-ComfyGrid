--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.7.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local PopupRegistry = {}
ComfyGrid.UI.Chrome.PopupRegistry = PopupRegistry

local Log = ComfyGrid.Core.Log

ComfyGrid._popupRegistry = ComfyGrid._popupRegistry or {}
local entries = ComfyGrid._popupRegistry

function PopupRegistry.register(name, current)
    if type(name) ~= "string" or type(current) ~= "function" then return end
    for i = 1, #entries do
        if entries[i].name == name then
            entries[i].current = current
            return
        end
    end
    entries[#entries + 1] = { name = name, current = current }
end

function PopupRegistry.closeOthers(keep)
    for i = 1, #entries do
        local e = entries[i]
        local ok, popup = pcall(e.current)
        if ok and popup ~= nil and popup ~= keep and popup.close ~= nil then
            local okClose, err = pcall(popup.close, popup)
            if not okClose then
                Log.warn("PopupRegistry: " .. e.name .. ":close() failed: "
                    .. tostring(err))
            end
        end
    end
end

function PopupRegistry.forEach(fn)
    if type(fn) ~= "function" then return end
    for i = 1, #entries do
        local e = entries[i]
        local ok, popup = pcall(e.current)
        if ok and popup ~= nil then pcall(fn, popup, e.name) end
    end
end

function PopupRegistry.anyOpen()
    for i = 1, #entries do
        local ok, popup = pcall(entries[i].current)
        if ok and popup ~= nil then return true end
    end
    return false
end
