--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Settings"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/StackRenderer"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local TileCache = {}
ComfyGrid.UI.TileCache = TileCache

local Style = ComfyGrid.UI.Style
local StackRenderer = ComfyGrid.UI.StackRenderer
local floor = math.floor

TileCache.enabled = true

local TTL_MS = 80
local RECORD_BUDGET = 12
local MAX_ENTRIES = 1024
local MAX_ARGS = 10
local GOLDEN_FRACTION = 0.6180339887498949
local NEAREST = "__nearest"

local POS = {
    DrawTextureScaledColor = 2,
    DrawTextureScaled = 2,
    DrawTextureScaledAspect = 2,
    DrawTextureIcon = 2,
    DrawTextureIconMask = 3,
    DrawItemIcon = 2,
    DrawText = 3,
    DrawTextCentre = 3,
}

local entries = {}
local entryCount = 0
local gen = 0
local serial = 0

local replays, records, lives = 0, 0, 0

function TileCache.stats()
    return replays, records, lives, gen, entryCount
end

local function bump()
    gen = gen + 1
    local Capacity = ComfyGrid.Model and ComfyGrid.Model.Capacity
    if Capacity ~= nil and Capacity.flushWeights ~= nil then Capacity.flushWeights() end
end
Style.onScaleChanged(bump)
for key in pairs(ComfyGrid.Settings.defaults) do
    ComfyGrid.Settings.onChanged(key, bump)
end

function TileCache.flush()
    bump()
end

local budget = 0
local boardView, boardGen, boardChange = nil, 0, 0
local mouseWasDown = false
local menuWasVisible = {}

function TileCache.beginBoard(view, viewGen, changeCount)
    budget = RECORD_BUDGET
    boardView, boardGen, boardChange = view, viewGen or 0, changeCount or 0
    local down = isMouseButtonDown(0) or isMouseButtonDown(1)
    if mouseWasDown and not down then bump() end
    mouseWasDown = down
    local pn = view ~= nil and view.playerNum or 0
    local menu = getPlayerContextMenu ~= nil and getPlayerContextMenu(pn) or nil
    local jo = menu ~= nil and menu.javaObject or nil
    local up = false
    if jo ~= nil and jo:isVisible() then up = true end
    if menuWasVisible[pn] and not up then bump() end
    menuWasVisible[pn] = up
end

local recEntry = nil
local recReal = nil

local function capture(e, name, fn, n, ...)
    local p = POS[name]
    if p == nil or n > MAX_ARGS then e.bad = true return end
    local k = e.n + 1
    local op = e.ops[k]
    if op == nil then
        op = {}
        e.ops[k] = op
    end
    op.name, op.fn, op.argc, op.pos = name, fn, n, p
    for i = 1, n do op[i] = (select(i, ...)) end
    if type(op[p]) ~= "number" or type(op[p + 1]) ~= "number" then
        e.bad = true
        return
    end
    e.n = k
end

local proxy = setmetatable({}, { __index = function(t, name)
    local f = function(_, ...)
        local real = recReal
        local fn = real[name]
        if recEntry ~= nil then capture(recEntry, name, fn, select("#", ...), ...) end
        return fn(real, ...)
    end
    rawset(t, name, f)
    return f
end })

local function tapNearest(tex)
    local e = recEntry
    if e == nil then return end
    local k = e.n + 1
    local op = e.ops[k]
    if op == nil then
        op = {}
        e.ops[k] = op
    end
    op.name, op.fn, op.argc, op.pos = NEAREST, nil, 1, nil
    op[1] = tex
    e.n = k
end

local function fluidOf(item)
    local fc = item.getFluidContainer ~= nil and item:getFluidContainer() or nil
    if fc == nil and item.getWorldItem ~= nil then
        local world = item:getWorldItem()
        if world ~= nil then fc = world:getFluidContainer() end
    end
    return fc
end

local function record(e, ctx, view, jo, now)
    e.n = 0
    e.bad = false
    recEntry, recReal = e, jo
    view.javaObject = proxy
    StackRenderer.setNearestTap(tapNearest)
    local ok, err = pcall(StackRenderer.draw, ctx)
    view.javaObject = jo
    StackRenderer.setNearestTap(nil)
    recEntry, recReal = nil, nil
    if not ok then
        e.bad = true
        error(err, 0)
    end
    local item = ctx.item
    e.front, e.count = item, ctx.stack.count
    e.gen, e.view, e.jo = gen, view, jo
    e.viewGen, e.change = boardGen, boardChange
    e.cell, e.player, e.skip = Style.CELL, ctx.playerNum, ctx.skipWeightMark
    e.ox, e.oy = ctx.x, ctx.y
    local fc = fluidOf(item)
    e.fluid = fc
    e.fluidAmount = fc ~= nil and fc:getAmount() or nil
    serial = serial + 1
    e.expires = now + TTL_MS + floor(((serial * GOLDEN_FRACTION) % 1) * TTL_MS)
end

local function valid(e, ctx, view, now)
    return not e.bad and e.gen == gen and now < e.expires
        and e.front == ctx.item and e.count == ctx.stack.count
        and e.view == view and e.jo == view.javaObject
        and e.viewGen == boardGen and e.change == boardChange
        and e.cell == Style.CELL and e.player == ctx.playerNum
        and e.skip == ctx.skipWeightMark
        and (e.fluid == nil or e.fluid:getAmount() == e.fluidAmount)
end

local function replay(e, jo, dx, dy)
    local ops = e.ops
    for k = 1, e.n do
        local op = ops[k]
        if op.name == NEAREST then
            StackRenderer.applyNearestTo(op[1])
        else
            local p = op.pos
            local x, y = op[p], op[p + 1]
            if dx ~= 0 or dy ~= 0 then
                op[p], op[p + 1] = x + dx, y + dy
                op.fn(jo, unpack(op, 1, op.argc))
                op[p], op[p + 1] = x, y
            else
                op.fn(jo, unpack(op, 1, op.argc))
            end
        end
    end
end

function TileCache.draw(ctx, now, live)
    local view = ctx.view
    local stack = ctx.stack
    local jo = view ~= nil and view.javaObject or nil
    if not TileCache.enabled or jo == nil or stack == nil or ctx.item == nil
            or view ~= boardView then
        lives = lives + 1
        return StackRenderer.draw(ctx)
    end
    local e = entries[stack]
    if e ~= nil and not live and valid(e, ctx, view, now) then
        replays = replays + 1
        replay(e, jo, ctx.x - e.ox, ctx.y - e.oy)
        return
    end
    if budget <= 0 then

        if e ~= nil then e.expires = 0 end
        lives = lives + 1
        return StackRenderer.draw(ctx)
    end
    budget = budget - 1
    records = records + 1
    if e == nil then
        if entryCount >= MAX_ENTRIES then
            entries = {}
            entryCount = 0
        end
        e = { ops = {}, n = 0 }
        entries[stack] = e
        entryCount = entryCount + 1
    end
    record(e, ctx, view, jo, now)
end
