--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.2.1
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

    local function padModule(page, name)
        local pane = page.inventoryPane
        if pane == nil or pane.mode ~= "comfy" then return nil end
        local Interact = ComfyGrid.Interact
        return Interact ~= nil and Interact[name] or nil
    end

    local function raiseHintBar(page)
        local okBp, bp = pcall(getButtonPrompts, page.player)
        if okBp and bp ~= nil and bp.bringToTop ~= nil then
            bp:bringToTop()
        end
    end

    local og_onGainJoypadFocus = ISInventoryPage.onGainJoypadFocus
    function ISInventoryPage:onGainJoypadFocus(joypadData)
        og_onGainJoypadFocus(self, joypadData)
        local Pad = padModule(self, "PadFocus")
        if Pad then Pad.onGain(self, joypadData) end

        if padModule(self, "PadInput") ~= nil then
            self.overrideBPrompt = true
            raiseHintBar(self)
        end
    end

    local og_onLoseJoypadFocus = ISInventoryPage.onLoseJoypadFocus
    function ISInventoryPage:onLoseJoypadFocus(joypadData)
        og_onLoseJoypadFocus(self, joypadData)
        local Pad = padModule(self, "PadFocus")
        if Pad then Pad.onLose(self) end
        self.overrideBPrompt = nil
    end

    function ISInventoryPage:isValidPrompt()
        return padModule(self, "PadInput") ~= nil
    end

    local function promptGetter(slotKey)
        return function(page)
            local Input = padModule(page, "PadInput")
            if Input == nil or Input.promptFor == nil then return nil end
            return Input.promptFor(page, slotKey)
        end
    end
    ISInventoryPage.getAPrompt = promptGetter("A")
    ISInventoryPage.getBPrompt = promptGetter("B")
    ISInventoryPage.getXPrompt = promptGetter("X")
    ISInventoryPage.getYPrompt = promptGetter("Y")
    ISInventoryPage.getLBPrompt = promptGetter("LB")
    ISInventoryPage.getRBPrompt = promptGetter("RB")

    local og_onJoypadDown = ISInventoryPage.onJoypadDown
    function ISInventoryPage:onJoypadDown(button, joypadData)
        local Input = padModule(self, "PadInput")
        if Input ~= nil then raiseHintBar(self) end
        if Input ~= nil and Input.onButton(self, button) then return end
        return og_onJoypadDown(self, button, joypadData)
    end

    local og_onJoypadDirUp = ISInventoryPage.onJoypadDirUp
    function ISInventoryPage:onJoypadDirUp(joypadData)
        local Pad = padModule(self, "PadFocus")
        if Pad ~= nil then raiseHintBar(self) end
        if Pad ~= nil and Pad.onDir(self, 0, -1) then return end
        return og_onJoypadDirUp(self, joypadData)
    end

    local og_onJoypadDirDown = ISInventoryPage.onJoypadDirDown
    function ISInventoryPage:onJoypadDirDown(joypadData)
        local Pad = padModule(self, "PadFocus")
        if Pad ~= nil then raiseHintBar(self) end
        if Pad ~= nil and Pad.onDir(self, 0, 1) then return end
        return og_onJoypadDirDown(self, joypadData)
    end

    local og_onJoypadDirLeft = ISInventoryPage.onJoypadDirLeft
    function ISInventoryPage:onJoypadDirLeft(joypadData)
        local Pad = padModule(self, "PadFocus")
        if Pad ~= nil then raiseHintBar(self) end
        if Pad ~= nil and Pad.onDir(self, -1, 0) then return end
        return og_onJoypadDirLeft(self, joypadData)
    end

    local og_onJoypadDirRight = ISInventoryPage.onJoypadDirRight
    function ISInventoryPage:onJoypadDirRight(joypadData)
        local Pad = padModule(self, "PadFocus")
        if Pad ~= nil then raiseHintBar(self) end
        if Pad ~= nil and Pad.onDir(self, 1, 0) then return end
        return og_onJoypadDirRight(self, joypadData)
    end

    Log.info("InventoryPagePatch applied")
end)
