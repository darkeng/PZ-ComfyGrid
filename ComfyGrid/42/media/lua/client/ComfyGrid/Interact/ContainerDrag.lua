--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.6.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Model/ContainerOrder"
require "ComfyGrid/Settings"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local ContainerDrag = {}
ComfyGrid.Interact.ContainerDrag = ContainerDrag

local Log = ComfyGrid.Core.Log
local Order = ComfyGrid.Model.ContainerOrder

local THRESHOLD = 8

local drag = nil

local suppressClick = false

local function comfyPlayerPage(page)
    if page == nil or page.onCharacter ~= true then return false end
    local pane = page.inventoryPane
    if pane == nil or pane.mode ~= "comfy" then return false end
    return type(page.backpacks) == "table" and #page.backpacks > 1
end

local function movable(inv, playerNum)
    if inv == nil then return false end
    return not Order.isPinned(inv, getSpecificPlayer(playerNum), playerNum)
end

function ContainerDrag.arm(page, button)
    drag = nil

    suppressClick = false
    if not comfyPlayerPage(page) then return end

    if ISMouseDrag ~= nil and ISMouseDrag.dragging ~= nil then return end
    local inv = button ~= nil and button.inventory or nil
    if inv == nil or not movable(inv, page.player) then return end
    local at = Order.indexOf(page, inv)
    if at == nil then return end
    drag = {
        page = page,
        inv = inv,
        anchor = at,
        startY = getMouseY(),
        active = false,
    }
end

function ContainerDrag.isActive()
    return drag ~= nil and drag.active == true
end

function ContainerDrag.consumeClick()
    if suppressClick then
        suppressClick = false
        return true
    end
    return ContainerDrag.isActive()
end

local function commit(page)
    Order.commit(page)
end

function ContainerDrag.update(page)
    if drag == nil or drag.page ~= page then return end

    if not comfyPlayerPage(page) then
        drag = nil
        return
    end

    local down = isMouseButtonDown ~= nil and isMouseButtonDown(0) or false
    local at = Order.indexOf(page, drag.inv)
    if at == nil then

        drag = nil
        return
    end

    if not down then
        if drag.active then
            suppressClick = true
            local ok, err = pcall(commit, page)
            if not ok then
                Log.warn("ContainerDrag: commit failed: " .. tostring(err))
                Order.apply(page)
            end
        end
        drag = nil
        return
    end

    local size = page.buttonSize or 0
    if size <= 0 then return end
    local dy = getMouseY() - drag.startY
    if not drag.active then
        if dy > -THRESHOLD and dy < THRESHOLD then return end
        drag.active = true
    end

    at = Order.preview(page, drag.inv,
        drag.anchor + math.floor(dy / size + 0.5)) or at
    Order.layout(page, at, ((drag.anchor - 1) * size) - 1 + dy)
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
