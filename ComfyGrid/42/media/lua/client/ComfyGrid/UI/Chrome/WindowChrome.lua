--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Settings"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
require "ComfyGrid/UI/Chrome/WindowStrip"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local WindowChrome = {}
ComfyGrid.UI.Chrome.WindowChrome = WindowChrome

local Log = ComfyGrid.Core.Log
local Style = ComfyGrid.UI.Style
local WindowStrip = ComfyGrid.UI.Chrome.WindowStrip
local Draw = ComfyGrid.UI.Draw

local SHADOW_SPREAD = 12
local SHADOW_ALPHA = 0.45

WindowChrome.SHADOW_ALPHA = SHADOW_ALPHA

function WindowChrome.shadowSpread()
    return math.max(6, math.floor(SHADOW_SPREAD * (Style.SCALE or 1)))
end

local function abutsSibling(page)
    local ok, data = pcall(getPlayerData, page.player)
    if not ok or data == nil then return false end
    local other = page.onCharacter and data.lootInventory or data.playerInventory
    if other == nil or other == page then return false end
    local otherVisible = other.getIsVisible ~= nil and other:getIsVisible()
        or other.visible == true
    if not otherVisible then return false end

    local ax, aw = page:getX(), page:getWidth()
    local bx, bw = other:getX(), other:getWidth()
    local ay, ah = page:getY(), page:getHeight()
    local by, bh = other:getY(), other:getHeight()
    if ay + ah <= by or by + bh <= ay then return false end
    local gapRight = bx - (ax + aw)
    local gapLeft = ax - (bx + bw)
    return (gapRight >= -2 and gapRight <= 2)
        or (gapLeft >= -2 and gapLeft <= 2)
end

function WindowChrome.shadow(page)
    if page.isCollapsed then return end
    if Draw == nil or Draw.shadow == nil then return end
    if abutsSibling(page) then return end
    Draw.shadow(page, 0, 0, page.width, page.height, WindowChrome.shadowSpread(),
        SHADOW_ALPHA)
end

function WindowChrome.resizeGrips(page)
    local cornerWidget = page.resizeWidget
    if cornerWidget == nil or cornerWidget.height == nil
            or cornerWidget.height <= 0 then
        return
    end
    if page.width == nil or page.height == nil then return end
    local gripSize = cornerWidget.height
    local x, y = page.width - gripSize, page.height - gripSize

    if not cornerWidget.resizing then
        if cornerWidget.x ~= x then cornerWidget:setX(x) end
        if cornerWidget.y ~= y then cornerWidget:setY(y) end
    end

    local edgeWidget = page.resizeWidget2
    if edgeWidget == nil or edgeWidget.resizing then return end
    if edgeWidget.y ~= y then edgeWidget:setY(y) end
    if edgeWidget.width ~= x then edgeWidget:setWidth(x) end
end

function WindowChrome.resync(page)
    local pane = page.inventoryPane
    if pane == nil or page.width == nil then return end
    local buttonSize = page.buttonSize
    if buttonSize == nil or page.onInventoryContainerSizeChanged == nil then
        return
    end
    if pane.width == page.width - buttonSize then return end
    pcall(page.onInventoryContainerSizeChanged, page)
end

function WindowChrome.onLeft(page)
    local Settings = ComfyGrid.Settings
    if Settings == nil or Settings.get == nil then return false end
    local key = "CONTAINERS_LEFT_PLAYER"
    if page ~= nil and page.onCharacter == false then
        key = "CONTAINERS_LEFT_LOOT"
    end
    return Settings.get(key) == true
end

function WindowChrome.side(page)
    local panel = page.containerButtonPanel
    local pane = page.inventoryPane
    if panel == nil or pane == nil or page.width == nil then return end
    local buttonSize = page.buttonSize
    if buttonSize == nil or buttonSize <= 0 then return end
    local left = pane.mode == "comfy" and WindowChrome.onLeft(page)
    local panelX, paneX = page.width - buttonSize, 0
    if left then panelX, paneX = 0, buttonSize end
    if panel.x ~= panelX then panel:setX(panelX) end
    if pane.x ~= paneX then pane:setX(paneX) end

end

local VANILLA_BUTTON_SIZES = { 32, 40, 48 }

local MIN_BUTTON = 20

local function vanillaButtonSize()
    local core = getCore()
    local opt = core ~= nil and core:getOptionInventoryContainerSize() or 2
    return VANILLA_BUTTON_SIZES[opt] or 40
end

function WindowChrome.buttonSizeFor(page)
    local base = vanillaButtonSize()
    local pane = page ~= nil and page.inventoryPane or nil
    if pane == nil or pane.mode ~= "comfy" then return base end
    local buttonSize = math.floor(base * (Style.SCALE or 1) + 0.5)
    if buttonSize < MIN_BUTTON then buttonSize = MIN_BUTTON end
    return buttonSize
