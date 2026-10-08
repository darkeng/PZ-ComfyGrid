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
local Categories = {}
ComfyGrid.Model.Categories = Categories

Categories.ORDER = {
    "weapons",
    "tools",
    "food",
    "medical",
    "hygiene",
    "kitchen",
    "materials",
    "containers",
    "literature",
    "clothing",
    "survival",
    "misc",
    "other",
}

local rankByBucket = {}
for i = 1, #Categories.ORDER do
    rankByBucket[Categories.ORDER[i]] = i
end

local DEFAULT_BUCKET = "other"
Categories.DEFAULT_BUCKET = DEFAULT_BUCKET

Categories.BUCKET = {

    Weapon           = "weapons",
    WeaponCrafted    = "weapons",
    WeaponImprovised = "weapons",
    BrokenWeapon     = "weapons",
    Explosives       = "weapons",
    WeaponPart       = "weapons",
    Ammo             = "weapons",

    Tool                     = "tools",
    ToolWeapon               = "tools",
    VehicleMaintenance       = "tools",
    VehicleMaintenanceWeapon = "tools",
    Paint                    = "tools",
    Electronics              = "tools",

    Food           = "food",
    Water          = "food",
    WaterContainer = "food",

    FirstAid       = "medical",
    FirstAidWeapon = "medical",

    Cooking       = "kitchen",
    CookingWeapon = "kitchen",

    Material           = "materials",
    MaterialWeapon     = "materials",
    Gardening          = "materials",
    GardeningWeapon    = "materials",
    AnimalPart         = "materials",
    AnimalPartWeapon   = "materials",

    Bag       = "containers",
    Container = "containers",

    Literature     = "literature",
    SkillBook      = "literature",
    RecipeResource = "literature",
    Cartography    = "literature",

    Clothing       = "clothing",
    Accessory      = "clothing",
    ProtectiveGear = "clothing",
    Appearance     = "clothing",

    Camping        = "survival",
    Fishing        = "survival",
    Trapping       = "survival",
    FireSource     = "survival",
    LightSource    = "survival",
    Communications = "survival",
    Security       = "survival",

    Household       = "misc",
    HouseholdWeapon = "misc",
    Junk            = "misc",
    JunkWeapon      = "misc",
    Memento         = "misc",
    Sports          = "misc",
    SportsWeapon    = "misc",
    Instrument      = "misc",
    InstrumentWeapon = "misc",
    Entertainment   = "misc",
    ["Teddy Bear"]  = "misc",

    AlarmClock  = "misc",
    Key         = "misc",
    ["Key Ring"] = "misc",
    Animal      = "materials",

}

Categories.BS_PREFIX = {
    { "ClothBag", "containers" },
    { "CookImp",  "kitchen"    },
    { "CookBev",  "food"       },
    { "CookIng",  "food"       },
    { "Media",    "misc"       },
    { "Wep",      "weapons"    },
    { "Tool",     "tools"      },
    { "Mech",     "tools"      },
    { "Elec",     "tools"      },
    { "Food",     "food"       },
    { "Cook",     "food"       },
    { "Med",      "medical"    },
    { "Drugs",    "medical"    },
    { "Clean",    "hygiene"    },
    { "Appear",   "clothing"   },
    { "Cloth",    "clothing"   },
    { "Cont",     "containers" },
    { "Lit",      "literature" },
    { "Sur",      "survival"   },
    { "Craft",    "materials"  },
    { "Build",    "materials"  },
    { "Fuel",     "materials"  },
    { "Collect",  "misc"       },
    { "Misc",     "misc"       },
}

local bsActive = nil
local function betterSortingActive()
    if bsActive ~= nil then return bsActive end
    bsActive = false
    if getActivatedMods ~= nil then
        local ok, mods = pcall(getActivatedMods)
        if ok and mods ~= nil and mods.size ~= nil then
            for i = 0, mods:size() - 1 do
                if tostring(mods:get(i)) == "BetterSortCC" then
                    bsActive = true
                    break
                end
            end
        end
    end
    return bsActive
end

