--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.5.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Core/Notify"
require "ComfyGrid/Model/Capacity"
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
local ContainerStatus = ComfyGrid.Model.ContainerStatus
local Style = ComfyGrid.UI.Style
local Draw = ComfyGrid.UI.Draw
local Chip = ComfyGrid.UI.Chrome.Chip
local SectionRule = ComfyGrid.UI.Chrome.SectionRule
local GridView = ComfyGrid.UI.GridView

local SECTION_TEXT = SectionRule.TEXT
local SECTION_LINE = SectionRule.LINE

local Text = ComfyGrid.Core.Text

local CHIPS = {
    { id = "sort", tex = function() return Draw.sortTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipSortTip",
      tipEN = "Sort this container by category." },
    { id = "stow", tex = function() return Draw.stowTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipStowTip",
      tipEN = "Bring in more of what this container holds." },

    { id = "spread", tex = function() return Draw.spreadTexture() end,
      tipKey = "IGUI_ComfyGrid_ChipSpreadTip",
      tipEN = "Spread these among the containers that hold their kind." },

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
    local hot = self.chips.hotId
    if hot ~= nil and PREVIEW_CHIPS[hot] and self.model ~= nil then
        local Bulk = ComfyGrid.Interact and ComfyGrid.Interact.BulkTransfer
        local pane = self.parent ~= nil and self.parent.pane or nil
        if Bulk ~= nil and pane ~= nil then
            local list, map = Bulk.plan(hot, self.model.inventory,
                self.playerNum)

            if map ~= nil and list ~= nil and #list > 0 then
                Highlight.publish(pane, self, map)
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
    local row = self.chips
    row:reset(rightX, y, h)
    for i = 1, #CHIPS do
        local def = CHIPS[i]
        if def.when == nil or def.when(self) then
            row:add(def.id, def.tex(), chipTip(def))
        end
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
        local tm = getTextManager and getTextManager() or nil
        local ok, w = pcall(tm.MeasureStringX, tm, Style.FONT, WEIGHT_TEMPLATE)
        weightCol = (ok and type(w) == "number") and w or 57
        weightColGen = metricsGen
    end
    return weightCol
end

local HEADER_PAD = 4

local function fmtWeight(cur, max)
    local c = string.format("%.1f", cur)
    c = c:gsub("%.0$", "")
    return c .. "/" .. tostring(math.floor(max + 0.5))
end

local function headerHeight()
    return math.max(18, Style.FONT_H + 4, math.floor(Style.CELL / 2))
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
    local OV = ComfyGrid.Interact and ComfyGrid.Interact.ObjectVerbs
    if OV == nil or self.model == nil then return nil end
    local verbs = OV.of(self.model.inventory, self.playerNum)

    local trash = isTrashable(self)
    if verbs == nil and not trash then return nil end

    seenGen = seenGen + 1
    local n, overflow = 0, 0
    for i = 1, (verbs ~= nil and #verbs or 0) do
        local g = OV.glyphFor(verbs[i].key)

        local tex = g ~= nil and seenGlyph[g] ~= seenGen
            and Draw.glyphTexture(g) or nil
        if tex ~= nil then
            seenGlyph[g] = seenGen
            n = n + 1
            pick[n], pickTex[n] = i, tex
        else
            overflow = overflow + 1
        end
    end

    local gg = groupGap()

    local avail = transferLeft - gg - HEADER_PAD
    local extra = (trash and 1 or 0)
    local total = n + ((overflow > 0) and 1 or 0) + extra
    while n > 0 and Chip.groupWidth(total, h) > avail do
        n = n - 1
        overflow = overflow + 1
        total = n + 1 + extra
    end
    if total == 0 then return nil end
    local w = Chip.groupWidth(total, h)

    local maxLeft = transferLeft - gg - w
    if maxLeft < HEADER_PAD then return nil end

    local centre = math.floor((HEADER_PAD + nameMin() + transferLeft) / 2)
    local left = math.max(HEADER_PAD,
        math.min(centre - math.floor(w / 2), maxLeft))

    local row = self.actions
    row:resetLeft(left, y, h)
    if trash then row:add("trash", Draw.trashTexture(), trashTip()) end

    local chipped = self._chipped
    if chipped == nil then
        chipped = {}
        self._chipped = chipped
    end
    self._chippedGen = seenGen
    for i = 1, n do
        local e = verbs[pick[i]]

        row:add(chipIdFor(e.key), pickTex[i], e.label, e.active)
        chipped[e.key] = seenGen
    end
    if overflow > 0 then
        row:add("verbs", Draw.moreTexture(), actionsTip())
    end
    if row.count == 0 then return nil end

    local ruleX = math.floor((left + w + transferLeft) / 2)
    local inset = math.max(2, math.floor(h / 5))
    self:drawRect(ruleX, y + inset, 1, h - inset * 2, SECTION_LINE.a,
        SECTION_LINE.r, SECTION_LINE.g, SECTION_LINE.b)
    return left, left + w
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

    local invType = inventory:getType()
    return getTextOrNull("IGUI_ContainerTitle_" .. invType) or invType
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
    end
end

function ContainerPanel:new(x, y, model, playerNum)

    local o = ISPanel:new(x, y, 1, headerHeight() + 1)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
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
    local gv = GridView:new(0, headerHeight(), self.model, self.playerNum)
    gv.compactEligible = true
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

function ContainerPanel:prerender()

    local Pad = ComfyGrid.Interact and ComfyGrid.Interact.PadFocus
    local padSlot = Pad ~= nil and Pad.cursorFor ~= nil and Pad.cursorFor(self)
        or nil
    local padId = padSlot ~= nil and self:padChipAt(padSlot) or nil
    self.chips:clear()
    self.actions:clear()
    self.chips.padHot = padId
    self.actions.padHot = padId

    local headerH = headerHeight()
    local gridTop = headerH
    local gv = self.gridView
    if gv then

        gv:setAvailableWidth(self.width)
        if gv.x ~= 0 then gv:setX(0) end
        if gv.y ~= gridTop then gv:setY(gridTop) end
        local h = gridTop + gv.height
        if self.height ~= h then self:setHeight(h) end
    end

    local tm = getTextManager()
    local wtText = nil
    local inv = self.model ~= nil and self.model.inventory or nil
    if inv ~= nil then
        local cur, cmax = nil, nil
        local okC, c = pcall(inv.getCapacityWeight, inv)
        if okC and type(c) == "number" then cur = c end
        local playerObj = self.playerNum ~= nil
            and getSpecificPlayer(self.playerNum) or nil
        if playerObj ~= nil and inv == playerObj:getInventory() then
            local okM, m = pcall(playerObj.getMaxWeight, playerObj)
            if okM and type(m) == "number" then cmax = m end
        else

            cmax = Capacity.effectiveFor(inv, self.playerNum)
        end
        if cur ~= nil and cmax ~= nil then
            local key = math.floor(cur * 10 + 0.5) * 1000 + cmax
            if self._wtKey ~= key or self._wtGen ~= metricsGen then
                self._wtKey = key
                self._wtGen = metricsGen
                self._wtText = fmtWeight(cur, cmax)

            end
            wtText = self._wtText
        end
    end
    do

        local fontHgt = tm:getFontHeight(Style.FONT)
        local textY = math.floor((headerH - fontHgt) / 2)

        local gutter = wtText ~= nil and weightGutter() or 0
        if wtText ~= nil then
            self:drawTextRight(wtText, self.width - HEADER_PAD,
                textY, SECTION_TEXT.r, SECTION_TEXT.g, SECTION_TEXT.b,
                SECTION_TEXT.a, Style.FONT)
        end
        local rightPad = gutter + (wtText ~= nil and weightMargin() or 0)
        rightPad = rightPad + drawChips(self,
            self.width - HEADER_PAD - rightPad, 0, headerH)

        local transferLeft = self.width - HEADER_PAD - rightPad
        local budgetRight = transferLeft
        local actionsLeft = drawActions(self, transferLeft, 0, headerH)
        if actionsLeft ~= nil then budgetRight = actionsLeft - 6 end

        local shown = self.headerName
        local status = ContainerStatus ~= nil and self.model ~= nil
            and ContainerStatus.of(self.model.inventory) or nil
        if shown ~= nil and status ~= nil then
            shown = shown .. ": " .. status
        end
        local nameW = 0
        if shown then

            local fitKey = self.width * 10000 + math.floor(budgetRight)
            if self._nameFitKey ~= fitKey or self._nameFitGen ~= metricsGen
                    or self._nameFitText ~= shown then
                self._nameFitKey = fitKey
                self._nameFitGen = metricsGen
                self._nameFitText = shown
                self._nameFit = Text.fitEllipsis(shown, Style.FONT,
                    budgetRight - HEADER_PAD, 60)
                local okW, npx = pcall(tm.MeasureStringX, tm, Style.FONT,
                    self._nameFit)
                self._nameFitW = okW and npx or 0
            end
            self:drawText(self._nameFit, HEADER_PAD, textY,
                SECTION_TEXT.r, SECTION_TEXT.g, SECTION_TEXT.b,
                SECTION_TEXT.a, Style.FONT)
            nameW = self._nameFitW or 0
        end
        local lineX = HEADER_PAD + nameW + 6
        local lineW = budgetRight - lineX
        if lineW > 0 then
            self:drawRect(lineX, textY + math.floor(fontHgt / 2), lineW, 1,
                SECTION_LINE.a, SECTION_LINE.r, SECTION_LINE.g,
                SECTION_LINE.b)
        end
    end
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

function CHIP_ACTIONS.stow(self)

    local Bulk = ComfyGrid.Interact and ComfyGrid.Interact.BulkTransfer
    if Bulk == nil or Bulk.stow == nil then return end
    local ok, outcome = pcall(Bulk.stow, self.model, self.playerNum)
    if not ok then
        Log.warn("ContainerPanel: stow failed: " .. tostring(outcome))
        Notify.bad(self.playerNum,
            Text.tr("IGUI_ComfyGrid_ChipStowFailed",
                "Could not bring anything."))
        return
    end

    Bulk.report(outcome, self.playerNum, "stow")
end

function CHIP_ACTIONS.empty(self)
    local Bulk = ComfyGrid.Interact and ComfyGrid.Interact.BulkTransfer
    if Bulk == nil or Bulk.empty == nil then return end
    local ok, outcome = pcall(Bulk.empty, self.model, self.playerNum)
    if not ok then
        Log.warn("ContainerPanel: empty failed: " .. tostring(outcome))
        Notify.bad(self.playerNum,
            Text.tr("IGUI_ComfyGrid_ChipEmptyFailed",
                "Could not send anything."))
        return
    end
    Bulk.report(outcome, self.playerNum, "empty")
end

function CHIP_ACTIONS.trash(self)
    local Bulk = ComfyGrid.Interact and ComfyGrid.Interact.BulkTransfer
    if Bulk == nil or Bulk.emptyTrash == nil then return end
    local ok, outcome = pcall(Bulk.emptyTrash, self.model, self.playerNum)
    if not ok then
        Log.warn("ContainerPanel: empty bin failed: " .. tostring(outcome))
        Notify.bad(self.playerNum,
            Text.tr("IGUI_ComfyGrid_ChipTrashFailed",
                "Could not empty this bin."))
        return
    end
    Bulk.report(outcome, self.playerNum, "trash")
end

function CHIP_ACTIONS.spread(self)
    local Bulk = ComfyGrid.Interact and ComfyGrid.Interact.BulkTransfer
    if Bulk == nil or Bulk.spread == nil then return end
    local ok, outcome = pcall(Bulk.spread, self.model, self.playerNum)
    if not ok then
        Log.warn("ContainerPanel: spread failed: " .. tostring(outcome))
        Notify.bad(self.playerNum,
            Text.tr("IGUI_ComfyGrid_ChipSpreadFailed",
                "Could not spread anything."))
        return
    end
    Bulk.report(outcome, self.playerNum, "spread")
end

function CHIP_ACTIONS.floor(self)
    local Bulk = ComfyGrid.Interact and ComfyGrid.Interact.BulkTransfer
    if Bulk == nil or Bulk.dropToFloor == nil then return end
    local ok, outcome = pcall(Bulk.dropToFloor, self.model, self.playerNum)
    if not ok then
        Log.warn("ContainerPanel: drop to floor failed: " .. tostring(outcome))
        Notify.bad(self.playerNum,
            Text.tr("IGUI_ComfyGrid_ChipFloorFailed",
                "Could not drop anything."))
        return
    end
    Bulk.report(outcome, self.playerNum, "floor")
end

function ContainerPanel:onMouseDown(_x, _y)
    return true
end

local function openActions(self)
    local OV = ComfyGrid.Interact and ComfyGrid.Interact.ObjectVerbs
    if OV == nil or ISContextMenu == nil or self.model == nil then return end
    local verbs = OV.of(self.model.inventory, self.playerNum)
    if verbs == nil then return end

    local r = self.actions:rectOf("verbs")
    local ax = self:getAbsoluteX() + (r ~= nil and r.x or 0)
    local ay = self:getAbsoluteY() + (r ~= nil and (r.y + r.s + 4) or 0)
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
    OV.fillMenu(rest, context)

    local CM = ComfyGrid.Interact and ComfyGrid.Interact.ContextMenu
    if CM ~= nil and CM.handOff ~= nil then
        local host = self.parent
        local pane = host ~= nil and host.pane or nil
        CM.handOff(self.playerNum, context,
            pane ~= nil and pane.inventoryPage or nil)
    end
end

local function performVerb(self, key)
    local OV = ComfyGrid.Interact and ComfyGrid.Interact.ObjectVerbs
    if OV == nil then return end
    local verbs = OV.of(self.model.inventory, self.playerNum)
    if verbs == nil then return end
    for i = 1, #verbs do
        if verbs[i].key == key then
            local r = self.actions:rectOf(chipIdFor(key))
            OV.perform(verbs[i],
                self:getAbsoluteX() + (r ~= nil and r.x or 0),
                self:getAbsoluteY() + (r ~= nil and r.y or 0),
                r ~= nil and r.s or 0)
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
    local a = self.actions.count
    if slot < a then return self.actions:idAt(slot + 1) end
    return self.chips:idAt(self.chips.count - (slot - a))
end

function ContainerPanel:padActivateChip(slot)
    self:activateChip(self:padChipAt(slot))
end

function ContainerPanel:onMouseUp(x, y)
    if self.model ~= nil then
        self:activateChip(self.chips:hit(x, y) or self.actions:hit(x, y))
    end
    return true
end