end

local function iconFor(buttonSize)
    local base = vanillaButtonSize()
    local vIcon = base - 2
    if vIcon > 32 then vIcon = 32 end
    local icon = math.floor(buttonSize * vIcon / base + 0.5)
    if icon > buttonSize - 2 then icon = buttonSize - 2 end
    if icon < 1 then icon = 1 end
    return icon
end

local function fitArt(button, comfy)
    local img = button.image
    if img == nil then return end
    if comfy then
        if img == button._comfyArt then return end
        local Icons = ComfyGrid.UI ~= nil and ComfyGrid.UI.Icons or nil
        local hiResArt = Icons ~= nil and Icons.gameArt ~= nil
            and Icons.gameArt(img) or false
        if hiResArt then
            button._comfyArtVanilla = img
            button._comfyArt = hiResArt
            button:setImage(hiResArt)
        end
        return
    end

    if img == button._comfyArt and button._comfyArtVanilla ~= nil then
        button:setImage(button._comfyArtVanilla)
    end
    button._comfyArt = nil
    button._comfyArtVanilla = nil
end

local function fitOneButton(button, buttonSize, iconSize, comfy)
    if button == nil or button.setWidth == nil then return end
    fitArt(button, comfy)
    if button.anchorRight ~= false then button:setAnchorRight(false) end
    if button.anchorLeft ~= true then button:setAnchorLeft(true) end
    if button:getX() ~= 0 then button:setX(0) end
    if button:getWidth() ~= buttonSize then button:setWidth(buttonSize) end
    if button:getHeight() ~= buttonSize then button:setHeight(buttonSize) end
    if button.forcedWidthImage ~= iconSize
            or button.forcedHeightImage ~= iconSize then
        button:forceImageSize(iconSize, iconSize)
    end
end

function WindowChrome.fitButton(page, button)
    local buttonSize = page ~= nil and page.buttonSize or nil
    if buttonSize == nil or buttonSize <= 0 then return end
    local pane = page.inventoryPane
    fitOneButton(button, buttonSize, iconFor(buttonSize),
        pane ~= nil and pane.mode == "comfy")
end

