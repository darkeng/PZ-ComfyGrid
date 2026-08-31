--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.0
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
    PLAYER_LAYOUT = "compact",

    LOOT_LAYOUT = "sections",

    COMPACT_ROWS = true,
    STACK_BY_TYPE = true,
    HOTBAR_SECTION = false,
    EQUIPMENT_VIEW = "window",
    EQUIPMENT_AVATAR = "model",
}

local GROUPS = {
    { key = "layout",   nameKey = "IGUI_ComfyGrid_GroupLayout",   name = "Layout" },
    { key = "tiles",    nameKey = "IGUI_ComfyGrid_GroupTiles",    name = "Tiles" },
    { key = "advanced", nameKey = "IGUI_ComfyGrid_GroupAdvanced", name = "Advanced" },
}

local OPTION_DEFS = {
    { key = "SCALE",              kind = "slider", group = "layout",
      min = 0.3, max = 4, step = 0.1,
      nameKey = "IGUI_ComfyGrid_OptScale",
      tipKey = "IGUI_ComfyGrid_OptScaleTip",
      tooltip = "How big the grid is drawn." },
    { key = "PLAYER_LAYOUT",      kind = "choice", group = "layout",
      values = { "compact", "full", "single" },
      labelKeys = { "IGUI_ComfyGrid_PlayerLayoutCompact",
                    "IGUI_ComfyGrid_PlayerLayoutFull",
                    "IGUI_ComfyGrid_PlayerLayoutSingle" },
      labels = { "Compact - pockets share one row",
                 "Full - a section per pocket",
                 "One container at a time" },
      nameKey = "IGUI_ComfyGrid_OptPlayerLayout",
      tipKey = "IGUI_ComfyGrid_OptPlayerLayoutTip",
      tooltip = "How your containers are arranged." },
    { key = "LOOT_LAYOUT",        kind = "choice", group = "layout",
      values = { "single", "sections" },
      labelKeys = { "IGUI_ComfyGrid_LootLayoutSingle",
                    "IGUI_ComfyGrid_LootLayoutSections" },
      labels = { "One container at a time",
                 "Every container within reach" },
      nameKey = "IGUI_ComfyGrid_OptLootLayout",
      tipKey = "IGUI_ComfyGrid_OptLootLayoutTip",
      tooltip = "How many containers the loot window shows." },
    { key = "EQUIPMENT_VIEW",     kind = "choice", group = "layout",
      values = { "strip", "window" },
      labelKeys = { "IGUI_ComfyGrid_EquipViewStrip",
                    "IGUI_ComfyGrid_EquipViewWindow" },
      labels = { "A row in the inventory",
                 "Its own window" },
      nameKey = "IGUI_ComfyGrid_OptEquipmentView",
      tipKey = "IGUI_ComfyGrid_OptEquipmentViewTip",
      tooltip = "The window replaces the row; you get one or the other." },
    { key = "EQUIPMENT_AVATAR",   kind = "choice", group = "layout",
      values = { "model", "silhouette" },
      labelKeys = { "IGUI_ComfyGrid_EquipAvatarModel",
                    "IGUI_ComfyGrid_EquipAvatarSilhouette" },
      labels = { "Your character in 3D",
                 "A plain silhouette" },
      nameKey = "IGUI_ComfyGrid_OptEquipmentAvatar",
      tipKey = "IGUI_ComfyGrid_OptEquipmentAvatarTip",
      tooltip = "How your character is drawn." },
    { key = "HOTBAR_SECTION",     kind = "tickbox", group = "layout",
      nameKey = "IGUI_ComfyGrid_OptHotbarSection",
      tipKey = "IGUI_ComfyGrid_OptHotbarSectionTip",
      tooltip = "Turn it off if you use the bar at the bottom of the screen." },
    { key = "SLOTS_PER_CAPACITY", kind = "slider", group = "tiles",
      min = 1, max = 4, step = 0.5,
      nameKey = "IGUI_ComfyGrid_OptSlotsPerCapacity",
      tipKey = "IGUI_ComfyGrid_OptSlotsPerCapacityTip",
      tooltip = "Slots each point of container capacity is worth." },
    { key = "COMPACT_ROWS",       kind = "tickbox", group = "tiles",
      nameKey = "IGUI_ComfyGrid_OptCompactRows",
      tipKey = "IGUI_ComfyGrid_OptCompactRowsTip",
      tooltip = "Show one spare row instead of the whole capacity." },
    { key = "STACK_BY_TYPE",      kind = "tickbox", group = "tiles",
      nameKey = "IGUI_ComfyGrid_OptStackByType",
      tipKey = "IGUI_ComfyGrid_OptStackByTypeTip",
      tooltip = "Identical items share a tile whatever their state." },
    { key = "INSTANT_TRANSFER",   kind = "tickbox", group = "advanced",
      nameKey = "IGUI_ComfyGrid_OptInstantTransfer",
      tipKey = "IGUI_ComfyGrid_OptInstantTransferTip",
      tooltip = "Items move with no transfer time." },
}

