--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Input"
require "ComfyGrid/Core/Prefs"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Settings"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
require "ComfyGrid/UI/Chrome/WindowStrip"
require "ComfyGrid/UI/Chrome/WindowChrome"
require "ComfyGrid/UI/Chrome/ResizeGrip"
require "ComfyGrid/UI/Avatar"
require "ComfyGrid/UI/EquipmentStrip"
require "ComfyGrid/UI/EquipDock"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local Prefs = ComfyGrid.Core.Prefs
local Text = ComfyGrid.Core.Text
local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw
local WindowStrip = ComfyGrid.UI.Chrome.WindowStrip
local WindowChrome = ComfyGrid.UI.Chrome.WindowChrome
local ResizeGrip = ComfyGrid.UI.Chrome.ResizeGrip
local Avatar = ComfyGrid.UI.Avatar
local EquipmentStrip = ComfyGrid.UI.EquipmentStrip
local EquipDock = ComfyGrid.UI.EquipDock

local EquipWindow = ISPanel:derive("ComfyEquipWindow")
ComfyGrid.UI.EquipWindow = EquipWindow

local windows = {}

local MODDATA_KEY = "ComfyGrid_EquipWindow"
local LAYOUT_ID = "ComfyGridEquipWindow"

local function padOwns(playerNum)
    return ComfyGrid.Core.Input.padOwns(playerNum)
end

local function settings()
    return ComfyGrid.Settings
end

local function wantsWindow()
    local Settings = settings()
    if Settings == nil or Settings.get == nil then return false end
    return Settings.get("EQUIPMENT_VIEW") == "window"
end

local function setView(view)
    local Settings = settings()
    if Settings == nil or Settings.set == nil then return end
    Settings.set("EQUIPMENT_VIEW", view)
    if Settings.save ~= nil then Settings.save() end
end

local FIGURE_TILES = 3
local PAD = 6

local PREF_KEY = "equipWindowScale"
local MAX_FIGURE_SCALE = 3

local SNAP = 0.03

local function clampFigureScale(requestedScale)
    if type(requestedScale) ~= "number" or requestedScale ~= requestedScale then
        requestedScale = 1
    end
    local natural = Avatar.heightFor(FIGURE_TILES * Style.CELL)
    local minimumScale = natural > 0
        and EquipmentStrip.minFigureHeight() / natural or 1
    if minimumScale > 1 then minimumScale = 1 end
    if requestedScale < minimumScale then requestedScale = minimumScale end
    if requestedScale > MAX_FIGURE_SCALE then requestedScale = MAX_FIGURE_SCALE end
    return requestedScale
end

local function figureWidth(figureScale)
    return math.floor(FIGURE_TILES * Style.CELL * clampFigureScale(figureScale)
        + 0.5)
end

local function sideColumn()
    return Style.CELL_STRIDE + EquipmentStrip.ROW_GAP
end

local function defaultWidth(figureScale)
    return figureWidth(figureScale) + 2 * sideColumn() + 2 * PAD
end

local function defaultHeight(trayRows, stripWidth, figureScale)
    return Style.headerHeight() + PAD
        + EquipmentStrip.anchorsHeight(Avatar.heightFor(figureWidth(figureScale)),
            trayRows, stripWidth or (defaultWidth(figureScale) - PAD * 2))
        + PAD
end

local function wantedHeight(win)
    local strip = win ~= nil and win.content or nil
    return defaultHeight(strip ~= nil and strip.trayRows or 0,
        win ~= nil and win.width - PAD * 2 or nil,
        win ~= nil and win.figureK or nil)
end

local lastError = nil
local function report(where, err)
    local key = where .. tostring(err)
    if key ~= lastError then
        lastError = key
        Log.error("EquipWindow " .. where .. " failed: " .. tostring(err))
    end
end

local function stateOf(playerNum)
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj == nil or playerObj.getModData == nil then return nil end
    local ok, modData = pcall(playerObj.getModData, playerObj)
    if not ok or modData == nil then return nil end
    local state = modData[MODDATA_KEY]
    if type(state) ~= "table" then
        state = { docked = true }
        modData[MODDATA_KEY] = state
    end
    return state
end

local CHIP_LEFT = {

    { id = "close", tex = function() return Draw.closeTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipEquipBackTip",
      tipEN = "Put equipment back in the inventory." },
}

local CHIP_RIGHT = {

    { id = "dock", tex = function() return Draw.dockTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipDockTip",
      tipEN = "Attach this window to the inventory.",
      when = function(win) return not padOwns(win.playerNum) end,
      active = function(win) return win.docked == true end },
    { id = "pin", tex = function() return Draw.pinTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipPinTip",
      tipEN = "Keep this window open.",
      when = function(win) return win.docked ~= true end,
      active = function(win) return win.pin == true end },
}

