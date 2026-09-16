--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Model/Capacity"
require "ComfyGrid/Model/ContainerOrder"
require "ComfyGrid/Settings"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local SectionPlan = {}
ComfyGrid.Model.SectionPlan = SectionPlan

local Capacity = ComfyGrid.Model.Capacity
local Settings = ComfyGrid.Settings

SectionPlan.POCKET_MAX_SLOTS = 6

function SectionPlan.newPlan()
    return {
        sections = {}, count = 0,
        pockets = {}, pocketCount = 0,
        playerStrips = false,
        stacked = false,
        _gathered = {}, _gatherCount = 0,
    }
end

local function wipe(t, n)
    for i = n, 1, -1 do t[i] = nil end
end

local function lootSectionAllowed(page, inv, playerObj)
    local okP, parent = pcall(inv.getParent, inv)
    if okP and parent ~= nil and instanceof(parent, "IsoThumpable")
            and parent.isLockedToCharacter ~= nil then
        local okL, locked = pcall(parent.isLockedToCharacter, parent, playerObj)
        if okL and locked then return false end
    end
    if page.checkExplored ~= nil then
        pcall(page.checkExplored, page, inv, playerObj)
    end
    return true
end

local function gather(plan, page, pane, gate, playerObj)
    local out = plan._gathered
    wipe(out, plan._gatherCount)
    local n = 0

    local Order = ComfyGrid.Model and ComfyGrid.Model.ContainerOrder
    local buttons = Order ~= nil and Order.sequenceFor(page) or nil
    if buttons == nil then buttons = page ~= nil and page.backpacks or nil end
    if type(buttons) == "table" then
        for i = 1, #buttons do
            local inv = buttons[i] ~= nil and buttons[i].inventory or nil
            if inv ~= nil and (gate == nil or gate(page, inv, playerObj)) then
                local dup = false
                for j = 1, n do
                    if out[j] == inv then
                        dup = true
                        break
                    end
                end
                if not dup then
                    n = n + 1
                    out[n] = inv
                end
            end
        end
    end
    if n == 0 and pane.inventory ~= nil then
        n = 1
        out[1] = pane.inventory
    end
    plan._gatherCount = n
    return out, n
end

SectionPlan.STRATEGIES = {}

local function playerSections(plan, page, pane, foldPockets)
    local playerObj = getSpecificPlayer(pane.player)
    local invs, n = gather(plan, page, pane, nil, playerObj)

    local sections, pockets = plan.sections, plan.pockets
    wipe(sections, plan.count)
    wipe(pockets, plan.pocketCount)
    local sc, pc = 0, 0

    local Order = ComfyGrid.Model and ComfyGrid.Model.ContainerOrder

    for i = 1, n do
        local inv = invs[i]

        local isMain = (Order ~= nil and Order.isMain(inv, playerObj))
            or (Order == nil and i == 1)
        if isMain then

            sc = sc + 1
            sections[sc] = inv
        elseif foldPockets
                and Capacity.slotsFor(inv, pane.player) <= SectionPlan.POCKET_MAX_SLOTS then
            pc = pc + 1
            pockets[pc] = inv
        else
            sc = sc + 1
            sections[sc] = inv
        end
    end

    plan.count, plan.pocketCount = sc, pc
    plan.playerStrips = true
    plan.stacked = true
end

function SectionPlan.STRATEGIES.playerCompact(plan, page, pane)
    playerSections(plan, page, pane, true)
end

function SectionPlan.STRATEGIES.playerFull(plan, page, pane)
    playerSections(plan, page, pane, false)
end

function SectionPlan.STRATEGIES.lootSections(plan, page, pane)
    local playerObj = getSpecificPlayer(pane.player)
    local invs, n = gather(plan, page, pane, lootSectionAllowed, playerObj)

    local sections = plan.sections
    wipe(sections, plan.count)
    wipe(plan.pockets, plan.pocketCount)
    for i = 1, n do sections[i] = invs[i] end

    plan.count, plan.pocketCount = n, 0
    plan.playerStrips = false
    plan.stacked = true
end

function SectionPlan.STRATEGIES.single(plan, page, pane)
    local sections = plan.sections
    wipe(sections, plan.count)
    wipe(plan.pockets, plan.pocketCount)
    local n = 0
    if pane.inventory ~= nil then
        n = 1
        sections[1] = pane.inventory
    end

    plan.count, plan.pocketCount = n, 0
    plan.playerStrips = (n > 0 and page ~= nil and page.onCharacter == true)
    plan.stacked = false
end

local PLAYER_MODE = {
    compact = "playerCompact",
    full    = "playerFull",
    single  = "single",
}
local LOOT_MODE = {
    sections = "lootSections",
    single   = "single",
}

function SectionPlan.pick(page, _pane)
    if page ~= nil and page.onCharacter == true then
        return PLAYER_MODE[Settings.get("PLAYER_LAYOUT")] or "playerCompact"
    end
    if page ~= nil and page.onCharacter == false then
        return LOOT_MODE[Settings.get("LOOT_LAYOUT")] or "single"
    end
    return "single"
end

function SectionPlan.build(plan, page, pane)
    SectionPlan.STRATEGIES[SectionPlan.pick(page, pane)](plan, page, pane)
    return plan
end
