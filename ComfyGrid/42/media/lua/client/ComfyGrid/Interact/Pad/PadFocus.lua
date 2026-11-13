--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Util"
require "ComfyGrid/Core/Input"
require "ComfyGrid/UI/Style"
require "ComfyGrid/Interact/Pad/PadMove"
require "ComfyGrid/Interact/Pad/PadBeam"
require "ComfyGrid/Interact/Pad/PadTargets"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local PadFocus = {}
ComfyGrid.Interact.PadFocus = PadFocus

local Util = ComfyGrid.Core.Util
local Input = ComfyGrid.Core.Input
local Style = ComfyGrid.UI.Style
local PadMove = ComfyGrid.Interact.PadMove
local PadBeam = ComfyGrid.Interact.PadBeam
local PadTargets = ComfyGrid.Interact.PadTargets

local states = {}
local SLOT_MEMORY = 64

local function stateFor(playerNum)
    local seatState = states[playerNum]
    if seatState == nil then
        seatState = { active = false, page = nil, win = {} }
        states[playerNum] = seatState
    end
    return seatState
end

local function handFocus(seatState, playerNum, page)
    if not Input.padOwns(playerNum) then return end
    seatState.handoff = page
    setJoypadFocus(playerNum, page)
end

local function winState(seatState, page)
    local windowCursor = seatState.win[page]
    if windowCursor == nil then
        windowCursor = { el = nil, kind = nil, slot = 0, slotIn = {}, remembered = 0 }
        seatState.win[page] = windowCursor
    end
    return windowCursor
end

local function rememberSlot(windowCursor, node, slot)
    if node.kind ~= "grid" and node.kind ~= "pocket" then return end
    local model = node.el.model
    local container = model ~= nil and model.inventory or nil
    if container == nil then return end
    if windowCursor.slotIn[container] == nil then
        if windowCursor.remembered >= SLOT_MEMORY then
            windowCursor.slotIn = {}
            windowCursor.remembered = 0
        end
        windowCursor.remembered = windowCursor.remembered + 1
    end
    windowCursor.slotIn[container] = slot
end

local function hostOf(page)
    local pane = page ~= nil and page.inventoryPane or nil
    return pane ~= nil and pane.comfyHost or nil
end

local function addTitleBandNode(nodes, page)
    local band = page._comfyStrip
    if band ~= nil and band:getIsVisible() and band.padChipCount ~= nil then
        nodes[#nodes + 1] = { kind = "chip", el = band, panel = page,
            fixed = true }
    end
end

local function addPlayerStripNodes(nodes, strips)
    if strips == nil then return end

    if strips.equipStrip ~= nil and strips.equipStrip:getIsVisible() then
        nodes[#nodes + 1] = { kind = "equip", el = strips.equipStrip,
            panel = strips }
    end
    if strips.hotbarStrip ~= nil
            and strips.hotbarStrip:getIsVisible() then
        nodes[#nodes + 1] = { kind = "hotbar", el = strips.hotbarStrip,
            panel = strips }
    end
    local pocketsPanel = strips.pocketsPanel
    if pocketsPanel ~= nil and pocketsPanel:getIsVisible() then

        if pocketsPanel.padChipCount ~= nil then
            nodes[#nodes + 1] = { kind = "chip", el = pocketsPanel,
                panel = strips }
        end
        local pocketGrids = pocketsPanel.gridViews
        for islandIndex = 1, #pocketGrids do

            local island = pocketGrids[islandIndex]
            if island:getIsVisible() then
                nodes[#nodes + 1] = { kind = "pocket", el = island,
                    panel = strips }
            end
        end
    end
end

