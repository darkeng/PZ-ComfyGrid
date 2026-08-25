--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.7
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/UI/PaneHost"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Patches = ComfyGrid.Patches or {}
local InventoryPanePatch = {}
ComfyGrid.Patches.InventoryPanePatch = InventoryPanePatch

local Log = ComfyGrid.Core.Log
local ContainerModel = ComfyGrid.Model.ContainerModel

local function hideListChrome(pane)
    if pane.nameHeader then pane.nameHeader:setVisible(false) end
    if pane.typeHeader then pane.typeHeader:setVisible(false) end
    if pane.expandAll then pane.expandAll:setVisible(false) end
    if pane.collapseAll then pane.collapseAll:setVisible(false) end
    if pane.filterMenu then pane.filterMenu:setVisible(false) end
end

local function bumpRefreshCounter(pane)
    local model = ContainerModel.getOrCreate(pane.inventory, pane.player)
    if not model then return end
    local stamp = model.grid.changeCount
    if stamp ~= pane.comfyChangeStamp then
        pane.comfyChangeStamp = stamp
        local count = (pane.refreshContainerCount or 0) + 1
        if count > 10000 then count = 0 end
        pane.refreshContainerCount = count
    end
end

local refreshCounterFailLogged = false

Events.OnGameBoot.Add(function()

    if ISInventoryPane._comfyPatched then return end

    local PaneHost = ComfyGrid.UI and ComfyGrid.UI.PaneHost
    if not PaneHost then
        Log.error("InventoryPanePatch: ComfyGrid.UI.PaneHost missing; vanilla inventory pane left untouched")
        return
    end
    ISInventoryPane._comfyPatched = true

    local function mountHost(pane)
        local host = PaneHost:new(pane)
        host:initialise()
        pane:addChild(host)
        pane.comfyHost = host
        pane.comfyHostShown = true
    end

    local function setHostShown(pane, shown)
        local host = pane.comfyHost
        if host and pane.comfyHostShown ~= shown then
            pane.comfyHostShown = shown
            host:setVisible(shown)
        end
    end

    local og_createChildren = ISInventoryPane.createChildren
    function ISInventoryPane:createChildren()
        og_createChildren(self)
        local ok, err = pcall(mountHost, self)
        if ok then
            hideListChrome(self)

            self.mode = "comfy"
        else
            Log.error("InventoryPanePatch: PaneHost mount failed, pane stays vanilla: " .. tostring(err))
        end
    end

    local og_prerender = ISInventoryPane.prerender
    function ISInventoryPane:prerender()
        if self.mode ~= "comfy" then

            setHostShown(self, false)
            return og_prerender(self)
        end
        setHostShown(self, true)

        if self.items ~= nil then
            table.wipe(self.items)
        end

        if self.inventory ~= self.lastinventory then
            self.lastinventory = self.inventory
        end

        local ok, err = pcall(bumpRefreshCounter, self)
        if not ok and not refreshCounterFailLogged then
            refreshCounterFailLogged = true
            Log.error("InventoryPanePatch: refresh bookkeeping failed (logged once): " .. tostring(err))
        end

        hideListChrome(self)
    end

    local og_render = ISInventoryPane.render
    function ISInventoryPane:render()
        if self.mode ~= "comfy" then return og_render(self) end

    end

    local og_updateTooltip = ISInventoryPane.updateTooltip
    function ISInventoryPane:updateTooltip()
        if self.mode ~= "comfy" then return og_updateTooltip(self) end

        local Tooltip = ComfyGrid.Interact and ComfyGrid.Interact.Tooltip
        if Tooltip then Tooltip.updateForPane(self) end
    end

    local og_onMouseDown = ISInventoryPane.onMouseDown
    function ISInventoryPane:onMouseDown(x, y)
        if self.mode ~= "comfy" then return og_onMouseDown(self, x, y) end
        return true
    end

    local og_onMouseUp = ISInventoryPane.onMouseUp
    function ISInventoryPane:onMouseUp(x, y)
        if self.mode ~= "comfy" then return og_onMouseUp(self, x, y) end
        return true
    end

    local og_onMouseDoubleClick = ISInventoryPane.onMouseDoubleClick
    function ISInventoryPane:onMouseDoubleClick(x, y)
        if self.mode ~= "comfy" then return og_onMouseDoubleClick(self, x, y) end

        return true
    end

    local og_onRightMouseDown = ISInventoryPane.onRightMouseDown
    function ISInventoryPane:onRightMouseDown(x, y)
        if self.mode ~= "comfy" then
            if og_onRightMouseDown then return og_onRightMouseDown(self, x, y) end
            return
        end
        return false
    end

    local og_onRightMouseUp = ISInventoryPane.onRightMouseUp
    function ISInventoryPane:onRightMouseUp(x, y)
        if self.mode ~= "comfy" then return og_onRightMouseUp(self, x, y) end
        return false
    end

    Log.info("InventoryPanePatch applied (ISInventoryPane grid mode active)")
end)
