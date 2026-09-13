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
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local Tooltip = {}
ComfyGrid.Interact.Tooltip = Tooltip

local Log = ComfyGrid.Core.Log
local ItemStack = ComfyGrid.Model.ItemStack

local function isDragActive()
    local dnd = ComfyGrid.Interact.DragAndDrop
    if dnd ~= nil and dnd.isDragging ~= nil and dnd.isDragging() then
        return true
    end
    return ISMouseDrag.dragging ~= nil
end

local function containerWindowGrid(pane)
    local page = pane ~= nil and pane.parent or nil
    if page == nil or page.onCharacter ~= true then return nil end
    local CW = ComfyGrid.UI and ComfyGrid.UI.ContainerWindow
    if CW == nil or CW.gridFor == nil then return nil end
    return CW.gridFor(page.player)
end

local function overContainerWindow(pane)
    local page = pane ~= nil and pane.parent or nil
    if page == nil or page.onCharacter ~= true then return false end
    local CW = ComfyGrid.UI and ComfyGrid.UI.ContainerWindow
    if CW == nil or CW.isMouseOverIt == nil then return false end
    local ok, over = pcall(CW.isMouseOverIt, page.player)
    return ok and over == true
end

local function hoveredStack(pane)

    if overContainerWindow(pane) then
        local gv = containerWindowGrid(pane)
        if gv ~= nil then
            local slot = gv.hoverSlot
            if slot ~= nil and gv:isMouseOver() and gv.model ~= nil
                    and gv.model.grid ~= nil then
                return gv.model.grid:stackAt(slot), gv.model.inventory
            end
        end
        return nil, nil
    end
    local host = pane.comfyHost
    if host == nil or not host.panelShown then return nil, nil end

    local panels = host.panels
    local single = panels == nil and host.containerPanel or nil
    local count = panels ~= nil and #panels or (single ~= nil and 1 or 0)

    local function probe(gridView)
        if gridView == nil then return nil, nil end
        local slot = gridView.hoverSlot
        if slot == nil or not gridView:isMouseOver() then return nil, nil end
        local model = gridView.model
        if model == nil or model.grid == nil then return nil, nil end
        return model.grid:stackAt(slot), model.inventory
    end

    local strips = host.strips
    local pocketsPanel = strips ~= nil and strips.pocketsPanel or nil
    local islandGrids = pocketsPanel ~= nil and pocketsPanel.gridViews or nil
    if islandGrids ~= nil then
        for j = 1, #islandGrids do
            local stack, inventory = probe(islandGrids[j])
            if inventory ~= nil then return stack, inventory end
        end
    end
    for i = 1, count do
        local panel = panels ~= nil and panels[i] or single
        local stack, inventory = probe(panel ~= nil and panel.gridView or nil)
        if inventory ~= nil then return stack, inventory end
    end
    return nil, nil
end

Tooltip.hoveredStackOf = hoveredStack

local function equipWindowStrip(pane)
    local page = pane ~= nil and pane.parent or nil
    if page == nil or page.onCharacter ~= true then return nil end
    local EquipWindow = ComfyGrid.UI and ComfyGrid.UI.EquipWindow
    if EquipWindow == nil or EquipWindow.windowFor == nil then return nil end
    local win = EquipWindow.windowFor(page.player)
    if win == nil or not win:getIsVisible() then return nil end
    return win.content
end

function Tooltip.isOverBoard(pane)
    if pane == nil then return false end

    if overContainerWindow(pane) then
        local gv = containerWindowGrid(pane)
        if gv ~= nil and gv.isMouseOver ~= nil and gv:isMouseOver() then
            return true
        end
    end
    local host = pane.comfyHost
    if host == nil or not host.panelShown then return false end
    local panels = host.panels
    local single = panels == nil and host.containerPanel or nil
    local count = panels ~= nil and #panels or (single ~= nil and 1 or 0)
    local function over(el)
        return el ~= nil and el.isMouseOver ~= nil and el:isMouseOver() == true
    end
    if over(equipWindowStrip(pane)) then return true end
    local strips = host.strips
    if strips ~= nil then
        if over(strips.equipStrip) or over(strips.hotbarStrip) then
            return true
        end
        local pocketsPanel = strips.pocketsPanel
        local islandGrids = pocketsPanel ~= nil and pocketsPanel.gridViews or nil
        if islandGrids ~= nil then
            for j = 1, #islandGrids do
                if over(islandGrids[j]) then return true end
            end
        end
    end
    for i = 1, count do
        local panel = panels ~= nil and panels[i] or single
        if panel ~= nil and over(panel.gridView) then return true end
    end
    return false
