--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.4.0
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
    for i = 1, #panels do
        local p = panels[i]
        if p.equipStrip ~= nil then
            nodes[#nodes + 1] = { kind = "equip", el = p.equipStrip, panel = p }
        end
        if p.hotbarStrip ~= nil then
            nodes[#nodes + 1] = { kind = "hotbar", el = p.hotbarStrip, panel = p }
        end
        local pp = p.pocketsPanel
        local gvs = pp ~= nil and pp.gridViews or nil
        if gvs ~= nil then
            for j = 1, #gvs do
                nodes[#nodes + 1] = { kind = "pocket", el = gvs[j], panel = p }
            end
        end
        if p.gridView ~= nil then
            nodes[#nodes + 1] = { kind = "grid", el = p.gridView, panel = p }
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

local function defaultIndex(nodes, page)
    local host = hostOf(page)
    local mainGrid = host ~= nil and host.panels[1] ~= nil
        and host.panels[1].gridView or nil
    local idx = indexOfEl(nodes, mainGrid)
    if idx ~= nil and countOf(nodes[idx]) > 0 then return idx end
    for i = 1, #nodes do
        if countOf(nodes[i]) > 0 then return i end
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
end

local function ensureVisible(host, node, slot)
    if host == nil then return end
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
    local row = math.floor(slot / cols)
    local top = (node.panel.y or 0) + (host.yOffset or 0) + gy + row * stride
    local bottom = top + cell
    local view = host.height or 0
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
    if ws.el == nil then
        local nodes = nodesFor(page)
        local idx = nodes ~= nil and defaultIndex(nodes, page) or nil
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
    if cur == nil or countOf(nodes[cur]) < 1 then
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
    local fromPocket = nodes[cur].kind == "pocket"
    local idx = cur + step
    while nodes[idx] ~= nil do
        local node = nodes[idx]
        local skip = countOf(node) < 1
            or (fromPocket and node.kind == "pocket")
        if not skip then
            local cols = node.el.cols or 1
            local rows = node.el.rows or 1
            local nCol = col
            if nCol > cols - 1 then nCol = cols - 1 end
            local enterRow = step > 0 and 0 or (rows - 1)
            return node, enterRow * cols + nCol
        end
        idx = idx + step
    end
    return nil
end

function PadFocus.onDir(page, dx, dy)
    local st = stateFor(page.player)
    st.page = page
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
    local cols = node.el.cols or 1
    local rows = node.el.rows or 1
    local slot = ws.slot or 0
    if slot >= count then slot = count - 1 end
    if slot < 0 then slot = 0 end
    local col = slot % cols
    local row = math.floor(slot / cols)

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
    end
    return true
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
