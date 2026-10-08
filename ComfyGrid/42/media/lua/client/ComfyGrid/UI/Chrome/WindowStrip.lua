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
require "ComfyGrid/UI/Draw"
require "ComfyGrid/UI/Chrome/Chip"
require "ComfyGrid/UI/Chrome/SearchField"
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

    { id = "layout", tex = function() return Draw.layersTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipLayoutSectionsTip",
      tipEN = "Show every container within reach.",
      tipFor = function(_page)
          local Settings = ComfyGrid.Settings
          local layout = Settings ~= nil and Settings.get ~= nil
              and Settings.get("LOOT_LAYOUT") or nil
          if layout == "sections" then
              return "IGUI_ComfyGrid_ChipLayoutSingleTip",
                  "Show one container at a time."
          end
          return "IGUI_ComfyGrid_ChipLayoutSectionsTip",
              "Show every container within reach."
      end,

      when = function(page) return page.onCharacter ~= true end,

      active = function(_page)
          local Settings = ComfyGrid.Settings
          return Settings ~= nil and Settings.get ~= nil
              and Settings.get("LOOT_LAYOUT") == "sections"
      end },

    { id = "equip", tex = function() return Draw.personTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipEquipTip",
      tipEN = "Show the equipment window.",
      tipFor = function(page)
          local EquipWindow = ComfyGrid.UI and ComfyGrid.UI.EquipWindow
          local view = EquipWindow ~= nil and EquipWindow.viewOf ~= nil
              and EquipWindow.viewOf(page.player) or "strip"
          if view == "strip" then
              return "IGUI_ComfyGrid_ChipEquipTip", "Show the equipment window."
          elseif view == "window" then
              return "IGUI_ComfyGrid_ChipEquipOffTip",
                  "Turn the equipment off - another mod shows it."
          end
          return "IGUI_ComfyGrid_ChipEquipBackTip",
              "Put equipment back in the inventory."
      end,
      when = function(page) return page.onCharacter == true end,
      active = function(page)
          local EquipWindow = ComfyGrid.UI and ComfyGrid.UI.EquipWindow
          return EquipWindow ~= nil and EquipWindow.isOn ~= nil
              and EquipWindow.isOn(page.player) == true
      end },

    { id = "settings", tex = function() return Draw.gearTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipSettingsTip",
      tipEN = "Comfy Grid settings.",
      when = function(page) return page.onCharacter == true end },
}

local DEFAULT_SPEC = { left = LEFT_CHIPS, right = RIGHT_CHIPS, search = true }

local function chipWanted(def, page)
    return def.when == nil or def.when(page) == true
end

local tips = {}
local function tipOf(def, page)
    local tipKey, tipEnglish = def.tipKey, def.tipEN
    if def.tipFor ~= nil then
        local ok, stateTipKey, stateTipEnglish = pcall(def.tipFor, page)
        if ok and stateTipKey ~= nil then
            tipKey, tipEnglish = stateTipKey, stateTipEnglish
        end
    end
    if tipKey == nil then return nil end
    local tipText = tips[tipKey]
    if tipText == nil then
        tipText = Text.tr(tipKey, tipEnglish)
        tips[tipKey] = tipText
    end
    return tipText
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

    local bandHeight = page.titleBarHeight ~= nil and page:titleBarHeight()
        or WindowStrip.height()
    if self.height ~= bandHeight then self:setHeight(bandHeight) end
    local bandWidth = page.width or self.width
    if self.width ~= bandWidth then self:setWidth(bandWidth) end

    hideVanillaButtons(page)

    local Pad = ComfyGrid.Interact and ComfyGrid.Interact.PadFocus
    local padSlot = Pad ~= nil and Pad.cursorFor ~= nil and Pad.cursorFor(self)
        or nil
    local padId = padSlot ~= nil and self:padChipAt(padSlot) or nil
    self.chips:clear()
    self.chipsLeft:clear()
    self.chips.padHot = padId
    self.chipsLeft.padHot = padId

    local surface = Style.COLORS and Style.COLORS.SURFACE
    if surface == nil then return end

    self:drawRect(0, 0, self.width, self.height, 1, surface.panel.r,
        surface.panel.g, surface.panel.b)
    self:drawRect(0, self.height - 1, self.width, 1, 0.85, surface.line.r,
        surface.line.g, surface.line.b)

    local right = self.spec.right or RIGHT_CHIPS
    self.chips:reset(self.width - PAD, 0, self.height)
    for i = 1, #right do
        local def = right[i]
        if chipWanted(def, page) then
            local isActive = def.active ~= nil and def.active(page) or false
            self.chips:add(def.id, def.tex(), tipOf(def, page), isActive)
        end
    end
    local left = self.spec.left or LEFT_CHIPS
    self.chipsLeft:resetLeft(PAD, 0, self.height)
    for i = 1, #left do
        local def = left[i]
        if chipWanted(def, page) then
            self.chipsLeft:add(def.id, def.tex(), tipOf(def, page))
        end
    end
    if self.spec.search then self:layoutSearchField() end
