--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.11
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/TextureCache"
require "ComfyGrid/Settings"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/SlotRenderer"
require "ComfyGrid/UI/Icons"
require "ComfyGrid/UI/Blit"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local StackRenderer = {}
ComfyGrid.UI.StackRenderer = StackRenderer

local Log = ComfyGrid.Core.Log
local Style = ComfyGrid.UI.Style
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local Icons = ComfyGrid.UI.Icons

local Blit = ComfyGrid.UI.Blit
local TextureCache = ComfyGrid.Core.TextureCache
local floor = math.floor

local showStatusBar = ComfyGrid.Settings.get("STATUS_BAR")
ComfyGrid.Settings.onChanged("STATUS_BAR", function(newValue)
    showStatusBar = newValue
end)

local CORNER_MARK_PX = 11

local UNWANTED_ALPHA = 0.40

local UNWANTED_MARK_FRAC = 0.66
local UNWANTED_MARK_ALPHA = 0.22

local countStrings = {}

local VOLUME_OF_LVL = { [1] = 1, [3] = 2, [5] = 3, [7] = 4, [9] = 5 }

local ammoTextSets = {}

local BAR_COLORS = {}
do
    local colors = Style.COLORS
    local low, mid, high = colors.BAR_LOW, colors.BAR_MID, colors.BAR_HIGH
    for i = 0, 100 do
        local position = i / 100
        local fromColor, toColor, mix
        if position <= 0.5 then
            fromColor, toColor, mix = low, mid, position * 2
        else
            fromColor, toColor, mix = mid, high, (position - 0.5) * 2
        end
        BAR_COLORS[i] = {
            r = fromColor.r + (toColor.r - fromColor.r) * mix,
            g = fromColor.g + (toColor.g - fromColor.g) * mix,
            b = fromColor.b + (toColor.b - fromColor.b) * mix,
        }
    end
end

local WEIGHT_MIN_ALPHA = 0.08

local WEIGHT_RED_AT = 40.0
local WEIGHT_CARRY_MAX = 7.0
local WEIGHT_KNEE_FRAC = 0.78
local WEIGHT_LOG_K = 0.6
local WEIGHT_LOG_DEN = math.log(1 + WEIGHT_CARRY_MAX * WEIGHT_LOG_K)

local WEIGHT_COLORS = {}
do
    local colors = Style.COLORS
    local low, mid = colors.WEIGHT_LOW, colors.WEIGHT_MID
    local deep, high = colors.WEIGHT_DEEP, colors.WEIGHT_HIGH
    local dark = colors.SURFACE.card
    for i = 0, 100 do
        local position = i / 100
        local fromColor, toColor, mix
        if position <= 0.5 then
            fromColor, toColor, mix = low, mid, position * 2
        elseif position <= WEIGHT_KNEE_FRAC then
            fromColor, toColor, mix = mid, deep,
                (position - 0.5) / (WEIGHT_KNEE_FRAC - 0.5)
        else
            fromColor, toColor, mix = deep, high,
                (position - WEIGHT_KNEE_FRAC) / (1 - WEIGHT_KNEE_FRAC)
        end
        local rampRed = fromColor.r + (toColor.r - fromColor.r) * mix
        local rampGreen = fromColor.g + (toColor.g - fromColor.g) * mix
        local rampBlue = fromColor.b + (toColor.b - fromColor.b) * mix

        local presenceRamp = position * 1.6
        if presenceRamp > 1 then presenceRamp = 1 end
        local presence = WEIGHT_MIN_ALPHA + (1 - WEIGHT_MIN_ALPHA) * presenceRamp
        local outlinePresence = 0.65 * presence
        WEIGHT_COLORS[i] = {
            r = dark.r + (rampRed - dark.r) * presence,
            g = dark.g + (rampGreen - dark.g) * presence,
            b = dark.b + (rampBlue - dark.b) * presence,
            lr = dark.r + (1 - dark.r) * outlinePresence,
            lg = dark.g + (1 - dark.g) * outlinePresence,
            lb = dark.b + (1 - dark.b) * outlinePresence,
        }
    end
end

local weightTexture = TextureCache.lazy("media/textures/comfy_weight.png")

local weightLineTexture = TextureCache.lazy("media/textures/comfy_weight_line.png")

local brokenTexture = TextureCache.lazy("media/textures/comfy_broken.png")
local brokenLineTexture = TextureCache.lazy("media/textures/comfy_broken_line.png")

local BROKEN_SPAN = 0.86

local BROKEN_BADGE_PX = 12

local BROKEN_BADGE_MAX_FRAC = 0.30

local textWidths = {}

local function measuredWidth(text)
    local byFont = textWidths[Style.FONT_H]
    if byFont == nil then
        byFont = {}
        textWidths[Style.FONT_H] = byFont
    end
    local textWidth = byFont[text]
    if textWidth == nil then
        textWidth = getTextManager():MeasureStringX(Style.FONT, text)
        byFont[text] = textWidth
    end
    return textWidth