Settings.GROUPS = GROUPS
Settings.OPTION_DEFS = OPTION_DEFS

local function choiceLabel(def, i)
    local fallback = def.labels and def.labels[i] or tostring(def.values[i])
    local key = def.labelKeys and def.labelKeys[i] or nil
    return key and Text.tr(key, fallback) or fallback
end

local function choiceIndexOf(def, value)
    for i = 1, #def.values do
        if def.values[i] == value then return i end
    end
    return nil
end

local function titleFor(key)
    local words = {}
    for word in key:lower():gmatch("[^_]+") do
        words[#words + 1] = word:sub(1, 1):upper() .. word:sub(2)
    end
    return table.concat(words, " ")
end

function Settings.defOf(key)
    for i = 1, #OPTION_DEFS do
        if OPTION_DEFS[i].key == key then return OPTION_DEFS[i] end
    end
    return nil
end

function Settings.labelFor(def)
    if def == nil then return "" end
    return def.nameKey and Text.tr(def.nameKey, titleFor(def.key))
        or titleFor(def.key)
end

function Settings.tipFor(def)
    if def == nil then return nil end
    return def.tipKey and Text.tr(def.tipKey, def.tooltip) or def.tooltip
end

function Settings.choiceLabel(def, i)
    return choiceLabel(def, i)
end

function Settings.choiceIndexOf(def, value)
    return choiceIndexOf(def, value)
end

function Settings.groupLabel(groupKey)
    for i = 1, #GROUPS do
        if GROUPS[i].key == groupKey then
            return Text.tr(GROUPS[i].nameKey, GROUPS[i].name)
        end
    end
    return tostring(groupKey)
end

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
        instance = PZAPI.ModOptions:create(ComfyGrid.MOD_ID, "Comfy Grid settings")
        local lastGroup = nil
        for i = 1, #OPTION_DEFS do
            local def = OPTION_DEFS[i]

            if def.group ~= lastGroup then
                lastGroup = def.group
                instance:addTitle(Settings.groupLabel(def.group))
            end

            local title = Settings.labelFor(def)
            local tip = Settings.tipFor(def)
            if def.kind == "tickbox" then
                instance:addTickBox(def.key, title, Settings.defaults[def.key], tip)
            elseif def.kind == "choice" then
                local combo = instance:addComboBox(def.key, title, tip)
                local selected = choiceIndexOf(def, Settings.defaults[def.key]) or 1
                for v = 1, #def.values do

                    combo:addItem(choiceLabel(def, v), v == selected)
                end
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
                    if def.kind == "choice" then

                        v = def.values[v] or Settings.defaults[def.key]
                    elseif def.integer and type(v) == "number" then

                        v = math.floor(v + 0.5)
                    end
                    setValue(def.key, v)
                end
            end
        end
    end
end

function Settings.set(key, value)
    local def = nil
    for i = 1, #OPTION_DEFS do
        if OPTION_DEFS[i].key == key then
            def = OPTION_DEFS[i]
            break
        end
    end
    if def == nil or value == nil then return false end
    local changed = values[key] ~= value
    setValue(key, value)

    local opt = instance and instance.getOption and instance:getOption(key) or nil
    if opt ~= nil and opt.setValue ~= nil then
        local stored = value
        if def.kind == "choice" then
            stored = choiceIndexOf(def, value)
        end
        if stored ~= nil then pcall(opt.setValue, opt, stored) end
    end
    return changed
end

function Settings.save()
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then
        pcall(PZAPI.ModOptions.save, PZAPI.ModOptions)
    end
end

local LEGACY = {

    LOOT_SECTIONS = {
        key = "LOOT_LAYOUT",
        map = function(raw) return raw == "true" and "sections" or "single" end,
    },
}

local MIGRATIONS = {}

local function versionKey(v)
    local a, b, c = tostring(v or ""):match("^(%d*)%.?(%d*)%.?(%d*)")
    return (tonumber(a) or 0) * 10000 + (tonumber(b) or 0) * 100
        + (tonumber(c) or 0)
end

local function migrateScaleForFontOption()
    local stored = Settings.get("SCALE")
    local default = Settings.defaults.SCALE
    if type(stored) ~= "number" or stored == default then return end

    local core = type(getCore) == "function" and getCore() or nil
    local step = core ~= nil and core.getOptionFontSizeReal ~= nil
        and core:getOptionFontSizeReal() or nil
    local Style = ComfyGrid.UI and ComfyGrid.UI.Style or nil
    local now = Style ~= nil and Style.FONT_SCALE or nil
    if type(step) ~= "number" or type(now) ~= "number"
            or step <= 0 or now <= 0 then
        return
    end

    local fixed = stored * step / now
    if math.abs(fixed - stored) < 0.005 then return end

    fixed = math.floor(fixed * 10 + 0.5) / 10
    Settings.set("SCALE", fixed)
    Settings.save()
    Log.info("migrated SCALE " .. tostring(stored) .. " -> " .. tostring(fixed)
        .. " (font step " .. tostring(step) .. ", measured " .. tostring(now) .. ")")
end

MIGRATIONS[#MIGRATIONS + 1] =
    { since = "1.5.0", run = migrateScaleForFontOption }

local function runMigrations()
    local Prefs = ComfyGrid.Core and ComfyGrid.Core.Prefs
    if Prefs == nil then return end
    local seen = versionKey(Prefs.get("version"))
    local now = ComfyGrid.VERSION
    if seen >= versionKey(now) then return end
    for i = 1, #MIGRATIONS do
        local m = MIGRATIONS[i]
        if seen < versionKey(m.since) then
            local ok, err = pcall(m.run)
            if not ok then
                Log.warn("migration " .. m.since .. " failed: " .. tostring(err))
            end
        end
    end
    Prefs.set("version", now)
end

local function migrateLegacyOptions()
    local other = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.OtherOptions
    if type(other) ~= "table" then return end
    local migrated = false
    for i = #other, 1, -1 do
        local line = other[i]
        if type(line) == "string" then

            local modId, optId, raw = line:match("^[^|]*|([^|]*)|([^|]*)|(.-)%s*$")
            local rule = modId == ComfyGrid.MOD_ID and optId ~= nil
                and LEGACY[optId] or nil
            if rule ~= nil then
                local ok, mapped = pcall(rule.map, raw)
                if ok and mapped ~= nil then
                    Settings.set(rule.key, mapped)
                    Log.info("migrated option " .. optId .. "=" .. tostring(raw)
                        .. " -> " .. rule.key .. "=" .. tostring(mapped))
                end
                table.remove(other, i)
                migrated = true
            end
        end
    end
    if migrated then Settings.save() end
end

Settings.buildOptions()

if not ComfyGrid._settingsApplyHooked then
    ComfyGrid._settingsApplyHooked = true
    Events.OnGameStart.Add(function()
        if instance and instance.apply then
            pcall(instance.apply, instance)
        end

        pcall(migrateLegacyOptions)

        pcall(runMigrations)
    end)
end
