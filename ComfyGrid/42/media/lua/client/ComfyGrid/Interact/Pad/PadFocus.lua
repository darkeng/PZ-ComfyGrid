--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Util"
require "ComfyGrid/Core/Input"
require "ComfyGrid/UI/Style"
require "ComfyGrid/Interact/Pad/PadMove"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local PadFocus = {}
ComfyGrid.Interact.PadFocus = PadFocus

local Util = ComfyGrid.Core.Util
local Input = ComfyGrid.Core.Input
local Style = ComfyGrid.UI.Style
local PadMove = ComfyGrid.Interact.PadMove

local states = {}

local function stateFor(playerNum)
    local seatState = states[playerNum]
    if seatState == nil then
        seatState = { active = false, page = nil, win = {} }
        states[playerNum] = seatState
    end
    return seatState
end

local function winState(seatState, page)
    local windowCursor = seatState.win[page]
    if windowCursor == nil then
        windowCursor = { el = nil, kind = nil, slot = 0 }
        seatState.win[page] = windowCursor
    end
    return windowCursor
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
    local pocketGrids = pocketsPanel ~= nil and pocketsPanel.gridViews
        or nil
    if pocketGrids ~= nil then
        for j = 1, #pocketGrids do
            nodes[#nodes + 1] = { kind = "pocket", el = pocketGrids[j],
                panel = strips }
        end
    end
end