end
StackRenderer.measuredWidth = measuredWidth

local MAX_MEMO_ENTRIES = 512
local MEMBER_RESCAN_MS = 700

local function newMemoEntry(map, entryCount, stack)
    if entryCount >= MAX_MEMO_ENTRIES then
        map, entryCount = {}, 0
    end
    local entry = {}
    map[stack] = entry
    return map, entryCount + 1, entry
end

local stackWeights = {}
local stackWeightEntries = 0

local stackBroken = {}
local stackBrokenEntries = 0

local function stackHasBroken(stack, inventory)

    if not inventory or stack == nil or stack.itemIDs == nil then
        return false
    end
    local now = getTimestampMs()
    local entry = stackBroken[stack]
    if entry ~= nil and entry.count == stack.count
            and (now - entry.at) < MEMBER_RESCAN_MS then
        return entry.broken
    end
    local broken = false
    for id in pairs(stack.itemIDs) do
        local member = inventory:getItemWithID(id)
        if member ~= nil and member.isBroken ~= nil and member:isBroken() then
            broken = true
            break
        end
    end
    if entry == nil then
        stackBroken, stackBrokenEntries, entry =
            newMemoEntry(stackBroken, stackBrokenEntries, stack)
    end
    entry.count, entry.at, entry.broken = stack.count, now, broken
    return broken
end

local HOT_HEAT = 1.3
local COLD_HEAT = 0.6
local COOKING_HEAT = 1.6

local function memberTemperature(item, typeInfo)
    if not typeInfo.isFood then
        local itemHeat = item:getItemHeat()
        return false, itemHeat > HOT_HEAT and 1 or (itemHeat < COLD_HEAT and -1 or 0), false
    end
    local heat = item:getHeat()
    local frozen = item:isFrozen()
    local side = heat > HOT_HEAT and 1 or (heat < COLD_HEAT and -1 or 0)
    local burning = heat > COOKING_HEAT and not frozen and typeInfo.isCookable
        and item:getCookingTime() > item:getMinutesToCook()
    return frozen, side, burning == true
end

local stackTemperature = {}
local stackTemperatureEntries = 0

local function stackTemperatureState(stack, typeInfo, inventory)
    local now = getTimestampMs()
    local entry = stackTemperature[stack]
    if entry ~= nil and entry.count == stack.count
            and (now - entry.at) < MEMBER_RESCAN_MS then
        return entry.frozen, entry.side, entry.burning
    end
    local seen, frozenCount, hotCount, coldCount, burning = 0, 0, 0, 0, false
    for id in pairs(stack.itemIDs) do
        local member = inventory:getItemWithID(id)
        if member ~= nil then
            seen = seen + 1
            local memberFrozen, memberSide, memberBurning = memberTemperature(member, typeInfo)
            if memberFrozen then frozenCount = frozenCount + 1 end
            if memberSide > 0 then
                hotCount = hotCount + 1
            elseif memberSide < 0 then
                coldCount = coldCount + 1
            end
            if memberBurning then burning = true end
        end
    end

    local frozen, side = 0, 0
    if frozenCount > 0 then frozen = (frozenCount == seen) and 2 or 1 end
    if seen > 0 then
        if hotCount == seen then
            side = 1
        elseif coldCount == seen then
            side = -1
        end
    end
    if entry == nil then
        stackTemperature, stackTemperatureEntries, entry =
            newMemoEntry(stackTemperature, stackTemperatureEntries, stack)
    end
    entry.count, entry.at = stack.count, now
    entry.frozen, entry.side, entry.burning = frozen, side, burning
    return frozen, side, burning
end

local function temperatureStateOf(stack, item, typeInfo, inventory)
    if stack.count == nil or stack.count <= 1 or not inventory
            or stack.itemIDs == nil then
        local frozen, side, burning = memberTemperature(item, typeInfo)
        return frozen and 2 or 0, side, burning
    end
    return stackTemperatureState(stack, typeInfo, inventory)
end

local function totalStackWeight(stack, inventory)
    local entry = stackWeights[stack]
    if entry ~= nil and entry.count == stack.count then
        return entry.total
    end

    local ItemStack = ComfyGrid.Model and ComfyGrid.Model.ItemStack
    local total = 0
    if ItemStack ~= nil and ItemStack.weightOf ~= nil then
        total = ItemStack.weightOf(stack, inventory)
    end
    if entry == nil then
        stackWeights, stackWeightEntries, entry =
            newMemoEntry(stackWeights, stackWeightEntries, stack)
    end
    entry.count = stack.count
    entry.total = total
    return total
end

