--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.9
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

local function abutsSibling(page)
    local ok, data = pcall(getPlayerData, page.player)
    if not ok or data == nil then return false end
    local other = page.onCharacter and data.lootInventory or data.playerInventory
    if other == nil or other == page then return false end
    local vis = other.getIsVisible ~= nil and other:getIsVisible()
        or other.visible == true
    if not vis then return false end

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
    local spread = math.max(6, math.floor(SHADOW_SPREAD * (Style.SCALE or 1)))
    Draw.shadow(page, 0, 0, page.width, page.height, spread, SHADOW_ALPHA)
end

function WindowChrome.resizeGrips(page)
    local rw = page.resizeWidget
    if rw == nil or rw.height == nil or rw.height <= 0 then return end
    if page.width == nil or page.height == nil then return end
    local rh = rw.height
    local x, y = page.width - rh, page.height - rh

    if not rw.resizing then
        if rw.x ~= x then rw:setX(x) end
        if rw.y ~= y then rw:setY(y) end
    end

    local rw2 = page.resizeWidget2
    if rw2 == nil or rw2.resizing then return end
    if rw2.y ~= y then rw2:setY(y) end
    if rw2.width ~= x then rw2:setWidth(x) end
end

function WindowChrome.resync(page)
    local pane = page.inventoryPane
    if pane == nil or page.width == nil then return end
    local bs = page.buttonSize
    if bs == nil or page.onInventoryContainerSizeChanged == nil then return end
    if pane.width == page.width - bs then return end
    pcall(page.onInventoryContainerSizeChanged, page)
end

function WindowChrome.onLeft(page)
    local S = ComfyGrid.Settings
    if S == nil or S.get == nil then return false end
    local key = "CONTAINERS_LEFT_PLAYER"
    if page ~= nil and page.onCharacter == false then
        key = "CONTAINERS_LEFT_LOOT"
    end
    return S.get(key) == true
end

function WindowChrome.side(page)
    local panel = page.containerButtonPanel
    local pane = page.inventoryPane
    if panel == nil or pane == nil or page.width == nil then return end
    local bs = page.buttonSize
    if bs == nil or bs <= 0 then return end
    local left = pane.mode == "comfy" and WindowChrome.onLeft(page)
    local px, vx = page.width - bs, 0
    if left then px, vx = 0, bs end
    if panel.x ~= px then panel:setX(px) end
    if pane.x ~= vx then pane:setX(vx) end

    local wantRight = not left
    if panel.anchorLeft ~= left then panel.anchorLeft = left end
    if panel.anchorRight ~= wantRight then panel.anchorRight = wantRight end
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
    local bs = math.floor(base * (Style.SCALE or 1) + 0.5)
    if bs < MIN_BUTTON then bs = MIN_BUTTON end
    return bs
end

local function iconFor(bs)
    local base = vanillaButtonSize()
    local vIcon = base - 2
    if vIcon > 32 then vIcon = 32 end
    local icon = math.floor(bs * vIcon / base + 0.5)
    if icon > bs - 2 then icon = bs - 2 end
    if icon < 1 then icon = 1 end
    return icon
end

local function fitArt(b, comfy)
    local img = b.image
    if img == nil then return end
    if comfy then
        if img == b._comfyArt then return end
        local Icons = ComfyGrid.UI ~= nil and ComfyGrid.UI.Icons or nil
        local hi = Icons ~= nil and Icons.gameArt ~= nil and Icons.gameArt(img) or false
        if hi then
            b._comfyArtVanilla = img
            b._comfyArt = hi
            b:setImage(hi)
        end
        return
    end

    if img == b._comfyArt and b._comfyArtVanilla ~= nil then
        b:setImage(b._comfyArtVanilla)
    end
    b._comfyArt = nil
    b._comfyArtVanilla = nil
end

local function fitButton(b, bs, icon, comfy)
    if b == nil or b.setWidth == nil then return end
    fitArt(b, comfy)
    if b.anchorRight ~= false then b:setAnchorRight(false) end
    if b.anchorLeft ~= true then b:setAnchorLeft(true) end
    if b:getX() ~= 0 then b:setX(0) end
    if b:getWidth() ~= bs then b:setWidth(bs) end
    if b:getHeight() ~= bs then b:setHeight(bs) end
    if b.forcedWidthImage ~= icon or b.forcedHeightImage ~= icon then
        b:forceImageSize(icon, icon)
    end
end

function WindowChrome.fitButton(page, b)
    local bs = page ~= nil and page.buttonSize or nil
    if bs == nil or bs <= 0 then return end
    local pane = page.inventoryPane
    fitButton(b, bs, iconFor(bs), pane ~= nil and pane.mode == "comfy")
end

