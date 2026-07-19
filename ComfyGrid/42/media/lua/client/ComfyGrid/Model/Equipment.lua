--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.2.0
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local Equipment = {}
ComfyGrid.Model.Equipment = Equipment

Equipment.GROUPS = {
    { key = "Primary",   hand = "primary" },
    { key = "Secondary", hand = "secondary" },
    { key = "Head" },
    { key = "Face" },
    { key = "Neck" },
    { key = "Torso" },
    { key = "Hands" },
    { key = "Legs" },
    { key = "Feet" },
    { key = "Back" },
}

local LOCATION_GROUP = {

    Hat = "Head", FullHat = "Head", SweaterHat = "Head", JacketHat = "Head",
    JacketHat_Bulky = "Head", JacketHatBulky = "Head", FullSuitHead = "Head",
    FullSuitHeadSCBA = "Head",

    Mask = "Face", MaskEyes = "Face", MaskFull = "Face", Eyes = "Face",
    LeftEye = "Face", RightEye = "Face", Nose = "Face",
    Ears = "Face", EarTop = "Face",
    MakeUp_FullFace = "Face", MakeUpFullFace = "Face",
    MakeUp_Eyes = "Face", MakeUpEyes = "Face",
    MakeUp_EyesShadow = "Face", MakeUpEyesShadow = "Face",
    MakeUp_Lips = "Face", MakeUpLips = "Face",

    Neck = "Neck", Necklace = "Neck", Necklace_Long = "Neck",
    NecklaceLong = "Neck", NeckTexture = "Neck", Gorget = "Neck",
    Scarf = "Neck",

    Underwear = "Torso", UnderwearBottom = "Torso", UnderwearTop = "Torso",
    UnderwearExtra1 = "Torso", UnderwearExtra2 = "Torso",
    Torso1 = "Torso", Torso1Legs1 = "Torso", TankTop = "Torso",
    Tshirt = "Torso", ShortSleeveShirt = "Torso", Shirt = "Torso",
    Sweater = "Torso", Jersey = "Torso",
    Jacket = "Torso", Jacket_Bulky = "Torso", JacketBulky = "Torso",
    Jacket_Down = "Torso", JacketDown = "Torso",
    JacketSuit = "Torso", FullTop = "Torso", BathRobe = "Torso",
    FullRobe = "Torso", BodyCostume = "Torso",
    TorsoExtra = "Torso", TorsoExtraVest = "Torso",
    TorsoExtraVestBullet = "Torso", TorsoExtraPlus = "Torso",
    VestTexture = "Torso", Cuirass = "Torso",
    Dress = "Torso", LongDress = "Torso", FullSuit = "Torso",
    Boilersuit = "Torso",
    LeftArm = "Torso", RightArm = "Torso",
    ElbowLeft = "Torso", ElbowRight = "Torso",
    ForeArmLeft = "Torso", ForeArmRight = "Torso",
    ShoulderpadLeft = "Torso", ShoulderpadRight = "Torso",
    SportShoulderpad = "Torso", SportShoulderpadOnTop = "Torso",

    Gloves = "Hands", Hands = "Hands", LeftWrist = "Hands",
    RightWrist = "Hands", HandsLeft = "Hands", HandsRight = "Hands",
    LeftMiddleFinger = "Hands", RightMiddleFinger = "Hands",
    LeftRingFinger = "Hands", RightRingFinger = "Hands",

    Pants = "Legs", PantsExtra = "Legs", PantsSkinny = "Legs",
    ShortPants = "Legs", ShortsShort = "Legs", Skirt = "Legs",
    LongSkirt = "Legs", Legs1 = "Legs", Legs5 = "Legs", LowerBody = "Legs",
    Codpiece = "Legs", Tail = "Legs",
    ThighLeft = "Legs", ThighRight = "Legs",
    KneeLeft = "Legs", KneeRight = "Legs",
    CalfLeft = "Legs", CalfRight = "Legs",
    CalfLeftTexture = "Legs", CalfRightTexture = "Legs",
    GaiterLeft = "Legs", GaiterRight = "Legs", AnkleHolster = "Legs",

    Socks = "Feet", Shoes = "Feet",

    Back = "Back", SCBA = "Back", SCBAnotank = "Back", SCBANoTank = "Back",
    Satchel = "Back",

    Belt = "Legs", BeltExtra = "Legs",
    FannyPackFront = "Legs", FannyPackBack = "Legs",
    AmmoStrap = "Torso", Webbing = "Torso", ShoulderHolster = "Torso",
}

local function normalize(id)
    id = tostring(id)
    local cut = id:match("[%.:]([^%.:]+)$")
    if cut ~= nil then id = cut end
    id = id:gsub("[^%w]", ""):lower()
    return id
end

local NORMALIZED = {}
for id, group in pairs(LOCATION_GROUP) do
    NORMALIZED[normalize(id)] = group
end

local reportedLocations = {}
local Log = ComfyGrid.Core.Log
local function resolveGroup(rawLocation)
    local pretty = tostring(rawLocation)
    local group = LOCATION_GROUP[pretty] or NORMALIZED[normalize(pretty)]
    if reportedLocations[pretty] == nil then
        reportedLocations[pretty] = true
        Log.info("worn location '" .. pretty .. "' -> "
            .. (group or "DYNAMIC (unmapped)"))
    end
    return group, pretty
