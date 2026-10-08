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
require "ComfyGrid/Core/Notify"
require "ComfyGrid/Model/Capacity"
require "ComfyGrid/Model/ContainerName"
require "ComfyGrid/Model/ContainerStatus"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/Draw"
require "ComfyGrid/UI/Chrome/Chip"
require "ComfyGrid/UI/Chrome/SectionRule"
require "ComfyGrid/UI/GridView"
require "ComfyGrid/Interact/SortContainer"
require "ComfyGrid/Interact/BulkTransfer"
require "ComfyGrid/Interact/ObjectVerbs"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local ContainerPanel = ISPanel:derive("ComfyContainerPanel")
ComfyGrid.UI.ContainerPanel = ContainerPanel

local Capacity = ComfyGrid.Model.Capacity
local Log = ComfyGrid.Core.Log
local Notify = ComfyGrid.Core.Notify
local ContainerName = ComfyGrid.Model.ContainerName
local ContainerStatus = ComfyGrid.Model.ContainerStatus
local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw
local Chip = ComfyGrid.UI.Chrome.Chip
local SectionRule = ComfyGrid.UI.Chrome.SectionRule
local GridView = ComfyGrid.UI.GridView

local SECTION_TEXT = SectionRule.TEXT
local SECTION_LINE = SectionRule.LINE
local SECTION_TEXT_HI = SectionRule.TEXT_HI
local SECTION_LINE_HI = SectionRule.LINE_HI

local Text = ComfyGrid.Core.Text

local CHIPS = {
    { id = "sort", tex = function() return Draw.sortTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipSortTip",

      tipEN = "Sort this container." },
    { id = "stow", tex = function() return Draw.stowTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipStowTip",
      tipEN = "Bring in more of what this container holds." },

    { id = "spread", tex = function() return Draw.spreadTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipSpreadTip",

      tipEN = "Put each thing away where you already keep it." },

    { id = "empty", tex = function() return Draw.emptyTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipEmptyTip",
      tipEN = "Send everything to the other side." },
    { id = "floor", tex = function() return Draw.floorTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipFloorTip",
      tipEN = "Drop everything on the floor." },
}

local function isTrashable(panel)
    local Bulk = ComfyGrid.Interact and ComfyGrid.Interact.BulkTransfer
    if Bulk == nil or Bulk.trashObjectFor == nil then return false end
    return panel.model ~= nil
        and Bulk.trashObjectFor(panel.model.inventory) ~= nil
end

local chipTips = {}
local function chipTip(def)
    local tip = chipTips[def.id]
    if tip == nil then
        tip = Text.tr(def.tipKey, def.tipEN)
        chipTips[def.id] = tip
    end
    return tip
end

local PREVIEW_CHIPS = { stow = true, spread = true, empty = true, floor = true }

local function syncPreview(self)
    local Highlight = ComfyGrid.Interact and ComfyGrid.Interact.Highlight
    if Highlight == nil then return end
    local hotChipId = self.chips.hotId
    if hotChipId ~= nil and PREVIEW_CHIPS[hotChipId] and self.model ~= nil then
        local Bulk = ComfyGrid.Interact and ComfyGrid.Interact.BulkTransfer
        local pane = self.parent ~= nil and self.parent.pane or nil
        if Bulk ~= nil and pane ~= nil then
            local planItems, planMap = Bulk.plan(hotChipId, self.model.inventory,
                self.playerNum)

            if planMap ~= nil and planItems ~= nil and #planItems > 0 then
                Highlight.publish(pane, self, planMap)
                self._previewing = true
                return
            end
        end
    end

    if self._previewing then
        Highlight.release(self)
        self._previewing = false
    end
end

local function drawChips(self, rightX, y, h)

    if self.noChips then return 0 end
    local row = self.chips
    row:reset(rightX, y, h)
    for i = 1, #CHIPS do
        local def = CHIPS[i]
        row:add(def.id, def.tex(), chipTip(def))
    end
    return row.consumed
end

local metricsGen = 0
Style.onScaleChanged(function()
    metricsGen = metricsGen + 1
end)

local WEIGHT_TEMPLATE = "999.9/999"
local WEIGHT_MARGIN = 12

local function weightMargin()
    return math.max(4, math.floor(WEIGHT_MARGIN * (Style.SCALE or 1) + 0.5))
end
local weightCol, weightColGen = 0, -1

