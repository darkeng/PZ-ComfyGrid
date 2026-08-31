--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.0
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

    local function noop() end

    local og_pagePrerender = ISInventoryPage.prerender
    function ISInventoryPage:prerender()
        local pane = self.inventoryPane
        local Chrome = ComfyGrid.UI ~= nil and ComfyGrid.UI.Chrome or nil
        local WindowChrome = Chrome ~= nil and Chrome.WindowChrome or nil
        if WindowChrome ~= nil then
            if pane ~= nil and pane.mode == "comfy" then
                WindowChrome.applyTo(self)
                WindowChrome.shadow(self)
            else

                WindowChrome.restore(self)
            end
        end

        local Drag = ComfyGrid.Interact ~= nil
            and ComfyGrid.Interact.ContainerDrag or nil
        if Drag ~= nil then Drag.update(self) end

        local EquipWindow = ComfyGrid.UI ~= nil
            and ComfyGrid.UI.EquipWindow or nil
        if EquipWindow ~= nil then pcall(EquipWindow.follow, self) end

        local mute = self.inventoryPane ~= nil
            and self.inventoryPane.mode == "comfy"
        local savedText, savedRight
        if mute then
            savedText = rawget(self, "drawText")
            savedRight = rawget(self, "drawTextRight")
            self.drawText = noop
            self.drawTextRight = noop
        end
        local ok, err = pcall(og_pagePrerender, self)
        if mute then
            self.drawText = savedText
            self.drawTextRight = savedRight

            if WindowChrome ~= nil and WindowChrome.resizeGrips ~= nil then
                pcall(WindowChrome.resizeGrips, self)
            end

            if WindowChrome ~= nil and WindowChrome.resync ~= nil then
                pcall(WindowChrome.resync, self)
            end
        end
        if not ok then error(err) end
    end

    local og_pageRender = ISInventoryPage.render
    function ISInventoryPage:render()
        local pane = self.inventoryPane
        local comfy = pane ~= nil and pane.mode == "comfy"
                and not self.isCollapsed

        local savedBorder
        if comfy then
            savedBorder = rawget(self, "drawRectBorder")
            local ogBorder = self.drawRectBorder
            local height = self:getHeight()
            self.drawRectBorder = function(sel, x, y, w, h, ...)

                if x == 0 and y > 0 and w == sel:getWidth()
                        and (y + h) == height then
                    return
                end
                return ogBorder(sel, x, y, w, h, ...)
            end
        end

        if og_pageRender ~= nil then og_pageRender(self) end

        if not comfy then return end
        self.drawRectBorder = savedBorder
        local Chrome = ComfyGrid.UI ~= nil and ComfyGrid.UI.Chrome or nil
        local WindowChrome = Chrome ~= nil and Chrome.WindowChrome or nil
        if WindowChrome ~= nil and WindowChrome.seam ~= nil then
            pcall(WindowChrome.seam, self)
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

    local function overEquipWindow(page)
        if page == nil or page.onCharacter ~= true then return false end
        local W = ComfyGrid.UI ~= nil and ComfyGrid.UI.EquipWindow or nil
        if W == nil or W.isMouseOverIt == nil then return false end
        local ok, over = pcall(W.isMouseOverIt, page.player)
        return ok and over == true
    end

    local function pinnedThrough(self, original, x, y)
        if not overEquipWindow(self) then return original(self, x, y) end
        local saved = self.pin
        self.pin = true
        local ok, err = pcall(original, self, x, y)
        self.pin = saved
        if not ok then error(err) end
    end

    local og_onMouseDownOutside = ISInventoryPage.onMouseDownOutside
    function ISInventoryPage:onMouseDownOutside(x, y)
        return pinnedThrough(self, og_onMouseDownOutside, x, y)
    end

    local og_onRightMouseDownOutside = ISInventoryPage.onRightMouseDownOutside
    function ISInventoryPage:onRightMouseDownOutside(x, y)
        return pinnedThrough(self, og_onRightMouseDownOutside, x, y)
    end

    local og_onMouseMoveOutside = ISInventoryPage.onMouseMoveOutside
    function ISInventoryPage:onMouseMoveOutside(dx, dy)
        return pinnedThrough(self, og_onMouseMoveOutside, dx, dy)
    end

    Log.info("InventoryPagePatch applied")
end)