function StackRenderer.weightColor(weight)
    if weight < 0 then weight = 0 end
    local frac
    if weight <= WEIGHT_CARRY_MAX then
        frac = WEIGHT_KNEE_FRAC
            * math.log(1 + weight * WEIGHT_LOG_K) / WEIGHT_LOG_DEN
    else
        frac = WEIGHT_KNEE_FRAC + (1 - WEIGHT_KNEE_FRAC)
            * (weight - WEIGHT_CARRY_MAX) / (WEIGHT_RED_AT - WEIGHT_CARRY_MAX)
        if frac > 1 then frac = 1 end
    end
    return WEIGHT_COLORS[floor(frac * 100 + 0.5)]
end

function StackRenderer.weightTexture()
    return weightTexture()
end

function StackRenderer.drawBrokenMark(view, x, y, size)
    local tex = brokenTexture()
    if tex == nil then return end
    local markSize = floor(size * BROKEN_SPAN + 0.5)
    if markSize < 1 then return end
    local inset = floor((size - markSize) * 0.5)
    StackRenderer.blitBrokenMark(view, x + inset, y + inset, markSize)
end

function StackRenderer.blitBrokenMark(view, x, y, markSize)
    local tex = brokenTexture()
    if tex == nil or markSize < 1 then return end
    local colors = Style.COLORS
    local fill = colors.BROKEN
    local line = colors.BROKEN_LINE
    local outline = brokenLineTexture()
    if outline ~= nil then
        Blit.drawTextureScaled(view, outline, x, y, markSize, markSize,
            line.a or 1, line.r, line.g, line.b)
    end
    Blit.drawTextureScaled(view, tex, x, y, markSize, markSize, fill.a or 1,
        fill.r, fill.g, fill.b)
end

local typeData = {}

local function typeDataFor(item, fullType)
    local typeInfo = typeData[fullType]
    if typeInfo then return typeInfo end
    typeInfo = {
        isFood = (item.IsFood and item:IsFood()) or false,
        isDrainable = (item.IsDrainable and item:IsDrainable()) or false,
        isLiterature = (item.IsLiterature and item:IsLiterature()) or false,
        isMap = instanceof(item, "MapItem") or false,
        hasMedia = (item.getMediaData and item:getMediaData() ~= nil) or false,
    }
    typeInfo.readable = typeInfo.isLiterature or typeInfo.isMap or typeInfo.hasMedia

    typeInfo.isCookable = typeInfo.isFood
        and (item.isIsCookable ~= nil and item:isIsCookable()) or false

    typeInfo.heatsAsItem = not typeInfo.isFood
        and (item.isCookable ~= nil and item:isCookable())
        and (item.getFluidContainer ~= nil and item:getFluidContainer() ~= nil)
        or false
    if typeInfo.isDrainable and item.getMaxUses then
        typeInfo.maxUses = item:getMaxUses()
    end

    if typeInfo.isLiterature and item.getLvlSkillTrained and item.getSkillTrained then
        local trainedLevel = item:getLvlSkillTrained()
        local volume = type(trainedLevel) == "number" and VOLUME_OF_LVL[trainedLevel] or nil
        if volume ~= nil then
            local trained = item:getSkillTrained()
            if trained ~= nil then
                typeInfo.bookVolume = volume
                typeInfo.bookLvl = trainedLevel
                typeInfo.bookSkill = tostring(trained)
            end
        end
    end

    if item.getMaxAmmo then
        local maxAmmo = item:getMaxAmmo()
        if type(maxAmmo) == "number" and maxAmmo > 0 then
            typeInfo.maxAmmo = maxAmmo
        end
    end
    typeData[fullType] = typeInfo
    return typeInfo
end

local textureIds = {}
local spriteRenderer = nil

local function applyNearest(tex)
    local id = textureIds[tex]
    if not id then
        id = tex:getID()
        textureIds[tex] = id
    end
    if not spriteRenderer then

        spriteRenderer = SpriteRenderer.instance
    end
    spriteRenderer:glBind(id)
    spriteRenderer:glTexParameteri(3553, 10240, 9728)
end

local nearestUnsupported = false

local function disableNearest()
    nearestUnsupported = true
    Log.warn("nearest-neighbor icon filtering unavailable; falling back to linear")
end

local nearestTap = nil

function StackRenderer.applyNearestTo(tex)
    if nearestUnsupported or tex == nil then return end
    if not pcall(applyNearest, tex) then disableNearest() end
end

function StackRenderer.setNearestTap(tap)
    nearestTap = tap
end