local bucketByCategory = {}
function Categories.bucketForCategory(displayCategory)
    if displayCategory == nil then return nil end
    local cachedBucket = bucketByCategory[displayCategory]
    if cachedBucket ~= nil then
        if cachedBucket == false then return nil end
        return cachedBucket
    end
    local bucket = Categories.BUCKET[displayCategory]
    if bucket == nil and betterSortingActive() then
        local rules = Categories.BS_PREFIX
        for i = 1, #rules do
            local prefix = rules[i][1]
            if string.sub(displayCategory, 1, #prefix) == prefix then
                bucket = rules[i][2]
                break
            end
        end
    end
    bucketByCategory[displayCategory] = bucket or false
    return bucket
end

Categories.HYGIENE_TYPES = {
    ["Base.Soap2"]         = true,
    ["Base.BathTowel"]     = true,
    ["Base.BathTowelWet"]  = true,
    ["Base.DishCloth"]     = true,
    ["Base.DishClothWet"]  = true,
    ["Base.Sponge"]        = true,
    ["Base.ToiletBrush"]   = true,
    ["Base.Toothbrush"]    = true,
    ["Base.Toothpaste"]    = true,
    ["Base.Comb"]          = true,
    ["Base.Razor"]         = true,
    ["Base.StraightRazor"] = true,
    ["Base.Perfume"]       = true,
    ["Base.Cologne"]       = true,
    ["Base.ToiletPaper"]   = true,
    ["Base.PaperNapkins2"] = true,
    ["Base.Hairgel"]       = true,
    ["Base.Hairspray2"]    = true,
}

Categories.WEAPON_SUB = {
    "firearm",
    "ammo",
    "longblunt",
    "shortblunt",
    "axe",
    "blade",
    "spear",
    "other",
}
local rankBySub = {}
for i = 1, #Categories.WEAPON_SUB do
    rankBySub[Categories.WEAPON_SUB[i]] = i
end

local WEAPON_DC = {
    Weapon           = "other",
    WeaponCrafted    = "other",
    WeaponImprovised = "other",
    BrokenWeapon     = "other",
    Explosives       = "other",
    WeaponPart       = "ammo",
    Ammo             = "ammo",
}

Categories.MIN_WEAPON_DAMAGE = 0.3

local verdictByFullType = {}

local function isWeaponCategory(item, weaponCategory)
    if weaponCategory == nil then return false end
    local ok, matches = pcall(item.isOfWeaponCategory, item, weaponCategory)
    return ok and matches == true
end

local function weaponSubOf(item)
    local subCategory = nil
    if item.getSubCategory ~= nil then
        local okSub, probedSub = pcall(item.getSubCategory, item)
        if okSub and probedSub ~= nil then subCategory = tostring(probedSub) end
    end
    if subCategory == "Firearm" then return "firearm" end
    if WeaponCategory ~= nil and item.isOfWeaponCategory ~= nil then

        if isWeaponCategory(item, WeaponCategory.AXE) then return "axe" end
        if isWeaponCategory(item, WeaponCategory.SPEAR) then return "spear" end
        if isWeaponCategory(item, WeaponCategory.LONG_BLADE) then return "blade" end
        if isWeaponCategory(item, WeaponCategory.SMALL_BLADE) then return "blade" end
        if isWeaponCategory(item, WeaponCategory.BLUNT) then return "longblunt" end
        if isWeaponCategory(item, WeaponCategory.SMALL_BLUNT) then
            return "shortblunt"
        end
    end
    if subCategory == "Spear" then return "spear" end
    return "other"
end

local function combatVerdict(item, displayCategory)
    local forced = displayCategory ~= nil and WEAPON_DC[displayCategory] or nil
    if item == nil or not instanceof(item, "HandWeapon") then
        return forced ~= nil, forced or "other"
    end
    local weaponSub = weaponSubOf(item)
    if forced ~= nil then

        return true, weaponSub
    end
    local improvised = false
    if WeaponCategory ~= nil and item.isOfWeaponCategory ~= nil then
        local okImprovised, isImprovised = pcall(item.isOfWeaponCategory, item,
            WeaponCategory.IMPROVISED)
        improvised = okImprovised and isImprovised == true
    end
    if improvised then return false, weaponSub end
    local maxDamage = nil
    if item.getMaxDamage ~= nil then
        local okDamage, probedDamage = pcall(item.getMaxDamage, item)
        if okDamage and type(probedDamage) == "number" then
            maxDamage = probedDamage
        end
    end
    if maxDamage ~= nil and maxDamage < Categories.MIN_WEAPON_DAMAGE then
        return false, weaponSub
    end
    return true, weaponSub
end

function Categories.bucketOf(stack)
    if stack == nil then return DEFAULT_BUCKET end
    local itemType = stack.itemType
    if itemType ~= nil and Categories.HYGIENE_TYPES[itemType] then
        return "hygiene"
    end
    local displayCategory = stack.category
    if displayCategory == nil then return DEFAULT_BUCKET end
    return Categories.bucketForCategory(displayCategory) or DEFAULT_BUCKET
end

function Categories.classify(stack, inventory)
    if stack == nil then return DEFAULT_BUCKET, 0 end
    local itemType = stack.itemType
    if itemType ~= nil and Categories.HYGIENE_TYPES[itemType] then
        return "hygiene", 0
    end

    local item = nil
    if inventory ~= nil then
        local ItemStack = ComfyGrid.Model and ComfyGrid.Model.ItemStack
        if ItemStack ~= nil and ItemStack.frontItem ~= nil then
            local okFront, front = pcall(ItemStack.frontItem, stack, inventory)
            if okFront then item = front end
        end
    end

    local key = nil
    if item ~= nil and item.getFullType ~= nil then
        local okFullType, fullType = pcall(item.getFullType, item)
        if okFullType then key = fullType end
    end
    if key == nil then key = itemType end
    local cachedVerdict = key ~= nil and verdictByFullType[key] or nil
    if cachedVerdict ~= nil then
        return cachedVerdict.bucket, cachedVerdict.sub
    end

    local bucket, subIndex
    local isWeapon, weaponSub = combatVerdict(item, stack.category)
    if isWeapon then
        bucket = "weapons"
        subIndex = rankBySub[weaponSub] or rankBySub.other
    else
        bucket = Categories.bucketOf(stack)
        subIndex = 0
    end

    if key ~= nil and item ~= nil then
        verdictByFullType[key] = { bucket = bucket, sub = subIndex }
    end
    return bucket, subIndex
end

function Categories.rankPairOf(stack, inventory)
    local bucket, subIndex = Categories.classify(stack, inventory)
    return rankByBucket[bucket] or #Categories.ORDER, subIndex or 0
end
