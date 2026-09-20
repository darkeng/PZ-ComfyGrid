--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.6
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Model/ContainerModel"
require "ComfyGrid/Model/Capacity"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
require "ComfyGrid/UI/ContainerPanel"
require "ComfyGrid/UI/Chrome/WindowStrip"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local Log = ComfyGrid.Core.Log
local ContainerModel = ComfyGrid.Model.ContainerModel
local Capacity = ComfyGrid.Model.Capacity
local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw
local ContainerPanel = ComfyGrid.UI.ContainerPanel
local WindowStrip = ComfyGrid.UI.Chrome.WindowStrip

local ContainerWindow = ISPanel:derive("ComfyContainerWindow")
ComfyGrid.UI.ContainerWindow = ContainerWindow

local windows = {}

local PAD = 6
local MIN_COLS, MAX_COLS = 4, 10

local lastError = nil
local function report(what, err)
    if err == lastError then return end
    lastError = err
    Log.error("ContainerWindow " .. what .. ": " .. tostring(err))
end

local SPEC = {
    left = {},
    right = {
        { id = "close", tex = function() return Draw.closeTexture() end,
          tipKey = "IGUI_ComfyGrid_ChipCloseTip", tipEN = "Close this window." },
    },
    actions = {},
}

function SPEC.actions.close(strip)
    local page = strip.page
    if page ~= nil then page:close() end
end

local function inventoryOf(item)
    if item == nil or not instanceof(item, "InventoryContainer") then return nil end
    if item.getInventory == nil then return nil end
    local ok, inv = pcall(item.getInventory, item)
    if not ok then return nil end
    return inv
end

ContainerWindow.inventoryOf = inventoryOf

function ContainerWindow.slotOf(playerNum, item)
    if item == nil then return nil end
    local CM = ComfyGrid.Model ~= nil and ComfyGrid.Model.ContainerModel or nil
    if CM == nil or CM.getPlayerMain == nil then return nil end
    local okM, model = pcall(CM.getPlayerMain, playerNum)
    if not okM or model == nil or model.grid == nil then return nil end
    local stacks = model.grid.data ~= nil and model.grid.data.stacks or nil
    if stacks == nil then return nil end
    local id = item:getID()
    for i = 1, #stacks do
        if stacks[i].itemIDs ~= nil and stacks[i].itemIDs[id] then
            return stacks[i].slot
        end
    end
    return nil
end

local function pageShowing(playerNum, cont)
    if cont == nil then return nil end
    for _, get in ipairs({ getPlayerInventory, getPlayerLoot }) do
        local okP, pg = pcall(get, playerNum)
        local pane = okP and pg ~= nil and pg.inventoryPane or nil
        local host = pane ~= nil and pane.comfyHost or nil
        if host ~= nil and host.showsInventory ~= nil then
            local okS, shown = pcall(host.showsInventory, host, cont)
            if okS and shown then return pg end
        end
    end
    return nil
end

local function sourceStillOnScreen(self)
    local inv = self.openedIn
    if inv == nil then return true end
    local seat = self.playerNum or 0
    for _, get in ipairs({ getPlayerInventory, getPlayerLoot }) do
        local okP, page = pcall(get, seat)
        local pane = okP and page ~= nil and page.inventoryPane or nil
        local host = pane ~= nil and pane.comfyHost or nil
        if host ~= nil and host.showsInventory ~= nil then
            local okS, shown = pcall(host.showsInventory, host, inv)
            if okS and shown then return true end
        end
    end
    if ContainerWindow.showsInventory ~= nil then
        local okC, shown = pcall(ContainerWindow.showsInventory, seat, inv)
        if okC and shown then return true end
    end
    return false
end

local function itemIsGone(item, playerNum)
    if item == nil then return true end
    local okC, cont = pcall(item.getContainer, item)
    if not okC or cont == nil then return true end
    local playerObj = playerNum ~= nil and getSpecificPlayer(playerNum) or nil
    if playerObj ~= nil then
        local okE, eq = pcall(playerObj.isEquipped, playerObj, item)
        if okE and eq then return true end
    end
    return false
