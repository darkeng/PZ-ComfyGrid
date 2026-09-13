--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.7.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Model/ItemStack"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/Model/Equipment"
require "ComfyGrid/Interact/Tooltip"
require "ComfyGrid/Interact/Consume"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local QuickEquip = {}
ComfyGrid.Interact.QuickEquip = QuickEquip

local Log = ComfyGrid.Core.Log
local ItemStack = ComfyGrid.Model.ItemStack
local ContainerModel = ComfyGrid.Model.ContainerModel
local Equipment = ComfyGrid.Model.Equipment

local lastError = nil

local function isWearable(item)
    if instanceof(item, "Clothing") then return true end
    if item.canBeEquipped ~= nil then
        local ok, loc = pcall(item.canBeEquipped, item)
        if ok and loc ~= nil and tostring(loc) ~= "" then return true end
    end
    return false
end

local function canEquip(item)
    if item == nil then return false end
    if isWearable(item) then
        local ok, broken = pcall(item.isBroken, item)
        if ok and broken == true then return false end
        return true
    end
    if instanceof(item, "HandWeapon") then

        local ok, condition = pcall(item.getCondition, item)
        if ok and type(condition) == "number" and condition <= 0 then
            return false
        end
        return true
    end

    return false
end

local function queueLength(playerObj)
    if ISTimedActionQueue == nil then return 0 end
    local ok, q = pcall(ISTimedActionQueue.getTimedActionQueue, playerObj)
    if not ok or q == nil or q.queue == nil then return 0 end
    return #q.queue
end

local function isHandEquippable(item)
    if item == nil then return false end
    if instanceof(item, "HandWeapon") then
        local ok, condition = pcall(item.getCondition, item)
        return not (ok and type(condition) == "number" and condition <= 0)
    end
    if not instanceof(item, "InventoryItem") then return false end
    if instanceof(item, "Clothing") then return false end
    if instanceof(item, "Food") then return false end
    return true
end

local function capacityOf(item)
    if item == nil or not instanceof(item, "InventoryContainer") then return nil end
    if item.getInventory == nil then return nil end
    local ok, inv = pcall(item.getInventory, item)
    if not ok or inv == nil then return nil end
    local Capacity = ComfyGrid.Model and ComfyGrid.Model.Capacity
    if Capacity == nil or Capacity.effectiveFor == nil then return nil end
    return Capacity.effectiveFor(inv, 0)
end

local function holdsMoreThan(item, other)
    local mine = capacityOf(item)
    local theirs = capacityOf(other)
    if mine == nil or theirs == nil then return false end
    return mine > theirs
end

local function equipInHand(playerObj, item)
    local two = false
    local okT, isTwo = pcall(item.isTwoHandWeapon, item)
    if okT and isTwo then two = true end
    local okR, forcesTwo = pcall(item.isRequiresEquippedBothHands, item)
    if okR and forcesTwo then two = true end

    local primary = true
    if not two then
        local okP, held = pcall(playerObj.getPrimaryHandItem, playerObj)
        local okS, off = pcall(playerObj.getSecondaryHandItem, playerObj)
        if okP and held ~= nil and okS and off == nil then primary = false end
    end
    pcall(ISInventoryPaneContextMenu.equipWeapon, item, primary, two, 0)
end

local function isEquippableKind(item)
    if item == nil then return false end
    return isWearable(item) or instanceof(item, "HandWeapon")
end

local function equippableIn(stack, inventory)
    local front = ItemStack.frontItem(stack, inventory)
    if front == nil then return nil end
    if canEquip(front) then return front end
    local items = ItemStack.getItems(stack, inventory)
    for i = 1, #items do
        if canEquip(items[i]) then return items[i] end
    end
    return nil
end

