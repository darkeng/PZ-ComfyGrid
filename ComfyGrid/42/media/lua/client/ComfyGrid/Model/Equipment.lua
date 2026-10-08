--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Text"
require "ComfyGrid/Core/GameMode"
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
    local unprefixed = id:match("[%.:]([^%.:]+)$")
    if unprefixed ~= nil then id = unprefixed end
    id = id:gsub("[^%w]", ""):lower()
    return id
end

local NORMALIZED = {}
for id, group in pairs(LOCATION_GROUP) do
    NORMALIZED[normalize(id)] = group
end

local reportedLocations = {}
local Log = ComfyGrid.Core.Log
local Text = ComfyGrid.Core.Text
local GameMode = ComfyGrid.Core.GameMode

local displayNames = {}

local groupOfLocation = {}

local function resolveGroup(rawLocation)
    local pretty = tostring(rawLocation)
    local group = groupOfLocation[pretty]
    if group == nil then
        group = LOCATION_GROUP[pretty] or NORMALIZED[normalize(pretty)] or false
        groupOfLocation[pretty] = group
    end
    if group == false then group = nil end
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
    local groupItems = itemsByGroup[groupKey]
    if groupItems == nil then
        groupItems = {}
        itemsByGroup[groupKey] = groupItems
    end
    return groupItems
end

function Equipment.displayNameFor(key)
    local name = displayNames[tostring(key)]
    if name == false then return nil end
    return name
end

local function emitEntry(entries, entryCount, key, hand, dynamic)
    entryCount = entryCount + 1
    local entry = entries[entryCount]
    if entry == nil then
        entry = {}
        entries[entryCount] = entry
    end
    entry.key = key
    entry.hand = hand
    entry.items = listFor(key)
    entry.dynamic = dynamic
    return entryCount
end

function Equipment.collect(playerObj, entries)
    for _, groupItems in pairs(itemsByGroup) do
        for i = #groupItems, 1, -1 do groupItems[i] = nil end
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
                        local okItem, wornItem = pcall(wornEntry.getItem, wornEntry)
                        item = okItem and wornItem or nil
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

                        local okHidden, hidden = pcall(item.isHidden, item)
                        if okHidden and hidden then
                            groupKey = nil
                        else
                            groupKey = pretty
                            if displayNames[groupKey] == nil then
                                local translatedName = nil
                                if rawLoc ~= nil and rawLoc.getTranslationName ~= nil then
                                    local okName, translationId = pcall(
                                        rawLoc.getTranslationName, rawLoc)
                                    if okName and translationId ~= nil then
                                        translatedName = Text.tr("UI_ClothingType_"
                                            .. tostring(translationId), nil)
                                    end
                                end
                                displayNames[groupKey] = translatedName or false
                            end
                            local groupItems = itemsByGroup[groupKey]
                            if groupItems == nil or #groupItems == 0 then
                                dynamicKeys[#dynamicKeys + 1] = groupKey
                            end
                        end
                    end
                    if groupKey ~= nil then
                        table.insert(listFor(groupKey), 1, item)
                    end
                end
            end
        end

        local okPrimary, primary = pcall(playerObj.getPrimaryHandItem, playerObj)
        if okPrimary and primary ~= nil then
            listFor("Primary")[1] = primary
        end
        local okSecondary, secondary = pcall(playerObj.getSecondaryHandItem, playerObj)
        if okSecondary and secondary ~= nil then
            listFor("Secondary")[1] = secondary
        end
    end

    local entryCount = 0
    local GROUPS = Equipment.GROUPS
    for i = 1, #GROUPS do
        entryCount = emitEntry(entries, entryCount, GROUPS[i].key, GROUPS[i].hand, nil)
    end
    for i = 1, #dynamicKeys do
        entryCount = emitEntry(entries, entryCount, dynamicKeys[i], nil, true)
    end
    return entryCount
end

local function targetLocationOf(item)
    if item.getBodyLocation ~= nil then
        local ok, loc = pcall(item.getBodyLocation, item)
        if ok and loc ~= nil and tostring(loc) ~= "" then
            return tostring(loc)
        end
    end
    if item.canBeEquipped ~= nil then
        local ok, loc = pcall(item.canBeEquipped, item)
        if ok and loc ~= nil and tostring(loc) ~= "" then
            return tostring(loc)
        end
    end
    return nil
end

function Equipment.findDisplacedWorn(playerObj, item)
    if playerObj == nil or item == nil then return nil end
    local target = targetLocationOf(item)
    if target == nil then return nil end
    target = normalize(target)
    local okWorn, worn = pcall(playerObj.getWornItems, playerObj)
    if not okWorn or worn == nil then return nil end
    for i = 1, worn:size() do
        local entry = worn:get(i - 1)
        local wornItem = nil
        if entry ~= nil and entry.getItem ~= nil then
            local okItem, entryItem = pcall(entry.getItem, entry)
            wornItem = okItem and entryItem or nil
        end
        if wornItem ~= nil and wornItem ~= item and entry.getLocation ~= nil then
            local okLocation, loc = pcall(entry.getLocation, entry)
            if okLocation and loc ~= nil and normalize(loc) == target then
                return wornItem
            end
        end
    end
    return nil
end

function Equipment.handAccepts(item)
    if item == nil then return false end
    if GameMode.isTutorial() then return false end
    if item.getScriptItem ~= nil then
        local okScript, script = pcall(item.getScriptItem, item)
        if okScript and script ~= nil and script.getReplaceWhenUnequip ~= nil then
            local okReplace, replace = pcall(script.getReplaceWhenUnequip, script)
            if okReplace and replace then return false end
        end
    end
    if item.IsWeapon ~= nil then
        local okWeapon, isWeapon = pcall(item.IsWeapon, item)
        if okWeapon and isWeapon then
            local okCondition, condition = pcall(item.getCondition, item)
            if okCondition and type(condition) == "number" then
                return condition > 0
            end
            return true
        end
    end
    if item.IsFood ~= nil then
        local okFood, isFood = pcall(item.IsFood, item)
        if okFood and isFood then return false end
    end
    if item.IsClothing ~= nil then
        local okClothing, isClothing = pcall(item.IsClothing, item)
        if okClothing and isClothing then return false end
    end
    return true
end

function Equipment.itemMatchesGroup(item, groupKey)
    if item == nil then return false end
    if groupKey == "Primary" or groupKey == "Secondary" then
        return Equipment.handAccepts(item)
    end
    local location = targetLocationOf(item)
    if location == nil then return false end

    local group = LOCATION_GROUP[location] or NORMALIZED[normalize(location)]
    return (group or location) == groupKey
end