local function addPanelNodes(nodes, panels)
    for i = 1, #panels do
        local panel = panels[i]

        if panel.padChipCount ~= nil then
            nodes[#nodes + 1] = { kind = "chip", el = panel, panel = panel }
        end

        if panel.gridView ~= nil and panel.gridView:getIsVisible() then
            nodes[#nodes + 1] = { kind = "grid", el = panel.gridView,
                panel = panel }
        end
    end
end

local function addEquipWindowNodes(nodes, page)
    local EquipWindow = ComfyGrid.UI and ComfyGrid.UI.EquipWindow
    local win = EquipWindow ~= nil and EquipWindow.windowFor ~= nil
        and EquipWindow.windowFor(page.player) or nil

    if page.onCharacter == true and win ~= nil and win:getIsVisible()
            and win.content ~= nil then
        local floating = win.docked == false

        if win.strip ~= nil and win.strip.padChipCount ~= nil then
            nodes[#nodes + 1] = { kind = "chip", el = win.strip,
                panel = win, side = true, floating = floating }
        end
        nodes[#nodes + 1] = { kind = "equip", el = win.content,
            panel = win, side = true, floating = floating }
    end
end

local function addBagWindowNode(nodes, page)
    local ContainerWindow = ComfyGrid.UI and ComfyGrid.UI.ContainerWindow
    local win = ContainerWindow ~= nil and ContainerWindow.windowFor ~= nil
        and ContainerWindow.windowFor(page.player) or nil
    local grid = ContainerWindow ~= nil and ContainerWindow.gridFor ~= nil
        and ContainerWindow.gridFor(page.player) or nil
    if page.onCharacter == true and win ~= nil and grid ~= nil
            and win:getIsVisible() then
        nodes[#nodes + 1] = { kind = "grid", el = grid, panel = win, side = true,
            floating = true }
    end
end

local function nodesFor(page)
    local host = hostOf(page)
    local panels = host ~= nil and host.panels or nil
    if panels == nil then return nil, nil end
    local nodes = {}
    addTitleBandNode(nodes, page)
    addPlayerStripNodes(nodes, host.strips)
    addPanelNodes(nodes, panels)
    addEquipWindowNodes(nodes, page)
    addBagWindowNode(nodes, page)
    if #nodes == 0 then return nil, nil end
    return nodes, host
end

local function countOf(node)
    local el = node.el
    if node.kind == "equip" or node.kind == "hotbar" then
        return el.entryCount or 0
    end
    if node.kind == "chip" then
        return el.padChipCount ~= nil and el:padChipCount() or 0
    end

    if el.visibleSlots ~= nil then return el:visibleSlots() end
    local cols = el.cols or 0
    local rows = el.rows or 0
    return cols * rows
end

local function indexOfEl(nodes, el)
    if el == nil then return nil end
    for i = 1, #nodes do
        if nodes[i].el == el then return i end
    end
    return nil
end

local function isLandable(node)
    return node ~= nil and not node.side and countOf(node) >= 1
end

local function isColdLanding(node)
    return isLandable(node) and node.kind ~= "chip"
end

local function defaultIndex(nodes, page)
    local host = hostOf(page)
    local mainGrid = host ~= nil and host.panels[1] ~= nil
        and host.panels[1].gridView or nil
    local idx = indexOfEl(nodes, mainGrid)
    if idx ~= nil and countOf(nodes[idx]) > 0 then return idx end
    for i = 1, #nodes do
        if isColdLanding(nodes[i]) then return i end
    end
    return nil
end

local function isShown(page)
    return page ~= nil and page:getIsVisible() and not page.isCollapsed
end

local function viewportOf(host)
    if host.viewportHeight ~= nil then return host:viewportHeight() end
    return host.height or 0
end

local function stampNode(windowCursor, node, slot)
    local count = countOf(node)
    if slot < 0 then slot = 0 end
    if count > 0 and slot >= count then slot = count - 1 end
    windowCursor.el = node.el
    windowCursor.kind = node.kind
    windowCursor.slot = slot
    rememberSlot(windowCursor, node, slot)

    local el = node.el
    if el.padFocusChanged ~= nil then el:padFocusChanged(slot) end
end

local function ensureVisible(host, node, slot)

    if host == nil or node.side or node.fixed then return end
    local stride = Style.CELL_STRIDE
    local cell = Style.CELL or 45
    local gy = 0
    local walker = node.el
    while walker ~= nil and walker ~= node.panel do
        gy = gy + (walker.y or 0)
        walker = walker.parent
    end
    if walker == nil then return end
    local cols = node.el.cols or 1
    if cols < 1 then cols = 1 end

    local row = node.kind == "chip" and 0 or math.floor(slot / cols)

    local top = (node.panel.y or 0) + (host.yOffset or 0)
        + gy + row * stride
    local bottom = top + cell
    local view = viewportOf(host)
    local offset = host.yOffset or 0
    if top < offset then
        offset = top
    elseif bottom > offset + view then
        offset = bottom - view
    end
    if offset < 0 then offset = 0 end
    host.yOffset = offset
end

local function placeCursor(windowCursor, host, node, slot)
    stampNode(windowCursor, node, slot)
    ensureVisible(host, node, windowCursor.slot)
end

function PadFocus.onGain(page, _joypadData)
    local seatState = stateFor(page.player)
    seatState.page = page
    seatState.active = true

    local placed = seatState.handoff == page
    seatState.handoff = nil
    if placed then return end
    local windowCursor = winState(seatState, page)
    local nodes = nodesFor(page)
    local cur = nodes ~= nil and indexOfEl(nodes, windowCursor.el) or nil

    if nodes ~= nil and (cur == nil or not isColdLanding(nodes[cur])) then
        local idx = defaultIndex(nodes, page)
        if idx ~= nil then
            stampNode(windowCursor, nodes[idx], windowCursor.slot or 0)
        end
    end
end

function PadFocus.clearSelections(page)
    local nodes = nodesFor(page)
    if nodes == nil then return false end
    local cleared = false
    for i = 1, #nodes do
        local el = nodes[i].el
        if el.padClearSelection ~= nil and el:padClearSelection() then
            cleared = true
        end
    end
    return cleared
end

function PadFocus.focusWindow(page, target)
    if target == nil or target == page then return false end
    local seatState = stateFor(page.player)
    local windowCursor = winState(seatState, target)
    local nodes, host = nodesFor(target)
    if nodes == nil then return false end
    local cur = indexOfEl(nodes, windowCursor.el)

    if cur == nil or not isColdLanding(nodes[cur]) then
        cur = defaultIndex(nodes, target)
        if cur == nil then return false end
    end

    placeCursor(windowCursor, host, nodes[cur], windowCursor.slot or 0)
    handFocus(seatState, page.player, target)
    return true
end

function PadFocus.enterBagWindow(page)
    local owner = getPlayerInventory(page.player)
    if not isShown(owner) then return false end
    local ContainerWindow = ComfyGrid.UI and ComfyGrid.UI.ContainerWindow
    local grid = ContainerWindow ~= nil and ContainerWindow.gridFor ~= nil
        and ContainerWindow.gridFor(page.player) or nil
    local nodes = nodesFor(owner)
    local index = nodes ~= nil and indexOfEl(nodes, grid) or nil
    if index == nil then return false end
    local seatState = stateFor(page.player)
    stampNode(winState(seatState, owner), nodes[index], 0)
    if owner ~= page then handFocus(seatState, page.player, owner) end
    return true
end

function PadFocus.focusInventory(page, inv)
    if inv == nil then return false end
    local nodes, host = nodesFor(page)
    if nodes == nil then return false end
    local windowCursor = winState(stateFor(page.player), page)

    local cur = indexOfEl(nodes, windowCursor.el)
    if cur ~= nil then
        local model = nodes[cur].el.model
        if model ~= nil and model.inventory == inv then
            ensureVisible(host, nodes[cur], windowCursor.slot)
            return true
        end
    end
    for i = 1, #nodes do
        local node = nodes[i]

        if node.kind == "grid" or node.kind == "pocket" then
            local model = node.el.model
            if model ~= nil and model.inventory == inv then
                placeCursor(windowCursor, host, node, windowCursor.slot or 0)
                return true
            end
        end
    end
    return false
end

function PadFocus.followSelection(page)
    local seatState = stateFor(page.player)
    if seatState.page ~= page then return false end
    local container = page.inventoryPane ~= nil and page.inventoryPane.inventory or nil
    if container == nil then return false end
    local host = hostOf(page)

    if host ~= nil and host.refreshLayout ~= nil then host:refreshLayout() end
    local nodes = nodesFor(page)
    if nodes == nil then return false end
    local windowCursor = winState(seatState, page)
    local header = nil
    for i = 1, #nodes do
        local node = nodes[i]
        local model = node.el.model
        if not node.side and model ~= nil and model.inventory == container then
            if node.kind == "grid" or node.kind == "pocket" then
                placeCursor(windowCursor, host, node, windowCursor.slotIn[container] or 0)
                return true
            end
            if node.kind == "chip" and header == nil then header = node end
        end
    end
    if header == nil then return false end
    placeCursor(windowCursor, host, header, 0)
    return true
end

PadFocus.movingInv = PadMove.movingInv
PadFocus.canMove = PadMove.canMove
PadFocus.beginMove = PadMove.beginMove
PadFocus.endMove = PadMove.endMove

function PadFocus.eachGridNode(page, fn)
    local nodes = nodesFor(page)
    if nodes == nil then return end
    for i = 1, #nodes do
        local node = nodes[i]
        if node.kind == "grid" or node.kind == "pocket" then
            fn(node.el)
        end
    end
end

function PadFocus.onLose(page)
    local seatState = states[page.player]

    if seatState == nil or seatState.page ~= page then return end

    if getFocusForPlayer(page.player) ~= nil then return end
    seatState.active = false
    seatState.handoff = nil

    PadFocus.endMove(page)

    local Carry = ComfyGrid.Interact.PadCarry
    if Carry ~= nil then Carry.cancel(page.player) end

    PadFocus.clearSelections(page)
    local other = page.onCharacter and getPlayerLoot(page.player)
        or getPlayerInventory(page.player)
    if other ~= nil and other ~= page then
        PadFocus.clearSelections(other)
    end
end

local function enterSide(node)
    if not node.side then return end
    local window = node.panel
    if window ~= nil and window.isCollapsed and window.uncollapse ~= nil then
        window:uncollapse()
    end
end

local function relandStaleCursor(page, nodes, host, windowCursor)
    local cur = defaultIndex(nodes, page)
    if cur == nil then return false end
    placeCursor(windowCursor, host, nodes[cur], windowCursor.slot or 0)
    return true
end

local function otherPageOf(page)
    local other
    if page.onCharacter then other = getPlayerLoot(page.player)
    else other = getPlayerInventory(page.player) end
    if other == page or not isShown(other) then return nil end
    return other
end

local function windowOf(node, page)
    return node.side and node.panel or page
end

local function addWindowTarget(targets, page, node)
    local window = node.panel
    local x, y = window:getAbsoluteX(), window:getAbsoluteY()
    targets[#targets + 1] = { page = page, node = node, wholeWindow = true, far = true,
        x0 = x, y0 = y, x1 = x + window:getWidth(), y1 = y + window:getHeight() }
end

local scratchCell = {}

local function addTargets(targets, page, nodes, host, covers, own, listed, from, dx, dy)
    local viewTop, viewBottom = 0, 0
    if host ~= nil then
        viewTop = host:getAbsoluteY()
        viewBottom = viewTop + viewportOf(host)
    end
    for i = 1, #nodes do
        local node = nodes[i]
        if not listed[node.el] then
            listed[node.el] = true
            local window = windowOf(node, page)
            if node.floating and window ~= own and from ~= nil then

                if node.kind ~= "chip" then addWindowTarget(targets, page, node) end
            else
                local far = window ~= own
                local scrolls = host ~= nil and not node.side and not node.fixed
                local el = node.el
                local elX, elY = el:getAbsoluteX(), el:getAbsoluteY()
                local cell = scratchCell
                cell.far = far
                for slot = 0, countOf(node) - 1 do
                    if PadTargets.cellRect(node, slot, cell, elX, elY)
                            and (from == nil or PadBeam.mayLand(from, cell, dx, dy)) then
                        local onScreen = not scrolls
                            or (cell.y1 > viewTop and cell.y0 < viewBottom)
                        if not PadTargets.isCovered(cell, covers, node.side and window or nil, onScreen) then
                            targets[#targets + 1] = { page = page, host = host, node = node,
                                slot = slot, far = far, offScreen = not onScreen,
                                x0 = cell.x0, y0 = cell.y0, x1 = cell.x1, y1 = cell.y1 }
                        end
                    end
                end
            end
        end
    end
end

local function cellFacing(node, from, dx, dy)
    local cells = {}
    for slot = 0, countOf(node) - 1 do
        local cell = { slot = slot }
        if PadTargets.cellRect(node, slot, cell) then cells[#cells + 1] = cell end
    end
    local picked = PadBeam.pick(from, cells, dx, dy)
        or PadBeam.nearest(cells, (from.x0 + from.x1) / 2, (from.y0 + from.y1) / 2)
    return picked ~= nil and cells[picked].slot or 0
end

local function landAt(seatState, playerNum, focused, targetPage, host, node, slot, handOver)
    enterSide(node)
    placeCursor(winState(seatState, targetPage), host, node, slot)
    if handOver and targetPage ~= focused then handFocus(seatState, playerNum, targetPage) end
end

local function landOn(seatState, page, target, from, dx, dy)
    local slot = target.slot
    if target.wholeWindow then slot = cellFacing(target.node, from, dx, dy) end
    landAt(seatState, page.player, page, target.page, target.host, target.node, slot, true)
end

function PadFocus.onDir(page, dx, dy)
    local seatState = stateFor(page.player)
    seatState.page = page

    local moving = PadMove.movingInv(page)
    if moving ~= nil then return PadMove.press(page, moving, dx, dy) end
    local nodes, host = nodesFor(page)
    if nodes == nil then return false end
    local windowCursor = winState(seatState, page)
    local cur = indexOfEl(nodes, windowCursor.el)
    if cur == nil or countOf(nodes[cur]) < 1 then
        return relandStaleCursor(page, nodes, host, windowCursor)
    end
    local slot = Util.clamp(windowCursor.slot or 0, 0, countOf(nodes[cur]) - 1)
    local from = {}
    if not PadTargets.cellRect(nodes[cur], slot, from) then return true end
    local own = windowOf(nodes[cur], page)
    local covers = PadTargets.covers(page.player)
    local targets, listed = {}, {}
    addTargets(targets, page, nodes, host, covers, own, listed, from, dx, dy)
    local other = otherPageOf(page)
    local otherNodes, otherHost = nil, nil
    if other ~= nil then otherNodes, otherHost = nodesFor(other) end
    if otherNodes ~= nil then
        addTargets(targets, other, otherNodes, otherHost, covers, own, listed, from, dx, dy)
    end
    local landing = PadBeam.pick(from, targets, dx, dy)
    if landing ~= nil then landOn(seatState, page, targets[landing], from, dx, dy) end
    return true
end

function PadFocus.cursorRectOn(playerNum, el)
    if not Input.padOwns(playerNum) then return nil end
    local seatState = states[playerNum]
    if seatState == nil or not seatState.active or seatState.page == nil then return nil end
    local windowCursor = seatState.win[seatState.page]
    if windowCursor == nil or windowCursor.el ~= el then return nil end
    local rect = {}
    local node = { kind = windowCursor.kind, el = el }
    if not PadTargets.cellRect(node, windowCursor.slot or 0, rect) then return nil end
    return rect
end

function PadFocus.landBeneath(playerNum, rect, releasing)
    local covers = PadTargets.covers(playerNum)
    local targets, listed = {}, {}
    local inventoryPage, lootPage = getPlayerInventory(playerNum), getPlayerLoot(playerNum)
    for _, page in ipairs({ inventoryPage, lootPage }) do
        local nodes, host = nil, nil
        if isShown(page) then nodes, host = nodesFor(page) end
        if nodes ~= nil then addTargets(targets, page, nodes, host, covers, nil, listed) end
    end
    local shown = {}
    for i = 1, #targets do
        if not targets[i].offScreen then shown[#shown + 1] = targets[i] end
    end
    local index = PadBeam.nearest(shown, (rect.x0 + rect.x1) / 2, (rect.y0 + rect.y1) / 2)
    if index == nil then return false end
    local best = shown[index]
    local focused = getFocusForPlayer(playerNum)
    local ours = focused ~= nil and (focused == releasing or focused == inventoryPage
        or focused == lootPage)
    landAt(stateFor(playerNum), playerNum, focused, best.page, best.host, best.node,
        best.slot, ours)
    return true
end

local function shownSlotOf(el, slot)
    if slot == nil or el.visibleSlots == nil then return slot end
    local shown = el:visibleSlots()
    if shown > 0 and slot > shown - 1 then return shown - 1 end
    return slot
end

function PadFocus.cursorFor(el)
    local seatState = states[el.playerNum]
    if seatState == nil or not seatState.active then return nil end
    local page = seatState.page
    if page == nil then return nil end
    local windowCursor = seatState.win[page]
    if windowCursor == nil or windowCursor.el ~= el then return nil end
    return shownSlotOf(el, windowCursor.slot)
end

function PadFocus.peek(page)
    local seatState = stateFor(page.player)
    local windowCursor = winState(seatState, page)
    local el = windowCursor.el
    if el == nil then return nil end
    local kind = windowCursor.kind
    local slot = windowCursor.slot or 0
    if kind == "equip" then
        if slot >= (el.entryCount or 0) then return nil end
        local entry = el.entries ~= nil and el.entries[slot + 1] or nil
        local item = entry ~= nil and entry.items ~= nil and entry.items[1]
            or nil
        return kind, el, slot, item
    end
    if kind == "chip" then

        local chipCount = el.padChipCount ~= nil and el:padChipCount() or 0
        if slot >= chipCount then return nil end
        return kind, el, slot, nil
    end
    if kind == "hotbar" then
        if slot >= (el.entryCount or 0) then return nil end
        local hotbar = Input.hotbarOf(el.playerNum)
        local item = hotbar ~= nil and hotbar.attachedItems ~= nil
            and hotbar.attachedItems[slot + 1] or nil
        return kind, el, slot, item
    end
    slot = shownSlotOf(el, slot)
    local model = el.model
    local stack = nil
    if model ~= nil and model.grid ~= nil then
        stack = model.grid:stackAt(slot)

        if stack ~= nil and el.isVeiledStack ~= nil and el:isVeiledStack(stack) then
            stack = nil
        end
    end
    return kind or "grid", el, slot, stack
end

return PadFocus
