--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.7.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
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

function WindowChrome.seam(page)
    if page.isCollapsed then return end
    local rw = page.resizeWidget
    if rw == nil or rw.height == nil or page.height == nil then return end
    local sf = Style.COLORS ~= nil and Style.COLORS.SURFACE or nil
    if sf == nil then return end

    page:drawRect(0, math.floor(page.height - rw.height), page.width, 1, 0.85,
        sf.line.r, sf.line.g, sf.line.b)
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
