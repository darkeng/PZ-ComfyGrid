--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Core = ComfyGrid.Core or {}
local Prefs = {}
ComfyGrid.Core.Prefs = Prefs

local Log = ComfyGrid.Core.Log

local FILE = "ComfyGrid_state.ini"

local cache = nil

local function load()
    if cache ~= nil then return cache end
    cache = {}
    if getFileReader == nil then return cache end

    local ok, reader = pcall(getFileReader, FILE, false)
    if not ok or reader == nil then return cache end
    local okRead = pcall(function()
        local line = reader:readLine()
        while line ~= nil do
            local k, v = string.match(line, "^([%w_]+)%s*=%s*(.-)%s*$")
            if k ~= nil then cache[k] = v end
            line = reader:readLine()
        end
    end)
    pcall(reader.close, reader)
    if not okRead then Log.warn("Prefs: could not read " .. FILE) end
    return cache
end

local function store()
    if getFileWriter == nil then return end
    local ok, writer = pcall(getFileWriter, FILE, true, false)
    if not ok or writer == nil then
        Log.warn("Prefs: could not open " .. FILE .. " for writing")
        return
    end
    local okWrite = pcall(function()
        for k, v in pairs(cache) do
            writer:write(k .. "=" .. tostring(v) .. "\r\n")
        end
    end)
    pcall(writer.close, writer)
    if not okWrite then Log.warn("Prefs: could not write " .. FILE) end
end

function Prefs.get(key)
    return load()[key]
end

function Prefs.getNumber(key, default)
    local v = tonumber(Prefs.get(key))
    if v == nil then return default end
    return v
end

function Prefs.set(key, value)
    load()
    local s = tostring(value)
    if cache[key] == s then return end
    cache[key] = s
    store()
end
