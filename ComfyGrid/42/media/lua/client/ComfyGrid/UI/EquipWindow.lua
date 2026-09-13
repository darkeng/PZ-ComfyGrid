--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.7.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Prefs"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Settings"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
require "ComfyGrid/UI/Chrome/WindowStrip"
require "ComfyGrid/UI/Avatar"
require "ComfyGrid/UI/EquipmentStrip"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local Prefs = ComfyGrid.Core.Prefs
local Text = ComfyGrid.Core.Text
local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw
local WindowStrip = ComfyGrid.UI.Chrome.WindowStrip
local Avatar = ComfyGrid.UI.Avatar
local EquipmentStrip = ComfyGrid.UI.EquipmentStrip

local EquipWindow = ISPanel:derive("ComfyEquipWindow")
ComfyGrid.UI.EquipWindow = EquipWindow

local windows = {}

local MODDATA_KEY = "ComfyGrid_EquipWindow"
local LAYOUT_ID = "ComfyGridEquipWindow"

local function padOwns(playerNum)
    if JoypadState == nil or JoypadState.players == nil then return false end
    return JoypadState.players[(playerNum or 0) + 1] ~= nil
end

local function settings()
    return ComfyGrid.Settings
end

local function wantsWindow()
    local S = settings()
    if S == nil or S.get == nil then return false end
    return S.get("EQUIPMENT_VIEW") == "window"
end

local function setView(view)
    local S = settings()
    if S == nil or S.set == nil then return end
    S.set("EQUIPMENT_VIEW", view)
    if S.save ~= nil then S.save() end
end

local FIGURE_TILES = 3

local COL_GAP = 4
local PAD = 6
local SHADOW_SPREAD = 12
local SHADOW_ALPHA = 0.45

local function figureWidth()
    return FIGURE_TILES * Style.CELL
end

local function sideColumn()
    return Style.CELL_STRIDE + COL_GAP
end

local function defaultWidth()
    return figureWidth() + 2 * sideColumn() + 2 * PAD
end

local function defaultHeight(trayRows)
    return Style.headerHeight() + PAD
        + EquipmentStrip.anchorsHeight(Avatar.heightFor(figureWidth()), trayRows)
        + PAD
end

local function wantedHeight(win)
    local strip = win ~= nil and win.content or nil
    return defaultHeight(strip ~= nil and strip.trayRows or 0)
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
    local ok, md = pcall(playerObj.getModData, playerObj)
    if not ok or md == nil then return nil end
    local st = md[MODDATA_KEY]
    if type(st) ~= "table" then
        st = { docked = true }
        md[MODDATA_KEY] = st
    end
    return st
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
    local w, h = defaultWidth(), defaultHeight(0)
    local o = ISPanel:new(0, 0, w, h)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.pin = true
    o.isCollapsed = false
    o.collapseCounter = 0

    o.preferredWidth = w
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

    local band = WindowStrip:new(self, CHIP_SPEC)
    band:initialise()
    self:addChild(band)
    self.strip = band
end

local function flushLootPage(playerNum, page)
    local ok, data = pcall(getPlayerData, playerNum)
    if not ok or data == nil then return nil end
    local loot = data.lootInventory
    if loot == nil or loot.getIsVisible == nil or not loot:getIsVisible() then
        return nil
    end
    local gap = loot:getX() - (page:getX() + page:getWidth())
    if gap < -2 or gap > 2 then return nil end
    return loot
end

local function makeRoom(self, page)
    local prev = type(self.push) == "table" and self.push or nil

    if prev ~= nil and prev.page ~= nil and prev.page:getX() ~= prev.pageX then
        prev = nil
    end
    self.pushWidth = self.preferredWidth or self.width
    self.push = prev or false
    local left = getPlayerScreenLeft ~= nil
        and getPlayerScreenLeft(self.playerNum) or 0
    local screenW = getPlayerScreenWidth ~= nil
        and getPlayerScreenWidth(self.playerNum) or 0
    local short = (self.preferredWidth or self.width) - (page:getX() - left) - 1
    if short <= 0 or screenW <= 0 then return end
    local loot = flushLootPage(self.playerNum, page)
    local rightMost = loot ~= nil and (loot:getX() + loot:getWidth())
        or (page:getX() + page:getWidth())
    local slack = (left + screenW) - rightMost

    if short > slack then return end
    page:setX(page:getX() + short)
    if loot ~= nil then loot:setX(loot:getX() + short) end

    self.push = { page = page, pageX = page:getX(),
        amount = short + (prev ~= nil and prev.amount or 0),
        loot = loot, lootX = loot ~= nil and loot:getX() or nil }
end

local function giveBackRoom(self)
    local p = self.push
    self.push = nil
    self.pushWidth = nil
    if type(p) ~= "table" then return end
    if p.page ~= nil and p.page:getX() == p.pageX then
        p.page:setX(p.pageX - p.amount)
    end
    if p.loot ~= nil and p.loot:getX() == p.lootX then
        p.loot:setX(p.lootX - p.amount)
    end
end