local CHIP_ACTIONS = {}

function CHIP_ACTIONS.close(_strip)
    setView("strip")
end

function CHIP_ACTIONS.pin(strip)
    local win = strip.page
    if win ~= nil then win:setPinned(not win.pin) end
end

function CHIP_ACTIONS.dock(strip)
    local win = strip.page
    if win ~= nil then win:setDocked(not win.docked) end
end

local CHIP_SPEC = { left = CHIP_LEFT, right = CHIP_RIGHT,
    actions = CHIP_ACTIONS }

function EquipWindow:new(playerNum)

    local savedFigureScale = Prefs ~= nil and Prefs.getNumber ~= nil
        and Prefs.getNumber(PREF_KEY .. tostring(playerNum), 1) or 1
    local width = defaultWidth(savedFigureScale)
    local height = defaultHeight(0, nil, savedFigureScale)
    local o = ISPanel:new(0, 0, width, height)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.figureK = savedFigureScale
    o.resize = nil
    o.pin = true
    o.isCollapsed = false
    o.collapseCounter = 0

    o.preferredWidth = width
    o.docked = true

    o.dockSide = "left"

    o.push = nil

    o.pushWidth = nil
    o.dragging = false

    o.keepOnScreen = false
    o.moveWithMouse = false
    o.strip = nil
    o.content = nil
    o.avatar = nil
    return o
end

function EquipWindow.titleBarHeight(_self)
    return Style.headerHeight()
end

function EquipWindow:createChildren()
    ISPanel.createChildren(self)

    local avatar = Avatar:new(0, 0, 1, 1, self.playerNum)
    avatar:initialise()
    self:addChild(avatar)
    self.avatar = avatar

    local strip = EquipmentStrip:new(0, 0, self.playerNum)
    strip:setLayout("anchors")
    strip:initialise()
    self:addChild(strip)
    self.content = strip

    local grip = ResizeGrip:new(self)
    grip:initialise()
    self:addChild(grip)
    self.grip = grip

    local band = WindowStrip:new(self, CHIP_SPEC)
    band:initialise()
    self:addChild(band)
    self.strip = band
end

local function clampOnScreen(self)
    local left, top, screenWidth, screenHeight =
        EquipDock.screenRect(self.playerNum)
    local band = self:titleBarHeight()
    local x = self.x
    if x < left then x = left end
    if screenWidth > 0 and x + self.width > left + screenWidth then
        x = left + screenWidth - self.width
        if x < left then x = left end
    end
    local y = self.y
    if y < top then y = top end
    if screenHeight > 0 and y + band > top + screenHeight then
        y = top + screenHeight - band
    end
    if self.x ~= x then self:setX(x) end
    if self.y ~= y then self:setY(y) end
end

local function overPage(self)
    if getPlayerInventory == nil then return false end
    local ok, page = pcall(getPlayerInventory, self.playerNum)
    if not ok or page == nil or not page:getIsVisible() then return false end
    local mx, my = getMouseX(), getMouseY()
    local px, py = page:getX(), page:getY()
    local ph = page.isCollapsed and page:titleBarHeight() or page:getHeight()
    return mx >= px and mx < px + page:getWidth()
        and my >= py and my < py + ph
end

function EquipWindow.isMouseOverIt(playerNum)
    local win = windows[playerNum]
    if win == nil or not win:getIsVisible() then return false end
    local mx, my = getMouseX(), getMouseY()
    local h = win.isCollapsed and win:titleBarHeight() or win.height
    return mx >= win.x and mx < win.x + win.width
        and my >= win.y and my < win.y + h
end

function EquipWindow:collapseNow()
    if self.isCollapsed or self.docked then return end
    self.isCollapsed = true
    self:setMaxDrawHeight(self:titleBarHeight())

    if self.avatar ~= nil then self.avatar:hideModel() end
end

function EquipWindow:uncollapse()
    if not self.isCollapsed then return end
    self.isCollapsed = false

    self:clearMaxDrawHeight()
    self.collapseCounter = 0
end

function EquipWindow:setPinned(pin)
    self.pin = pin and true or false
    local state = stateOf(self.playerNum)
    if state ~= nil then state.pin = self.pin end
    if self.pin then self:uncollapse() end
end