end

local function colsFor(slots)
    local n = math.ceil(math.sqrt(math.max(1, slots or 1)))
    if n < MIN_COLS then n = MIN_COLS elseif n > MAX_COLS then n = MAX_COLS end
    return n
end

local function widthFor(inv)
    local slots = nil
    if Capacity ~= nil and Capacity.slotsFor ~= nil then
        local ok, n = pcall(Capacity.slotsFor, inv)
        if ok then slots = n end
    end
    return colsFor(slots) * Style.CELL_STRIDE + 2 * PAD
end

function ContainerWindow:new(playerNum)
    local o = ISPanel:new(0, 0, 200, 200)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.item = nil
    o.dragging = false

    o.keepOnScreen = false
    o.moveWithMouse = false
    o.background = false
    o.strip = nil
    o.content = nil
    return o
end

function ContainerWindow.titleBarHeight(_self)
    return Style.headerHeight()
end

function ContainerWindow:createChildren()
    ISPanel.createChildren(self)

    local panel = ContainerPanel:new(PAD, self:titleBarHeight(), nil,
        self.playerNum, true)
    panel:initialise()
    self:addChild(panel)
    self.content = panel

    local strip = WindowStrip:new(self, SPEC)
    strip:initialise()
    self:addChild(strip)
    self.strip = strip
end

function ContainerWindow.windowFor(playerNum)
    return windows[playerNum or 0]
end

function ContainerWindow.gridFor(playerNum)
    local win = windows[playerNum or 0]
    if win == nil or not win:getIsVisible() then return nil end
    local panel = win.content
    return panel ~= nil and panel.gridView or nil
end

function ContainerWindow.showsInventory(playerNum, inv)
    if inv == nil then return false end
    local win = windows[playerNum or 0]
    if win == nil or not win:getIsVisible() then return false end
    return inventoryOf(win.item) == inv
end

function ContainerWindow.closeFor(playerNum)
    local win = windows[playerNum or 0]
    if win == nil then return end
    win.item = nil
    win.ownerPage = nil
    win:setVisible(false)
end

function ContainerWindow:close()
    ContainerWindow.closeFor(self.playerNum)
end

function ContainerWindow.openFor(playerNum, item, anchorX, anchorY)
    playerNum = playerNum or 0
    local inv = inventoryOf(item)
    if inv == nil then return false end

    local win = windows[playerNum]
    if win == nil then
        win = ContainerWindow:new(playerNum)
        win:initialise()
        win:instantiate()
        win:addToUIManager()
        windows[playerNum] = win
    end
    win.item = item

    local okC, cont = pcall(item.getContainer, item)
    win.openedIn = okC and cont or nil
    win.openedSlot = ContainerWindow.slotOf(playerNum, item)

    local okPg, owner = pcall(pageShowing, playerNum, win.openedIn)
    local fallback = nil
    local okF, pg = pcall(getPlayerInventory, playerNum)
    if okF then fallback = pg end
    win.ownerPage = (okPg and owner) or fallback
    win:setWidth(widthFor(inv))
    win:setVisible(true)
    win:bringToTop()

    local Registry = ComfyGrid.UI.Chrome and ComfyGrid.UI.Chrome.PopupRegistry
    if Registry ~= nil and Registry.closeOthers ~= nil then
        pcall(Registry.closeOthers, nil)
    end

    win:setX(anchorX or win.x)
    win:setY(anchorY or win.y)
    win:clampToScreen()
    return true
end

function ContainerWindow:clampToScreen()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local x, y = self.x, self.y
    if x + self.width > sw then x = sw - self.width end
    if x < 0 then x = 0 end
    if y + self.height > sh then y = sh - self.height end
    if y < 0 then y = 0 end
    if x ~= self.x then self:setX(x) end
    if y ~= self.y then self:setY(y) end