local function screenRect(playerNum)
    local left = getPlayerScreenLeft ~= nil
        and getPlayerScreenLeft(playerNum) or 0
    local top = getPlayerScreenTop ~= nil
        and getPlayerScreenTop(playerNum) or 0
    local w = getPlayerScreenWidth ~= nil
        and getPlayerScreenWidth(playerNum) or 0
    local h = getPlayerScreenHeight ~= nil
        and getPlayerScreenHeight(playerNum) or 0
    return left, top, w, h
end

local function placePage(page, x, width)
    if page == nil then return end
    if page:getX() ~= x then page:setX(x) end
    if width > 0 and page:getWidth() ~= width then page:setWidth(width) end
end

local function padRestore(page)
    local playerNum = page.player
    local left, _, w = screenRect(playerNum)
    if w <= 0 then return end
    local half = math.floor(w / 2)
    placePage(page, left, half)
    local ok, loot = pcall(getPlayerLoot, playerNum)
    if ok and loot ~= nil and loot ~= page then
        placePage(loot, left + half, w - half)
    end
end

local function padSplit(self, page)
    local playerNum = self.playerNum
    local left, _, w = screenRect(playerNum)
    local mid = self.preferredWidth or self.width
    if w <= 0 or mid <= 0 or w - mid < 200 then

        return false
    end
    local half = math.floor((w - mid) / 2)
    placePage(page, left, half)
    local ok, loot = pcall(getPlayerLoot, playerNum)
    if ok and loot ~= nil and loot ~= page then
        placePage(loot, left + half + mid, w - half - mid)
    end

    self.dockSide = "centre"
    if self.width ~= mid then self:setWidth(mid) end
    if self.x ~= left + half then self:setX(left + half) end
    local y = page:getY()
    if self.y ~= y then self:setY(y) end
    return true
end

local function dockTo(self, page)

    if self.preferredWidth ~= nil and self.width ~= self.preferredWidth then
        self:setWidth(self.preferredWidth)
    end
    local left = getPlayerScreenLeft ~= nil
        and getPlayerScreenLeft(self.playerNum) or 0
    local top = getPlayerScreenTop ~= nil
        and getPlayerScreenTop(self.playerNum) or 0
    local x = page:getX() - self.width + 1
    local y = page:getY()
    if x >= left then
        self.dockSide = "left"
    else
        local above = page:getY() - self.height + 1
        if above >= top then

            self.dockSide, x, y = "above", page:getX(), above
        else

            self.dockSide, x, y = "above", page:getX(), top
        end
    end
    if self.x ~= x then self:setX(x) end
    if self.y ~= y then self:setY(y) end
end

local function clampOnScreen(self)
    local left = getPlayerScreenLeft ~= nil
        and getPlayerScreenLeft(self.playerNum) or 0
    local top = getPlayerScreenTop ~= nil
        and getPlayerScreenTop(self.playerNum) or 0
    local w = getPlayerScreenWidth ~= nil
        and getPlayerScreenWidth(self.playerNum) or 0
    local h = getPlayerScreenHeight ~= nil
        and getPlayerScreenHeight(self.playerNum) or 0
    local band = self:titleBarHeight()
    local x = self.x
    if x < left then x = left end
    if w > 0 and x + self.width > left + w then
        x = left + w - self.width
        if x < left then x = left end
    end
    local y = self.y
    if y < top then y = top end
    if h > 0 and y + band > top + h then y = top + h - band end
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
    local st = stateOf(self.playerNum)
    if st ~= nil then st.pin = self.pin end
    if self.pin then self:uncollapse() end
end

function EquipWindow:setDocked(docked)
    self.docked = docked and true or false
    local st = stateOf(self.playerNum)
    if st ~= nil then st.docked = self.docked end

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
    local st = stateOf(playerNum)
    win.docked = st == nil or st.docked ~= false
    win.pin = st == nil or st.pin ~= false

    if playerNum == 0 and ISLayoutManager ~= nil then
        pcall(ISLayoutManager.RegisterWindow, LAYOUT_ID, EquipWindow, win)
    end
    windows[playerNum] = win
    return win
end

function EquipWindow.windowFor(playerNum)
    return windows[playerNum]
end

function EquipWindow.isOpen(_playerNum)
    return wantsWindow()
end

function EquipWindow.viewOf(_playerNum)
    local S = settings()
    local v = (S ~= nil and S.get ~= nil) and S.get("EQUIPMENT_VIEW") or nil
    if v == "window" or v == "off" then return v end
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
    local next_ = NEXT_VIEW[EquipWindow.viewOf(playerNum)] or "window"
    if next_ ~= "off" then return setView(next_) end
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
            if pad then padRestore(page) end
            return
        end
        win = EquipWindow.getOrCreate(playerNum)
    end
    local split = false
    if pad then

        win.docked = true
        if win.push ~= nil then giveBackRoom(win) end
        if wanted then
            split = padSplit(win, page)
        else
            padRestore(page)
        end
    elseif wanted and win.docked then

        local grew = win.pushWidth ~= nil
            and (win.preferredWidth or win.width) > win.pushWidth
        if win.push == nil or grew then makeRoom(win, page) end
    elseif win.push ~= nil then
        giveBackRoom(win)
    end
    if win:getIsVisible() ~= showing then
        win:setVisible(showing)
        if showing then win:bringToTop() end
    end

    if showing and win.docked and not split then dockTo(win, page) end
