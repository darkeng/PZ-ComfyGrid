--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/Interact/DragAndDrop"
require "ComfyGrid/Interact/Pad/PadPopup"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local InspectorChrome = {}
ComfyGrid.UI.Chrome.InspectorChrome = InspectorChrome

local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local Style = ComfyGrid.UI.Style
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local DragAndDrop = ComfyGrid.Interact.DragAndDrop
local PadPopup = ComfyGrid.Interact.PadPopup

local PAD_X = 4
InspectorChrome.PAD_X = PAD_X

local BOTTOM_PAD = 4
InspectorChrome.BOTTOM_PAD = BOTTOM_PAD

function InspectorChrome.closeChip()
    return math.max(14, math.floor(Style.FONT_H * 0.9 + 0.5))
end
local closeChip = InspectorChrome.closeChip

function InspectorChrome.closeZoneLeft(w)
    return w - (closeChip() + 12)
end
local closeZoneLeft = InspectorChrome.closeZoneLeft

function InspectorChrome.isCloseHit(popup, x, y)
    return not popup.dragDidStart and y < popup.titleH
        and x > closeZoneLeft(popup.width)
end

local DEFAULT_BG = { r = 0.07, g = 0.07, b = 0.09, a = 0.96 }
local DEFAULT_TEXT = { r = 0.9, g = 0.9, b = 0.9, a = 1 }

function InspectorChrome.boardBackground()
    local colors = Style.COLORS
    return colors and colors.BOARD_BG or DEFAULT_BG
end

function InspectorChrome.newErrorLatch(name)
    return { name = name }
end

function InspectorChrome.reportError(latch, what, err)
    if err == latch[what] then return end
    latch[what] = err
    Log.error(latch.name .. " " .. what .. " failed: " .. tostring(err))
end

function InspectorChrome.hostPaneOf(element, playerNum)
    local PaneHost = ComfyGrid.UI and ComfyGrid.UI.PaneHost
    if PaneHost == nil or PaneHost.paneOf == nil then return nil end
    return PaneHost.paneOf(element, playerNum)
end

function InspectorChrome.standDownOthers()
    local Chrome = ComfyGrid.UI and ComfyGrid.UI.Chrome
    local Registry = Chrome ~= nil and Chrome.PopupRegistry or nil
    if Registry ~= nil then Registry.closeOthers(nil) end
end

function InspectorChrome.show(popup)
    popup:initialise()
    popup:addToUIManager()
    popup:bringToTop()
end

function InspectorChrome.dismantle(popup)
    PadPopup.releaseFocus(popup)
    if DragAndDrop.isDragOwner(popup) and not DragAndDrop.isDragging() then
        DragAndDrop.endDrag()
    end
    popup:setVisible(false)
    popup:removeFromUIManager()
end

local function closeOnOutsidePress(popup, _x, _y)
    popup:close()
end

local function consumePress(_popup, _x, _y)
    return true
end

function InspectorChrome.installDismissHandlers(popupClass)
    popupClass.onMouseDownOutside = closeOnOutsidePress
    popupClass.onRightMouseDownOutside = closeOnOutsidePress
    popupClass.onRightMouseDown = consumePress
end

function InspectorChrome.fitColumns(popup, minCols, maxCols)
    local tileCount = #popup.tiles
    if tileCount < 1 then tileCount = 1 end
    local cols = math.ceil(math.sqrt(tileCount))
    if cols < minCols then cols = minCols end
    if cols > maxCols then cols = maxCols end
    popup.cols = cols
    popup.rowsTotal = math.ceil(tileCount / cols)
    return cols
end

function InspectorChrome.sizeToBoard(popup, bw, bh)
    local w = bw + PAD_X * 2
    local h = popup.titleH + bh + BOTTOM_PAD
    if popup.width ~= w then popup:setWidth(w) end
    if popup.height ~= h then popup:setHeight(h) end
    return w, h
end

function InspectorChrome.screenSize()
    local core = getCore()
    local screenW = core and core:getScreenWidth() or 1920
    local screenH = core and core:getScreenHeight() or 1080
    return screenW, screenH
end

function InspectorChrome.placeOnScreen(popup, x, y, w, h, screenW, screenH)
    if x + w > screenW then x = math.max(0, screenW - w) end
    if y + h > screenH then y = math.max(0, screenH - h) end
    if x ~= popup:getX() then popup:setX(x) end
    if y ~= popup:getY() then popup:setY(y) end
