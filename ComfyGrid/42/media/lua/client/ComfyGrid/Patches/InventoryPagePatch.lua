--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
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

local function chromeModule(name)
    local Chrome = ComfyGrid.UI ~= nil and ComfyGrid.UI.Chrome or nil
    return Chrome ~= nil and Chrome[name] or nil
end

local function noop() end

local function mirroredPlateRect(page, x, y, w, h, ...)
    local buttonSize = page._comfyPlateBs
    if w == buttonSize and x == page:getWidth() - buttonSize then x = 0 end
    return page._comfyPlateOg(page, x, y, w, h, ...)
end

local function footerlessBorder(page, x, y, w, h, ...)

    if x == 0 and y > 0 and w == page:getWidth()
            and (y + h) == page._comfyBorderH then
        return
    end
    local buttonSize = page._comfyBorderBs
    if buttonSize ~= nil and w == buttonSize
            and x == page:getWidth() - buttonSize then
        x = 0
    end
    return page._comfyBorderOg(page, x, y, w, h, ...)
end

local function syncChromeBeforeOriginal(page, WindowChrome)
    if WindowChrome == nil then return end
    local pane = page.inventoryPane
    if pane ~= nil and pane.mode == "comfy" then
        WindowChrome.applyTo(page)
        WindowChrome.shadow(page)
    else

        WindowChrome.restore(page)
    end

    if WindowChrome.buttonSizeFor ~= nil
            and (page.buttonSize ~= WindowChrome.buttonSizeFor(page)
            or page._comfyButtonsComfy ~= (pane ~= nil and pane.mode == "comfy")) then
        pcall(WindowChrome.fitButtons, page)
    end
end

local function runFrameHeartbeats(page)

    local Drag = ComfyGrid.Interact ~= nil
        and ComfyGrid.Interact.ContainerDrag or nil
    if Drag ~= nil then Drag.update(page) end

    local EquipWindow = ComfyGrid.UI ~= nil
        and ComfyGrid.UI.EquipWindow or nil
    if EquipWindow ~= nil then pcall(EquipWindow.follow, page) end

    local ZOrder = chromeModule("ZOrder")
    if ZOrder ~= nil and ZOrder.enforce ~= nil then
        pcall(ZOrder.enforce, page.player)
    end
end

local function runOriginalPrerender(page, original, WindowChrome)

    local mute = page.inventoryPane ~= nil
        and page.inventoryPane.mode == "comfy"
    local savedText, savedRight
    if mute then
        savedText = rawget(page, "drawText")
        savedRight = rawget(page, "drawTextRight")
        page.drawText = noop
        page.drawTextRight = noop
    end

    local mirrorPlate = mute and WindowChrome ~= nil
        and WindowChrome.onLeft ~= nil and WindowChrome.onLeft(page)
        and page.buttonSize ~= nil
    local savedRect
    if mirrorPlate then
        savedRect = rawget(page, "drawRect")
        page._comfyPlateOg = page.drawRect
        page._comfyPlateBs = page.buttonSize
        page.drawRect = mirroredPlateRect
    end
    local ok, err = pcall(original, page)
    if mirrorPlate then page.drawRect = savedRect end
    if mute then
        page.drawText = savedText
        page.drawTextRight = savedRight
    end
    return ok, err, mute
end

local function syncChromeAfterOriginal(page, WindowChrome, mute)
    if mute then

        if WindowChrome ~= nil and WindowChrome.resizeGrips ~= nil then
            pcall(WindowChrome.resizeGrips, page)
        end

        if WindowChrome ~= nil and WindowChrome.resync ~= nil then
            pcall(WindowChrome.resync, page)
        end
    end

    if WindowChrome ~= nil and WindowChrome.side ~= nil then
        pcall(WindowChrome.side, page)
    end
end