end

local function stackWeight(pane, stack, inventory)
    if stack.count == nil or stack.count < 2 then return 0.0 end
    if pane.comfyTooltipWeightStack == stack
            and pane.comfyTooltipWeightCount == stack.count then
        return pane.comfyTooltipWeightValue
    end
    local total = 0.0
    for id in pairs(stack.itemIDs) do
        local item = inventory:getItemWithID(id)

        if item ~= nil then

            total = total + item:getUnequippedWeight()
        end
    end
    pane.comfyTooltipWeightStack = stack
    pane.comfyTooltipWeightCount = stack.count
    pane.comfyTooltipWeightValue = total
    return total
end

local function syncPlayerTooltipPair(playerNum)
    local inventoryPage = getPlayerInventory(playerNum)
    local inventoryTooltip = inventoryPage and inventoryPage.inventoryPane
        and inventoryPage.inventoryPane.toolRender
    local lootPage = getPlayerLoot(playerNum)
    local lootTooltip = lootPage and lootPage.inventoryPane
        and lootPage.inventoryPane.toolRender
    UIManager.setPlayerInventoryTooltip(playerNum,
        inventoryTooltip and inventoryTooltip.javaObject or nil,
        lootTooltip and lootTooltip.javaObject or nil)
end

local function updateImpl(pane)

    if not pane:isReallyVisible() then
        local tr = pane.toolRender
        if tr ~= nil and tr:isVisible() then
            tr:removeFromUIManager()
            tr:setVisible(false)
        end
        return
    end

    local item = nil
    local weightOfStack = 0.0

    local padAnchorX, padAnchorY = nil, nil
    local padFocused = false

    local focus = getFocusForPlayer(pane.player)
    local padDrivesSeat = focus ~= nil
        and (focus == getPlayerInventory(pane.player)
            or focus == getPlayerLoot(pane.player))
    if pane.doController then

        padFocused = padDrivesSeat and focus == pane.inventoryPage
    end
    if padFocused and not isDragActive() then
        local PadFocus = ComfyGrid.Interact.PadFocus
        if PadFocus ~= nil and PadFocus.peek ~= nil then
            local kind, el, slot, occupant = PadFocus.peek(pane.inventoryPage)
            if occupant ~= nil then
                if kind == "grid" or kind == "pocket" then
                    local inventory = el.model ~= nil and el.model.inventory
                        or nil
                    if inventory ~= nil then
                        item = ItemStack.frontItem(occupant, inventory)
                        if item ~= nil then
                            weightOfStack = stackWeight(pane, occupant,
                                inventory)
                        end
                    end
                else
                    item = occupant
                end
                if item ~= nil then
                    local Style = ComfyGrid.UI.Style
                    local cell = Style ~= nil and Style.CELL or 45

                    local px, py
                    if el.padTileXY ~= nil then
                        px, py = el:padTileXY(slot)
                    else
                        px, py = Style.pixelForSlot(slot, el.cols or 1)
                    end
                    padAnchorX = el:getAbsoluteX() + px + cell + 6
                    padAnchorY = el:getAbsoluteY() + py - 2
                end
            end
        end
    elseif not padDrivesSeat and not isDragActive() then
        local stack, inventory = hoveredStack(pane)
        if stack ~= nil and inventory ~= nil then

            item = ItemStack.frontItem(stack, inventory)
            if item ~= nil then
                weightOfStack = stackWeight(pane, stack, inventory)
            end
        end

        if item == nil then
            local host = pane.comfyHost
            local strips = host ~= nil and host.strips or nil
            local strip = strips ~= nil and strips.equipStrip or nil
            if strip ~= nil and strip.hoveredItem ~= nil then
                item = strip:hoveredItem()
            end
            if item == nil then
                local hotbar = strips ~= nil and strips.hotbarStrip or nil
                if hotbar ~= nil and hotbar.hoveredItem ~= nil then
                    item = hotbar:hoveredItem()
                end
            end
            if item == nil then
                local zones = equipWindowStrip(pane)
                if zones ~= nil and zones.hoveredItem ~= nil then
                    item = zones:hoveredItem()
                end
            end
        end
    end

    if item ~= nil then
        local menu = getPlayerContextMenu(pane.player)
        if menu ~= nil and menu:isAnyVisible() then
            item = nil
        end
    end

    if not isDragActive() then
        local ui = ComfyGrid.UI
        local stackPopup = ui ~= nil and ui.StackPopup or nil
        local p = stackPopup ~= nil and stackPopup.current ~= nil
            and stackPopup.current() or nil
        if p == nil then
            local layersPopup = ui ~= nil and ui.LayersPopup or nil
            p = layersPopup ~= nil and layersPopup.current ~= nil
                and layersPopup.current() or nil
        end
        if p ~= nil and p.hostPane == pane then

            local PadPopup = ComfyGrid.Interact.PadPopup
            local padIdx = PadPopup ~= nil and PadPopup.cursorFor ~= nil
                and PadPopup.cursorFor(p) or nil
            if padIdx ~= nil and p.padTileItem ~= nil then
                item = p:padTileItem(padIdx)
                weightOfStack = 0.0
                if item ~= nil then
                    local Style = ComfyGrid.UI.Style
                    local cell = Style ~= nil and Style.CELL or 45
                    local px, py = Style.pixelForSlot(padIdx, p.cols or 1)
                    padAnchorX = p:getAbsoluteX() + 4 + px + cell + 6
                    padAnchorY = p:getAbsoluteY() + (p.titleH or 18) + py
                        - (p.yOffset or 0) - 2
                end
            elseif p.isMouseOver ~= nil and p:isMouseOver() then
                item = p.hoveredItem ~= nil and p:hoveredItem() or nil
                weightOfStack = 0.0
            end
        end
    end

    local toolRender = pane.toolRender
    if padAnchorX ~= nil and toolRender ~= nil
            and toolRender.anchorBottomLeft ~= nil then
        toolRender.anchorBottomLeft.x = padAnchorX
        toolRender.anchorBottomLeft.y = padAnchorY
    end

    if item ~= nil and toolRender ~= nil and item == toolRender.item
            and weightOfStack == toolRender.tooltip:getWeightOfStack()
            and toolRender:isVisible() then
        return
    end

    if item ~= nil then
        if toolRender ~= nil then

            toolRender:setItem(item)
            toolRender:setVisible(true)
            toolRender:addToUIManager()
            toolRender:bringToTop()
        else

            toolRender = ISToolTipInv:new(item)
            toolRender:initialise()
            toolRender:addToUIManager()
            toolRender:setVisible(true)
            toolRender:setOwner(pane)
            toolRender:setCharacter(getSpecificPlayer(pane.player))

            toolRender.anchorBottomLeft = { x = 0, y = 0 }
            pane.toolRender = toolRender
        end

        toolRender.followMouse = padAnchorX == nil
        toolRender.tooltip:setWeightOfStack(weightOfStack)
    elseif toolRender ~= nil then

        toolRender:removeFromUIManager()
        toolRender:setVisible(false)
    end

    syncPlayerTooltipPair(pane.player)
end

local updateFailLogged = false

function Tooltip.updateForPane(pane)
    if pane == nil then return end
    local ok, err = pcall(updateImpl, pane)
    if not ok and not updateFailLogged then
        updateFailLogged = true
        Log.error("Tooltip update failed (logged once): " .. tostring(err))
    end
end

function Tooltip.hideForPane(pane)
    if pane ~= nil and pane.toolRender ~= nil then
        pane.toolRender:setVisible(false)
    end
end
