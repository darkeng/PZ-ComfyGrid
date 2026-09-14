--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.7.3
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
    THEME = "amber",
    SCALE = 1,
    SLOTS_PER_CAPACITY = 2,
    INSTANT_TRANSFER = false,
    PLAYER_LAYOUT = "compact",

    LOOT_LAYOUT = "sections",

    COMPACT_ROWS = true,

    SORT_ORDER = "category",
    STACK_BY_TYPE = true,

    STATUS_BAR = true,
    HOTBAR_SECTION = false,
    HOTBAR_BAR = true,
    EQUIPMENT_VIEW = "window",
    EQUIPMENT_AVATAR = "model",

    TRANSFER_GESTURE = "shift",
    MULTISELECT_MOD = "ctrl",
}

local GROUPS = {

    { key = "general",  nameKey = "IGUI_ComfyGrid_GroupGeneral",  name = "General" },
    { key = "style",    nameKey = "IGUI_ComfyGrid_GroupStyle",    name = "Style" },
    { key = "controls", nameKey = "IGUI_ComfyGrid_GroupControls", name = "Controls" },
}

local OPTION_DEFS = {

    { key = "THEME",              kind = "choice", group = "style",

      values = { "amber", "dark", "slate", "olive", "sakura" },
      labelKeys = { "IGUI_ComfyGrid_ThemeAmber",
                    "IGUI_ComfyGrid_ThemeDark",
                    "IGUI_ComfyGrid_ThemeSlate",
                    "IGUI_ComfyGrid_ThemeOlive",
                    "IGUI_ComfyGrid_ThemeSakura" },
      labels = { "Comfy Grid - warm amber",
                 "Dark - vanilla greys",
                 "Slate - cool blue",
                 "Olive - muted green",
                 "Sakura - warm pink" },
      nameKey = "IGUI_ComfyGrid_OptTheme",
      tipKey = "IGUI_ComfyGrid_OptThemeTip",
      tooltip = "Colours for windows, borders, buttons, text and tiles." },

    { key = "SORT_ORDER",         kind = "choice", group = "style",
      values = { "category", "categoryWeight", "weight" },
      labelKeys = { "IGUI_ComfyGrid_SortOrderCategory",
                    "IGUI_ComfyGrid_SortOrderCategoryWeight",
                    "IGUI_ComfyGrid_SortOrderWeight" },
      labels = { "Category",
                 "Category, heaviest first",
                 "Heaviest first" },
      nameKey = "IGUI_ComfyGrid_OptSortOrder",
      tipKey = "IGUI_ComfyGrid_OptSortOrderTip",
      tooltip = "What the sort button arranges by." },
    { key = "SCALE",              kind = "slider", group = "style",
      min = 0.3, max = 4, step = 0.1,
      nameKey = "IGUI_ComfyGrid_OptScale",
      tipKey = "IGUI_ComfyGrid_OptScaleTip",
      tooltip = "How big the grid is drawn." },
    { key = "PLAYER_LAYOUT",      kind = "choice", group = "general",
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
    { key = "LOOT_LAYOUT",        kind = "choice", group = "general",
      values = { "single", "sections" },
      labelKeys = { "IGUI_ComfyGrid_LootLayoutSingle",
                    "IGUI_ComfyGrid_LootLayoutSections" },
      labels = { "One container at a time",
                 "Every container within reach" },
      nameKey = "IGUI_ComfyGrid_OptLootLayout",
      tipKey = "IGUI_ComfyGrid_OptLootLayoutTip",
      tooltip = "How many containers the loot window shows." },

    { key = "EQUIPMENT_VIEW",     kind = "choice", group = "general",
      values = { "strip", "window", "off" },
      labelKeys = { "IGUI_ComfyGrid_EquipViewStrip",
                    "IGUI_ComfyGrid_EquipViewWindow",
                    "IGUI_ComfyGrid_EquipViewOff" },
      labels = { "A row in the inventory",
                 "Its own window",
                 "Off - another mod shows it" },
      nameKey = "IGUI_ComfyGrid_OptEquipmentView",
      tipKey = "IGUI_ComfyGrid_OptEquipmentViewTip",
      tooltip = "Where your equipment lives, or off if another mod shows it." },
    { key = "EQUIPMENT_AVATAR",   kind = "choice", group = "general",
      values = { "model", "silhouette" },
      labelKeys = { "IGUI_ComfyGrid_EquipAvatarModel",
                    "IGUI_ComfyGrid_EquipAvatarSilhouette" },
      labels = { "Your character in 3D",
                 "A plain silhouette" },
      nameKey = "IGUI_ComfyGrid_OptEquipmentAvatar",
      tipKey = "IGUI_ComfyGrid_OptEquipmentAvatarTip",
      tooltip = "How your character is drawn." },
    { key = "HOTBAR_SECTION",     kind = "tickbox", group = "general",
      nameKey = "IGUI_ComfyGrid_OptHotbarSection",
      tipKey = "IGUI_ComfyGrid_OptHotbarSectionTip",
      tooltip = "Turn it off if you use the bar at the bottom of the screen." },

    { key = "HOTBAR_BAR",         kind = "tickbox", group = "general",
      nameKey = "IGUI_ComfyGrid_OptHotbarBar",
      tipKey = "IGUI_ComfyGrid_OptHotbarBarTip",
      tooltip = "The bar at the bottom of the screen wears the mod's tiles. Turn it off to leave it to the game or to another mod." },
    { key = "SLOTS_PER_CAPACITY", kind = "slider", group = "style",
      min = 1, max = 4, step = 0.5,
      nameKey = "IGUI_ComfyGrid_OptSlotsPerCapacity",
      tipKey = "IGUI_ComfyGrid_OptSlotsPerCapacityTip",
      tooltip = "Slots each point of container capacity is worth." },
    { key = "COMPACT_ROWS",       kind = "tickbox", group = "style",
      nameKey = "IGUI_ComfyGrid_OptCompactRows",
      tipKey = "IGUI_ComfyGrid_OptCompactRowsTip",
      tooltip = "Show one spare row instead of the whole capacity." },
    { key = "STACK_BY_TYPE",      kind = "tickbox", group = "style",
      nameKey = "IGUI_ComfyGrid_OptStackByType",
      tipKey = "IGUI_ComfyGrid_OptStackByTypeTip",
      tooltip = "Identical items share a tile whatever their state." },

    { key = "STATUS_BAR",         kind = "tickbox", group = "style",
      nameKey = "IGUI_ComfyGrid_OptStatusBar",
      tipKey = "IGUI_ComfyGrid_OptStatusBarTip",
      tooltip = "The bar at a tile's edge: condition, charge, what's left and reading progress." },

    { key = "TRANSFER_GESTURE",   kind = "choice", group = "controls",

      values = { "shift", "doubleclick", "ctrl", "alt" },
      labelKeys = { "IGUI_ComfyGrid_GestureShift",
                    "IGUI_ComfyGrid_GestureDouble",
                    "IGUI_ComfyGrid_GestureCtrl",
                    "IGUI_ComfyGrid_GestureAlt" },
      labels = { "Shift and click",
                 "Double click",
                 "Ctrl and click",
                 "Alt and click" },
      nameKey = "IGUI_ComfyGrid_OptTransferGesture",
      tipKey = "IGUI_ComfyGrid_OptTransferGestureTip",
      tooltip = "How an item moves to the other inventory.",

      padOffKey = "IGUI_ComfyGrid_PadInsteadTransfer",
      padOff = "The pad uses X",
      padOffTipKey = "IGUI_ComfyGrid_PadInsteadTransferTip",
      padOffTip = "A joypad always moves items with X. Turn the joypad off to pick a mouse gesture again." },

    { key = "MULTISELECT_MOD",    kind = "choice", group = "controls",
      values = { "ctrl", "shift", "alt" },
      labelKeys = { "IGUI_ComfyGrid_ModCtrl",
                    "IGUI_ComfyGrid_ModShift",
                    "IGUI_ComfyGrid_ModAlt" },
      labels = { "Ctrl", "Shift", "Alt" },
      nameKey = "IGUI_ComfyGrid_OptMultiSelectMod",
      tipKey = "IGUI_ComfyGrid_OptMultiSelectModTip",
      tooltip = "Held with a click to mark several tiles, or dragged to rubber-band them.",

      padOffKey = "IGUI_ComfyGrid_PadInsteadMultiSelect",
      padOff = "The pad uses L3",
      padOffTipKey = "IGUI_ComfyGrid_PadInsteadMultiSelectTip",
      padOffTip = "A joypad marks tiles with the left stick button. Turn the joypad off to pick a modifier again." },
    { key = "QUICK_EQUIP_KEY",    kind = "keybind", group = "controls",
      bind = "ComfyGrid_QuickEquip",
      nameKey = "IGUI_ComfyGrid_OptQuickEquipKey",
      tipKey = "IGUI_ComfyGrid_OptQuickEquipKeyTip",
      tooltip = "Acts on whatever is under the cursor: wear, wield, eat, open, smoke, read.",

      padOffKey = "IGUI_ComfyGrid_PadInsteadQuickEquip",
      padOff = "The pad uses Y",
      padOffTipKey = "IGUI_ComfyGrid_PadInsteadQuickEquipTip",
      padOffTip = "A joypad uses and equips from the Y menu. Turn the joypad off to bind a key again." },

    { key = "INSTANT_TRANSFER",   kind = "tickbox", group = "controls",
      nameKey = "IGUI_ComfyGrid_OptInstantTransfer",
      tipKey = "IGUI_ComfyGrid_OptInstantTransferTip",
      tooltip = "Items move with no transfer time." },
}

Settings.GROUPS = GROUPS
Settings.OPTION_DEFS = OPTION_DEFS

function Settings.defsInGroup(groupKey, out)
    out = out or {}
    for i = 1, #OPTION_DEFS do
        local def = OPTION_DEFS[i]
        if def.group == groupKey then out[#out + 1] = def end
    end
    return out
end

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

function Settings.transferIsDoubleClick()
    local ok, v = pcall(Settings.get, "TRANSFER_GESTURE")
    if not ok then return false end
    return v == "doubleclick"
end

function Settings.transferModifier()
    local ok, v = pcall(Settings.get, "TRANSFER_GESTURE")
    if not ok or v == nil or v == "doubleclick" then return nil end
    return v
end

function Settings.multiSelectModifier()
    local ok, v = pcall(Settings.get, "MULTISELECT_MOD")
    if not ok or v == nil then return "ctrl" end
    return v
end

local function modifierHeld(name)
    if name == "shift" then
        return isShiftKeyDown ~= nil and isShiftKeyDown() == true
    end
    if name == "ctrl" then
        return isCtrlKeyDown ~= nil and isCtrlKeyDown() == true
    end
    if name == "alt" then
        if Keyboard == nil or Keyboard.isKeyDown == nil then return false end
        return Keyboard.isKeyDown(Keyboard.KEY_LMENU) == true
            or Keyboard.isKeyDown(Keyboard.KEY_RMENU) == true
    end
    return false
end

function Settings.multiSelectHeld()
    local mine = Settings.multiSelectModifier()
    if not modifierHeld(mine) then return false end
    local other = Settings.transferModifier()
    if other ~= nil and other ~= mine and modifierHeld(other) then
        return false
    end
    return true
end

function Settings.transferModifierHeld()
    local mine = Settings.transferModifier()
    if mine == nil then return false end
    return modifierHeld(mine)
end

function Settings.tipFor(def)
    if def == nil then return nil end
    return def.tipKey and Text.tr(def.tipKey, def.tooltip) or def.tooltip
end

function Settings.appliesNow(def, playerNum)
    if def == nil or def.padOffKey == nil then return true end
    local Input = ComfyGrid.Core and ComfyGrid.Core.Input
    if Input == nil or Input.padOwns == nil then return true end
    local ok, owned = pcall(Input.padOwns, playerNum)
    if not ok then return true end
    return not owned
end

function Settings.padNoteFor(def)
    if def == nil or def.padOffKey == nil then return nil end
    return Text.tr(def.padOffKey, def.padOff)
end

function Settings.padTipFor(def)
    if def == nil or def.padOffTipKey == nil then return nil end
    return Text.tr(def.padOffTipKey, def.padOffTip)
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

local function applyTheme(name)
    local Themes = ComfyGrid.UI and ComfyGrid.UI.Themes
    if Themes == nil then return end
    local ok, err = pcall(Themes.apply, name)
    if not ok then
        Log.warn("Settings: theme '" .. tostring(name) .. "' failed: "
            .. tostring(err))
    end
end

Settings.onChanged("THEME", applyTheme)

function Settings.applyStoredTheme()
    applyTheme(Settings.get("THEME"))
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

        local groupDefs = {}
        for g = 1, #GROUPS do
            local groupKey = GROUPS[g].key
            for k = #groupDefs, 1, -1 do groupDefs[k] = nil end
            Settings.defsInGroup(groupKey, groupDefs)

            if #groupDefs > 0 then

                instance:addTitle(Settings.groupLabel(groupKey))
                for i = 1, #groupDefs do
                    local def = groupDefs[i]

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
                    elseif def.kind == "slider" then
                        instance:addSlider(def.key, title, def.min, def.max, def.step,
                            Settings.defaults[def.key], tip)
                    elseif def.kind == "keybind" then

                        _ = def
                    else

                        Log.warn("option '" .. tostring(def.key) .. "' has unknown kind '"
                            .. tostring(def.kind) .. "'; not shown on the options screen")
                    end
                end
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

local swapping = false
local function keepModifiersDistinct(changedKey, previous)
    if swapping then return end
    if changedKey ~= "MULTISELECT_MOD" and changedKey ~= "TRANSFER_GESTURE" then
        return
    end
    local gesture = values.TRANSFER_GESTURE
    local multi = values.MULTISELECT_MOD
    if gesture == nil or multi == nil or gesture ~= multi then return end

    local otherKey = "TRANSFER_GESTURE"
    if changedKey == "TRANSFER_GESTURE" then otherKey = "MULTISELECT_MOD" end
    local otherDef = Settings.defOf(otherKey)
    if otherDef == nil then return end

    local target = nil
    if previous ~= nil and choiceIndexOf(otherDef, previous) ~= nil
            and previous ~= values[changedKey] then
        target = previous
    else
        for i = 1, #otherDef.values do
            if otherDef.values[i] ~= values[changedKey] then
                target = otherDef.values[i]
                break
            end
        end
    end
    if target == nil then return end
    swapping = true
    pcall(Settings.set, otherKey, target)
    swapping = false
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
    local previous = values[key]
    local changed = previous ~= value
    setValue(key, value)
    keepModifiersDistinct(key, previous)

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

function Settings.syncPadAvailability(playerNum)
    if instance == nil or instance.getOption == nil then return end
    for i = 1, #OPTION_DEFS do
        local def = OPTION_DEFS[i]
        if def.padOffKey ~= nil then
            local opt = nil
            local okGet, got = pcall(instance.getOption, instance, def.key)
            if okGet then opt = got end
            if opt ~= nil and opt.setEnabled ~= nil then
                pcall(opt.setEnabled, opt, Settings.appliesNow(def, playerNum))
            end
        end
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

        pcall(Settings.applyStoredTheme)

        pcall(runMigrations)

        pcall(Settings.syncPadAvailability, 0)
    end)
end

if not ComfyGrid._settingsPadHooked then
    ComfyGrid._settingsPadHooked = true
    local function syncPad()
        pcall(Settings.syncPadAvailability, 0)
    end
    for _, name in ipairs({ "OnJoypadActivate", "OnJoypadDeactivate",
                            "OnGamepadConnect", "OnGamepadDisconnect" }) do
        local ev = Events ~= nil and Events[name] or nil
        if ev ~= nil and ev.Add ~= nil then pcall(ev.Add, syncPad) end
    end
end