local function statusBarFraction(item, typeInfo, playerObj)
    if typeInfo.isDrainable then
        local maxUses = typeInfo.maxUses
        if maxUses and maxUses > 0 and item.getCurrentUses then
            local frac = item:getCurrentUses() / maxUses
            if frac < 1 then return frac end
        end
    end
    if item.getCondition and item.getConditionMax then
        local maxCondition = item:getConditionMax()
        if maxCondition and maxCondition > 0 then
            local condition = item:getCondition()
            if condition < maxCondition then return condition / maxCondition end
        end
    end
    if typeInfo.isFood and item.getHungerChange and item.getBaseHunger then
        local baseHunger = item:getBaseHunger()
        if baseHunger ~= 0 then
            local frac = item:getHungerChange() / baseHunger
            if frac < 1 then return frac end
        end
    end
    if typeInfo.isLiterature and playerObj ~= nil
            and item.getNumberOfPages and playerObj.getAlreadyReadPages then
        local pages = item:getNumberOfPages()
        if pages and pages > 0 then
            local pagesRead = playerObj:getAlreadyReadPages(item:getFullType())
            if pagesRead and pagesRead > 0 and pagesRead < pages then
                return pagesRead / pages
            end
        end
    end
    return nil
end

local NEVER_ROTS_DAYS = 1000000

local function freshnessFraction(item)
    if item.isRotten and item:isRotten() then return 0 end
    if item.getAge and item.getOffAgeMax then
        local age = item:getAge()
        local rotDays = item:getOffAgeMax()
        if type(age) == "number" and type(rotDays) == "number"
                and rotDays > 0 and rotDays < NEVER_ROTS_DAYS and age >= 0 then
            local frac = 1 - age / rotDays
            if frac < 0 then return 0 end
            if frac > 1 then return 1 end
            return frac
        end
    end
    return nil
end

function StackRenderer.freshnessOf(item)
    if item == nil or not (item.IsFood and item:IsFood()) then return nil end
    return freshnessFraction(item)
end

local function isReadDone(item, typeInfo, playerObj)
    if typeInfo.isLiterature then
        local modData = item.hasModData and item:hasModData()
            and item:getModData() or nil
        if modData ~= nil then
            if modData.literatureTitle ~= nil and playerObj.isLiteratureRead
                    and playerObj:isLiteratureRead(modData.literatureTitle) then
                return true
            end

            if modData.printMedia ~= nil and playerObj.isPrintMediaRead
                    and playerObj:isPrintMediaRead(modData.printMedia.id) then
                return true
            end
            if modData.learnedRecipe ~= nil and playerObj.getKnownRecipes
                    and playerObj:getKnownRecipes():contains(modData.learnedRecipe) then
                return true
            end
        end
        local trained = item.getSkillTrained and item:getSkillTrained() or nil
        local skillBookEntry = trained ~= nil and SkillBook ~= nil and SkillBook[trained] or nil
        if skillBookEntry ~= nil and item.getMaxLevelTrained and playerObj.getPerkLevel
                and item:getMaxLevelTrained() < playerObj:getPerkLevel(skillBookEntry.perk) + 1 then
            return true
        end
        local pages = item.getNumberOfPages and item:getNumberOfPages() or 0
        if pages > 0 and playerObj.getAlreadyReadPages
                and playerObj:getAlreadyReadPages(item:getFullType()) >= pages then
            return true
        end
        local recipes = item.getLearnedRecipes and item:getLearnedRecipes() or nil
        if recipes ~= nil and playerObj.getKnownRecipes
                and playerObj:getKnownRecipes():containsAll(recipes) then
            return true
        end

        if playerObj.getAlreadyReadBook and item.getFullType then
            local readBooks = playerObj:getAlreadyReadBook()
            if readBooks ~= nil and readBooks:contains(item:getFullType()) then
                return true
            end
        end
    end
    if typeInfo.hasMedia then
        if item.hasBeenSeen and item:hasBeenSeen(playerObj) then return true end
        if item.hasBeenHeard and item:hasBeenHeard(playerObj) then return true end
    end
    if typeInfo.isMap and playerObj.hasReadMap and playerObj:hasReadMap(item) then
        return true
    end
    return false
end

local stackAllRead = {}
local stackAllReadEntries = 0

local function stackAllReadDone(stack, typeInfo, playerObj, inventory)

    if not inventory or stack == nil or stack.itemIDs == nil
            or playerObj == nil then
        return false
    end
    local now = getTimestampMs()
    local entry = stackAllRead[stack]

    if entry ~= nil and entry.count == stack.count
            and entry.player == playerObj
            and (now - entry.at) < MEMBER_RESCAN_MS then
        return entry.allRead
    end
    local allRead, seen = true, false
    for id in pairs(stack.itemIDs) do
        local member = inventory:getItemWithID(id)
        if member ~= nil then
            seen = true
            if not isReadDone(member, typeInfo, playerObj) then
                allRead = false
                break
            end
        end
    end

    if not seen then allRead = false end
    if entry == nil then
        stackAllRead, stackAllReadEntries, entry =
            newMemoEntry(stackAllRead, stackAllReadEntries, stack)
    end
    entry.count, entry.at, entry.allRead = stack.count, now, allRead
    entry.player = playerObj
    return allRead
