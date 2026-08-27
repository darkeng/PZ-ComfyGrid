--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.9
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

                if self.backpackChoice ~= nil then
                    self.backpackChoice = i
                end

                og_refreshBackpacks(self)
                return
            end
        end
    end

    local og_pagePrerender = ISInventoryPage.prerender
    function ISInventoryPage:prerender()
        local pane = self.inventoryPane
        if pane ~= nil and pane.mode == "comfy" then
            local UI = ComfyGrid.UI
            local Draw = UI ~= nil and UI.Draw or nil
            local colors = UI ~= nil and UI.Style ~= nil
                and UI.Style.COLORS or nil
            local sf = colors ~= nil and colors.SURFACE or nil
            if Draw ~= nil and sf ~= nil then
                if not self._comfyChrome then
                    self._comfyChrome = true
                    local ba = self.backgroundColor
                        and self.backgroundColor.a or 0.8
                    local bo = self.borderColor and self.borderColor.a or 0.85
                    self.backgroundColor =
                        { r = sf.bg.r, g = sf.bg.g, b = sf.bg.b, a = ba }
                    self.borderColor =
                        { r = sf.line.r, g = sf.line.g, b = sf.line.b, a = bo }
                end
                if not self.isCollapsed then
                    Draw.shadow(self, 0, 0, self.width, self.height, 12, 0.45)
                end
            end
        end
        og_pagePrerender(self)
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
