--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.7.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/UI/Style"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Interact = ComfyGrid.Interact or {}
local PadFocus = {}
ComfyGrid.Interact.PadFocus = PadFocus

local Style = ComfyGrid.UI.Style

local states = {}

local function stateFor(playerNum)
    local st = states[playerNum]
    if st == nil then
        st = { active = false, page = nil, win = {} }
        states[playerNum] = st
    end
    return st
end

local function winState(st, page)
    local ws = st.win[page]
    if ws == nil then
        ws = { el = nil, kind = nil, slot = 0 }
        st.win[page] = ws
    end
    return ws
end

local function hostOf(page)
    local pane = page ~= nil and page.inventoryPane or nil
    return pane ~= nil and pane.comfyHost or nil
end

local function nodesFor(page)
    local host = hostOf(page)
    local panels = host ~= nil and host.panels or nil
    if panels == nil then return nil, nil end
    local nodes = {}

    local band = page._comfyStrip
    if band ~= nil and band:getIsVisible() and band.padChipCount ~= nil then
        nodes[#nodes + 1] = { kind = "chip", el = band, panel = page,
            fixed = true }
    end

    local strips = host.strips
    if strips ~= nil then

        if strips.equipStrip ~= nil and strips.equipStrip:getIsVisible() then
            nodes[#nodes + 1] = { kind = "equip", el = strips.equipStrip,
                panel = strips }
        end
        if strips.hotbarStrip ~= nil
                and strips.hotbarStrip:getIsVisible() then
            nodes[#nodes + 1] = { kind = "hotbar", el = strips.hotbarStrip,
                panel = strips }
        end
        local pp = strips.pocketsPanel
        local gvs = pp ~= nil and pp.gridViews or nil
        if gvs ~= nil then
            for j = 1, #gvs do
                nodes[#nodes + 1] = { kind = "pocket", el = gvs[j],
                    panel = strips }
            end
        end
    end
    for i = 1, #panels do
        local p = panels[i]

        if p.padChipCount ~= nil then
            nodes[#nodes + 1] = { kind = "chip", el = p, panel = p }
        end
        if p.gridView ~= nil then
            nodes[#nodes + 1] = { kind = "grid", el = p.gridView, panel = p }
        end
    end

    do
        local W = ComfyGrid.UI and ComfyGrid.UI.EquipWindow
        local win = W ~= nil and W.windowFor ~= nil and W.windowFor(page.player)
            or nil

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

    do
        local CW = ComfyGrid.UI and ComfyGrid.UI.ContainerWindow
        local win = CW ~= nil and CW.windowFor ~= nil
            and CW.windowFor(page.player) or nil
        local grid = CW ~= nil and CW.gridFor ~= nil
            and CW.gridFor(page.player) or nil
        if page.onCharacter == true and win ~= nil and grid ~= nil
                and win:getIsVisible() then

            nodes[#nodes + 1] = { kind = "grid", el = grid, panel = win,
                side = true, bubble = true }
        end
    end
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

local function stampNode(ws, node, slot)
    local count = countOf(node)
    if slot < 0 then slot = 0 end
    if count > 0 and slot >= count then slot = count - 1 end
    ws.el = node.el
    ws.kind = node.kind
    ws.slot = slot

    local el = node.el
    if el.padFocusChanged ~= nil then el:padFocusChanged(slot) end
end

local function ensureVisible(host, node, slot)

    if host == nil or node.side or node.fixed then return end
    local stride = Style.CELL_STRIDE or 46
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
    local st = stateFor(page.player)
    st.page = page
    st.active = true
    local ws = winState(st, page)
    local nodes = nodesFor(page)
    local cur = nodes ~= nil and indexOfEl(nodes, ws.el) or nil

    if nodes ~= nil and (cur == nil or nodes[cur].side
            or nodes[cur].kind == "chip"
            or countOf(nodes[cur]) < 1) then
        local idx = defaultIndex(nodes, page)
        if idx ~= nil then stampNode(ws, nodes[idx], ws.slot or 0) end
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
    local st = stateFor(page.player)
    local ws = winState(st, target)
    local nodes, host = nodesFor(target)
    if nodes == nil then return false end
    local cur = indexOfEl(nodes, ws.el)

    if cur == nil or nodes[cur].side or countOf(nodes[cur]) < 1 then
        cur = defaultIndex(nodes, target)
        if cur == nil then return false end
    end
    stampNode(ws, nodes[cur], ws.slot or 0)
    ensureVisible(host, nodes[cur], ws.slot)
    setJoypadFocus(page.player, target)
    return true
end

function PadFocus.eachGridNode(page, fn)
    local nodes = nodesFor(page)
    if nodes == nil then return end
    for i = 1, #nodes do
        local n = nodes[i]
        if n.kind == "grid" or n.kind == "pocket" then
            fn(n.el)
        end
    end
end

function PadFocus.onLose(page)
    local st = states[page.player]

    if st == nil or st.page ~= page then return end

    if getFocusForPlayer(page.player) ~= nil then return end
    st.active = false

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

local function crossWindow(st, page, dir, fromRow)
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
    local ws = winState(st, other)
    local cols = node.el.cols or 1
    local rows = node.el.rows or 1
    local row = fromRow
    if row > rows - 1 then row = rows - 1 end
    if row < 0 then row = 0 end
    local col = dir > 0 and 0 or (cols - 1)
    stampNode(ws, node, row * cols + col)
    ensureVisible(host, node, ws.slot)

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

local function centreX(w)
    return w:getAbsoluteX() + (w:getWidth() or 0) / 2
end

local function dirOf(node, page)
    local w = node.panel
    if w == nil then return 0, 0 end
    if w.docked == true and w.dockSide == "above" then return 0, -1 end
    if w.getAbsoluteX == nil then return 0, 0 end

    return centreX(w) < centreX(page) and -1 or 1, 0
end

local function sideSpan(node, page)
    local w = node.panel
    if w == nil or w.getAbsoluteX == nil then return 0 end
    local d = centreX(w) - centreX(page)
    return d < 0 and -d or d
end

local function sideNodeOn(nodes, page, dx, dy, after)
    if dx == 0 and dy == 0 then return nil end
    local floor = after ~= nil and sideSpan(after, page) or nil
    local best, bestSpan = nil, nil
    for i = 1, #nodes do
        local n = nodes[i]

        if n.side and not n.bubble and n.kind ~= "chip" and countOf(n) > 0
                and n ~= after then
            local wx, wy = dirOf(n, page)
            if wx == dx and wy == dy then
                local span = sideSpan(n, page)
                if floor == nil or span > floor then
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
        local w = el.getWidth ~= nil and el:getWidth() or 0
        local h = el.getHeight ~= nil and el:getHeight() or 0
        local col = w > 0 and math.floor((fromAbsX - ex0) / (w / cols)) or 0
        local row = h > 0 and math.floor((fromAbsY - ey0) / (h / rows)) or 0
        if col < 0 then col = 0 elseif col > cols - 1 then col = cols - 1 end
        if row < 0 then row = 0 elseif row > rows - 1 then row = rows - 1 end
        local slot = row * cols + col
        if slot > count - 1 then slot = count - 1 end
        if slot < 0 then slot = 0 end
        return slot
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
    local w = node.panel
    if w ~= nil and w.isCollapsed and w.uncollapse ~= nil then
        w:uncollapse()
    end
end

local function leaveSide(page, nodes, ws, host)
    local idx = indexOfEl(nodes, ws.homeEl)
    if idx == nil or nodes[idx].side or countOf(nodes[idx]) < 1 then
        idx = defaultIndex(nodes, page)
    end
    if idx == nil then return end
    stampNode(ws, nodes[idx], ws.homeSlot or 0)
    ensureVisible(host, nodes[idx], ws.slot)
end

local function orderModel()
    return ComfyGrid.Model and ComfyGrid.Model.ContainerOrder or nil
end

function PadFocus.focusInventory(page, inv)
    if inv == nil then return false end
    local nodes, host = nodesFor(page)
    if nodes == nil then return false end
    local ws = winState(stateFor(page.player), page)

    local cur = indexOfEl(nodes, ws.el)
    if cur ~= nil then
        local m = nodes[cur].el.model
        if m ~= nil and m.inventory == inv then
            ensureVisible(host, nodes[cur], ws.slot)
            return true
        end
    end
    for i = 1, #nodes do
        local n = nodes[i]

        if n.kind == "grid" or n.kind == "pocket" then
            local model = n.el.model
            if model ~= nil and model.inventory == inv then
                stampNode(ws, n, ws.slot or 0)
                ensureVisible(host, n, ws.slot)
                return true
            end
        end
    end
    return false
end

function PadFocus.movingInv(page)
    return winState(stateFor(page.player), page).moving
end

function PadFocus.canMove(page)
    local Order = orderModel()
    if Order == nil then return nil end
    local kind, el = PadFocus.peek(page)

    if kind ~= "grid" and kind ~= "chip" then return nil end
    local inv = el.model ~= nil and el.model.inventory or nil
    if inv == nil or Order.indexOf(page, inv) == nil then return nil end
    if Order.isPinned(inv, getSpecificPlayer(page.player), page.player) then
        return nil
    end
    return inv
end

function PadFocus.beginMove(page)
    local Order = orderModel()
    local inv = PadFocus.canMove(page)
    if Order == nil or inv == nil then return nil end
    local ws = winState(stateFor(page.player), page)
    ws.moving = inv

    ws.movedFrom = Order.keysOf(page)
    return inv
end

function PadFocus.endMove(page, cancel)
    local ws = winState(stateFor(page.player), page)
    if ws.moving == nil then return false end
    local was = ws.movedFrom
    ws.moving, ws.movedFrom = nil, nil
    local Order = orderModel()
    if Order == nil then return true end
    if cancel and was ~= nil then
        Order.set(page.player, was)
        pcall(Order.apply, page)
    else
        pcall(Order.commit, page)
    end
    return true
end

local function movePress(page, inv, dx, dy)
    local Order = orderModel()
    if Order == nil then return true end
    if dx ~= 0 or dy == 0 then
        PadFocus.endMove(page)
        PadFocus.focusInventory(page, inv)
        return true
    end
    local at = Order.indexOf(page, inv)
    if at == nil then
        PadFocus.endMove(page)
        return true
    end
    Order.preview(page, inv, at + dy)
    Order.layout(page)
    PadFocus.focusInventory(page, inv)
    return true
end

local function leaveBubble(page, nodes, ws, host, dx, dy)
    local idx = indexOfEl(nodes, ws.homeEl)
    if idx == nil or nodes[idx].side or countOf(nodes[idx]) < 1 then
        idx = defaultIndex(nodes, page)
    end
    if idx == nil then return true end
    local node = nodes[idx]
    local count = countOf(node)
    local cols = shapeOf(node, count)
    local slot = ws.homeSlot or 0
    if slot >= count then slot = count - 1 end
    if slot < 0 then slot = 0 end
    local col = slot % cols + (dx or 0)
    local row = math.floor(slot / cols) + (dy or 0)
    if col < 0 then col = 0 elseif col > cols - 1 then col = cols - 1 end
    if row < 0 then row = 0 end
    local nslot = row * cols + col
    if nslot >= count then nslot = count - 1 end
    if nslot < 0 then nslot = 0 end
    stampNode(ws, node, nslot)
    ensureVisible(host, node, ws.slot)
    if nslot == slot then ws.bubbleSkip = true end
    return true
end

local function sideEdge(st, node, page, nodes, ws, host, dx, dy)

    if node.bubble then
        return leaveBubble(page, nodes, ws, host, dx, dy)
    end
    local wx, wy = dirOf(node, page)
    if dx == -wx and dy == -wy then
        leaveSide(page, nodes, ws, host)
        return true
    end

    local idx = sideNodeOn(nodes, page, dx, dy, node)
    if idx ~= nil then
        local sn = nodes[idx]
        enterSide(sn)
        stampNode(ws, sn, 0)
        ensureVisible(host, sn, ws.slot)
        return true
    end
    if dx ~= 0 then crossWindow(st, page, dx, 0) end
    return true
end

local function enterSideOn(nodes, page, ws, node, slot, cols, dx, dy)
    local idx = sideNodeOn(nodes, page, dx, dy)
    if idx == nil then return false end
    local sn = nodes[idx]
    enterSide(sn)
    local ax, ay = cursorAbs(node, slot, cols)
    ws.homeEl, ws.homeSlot = node.el, slot
    stampNode(ws, sn, raggedEntry(sn.el, countOf(sn), ax, ay))
    return true
end

local function bubbleRedirect(page)
    local CW = ComfyGrid.UI and ComfyGrid.UI.ContainerWindow
    local grid = CW ~= nil and CW.gridFor ~= nil and CW.gridFor(page.player)
        or nil
    if grid == nil then return end
    local ws = winState(stateFor(page.player), page)
    if ws.bubbleSkip then
        ws.bubbleSkip = nil
        return
    end
    if ws.el == grid then return end
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
    local bidx, fidx = nil, indexOfEl(nodes, el)
    for i = 1, #nodes do
        if nodes[i].el == grid then bidx = i break end
    end
    if bidx == nil or countOf(nodes[bidx]) < 1 then return end
    local from = fidx ~= nil and nodes[fidx] or nil
    local ax, ay = 0, 0
    if from ~= nil then
        ax, ay = cursorAbs(from, slot, shapeOf(from, countOf(from)))
    end
    enterSide(nodes[bidx])

    ws.homeEl, ws.homeSlot = el, slot
    stampNode(ws, nodes[bidx], raggedEntry(nodes[bidx].el,
        countOf(nodes[bidx]), ax, ay))
    ensureVisible(host, nodes[bidx], ws.slot)
end

local function onDirStep(page, dx, dy)
    local st = stateFor(page.player)
    st.page = page

    local moving = winState(st, page).moving
    if moving ~= nil then return movePress(page, moving, dx, dy) end
    local nodes, host = nodesFor(page)
    if nodes == nil then return false end
    local ws = winState(st, page)
    local cur = indexOfEl(nodes, ws.el)
    if cur == nil or countOf(nodes[cur]) < 1 then

        cur = defaultIndex(nodes, page)
        if cur == nil then return false end
        stampNode(ws, nodes[cur], ws.slot or 0)
        ensureVisible(host, nodes[cur], ws.slot)
        return true
    end
    local node = nodes[cur]
    local count = countOf(node)
    local cols, rows = shapeOf(node, count)
    local slot = ws.slot or 0
    if slot >= count then slot = count - 1 end
    if slot < 0 then slot = 0 end
    local col = slot % cols
    local row = math.floor(slot / cols)

    if node.el.padRagged == true and node.el.padTileXY ~= nil then
        local target = raggedStep(node.el, slot, dx, dy, count)
        if target ~= nil then
            stampNode(ws, node, target)
            return true
        end

        if dy ~= 0 then

            local nextNode, enterSlot = verticalStep(nodes, cur,
                dy > 0 and 1 or -1, 0)
            if nextNode ~= nil then
                stampNode(ws, nextNode, enterSlot)
                ensureVisible(host, nextNode, ws.slot)
                return true
            end
        end
        if node.side then
            return sideEdge(st, node, page, nodes, ws, host, dx, dy)
        end
        return true
    end

    if dx ~= 0 then
        local ncol = col + dx
        local nslot = row * cols + ncol
        if ncol >= 0 and ncol < cols and nslot < count then
            stampNode(ws, node, nslot)
            ensureVisible(host, node, ws.slot)
            return true
        end

        if node.kind == "pocket" then
            local sib = nodes[cur + dx]
            if sib ~= nil and sib.kind == "pocket" and countOf(sib) > 0 then
                local sCols = sib.el.cols or 1
                local sRows = sib.el.rows or 1
                local sRow = row
                if sRow > sRows - 1 then sRow = sRows - 1 end
                local sCol = dx > 0 and 0 or (sCols - 1)
                stampNode(ws, sib, sRow * sCols + sCol)
                ensureVisible(host, sib, ws.slot)
                return true
            end
        end

        if node.side then
            return sideEdge(st, node, page, nodes, ws, host, dx, 0)
        end

        if enterSideOn(nodes, page, ws, node, slot, cols, dx, 0) then
            return true
        end

        crossWindow(st, page, dx, row)
        return true
    end

    local nrow = row + dy
    local nslot = nrow * cols + col
    if nrow >= 0 and nrow <= rows - 1 then
        if nslot >= count then nslot = count - 1 end
        stampNode(ws, node, nslot)
        ensureVisible(host, node, ws.slot)
        return true
    end
    local nextNode, enterSlot = verticalStep(nodes, cur, dy > 0 and 1 or -1, col)
    if nextNode ~= nil then
        stampNode(ws, nextNode, enterSlot)
        ensureVisible(host, nextNode, ws.slot)
        return true
    end
    if node.side then
        return sideEdge(st, node, page, nodes, ws, host, 0, dy)
    end

    enterSideOn(nodes, page, ws, node, slot, cols, 0, dy)
    return true
end

function PadFocus.onDir(page, dx, dy)
    local handled = onDirStep(page, dx, dy)
    if handled then pcall(bubbleRedirect, page) end
    return handled
end

function PadFocus.cursorFor(el)
    local st = states[el.playerNum]
    if st == nil or not st.active then return nil end
    local page = st.page
    if page == nil then return nil end
    local ws = st.win[page]
    if ws == nil or ws.el ~= el then return nil end
    return ws.slot
end

function PadFocus.peek(page)
    local st = stateFor(page.player)
    local ws = winState(st, page)
    local el = ws.el
    if el == nil then return nil end
    local kind = ws.kind
    local slot = ws.slot or 0
    if kind == "equip" then
        if slot >= (el.entryCount or 0) then return nil end
        local entry = el.entries ~= nil and el.entries[slot + 1] or nil
        local item = entry ~= nil and entry.items ~= nil and entry.items[1]
            or nil
        return kind, el, slot, item
    end
    if kind == "chip" then

        local n = el.padChipCount ~= nil and el:padChipCount() or 0
        if slot >= n then return nil end
        return kind, el, slot, nil
    end
    if kind == "hotbar" then
        if slot >= (el.entryCount or 0) then return nil end

        local ok, hotbar = pcall(getPlayerHotbar, el.playerNum)
        local item = ok and hotbar ~= nil and hotbar.attachedItems ~= nil
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