local function equipHovered()
    local playerObj = getSpecificPlayer(0)
    if playerObj == nil then return end

    local dd = ComfyGrid.Interact.DragAndDrop
    if dd ~= nil and dd.isDragging ~= nil and dd.isDragging() then return end
    local Tooltip = ComfyGrid.Interact.Tooltip
    if Tooltip == nil or Tooltip.hoveredStackOf == nil then return end

    local stack, inventory
    local page = getPlayerInventory(0)
    local pane = page ~= nil and page.inventoryPane or nil
    if pane ~= nil then
        stack, inventory = Tooltip.hoveredStackOf(pane)
    end
    if stack == nil then
        page = getPlayerLoot(0)
        pane = page ~= nil and page.inventoryPane or nil
        if pane ~= nil then
            stack, inventory = Tooltip.hoveredStackOf(pane)
        end
    end
    if stack == nil or inventory == nil then return end
    local front = equippableIn(stack, inventory)
    if front == nil then

        local item = ItemStack.frontItem(stack, inventory)
        if item == nil or isEquippableKind(item) then return end

        local Consume = ComfyGrid.Interact and ComfyGrid.Interact.Consume
        if Consume ~= nil and Consume.tryUse ~= nil then
            local okC, owned = pcall(Consume.tryUse, playerObj, item, 0)
            if okC and owned then return end
        end

        local queued = queueLength(playerObj)
        if pane ~= nil and pane.doContextualDblClick ~= nil then
            local okAct, errAct = pcall(pane.doContextualDblClick, pane, item)
            if not okAct and errAct ~= lastError then
                lastError = errAct
                Log.error("QuickEquip contextual action failed: "
                    .. tostring(errAct))
            end
        end
        if queueLength(playerObj) > queued then return end

        local okMap, isMap = pcall(item.IsMap, item)
        if okMap and isMap then return end

        if isHandEquippable(item) then equipInHand(playerObj, item) end
        return
    end

    local displaced
    if isWearable(front) then
        displaced = Equipment.findDisplacedWorn(playerObj, front)

        if displaced ~= nil and isHandEquippable(front)
                and not holdsMoreThan(front, displaced) then
            equipInHand(playerObj, front)
            return
        end
        ISInventoryPaneContextMenu.onWearItems({ front }, 0)

    elseif instanceof(front, "HandWeapon") then

        local okH, held = pcall(playerObj.getPrimaryHandItem, playerObj)
        displaced = okH and held or nil
        local twoHands = front.isTwoHandWeapon ~= nil
            and front:isTwoHandWeapon() or false
        ISInventoryPaneContextMenu.equipWeapon(front, true, twoHands, 0)
    else
        return
    end

    if displaced ~= nil and displaced ~= front
            and inventory == playerObj:getInventory()
            and type(stack.slot) == "number" then
        local model = ContainerModel.getOrCreate(inventory, 0)
        local grid = model ~= nil and model.grid or nil
        if grid ~= nil and grid.claimSlotForItem ~= nil then
            grid:claimSlotForItem(displaced:getID(), stack.slot)
        end
    end
end

local SHIELD_MAX_MS = 1500

local shieldBox = nil
local shieldKey = nil
local shieldSinceMs = 0

QuickEquip._rawKeyDown = function(key)
    return GameKeyboard ~= nil and GameKeyboard.isKeyDownRaw ~= nil
        and GameKeyboard.isKeyDownRaw(key) == true
end

local function shieldUp(key)
    if shieldBox == nil then
        if ISTextEntryBox == nil then return false end

        local box = ISTextEntryBox:new("", -10, -10, 1, 1)
        box:initialise()
        box:instantiate()
        if box.setEditable ~= nil then box:setEditable(false) end
        if box.setVisible ~= nil then box:setVisible(false) end
        shieldBox = box
    end
    shieldBox:focus()
    shieldKey = key
    shieldSinceMs = getTimestampMs()
    return true
end

local function shieldDown()
    if shieldBox ~= nil and shieldBox.isFocused ~= nil and shieldBox:isFocused() then
        shieldBox:unfocus()
    end
    shieldKey = nil