function EquipWindow:setDocked(docked)
    self.docked = docked and true or false
    local state = stateOf(self.playerNum)
    if state ~= nil then state.docked = self.docked end

    self.dockedPageSpot = nil

    self:uncollapse()
    if not self.docked then
        if self.preferredWidth ~= nil and self.width < self.preferredWidth then
            self:setWidth(self.preferredWidth)
        end
        self:setX(self.x - 8)
        clampOnScreen(self)
        self:bringToTop()
    end
end

function EquipWindow.getOrCreate(playerNum)
    local win = windows[playerNum]
    if win ~= nil then return win end
    win = EquipWindow:new(playerNum)
    win:initialise()
    win:addToUIManager()
    local state = stateOf(playerNum)
    win.docked = state == nil or state.docked ~= false
    win.pin = state == nil or state.pin ~= false

    if playerNum == 0 and ISLayoutManager ~= nil then
        pcall(ISLayoutManager.RegisterWindow, LAYOUT_ID, EquipWindow, win)
    end
    windows[playerNum] = win
    return win
end

function EquipWindow.windowFor(playerNum)
    return windows[playerNum]
end

function EquipWindow.viewOf(_playerNum)
    local Settings = settings()
    local view = (Settings ~= nil and Settings.get ~= nil)
        and Settings.get("EQUIPMENT_VIEW") or nil
    if view == "window" or view == "off" then return view end
    return "strip"
end

function EquipWindow.isOn(playerNum)
    return EquipWindow.viewOf(playerNum) ~= "off"
end

local NEXT_VIEW = { strip = "window", window = "off", off = "strip" }

local WARNED_KEY = "equipOffWarned"

local function confirmOff(playerNum, onYes)
    if Prefs ~= nil and Prefs.get ~= nil and Prefs.get(WARNED_KEY) == "1" then
        return onYes()
    end
    local Confirm = ComfyGrid.UI and ComfyGrid.UI.Chrome
        and ComfyGrid.UI.Chrome.Confirm
    if Confirm == nil or Confirm.open == nil then return onYes() end
    local text = Text.tr("IGUI_ComfyGrid_EquipOffConfirm",

        "Turn the equipment off?\n\nComfy Grid will not show it anywhere, and you will not be able to unequip from the mod. This is for players who would rather use another equipment mod.")

    Confirm.open({
        text = text,
        playerNum = playerNum,
        onYes = function()
            if Prefs ~= nil and Prefs.set ~= nil then Prefs.set(WARNED_KEY, "1") end
            onYes()
        end,
    })
end

function EquipWindow.toggle(playerNum)
    playerNum = playerNum or 0
    local nextView = NEXT_VIEW[EquipWindow.viewOf(playerNum)] or "window"
    if nextView ~= "off" then return setView(nextView) end
    confirmOff(playerNum, function() setView("off") end)
end

function EquipWindow.follow(page)
    if page == nil or page.onCharacter ~= true then return end
    local playerNum = page.player

    local pane = page.inventoryPane
    local wanted = wantsWindow() and pane ~= nil and pane.mode == "comfy"
    local win = windows[playerNum]

    local docked = win == nil or win.docked
    local showing = wanted and page:getIsVisible() == true
        and not (docked and page.isCollapsed)
    local pad = padOwns(playerNum)
    if win == nil then

        if not wanted then
            if pad then EquipDock.padRestore(page) end
            return
        end
        win = EquipWindow.getOrCreate(playerNum)
    end
    local split = false
    if pad then

        win.docked = true
        if win.push ~= nil then EquipDock.giveBackRoom(win) end
        if wanted then
            split = EquipDock.padSplit(win, page)
        else
            EquipDock.padRestore(page)
        end
    elseif wanted and win.docked then

        local grew = win.pushWidth ~= nil
            and (win.preferredWidth or win.width) > win.pushWidth
        if win.push == nil then

            local spot = win.dockedPageSpot
            win.dockedPageSpot = nil
            if spot ~= nil and spot.x == page:getX() and spot.y == page:getY() then
                EquipDock.keepSavedSpot(win)
            else
                EquipDock.makeRoom(win, page)
            end
        elseif grew then
            EquipDock.makeRoom(win, page)
        end
    elseif win.push ~= nil then
        EquipDock.giveBackRoom(win)
    end
    if win:getIsVisible() ~= showing then
        win:setVisible(showing)
        if showing then win:bringToTop() end
    end

    if showing and win.docked and not split then EquipDock.dockTo(win, page) end
end

local function gripSide(self)
    if self.docked and self.dockSide == "left" then return "left" end
    return "right"
end

local function factorForWidth(windowWidth)
    return (windowWidth - 2 * sideColumn() - 2 * PAD) / (FIGURE_TILES * Style.CELL)
