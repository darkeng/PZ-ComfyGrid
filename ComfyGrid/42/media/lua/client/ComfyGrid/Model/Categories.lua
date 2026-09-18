--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.8.3
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

local rank = {}
for i = 1, #Categories.ORDER do
    rank[Categories.ORDER[i]] = i
end
Categories.RANK = rank

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

local catBucket = {}
function Categories.bucketForCategory(cat)
    if cat == nil then return nil end
    local memo = catBucket[cat]
    if memo ~= nil then
        if memo == false then return nil end
        return memo
    end
    local bucket = Categories.BUCKET[cat]
    if bucket == nil and betterSortingActive() then
        local rules = Categories.BS_PREFIX
        for i = 1, #rules do
            local prefix = rules[i][1]
            if string.sub(cat, 1, #prefix) == prefix then
                bucket = rules[i][2]
                break
            end
        end
    end
    catBucket[cat] = bucket or false
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
local subRank = {}
for i = 1, #Categories.WEAPON_SUB do
    subRank[Categories.WEAPON_SUB[i]] = i
end
Categories.SUB_RANK = subRank

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

local classMemo = {}

local function weaponSubOf(item)
    local sub = nil
    if item.getSubCategory ~= nil then
        local okS, s = pcall(item.getSubCategory, item)
        if okS and s ~= nil then sub = tostring(s) end
    end
    if sub == "Firearm" then return "firearm" end
    if WeaponCategory ~= nil and item.isOfWeaponCategory ~= nil then
        local function isCat(c)
            if c == nil then return false end
            local ok, v = pcall(item.isOfWeaponCategory, item, c)
            return ok and v == true
        end

        if isCat(WeaponCategory.AXE) then return "axe" end
        if isCat(WeaponCategory.SPEAR) then return "spear" end
        if isCat(WeaponCategory.LONG_BLADE) then return "blade" end
        if isCat(WeaponCategory.SMALL_BLADE) then return "blade" end
        if isCat(WeaponCategory.BLUNT) then return "longblunt" end
        if isCat(WeaponCategory.SMALL_BLUNT) then return "shortblunt" end
    end
    if sub == "Spear" then return "spear" end
    return "other"
end

local function combatVerdict(item, displayCategory)
    local forced = displayCategory ~= nil and WEAPON_DC[displayCategory] or nil
    if item == nil or not instanceof(item, "HandWeapon") then
        return forced ~= nil, forced or "other"
    end
    local sub = weaponSubOf(item)
    if forced ~= nil then

        return true, sub
    end
    local improvised = false
    if WeaponCategory ~= nil and item.isOfWeaponCategory ~= nil then
        local okI, v = pcall(item.isOfWeaponCategory, item,
            WeaponCategory.IMPROVISED)
        improvised = okI and v == true
    end
    if improvised then return false, sub end
    local dmg = nil
    if item.getMaxDamage ~= nil then
        local okD, d = pcall(item.getMaxDamage, item)
        if okD and type(d) == "number" then dmg = d end
    end
    if dmg ~= nil and dmg < Categories.MIN_WEAPON_DAMAGE then
        return false, sub
    end
    return true, sub
end

function Categories.bucketOf(stack)
    if stack == nil then return DEFAULT_BUCKET end
    local t = stack.itemType
    if t ~= nil and Categories.HYGIENE_TYPES[t] then
        return "hygiene"
    end
    local c = stack.category
    if c == nil then return DEFAULT_BUCKET end
    return Categories.bucketForCategory(c) or DEFAULT_BUCKET
end

function Categories.classify(stack, inventory)
    if stack == nil then return DEFAULT_BUCKET, 0 end
    local t = stack.itemType
    if t ~= nil and Categories.HYGIENE_TYPES[t] then
        return "hygiene", 0
    end

    local item = nil
    if inventory ~= nil then
        local ItemStack = ComfyGrid.Model and ComfyGrid.Model.ItemStack
        if ItemStack ~= nil and ItemStack.frontItem ~= nil then
            local okF, f = pcall(ItemStack.frontItem, stack, inventory)
            if okF then item = f end
        end
    end

    local key = nil
    if item ~= nil and item.getFullType ~= nil then
        local okT, ft = pcall(item.getFullType, item)
        if okT then key = ft end
    end
    if key == nil then key = t end
    local memo = key ~= nil and classMemo[key] or nil
    if memo ~= nil then return memo.bucket, memo.sub end

    local bucket, sub
    local isWeapon, weaponSub = combatVerdict(item, stack.category)
    if isWeapon then
        bucket = "weapons"
        sub = subRank[weaponSub] or subRank.other
    else
        bucket = Categories.bucketOf(stack)
        sub = 0
    end

    if key ~= nil and item ~= nil then
        classMemo[key] = { bucket = bucket, sub = sub }
    end
    return bucket, sub
end

function Categories.rankOf(stack)
    return rank[Categories.bucketOf(stack)] or #Categories.ORDER
end

function Categories.rankPairOf(stack, inventory)
    local bucket, sub = Categories.classify(stack, inventory)
    return rank[bucket] or #Categories.ORDER, sub or 0
end