end

local function ammoTextsFor(item, typeInfo)
    if typeInfo.maxAmmo == nil or item.getCurrentAmmoCount == nil then return nil end
    local loaded = item:getCurrentAmmoCount() or 0
    local chambered = item.isRoundChambered ~= nil
        and item:isRoundChambered() or false
    local ammoKey = loaded * 1000 + typeInfo.maxAmmo + (chambered and 500000 or 0)
    local texts = ammoTextSets[ammoKey]
    if texts == nil then
        if chambered then
            texts = { loaded .. "+1/" .. typeInfo.maxAmmo, loaded .. "+1",
                tostring(loaded + 1) }
        else
            texts = { loaded .. "/" .. typeInfo.maxAmmo, tostring(loaded) }
        end
        ammoTextSets[ammoKey] = texts
    end
    return texts
end

local marks = {}

local function markTextures(name, vanillaPath)
    local markSet = marks[name]
    if markSet ~= nil then return markSet end
    local fill = getTexture
        and getTexture("media/textures/comfy_" .. name .. ".png") or nil
    if fill ~= nil then
        markSet = { fill = fill, ours = true,
              line = getTexture("media/textures/comfy_" .. name .. "_line.png") }
    else

        local vanillaTexture = (vanillaPath ~= nil and getTexture)
            and getTexture(vanillaPath) or nil
        markSet = vanillaTexture ~= nil and { fill = vanillaTexture, ours = false }
            or false
    end
    marks[name] = markSet
    return markSet
end

local function markFit(tex, boxSize)
    local w, h = boxSize, boxSize
    local sourceWidth, sourceHeight = tex:getWidth(), tex:getHeight()
    if sourceWidth and sourceHeight and sourceWidth > 0 and sourceHeight > 0
            and sourceWidth ~= sourceHeight then
        if sourceWidth > sourceHeight then
            h = floor(boxSize * sourceHeight / sourceWidth + 0.5)
        else
            w = floor(boxSize * sourceWidth / sourceHeight + 0.5)
        end
    end
    return w, h
end

local function drawMark(view, markSet, x, y, w, h, fillColor, lineColor)
    if not markSet.ours then
        Blit.drawTextureScaled(view, markSet.fill, x, y, w, h, 1, 1, 1, 1)
        return
    end
    if markSet.line ~= nil and lineColor ~= nil then
        Blit.drawTextureScaled(view, markSet.line, x, y, w, h, 1,
            lineColor.r, lineColor.g, lineColor.b)
    end
    Blit.drawTextureScaled(view, markSet.fill, x, y, w, h, 1,
        fillColor.r, fillColor.g, fillColor.b)
end

local function drawCornerMark(view, name, vanillaPath, basePx, rightEdge, cellBottom,
        fillColor, lineColor)
    local markSet = markTextures(name, vanillaPath)
    if not markSet then return rightEdge end
    local markWidth, markHeight = markFit(markSet.fill, floor(basePx * Style.SCALE + 0.5))
    drawMark(view, markSet, rightEdge - markWidth, cellBottom - markHeight - 3,
        markWidth, markHeight, fillColor, lineColor)
    return rightEdge - markWidth - 2
end

local function drawShadowedText(view, text, x, y, color, shadowColor)
    if shadowColor ~= nil then
        local shadowOffset = floor(Style.SCALE + 0.5)
        if shadowOffset < 1 then shadowOffset = 1 end
        Blit.drawText(view, text, x + shadowOffset, y + shadowOffset,
            shadowColor.r, shadowColor.g, shadowColor.b, shadowColor.a or 1,
            Style.FONT)
    end
    Blit.drawText(view, text, x, y, color.r, color.g, color.b, color.a or 1,
        Style.FONT)
end
StackRenderer.drawShadowedText = drawShadowedText

local function drawStatusCapsule(view, x, y, size, fraction, color)
    local area = size - 10
    local barH = floor(area * fraction + 0.5)
    if barH < 2 and fraction > 0 then barH = 2 end

    if barH <= 0 then return end
    local barX = x + size - Style.BAR_INSET
    local barY = y + 5 + (area - barH)
    Blit.drawRect(view, barX + 1, barY, 1, 1, 1, color.r, color.g, color.b)
    if barH > 2 then
        Blit.drawRect(view, barX, barY + 1, 3, barH - 2, 1,
            color.r, color.g, color.b)
    end
    Blit.drawRect(view, barX + 1, barY + barH - 1, 1, 1, 1,
        color.r, color.g, color.b)
end
StackRenderer.drawStatusCapsule = drawStatusCapsule