end

local function prerenderImpl(self)
    local panel = self.content
    if panel == nil then return end

    local page = self.ownerPage
    if page == nil then
        local okP, pg = pcall(getPlayerInventory, self.playerNum)
        page = okP and pg or nil
    end
    if page == nil or not page:getIsVisible() then
        return ContainerWindow.closeFor(self.playerNum)
    end

    if page.isCollapsed then
        return ContainerWindow.closeFor(self.playerNum)
    end

    local inv = inventoryOf(self.item)
    if inv == nil then return ContainerWindow.closeFor(self.playerNum) end
    if itemIsGone(self.item, self.playerNum) then
        return ContainerWindow.closeFor(self.playerNum)
    end

    if sourceStillOnScreen(self) then
        self._offScreenFrames = nil
    else
        self._offScreenFrames = (self._offScreenFrames or 0) + 1
        if self._offScreenFrames >= 2 then
            return ContainerWindow.closeFor(self.playerNum)
        end
    end

    local okC, cont = pcall(self.item.getContainer, self.item)
    if okC and cont ~= self.openedIn then
        return ContainerWindow.closeFor(self.playerNum)
    end
    local slot = ContainerWindow.slotOf(self.playerNum, self.item)
    if slot ~= self.openedSlot then
        return ContainerWindow.closeFor(self.playerNum)
    end

    local model = ContainerModel.getOrCreate(inv, self.playerNum)
    if model == nil then return end
    if panel.model ~= model then panel:setModel(model) end

    local band = self:titleBarHeight()
    local innerW = self.width - 2 * PAD
    if panel.width ~= innerW then panel:setWidth(innerW) end
    if panel.x ~= PAD then panel:setX(PAD) end
    if panel.y ~= band then panel:setY(band) end

    local wantH = band + panel.height + PAD
    if wantH > 0 and self.height ~= wantH then
        self:setHeight(wantH)
        self:clampToScreen()
    end

    local strip = self.strip
    if strip ~= nil then
        if strip.width ~= self.width then strip:setWidth(self.width) end
        if strip.y ~= 0 then strip:setY(0) end
    end

    if Draw.shadow ~= nil then
        local spread = math.max(6, math.floor(8 * (Style.SCALE or 1)))
        Draw.shadow(self, 0, 0, self.width, self.height, spread, 0.35)
    end

    local sf = Style.COLORS and Style.COLORS.SURFACE
    if sf ~= nil then
        self:drawRect(0, 0, self.width, self.height, 0.95,
            sf.bg.r, sf.bg.g, sf.bg.b)
    end
end

function ContainerWindow:prerender()
    local ok, err = pcall(prerenderImpl, self)
    if not ok then report("prerender", err) end
end

function ContainerWindow:render()
    local sf = Style.COLORS and Style.COLORS.SURFACE
    if sf == nil or sf.line == nil then return end
    self:drawRectBorder(0, 0, self.width, self.height, 0.9,
        sf.line.r, sf.line.g, sf.line.b)
end

function ContainerWindow.isMouseOverIt(playerNum)
    local win = windows[playerNum or 0]
    if win == nil or not win:getIsVisible() then return false end
    local mx, my = getMouseX(), getMouseY()
    return mx >= win.x and mx < win.x + win.width
        and my >= win.y and my < win.y + win.height
end

function ContainerWindow:onMouseDown(_x, y)
    if y <= self:titleBarHeight() then
        self.dragging = true
        self:bringToTop()
    end

    return true
end

function ContainerWindow:onMouseUp(_x, _y)
    self.dragging = false
    return true
end

function ContainerWindow:onMouseMove(dx, dy)
    if not self.dragging then return true end
    self:setX(self.x + dx)
    self:setY(self.y + dy)
    self:clampToScreen()
    return true
end

function ContainerWindow:onMouseUpOutside(_x, _y)
    self.dragging = false
    return true
end
