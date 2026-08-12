--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Style"
require "ComfyGrid/Interact/QuickMove"
require "ComfyGrid/Interact/ContextMenu"
require "ComfyGrid/Interact/Pad/PadFocus"
require "ComfyGrid/Interact/Pad/PadCarry"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local PadInput = {}
ComfyGrid.Interact.PadInput = PadInput

local Style = ComfyGrid.UI.Style
local QuickMove = ComfyGrid.Interact.QuickMove
local ContextMenu = ComfyGrid.Interact.ContextMenu
local PadFocus = ComfyGrid.Interact.PadFocus
local PadCarry = ComfyGrid.Interact.PadCarry

local function hotbarIndexOf(strip, seat, itemId)
    if itemId == nil then return nil end
    local ok, hotbar = pcall(getPlayerHotbar, seat)
    local att = ok and hotbar ~= nil and hotbar.attachedItems or nil
    if att == nil then return nil end
    for i = 1, strip.entryCount or 0 do
        local it = att[i]
        if it ~= nil and it:getID() == itemId then return i - 1 end
    end
    return nil
end

local function verbA(page, seat)
    local kind, el, slot, occupant = PadFocus.peek(page)
    if kind == nil then return true end
    if PadCarry.isCarrying(seat) then
        if kind == "equip" then
            el:resolvePadDrop(slot)
            PadCarry.finish(seat)
        elseif kind == "hotbar" then

            local fromIdx = hotbarIndexOf(el, seat, PadCarry.carriedItemId(seat))
            if fromIdx ~= nil then
                el:resolvePadReslot(fromIdx, slot, PadCarry.carriedItemId(seat))
            else
                el:resolvePadDrop(slot)
            end
            PadCarry.finish(seat)
        else
            PadCarry.place(seat, el, slot)
        end
        return true
    end
    if occupant == nil then return true end
    if kind == "equip" or kind == "hotbar" then
        PadCarry.pickupItem(seat, occupant)
    else
        PadCarry.pickup(seat, el, occupant)
    end
    return true
end

function PadInput.quickMoveSeatSelections(page, seat, skipEl)
    local function sweep(pg)
        PadFocus.eachGridNode(pg, function(el)
            if el ~= skipEl and el.padSelectionPayload ~= nil
                    and el.model ~= nil then
                local payload = el:padSelectionPayload()
                if payload ~= nil then
                    QuickMove.run(payload, el.model.inventory, seat)
                end
            end
        end)
    end
    sweep(page)
    local other = page.onCharacter and getPlayerLoot(seat)
        or getPlayerInventory(seat)
    if other ~= nil and other ~= page then sweep(other) end
end

local function verbX(page, seat)
    if PadCarry.isCarrying(seat) then

        PadCarry.quickMoveCarried(seat)
        return true
    end
    local kind, el, _, occupant = PadFocus.peek(page)
    if kind == nil or occupant == nil then return true end
    if kind == "equip" then

        pcall(ISInventoryPaneContextMenu.unequipItem, occupant, seat)
    elseif kind == "hotbar" then

        local ok, hotbar = pcall(getPlayerHotbar, seat)
        if ok and hotbar ~= nil then
            pcall(hotbar.removeItem, hotbar, occupant, true)
        end
    elseif el.model ~= nil then

        local payload = el.dragPayloadFor ~= nil
            and el:dragPayloadFor(occupant) or nil
        QuickMove.run(payload or { occupant }, el.model.inventory, seat)

        local skipEl = el.padIsSelected ~= nil and el:padIsSelected(occupant)
            and el or nil
        PadInput.quickMoveSeatSelections(page, seat, skipEl)
    end
    return true
end

local function verbSelect(page, seat)
    if PadCarry.isCarrying(seat) then return true end
    local kind, el, _, occupant = PadFocus.peek(page)
    if (kind == "grid" or kind == "pocket") and occupant ~= nil
            and el.padToggleSelect ~= nil then
        el:padToggleSelect(occupant)
    end
    return true
end

local function verbY(page, seat)
    if PadCarry.cancel(seat) then return true end
    local kind, el, slot, occupant = PadFocus.peek(page)
    if kind == nil or occupant == nil then return true end

    local px, py = Style.pixelForSlot(slot, el.cols or 1)
    local cell = Style.CELL or 45
    local ax = el:getAbsoluteX() + px + cell
    local ay = el:getAbsoluteY() + py + cell
    if kind == "equip" or kind == "hotbar" then
        ContextMenu.openForItems(seat, { occupant }, ax, ay, page)
    else
        ContextMenu.open(seat, { occupant }, el, ax, ay)
    end
    return true