function StackRenderer.draw(ctx)

    local brokenBadge = false
    local stack = ctx.stack
    if not stack then return end
    local view = ctx.view
    local x = ctx.x
    local y = ctx.y
    local item = ctx.item
    local cellSize = Style.CELL
    local iconAreaSize = Style.TEXTURE_SIZE
    local iconPad = Style.PAD

    local colors = Style.COLORS
    local tint = Style.tintForCategory(stack.category)

    local unwanted = false
    local viewer = nil
    if item ~= nil and item.isUnwanted ~= nil and ctx.playerNum ~= nil then
        viewer = getSpecificPlayer(ctx.playerNum)
        if viewer ~= nil then unwanted = item:isUnwanted(viewer) == true end
    end

    local typeInfo = nil
    local frozen, heatSide, burning = 0, 0, false
    if item then
        typeInfo = typeDataFor(item,
            stack.itemType or (item.getFullType and item:getFullType()) or "?")
        if typeInfo.isFood or typeInfo.heatsAsItem then
            frozen, heatSide, burning =
                temperatureStateOf(stack, item, typeInfo, ctx.inventory)
        end
    end

    local cellTint = tint
    if unwanted then
        cellTint = colors.UNWANTED_CELL
    elseif frozen == 2 or heatSide < 0 then
        cellTint = colors.FROZEN_CELL
    elseif heatSide > 0 then
        cellTint = colors.HOT_CELL
    end
    SlotRenderer.drawCell(ctx, cellTint)

    local tex = item and item:getTex() or nil
    local bulky = false
    if tex then
        local texW = tex:getWidth()
        local texH = tex:getHeight()
        if texW and texH and texW > 0 and texH > 0 then

            local bulkScale = 0.92
            local frontActualWeight = item.getActualWeight and item:getActualWeight() or nil
            if type(frontActualWeight) == "number" then
                if frontActualWeight <= 0.4 then
                    bulkScale = 0.72
                elseif frontActualWeight >= 3 then
                    bulkScale = 1.05
                    bulky = true
                end
            end
            local box = iconAreaSize * bulkScale

            local hiRes = Icons.hiRes(tex)
            if not nearestUnsupported and not hiRes then

                if not pcall(applyNearest, tex) then
                    disableNearest()
                elseif nearestTap ~= nil then
                    nearestTap(tex)
                end
            end

            local faded = unwanted and UNWANTED_ALPHA or 1

            Icons.draw(view, item,
                x + 1 + iconPad + (iconAreaSize - box) * 0.5,
                y + 1 + iconPad + (iconAreaSize - box) * 0.5,
                faded, box, box, hiRes)

            if unwanted then
                local markSet = markTextures("unwanted", nil)
                if markSet then
                    local markSize = floor(cellSize * UNWANTED_MARK_FRAC + 0.5)
                    local markWidth, markHeight = markFit(markSet.fill, markSize)
                    Blit.drawTextureScaled(view, markSet.fill,
                        x + (cellSize - markWidth) * 0.5,
                        y + (cellSize - markHeight) * 0.5,
                        markWidth, markHeight, UNWANTED_MARK_ALPHA, 1, 1, 1)
                end
            end
        else
            tex = nil
        end
    end
    if not tex then

        local placeholder = colors.PLACEHOLDER_TEXT
        view:drawTextCentre("?", x + cellSize * 0.5,
            y + (cellSize - Style.FONT_H) * 0.5, placeholder.r, placeholder.g,
            placeholder.b, placeholder.a, Style.FONT)
    end

    if item then

        local single = (stack.count == nil or stack.count <= 1)
        if single then
            if item.isBroken and item:isBroken() then
                local wash = colors.BROKEN_WASH
                Blit.drawRect(view, x + 1, y + 1, cellSize - 2, cellSize - 2,
                    wash.a, wash.r, wash.g, wash.b)

                StackRenderer.drawBrokenMark(view, x, y, cellSize)
            end
        else
            brokenBadge = stackHasBroken(stack, ctx.inventory)
        end

        local playerObj = nil
        if typeInfo.readable and ctx.playerNum ~= nil then
            playerObj = viewer or getSpecificPlayer(ctx.playerNum)
        end

        local frac = nil
        if ctx.freshnessBar and typeInfo.isFood then
            frac = freshnessFraction(item)
        end
        if frac == nil and showStatusBar then
            frac = statusBarFraction(item, typeInfo, playerObj)
        end
        if frac then
            if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
            drawStatusCapsule(view, x, y, cellSize, frac,
                BAR_COLORS[floor(frac * 100 + 0.5)])
        end

        local readTick = false
        if playerObj ~= nil then
            if stack.count == nil or stack.count <= 1 or not ctx.inventory then
                readTick = isReadDone(item, typeInfo, playerObj)
            else
                readTick = stackAllReadDone(stack, typeInfo, playerObj, ctx.inventory)
            end
        end

        local clearRight = x + cellSize - Style.BAR_INSET - 1
        local cellBottom = y + cellSize
        local textRight = clearRight
        if readTick then
            textRight = drawCornerMark(view, "tick", "media/ui/Tick_Mark-10.png", 10,
                textRight, cellBottom, colors.READ_TICK, colors.READ_TICK_LINE)
        end

        if frozen > 0 then
            textRight = drawCornerMark(view, "frozen", "media/ui/icon_frozen.png",
                CORNER_MARK_PX, textRight, cellBottom, colors.FROZEN, colors.FROZEN_LINE)
        end

        if burning then
            textRight = drawCornerMark(view, "burning", nil, CORNER_MARK_PX,
                textRight, cellBottom, colors.BURNING, colors.BURNING_LINE)
        end

        local weightIcon = nil
        if not ctx.skipWeightMark then
            weightIcon = weightTexture()
        end

        local markRight = x + 2
        if weightIcon ~= nil then
            local total

            if stack.count and stack.count > 1 and ctx.inventory
                    and stack.itemIDs ~= nil then
                total = totalStackWeight(stack, ctx.inventory)
            else

                if item.getUnequippedWeight then
                    local okWeight, unequippedWeight = pcall(item.getUnequippedWeight, item)
                    total = okWeight and unequippedWeight or nil
                end
                if type(total) ~= "number" and item.getActualWeight then
                    total = item:getActualWeight()
                end
            end
            if type(total) == "number" then
                local weightRamp = StackRenderer.weightColor(total)

                local weightSize = floor(8 * Style.SCALE + 0.5)
                local weightX, weightY = x + 3, y + cellSize - weightSize - 3
                local line = weightLineTexture()
                if line ~= nil then
                    Blit.drawTextureScaled(view, line, weightX, weightY,
                        weightSize, weightSize, 1,
                        weightRamp.lr, weightRamp.lg, weightRamp.lb)
                end
                Blit.drawTextureScaled(view, weightIcon, weightX, weightY,
                    weightSize, weightSize, 1,
                    weightRamp.r, weightRamp.g, weightRamp.b)
                markRight = weightX + weightSize + 2
            end
        end

        local ammoTexts = ammoTextsFor(item, typeInfo)
        if ammoTexts ~= nil then

            for textIndex = 1, #ammoTexts do
                local ammoText = ammoTexts[textIndex]
                local ammoX = textRight - measuredWidth(ammoText)
                if ammoX >= markRight then
                    drawShadowedText(view, ammoText, ammoX,
                        y + cellSize - Style.FONT_H - 1, colors.COUNT_TEXT,
                        colors.COUNT_SHADOW)
                    break
                end
            end
        end

        local volume = typeInfo.bookVolume
        if volume ~= nil and playerObj ~= nil then
            local text = countStrings[volume]
            if text == nil then
                text = tostring(volume)
                countStrings[volume] = text
            end
            local volumeX = textRight - measuredWidth(text)
            if volumeX >= markRight then

                local locked = false
                if not readTick and SkillBook ~= nil and typeInfo.bookSkill ~= nil
                        and playerObj.getPerkLevel ~= nil then
                    local skillBookEntry = SkillBook[typeInfo.bookSkill]
                    if skillBookEntry ~= nil and skillBookEntry.perk ~= nil then
                        locked = typeInfo.bookLvl
                            > playerObj:getPerkLevel(skillBookEntry.perk) + 1
                    end
                end
                drawShadowedText(view, text, volumeX,
                    y + cellSize - Style.FONT_H - 1,
                    locked and colors.BOOK_LOCKED or colors.COUNT_TEXT,
                    colors.COUNT_SHADOW)
            end
        end

        if bulky and weightIcon == nil and not ctx.skipWeightMark then
            local markBottom = y + cellSize - 3
            local mark = colors.BULK_MARK
            Blit.drawRect(view, x + 3, markBottom - 2, 7, 2,
                mark.a, mark.r, mark.g, mark.b)
            Blit.drawRect(view, x + 3, markBottom - 4, 5, 2,
                mark.a, mark.r, mark.g, mark.b)
            Blit.drawRect(view, x + 3, markBottom - 6, 3, 2,
                mark.a, mark.r, mark.g, mark.b)
        end
    end

    if item and item.isFavorite and item:isFavorite() then
        local markSet = markTextures("star", "media/ui/FavoriteStar.png")
        if markSet then
            local markSize = floor(10 * Style.SCALE + 0.5)
            local markWidth, markHeight = markFit(markSet.fill, markSize)
            drawMark(view, markSet, x + cellSize - Style.BAR_INSET - 1 - markWidth,
                y + 2, markWidth, markHeight,
                colors.FAVORITE, colors.FAVORITE_LINE)
        end
    end

    local count = stack.count
    if count and count > 1 then

        local textX = x + 2
        if brokenBadge then
            local badgeSize = floor(BROKEN_BADGE_PX * Style.SCALE + 0.5)
            local badgeCap = floor(cellSize * BROKEN_BADGE_MAX_FRAC)
            if badgeSize > badgeCap then badgeSize = badgeCap end
            if badgeSize < 4 then badgeSize = 4 end
            StackRenderer.blitBrokenMark(view, textX, y + 1, badgeSize)
            textX = textX + badgeSize + 2
        end
        local text = countStrings[count]
        if not text then
            text = tostring(count)
            countStrings[count] = text
        end
        drawShadowedText(view, text, textX, y, colors.COUNT_TEXT,
            colors.COUNT_SHADOW)
    end