end

function InspectorChrome.slideIn(popup)
    local Draw = ComfyGrid.UI.Draw
    if Draw == nil then return end
    local slideLeft = popup._comfySlide
    if slideLeft == nil then
        slideLeft = math.floor(10 * Style.SCALE + 0.5)
        popup._comfySlide = slideLeft
        popup:setY(popup:getY() + slideLeft)
    elseif slideLeft > 0 then
        local nextSlide = Draw.glide(slideLeft, 0, 0.35)
        popup:setY(popup:getY() - (slideLeft - nextSlide))
        popup._comfySlide = nextSlide
    end
end

function InspectorChrome.boardOrigin(popup)
    return PAD_X, popup.titleH
end

function InspectorChrome.tileAt(popup, x, y)
    local idx = Style.slotAtPixel(x - PAD_X, y - popup.titleH + (popup.yOffset or 0),
        popup.cols, popup.rowsTotal)
    if idx == nil or idx >= #popup.tiles then return nil end
    return idx
end
local tileAt = InspectorChrome.tileAt

function InspectorChrome.updateHover(popup)
    popup.hoverTile = tileAt(popup, popup:getMouseX(), popup:getMouseY())
end
local updateHover = InspectorChrome.updateHover

function InspectorChrome.tileXY(popup, index)
    local px, py = Style.pixelForSlot(index, popup.cols)
    return PAD_X + px, popup.titleH + py - (popup.yOffset or 0)
end

function InspectorChrome.visibleBoardHeight(popup)
    return popup.height - popup.titleH - BOTTOM_PAD
end

function InspectorChrome.drawFrame(popup, bg)
    local w = popup.width
    local h = popup.height
    local colors = Style.COLORS
    local Draw = ComfyGrid.UI.Draw
    local surface = colors and colors.SURFACE
    local bgA = math.min(1, (bg.a or 1) + 0.12)
    if Draw ~= nil and surface ~= nil then
        local cornerRadius = math.max(4, math.floor(8 * Style.SCALE + 0.5))
        Draw.shadow(popup, 0, 0, w, h, math.floor(10 * Style.SCALE + 0.5), 0.5)
        Draw.roundFrame(popup, 0, 0, w, h, cornerRadius,
            Style.CHROME_LINE_ALPHA, surface.line, bg, bgA)
    else
        popup:drawRect(0, 0, w, h, bgA, bg.r or 0, bg.g or 0, bg.b or 0)
        local chrome = Style.COLORS.POPUP_CHROME
        popup:drawRectBorder(0, 0, w, h, Style.CHROME_LINE_ALPHA, chrome.r,
            chrome.g, chrome.b)
    end
end

local function countSuffix(popup, count)
    if popup._countSuffix == nil or popup._countSuffixFor ~= count then
        popup._countSuffixFor = count
        popup._countSuffix = " x" .. tostring(count)
    end
    return popup._countSuffix
end

local function fittedTitle(popup, text, suffix, font, w)
    local fitGen = Style.FONT_H * 100000 + math.floor(w)
    if popup._titleFit == nil or popup._titleFitGen ~= fitGen
            or popup._titleFitSrc ~= text or popup._titleFitSuffix ~= suffix
            then
        local textManager = getTextManager and getTextManager() or nil
        local suffixW = 0
        if textManager ~= nil then
            local okMeasure, measuredW = pcall(textManager.MeasureStringX,
                textManager, font, suffix)
            if okMeasure then suffixW = measuredW end
        end
        local budget = closeZoneLeft(w) - (PAD_X + 2) - 6 - suffixW
        if budget < 1 then budget = 1 end
        popup._titleFitGen = fitGen
        popup._titleFitSrc = text
        popup._titleFitSuffix = suffix
        popup._titleFit = Text.fitEllipsis(text, font, budget, 60) .. suffix
    end
    return popup._titleFit
end

