--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.7
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local HotbarGhosts = {}
ComfyGrid.UI.HotbarGhosts = HotbarGhosts

local GHOST_ITEMS = {
    SmallBeltLeft = "Base.HuntingKnife",
    SmallBeltRight = "Base.HuntingKnife",
    WebbingLeft = "Base.HuntingKnife",
    WebbingRight = "Base.HuntingKnife",
    HolsterLeft = "Base.Pistol",
    HolsterRight = "Base.Pistol",
    HolsterShoulder = "Base.Pistol",
    HolsterAnkle = "Base.Pistol",
    Back = "Base.BaseballBat",
    Bag = "Base.Bag_Schoolbag",

    BedrollBottom = "Base.SleepingBag_Green_Packed",
    BedrollBottomBig = "Base.SleepingBag_Green_Packed",
    BedrollBottomALICE = "Base.SleepingBag_Green_Packed",
}

local ATTACH_ITEMS = {
    Bedroll = "Base.SleepingBag_Green_Packed",
    Holster = "Base.Pistol",
    HolsterSmall = "Base.Pistol",
    Knife = "Base.HuntingKnife",
    BigBlade = "Base.HuntingKnife",
    Rifle = "Base.HuntingRifle",
    BigWeapon = "Base.HuntingRifle",
    Hammer = "Base.Hammer",
}
local ghostTexCache = {}

function HotbarGhosts.texFor(slot)
    if slot == nil then return nil end
    local key = tostring(slot.slotType or slot.name or "?")
    local cached = ghostTexCache[key]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local fullType = GHOST_ITEMS[key]
    if fullType == nil and slot.def ~= nil
            and type(slot.def.attachments) == "table" then
        for attachType in pairs(slot.def.attachments) do
            if ATTACH_ITEMS[attachType] ~= nil then
                fullType = ATTACH_ITEMS[attachType]
                break
            end
        end
    end
    if fullType == nil then
        if key:find("Holster") ~= nil then
            fullType = "Base.Pistol"
        elseif key:find("Belt") ~= nil or key:find("Webbing") ~= nil then
            fullType = "Base.HuntingKnife"
        end
    end
    local tex = nil
    if fullType ~= nil and instanceItem ~= nil then
        local ok, item = pcall(instanceItem, fullType)
        if ok and item ~= nil and item.getTex ~= nil then
            local okT, t = pcall(item.getTex, item)
            if okT then tex = t end
        end
    end
    ghostTexCache[key] = tex or false
    return tex
end
