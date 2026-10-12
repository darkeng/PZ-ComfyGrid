--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.5
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local LookalikeTypes = {}
ComfyGrid.Model.LookalikeTypes = LookalikeTypes

local CANONICAL_BY_TYPE = {

    ["Base.Animal_BowtieGreen"] = "Base.Animal_BowtieGold",
    ["Base.Animal_BowtieRed"] = "Base.Animal_BowtieGold",

    ["Base.Bag_AmmoBox_308"] = "Base.Bag_AmmoBox",
    ["Base.Bag_AmmoBox_38"] = "Base.Bag_AmmoBox",
    ["Base.Bag_AmmoBox_44"] = "Base.Bag_AmmoBox",
    ["Base.Bag_AmmoBox_45"] = "Base.Bag_AmmoBox",
    ["Base.Bag_AmmoBox_9mm"] = "Base.Bag_AmmoBox",
    ["Base.Bag_AmmoBox_Hunting"] = "Base.Bag_AmmoBox",
    ["Base.Bag_AmmoBox_Mixed"] = "Base.Bag_AmmoBox",
    ["Base.Bag_AmmoBox_ShotgunShells"] = "Base.Bag_AmmoBox",

    ["Base.Tote"] = "Base.Bag_Dancer",
    ["Base.Tote_Bags"] = "Base.Bag_Dancer",
    ["Base.Tote_Clothing"] = "Base.Bag_Dancer",

    ["Base.Bag_DeadRats"] = "Base.Bag_DeadMice",
    ["Base.Bag_DeadRoaches"] = "Base.Bag_DeadMice",
    ["Base.Bag_TreasureBag"] = "Base.Bag_DeadMice",
    ["Base.EmptySandbag"] = "Base.Bag_DeadMice",

    ["Base.Bag_FoodSnacks"] = "Base.Bag_FoodCanned",
    ["Base.Bag_InmateEscapedBag"] = "Base.Bag_FoodCanned",
    ["Base.Bag_ToolBag"] = "Base.Bag_FoodCanned",
    ["Base.Bag_WeaponBag"] = "Base.Bag_FoodCanned",
    ["Base.Bag_WorkerBag"] = "Base.Bag_FoodCanned",

    ["Base.Toolbox_Mechanic"] = "Base.Bag_JanitorToolbox",

    ["Base.Bag_LaundryHospital"] = "Base.Bag_Laundry",
    ["Base.Bag_LaundryLinen"] = "Base.Bag_Laundry",

    ["Base.Bag_ProtectiveCase_Survivalist"] = "Base.Bag_ProtectiveCase",
    ["Base.Bag_ProtectiveCase_Tools"] = "Base.Bag_ProtectiveCase",

    ["Base.Bag_ProtectiveCaseBulky_Audio"] = "Base.Bag_ProtectiveCaseBulky",
    ["Base.Bag_ProtectiveCaseBulky_HAMRadio1"] = "Base.Bag_ProtectiveCaseBulky",
    ["Base.Bag_ProtectiveCaseBulky_SCBA"] = "Base.Bag_ProtectiveCaseBulky",

    ["Base.Bag_ProtectiveCaseBulkyAmmo_308"] = "Base.Bag_ProtectiveCaseBulkyAmmo",
    ["Base.Bag_ProtectiveCaseBulkyAmmo_38"] = "Base.Bag_ProtectiveCaseBulkyAmmo",
    ["Base.Bag_ProtectiveCaseBulkyAmmo_44"] = "Base.Bag_ProtectiveCaseBulkyAmmo",
    ["Base.Bag_ProtectiveCaseBulkyAmmo_45"] = "Base.Bag_ProtectiveCaseBulkyAmmo",
    ["Base.Bag_ProtectiveCaseBulkyAmmo_556"] = "Base.Bag_ProtectiveCaseBulkyAmmo",
    ["Base.Bag_ProtectiveCaseBulkyAmmo_9mm"] = "Base.Bag_ProtectiveCaseBulkyAmmo",
    ["Base.Bag_ProtectiveCaseBulkyAmmo_Hunting"] = "Base.Bag_ProtectiveCaseBulkyAmmo",
    ["Base.Bag_ProtectiveCaseBulkyAmmo_ShotgunShells"] = "Base.Bag_ProtectiveCaseBulkyAmmo",

    ["Base.Bag_ProtectiveCaseBulkyMilitary_HAMRadio2"] = "Base.Bag_ProtectiveCaseBulkyMilitary",
    ["Base.Bag_ProtectiveCaseBulky_Survivalist"] = "Base.Bag_ProtectiveCaseBulkyMilitary",

    ["Base.Bag_ProtectiveCaseMilitary_Tools"] = "Base.Bag_ProtectiveCaseMilitary_Medical",

    ["Base.Bag_ProtectiveCaseSmall_Electronics"] = "Base.Bag_ProtectiveCaseSmall",
    ["Base.Bag_ProtectiveCaseSmall_FirstAid"] = "Base.Bag_ProtectiveCaseSmall",
    ["Base.Bag_ProtectiveCaseSmall_Survivalist"] = "Base.Bag_ProtectiveCaseSmall",
    ["Base.Bag_ProtectiveCaseSmall_WalkieTalkie"] = "Base.Bag_ProtectiveCaseSmall",
    ["Base.Bag_ProtectiveCaseSmall_WalkieTalkiePolice"] = "Base.Bag_ProtectiveCaseSmall",

    ["Base.Bag_ProtectiveCaseSmallMilitary_WalkieTalkie"] = "Base.Bag_ProtectiveCaseSmallMilitary_FirstAid",

    ["Base.Bag_ProtectiveCaseSmall_KeyCutting"] = "Base.Bag_ProtectiveCaseSmall_Armorer",
    ["Base.Bag_ProtectiveCaseSmall_Pistol1"] = "Base.Bag_ProtectiveCaseSmall_Armorer",
    ["Base.Bag_ProtectiveCaseSmall_Pistol2"] = "Base.Bag_ProtectiveCaseSmall_Armorer",
    ["Base.Bag_ProtectiveCaseSmall_Pistol3"] = "Base.Bag_ProtectiveCaseSmall_Armorer",
    ["Base.Bag_ProtectiveCaseSmall_Revolver1"] = "Base.Bag_ProtectiveCaseSmall_Armorer",
    ["Base.Bag_ProtectiveCaseSmall_Revolver2"] = "Base.Bag_ProtectiveCaseSmall_Armorer",
    ["Base.Bag_ProtectiveCaseSmall_Revolver3"] = "Base.Bag_ProtectiveCaseSmall_Armorer",

    ["Base.Bag_RifleCase_Police2"] = "Base.Bag_RifleCase_Police",
    ["Base.Bag_RifleCase_Police3"] = "Base.Bag_RifleCase_Police",
    ["Base.Bag_ShotgunCase_Police"] = "Base.Bag_RifleCase_Police",

    ["Base.Garbagebag"] = "Base.Bag_TrashBag",

    ["Base.BakingTray_Muffin_Recipe"] = "Base.BakingTray_Muffin",

    ["Base.BusinessCard_Nolans"] = "Base.BusinessCard",
    ["Base.BusinessCard_Personal"] = "Base.BusinessCard",

    ["Base.CigarBox_Gaming"] = "Base.CigarBox",
    ["Base.CigarBox_Keepsakes"] = "Base.CigarBox",
    ["Base.CigarBox_Kids"] = "Base.CigarBox",

    ["Base.ComicBook_Retail"] = "Base.ComicBook",

    ["Base.Cooler_Meat"] = "Base.Cooler_Beer",
    ["Base.Cooler_Soda"] = "Base.Cooler_Beer",

    ["Base.CreditCard_Stolen"] = "Base.CreditCard",

    ["Base.DoodleKids"] = "Base.Doodle",

    ["Base.JarCrafted"] = "Base.EmptyJar",

    ["Base.FirstAidKit_New"] = "Base.FirstAidKit",
    ["Base.FirstAidKit_NewPro"] = "Base.FirstAidKit",

    ["Base.FirstAidKit_Camping_New"] = "Base.FirstAidKit_Camping",

    ["Base.Flier_Nolans"] = "Base.Flier",

    ["Base.GroceryBag2"] = "Base.GroceryBag1",
    ["Base.GroceryBag3"] = "Base.GroceryBag1",
    ["Base.GroceryBag4"] = "Base.GroceryBag1",
    ["Base.GroceryBag5"] = "Base.GroceryBag1",
    ["Base.GroceryBagGourmet"] = "Base.GroceryBag1",
    ["Base.Plasticbag"] = "Base.GroceryBag1",
    ["Base.Plasticbag_Bags"] = "Base.GroceryBag1",
    ["Base.Plasticbag_Clothing"] = "Base.GroceryBag1",

    ["Base.Hat_HockeyHelmet_TINT"] = "Base.Hat_HockeyHelmet",

    ["Base.HollowBook_Handgun"] = "Base.HollowBook",
    ["Base.HollowBook_Kids"] = "Base.HollowBook",
    ["Base.HollowBook_Prison"] = "Base.HollowBook",
    ["Base.HollowBook_Valuables"] = "Base.HollowBook",
    ["Base.HollowBook_Whiskey"] = "Base.HollowBook",

    ["Base.IDcard_Female"] = "Base.IDcard",
    ["Base.IDcard_Male"] = "Base.IDcard",
    ["Base.IDcard_Stolen"] = "Base.IDcard",

    ["Base.Magazine_New"] = "Base.Magazine",

    ["Base.Magazine_Art_New"] = "Base.Magazine_Art",

    ["Base.Magazine_Business_New"] = "Base.Magazine_Business",

    ["Base.Magazine_Car_New"] = "Base.Magazine_Car",

    ["Base.Magazine_Childs_New"] = "Base.Magazine_Childs",

    ["Base.Magazine_Cinema_New"] = "Base.Magazine_Cinema",

    ["Base.Magazine_Crime_New"] = "Base.Magazine_Crime",

    ["Base.Magazine_Fashion_New"] = "Base.Magazine_Fashion",

    ["Base.Magazine_Firearm_New"] = "Base.Magazine_Firearm",

    ["Base.Magazine_Gaming_New"] = "Base.Magazine_Gaming",

    ["Base.Magazine_Golf_New"] = "Base.Magazine_Golf",

    ["Base.Magazine_Health_New"] = "Base.Magazine_Health",

    ["Base.Magazine_Hobby_New"] = "Base.Magazine_Hobby",

    ["Base.Magazine_Horror_New"] = "Base.Magazine_Horror",

    ["Base.Magazine_Humor_New"] = "Base.Magazine_Humor",

    ["Base.Magazine_Military_New"] = "Base.Magazine_Military",

    ["Base.Magazine_Music_New"] = "Base.Magazine_Music",

    ["Base.Magazine_Outdoors_New"] = "Base.Magazine_Outdoors",

    ["Base.Magazine_Police_New"] = "Base.Magazine_Police",

    ["Base.Magazine_Popular_New"] = "Base.Magazine_Popular",

    ["Base.Magazine_Rich_New"] = "Base.Magazine_Rich",

    ["Base.Magazine_Science_New"] = "Base.Magazine_Science",

    ["Base.Magazine_Sports_New"] = "Base.Magazine_Sports",

    ["Base.Magazine_Tech_New"] = "Base.Magazine_Tech",

    ["Base.Magazine_Teens_New"] = "Base.Magazine_Teens",

    ["Base.Necklace_DogTag_Female"] = "Base.Necklace_DogTag",
    ["Base.Necklace_DogTag_Male"] = "Base.Necklace_DogTag",

    ["Base.Newspaper_Herald_New"] = "Base.Newspaper_Dispatch_New",
    ["Base.Newspaper_Knews_New"] = "Base.Newspaper_Dispatch_New",
    ["Base.Newspaper_Times_New"] = "Base.Newspaper_Dispatch_New",

    ["Base.PhotoAlbum_Old"] = "Base.PhotoAlbum",

    ["Base.Photo_Secret"] = "Base.Photo_Racy",

    ["Base.PieWholeRawSweet"] = "Base.PieWholeRaw",

    ["Base.PistolCase2"] = "Base.PistolCase1",
    ["Base.PistolCase3"] = "Base.PistolCase1",
    ["Base.RevolverCase1"] = "Base.PistolCase1",
    ["Base.RevolverCase2"] = "Base.PistolCase1",
    ["Base.RevolverCase3"] = "Base.PistolCase1",

    ["Base.Pop3Empty"] = "Base.Pop2Empty",
    ["Base.PopEmpty"] = "Base.Pop2Empty",

    ["Base.Rabbit_Head_Swamp"] = "Base.Rabbit_Head_CottonTail",

    ["Base.Rabbit_Kitten_Head_Swamp"] = "Base.Rabbit_Kitten_Head_CottonTail",

    ["Base.Raccoon_Sow_Head"] = "Base.Raccoon_Boar_Head",

    ["Base.ScytheForged"] = "Base.Scythe",

    ["Base.SeedBag_Farming"] = "Base.SeedBag",

    ["Base.Shirt_Crafted_DenimLight"] = "Base.Shirt_Crafted_Denim",

    ["Base.Shirt_FormalWhite"] = "Base.Shirt_FormalTINT",

    ["Base.Shirt_FormalWhite_ShortSleeveTINT"] = "Base.Shirt_FormalWhite_ShortSleeve",

    ["Base.Socks_Ankle_White"] = "Base.Socks_Ankle",

    ["Base.Socks_Long_White"] = "Base.Socks_Long",

    ["Base.Suit_Jacket_White"] = "Base.Suit_JacketTINT",

    ["Base.Toolbox_Farming"] = "Base.Toolbox",
    ["Base.Toolbox_Fishing"] = "Base.Toolbox",
    ["Base.Toolbox_Gardening"] = "Base.Toolbox",

    ["Base.Trousers_SuitWhite_White"] = "Base.Trousers_SuitWhite",

    ["Base.Tshirt_HipHop"] = "Base.Tshirt_BluesCountry",
    ["Base.Tshirt_Indie"] = "Base.Tshirt_BluesCountry",
    ["Base.Tshirt_Metal"] = "Base.Tshirt_BluesCountry",
    ["Base.Tshirt_Punk"] = "Base.Tshirt_BluesCountry",
    ["Base.Tshirt_Rock"] = "Base.Tshirt_BluesCountry",
    ["Base.Tshirt_Rock2"] = "Base.Tshirt_BluesCountry",

    ["Base.Tshirt_DefaultTEXTURE"] = "Base.Tshirt_DefaultDECAL",

    ["Base.Tshirt_DefaultTEXTURE_TINT"] = "Base.Tshirt_DefaultDECAL_TINT",
    ["Base.Tshirt_WhiteTINT"] = "Base.Tshirt_DefaultDECAL_TINT",

    ["Base.Tshirt_WhiteLongSleeveTINT"] = "Base.Tshirt_WhiteLongSleeve",

    ["Base.Vest_DefaultTEXTURE_TINT"] = "Base.Vest_DefaultTEXTURE",
}

function LookalikeTypes.canonicalOf(fullType)
    return CANONICAL_BY_TYPE[fullType] or fullType
end

return LookalikeTypes