function WindowChrome.fitButtons(page)
    if page == nil then return end
    local panel = page.containerButtonPanel
    local pane = page.inventoryPane
    if panel == nil or pane == nil or page.width == nil then return end
    local bs = WindowChrome.buttonSizeFor(page)
    page.buttonSize = bs
    page.minimumWidth = 256 + bs
    if pane.width ~= page.width - bs then pane:setWidth(page.width - bs) end
    if panel.width ~= bs then panel:setWidth(bs) end

    local icon = iconFor(bs)
    local comfy = pane.mode == "comfy"

    page._comfyButtonsComfy = comfy
    local pool = page.buttonPool
    if type(pool) == "table" then
        for i = 1, #pool do fitButton(pool[i], bs, icon, comfy) end
    end
    local list = page.backpacks
    if type(list) ~= "table" then return end
    for i = 1, #list do fitButton(list[i], bs, icon, comfy) end

    local CO = ComfyGrid.Model ~= nil and ComfyGrid.Model.ContainerOrder or nil
    local laid = false
    if pane.mode == "comfy" and CO ~= nil and CO.sequenceFor ~= nil
            and CO.layout ~= nil then
        local ok, s = pcall(CO.sequenceFor, page)
        if ok and s ~= nil then
            laid = pcall(CO.layout, page)
        end
    end
    if not laid and #list > 0 then
        local y = -1
        for i = 1, #list do
            local b = list[i]
            if b ~= nil and b:getY() ~= y then b:setY(y) end
            y = y + bs
        end

        local last = list[#list]
        if last ~= nil and panel.setScrollHeight ~= nil then
            panel:setScrollHeight(last:getBottom())
        end
    end

    WindowChrome.side(page)
end

function WindowChrome.seam(page)
    if page.isCollapsed then return end
    local rw = page.resizeWidget
    if rw == nil or rw.height == nil or page.height == nil then return end
    local sf = Style.COLORS ~= nil and Style.COLORS.SURFACE or nil
    if sf == nil then return end

    page:drawRect(0, math.floor(page.height - rw.height), page.width, 1, 0.85,
        sf.line.r, sf.line.g, sf.line.b)
end

function WindowChrome.selection(page)
    if page.isCollapsed then return end
    local pane = page.inventoryPane
    if pane == nil or pane.mode ~= "comfy" then return end
    local panel = page.containerButtonPanel
    local buttons = page.backpacks
    if panel == nil or type(buttons) ~= "table" or #buttons == 0 then return end
    local sf = Style.COLORS ~= nil and Style.COLORS.SURFACE or nil
    if sf == nil or sf.accent == nil then return end

    local selected = page.inventory
    if selected == nil then return end

    local bs = page.buttonSize
    if bs == nil or bs <= 0 then return end
    local bar = math.max(2, math.floor(bs * 0.075 + 0.5))
    local px = panel.x or 0

    local left = px == 0
    local x = left and (px + bs - bar) or px

    for i = 1, #buttons do
        local b = buttons[i]
        if b ~= nil and b.inventory == selected and b.getY ~= nil then
            local by = (panel.y or 0) + b:getY()
            local bh = b:getHeight()

            page:drawRect(x, by + 1, bar, math.max(1, bh - 2), 1,
                sf.accent.r, sf.accent.g, sf.accent.b)
        end
    end
end

local styled = {}

local function repaintChrome(page)
    local sf = Style.COLORS ~= nil and Style.COLORS.SURFACE or nil
    if sf == nil or page == nil then return end
    local bg, bo = page.backgroundColor, page.borderColor
    if bg ~= nil then bg.r, bg.g, bg.b = sf.bg.r, sf.bg.g, sf.bg.b end
    if bo ~= nil then bo.r, bo.g, bo.b = sf.line.r, sf.line.g, sf.line.b end

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
    local sf = Style.COLORS ~= nil and Style.COLORS.SURFACE or nil
    if sf == nil then return end

    local bg, bo = page.backgroundColor, page.borderColor
    page._comfyChromeSaved = {
        bg = bg ~= nil and { r = bg.r, g = bg.g, b = bg.b, a = bg.a } or nil,
        border = bo ~= nil and { r = bo.r, g = bo.g, b = bo.b, a = bo.a } or nil,
        titlebar = page.titlebarbkg,
        statusbar = page.statusbarbkg,
        resizeimage = page.resizeimage,
        titleBarHeight = rawget(page, "titleBarHeight"),
    }

    local ba = bg ~= nil and bg.a or 0.8
    local boa = bo ~= nil and bo.a or 1
    page.backgroundColor = { r = sf.bg.r, g = sf.bg.g, b = sf.bg.b, a = ba }
    page.borderColor = { r = sf.line.r, g = sf.line.g, b = sf.line.b, a = boa }

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
        page:removeChild(page._comfyStrip)
        page._comfyStrip = nil
    end
    page._comfyChrome = nil
    page._comfyChromeSaved = nil
end

function WindowChrome.styleButtons(page)
    local sf = Style.COLORS ~= nil and Style.COLORS.SURFACE or nil
    local buttons = page ~= nil and page.backpacks or nil
    if sf == nil or type(buttons) ~= "table" then return end
    local selected = page.inventory
    for i = 1, #buttons do
        local b = buttons[i]
        if b ~= nil and b.setBackgroundRGBA ~= nil then
            if b.inventory == selected then

                b:setBackgroundRGBA(sf.cardHi.r, sf.cardHi.g, sf.cardHi.b, 1)
                b:setBorderRGBA(sf.accent.r, sf.accent.g, sf.accent.b, 0.9)
            else
                b:setBackgroundRGBA(0, 0, 0, 0)
                b:setBorderRGBA(sf.line.r, sf.line.g, sf.line.b, 0.45)
            end
            if b.setBackgroundColorMouseOverRGBA ~= nil then
                b:setBackgroundColorMouseOverRGBA(sf.card.r, sf.card.g,
                    sf.card.b, 1)
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