end

local itemsByGroup = {}
local dynamicKeys = {}

local function listFor(groupKey)
    local list = itemsByGroup[groupKey]
    if list == nil then
        list = {}
        itemsByGroup[groupKey] = list
    end
    return list
end

function Equipment.collect(playerObj, out)
    for _, list in pairs(itemsByGroup) do
        for i = #list, 1, -1 do list[i] = nil end
    end
    for i = #dynamicKeys, 1, -1 do dynamicKeys[i] = nil end

    if playerObj ~= nil then

        local ok, worn = pcall(playerObj.getWornItems, playerObj)
        if ok and worn ~= nil then
            local size = worn:size()
            if reportedLocations.__count == nil then
                reportedLocations.__count = true
                Log.info("worn pass: " .. tostring(size) .. " entries")
            end
            for i = 1, size do
                local wornEntry = worn:get(i - 1)

                local item = nil
                if wornEntry ~= nil then
                    if wornEntry.getItem ~= nil then
                        local okItem, it = pcall(wornEntry.getItem, wornEntry)
                        item = okItem and it or nil
                    elseif instanceof(wornEntry, "InventoryItem") then
                        item = wornEntry
                    end
                end
                if item ~= nil then

                    local rawLoc = nil
                    if wornEntry ~= nil and wornEntry.getLocation ~= nil then
                        local okLoc, loc = pcall(wornEntry.getLocation, wornEntry)
                        rawLoc = okLoc and loc or nil
                    end
                    if rawLoc == nil and item.getBodyLocation ~= nil then
                        local okLoc, loc = pcall(item.getBodyLocation, item)
                        rawLoc = okLoc and loc or nil
                    end
                    local groupKey, pretty = resolveGroup(rawLoc or "?")
                    if groupKey == nil then
                        groupKey = pretty
                        local list = itemsByGroup[groupKey]
                        if list == nil or #list == 0 then
                            dynamicKeys[#dynamicKeys + 1] = groupKey
                        end
                    end
                    table.insert(listFor(groupKey), 1, item)
                end
            end
        end

        local okP, primary = pcall(playerObj.getPrimaryHandItem, playerObj)
        if okP and primary ~= nil then
            listFor("Primary")[1] = primary
        end
        local okS, secondary = pcall(playerObj.getSecondaryHandItem, playerObj)
        if okS and secondary ~= nil then
            listFor("Secondary")[1] = secondary
        end
    end

    local n = 0
    local function emit(key, hand, dynamic)
        n = n + 1
        local entry = out[n]
        if entry == nil then
            entry = {}
            out[n] = entry
        end
        entry.key = key
        entry.hand = hand
        entry.items = listFor(key)
        entry.dynamic = dynamic
    end
    local GROUPS = Equipment.GROUPS
    for i = 1, #GROUPS do
        emit(GROUPS[i].key, GROUPS[i].hand, nil)
    end
    for i = 1, #dynamicKeys do
        emit(dynamicKeys[i], nil, true)
    end
    return n
end

function Equipment.findDisplacedWorn(playerObj, item)
    if playerObj == nil or item == nil then return nil end
    local target = nil
    if item.getBodyLocation ~= nil then
        local ok, loc = pcall(item.getBodyLocation, item)
        if ok and loc ~= nil and tostring(loc) ~= "" then
            target = tostring(loc)
        end
    end
    if target == nil and item.canBeEquipped ~= nil then
        local ok, loc = pcall(item.canBeEquipped, item)
        if ok and loc ~= nil and tostring(loc) ~= "" then
            target = tostring(loc)
        end
    end
    if target == nil then return nil end
    target = normalize(target)
    local okW, worn = pcall(playerObj.getWornItems, playerObj)
    if not okW or worn == nil then return nil end
    for i = 1, worn:size() do
        local entry = worn:get(i - 1)
        local wItem = nil
        if entry ~= nil and entry.getItem ~= nil then
            local okI, it = pcall(entry.getItem, entry)
            wItem = okI and it or nil
        end
        if wItem ~= nil and wItem ~= item and entry.getLocation ~= nil then
            local okL, loc = pcall(entry.getLocation, entry)
            if okL and loc ~= nil and normalize(loc) == target then
                return wItem
            end
        end
    end
    return nil
end

function Equipment.itemMatchesGroup(item, groupKey)
    if item == nil then return false end
    if groupKey == "Primary" or groupKey == "Secondary" then
        return true
    end
    local location = nil
    if item.getBodyLocation ~= nil then
        local ok, loc = pcall(item.getBodyLocation, item)
        if ok and loc ~= nil and tostring(loc) ~= "" then
            location = tostring(loc)
        end
    end
    if location == nil and item.canBeEquipped ~= nil then
        local ok, loc = pcall(item.canBeEquipped, item)
        if ok and loc ~= nil and tostring(loc) ~= "" then
            location = tostring(loc)
        end
    end
    if location == nil then return false end

    local group = LOCATION_GROUP[location] or NORMALIZED[normalize(location)]
    return (group or location) == groupKey
end