local function drawCloseChip(popup, w, titleY, textColor, font, Draw, surface)
    local closeTex = Draw ~= nil and Draw.closeTexture ~= nil
        and Draw.closeTexture() or nil
    if closeTex ~= nil and surface ~= nil then
        local chip = closeChip()
        local chipX = w - 6 - chip
        local chipY = math.floor((popup.titleH - 1 - chip) * 0.5)
        Draw.disc(popup, chipX, chipY, chip, 1, surface.line)
        Draw.disc(popup, chipX + 1, chipY + 1, chip - 2, 1, surface.card)
        local glyphSize = math.floor(chip * 0.55 + 0.5)
        local glyphInset = math.floor((chip - glyphSize) * 0.5)
        popup:drawTextureScaled(closeTex, chipX + glyphInset,
            chipY + glyphInset, glyphSize, glyphSize, 0.9,
            textColor.r, textColor.g, textColor.b)
    else
        popup:drawTextRight("X", w - 8, titleY,
            textColor.r, textColor.g, textColor.b, textColor.a or 1, font)
    end
end

function InspectorChrome.drawTitleBar(popup, text, count)
    local w = popup.width
    local colors = Style.COLORS
    local textColor = colors and colors.COUNT_TEXT or DEFAULT_TEXT
    local Draw = ComfyGrid.UI.Draw
    local surface = colors and colors.SURFACE
    local font = Style.FONT
    if font ~= nil then
        local suffix = countSuffix(popup, count)
        local titleY = math.floor((popup.titleH - 1 - Style.FONT_H) * 0.5)
        if titleY < 2 then titleY = 2 end
        popup:drawText(fittedTitle(popup, text, suffix, font, w), PAD_X + 2,
            titleY, textColor.r, textColor.g, textColor.b, textColor.a or 1, font)
        drawCloseChip(popup, w, titleY, textColor, font, Draw, surface)
    end
    if Draw ~= nil and surface ~= nil then

        Draw.headerLine(popup, 1, popup.titleH - 1, w - 2,
            math.floor(10 * Style.SCALE + 0.5), colors)
    else
        local chrome = Style.COLORS.POPUP_CHROME
        popup:drawRect(0, popup.titleH - 1, w, 1, Style.CHROME_LINE_ALPHA,
            chrome.r, chrome.g, chrome.b)
    end
end

function InspectorChrome.drawTrailingCells(popup, ctx, bx, boardTop)
    local cols = popup.cols
    local pixelForSlot = Style.pixelForSlot
    for i = #popup.tiles + 1, cols * popup.rowsTotal do
        local ex, ey = pixelForSlot(i - 1, cols)
        ctx.stack = nil
        ctx.item = nil
        ctx.slot = i - 1
        ctx.x = bx + ex
        ctx.y = boardTop + ey
        SlotRenderer.drawCell(ctx, nil)
    end
end

function InspectorChrome.drawHoverAndPadCursor(popup, ctx, bx, boardTop)
    local tiles = popup.tiles
    local cols = popup.cols
    local pixelForSlot = Style.pixelForSlot
    local hover = popup.hoverTile
    if hover ~= nil and hover < #tiles and popup:isMouseOver() then
        local hx, hy = pixelForSlot(hover, cols)
        ctx.stack = tiles[hover + 1].synth
        ctx.item = nil
        ctx.slot = hover
        ctx.x = bx + hx
        ctx.y = boardTop + hy
        SlotRenderer.drawHover(ctx)
    end
    local padIdx = PadPopup.cursorFor(popup)
    if padIdx ~= nil and padIdx < #tiles then
        local px, py = pixelForSlot(padIdx, cols)
        SlotRenderer.drawSelection(popup, bx + px, boardTop + py)
        ctx.stack = tiles[padIdx + 1].synth
        ctx.item = nil
        ctx.slot = padIdx
        ctx.x = bx + px
        ctx.y = boardTop + py
        SlotRenderer.drawHover(ctx)
    end
end

function InspectorChrome.promoteDrag(popup)
    DragAndDrop.startDrag(popup)
    if not popup.dragDidStart and DragAndDrop.isDragging()
            and DragAndDrop.isDragOwner(popup) then
        popup.dragDidStart = true
    end
end

function InspectorChrome.pointerMoved(popup)
    updateHover(popup)
    InspectorChrome.promoteDrag(popup)
end

function InspectorChrome.pointerMovedOutside(popup)
    popup.hoverTile = nil
    InspectorChrome.promoteDrag(popup)
end

function InspectorChrome.hoveredItem(popup, liveTileItem)
    local idx = popup.hoverTile
    if idx == nil or not popup:isMouseOver() then return nil end
    return liveTileItem(popup, idx)
end