end

function QuickEquip.isShielding()
    return shieldKey ~= nil
end

function QuickEquip._onTick()
    if shieldKey == nil then return end
    local held = QuickEquip._rawKeyDown(shieldKey)
    if not held or getTimestampMs() - shieldSinceMs > SHIELD_MAX_MS then
        shieldDown()
    end
end

local function overAnyBoard()
    local Tooltip = ComfyGrid.Interact.Tooltip
    if Tooltip == nil or Tooltip.isOverBoard == nil then return false end
    for _, getter in ipairs({ getPlayerInventory, getPlayerLoot }) do
        local ok, page = pcall(getter, 0)
        local pane = ok and page ~= nil and page.inventoryPane or nil
        if pane ~= nil and pane.mode == "comfy" and Tooltip.isOverBoard(pane) then
            return true
        end
    end
    return false
end

local function targetKey()
    local KeyBinds = ComfyGrid.Interact and ComfyGrid.Interact.KeyBinds
    if KeyBinds ~= nil and KeyBinds.isRegistered ~= nil
            and KeyBinds.isRegistered(KeyBinds.QUICK_EQUIP) then

        return KeyBinds.keyFor(KeyBinds.QUICK_EQUIP)
    end

    local core = getCore and getCore() or nil
    if core ~= nil and core.getKey ~= nil then
        local ok, k = pcall(core.getKey, core, "Interact")
        if ok and type(k) == "number" and k > 0 then return k end
    end
    return Keyboard ~= nil and Keyboard.KEY_E or nil
end

local function modifiersHeld()
    local KeyBinds = ComfyGrid.Interact and ComfyGrid.Interact.KeyBinds
    if KeyBinds == nil or KeyBinds.modifiersFor == nil then return true end
    local ok, shift, ctrl, alt = pcall(KeyBinds.modifiersFor,
        KeyBinds.QUICK_EQUIP)
    if not ok then return true end
    if not (shift or ctrl or alt) then return true end
    if Keyboard == nil then return true end
    if shift and not (Keyboard.isKeyDown(Keyboard.KEY_LSHIFT)
            or Keyboard.isKeyDown(Keyboard.KEY_RSHIFT)) then
        return false
    end
    if ctrl and not (Keyboard.isKeyDown(Keyboard.KEY_LCONTROL)
            or Keyboard.isKeyDown(Keyboard.KEY_RCONTROL)) then
        return false
    end
    if alt and not (Keyboard.isKeyDown(Keyboard.KEY_LMENU)
            or Keyboard.isKeyDown(Keyboard.KEY_RMENU)) then
        return false
    end
    return true
end

function QuickEquip._onKey(key)
    local target = targetKey()
    if target == nil or key ~= target then return end

    local okMods, held = pcall(modifiersHeld)
    if okMods and not held then return end

    local okB, over = pcall(overAnyBoard)
    if okB and over then
        local okS, err = pcall(shieldUp, key)
        if not okS and err ~= lastError then
            lastError = err
            Log.error("QuickEquip shield failed: " .. tostring(err))
        end
    end
    local ok, err = pcall(equipHovered)
    if not ok and err ~= lastError then
        lastError = err
        Log.error("QuickEquip failed: " .. tostring(err))
    end
end

if not ComfyGrid._quickEquipHooked then
    ComfyGrid._quickEquipHooked = true
    Events.OnKeyStartPressed.Add(function(key)
        local qe = ComfyGrid.Interact and ComfyGrid.Interact.QuickEquip
        if qe ~= nil and qe._onKey ~= nil then
            qe._onKey(key)
        end
    end)
    Events.OnTick.Add(function()
        local qe = ComfyGrid.Interact and ComfyGrid.Interact.QuickEquip
        if qe ~= nil and qe._onTick ~= nil then
            qe._onTick()
        end
    end)
end