function WindowChrome.fitButtons(page)
    if page == nil then return end
    local panel = page.containerButtonPanel
    local pane = page.inventoryPane
    if panel == nil or pane == nil or page.width == nil then return end
    local buttonSize = WindowChrome.buttonSizeFor(page)
    page.buttonSize = buttonSize
    page.minimumWidth = 256 + buttonSize
    if pane.width ~= page.width - buttonSize then
        pane:setWidth(page.width - buttonSize)
    end
    if panel.width ~= buttonSize then panel:setWidth(buttonSize) end

    local icon = iconFor(buttonSize)
    local comfy = pane.mode == "comfy"

    page._comfyButtonsComfy = comfy
    local pool = page.buttonPool
    if type(pool) == "table" then
        for i = 1, #pool do fitOneButton(pool[i], buttonSize, icon, comfy) end
    end
    local buttons = page.backpacks
    if type(buttons) ~= "table" then return end
    for i = 1, #buttons do fitOneButton(buttons[i], buttonSize, icon, comfy) end

    local ContainerOrder = ComfyGrid.Model ~= nil
        and ComfyGrid.Model.ContainerOrder or nil
    local laid = false
    if pane.mode == "comfy" and ContainerOrder ~= nil
            and ContainerOrder.sequenceFor ~= nil
            and ContainerOrder.layout ~= nil then
        local ok, sequence = pcall(ContainerOrder.sequenceFor, page)
        if ok and sequence ~= nil then
            laid = pcall(ContainerOrder.layout, page)
        end
    end
    if not laid and #buttons > 0 then
        local y = -1
        for i = 1, #buttons do
            local button = buttons[i]
            if button ~= nil and button:getY() ~= y then button:setY(y) end
            y = y + buttonSize
        end

        local last = buttons[#buttons]
        if last ~= nil and panel.setScrollHeight ~= nil then
            panel:setScrollHeight(last:getBottom())
        end
    end

    WindowChrome.side(page)
end

function WindowChrome.seam(page)
    if page.isCollapsed then return end
    local cornerWidget = page.resizeWidget
    if cornerWidget == nil or cornerWidget.height == nil or page.height == nil then
        return
    end
    local surface = Style.COLORS ~= nil and Style.COLORS.SURFACE or nil
    if surface == nil then return end

    page:drawRect(0, math.floor(page.height - cornerWidget.height), page.width,
        1, 0.85, surface.line.r, surface.line.g, surface.line.b)
end

local function buttonTopOnPage(buttonPanel, button)
    local scroll = buttonPanel.getYScroll ~= nil and buttonPanel:getYScroll() or 0
    return (buttonPanel.y or 0) + button:getY() + scroll
end

function WindowChrome.selection(page)
    if page.isCollapsed then return end
    local pane = page.inventoryPane
    if pane == nil or pane.mode ~= "comfy" then return end
    local panel = page.containerButtonPanel
    local buttons = page.backpacks
    if panel == nil or type(buttons) ~= "table" or #buttons == 0 then return end
    local surface = Style.COLORS ~= nil and Style.COLORS.SURFACE or nil
    if surface == nil or surface.accent == nil then return end

    local selected = page.inventory
    if selected == nil then return end

    local buttonSize = page.buttonSize
    if buttonSize == nil or buttonSize <= 0 then return end
    local bar = math.max(2, math.floor(buttonSize * 0.075 + 0.5))
    local panelX = panel.x or 0

    local left = panelX == 0
    local x = left and (panelX + buttonSize - bar) or panelX

    local columnTop = panel.y or 0
    local columnBottom = columnTop + (panel.height or 0)
    for i = 1, #buttons do
        local button = buttons[i]
        if button ~= nil and button.inventory == selected
                and button.getY ~= nil then
            local buttonTop = buttonTopOnPage(panel, button)
            local buttonHeight = button:getHeight()

            if buttonTop + buttonHeight > columnTop and buttonTop < columnBottom then
                page:drawRect(x, buttonTop + 1, bar, math.max(1, buttonHeight - 2),
                    1, surface.accent.r, surface.accent.g, surface.accent.b)
            end
        end
    end
end

function WindowChrome.searchMarks(page)
    if page.isCollapsed then return end
    local pane = page.inventoryPane
    if pane == nil or pane.mode ~= "comfy" then return end
    local ItemSearch = ComfyGrid.Model and ComfyGrid.Model.ItemSearch or nil
    local SlotRenderer = ComfyGrid.UI and ComfyGrid.UI.SlotRenderer or nil
    if ItemSearch == nil or SlotRenderer == nil then return end
    local marks = ItemSearch.marksFor(page.player)
    if marks == nil then return end
    local buttonPanel = page.containerButtonPanel
    local buttons = page.backpacks
    if buttonPanel == nil or type(buttons) ~= "table" then return end
    local pulse = SlotRenderer.applyPulse()
    local panelX = buttonPanel.x or 0
    local columnTop = buttonPanel.y or 0
    local columnBottom = columnTop + (buttonPanel.height or 0)
    for buttonIndex = 1, #buttons do
        local button = buttons[buttonIndex]
        if button ~= nil and button:getIsVisible()
                and ItemSearch.marksContainer(marks, button.inventory) then

            local top = buttonTopOnPage(buttonPanel, button)
            local bottom = top + button:getHeight()
            if top < columnTop then top = columnTop end
            if bottom > columnBottom then bottom = columnBottom end
            if bottom - top >= 2 then
                SlotRenderer.drawSearchBox(page, panelX + button:getX(), top,
                    button:getWidth(), bottom - top, pulse, true)
            end
        end
    end
end

local styled = {}

local function repaintChrome(page)
    local surface = Style.COLORS ~= nil and Style.COLORS.SURFACE or nil
    if surface == nil or page == nil then return end
    local body, border = page.backgroundColor, page.borderColor
    if body ~= nil then
        body.r, body.g, body.b = surface.bg.r, surface.bg.g, surface.bg.b
    end
    if border ~= nil then
        border.r, border.g, border.b = surface.line.r, surface.line.g,
            surface.line.b
    end

    local tex = Draw ~= nil and Draw.titlebarTexture ~= nil
        and Draw.titlebarTexture() or nil
    if tex ~= nil then
        page.titlebarbkg = tex
        page.statusbarbkg = tex
    end
    local grip = Draw ~= nil and Draw.gripTexture ~= nil
        and Draw.gripTexture() or nil
    if grip ~= nil then page.resizeimage = grip end
end

if Style.onPaletteChanged ~= nil then
    Style.onPaletteChanged(function()
        for i = 1, #styled do repaintChrome(styled[i]) end
    end)
end

function WindowChrome.applyTo(page)
    if page._comfyChrome then return end
    local surface = Style.COLORS ~= nil and Style.COLORS.SURFACE or nil
    if surface == nil then return end

    local body, border = page.backgroundColor, page.borderColor
    page._comfyChromeSaved = {
        bg = body ~= nil and { r = body.r, g = body.g, b = body.b, a = body.a }
            or nil,
        border = border ~= nil
            and { r = border.r, g = border.g, b = border.b, a = border.a } or nil,
        titlebar = page.titlebarbkg,
        statusbar = page.statusbarbkg,
        resizeimage = page.resizeimage,
        titleBarHeight = rawget(page, "titleBarHeight"),
    }

    local bodyAlpha = body ~= nil and body.a or 0.8
    local borderAlpha = border ~= nil and border.a or 1
    page.backgroundColor = { r = surface.bg.r, g = surface.bg.g,
        b = surface.bg.b, a = bodyAlpha }
    page.borderColor = { r = surface.line.r, g = surface.line.g,
        b = surface.line.b, a = borderAlpha }

    local tex = Draw ~= nil and Draw.titlebarTexture ~= nil
        and Draw.titlebarTexture() or nil
    if tex ~= nil then
        page.titlebarbkg = tex
    end

    if tex ~= nil then
        page.statusbarbkg = tex
    end
    local grip = Draw ~= nil and Draw.gripTexture ~= nil
        and Draw.gripTexture() or nil
    if grip ~= nil then
        page.resizeimage = grip
    end

    page.titleBarHeight = function()
        return Style.headerHeight()
    end

    local saved = page._comfyChromeSaved
    saved.buttons = {}
    for _, name in ipairs({ "closeButton", "infoButton", "pinButton",
            "collapseButton" }) do
        local btn = page[name]
        if btn ~= nil and btn.setVisible ~= nil then
            saved.buttons[name] = btn:getIsVisible()
        end
    end

    local strip = WindowStrip:new(page)
    strip:initialise()
    page:addChild(strip)
    page._comfyStrip = strip

    page._comfyChrome = true
    styled[#styled + 1] = page

end

function WindowChrome.restore(page)
    if not page._comfyChrome then return end
    for i = #styled, 1, -1 do
        if styled[i] == page then table.remove(styled, i) end
    end
    local saved = page._comfyChromeSaved
    if saved ~= nil then
        if saved.bg ~= nil then page.backgroundColor = saved.bg end
        if saved.border ~= nil then page.borderColor = saved.border end
        if saved.titlebar ~= nil then page.titlebarbkg = saved.titlebar end
        if saved.statusbar ~= nil then page.statusbarbkg = saved.statusbar end
        if saved.resizeimage ~= nil then
            page.resizeimage = saved.resizeimage
        end

        page.titleBarHeight = saved.titleBarHeight
        if saved.buttons ~= nil then
            for name, wasVisible in pairs(saved.buttons) do
                local btn = page[name]
                if btn ~= nil and btn.setVisible ~= nil then
                    btn:setVisible(wasVisible)
                end
            end

            if page.pinButton ~= nil and page.collapseButton ~= nil then
                page.pinButton:setVisible(not page.pin)
                page.collapseButton:setVisible(page.pin == true)
            end
        end
    end
    if page._comfyStrip ~= nil then

        local searchField = page._comfyStrip.searchField
        if searchField ~= nil and searchField.javaObject ~= nil
                and searchField:isFocused() then
            searchField:unfocus()
        end
        local ItemSearch = ComfyGrid.Model and ComfyGrid.Model.ItemSearch or nil
        if ItemSearch ~= nil then ItemSearch.setTerm(page, "") end
        page:removeChild(page._comfyStrip)
        page._comfyStrip = nil
    end
    page._comfyChrome = nil
    page._comfyChromeSaved = nil
end

function WindowChrome.styleButtons(page)
    local surface = Style.COLORS ~= nil and Style.COLORS.SURFACE or nil
    local buttons = page ~= nil and page.backpacks or nil
    if surface == nil or type(buttons) ~= "table" then return end
    local selected = page.inventory
    for i = 1, #buttons do
        local button = buttons[i]
        if button ~= nil and button.setBackgroundRGBA ~= nil then
            if button.inventory == selected then

                button:setBackgroundRGBA(surface.cardHi.r, surface.cardHi.g,
                    surface.cardHi.b, 1)
                button:setBorderRGBA(surface.accent.r, surface.accent.g,
                    surface.accent.b, 0.9)
            else
                button:setBackgroundRGBA(0, 0, 0, 0)
                button:setBorderRGBA(surface.line.r, surface.line.g,
                    surface.line.b, 0.45)
            end
            if button.setBackgroundColorMouseOverRGBA ~= nil then
                button:setBackgroundColorMouseOverRGBA(surface.card.r,
                    surface.card.g, surface.card.b, 1)
            end
        end
    end
end

if not ComfyGrid._windowChromeHooked then
    ComfyGrid._windowChromeHooked = true
    Events.OnRefreshInventoryWindowContainers.Add(function(page, stage)
        if stage ~= "end" or page == nil then return end

        local pane = page.inventoryPane
        if pane == nil or pane.mode ~= "comfy" then return end
        local ok, err = pcall(WindowChrome.styleButtons, page)
        if not ok then
            Log.warn("WindowChrome: button restyle failed: " .. tostring(err))
        end
    end)
end
