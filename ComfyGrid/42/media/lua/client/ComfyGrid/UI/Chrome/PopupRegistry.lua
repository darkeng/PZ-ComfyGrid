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
ComfyGrid.UI = ComfyGrid.UI or {}

ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local PopupRegistry = {}
ComfyGrid.UI.Chrome.PopupRegistry = PopupRegistry

local Log = ComfyGrid.Core.Log

ComfyGrid._popupRegistry = ComfyGrid._popupRegistry or {}
local entries = ComfyGrid._popupRegistry

function PopupRegistry.register(name, current, opts)
    if type(name) ~= "string" or type(current) ~= "function" then return end
    local dismissable = not (type(opts) == "table" and opts.dismissable == false)
    for i = 1, #entries do
        if entries[i].name == name then
            entries[i].current = current
            entries[i].dismissable = dismissable
            return
        end
    end
    entries[#entries + 1] = { name = name, current = current,
        dismissable = dismissable }
end

function PopupRegistry.closeOthers(keep)
    for i = 1, #entries do
        local entry = entries[i]
        local ok, popup = pcall(entry.current)
        if ok and popup ~= nil and popup ~= keep and popup.close ~= nil
                and entry.dismissable ~= false then
            local okClose, err = pcall(popup.close, popup)
            if not okClose then
                Log.warn("PopupRegistry: " .. entry.name .. ":close() failed: "
                    .. tostring(err))
            end
        end
    end
end

function PopupRegistry.forEach(visit)
    if type(visit) ~= "function" then return end
    for i = 1, #entries do
        local entry = entries[i]
        local ok, popup = pcall(entry.current)
        if ok and popup ~= nil then pcall(visit, popup, entry.name) end
    end
end