local function addPanelNodes(nodes, panels)
    for i = 1, #panels do
        local panel = panels[i]

        if panel.padChipCount ~= nil then
            nodes[#nodes + 1] = { kind = "chip", el = panel, panel = panel }
        end
        if panel.gridView ~= nil then
            nodes[#nodes + 1] = { kind = "grid", el = panel.gridView,
                panel = panel }
        end
    end
end

local function addEquipWindowNodes(nodes, page)
    local EquipWindow = ComfyGrid.UI and ComfyGrid.UI.EquipWindow
    local win = EquipWindow ~= nil and EquipWindow.windowFor ~= nil
        and EquipWindow.windowFor(page.player) or nil

    local neighbour = win ~= nil
        and (page.onCharacter == true or win.dockSide == "centre")
    if neighbour and win:getIsVisible() and win.content ~= nil then

        if win.strip ~= nil and win.strip.padChipCount ~= nil then
            nodes[#nodes + 1] = { kind = "chip", el = win.strip,
                panel = win, side = true }
        end
        nodes[#nodes + 1] = { kind = "equip", el = win.content,
            panel = win, side = true }
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

        nodes[#nodes + 1] = { kind = "grid", el = grid, panel = win,
            side = true, bubble = true }
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

local function shapeOf(node, count)
    if node.kind == "chip" then
        return count > 0 and count or 1, 1
    end
    return node.el.cols or 1, node.el.rows or 1
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

local function defaultIndex(nodes, page)
    local host = hostOf(page)
    local mainGrid = host ~= nil and host.panels[1] ~= nil
        and host.panels[1].gridView or nil
    local idx = indexOfEl(nodes, mainGrid)
    if idx ~= nil and countOf(nodes[idx]) > 0 then return idx end
    for i = 1, #nodes do

        if not nodes[i].side and nodes[i].kind ~= "chip"
                and countOf(nodes[i]) > 0 then
            return i
        end
    end
    return nil
end

local function stampNode(windowCursor, node, slot)
    local count = countOf(node)
    if slot < 0 then slot = 0 end
    if count > 0 and slot >= count then slot = count - 1 end
    windowCursor.el = node.el
    windowCursor.kind = node.kind
    windowCursor.slot = slot

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

    local view = host.viewportHeight ~= nil and host:viewportHeight()
        or (host.height or 0)
    local offset = host.yOffset or 0
    if top < offset then
        offset = top
    elseif bottom > offset + view then
        offset = bottom - view
    end
    if offset < 0 then offset = 0 end
    host.yOffset = offset
end

function PadFocus.onGain(page, _joypadData)
    local seatState = stateFor(page.player)
    seatState.page = page
    seatState.active = true
    local windowCursor = winState(seatState, page)
    local nodes = nodesFor(page)
    local cur = nodes ~= nil and indexOfEl(nodes, windowCursor.el) or nil

    if nodes ~= nil and (cur == nil or not isLandable(nodes[cur])
            or nodes[cur].kind == "chip") then
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

    if cur == nil or not isLandable(nodes[cur]) then
        cur = defaultIndex(nodes, target)
        if cur == nil then return false end
    end

    stampNode(windowCursor, nodes[cur], windowCursor.slot or 0)
    ensureVisible(host, nodes[cur], windowCursor.slot)
    setJoypadFocus(page.player, target)
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
                stampNode(windowCursor, node, windowCursor.slot or 0)
                ensureVisible(host, node, windowCursor.slot)
                return true
            end
        end
    end
    return false
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

local function crossWindow(seatState, page, dir, fromRow)
    local other
    if page.onCharacter then
        other = getPlayerLoot(page.player)
    else
        other = getPlayerInventory(page.player)
    end
    if other == nil or other == page then return false end
    local otherOnSide
    if dir > 0 then
        otherOnSide = other:getAbsoluteX() >= page:getAbsoluteX()
    else
        otherOnSide = other:getAbsoluteX() <= page:getAbsoluteX()
    end
    if not otherOnSide then return false end
    local nodes, host = nodesFor(other)
    if nodes == nil then return false end
    local idx = defaultIndex(nodes, other)
    if idx == nil then return false end
    local node = nodes[idx]
    local windowCursor = winState(seatState, other)
    local cols = node.el.cols or 1
    local rows = node.el.rows or 1
    local row = fromRow
    if row > rows - 1 then row = rows - 1 end
    if row < 0 then row = 0 end
    local col = dir > 0 and 0 or (cols - 1)
    stampNode(windowCursor, node, row * cols + col)
    ensureVisible(host, node, windowCursor.slot)

    setJoypadFocus(page.player, other)
    return true
end

local function verticalStep(nodes, cur, step, col)
    local from = nodes[cur]
    local fromPocket = from.kind == "pocket"

    local sidePanel = from.side and from.panel or nil
    local idx = cur + step
    while nodes[idx] ~= nil do
        local node = nodes[idx]
        local skip = countOf(node) < 1
            or (sidePanel == nil and node.side)
            or (sidePanel ~= nil and node.panel ~= sidePanel)
            or (fromPocket and node.kind == "pocket")
        if not skip then
            local cols, rows = shapeOf(node, countOf(node))
            local nCol = col
            if nCol > cols - 1 then nCol = cols - 1 end
            local enterRow = step > 0 and 0 or (rows - 1)
            return node, enterRow * cols + nCol
        end
        idx = idx + step
    end
    return nil
end

local function centreX(window)
    return window:getAbsoluteX() + (window:getWidth() or 0) / 2
end

local function dirOf(node, page)
    local window = node.panel
    if window == nil then return 0, 0 end
    if window.docked == true and window.dockSide == "above" then
        return 0, -1
    end
    if window.getAbsoluteX == nil then return 0, 0 end

    return centreX(window) < centreX(page) and -1 or 1, 0
end

local function sideSpan(node, page)
    local window = node.panel
    if window == nil or window.getAbsoluteX == nil then return 0 end
    local centreDistance = centreX(window) - centreX(page)
    return centreDistance < 0 and -centreDistance or centreDistance
end

local function sideNodeOn(nodes, page, dx, dy, after)
    if dx == 0 and dy == 0 then return nil end
    local minSpan = after ~= nil and sideSpan(after, page) or nil
    local best, bestSpan = nil, nil
    for i = 1, #nodes do
        local node = nodes[i]

        if node.side and not node.bubble and node.kind ~= "chip"
                and countOf(node) > 0 and node ~= after then
            local wx, wy = dirOf(node, page)
            if wx == dx and wy == dy then
                local span = sideSpan(node, page)
                if minSpan == nil or span > minSpan then
                    if bestSpan == nil or span < bestSpan then
                        best, bestSpan = i, span
                    end
                end
            end
        end
    end
    return best
end

local function cursorAbs(node, slot, cols)
    local el = node.el
    if el.padRagged == true and el.padTileXY ~= nil then
        local x, y = el:padTileXY(slot)
        return el:getAbsoluteX() + x, el:getAbsoluteY() + y
    end
    if node.kind == "chip" then
        return el:getAbsoluteX(), el:getAbsoluteY()
    end
    local x, y = Style.pixelForSlot(slot, cols)
    return el:getAbsoluteX() + x, el:getAbsoluteY() + y
end

local function raggedStep(el, slot, dx, dy, count)
    local cx, cy = el:padTileXY(slot)
    local best, bestScore = nil, nil
    for i = 0, count - 1 do
        if i ~= slot then
            local x, y = el:padTileXY(i)
            local along, across
            if dx ~= 0 then
                along, across = (x - cx) * dx, y - cy
            else
                along, across = (y - cy) * dy, x - cx
            end
            if along > 0 then
                if across < 0 then across = -across end
                local score = along + across * 2
                if bestScore == nil or score < bestScore then
                    best, bestScore = i, score
                end
            end
        end
    end
    return best
end

local function raggedEntry(el, count, fromAbsX, fromAbsY)
    if count <= 0 then return 0 end

    if el.padRagged ~= true or el.padTileXY == nil then
        local cols = el.cols or 1
        if cols < 1 then cols = 1 end
        local rows = math.ceil(count / cols)
        local ex0 = el.getAbsoluteX ~= nil and el:getAbsoluteX() or 0
        local ey0 = el.getAbsoluteY ~= nil and el:getAbsoluteY() or 0
        local width = el.getWidth ~= nil and el:getWidth() or 0
        local height = el.getHeight ~= nil and el:getHeight() or 0
        local col = width > 0
            and math.floor((fromAbsX - ex0) / (width / cols)) or 0
        local row = height > 0
            and math.floor((fromAbsY - ey0) / (height / rows)) or 0
        col = Util.clamp(col, 0, cols - 1)
        row = Util.clamp(row, 0, rows - 1)
        return Util.clamp(row * cols + col, 0, count - 1)
    end
    local ex, ey = el:getAbsoluteX(), el:getAbsoluteY()
    local best, bestScore = 0, nil
    for i = 0, count - 1 do
        local x, y = el:padTileXY(i)
        local ay = (ey + y) - fromAbsY
        if ay < 0 then ay = -ay end
        local ax = (ex + x) - fromAbsX
        if ax < 0 then ax = -ax end
        local score = ay * 2 + ax
        if bestScore == nil or score < bestScore then
            best, bestScore = i, score
        end
    end
    return best
end

local function enterSide(node)
    local window = node.panel
    if window ~= nil and window.isCollapsed and window.uncollapse ~= nil then
        window:uncollapse()
    end
end

local function leaveSide(page, nodes, windowCursor, host)
    local idx = indexOfEl(nodes, windowCursor.homeEl)
    if idx == nil or not isLandable(nodes[idx]) then
        idx = defaultIndex(nodes, page)
    end
    if idx == nil then return end
    stampNode(windowCursor, nodes[idx], windowCursor.homeSlot or 0)
    ensureVisible(host, nodes[idx], windowCursor.slot)
end

local function leaveBubble(page, nodes, windowCursor, host, dx, dy)
    local idx = indexOfEl(nodes, windowCursor.homeEl)
    if idx == nil or not isLandable(nodes[idx]) then
        idx = defaultIndex(nodes, page)
    end
    if idx == nil then return true end
    local node = nodes[idx]
    local count = countOf(node)
    local cols = shapeOf(node, count)
    local slot = Util.clamp(windowCursor.homeSlot or 0, 0, count - 1)
    local col = Util.clamp(slot % cols + (dx or 0), 0, cols - 1)
    local row = math.floor(slot / cols) + (dy or 0)
    if row < 0 then row = 0 end
    local nslot = Util.clamp(row * cols + col, 0, count - 1)
    stampNode(windowCursor, node, nslot)
    ensureVisible(host, node, windowCursor.slot)
    if nslot == slot then windowCursor.bubbleSkip = true end
    return true
end

local function sideEdge(seatState, node, page, nodes, windowCursor, host, dx, dy)

    if node.bubble then
        return leaveBubble(page, nodes, windowCursor, host, dx, dy)
    end
    local wx, wy = dirOf(node, page)
    if dx == -wx and dy == -wy then
        leaveSide(page, nodes, windowCursor, host)
        return true
    end

    local idx = sideNodeOn(nodes, page, dx, dy, node)
    if idx ~= nil then
        local sideNode = nodes[idx]
        enterSide(sideNode)
        stampNode(windowCursor, sideNode, 0)
        ensureVisible(host, sideNode, windowCursor.slot)
        return true
    end
    if dx ~= 0 then crossWindow(seatState, page, dx, 0) end
    return true
end

local function enterSideOn(nodes, page, windowCursor, node, slot, cols, dx, dy)
    local idx = sideNodeOn(nodes, page, dx, dy)
    if idx == nil then return false end
    local sideNode = nodes[idx]
    enterSide(sideNode)
    local ax, ay = cursorAbs(node, slot, cols)
    windowCursor.homeEl, windowCursor.homeSlot = node.el, slot
    stampNode(windowCursor, sideNode,
        raggedEntry(sideNode.el, countOf(sideNode), ax, ay))
    return true
end

local function bubbleRedirect(page)
    local ContainerWindow = ComfyGrid.UI and ComfyGrid.UI.ContainerWindow
    local grid = ContainerWindow ~= nil and ContainerWindow.gridFor ~= nil
        and ContainerWindow.gridFor(page.player) or nil
    if grid == nil then return end
    local windowCursor = winState(stateFor(page.player), page)
    if windowCursor.bubbleSkip then
        windowCursor.bubbleSkip = nil
        return
    end
    if windowCursor.el == grid then return end
    local kind, el, slot, occupant = PadFocus.peek(page)
    if el == nil or occupant == nil then return end
    if kind ~= "grid" and kind ~= "pocket" then return end
    if occupant.itemIDs == nil then return end

    local inv = grid.model ~= nil and grid.model.inventory or nil
    if inv == nil then return end
    local okItem, item = pcall(inv.getContainingItem, inv)
    if not okItem or item == nil then return end
    local id = item:getID()
    local onTheDoor = false
    for sid in pairs(occupant.itemIDs) do
        if sid == id then onTheDoor = true break end
    end
    if not onTheDoor then return end

    local nodes, host = nodesFor(page)
    if nodes == nil then return end
    local bagNodeIndex, fromNodeIndex = nil, indexOfEl(nodes, el)
    for i = 1, #nodes do
        if nodes[i].el == grid then bagNodeIndex = i break end
    end
    if bagNodeIndex == nil or countOf(nodes[bagNodeIndex]) < 1 then return end
    local bagNode = nodes[bagNodeIndex]
    local from = fromNodeIndex ~= nil and nodes[fromNodeIndex] or nil
    local ax, ay = 0, 0
    if from ~= nil then
        ax, ay = cursorAbs(from, slot, shapeOf(from, countOf(from)))
    end
    enterSide(bagNode)

    windowCursor.homeEl, windowCursor.homeSlot = el, slot
    stampNode(windowCursor, bagNode, raggedEntry(bagNode.el,
        countOf(bagNode), ax, ay))
    ensureVisible(host, bagNode, windowCursor.slot)
end

local function relandStaleCursor(page, nodes, host, windowCursor)
    local cur = defaultIndex(nodes, page)
    if cur == nil then return false end
    stampNode(windowCursor, nodes[cur], windowCursor.slot or 0)
    ensureVisible(host, nodes[cur], windowCursor.slot)
    return true
end

local function walkRaggedBoard(press, dx, dy)
    local node, windowCursor = press.node, press.windowCursor
    local target = raggedStep(node.el, press.slot, dx, dy, press.count)
    if target ~= nil then
        stampNode(windowCursor, node, target)
        return true
    end

    if dy ~= 0 then

        local nextNode, enterSlot = verticalStep(press.nodes, press.cur,
            dy > 0 and 1 or -1, 0)
        if nextNode ~= nil then
            stampNode(windowCursor, nextNode, enterSlot)
            ensureVisible(press.host, nextNode, windowCursor.slot)
            return true
        end
    end
    if node.side then
        return sideEdge(press.seatState, node, press.page, press.nodes,
            windowCursor, press.host, dx, dy)
    end
    return true
end

local function walkHorizontal(press, dx)
    local node, windowCursor, host = press.node, press.windowCursor, press.host
    local cols, row = press.cols, press.row
    local ncol = press.col + dx
    local nslot = row * cols + ncol
    if ncol >= 0 and ncol < cols and nslot < press.count then
        stampNode(windowCursor, node, nslot)
        ensureVisible(host, node, windowCursor.slot)
        return true
    end

    if node.kind == "pocket" then
        local sib = press.nodes[press.cur + dx]
        if sib ~= nil and sib.kind == "pocket" and countOf(sib) > 0 then
            local sCols = sib.el.cols or 1
            local sRows = sib.el.rows or 1
            local sRow = row
            if sRow > sRows - 1 then sRow = sRows - 1 end
            local sCol = dx > 0 and 0 or (sCols - 1)
            stampNode(windowCursor, sib, sRow * sCols + sCol)
            ensureVisible(host, sib, windowCursor.slot)
            return true
        end
    end

    if node.side then
        return sideEdge(press.seatState, node, press.page, press.nodes,
            windowCursor, host, dx, 0)
    end

    if enterSideOn(press.nodes, press.page, windowCursor, node, press.slot,
            cols, dx, 0) then
        return true
    end

    crossWindow(press.seatState, press.page, dx, row)
    return true
end

local function walkVertical(press, dy)
    local node, windowCursor, host = press.node, press.windowCursor, press.host
    local cols, col = press.cols, press.col
    local nrow = press.row + dy
    local nslot = nrow * cols + col
    if nrow >= 0 and nrow <= press.rows - 1 then
        if nslot >= press.count then nslot = press.count - 1 end
        stampNode(windowCursor, node, nslot)
        ensureVisible(host, node, windowCursor.slot)
        return true
    end
    local nextNode, enterSlot = verticalStep(press.nodes, press.cur,
        dy > 0 and 1 or -1, col)
    if nextNode ~= nil then
        stampNode(windowCursor, nextNode, enterSlot)
        ensureVisible(host, nextNode, windowCursor.slot)
        return true
    end
    if node.side then
        return sideEdge(press.seatState, node, press.page, press.nodes,
            windowCursor, host, 0, dy)
    end

    enterSideOn(press.nodes, press.page, windowCursor, node, press.slot,
        cols, 0, dy)
    return true
end

local function onDirStep(page, dx, dy)
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
    local node = nodes[cur]
    local count = countOf(node)
    local cols, rows = shapeOf(node, count)
    local slot = Util.clamp(windowCursor.slot or 0, 0, count - 1)

    local press = {
        seatState = seatState, page = page, nodes = nodes, host = host,
        windowCursor = windowCursor, cur = cur, node = node, count = count,
        cols = cols, rows = rows, slot = slot,
        col = slot % cols, row = math.floor(slot / cols),
    }
    if node.el.padRagged == true and node.el.padTileXY ~= nil then
        return walkRaggedBoard(press, dx, dy)
    end
    if dx ~= 0 then return walkHorizontal(press, dx) end
    return walkVertical(press, dy)
end

function PadFocus.onDir(page, dx, dy)
    local handled = onDirStep(page, dx, dy)
    if handled then pcall(bubbleRedirect, page) end
    return handled
end

function PadFocus.cursorFor(el)
    local seatState = states[el.playerNum]
    if seatState == nil or not seatState.active then return nil end
    local page = seatState.page
    if page == nil then return nil end
    local windowCursor = seatState.win[page]
    if windowCursor == nil or windowCursor.el ~= el then return nil end
    return windowCursor.slot
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
    local model = el.model
    local stack = nil
    if model ~= nil and model.grid ~= nil then
        stack = model.grid:stackAt(slot)
    end
    return kind or "grid", el, slot, stack
end

return PadFocus