local function weightGutter()
    if weightColGen ~= metricsGen then
        local textManager = getTextManager and getTextManager() or nil
        local okWidth, templateW = pcall(textManager.MeasureStringX,
            textManager, Style.FONT, WEIGHT_TEMPLATE)
        weightCol = (okWidth and type(templateW) == "number") and templateW or 57
        weightColGen = metricsGen
    end
    return weightCol
end

local HEADER_PAD = 4

local function isActiveSection(self)
    local model = self.model
    local inv = model ~= nil and model.inventory or nil
    if inv == nil then return false end
    local host = self.parent
    local pane = host ~= nil and host.pane or nil
    if pane == nil then return false end
    local page = pane.inventoryPage
    local selected = page ~= nil and page.inventory or pane.inventory
    return selected ~= nil and selected == inv
end

local function selectableSection(self)
    local model = self.model
    local inv = model ~= nil and model.inventory or nil
    if inv == nil then return nil end
    local host = self.parent
    local pane = host ~= nil and host.pane or nil
    local page = pane ~= nil and pane.inventoryPage or nil
    local buttons = page ~= nil and page.backpacks or nil
    if type(buttons) ~= "table" then return nil end
    for i = 1, #buttons do
        local button = buttons[i]
        if button ~= nil and button.inventory == inv then return page, button end
    end
    return nil
end

local function selectZoneAt(self, x, y)
    local zoneW = self._selectZoneW
    local zoneH = self._selectZoneH
    if zoneW == nil or zoneH == nil or zoneW <= 0 then return false end
    return x >= 0 and x < zoneW and y >= 0 and y < zoneH
end

local function selectZoneHot(self, active)
    if self.isMouseOver == nil or not self:isMouseOver() then return false end
    if not active and selectableSection(self) then
        return selectZoneAt(self, self:getMouseX(), self:getMouseY())
    end
    return false
end

local GROUP_GAP = 16
local NAME_MIN = 62

local function groupGap()
    return math.max(6, math.floor(GROUP_GAP * (Style.SCALE or 1) + 0.5))
end
local function nameMin()
    return math.floor(NAME_MIN * (Style.SCALE or 1) + 0.5)
end

local trashTipText = nil
local function trashTip()
    if trashTipText == nil then
        trashTipText = Text.tr("IGUI_ComfyGrid_ChipTrashTip",
            "Empty this bin for good.")
    end
    return trashTipText
end

local actionsTipText = nil
local function actionsTip()
    if actionsTipText == nil then
        actionsTipText = Text.tr("IGUI_ComfyGrid_ChipActionsTip",
            "What this object can do.")
    end
    return actionsTipText
end

local seenGlyph, pick, pickTex = {}, {}, {}
local seenGen = 0

local verbChipId = {}
local function chipIdFor(key)
    local id = verbChipId[key]
    if id == nil then
        id = "verb:" .. key
        verbChipId[key] = id
    end
    return id
end