end

function WindowStrip:layoutSearchField()
    local chrome = ComfyGrid.UI.Chrome
    local SearchField = chrome ~= nil and chrome.SearchField or nil
    if SearchField == nil then return end
    local field = self.searchField
    if field == nil then
        field = SearchField:new(self.page)
        field:initialise()
        self:addChild(field)
        self.searchField = field
        SearchField.register(self.page, field)
    end
    field:applyPendingTerm()
    field:layoutIn(self, PAD + self.chipsLeft.consumed,
        self.width - PAD - self.chips.consumed)
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
    local toggle = page.pin and page.collapse or page.setPinned
    if toggle == nil then return end
    local ok, err = pcall(toggle, page)
    if not ok then Log.warn("WindowStrip: pin failed: " .. tostring(err)) end
end

function ACTIONS.layout(_self)
    local Settings = ComfyGrid.Settings
    if Settings == nil or Settings.get == nil or Settings.set == nil then return end

    local nextLayout = "sections"
    if Settings.get("LOOT_LAYOUT") == "sections" then nextLayout = "single" end
    local ok, err = pcall(Settings.set, "LOOT_LAYOUT", nextLayout)
    if not ok then
        Log.warn("WindowStrip: layout failed: " .. tostring(err))
        return
    end

    if Settings.save ~= nil then pcall(Settings.save) end
end

function ACTIONS.equip(self)
    local page = self.page
    local EquipWindow = ComfyGrid.UI and ComfyGrid.UI.EquipWindow
    if page == nil or EquipWindow == nil or EquipWindow.toggle == nil then
        return
    end
    local ok, err = pcall(EquipWindow.toggle, page.player)
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

function WindowStrip:chipAt(x, y)
    return self.chips:hit(x, y) or self.chipsLeft:hit(x, y)
end

function WindowStrip:onMouseDown(x, y)

    local field = self.searchField
    self.pressBeganOnPlate = field ~= nil and field:plateContains(x, y)
    if self.pressBeganOnPlate then return true end
    return self:chipAt(x, y) ~= nil
end

function WindowStrip:onMouseUpOutside(_x, _y)
    self.pressBeganOnPlate = false
    return false
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
    local leftCount = self.chipsLeft.count
    if slot < leftCount then return self.chipsLeft:idAt(slot + 1) end
    return self.chips:idAt(self.chips.count - (slot - leftCount))
end

function WindowStrip:padActivateChip(slot)
    self:activateChip(self:padChipAt(slot))
end

function WindowStrip:onMouseUp(x, y)

    local field = self.searchField
    local pressBeganOnPlate = self.pressBeganOnPlate
    self.pressBeganOnPlate = false
    if pressBeganOnPlate and field ~= nil and field:plateContains(x, y) then
        if field:clearContains(x, y) then
            field:clearSearch()
        else
            field:focus()
        end
        return true
    end

    local id = self:chipAt(x, y)
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
