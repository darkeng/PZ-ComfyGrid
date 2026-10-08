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
    local key = KeyBinds.defaultKeyFor(KeyBinds.QUICK_EQUIP)
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
        local bindingRow = keyBinding[i]
        if bindingRow ~= nil and bindingRow.value == name then return true end
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
    local ok, keyCode = pcall(core.getKey, core, name)
    if ok and type(keyCode) == "number" and keyCode > 0 then return keyCode end
    return nil
end

function KeyBinds.rowFor(name)
    if MainOptions == nil or type(MainOptions.keyText) ~= "table" then
        return nil
    end
    for i = 1, #MainOptions.keyText do
        local keyRow = MainOptions.keyText[i]
        if keyRow ~= nil and not keyRow.value and keyRow.txt ~= nil then
            local ok, actionId = pcall(keyRow.txt.getName, keyRow.txt)
            if ok and actionId == name then return keyRow end
        end
    end
    return nil
end

function KeyBinds.labelFor(name)
    local row = KeyBinds.rowFor(name)
    if row == nil then return nil end
    local prefix = ""
    if MainOptions ~= nil and MainOptions.getKeyPrefix ~= nil then
        local ok, rowPrefix = pcall(MainOptions.getKeyPrefix, row)
        if ok and type(rowPrefix) == "string" then prefix = rowPrefix end
    end
    local okN, keyName = pcall(getKeyName, row.keyCode or 0)
    return prefix .. (okN and tostring(keyName) or "?")
end

function KeyBinds.duplicateOf(key, shift, ctrl, alt, exceptName)
    if MainOptions == nil or type(MainOptions.keyText) ~= "table" then
        return nil
    end
    for i = 1, #MainOptions.keyText do
        local keyRow = MainOptions.keyText[i]
        if keyRow ~= nil and not keyRow.value and keyRow.txt ~= nil then
            local ok, actionId = pcall(keyRow.txt.getName, keyRow.txt)
            if ok and actionId ~= exceptName and keyRow.keyCode == key
                    and (keyRow.shift == true) == (shift == true)
                    and (keyRow.ctrl == true) == (ctrl == true)
                    and (keyRow.alt == true) == (alt == true) then
                return actionId, KeyBinds.actionName(actionId)
            end
        end
    end
    return nil
end

function KeyBinds.actionName(name)
    local ok, translated = pcall(getText,
        "UI_optionscreen_binding_" .. tostring(name))
    if ok and type(translated) == "string" and translated ~= "" then
        local trimmed = translated:trim()
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