end

function StackRenderer.updateItem(item)
    if not item then return end
    if item.updateAge then
        item:updateAge()
    end
    if instanceof(item, "Clothing") and item.updateWetness then
        item:updateWetness()
    end
end

function StackRenderer.currentActionOf(playerNum)
    local playerObj = playerNum ~= nil and getSpecificPlayer(playerNum) or nil
    if playerObj == nil then return nil end
    local queues = ISTimedActionQueue.queues
    local actionQueue = queues ~= nil and queues[playerObj] or nil
    local queuedActions = actionQueue ~= nil and actionQueue.queue or nil
    return queuedActions ~= nil and queuedActions[1] or nil
end

function StackRenderer.jobDeltaOf(item, currentAction)
    if item == nil then return nil end
    local itemDelta = item:getJobDelta()
    if itemDelta ~= nil and itemDelta > 0 then return itemDelta end
    if currentAction ~= nil and currentAction.item == item
            and currentAction.getJobDelta ~= nil then
        local ok, actionDelta = pcall(currentAction.getJobDelta, currentAction)
        if ok and type(actionDelta) == "number" then
            if actionDelta < 0 then actionDelta = 0 end
            return actionDelta
        end

        return 0
    end
    return nil
end

function StackRenderer.drawJobOverlay(view, x, y, delta)
    if view == nil or delta == nil or delta >= 1 then return end
    local cell = Style.CELL

    local inner = cell - 4
    local coverH = inner
    if delta > 0 then
        coverH = floor(inner * (1 - delta) + 0.5)
    end
    if coverH <= 0 then return end
    local colors = Style.COLORS
    local overlayColor = colors.TRANSFER_OVERLAY
    local edgeColor = colors.TRANSFER_EDGE
    Blit.drawRect(view, x + 2, y + 2, inner, coverH, overlayColor.a,
        overlayColor.r, overlayColor.g, overlayColor.b)
    Blit.drawRect(view, x + 2, y + coverH, inner, 2, edgeColor.a,
        edgeColor.r, edgeColor.g, edgeColor.b)
