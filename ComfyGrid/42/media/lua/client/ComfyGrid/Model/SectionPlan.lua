--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
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

local function isPocketSized(inventory, playerNum)
    return Capacity.slotsFor(inventory, playerNum) <= SectionPlan.POCKET_MAX_SLOTS
end

function SectionPlan.newPlan()
    return {
        sections = {}, count = 0,
        pockets = {}, pocketCount = 0,
        playerStrips = false,
        stacked = false,
        _gathered = {}, _gatherCount = 0,
    }
end

local function clearArrayTail(array, count)
    for i = count, 1, -1 do array[i] = nil end
end

local function lootSectionAllowed(page, inv, playerObj)
    local okParent, parent = pcall(inv.getParent, inv)
    if okParent and parent ~= nil and instanceof(parent, "IsoThumpable")
            and parent.isLockedToCharacter ~= nil then
        local okLocked, locked = pcall(parent.isLockedToCharacter, parent, playerObj)
        if okLocked and locked then return false end
    end
    if page.checkExplored ~= nil then
        pcall(page.checkExplored, page, inv, playerObj)
    end
    return true
end

local function gather(plan, page, pane, gate, playerObj)
    local gathered = plan._gathered
    clearArrayTail(gathered, plan._gatherCount)
    local gatheredCount = 0

    local Order = ComfyGrid.Model and ComfyGrid.Model.ContainerOrder
    local buttons = Order ~= nil and Order.sequenceFor(page) or nil
    if buttons == nil then buttons = page ~= nil and page.backpacks or nil end
    if type(buttons) == "table" then
        for i = 1, #buttons do
            local inv = buttons[i] ~= nil and buttons[i].inventory or nil
            if inv ~= nil and (gate == nil or gate(page, inv, playerObj)) then
                local alreadyGathered = false
                for j = 1, gatheredCount do
                    if gathered[j] == inv then
                        alreadyGathered = true
                        break
                    end
                end
                if not alreadyGathered then
                    gatheredCount = gatheredCount + 1
                    gathered[gatheredCount] = inv
                end
            end
        end
    end
    if gatheredCount == 0 and pane.inventory ~= nil then
        gatheredCount = 1
        gathered[1] = pane.inventory
    end
    plan._gatherCount = gatheredCount
    return gathered, gatheredCount
end

SectionPlan.STRATEGIES = {}

local function playerSections(plan, page, pane, foldPockets)
    local playerObj = getSpecificPlayer(pane.player)
    local containers, containerCount = gather(plan, page, pane, nil, playerObj)

    local sections, pockets = plan.sections, plan.pockets
    clearArrayTail(sections, plan.count)
    clearArrayTail(pockets, plan.pocketCount)
    local sectionCount, pocketCount = 0, 0

    local Order = ComfyGrid.Model and ComfyGrid.Model.ContainerOrder

    for i = 1, containerCount do
        local inv = containers[i]

        local isMain = (Order ~= nil and Order.isMain(inv, playerObj))
            or (Order == nil and i == 1)
        if isMain then

            sectionCount = sectionCount + 1
            sections[sectionCount] = inv
        elseif foldPockets and isPocketSized(inv, pane.player) then
            pocketCount = pocketCount + 1
            pockets[pocketCount] = inv
        else
            sectionCount = sectionCount + 1
            sections[sectionCount] = inv
        end
    end

    plan.count, plan.pocketCount = sectionCount, pocketCount
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
    local containers, containerCount = gather(plan, page, pane,
        lootSectionAllowed, playerObj)

    local sections = plan.sections
    clearArrayTail(sections, plan.count)
    clearArrayTail(plan.pockets, plan.pocketCount)
    for i = 1, containerCount do sections[i] = containers[i] end

    plan.count, plan.pocketCount = containerCount, 0
    plan.playerStrips = false
    plan.stacked = true
end

function SectionPlan.STRATEGIES.single(plan, page, pane)
    local sections = plan.sections
    clearArrayTail(sections, plan.count)
    clearArrayTail(plan.pockets, plan.pocketCount)
    local sectionCount = 0
    if pane.inventory ~= nil then
        sectionCount = 1
        sections[1] = pane.inventory
    end

    plan.count, plan.pocketCount = sectionCount, 0
    plan.playerStrips = (sectionCount > 0 and page ~= nil and page.onCharacter == true)
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

local function playerStrategy()
    return PLAYER_MODE[Settings.get("PLAYER_LAYOUT")] or "playerCompact"
end

function SectionPlan.foldsPockets()
    return playerStrategy() == "playerCompact"
end

function SectionPlan.isPocket(inventory, playerObj, playerNum)
    if not SectionPlan.foldsPockets() then return false end

    local Order = ComfyGrid.Model and ComfyGrid.Model.ContainerOrder
    if Order ~= nil and Order.isMain(inventory, playerObj) then return false end
    local ok, small = pcall(isPocketSized, inventory, playerNum)
    return ok and small == true
end

function SectionPlan.pick(page, _pane)
    if page ~= nil and page.onCharacter == true then
        return playerStrategy()
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