end

local function verbB(page, seat)
    if PadCarry.cancel(seat) then return true end

    if PadFocus.clearSelections(page) then return true end
    setJoypadFocus(seat, nil)
    return true
end

local function verbShoulder(page, seat, wantLoot)
    if page.onCharacter ~= wantLoot then return false end
    local target = wantLoot and getPlayerLoot(seat) or getPlayerInventory(seat)
    return PadFocus.focusWindow(page, target)
end

local function verbLB(page, seat)
    return verbShoulder(page, seat, false)
end

local function verbRB(page, seat)
    return verbShoulder(page, seat, true)
end

local function verbInspect(page, seat)
    if PadCarry.isCarrying(seat) then return true end
    local kind, el, slot, occupant = PadFocus.peek(page)
    if kind == nil or occupant == nil then return true end
    local PadPopup = ComfyGrid.Interact.PadPopup
    if PadPopup == nil then return true end
    if kind == "equip" then

        local entry = el.entries ~= nil and el.entries[slot + 1] or nil
        if entry ~= nil and entry.items ~= nil and #entry.items > 1 then
            local LayersPopup = ComfyGrid.UI and ComfyGrid.UI.LayersPopup
            local popup = LayersPopup ~= nil and LayersPopup.openFor ~= nil
                and LayersPopup.openFor(el, entry.key) or nil
            if popup ~= nil then PadPopup.focus(popup, page) end
        end
    elseif kind == "grid" or kind == "pocket" then

        if (occupant.count or 0) > 1 then
            local StackPopup = ComfyGrid.UI and ComfyGrid.UI.StackPopup
            local popup = StackPopup ~= nil and StackPopup.openFor ~= nil
                and StackPopup.openFor(el, occupant) or nil
            if popup ~= nil then PadPopup.focus(popup, page) end
        end
    end
    return true
end

local VERBS = nil

local function verbs()
    if VERBS == nil then
        VERBS = {
            [Joypad.AButton] = verbA,
            [Joypad.BButton] = verbB,
            [Joypad.XButton] = verbX,
            [Joypad.YButton] = verbY,
            [Joypad.LBumper] = verbLB,
            [Joypad.RBumper] = verbRB,
            [Joypad.LStickButton] = verbSelect,
            [Joypad.RStickButton] = verbInspect,
        }
    end
    return VERBS
end

function PadInput.onButton(page, button)
    local fn = verbs()[button]
    if fn == nil then return false end
    return fn(page, page.player) == true
end

local labels = {}
local function label(key)
    local s = labels[key]
    if s == nil then
        s = getText("IGUI_ComfyGrid_Pad" .. key)
        labels[key] = s
    end
    return s
end

function PadInput.promptFor(page, slotKey)
    if slotKey == "LB" then

        if page.onCharacter then return label("Section") end
        return label("Inventory")
    end
    if slotKey == "RB" then

        if page.onCharacter then return label("Loot") end
        return label("Container")
    end

    if slotKey == "L3" then
        if PadCarry.isCarrying(page.player) then return nil end
        local kind, _, _, occupant = PadFocus.peek(page)
        if (kind == "grid" or kind == "pocket") and occupant ~= nil then
            return label("Select")
        end
        return nil
    end
    if slotKey == "R3" then
        if PadCarry.isCarrying(page.player) then return nil end
        local kind, el, slot, occupant = PadFocus.peek(page)
        if occupant == nil then return nil end
        if kind == "grid" or kind == "pocket" then

            if (occupant.count or 0) > 1 then return label("Inspect") end
            return nil
        end
        if kind == "equip" then
            local entry = el.entries ~= nil and el.entries[slot + 1] or nil
            if entry ~= nil and entry.items ~= nil and #entry.items > 1 then
                return label("Inspect")
            end
        end
        return nil
    end
    local kind, _, _, occupant = PadFocus.peek(page)
    local onStrip = kind == "equip" or kind == "hotbar"
    if PadCarry.isCarrying(page.player) then
        if slotKey == "A" then
            return onStrip and label("Equip") or label("Place")
        end
        if slotKey == "X" then return label("QuickMove") end
        if slotKey == "B" then return label("Cancel") end
        return nil
    end
    if slotKey == "B" then return label("Close") end
    if occupant == nil then return nil end
    if slotKey == "A" then return label("Take") end
    if slotKey == "X" then
        return onStrip and label("Unequip") or label("QuickMove")
    end
    if slotKey == "Y" then return label("Menu") end
    return nil
end

return PadInput