end

function StackRenderer.overlayInfo(item)
    if item == nil then return nil, nil, nil end
    local typeInfo = typeDataFor(item,
        (item.getFullType and item:getFullType()) or "?")
    local frac = statusBarFraction(item, typeInfo, nil)
    local barColor = nil
    if frac ~= nil then
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        barColor = BAR_COLORS[floor(frac * 100 + 0.5)]
    end
    return frac, barColor, ammoTextsFor(item, typeInfo)
end

function StackRenderer.isReadDone(item, playerObj)
    if item == nil or playerObj == nil then return false end
    local typeInfo = typeDataFor(item,
        (item.getFullType and item:getFullType()) or "?")
    if not typeInfo.readable then return false end
    return isReadDone(item, typeInfo, playerObj)
end

function StackRenderer.stackReadDone(stack, front, playerObj, inventory)
    if stack == nil or front == nil or playerObj == nil then return false end
    local typeInfo = typeDataFor(front,
        stack.itemType or (front.getFullType and front:getFullType()) or "?")
    if not typeInfo.readable then return false end
    if stack.count == nil or stack.count <= 1 or not inventory then
        return isReadDone(front, typeInfo, playerObj)
    end
    return stackAllReadDone(stack, typeInfo, playerObj, inventory)
end

function StackRenderer.jobOverlayFor(stack, front, jobs, currentAction)
    local hit, bestDelta = false, 0
    if jobs ~= nil then
        for id, jobItem in pairs(jobs) do
            if stack.itemIDs[id] then
                hit = true
                local itemDelta = jobItem:getJobDelta()
                if itemDelta ~= nil and itemDelta > bestDelta then bestDelta = itemDelta end
                if bestDelta > 0 then break end
            end
        end
    end
    if not hit then
        local frontDelta = StackRenderer.jobDeltaOf(front, currentAction)
        if frontDelta ~= nil then hit, bestDelta = true, frontDelta end
    end
    return hit, bestDelta
end
