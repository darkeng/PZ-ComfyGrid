--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local Herbalist = {}
ComfyGrid.Model.Herbalist = Herbalist

local isFoodByType = {}

function Herbalist.typeOf(item, fullType)
    if item == nil then return nil end

    local isFood = nil
    if fullType ~= nil then isFood = isFoodByType[fullType] end
    if isFood == nil then
        local okFood, answeredFood = pcall(item.IsFood, item)
        if not okFood then return nil end
        isFood = false
        if answeredFood then isFood = true end
        if fullType ~= nil then isFoodByType[fullType] = isFood end
    end
    if not isFood then return nil end
    if item.getHerbalistType == nil then return nil end
    local okType, herbalistType = pcall(item.getHerbalistType, item)
    if not okType or herbalistType == nil then return nil end
    herbalistType = tostring(herbalistType)
    if herbalistType == "" then return nil end
    return herbalistType
end

function Herbalist.maskFor(item, playerObj)
    local herbalistType = Herbalist.typeOf(item)
    if herbalistType == nil then return nil end

    if herbalistType ~= "Berry" and herbalistType ~= "Mushroom" then return nil end

    local known = false
    if playerObj ~= nil and playerObj.isRecipeActuallyKnown ~= nil then
        local okKnown, knowsRecipe = pcall(playerObj.isRecipeActuallyKnown,
            playerObj, "Herbalist")
        known = okKnown and knowsRecipe == true
    end
    if not known then
        if herbalistType == "Berry" then return getText("IGUI_UnknownBerry") end
        return getText("IGUI_UnknownMushroom")
    end

    local poison = 0
    if item.getPoisonPower ~= nil then
        local okPoison, poisonPower = pcall(item.getPoisonPower, item)
        if okPoison and type(poisonPower) == "number" then poison = poisonPower end
    end
    if herbalistType == "Berry" then
        if poison > 0 then return getText("IGUI_PoisonousBerry") end
        return getText("IGUI_Berry")
    end
    if poison > 0 then return getText("IGUI_PoisonousMushroom") end
    return getText("IGUI_Mushroom")
end

function Herbalist.applyMask(inventory, playerNum)
    if inventory == nil then return 0 end
    local playerObj = nil
    if playerNum ~= nil then
        local okPlayer, player = pcall(getSpecificPlayer, playerNum)
        if okPlayer then playerObj = player end
    end
    local okItems, items = pcall(inventory.getItems, inventory)
    if not okItems or items == nil then return 0 end
    local changed = 0

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local masked = Herbalist.maskFor(item, playerObj)
        if masked ~= nil then
            local okName, current = pcall(item.getDisplayName, item)
            if okName and current ~= masked then
                pcall(item.setName, item, masked)
                changed = changed + 1
            end
        end
    end
    return changed
end

function Herbalist.groupNameOf(item, fullType)
    if Herbalist.typeOf(item, fullType) == nil then return nil end
    local okName, name = pcall(item.getDisplayName, item)
    if okName and name ~= nil and tostring(name) ~= "" then
        return tostring(name)
    end
    return nil
end
