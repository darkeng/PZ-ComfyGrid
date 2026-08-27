--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.4.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
ComfyGrid = ComfyGrid or {}
local Settings = {}
ComfyGrid.Settings = Settings

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text

Settings.defaults = {
    SCALE = 1,
    SLOTS_PER_CAPACITY = 2,
    INSTANT_TRANSFER = false,
    LOOT_SECTIONS = false,
    COMPACT_ROWS = false,
    STACK_BY_TYPE = true,
}

local OPTION_DEFS = {
    { key = "SCALE",              kind = "slider", min = 0.3, max = 4,  step = 0.1,
      nameKey = "IGUI_ComfyGrid_OptScale",
      tipKey = "IGUI_ComfyGrid_OptScaleTip",
      tooltip = "Size multiplier for the grid UI." },
    { key = "SLOTS_PER_CAPACITY", kind = "slider", min = 1,   max = 4,  step = 0.5,
      nameKey = "IGUI_ComfyGrid_OptSlotsPerCapacity",
      tipKey = "IGUI_ComfyGrid_OptSlotsPerCapacityTip",
      tooltip = "Slots granted per point of container capacity." },
    { key = "INSTANT_TRANSFER",   kind = "tickbox",
      nameKey = "IGUI_ComfyGrid_OptInstantTransfer",
      tipKey = "IGUI_ComfyGrid_OptInstantTransferTip",
      tooltip = "Move items instantly instead of taking transfer time." },
    { key = "LOOT_SECTIONS",      kind = "tickbox",
      nameKey = "IGUI_ComfyGrid_OptLootSections",
      tipKey = "IGUI_ComfyGrid_OptLootSectionsTip",
      tooltip = "Loot window: show every container within reach as stacked sections." },
    { key = "COMPACT_ROWS",       kind = "tickbox",
      nameKey = "IGUI_ComfyGrid_OptCompactRows",
      tipKey = "IGUI_ComfyGrid_OptCompactRowsTip",
      tooltip = "Boards show their items plus one free row instead of the whole capacity." },
    { key = "STACK_BY_TYPE",      kind = "tickbox",
      nameKey = "IGUI_ComfyGrid_OptStackByType",
      tipKey = "IGUI_ComfyGrid_OptStackByTypeTip",
      tooltip = "Identical items stack together regardless of their state." },
}

local values = {}
for k, v in pairs(Settings.defaults) do
    values[k] = v
end

local listeners = {}

local instance = nil

function Settings.get(key)
    local v = values[key]
    if v == nil then
        v = Settings.defaults[key]
    end
    return v
end

function Settings.onChanged(key, fn)
    local list = listeners[key]
    if not list then
        list = {}
        listeners[key] = list
    end
    list[#list + 1] = fn
end

local function setValue(key, newValue)
    if newValue == nil then
        return
    end
    local oldValue = values[key]
    if oldValue == newValue then
        return
    end
    values[key] = newValue
    local list = listeners[key]
    if list then
        for i = 1, #list do

            local ok, err = pcall(list[i], newValue, oldValue)
            if not ok then
                Log.warn("Settings listener for " .. key .. " failed: " .. tostring(err))
            end
        end
    end
end

local function titleFor(key)
    local words = {}
    for word in key:lower():gmatch("[^_]+") do
        words[#words + 1] = word:sub(1, 1):upper() .. word:sub(2)
    end
    return table.concat(words, " ")
end

function Settings.buildOptions()
    if instance then
        return
    end

    if not (PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.create) then
        return
    end

    instance = PZAPI.ModOptions.getOptions
        and PZAPI.ModOptions:getOptions(ComfyGrid.MOD_ID) or nil
    if not instance then
        instance = PZAPI.ModOptions:create(ComfyGrid.MOD_ID, "Comfy Grid")
        for i = 1, #OPTION_DEFS do
            local def = OPTION_DEFS[i]

            local title = def.nameKey and Text.tr(def.nameKey, titleFor(def.key))
                or titleFor(def.key)
            local tip = def.tipKey and Text.tr(def.tipKey, def.tooltip)
                or def.tooltip
            if def.kind == "tickbox" then
                instance:addTickBox(def.key, title, Settings.defaults[def.key], tip)
            else
                instance:addSlider(def.key, title, def.min, def.max, def.step,
                    Settings.defaults[def.key], tip)
            end
        end
    end

    instance.apply = function(self)
        for i = 1, #OPTION_DEFS do
            local def = OPTION_DEFS[i]
            local opt = self:getOption(def.key)
            if opt and opt.getValue then
                local ok, v = pcall(opt.getValue, opt)
                if ok and v ~= nil then

                    if def.integer and type(v) == "number" then
                        v = math.floor(v + 0.5)
                    end
                    setValue(def.key, v)
                end
            end
        end
    end
end

Settings.buildOptions()

if not ComfyGrid._settingsApplyHooked then
    ComfyGrid._settingsApplyHooked = true
    Events.OnGameStart.Add(function()
        if instance and instance.apply then
            pcall(instance.apply, instance)
        end
    end)
end
