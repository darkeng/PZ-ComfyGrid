--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.0.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Patches = ComfyGrid.Patches or {}
local InventoryPagePatch = {}
ComfyGrid.Patches.InventoryPagePatch = InventoryPagePatch

local Log = ComfyGrid.Core.Log

Events.OnGameBoot.Add(function()

    if ISInventoryPage._comfyPatched then return end
    ISInventoryPage._comfyPatched = true

    local og_createChildren = ISInventoryPage.createChildren
    function ISInventoryPage:createChildren()
        og_createChildren(self)

    end

    local og_refreshBackpacks = ISInventoryPage.refreshBackpacks
    function ISInventoryPage:refreshBackpacks()
        local pane = self.inventoryPane
        local prevInv = pane ~= nil and pane.inventory or nil
        local prevCount = self.backpacks ~= nil and #self.backpacks or 0
        og_refreshBackpacks(self)
        if self.onCharacter or prevCount ~= 1 or prevInv == nil then return end
        pane = self.inventoryPane
        if pane == nil or pane.inventory == prevInv then return end
        local newInv = pane.inventory
        local okCI, containingItem = pcall(newInv.getContainingItem, newInv)
        if not okCI or containingItem == nil then return end

        for i = 1, #self.backpacks do
            if self.backpacks[i].inventory == prevInv then
                pane.inventory = prevInv
                pane.lastinventory = prevInv

                og_refreshBackpacks(self)
                return
            end
        end
    end

    Log.info("InventoryPagePatch applied")
end)