end

local function factorForHeight(self, windowHeight)
    local strip = self.content
    local trayRows = strip ~= nil and strip.trayRows or 0
    local chromeHeight = Style.headerHeight() + PAD
        + EquipmentStrip.anchorsHeight(0, trayRows, self.width - PAD * 2) + PAD
    return Avatar.widthFor(windowHeight - chromeHeight) / (FIGURE_TILES * Style.CELL)
end

local function applySize(self)
    self.preferredWidth = defaultWidth(self.figureK)

    if not self.docked then self:setWidth(self.preferredWidth) end
    self:setHeight(wantedHeight(self))
end

function EquipWindow:beginResize()
    if self.resize ~= nil then return end
    self.resize = {
        mouseX = getMouseX(), mouseY = getMouseY(),
        startFigureScale = clampFigureScale(self.figureK),
        width = self.width, height = self.height,
        side = gripSide(self),
    }
    self.resize.widthSign = self.resize.side == "left" and -1 or 1
end

function EquipWindow:endResize()
    local drag = self.resize
    if drag == nil then return end
    self.resize = nil
    if self.figureK ~= drag.startFigureScale and Prefs ~= nil
            and Prefs.set ~= nil then
        Prefs.set(PREF_KEY .. tostring(self.playerNum),
            string.format("%.3f", self.figureK))
    end
end

function EquipWindow:updateResize()
    local drag = self.resize
    local dx = (getMouseX() - drag.mouseX) * drag.widthSign
    local dy = getMouseY() - drag.mouseY
    local byWidth = factorForWidth(drag.width + dx)
    local byHeight = factorForHeight(self, drag.height + dy)
    local nextFigureScale = byWidth
    if math.abs(byHeight - drag.startFigureScale)
            > math.abs(byWidth - drag.startFigureScale) then
        nextFigureScale = byHeight
    end
    nextFigureScale = clampFigureScale(nextFigureScale)
    if math.abs(nextFigureScale - 1) < SNAP then nextFigureScale = 1 end
    if nextFigureScale ~= self.figureK then
        self.figureK = nextFigureScale
        applySize(self)
    end
end

local function layoutGrip(self)
    local grip = self.grip
    if grip == nil then return end
    local show = not padOwns(self.playerNum) and not self.isCollapsed

    local side = self.resize ~= nil and self.resize.side or gripSide(self)
    ResizeGrip.seat(grip, show, side, ResizeGrip.defaultSize())
end

local function standDownWithPage(self)
    local ok, page = pcall(getPlayerInventory, self.playerNum)
    if not ok or page == nil or not page:getIsVisible() then
        self:setVisible(false)
        return true
    end
    return false
end

local function paintBody(self, bandH)
    if Draw ~= nil and Draw.shadow ~= nil and not self.docked then
        local shadowH = self.isCollapsed and bandH or self.height
        Draw.shadow(self, 0, 0, self.width, shadowH, WindowChrome.shadowSpread(),
            WindowChrome.SHADOW_ALPHA)
    end

    local surface = Style.COLORS and Style.COLORS.SURFACE
    if surface ~= nil then
        self:drawRect(0, 0, self.width, self.height, 0.95, surface.bg.r,
            surface.bg.g, surface.bg.b)
    end
end

local function trackBand(self)
    local band = self.strip
    if band == nil then return end
    if band.width ~= self.width then band:setWidth(self.width) end
    if band.y ~= 0 then band:setY(0) end
end

local function fitFigure(self, innerW)
    local columnWidth = sideColumn()
    local figureRoom = innerW - columnWidth * 2
    local figW = figureWidth(self.figureK)
    if figW > figureRoom then figW = figureRoom end
    if figW < Style.CELL then figW = Style.CELL end
    local figX = math.floor((innerW - figW) / 2)
    local figY = EquipmentStrip.anchorsTop()
    local figH = Avatar.heightFor(figW)
    return figX, figY, figW, figH
end

local function placeContent(self, innerY, innerW, figX, figY, figW, figH)
    local content = self.content
    if content == nil then return end
    if content.x ~= PAD then content:setX(PAD) end
    if content.y ~= innerY then content:setY(innerY) end
    if content.setAvailableWidth ~= nil then
        content:setAvailableWidth(innerW)
    end
    if content.setFigureBox ~= nil then
        content:setFigureBox(figX, figY, figW, figH)
    end
end

