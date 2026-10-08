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
local Prefs = {}
ComfyGrid.Core.Prefs = Prefs

local Log = ComfyGrid.Core.Log

local FILE = "ComfyGrid_state.ini"

local prefsByKey = nil

local function readPrefsFile()
    if prefsByKey ~= nil then return prefsByKey end
    prefsByKey = {}
    if getFileReader == nil then return prefsByKey end

    local ok, reader = pcall(getFileReader, FILE, false)
    if not ok or reader == nil then return prefsByKey end
    local okRead = pcall(function()
        local line = reader:readLine()
        while line ~= nil do
            local key, value = string.match(line, "^([%w_]+)%s*=%s*(.-)%s*$")
            if key ~= nil then prefsByKey[key] = value end
            line = reader:readLine()
        end
    end)
    pcall(reader.close, reader)
    if not okRead then Log.warn("Prefs: could not read " .. FILE) end
    return prefsByKey
end

local function writePrefsFile()
    if getFileWriter == nil then return end
    local ok, writer = pcall(getFileWriter, FILE, true, false)
    if not ok or writer == nil then
        Log.warn("Prefs: could not open " .. FILE .. " for writing")
        return
    end
    local okWrite = pcall(function()
        for key, value in pairs(prefsByKey) do
            writer:write(key .. "=" .. tostring(value) .. "\r\n")
        end
    end)
    pcall(writer.close, writer)
    if not okWrite then Log.warn("Prefs: could not write " .. FILE) end
end

function Prefs.get(key)
    return readPrefsFile()[key]
end

function Prefs.getNumber(key, default)
    local number = tonumber(Prefs.get(key))
    if number == nil then return default end
    return number
end

function Prefs.set(key, value)
    readPrefsFile()
    local text = tostring(value)
    if prefsByKey[key] == text then return end
    prefsByKey[key] = text
    writePrefsFile()
end