end

local function prerenderImpl(self)

    local ok, page = pcall(getPlayerInventory, self.playerNum)
    if not ok or page == nil or not page:getIsVisible() then
        self:setVisible(false)
        return
    end

    local band = self.strip
    local bandH = self:titleBarHeight()

    if Draw ~= nil and Draw.shadow ~= nil and not self.docked then
        local spread = math.max(6,
            math.floor(SHADOW_SPREAD * (Style.SCALE or 1)))
        Draw.shadow(self, 0, 0, self.width, self.height, spread, SHADOW_ALPHA)
    end

    local sf = Style.COLORS and Style.COLORS.SURFACE
    if sf ~= nil then
        self:drawRect(0, 0, self.width, self.height, 0.95, sf.bg.r, sf.bg.g,
            sf.bg.b)
    end

    if band ~= nil then
        if band.width ~= self.width then band:setWidth(self.width) end
        if band.y ~= 0 then band:setY(0) end
    end

    local innerY = bandH + PAD
    local innerW = self.width - PAD * 2

    local col = sideColumn()
    local span = innerW - col * 2
    local figW = figureWidth()
    if figW > span then figW = span end
    if figW < Style.CELL then figW = Style.CELL end
    local figX = math.floor((innerW - figW) / 2)
    local figY = EquipmentStrip.anchorsTop()
    local figH = Avatar.heightFor(figW)

    local content = self.content
    if content ~= nil then
        if content.x ~= PAD then content:setX(PAD) end
        if content.y ~= innerY then content:setY(innerY) end
        if content.setAvailableWidth ~= nil then
            content:setAvailableWidth(innerW)
        end
        if content.setFigureBox ~= nil then
            content:setFigureBox(figX, figY, figW, figH)
        end
    end

    local av = self.avatar
    if av ~= nil then
        local ax, ay = PAD + figX, innerY + figY
        if not av:getIsVisible() then av:setVisible(true) end
        if av.x ~= ax then av:setX(ax) end
        if av.y ~= ay then av:setY(ay) end
        if av.width ~= figW then av:setWidth(figW) end
        if av.height ~= figH then av:setHeight(figH) end
    end

    local wantH = wantedHeight(self)
    if wantH ~= nil and self.height ~= wantH then self:setHeight(wantH) end
end

function EquipWindow:prerender()
    local ok, err = pcall(prerenderImpl, self)
    if not ok then report("prerender", err) end
end

function EquipWindow:render()
    local sf = Style.COLORS and Style.COLORS.SURFACE
    if sf == nil then return end

    local h = self.isCollapsed and self:titleBarHeight() or self.height
    self:drawRectBorder(0, 0, self.width, h, 0.85, sf.line.r, sf.line.g,
        sf.line.b)
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

function EquipWindow:onMouseMove(dx, dy)

    if not isMouseButtonDown(0) and not isMouseButtonDown(1)
            and not isMouseButtonDown(2) then
        self.collapseCounter = 0
        if self.isCollapsed and self:getMouseY() < self:titleBarHeight() then
            self:uncollapse()
        end
    end
    if not self.dragging then return end
    self:setX(self.x + dx)
    self:setY(self.y + dy)
    clampOnScreen(self)
end

function EquipWindow:onMouseMoveOutside(dx, dy)
    if self.dragging then
        self:setX(self.x + dx)
        self:setY(self.y + dy)
        clampOnScreen(self)
        return
    end
    if self.docked or self.pin or self.isCollapsed then return end

    if ISMouseDrag ~= nil and ISMouseDrag.dragging ~= nil then return end
    if overPage(self) then
        self.collapseCounter = 0
        return
    end

    local gt = getGameTime()
    self.collapseCounter = self.collapseCounter
        + gt:getMultiplier() / gt:getTrueMultiplier() / 0.8
    if self.collapseCounter > 120 then self:collapseNow() end
end

function EquipWindow:RestoreLayout(_name, layout)
    ISLayoutManager.DefaultRestoreWindow(self, layout)

    self.preferredWidth = defaultWidth()
    self:setWidth(self.preferredWidth)
    self:setHeight(wantedHeight(self))

    self:setVisible(wantsWindow())
end

function EquipWindow:SaveLayout(_name, layout)

    local live = self.width
    if self.docked and self.preferredWidth ~= nil then
        self.width = self.preferredWidth
    end
    ISLayoutManager.DefaultSaveWindow(self, layout)
    self.width = live
end

Style.onScaleChanged(function()
    for _, win in pairs(windows) do
        win.preferredWidth = defaultWidth()
        if not win.docked then win:setWidth(win.preferredWidth) end
        win:setHeight(wantedHeight(win))
    end
end)