local function placeAvatar(self, innerY, figX, figY, figW, figH)
    local avatar = self.avatar
    if avatar == nil then return end
    local ax, ay = PAD + figX, innerY + figY
    if not avatar:getIsVisible() then avatar:setVisible(true) end
    if avatar.x ~= ax then avatar:setX(ax) end
    if avatar.y ~= ay then avatar:setY(ay) end
    if avatar.width ~= figW then avatar:setWidth(figW) end
    if avatar.height ~= figH then avatar:setHeight(figH) end
end

local function followTray(self)
    local wantH = wantedHeight(self)
    if wantH ~= nil and self.height ~= wantH then self:setHeight(wantH) end
end

local function prerenderImpl(self)
    if standDownWithPage(self) then return end
    ResizeGrip.poll(self)
    local bandH = self:titleBarHeight()
    paintBody(self, bandH)
    trackBand(self)
    local innerY = bandH + PAD
    local innerW = self.width - PAD * 2
    local figX, figY, figW, figH = fitFigure(self, innerW)
    placeContent(self, innerY, innerW, figX, figY, figW, figH)
    placeAvatar(self, innerY, figX, figY, figW, figH)
    followTray(self)
    layoutGrip(self)
end

function EquipWindow:prerender()
    local ok, err = pcall(prerenderImpl, self)
    if not ok then report("prerender", err) end
end

function EquipWindow:render()
    local surface = Style.COLORS and Style.COLORS.SURFACE
    if surface == nil then return end

    local frameHeight = self.isCollapsed and self:titleBarHeight() or self.height
    self:drawRectBorder(0, 0, self.width, frameHeight, 0.85, surface.line.r,
        surface.line.g, surface.line.b)
end

function EquipWindow:onMouseDown(_x, y)
    if self.docked then return true end
    self:uncollapse()
    if y <= self:titleBarHeight() then
        self.dragging = true
        self:bringToTop()
    end
    return true
end

function EquipWindow:onMouseDownOutside(_x, _y)
    if self.docked or self.pin then return end
    if overPage(self) then return end
    self:collapseNow()
end

function EquipWindow:onRightMouseDownOutside(x, y)
    self:onMouseDownOutside(x, y)
end

function EquipWindow:onMouseUp(_x, _y)
    self.dragging = false
    return true
end

function EquipWindow:onMouseUpOutside(_x, _y)
    self.dragging = false
end

local function dragBy(self, dx, dy)
    self:setX(self.x + dx)
    self:setY(self.y + dy)
    clampOnScreen(self)
end

function EquipWindow:onMouseMove(dx, dy)

    if not isMouseButtonDown(0) and not isMouseButtonDown(1)
            and not isMouseButtonDown(2) then
        self.collapseCounter = 0
        if self.isCollapsed and self:getMouseY() < self:titleBarHeight() then
            self:uncollapse()
        end
    end
    if not self.dragging then return end
    dragBy(self, dx, dy)
end

function EquipWindow:onMouseMoveOutside(dx, dy)
    if self.dragging then
        dragBy(self, dx, dy)
        return
    end
    if self.docked or self.pin or self.isCollapsed then return end

    if ISMouseDrag ~= nil and ISMouseDrag.dragging ~= nil then return end
    if overPage(self) then
        self.collapseCounter = 0
        return
    end

    local gameTime = getGameTime()
    self.collapseCounter = self.collapseCounter
        + gameTime:getMultiplier() / gameTime:getTrueMultiplier() / 0.8
    if self.collapseCounter > 120 then self:collapseNow() end
end

function EquipWindow:RestoreLayout(_name, layout)
    ISLayoutManager.DefaultRestoreWindow(self, layout)

    self.preferredWidth = defaultWidth(self.figureK)
    self:setWidth(self.preferredWidth)
    self:setHeight(wantedHeight(self))

    self:setVisible(wantsWindow())

    local pageX, pageY = tonumber(layout.dockedPageX), tonumber(layout.dockedPageY)
    self.dockedPageSpot = nil
    if pageX ~= nil and pageY ~= nil then
        self.dockedPageSpot = { x = pageX, y = pageY }
    end
end

function EquipWindow:SaveLayout(_name, layout)

    local live = self.width
    if self.docked and self.preferredWidth ~= nil then
        self.width = self.preferredWidth
    end
    ISLayoutManager.DefaultSaveWindow(self, layout)
    self.width = live

    local okPage, page = pcall(getPlayerInventory, self.playerNum)
    if self.docked and okPage and page ~= nil and not padOwns(self.playerNum) then
        layout.dockedPageX = page:getX()
        layout.dockedPageY = page:getY()
    else
        layout.dockedPageX = nil
        layout.dockedPageY = nil
    end
end

Style.onScaleChanged(function()
    for _, win in pairs(windows) do applySize(win) end
end)
