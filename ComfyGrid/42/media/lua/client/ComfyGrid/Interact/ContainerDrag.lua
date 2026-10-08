--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Model/ContainerOrder"
require "ComfyGrid/Settings"
require "ComfyGrid/Interact/DragAndDrop"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local ContainerDrag = {}
ComfyGrid.Interact.ContainerDrag = ContainerDrag

local Log = ComfyGrid.Core.Log
local ContainerOrder = ComfyGrid.Model.ContainerOrder

local THRESHOLD = ComfyGrid.Interact.DragAndDrop.DRAG_THRESHOLD_PX

local reorderGesture = nil

local suppressClick = false

local function comfyPlayerPage(page)
    if page == nil or page.onCharacter ~= true then return false end
    local pane = page.inventoryPane
    if pane == nil or pane.mode ~= "comfy" then return false end
    return type(page.backpacks) == "table" and #page.backpacks > 1
end

local function movable(container, playerNum)
    if container == nil then return false end
    return not ContainerOrder.isPinned(container, getSpecificPlayer(playerNum),
        playerNum)
end

function ContainerDrag.arm(page, button)
    reorderGesture = nil

    suppressClick = false
    if not comfyPlayerPage(page) then return end

    if ISMouseDrag ~= nil and ISMouseDrag.dragging ~= nil then return end
    local container = button ~= nil and button.inventory or nil
    if container == nil or not movable(container, page.player) then return end
    local index = ContainerOrder.indexOf(page, container)
    if index == nil then return end
    reorderGesture = {
        page = page,
        container = container,
        anchor = index,
        startY = getMouseY(),
        active = false,
    }
end

local function isActive()
    return reorderGesture ~= nil and reorderGesture.active == true
end

function ContainerDrag.consumeClick()
    if suppressClick then
        suppressClick = false
        return true
    end
    return isActive()
end

function ContainerDrag.update(page)
    local gesture = reorderGesture
    if gesture == nil or gesture.page ~= page then return end

    if not comfyPlayerPage(page) then
        reorderGesture = nil
        return
    end

    local buttonHeld = isMouseButtonDown ~= nil and isMouseButtonDown(0) or false
    local index = ContainerOrder.indexOf(page, gesture.container)
    if index == nil then

        reorderGesture = nil
        return
    end

    if not buttonHeld then
        if gesture.active then
            suppressClick = true

            local ok, err = pcall(ContainerOrder.commit, page)
            if not ok then
                Log.warn("ContainerDrag: commit failed: " .. tostring(err))
                ContainerOrder.apply(page)
            end
        end
        reorderGesture = nil
        return
    end

    local size = page.buttonSize or 0
    if size <= 0 then return end
    local dy = getMouseY() - gesture.startY
    if not gesture.active then
        if dy > -THRESHOLD and dy < THRESHOLD then return end
        gesture.active = true
    end

    index = ContainerOrder.preview(page, gesture.container,
        gesture.anchor + math.floor(dy / size + 0.5)) or index
    ContainerOrder.layout(page, index, ((gesture.anchor - 1) * size) - 1 + dy)
end

Events.OnGameBoot.Add(function()
    if ISInventoryPage == nil then
        Log.warn("ContainerDrag: no ISInventoryPage, skipped")
        return
    end
    if ISInventoryPage._comfyDragPatched then return end
    ISInventoryPage._comfyDragPatched = true

    local og_down = ISInventoryPage.onBackpackMouseDown

    function ISInventoryPage:onBackpackMouseDown(button, x, y)

        local ok, err = pcall(ContainerDrag.arm, self, button)
        if not ok then
            Log.warn("ContainerDrag: arm failed: " .. tostring(err))
        end
        return og_down(self, button, x, y)
    end

    local og_up = ISInventoryPage.onBackpackMouseUp

    function ISInventoryPage:onBackpackMouseUp(x, y)
        if ContainerDrag.consumeClick() then
            self.pressed = false
            return
        end
        return og_up(self, x, y)
    end

    Log.info("ContainerDrag ready")
end)