local function drawActions(self, transferLeft, y, h)

    if self.noChips then return nil end
    local ObjectVerbs = ComfyGrid.Interact and ComfyGrid.Interact.ObjectVerbs
    if ObjectVerbs == nil or self.model == nil then return nil end
    local verbs = ObjectVerbs.of(self.model.inventory, self.playerNum)

    local trash = isTrashable(self)
    if verbs == nil and not trash then return nil end

    seenGen = seenGen + 1
    local chipCount, overflow = 0, 0
    for i = 1, (verbs ~= nil and #verbs or 0) do
        local glyph = ObjectVerbs.glyphFor(verbs[i].key)

        local tex = glyph ~= nil and seenGlyph[glyph] ~= seenGen
            and Draw.glyphTexture(glyph) or nil
        if tex ~= nil then
            seenGlyph[glyph] = seenGen
            chipCount = chipCount + 1
            pick[chipCount], pickTex[chipCount] = i, tex
        else
            overflow = overflow + 1
        end
    end

    local gap = groupGap()
    local leftPad = SectionRule.pad()

    local avail = transferLeft - gap - leftPad
    local extra = (trash and 1 or 0)
    local total = chipCount + ((overflow > 0) and 1 or 0) + extra
    while chipCount > 0 and Chip.groupWidth(total, h) > avail do
        chipCount = chipCount - 1
        overflow = overflow + 1
        total = chipCount + 1 + extra
    end
    if total == 0 then return nil end
    local groupW = Chip.groupWidth(total, h)

    local maxLeft = transferLeft - gap - groupW
    if maxLeft < leftPad then return nil end

    local centre = math.floor((leftPad + nameMin() + transferLeft) / 2)
    local left = math.max(leftPad,
        math.min(centre - math.floor(groupW / 2), maxLeft))

    local row = self.actions
    row:resetLeft(left, y, h)
    if trash then row:add("trash", Draw.trashTexture(), trashTip()) end

    local chipped = self._chipped
    if chipped == nil then
        chipped = {}
        self._chipped = chipped
    end
    self._chippedGen = seenGen
    for i = 1, chipCount do
        local verb = verbs[pick[i]]

        row:add(chipIdFor(verb.key), pickTex[i], verb.label, verb.active)
        chipped[verb.key] = seenGen
    end
    if overflow > 0 then
        row:add("verbs", Draw.moreTexture(), actionsTip())
    end
    if row.count == 0 then return nil end

    local ruleX = math.floor((left + groupW + transferLeft) / 2)
    local inset = math.max(2, math.floor(h / 5))
    self:drawRect(ruleX, y + inset, 1, h - inset * 2, SECTION_LINE.a,
        SECTION_LINE.r, SECTION_LINE.g, SECTION_LINE.b)
    return left, left + groupW
end

local function resolveDisplayName(inventory, playerNum)
    if not inventory then return "?" end

    local containing = inventory:getContainingItem()
    if containing then
        local name = containing:getName()
        if name then return name end
    end

    local playerObj = playerNum ~= nil and getSpecificPlayer(playerNum) or nil
    if playerObj and inventory == playerObj:getInventory() then
        return getText("IGUI_InventoryTooltip")
    end

    local okParent, parent = pcall(inventory.getParent, inventory)
    if okParent and parent ~= nil and inventory.getCustomName ~= nil then
        local okC, custom = pcall(inventory.getCustomName, inventory)
        if okC and custom ~= nil and custom ~= "" then return custom end
    end

    return ContainerName.titleFor(inventory)
end

local function applyModel(self, model)

    local Highlight = ComfyGrid.Interact and ComfyGrid.Interact.Highlight
    if Highlight ~= nil then
        Highlight.release(self)
        self._previewing = false
    end
    self.model = model
    self.headerName = nil
    self._wtKey = nil
    self._wtText = nil
    self._nameFitKey = nil
    self._nameFit = nil
    if model then

        local ok, name = pcall(resolveDisplayName, model.inventory, self.playerNum)
        self.headerName = (ok and name) or "?"
        self._nameGen = ContainerName.renameGeneration()
    end
end

function ContainerPanel:new(x, y, model, playerNum, noChips)

    local o = ISPanel:new(x, y, 1, Style.headerHeight() + 1)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.noChips = noChips == true
    o.gridView = nil

    o.background = false

    o.keepOnScreen = false

    o.chips = Chip.newRow(o)

    o.actions = Chip.newRow(o)
    applyModel(o, model)
    return o
end

function ContainerPanel:createChildren()
    if not self.gridView then
        self:_buildGridView()
    end
end

function ContainerPanel:_buildGridView()
    if not self.model then return end
    local gv = GridView:new(0, Style.headerHeight(), self.model, self.playerNum)
    gv.spareSlotsEligible = true
    gv:initialise()
    self:addChild(gv)
    self.gridView = gv
end

function ContainerPanel:setModel(model)
    if model == self.model then return end
    applyModel(self, model)
    if self.gridView then
        self:removeChild(self.gridView)
        self.gridView = nil
    end
    self:_buildGridView()
end

local function resetChipRows(self)
    local PadFocus = ComfyGrid.Interact and ComfyGrid.Interact.PadFocus
    local padSlot = PadFocus ~= nil and PadFocus.cursorFor ~= nil
        and PadFocus.cursorFor(self) or nil
    local padId = padSlot ~= nil and self:padChipAt(padSlot) or nil
    self.chips:clear()
    self.actions:clear()
    self.chips.padHot = padId
    self.actions.padHot = padId
end

local function syncGridBox(self, gridTop)
    local gv = self.gridView
    if not gv then return end
    gv:setAvailableWidth(self.width)
    if gv.x ~= 0 then gv:setX(0) end
    if gv.y ~= gridTop then gv:setY(gridTop) end
    local panelH = gridTop + gv.height
    if self.height ~= panelH then self:setHeight(panelH) end
end

local function loadFigureText(self)
    local inv = self.model ~= nil and self.model.inventory or nil
    if inv == nil then return nil end
    local cmax = nil

    local grid = self.model.grid
    local cur = Capacity.weightOf(inv, grid ~= nil and grid.changeCount or nil)
    local playerObj = self.playerNum ~= nil
        and getSpecificPlayer(self.playerNum) or nil
    if playerObj ~= nil and inv == playerObj:getInventory() then
        local okMax, maxWeight = pcall(playerObj.getMaxWeight, playerObj)
        if okMax and type(maxWeight) == "number" then cmax = maxWeight end
    else

        cmax = Capacity.effectiveFor(inv, self.playerNum)
    end
    if cur == nil or cmax == nil then return nil end
    local key = math.floor(cur * 10 + 0.5) * 1000 + cmax
    if self._wtKey ~= key or self._wtGen ~= metricsGen then
        self._wtKey = key
        self._wtGen = metricsGen
        self._wtText = Text.formatLoad(cur, cmax)

    end
    return self._wtText
end

local function drawHeaderPlate(self, active, headerH)
    if active then
        SectionRule.plate(self, 0, headerH, true)
        SectionRule.activeBar(self, 0, headerH)
    elseif selectZoneHot(self, active) then
        SectionRule.plate(self, 0, headerH, false)
    end
end

local function drawFigureAndChips(self, wtText, textY, textColor, headerH)
    local gutter = wtText ~= nil and weightGutter() or 0
    if wtText ~= nil then
        self:drawTextRight(wtText, self.width - HEADER_PAD,
            textY, textColor.r, textColor.g, textColor.b, textColor.a,
            Style.FONT)
    end
    local rightPad = gutter + (wtText ~= nil and weightMargin() or 0)
    return rightPad + drawChips(self,
        self.width - HEADER_PAD - rightPad, 0, headerH)
end

local function refreshRenamedTitle(self)
    local nameGen = ContainerName.renameGeneration()
    if self._nameGen == nameGen then return end
    self._nameGen = nameGen
    if self.model ~= nil then
        local okN, freshName = pcall(resolveDisplayName,
            self.model.inventory, self.playerNum)
        if okN and freshName ~= nil then self.headerName = freshName end
    end
end

local function headerTextWithStatus(self)
    local headerText = self.headerName
    local status = ContainerStatus ~= nil and self.model ~= nil
        and ContainerStatus.of(self.model.inventory) or nil
    if headerText ~= nil and status ~= nil then
        if self._statusTitleName ~= headerText
                or self._statusTitleStatus ~= status then
            self._statusTitleName = headerText
            self._statusTitleStatus = status
            self._statusTitle = headerText .. ": " .. status
        end
        headerText = self._statusTitle
    end
    return headerText
end

local function drawFittedName(self, headerText, budgetRight, leftPad, textY,
        textColor, textManager)
    if not headerText then return 0 end
    local fitKey = self.width * 10000 + math.floor(budgetRight)
    if self._nameFitKey ~= fitKey or self._nameFitGen ~= metricsGen
            or self._nameFitText ~= headerText then
        self._nameFitKey = fitKey
        self._nameFitGen = metricsGen
        self._nameFitText = headerText
        self._nameFit = Text.fitEllipsis(headerText, Style.FONT,
            budgetRight - leftPad, 60)
        local okWidth, nameWidth = pcall(textManager.MeasureStringX,
            textManager, Style.FONT, self._nameFit)
        self._nameFitW = okWidth and nameWidth or 0
    end
    self:drawText(self._nameFit, leftPad, textY,
        textColor.r, textColor.g, textColor.b, textColor.a, Style.FONT)
    return self._nameFitW or 0
end

local function drawHeaderRule(self, lineX, lineRight, lineY, lineColor)
    local lineW = lineRight - lineX
    if lineW > 0 then
        self:drawRect(lineX, lineY, lineW, 1,
            lineColor.a, lineColor.r, lineColor.g, lineColor.b)
    end
end

local function publishSelectZone(self, budgetRight, headerH)
    self._selectZoneW = budgetRight
    self._selectZoneH = headerH
end

local function drawHeader(self, headerH, wtText, active, textManager)

    local fontHgt = textManager:getFontHeight(Style.FONT)
    local textY = math.floor((headerH - fontHgt) / 2)
    local textColor = active and SECTION_TEXT_HI or SECTION_TEXT
    local lineColor = active and SECTION_LINE_HI or SECTION_LINE
    drawHeaderPlate(self, active, headerH)
    local leftPad = SectionRule.pad()
    local rightPad = drawFigureAndChips(self, wtText, textY, textColor, headerH)

    local transferLeft = self.width - HEADER_PAD - rightPad
    local budgetRight = transferLeft
    local actionsLeft = drawActions(self, transferLeft, 0, headerH)
    if actionsLeft ~= nil then budgetRight = actionsLeft - 6 end
    refreshRenamedTitle(self)
    local headerText = headerTextWithStatus(self)
    local nameW = drawFittedName(self, headerText, budgetRight, leftPad, textY,
        textColor, textManager)
    drawHeaderRule(self, leftPad + nameW + 6, budgetRight,
        textY + math.floor(fontHgt / 2), lineColor)
    publishSelectZone(self, budgetRight, headerH)
end

function ContainerPanel:prerender()

    resetChipRows(self)

    local headerH = Style.headerHeight()
    syncGridBox(self, headerH)
    local textManager = getTextManager()
    local wtText = loadFigureText(self)

    local active = isActiveSection(self)
    self._activeSection = active
    drawHeader(self, headerH, wtText, active, textManager)
    syncPreview(self)
end

local CHIP_ACTIONS = {}

function CHIP_ACTIONS.sort(self)

    local Sort = ComfyGrid.Interact and ComfyGrid.Interact.SortContainer
    if Sort == nil or Sort.run == nil then return end

    local ok, result = pcall(Sort.run, self.model)
    if not ok then
        Log.warn("ContainerPanel: sort failed: " .. tostring(result))
        Notify.bad(self.playerNum,
            Text.tr("IGUI_ComfyGrid_SortFailed", "Could not sort this container."))
        return
    end

    if result == Sort.NO_CHANGE then
        Notify.say(self.playerNum,
            Text.tr("IGUI_ComfyGrid_SortNoChange", "Already sorted."))
    elseif result == Sort.BUSY then
        Notify.say(self.playerNum,
            Text.tr("IGUI_ComfyGrid_ChipBusy",
                "Still moving things - try again in a moment."))
    elseif result ~= Sort.OK then
        Notify.bad(self.playerNum,
            Text.tr("IGUI_ComfyGrid_SortFailed", "Could not sort this container."))
    end
end

local function runBulkVerb(self, verbName, what, failText, reportId)
    local Bulk = ComfyGrid.Interact and ComfyGrid.Interact.BulkTransfer
    if Bulk == nil or Bulk[verbName] == nil then return end
    local ok, outcome = pcall(Bulk[verbName], self.model, self.playerNum)
    if not ok then
        Log.warn("ContainerPanel: " .. what .. " failed: " .. tostring(outcome))
        Notify.bad(self.playerNum, Text.tr(failText[1], failText[2]))
        return
    end
    Bulk.report(outcome, self.playerNum, reportId)
end

local STOW_FAILED = { "IGUI_ComfyGrid_ChipStowFailed",
    "Could not bring anything." }
function CHIP_ACTIONS.stow(self)
    runBulkVerb(self, "stow", "stow", STOW_FAILED, "stow")
end

local EMPTY_FAILED = { "IGUI_ComfyGrid_ChipEmptyFailed",
    "Could not send anything." }
function CHIP_ACTIONS.empty(self)
    runBulkVerb(self, "empty", "empty", EMPTY_FAILED, "empty")
end

local TRASH_FAILED = { "IGUI_ComfyGrid_ChipTrashFailed",
    "Could not empty this bin." }
function CHIP_ACTIONS.trash(self)
    runBulkVerb(self, "emptyTrash", "empty bin", TRASH_FAILED, "trash")
end

local SPREAD_FAILED = { "IGUI_ComfyGrid_ChipSpreadFailed",
    "Could not put anything away." }
function CHIP_ACTIONS.spread(self)
    runBulkVerb(self, "spread", "spread", SPREAD_FAILED, "spread")
end

local FLOOR_FAILED = { "IGUI_ComfyGrid_ChipFloorFailed",
    "Could not drop anything." }
function CHIP_ACTIONS.floor(self)
    runBulkVerb(self, "dropToFloor", "drop to floor", FLOOR_FAILED, "floor")
end

function ContainerPanel.onMouseDown(_self, _x, _y)
    return true
end

local function drawSearchRing(self)
    local ItemSearch = ComfyGrid.Model and ComfyGrid.Model.ItemSearch or nil
    local SlotRenderer = ComfyGrid.UI and ComfyGrid.UI.SlotRenderer or nil
    if ItemSearch == nil or SlotRenderer == nil then return end
    local marks = ItemSearch.marksFor(self.playerNum)
    if not ItemSearch.marksContainer(marks, self.model.inventory) then return end
    SlotRenderer.drawSearchBox(self, 0, 0, self.width, Style.headerHeight(),
        SlotRenderer.applyPulse(), false)
end

function ContainerPanel:render()
    if self.model == nil then return end
    drawSearchRing(self)
    if not self._activeSection then return end
    SectionRule.card(self, 0, 0, self.width, self.height)
end

local function openActions(self)
    local ObjectVerbs = ComfyGrid.Interact and ComfyGrid.Interact.ObjectVerbs
    if ObjectVerbs == nil or ISContextMenu == nil or self.model == nil then
        return
    end
    local verbs = ObjectVerbs.of(self.model.inventory, self.playerNum)
    if verbs == nil then return end

    local chipRect = self.actions:rectOf("verbs")
    local ax = self:getAbsoluteX() + (chipRect ~= nil and chipRect.x or 0)
    local ay = self:getAbsoluteY()
        + (chipRect ~= nil and (chipRect.y + chipRect.s + 4) or 0)
    local ok, context = pcall(ISContextMenu.get, self.playerNum, ax, ay)
    if not ok or context == nil then
        Log.warn("ContainerPanel: could not open the actions menu")
        return
    end

    local chipped = self._chipped
    local gen = self._chippedGen
    local rest = verbs
    if chipped ~= nil and gen ~= nil then
        rest = {}
        for i = 1, #verbs do
            if chipped[verbs[i].key] ~= gen then rest[#rest + 1] = verbs[i] end
        end
        if #rest == 0 then rest = verbs end
    end
    ObjectVerbs.fillMenu(rest, context)

    local ContextMenu = ComfyGrid.Interact and ComfyGrid.Interact.ContextMenu
    if ContextMenu ~= nil and ContextMenu.handOff ~= nil then
        local host = self.parent
        local pane = host ~= nil and host.pane or nil
        ContextMenu.handOff(self.playerNum, context,
            pane ~= nil and pane.inventoryPage or nil)
    end
end

local function performVerb(self, key)
    local ObjectVerbs = ComfyGrid.Interact and ComfyGrid.Interact.ObjectVerbs
    if ObjectVerbs == nil then return end
    local verbs = ObjectVerbs.of(self.model.inventory, self.playerNum)
    if verbs == nil then return end
    for i = 1, #verbs do
        if verbs[i].key == key then
            local chipRect = self.actions:rectOf(chipIdFor(key))
            ObjectVerbs.perform(verbs[i],
                self:getAbsoluteX() + (chipRect ~= nil and chipRect.x or 0),
                self:getAbsoluteY() + (chipRect ~= nil and chipRect.y or 0),
                chipRect ~= nil and chipRect.s or 0)
            return
        end
    end
end

function ContainerPanel:activateChip(id)
    if id == nil or self.model == nil then return end
    local action = CHIP_ACTIONS[id]
    if action ~= nil then
        action(self)
        return
    end
    if id == "verbs" then
        openActions(self)
        return
    end
    local key = string.match(id, "^verb:(.+)$")
    if key ~= nil then performVerb(self, key) end
end

function ContainerPanel:padChipCount()
    return self.actions.count + self.chips.count
end

function ContainerPanel:padChipAt(slot)
    local actionCount = self.actions.count
    if slot < actionCount then return self.actions:idAt(slot + 1) end
    return self.chips:idAt(self.chips.count - (slot - actionCount))
end

function ContainerPanel:padActivateChip(slot)
    self:activateChip(self:padChipAt(slot))
end

function ContainerPanel:selectMe()
    if isActiveSection(self) then return false end
    local page, button = selectableSection(self)
    if page == nil then return false end
    page:selectContainer(button)
    return true
end

function ContainerPanel:onMouseUp(x, y)
    if self.model ~= nil then
        local id = self.chips:hit(x, y) or self.actions:hit(x, y)
        if id ~= nil then
            self:activateChip(id)
        elseif selectZoneAt(self, x, y) then
            self:selectMe()
        end
    end
    return true
end
