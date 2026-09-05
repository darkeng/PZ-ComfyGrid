--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
require "ComfyGrid/UI/Chrome/Chip"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
ComfyGrid.UI.Chrome = ComfyGrid.UI.Chrome or {}
local WindowStrip = ISUIElement:derive("ComfyWindowStrip")
ComfyGrid.UI.Chrome.WindowStrip = WindowStrip

local Log = ComfyGrid.Core.Log
local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw
local Chip = ComfyGrid.UI.Chrome.Chip
local Text = ComfyGrid.Core.Text

local PAD = 6

local LEFT_CHIPS = {
    { id = "close", tex = function() return Draw.closeTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipCloseTip", tipEN = "Close this window." },
}

local RIGHT_CHIPS = {

    { id = "pin", tex = function() return Draw.pinTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipPinTip",
      tipEN = "Keep this window open.",
      active = function(page) return page.pin == true end },

    { id = "equip", tex = function() return Draw.personTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipEquipTip",
      tipEN = "Show the equipment window.",
      when = function(page) return page.onCharacter == true end,
      active = function(page)
          local W = ComfyGrid.UI and ComfyGrid.UI.EquipWindow
          return W ~= nil and W.isOpen ~= nil and W.isOpen(page.player) == true
      end },
    { id = "settings", tex = function() return Draw.gearTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipSettingsTip",
      tipEN = "Comfy Grid settings.",
      when = function(page) return page.onCharacter == true end },
}

local DEFAULT_SPEC = { left = LEFT_CHIPS, right = RIGHT_CHIPS }

local function chipWanted(def, page)
    return def.when == nil or def.when(page) == true
end

local tips = {}
local function tipOf(def)
    local t = tips[def.id]
    if t == nil then
        t = Text.tr(def.tipKey, def.tipEN)
        tips[def.id] = t
    end
    return t
end

local VANILLA_BUTTONS = {
    "closeButton", "infoButton", "pinButton", "collapseButton",
}

local function hideVanillaButtons(page)
    for i = 1, #VANILLA_BUTTONS do
        local btn = page[VANILLA_BUTTONS[i]]
        if btn ~= nil and btn.getIsVisible ~= nil and btn:getIsVisible() then
            btn:setVisible(false)
        end
    end
end

function WindowStrip.height()
    return Style.headerHeight()
end

function WindowStrip:new(page, spec)
    local o = ISUIElement:new(0, 0, page ~= nil and page.width or 1,
        WindowStrip.height())
    setmetatable(o, self)
    self.__index = self
    o.page = page
    o.spec = spec or DEFAULT_SPEC

    o.playerNum = page ~= nil and (page.player or page.playerNum) or nil
    o.keepOnScreen = false
    o.chips = Chip.newRow(o)
    o.chipsLeft = Chip.newRow(o)
    return o
end

function WindowStrip:prerender()
    local page = self.page
    if page == nil then return end

    local h = page.titleBarHeight ~= nil and page:titleBarHeight()
        or WindowStrip.height()
    if self.height ~= h then self:setHeight(h) end
    local w = page.width or self.width
    if self.width ~= w then self:setWidth(w) end

    hideVanillaButtons(page)

    local Pad = ComfyGrid.Interact and ComfyGrid.Interact.PadFocus
    local padSlot = Pad ~= nil and Pad.cursorFor ~= nil and Pad.cursorFor(self)
        or nil
    local padId = padSlot ~= nil and self:padChipAt(padSlot) or nil
    self.chips:clear()
    self.chipsLeft:clear()
    self.chips.padHot = padId
    self.chipsLeft.padHot = padId

    local sf = Style.COLORS and Style.COLORS.SURFACE
    if sf == nil then return end

    self:drawRect(0, 0, self.width, self.height, 1, sf.panel.r, sf.panel.g,
        sf.panel.b)
    self:drawRect(0, self.height - 1, self.width, 1, 0.85, sf.line.r,
        sf.line.g, sf.line.b)

    local right = self.spec.right or RIGHT_CHIPS
    self.chips:reset(self.width - PAD, 0, self.height)
    for i = 1, #right do
        local def = right[i]
        if chipWanted(def, page) then
            local on = def.active ~= nil and def.active(page) or false
            self.chips:add(def.id, def.tex(), tipOf(def), on)
        end
    end
    local left = self.spec.left or LEFT_CHIPS
    self.chipsLeft:resetLeft(PAD, 0, self.height)
    for i = 1, #left do
        local def = left[i]
        if chipWanted(def, page) then
            self.chipsLeft:add(def.id, def.tex(), tipOf(def))
        end
    end
end

local ACTIONS = {}

function ACTIONS.close(self)
    local page = self.page
    if page == nil or page.close == nil then return end
    local ok, err = pcall(page.close, page)
    if not ok then Log.warn("WindowStrip: close failed: " .. tostring(err)) end
end

function ACTIONS.pin(self)
    local page = self.page
    if page == nil then return end
    local fn = page.pin and page.collapse or page.setPinned
    if fn == nil then return end
    local ok, err = pcall(fn, page)
    if not ok then Log.warn("WindowStrip: pin failed: " .. tostring(err)) end
end

function ACTIONS.equip(self)
    local page = self.page
    local W = ComfyGrid.UI and ComfyGrid.UI.EquipWindow
    if page == nil or W == nil or W.toggle == nil then return end
    local ok, err = pcall(W.toggle, page.player)
    if not ok then
        Log.warn("WindowStrip: equipment window failed: " .. tostring(err))
    end
end

function ACTIONS.settings(self)
    local Chrome = ComfyGrid.UI and ComfyGrid.UI.Chrome
    local Popup = Chrome ~= nil and Chrome.SettingsPopup or nil
    if Popup == nil or Popup.toggleFor == nil then return end
    local ok, err = pcall(Popup.toggleFor, self)
    if not ok then
        Log.warn("WindowStrip: settings popup failed: " .. tostring(err))
    end
end

function WindowStrip:onChip(x, y)
    return self.chips:hit(x, y) ~= nil or self.chipsLeft:hit(x, y) ~= nil
end

function WindowStrip:onMouseDown(x, y)
    return self:onChip(x, y)
end

function WindowStrip:activateChip(id)
    if id == nil then return end
    local action = (self.spec.actions or ACTIONS)[id]
    if action ~= nil then action(self) end
end

function WindowStrip:padChipCount()
    return self.chipsLeft.count + self.chips.count
end

function WindowStrip:padChipAt(slot)
    local l = self.chipsLeft.count
    if slot < l then return self.chipsLeft:idAt(slot + 1) end
    return self.chips:idAt(self.chips.count - (slot - l))
end

function WindowStrip:padActivateChip(slot)
    self:activateChip(self:padChipAt(slot))
end

function WindowStrip:onMouseUp(x, y)

    local id = self.chips:hit(x, y) or self.chipsLeft:hit(x, y)
    if id == nil then return false end
    self:activateChip(id)
    return true
end

function WindowStrip:onRightMouseDown(_x, _y)
    return false
end

function WindowStrip:onRightMouseUp(_x, _y)
    return false
end