Events.OnGameBoot.Add(function()

    if ISInventoryPage._comfyPatched then return end
    ISInventoryPage._comfyPatched = true

    local og_containerSizeChanged = ISInventoryPage.onInventoryContainerSizeChanged
    function ISInventoryPage:onInventoryContainerSizeChanged()
        og_containerSizeChanged(self)
        local WindowChrome = chromeModule("WindowChrome")

        if WindowChrome ~= nil and WindowChrome.fitButtons ~= nil then
            local ok, err = pcall(WindowChrome.fitButtons, self)
            if not ok then
                Log.warn("InventoryPagePatch: fitButtons failed: " .. tostring(err))
            end
        end
    end

    local og_addContainerButton = ISInventoryPage.addContainerButton
    function ISInventoryPage:addContainerButton(...)
        local button = og_addContainerButton(self, ...)
        local WindowChrome = chromeModule("WindowChrome")
        if button ~= nil and WindowChrome ~= nil
                and WindowChrome.fitButton ~= nil then
            pcall(WindowChrome.fitButton, self, button)
        end
        return button
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
        local WindowChrome = chromeModule("WindowChrome")
        syncChromeBeforeOriginal(self, WindowChrome)
        runFrameHeartbeats(self)
        local ok, err, mute = runOriginalPrerender(self, og_pagePrerender,
            WindowChrome)
        syncChromeAfterOriginal(self, WindowChrome, mute)
        if not ok then error(err) end
    end

    local og_pageRender = ISInventoryPage.render
    function ISInventoryPage:render()
        local pane = self.inventoryPane
        local comfy = pane ~= nil and pane.mode == "comfy"
                and not self.isCollapsed

        local savedBorder
        local WindowChrome = nil
        if comfy then
            savedBorder = rawget(self, "drawRectBorder")
            local ogBorder = self.drawRectBorder
            local height = self:getHeight()

            WindowChrome = chromeModule("WindowChrome")
            local buttonSize = nil
            if WindowChrome ~= nil and WindowChrome.onLeft ~= nil
                    and WindowChrome.onLeft(self) then
                buttonSize = self.buttonSize
            end
            self._comfyBorderOg = ogBorder
            self._comfyBorderH = height
            self._comfyBorderBs = buttonSize
            self.drawRectBorder = footerlessBorder
        end

        if og_pageRender ~= nil then og_pageRender(self) end

        if not comfy then return end
        self.drawRectBorder = savedBorder
        if WindowChrome ~= nil and WindowChrome.seam ~= nil then
            pcall(WindowChrome.seam, self)
        end

        if WindowChrome ~= nil and WindowChrome.selection ~= nil then
            pcall(WindowChrome.selection, self)
        end

        if WindowChrome ~= nil and WindowChrome.searchMarks ~= nil then
            pcall(WindowChrome.searchMarks, self)
        end
    end

    local og_pageSetVisible = ISInventoryPage.setVisible
    function ISInventoryPage:setVisible(visible, ...)
        if not visible and self.javaObject ~= nil and self:getIsVisible() then
            local SearchField = chromeModule("SearchField")
            if SearchField ~= nil and SearchField.onPageClosed ~= nil then
                pcall(SearchField.onPageClosed, self)
            end
        end
        return og_pageSetVisible(self, visible, ...)
    end

    local function padModule(page, name)
        local pane = page.inventoryPane
        if pane == nil or pane.mode ~= "comfy" then return nil end
        local Interact = ComfyGrid.Interact
        return Interact ~= nil and Interact[name] or nil
    end

    local function seqOf(page)
        local ContainerOrder = ComfyGrid.Model
            and ComfyGrid.Model.ContainerOrder
        if ContainerOrder == nil or ContainerOrder.sequenceFor == nil then
            return nil
        end
        local ok, sequence = pcall(ContainerOrder.sequenceFor, page)
        if not ok or type(sequence) ~= "table" or #sequence < 2 then
            return nil
        end
        return sequence
    end

    local function stepInVisualOrder(page, index, wrap, dir)
        local visualSequence = seqOf(page)
        if visualSequence == nil then return nil end
        local backpackButtons = page.backpacks

        local at = nil
        if index ~= nil and index >= 1 and backpackButtons[index] ~= nil then
            for i = 1, #visualSequence do
                if visualSequence[i] == backpackButtons[index] then
                    at = i
                    break
                end
            end
        end

        if at == nil then
            if not wrap then return -1 end
            at = (dir > 0) and 0 or (#visualSequence + 1)
            wrap = false
        end
        local playerObj = getSpecificPlayer(page.player)
        local sequenceLength = #visualSequence
        for hop = 1, sequenceLength do
            local i = at + dir * hop
            if i < 1 or i > sequenceLength then
                if not wrap then return -1 end

                if i < 1 then
                    i = i + sequenceLength
                else
                    i = i - sequenceLength
                end
            end
            local button = visualSequence[i]
            local object = button ~= nil and button.inventory ~= nil
                and button.inventory:getParent() or nil
            if button ~= nil and not (instanceof(object, "IsoThumpable")
                    and object:isLockedToCharacter(playerObj)) then
                for arrayIndex = 1, #backpackButtons do
                    if backpackButtons[arrayIndex] == button then
                        return arrayIndex
                    end
                end
            end
        end
        return -1
    end

    local og_nextUnlocked = ISInventoryPage.nextUnlockedContainer
    function ISInventoryPage:nextUnlockedContainer(index, wrap)
        local nextIndex = stepInVisualOrder(self, index, wrap, 1)
        if nextIndex ~= nil then return nextIndex end
        return og_nextUnlocked(self, index, wrap)
    end

    local og_prevUnlocked = ISInventoryPage.prevUnlockedContainer
    function ISInventoryPage:prevUnlockedContainer(index, wrap)
        local prevIndex = stepInVisualOrder(self, index, wrap, -1)
        if prevIndex ~= nil then return prevIndex end
        return og_prevUnlocked(self, index, wrap)
    end

    local og_pageWheel = ISInventoryPage.onMouseWheel
    function ISInventoryPage:onMouseWheel(wheelDelta)
        local pane = self.inventoryPane
        local WindowChrome = chromeModule("WindowChrome")
        local buttonSize = self.buttonSize
        local mirror = pane ~= nil and pane.mode == "comfy"
            and buttonSize ~= nil
            and WindowChrome ~= nil and WindowChrome.onLeft ~= nil
            and WindowChrome.onLeft(self)
        if not mirror then return og_pageWheel(self, wheelDelta) end
        local overColumn = self:getMouseX() < buttonSize
        local saved = rawget(self, "getMouseX")
        self.getMouseX = function(page)

            if overColumn then return page:getWidth() end
            return 0
        end
        local ok, result = pcall(og_pageWheel, self, wheelDelta)
        self.getMouseX = saved
        if not ok then error(result) end
        return result
    end

    local function raiseHintBar(page)
        local okPromptBar, promptBar = pcall(getButtonPrompts, page.player)
        if okPromptBar and promptBar ~= nil and promptBar.bringToTop ~= nil then
            promptBar:bringToTop()
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

    local function wrapJoypadDir(methodName, dx, dy)
        local og_onJoypadDir = ISInventoryPage[methodName]
        ISInventoryPage[methodName] = function(self, joypadData)
            local Pad = padModule(self, "PadFocus")
            if Pad ~= nil then raiseHintBar(self) end
            if Pad ~= nil and Pad.onDir(self, dx, dy) then return end
            return og_onJoypadDir(self, joypadData)
        end
    end
    wrapJoypadDir("onJoypadDirUp", 0, -1)
    wrapJoypadDir("onJoypadDirDown", 0, 1)
    wrapJoypadDir("onJoypadDirLeft", -1, 0)
    wrapJoypadDir("onJoypadDirRight", 1, 0)

    local function mouseOverWindow(moduleName, page)
        if page == nil then return false end
        local Window = ComfyGrid.UI ~= nil and ComfyGrid.UI[moduleName] or nil
        if Window == nil or Window.isMouseOverIt == nil then return false end
        local ok, over = pcall(Window.isMouseOverIt, page.player)
        return ok and over == true
    end

    local function overEquipWindow(page)
        if page == nil or page.onCharacter ~= true then return false end
        return mouseOverWindow("EquipWindow", page)
    end

    local function overContainerWindow(page)
        return mouseOverWindow("ContainerWindow", page)
    end

    local function overAnyComfyWindow(page)
        return overEquipWindow(page) or overContainerWindow(page)
    end

    local function bandInProgress()
        local GridView = ComfyGrid.UI ~= nil and ComfyGrid.UI.GridView or nil
        if GridView == nil or GridView.bandIsLive == nil then return false end
        local ok, live = pcall(GridView.bandIsLive)
        return ok and live == true
    end

    local function pinnedThrough(self, original, x, y)
        if not (overAnyComfyWindow(self) or bandInProgress()) then
            return original(self, x, y)
        end
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
