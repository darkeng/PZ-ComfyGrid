--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.7.3
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local Herbalist = {}
ComfyGrid.Model.Herbalist = Herbalist

function Herbalist.typeOf(item)
    if item == nil then return nil end
    local okFood, isFood = pcall(item.IsFood, item)
    if not okFood or not isFood then return nil end
    if item.getHerbalistType == nil then return nil end
    local okType, hType = pcall(item.getHerbalistType, item)
    if not okType or hType == nil then return nil end
    hType = tostring(hType)
    if hType == "" then return nil end
    return hType
end

function Herbalist.maskFor(item, playerObj)
    local hType = Herbalist.typeOf(item)
    if hType == nil then return nil end

    if hType ~= "Berry" and hType ~= "Mushroom" then return nil end

    local known = false
    if playerObj ~= nil and playerObj.isRecipeActuallyKnown ~= nil then
        local okKnown, k = pcall(playerObj.isRecipeActuallyKnown, playerObj,
            "Herbalist")
        known = okKnown and k == true
    end
    if not known then
        if hType == "Berry" then return getText("IGUI_UnknownBerry") end
        return getText("IGUI_UnknownMushroom")
    end

    local poison = 0
    if item.getPoisonPower ~= nil then
        local okPoison, p = pcall(item.getPoisonPower, item)
        if okPoison and type(p) == "number" then poison = p end
    end
    if hType == "Berry" then
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
        local okPlayer, p = pcall(getSpecificPlayer, playerNum)
        if okPlayer then playerObj = p end
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

function Herbalist.groupNameOf(item)
    if Herbalist.typeOf(item) == nil then return nil end
    local okName, name = pcall(item.getDisplayName, item)
    if okName and name ~= nil and tostring(name) ~= "" then
        return tostring(name)
    end
    return nil
end
