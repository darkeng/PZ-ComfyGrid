--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.7.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local KeyBinds = {}
ComfyGrid.Interact.KeyBinds = KeyBinds

local Log = ComfyGrid.Core.Log

KeyBinds.CATEGORY = "[Comfy Grid]"

KeyBinds.QUICK_EQUIP = "ComfyGrid_QuickEquip"

local QUICK_EQUIP_DEFAULT = 18

function KeyBinds.install()
    if ComfyGrid._keyBindsInstalled then return end
    if type(keyBinding) ~= "table" then
        Log.warn("KeyBinds: no global keyBinding table; controls row skipped")
        return
    end
    ComfyGrid._keyBindsInstalled = true
    local key = QUICK_EQUIP_DEFAULT
    if Keyboard ~= nil and Keyboard.KEY_E ~= nil then key = Keyboard.KEY_E end
    table.insert(keyBinding, { value = KeyBinds.CATEGORY })
    table.insert(keyBinding, { value = KeyBinds.QUICK_EQUIP, key = key })
    Log.info("KeyBinds: registered " .. KeyBinds.QUICK_EQUIP)
end

function KeyBinds.defaultKeyFor(name)
    if name ~= KeyBinds.QUICK_EQUIP then return nil end
    if Keyboard ~= nil and Keyboard.KEY_E ~= nil then return Keyboard.KEY_E end
    return QUICK_EQUIP_DEFAULT
end

function KeyBinds.isRegistered(name)
    if type(keyBinding) ~= "table" then return false end
    for i = 1, #keyBinding do
        local b = keyBinding[i]
        if b ~= nil and b.value == name then return true end
    end
    return false
end

function KeyBinds.modifiersFor(name)
    local row = KeyBinds.rowFor(name)
    if row == nil then return false, false, false end
    return row.shift == true, row.ctrl == true, row.alt == true
end

function KeyBinds.keyFor(name)
    local core = getCore and getCore() or nil
    if core == nil or core.getKey == nil then return nil end
    local ok, k = pcall(core.getKey, core, name)
    if ok and type(k) == "number" and k > 0 then return k end
    return nil
end

function KeyBinds.rowFor(name)
    if MainOptions == nil or type(MainOptions.keyText) ~= "table" then
        return nil
    end
    for i = 1, #MainOptions.keyText do
        local v = MainOptions.keyText[i]
        if v ~= nil and not v.value and v.txt ~= nil then
            local ok, n = pcall(v.txt.getName, v.txt)
            if ok and n == name then return v end
        end
    end
    return nil
end

function KeyBinds.labelFor(name)
    local row = KeyBinds.rowFor(name)
    if row == nil then return nil end
    local prefix = ""
    if MainOptions ~= nil and MainOptions.getKeyPrefix ~= nil then
        local ok, p = pcall(MainOptions.getKeyPrefix, row)
        if ok and type(p) == "string" then prefix = p end
    end
    local okN, keyName = pcall(getKeyName, row.keyCode or 0)
    return prefix .. (okN and tostring(keyName) or "?")
end

function KeyBinds.duplicateOf(key, shift, ctrl, alt, exceptName)
    if MainOptions == nil or type(MainOptions.keyText) ~= "table" then
        return nil
    end
    for i = 1, #MainOptions.keyText do
        local v = MainOptions.keyText[i]
        if v ~= nil and not v.value and v.txt ~= nil then
            local ok, n = pcall(v.txt.getName, v.txt)
            if ok and n ~= exceptName and v.keyCode == key
                    and (v.shift == true) == (shift == true)
                    and (v.ctrl == true) == (ctrl == true)
                    and (v.alt == true) == (alt == true) then
                return n, KeyBinds.actionName(n)
            end
        end
    end
    return nil
end

function KeyBinds.actionName(name)
    local ok, t = pcall(getText, "UI_optionscreen_binding_" .. tostring(name))
    if ok and type(t) == "string" and t ~= "" then
        local trimmed = t:trim()
        if trimmed ~= "" then return trimmed end
    end
    return tostring(name)
end

function KeyBinds.assign(name, key, shift, ctrl, alt)
    local row = KeyBinds.rowFor(name)
    if row == nil then
        Log.warn("KeyBinds: no controls row for " .. tostring(name))
        return false
    end
    row.keyCode = key
    row.shift = shift == true
    row.ctrl = ctrl == true
    row.alt = alt == true
    if row.btn ~= nil and MainOptions.getKeyPrefix ~= nil then
        local okP, prefix = pcall(MainOptions.getKeyPrefix, row)
        local okN, keyName = pcall(getKeyName, key)
        if okP and okN then
            pcall(row.btn.setTitle, row.btn, prefix .. tostring(keyName))
        end
    end

    local core = getCore and getCore() or nil
    if core ~= nil and core.addKeyBinding ~= nil then
        pcall(core.addKeyBinding, core, name, key, row.altCode or 0,
            row.shift, row.ctrl, row.alt)
    end

    if MainOptions.saveKeys ~= nil then
        local okS, err = pcall(MainOptions.saveKeys)
        if not okS then
            Log.error("KeyBinds: saveKeys failed: " .. tostring(err))
            return false
        end
    end
    Log.info("KeyBinds: " .. tostring(name) .. " -> " .. tostring(key))
    return true
end

Events.OnGameBoot.Add(KeyBinds.install)
