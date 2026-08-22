--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.3.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/UI/Style"
require "ComfyGrid/UI/SlotRenderer"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}
local StackRenderer = {}
ComfyGrid.UI.StackRenderer = StackRenderer

local Log = ComfyGrid.Core.Log
local Style = ComfyGrid.UI.Style
local SlotRenderer = ComfyGrid.UI.SlotRenderer
local floor = math.floor

local FALLBACK_TINT = { r = 0.65, g = 0.65, b = 0.65 }
local FALLBACK_COUNT_TEXT = { r = 1, g = 1, b = 1, a = 1 }

local BROKEN_OVERLAY_ALPHA = 0.35

local countStrings = {}

local ammoStrings = {}

local BAR_COLORS = {}
do
    local colors = Style.COLORS
    local low = (colors and colors.BAR_LOW) or { r = 1, g = 0, b = 0 }
    local mid = (colors and colors.BAR_MID) or { r = 1, g = 1, b = 0 }
    local high = (colors and colors.BAR_HIGH) or { r = 0, g = 1, b = 0 }
    for i = 0, 100 do
        local t = i / 100
        local a, b, f
        if t <= 0.5 then
            a, b, f = low, mid, t * 2
        else
            a, b, f = mid, high, (t - 0.5) * 2
        end
        BAR_COLORS[i] = {
            r = a.r + (b.r - a.r) * f,
            g = a.g + (b.g - a.g) * f,
            b = a.b + (b.b - a.b) * f,
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
    local low = (colors and colors.WEIGHT_LOW) or { r = 0.45, g = 0.80, b = 0.40 }
    local mid = (colors and colors.WEIGHT_MID) or { r = 0.90, g = 0.72, b = 0.30 }
    local deep = (colors and colors.WEIGHT_DEEP) or { r = 0.64, g = 0.10, b = 0.09 }
    local high = (colors and colors.WEIGHT_HIGH) or { r = 1.00, g = 0.17, b = 0.12 }
    local surf = colors and colors.SURFACE
    local dark = (surf and surf.card) or { r = 0.148, g = 0.135, b = 0.116 }
    for i = 0, 100 do
        local t = i / 100
        local a, b, f
        if t <= 0.5 then
            a, b, f = low, mid, t * 2
        elseif t <= WEIGHT_KNEE_FRAC then
            a, b, f = mid, deep, (t - 0.5) / (WEIGHT_KNEE_FRAC - 0.5)
        else
            a, b, f = deep, high, (t - WEIGHT_KNEE_FRAC) / (1 - WEIGHT_KNEE_FRAC)
        end
        local cr = a.r + (b.r - a.r) * f
        local cg = a.g + (b.g - a.g) * f
        local cb = a.b + (b.b - a.b) * f

        local pt = t * 1.6
        if pt > 1 then pt = 1 end
        local pres = WEIGHT_MIN_ALPHA + (1 - WEIGHT_MIN_ALPHA) * pt
        local lp = 0.65 * pres
        WEIGHT_COLORS[i] = {
            r = dark.r + (cr - dark.r) * pres,
            g = dark.g + (cg - dark.g) * pres,
            b = dark.b + (cb - dark.b) * pres,
            lr = dark.r + (1 - dark.r) * lp,
            lg = dark.g + (1 - dark.g) * lp,
            lb = dark.b + (1 - dark.b) * lp,
        }
    end
end

local weightTex = nil
local weightTexMissing = false
local function weightTexture()
    if weightTex == nil and not weightTexMissing then
        weightTex = getTexture and getTexture("media/textures/comfy_weight.png") or nil
        if weightTex == nil then weightTexMissing = true end
    end
    return weightTex
end

local weightLineTex = nil
local weightLineTexMissing = false
local function weightLineTexture()
    if weightLineTex == nil and not weightLineTexMissing then
        weightLineTex = getTexture and getTexture("media/textures/comfy_weight_line.png") or nil
        if weightLineTex == nil then weightLineTexMissing = true end
    end
    return weightLineTex
end

local ammoWidths = {}

local stackWeights = {}
local stackWeightEntries = 0
local MAX_WEIGHT_ENTRIES = 512

local function totalStackWeight(stack, inventory)
    local entry = stackWeights[stack]
    if entry ~= nil and entry.count == stack.count then
        return entry.total
    end
    local total = 0
    for id in pairs(stack.itemIDs) do
        local item = inventory:getItemWithID(id)

        if item ~= nil then

            total = total + item:getUnequippedWeight()
        end
    end
    if entry == nil then
        if stackWeightEntries >= MAX_WEIGHT_ENTRIES then
            stackWeights = {}
            stackWeightEntries = 0
        end
        entry = {}
        stackWeights[stack] = entry
        stackWeightEntries = stackWeightEntries + 1
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

function StackRenderer.weightLineTexture()
    return weightLineTexture()
end

local typeData = {}

local function typeDataFor(item, fullType)
    local td = typeData[fullType]
    if td then return td end
    td = {
        isFood = (item.IsFood and item:IsFood()) or false,
        isDrainable = (item.IsDrainable and item:IsDrainable()) or false,
        isLiterature = (item.IsLiterature and item:IsLiterature()) or false,
        isMap = instanceof(item, "MapItem") or false,
        hasMedia = (item.getMediaData and item:getMediaData() ~= nil) or false,
    }
    td.readable = td.isLiterature or td.isMap or td.hasMedia
    if td.isDrainable and item.getMaxUses then
        td.maxUses = item:getMaxUses()
    end

    if item.getMaxAmmo then
        local ma = item:getMaxAmmo()
        if type(ma) == "number" and ma > 0 then
            td.maxAmmo = ma
        end
    end
    typeData[fullType] = td
    return td
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

local function statusBarFraction(item, td, playerObj)
    if td.isDrainable then
        local max = td.maxUses
        if max and max > 0 and item.getCurrentUses then
            local frac = item:getCurrentUses() / max
            if frac < 1 then return frac end
        end
    end
    if item.getCondition and item.getConditionMax then
        local max = item:getConditionMax()
        if max and max > 0 then
            local cond = item:getCondition()
            if cond < max then return cond / max end
        end
    end
    if td.isFood and item.getHungerChange and item.getBaseHunger then
        local base = item:getBaseHunger()
        if base ~= 0 then
            local frac = item:getHungerChange() / base
            if frac < 1 then return frac end
        end
    end
    if td.isLiterature and playerObj ~= nil
            and item.getNumberOfPages and playerObj.getAlreadyReadPages then
        local pages = item:getNumberOfPages()
        if pages and pages > 0 then
            local read = playerObj:getAlreadyReadPages(item:getFullType())
            if read and read > 0 and read < pages then
                return read / pages
            end
        end
    end
    return nil
end

local function isReadDone(item, td, playerObj)
    if td.isLiterature then
        local modData = item.hasModData and item:hasModData()
            and item:getModData() or nil
        if modData ~= nil then
            if modData.literatureTitle ~= nil and playerObj.isLiteratureRead
                    and playerObj:isLiteratureRead(modData.literatureTitle) then
                return true
            end
            if modData.printMedia ~= nil and playerObj.isPrintMediaRead
                    and playerObj:isPrintMediaRead(modData.printMedia.title) then
                return true
            end
            if modData.learnedRecipe ~= nil and playerObj.getKnownRecipes
                    and playerObj:getKnownRecipes():contains(modData.learnedRecipe) then
                return true
            end
        end
        local trained = item.getSkillTrained and item:getSkillTrained() or nil
        local sb = trained ~= nil and SkillBook ~= nil and SkillBook[trained] or nil
        if sb ~= nil and item.getMaxLevelTrained and playerObj.getPerkLevel
                and item:getMaxLevelTrained() < playerObj:getPerkLevel(sb.perk) + 1 then
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
    end
    if td.hasMedia then
        if item.hasBeenSeen and item:hasBeenSeen(playerObj) then return true end
        if item.hasBeenHeard and item:hasBeenHeard(playerObj) then return true end
    end
    if td.isMap and playerObj.hasReadMap and playerObj:hasReadMap(item) then
        return true
    end
    return false
end

local function ammoTextFor(item, td)
    if td.maxAmmo == nil or item.getCurrentAmmoCount == nil then return nil end
    local cur = item:getCurrentAmmoCount() or 0
    local chambered = item.isRoundChambered ~= nil
        and item:isRoundChambered() or false
    local akey = cur * 1000 + td.maxAmmo + (chambered and 500000 or 0)
    local text = ammoStrings[akey]
    if text == nil then
        if chambered then
            text = cur .. "+1/" .. td.maxAmmo
        else
            text = cur .. "/" .. td.maxAmmo
        end
        ammoStrings[akey] = text
    end
    return text
end

local tickTex = nil
local tickTexMissing = false

local function readTickTexture()
    if tickTex == nil and not tickTexMissing then
        tickTex = getTexture and getTexture("media/ui/Tick_Mark-10.png") or nil
        if tickTex == nil then tickTexMissing = true end
    end
    return tickTex
end

function StackRenderer.draw(ctx)
    local stack = ctx.stack
    if not stack then return end
    local view = ctx.view
    local x = ctx.x
    local y = ctx.y
    local item = ctx.item
    local CELL = Style.CELL
    local TEXTURE_SIZE = Style.TEXTURE_SIZE
    local PAD = Style.PAD

    local colors = Style.COLORS
    local tints = colors and colors.CATEGORY
    local tint = (tints and (tints[stack.category] or tints.default))
        or FALLBACK_TINT
    SlotRenderer.drawCell(ctx, tint)

    local tex = item and item:getTex() or nil
    local bulky = false

    local aw = nil
    if tex then
        local texW = tex:getWidth()
        local texH = tex:getHeight()
        if texW and texH and texW > 0 and texH > 0 then

            local wmul = 0.92
            aw = item.getActualWeight and item:getActualWeight() or nil
            if type(aw) == "number" then
                if aw <= 0.4 then
                    wmul = 0.72
                elseif aw >= 3 then
                    wmul = 1.05
                    bulky = true
                end
            end
            local box = TEXTURE_SIZE * wmul
            if not nearestUnsupported then

                if not pcall(applyNearest, tex) then
                    nearestUnsupported = true
                    Log.warn("nearest-neighbor icon filtering unavailable; falling back to linear")
                end
            end

            view:drawItemIcon(item,
                x + 1 + PAD + (TEXTURE_SIZE - box) * 0.5,
                y + 1 + PAD + (TEXTURE_SIZE - box) * 0.5,
                1, box, box)
        else
            tex = nil
        end
    end
    if not tex then

        view:drawTextCentre("?", x + CELL * 0.5,
            y + (CELL - Style.FONT_H) * 0.5, 1, 1, 1, 1, UIFont.Small)
    end

    if item then

        if item.isBroken and item:isBroken() then
            view:drawRect(x + 1, y + 1, CELL - 2, CELL - 2,
                BROKEN_OVERLAY_ALPHA, 0, 0, 0)
        end

        local td = typeDataFor(item,
            stack.itemType or (item.getFullType and item:getFullType()) or "?")
        local playerObj = nil
        if td.readable and ctx.playerNum ~= nil then
            playerObj = getSpecificPlayer(ctx.playerNum)
        end
        local frac = statusBarFraction(item, td, playerObj)
        if frac then
            if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end

            local area = CELL - 10
            local barH = floor(area * frac + 0.5)
            if barH < 2 and frac > 0 then barH = 2 end
            local col = BAR_COLORS[floor(frac * 100 + 0.5)]
            local bx = x + CELL - 7
            local by = y + 5 + (area - barH)
            view:drawRect(bx + 1, by, 1, 1, 1, col.r, col.g, col.b)
            if barH > 2 then
                view:drawRect(bx, by + 1, 3, barH - 2, 1, col.r, col.g, col.b)
            end
            view:drawRect(bx + 1, by + barH - 1, 1, 1, 1, col.r, col.g, col.b)
        end

        if playerObj ~= nil and isReadDone(item, td, playerObj) then
            local tick = readTickTexture()
            if tick then
                local sz = floor(10 * Style.SCALE + 0.5)
                view:drawTextureScaled(tick, x + CELL - sz - 4, y + CELL - sz - 3,
                    sz, sz, 1, 1, 1, 1)
            end
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
                if aw == nil and item.getActualWeight then
                    aw = item:getActualWeight()
                end
                total = aw
            end
            if type(total) == "number" then
                local wc = StackRenderer.weightColor(total)

                local wsz = floor(8 * Style.SCALE + 0.5)
                local wx, wy = x + 3, y + CELL - wsz - 3
                local line = weightLineTexture()
                if line ~= nil then
                    view:drawTextureScaled(line, wx, wy, wsz, wsz, 1,
                        wc.lr, wc.lg, wc.lb)
                end
                view:drawTextureScaled(weightIcon, wx, wy, wsz, wsz, 1,
                    wc.r, wc.g, wc.b)
                markRight = wx + wsz + 2
            end
        end

        local ammoText = ammoTextFor(item, td)
        if ammoText ~= nil then
            local fh = Style.FONT_H
            local byFont = ammoWidths[fh]
            if byFont == nil then
                byFont = {}
                ammoWidths[fh] = byFont
            end
            local tw = byFont[ammoText]
            if tw == nil then
                tw = getTextManager():MeasureStringX(UIFont.Small, ammoText)
                byFont[ammoText] = tw
            end
            local ax = x + CELL - 9 - tw

            if ax >= markRight then
                local colors2 = Style.COLORS
                local ty = y + CELL - fh - 1
                local cs = colors2 and colors2.COUNT_SHADOW
                if cs then
                    local off = floor(Style.SCALE + 0.5)
                    if off < 1 then off = 1 end
                    view:drawText(ammoText, ax + off, ty + off,
                        cs.r, cs.g, cs.b, cs.a or 1, UIFont.Small)
                end
                local ct = (colors2 and colors2.COUNT_TEXT) or FALLBACK_COUNT_TEXT
                view:drawText(ammoText, ax, ty, ct.r, ct.g, ct.b, ct.a or 1,
                    UIFont.Small)
            end
        end

        if bulky and weightIcon == nil and not ctx.skipWeightMark then
            local mb = y + CELL - 3
            view:drawRect(x + 3, mb - 2, 7, 2, 0.9, 0.82, 0.65, 0.38)
            view:drawRect(x + 3, mb - 4, 5, 2, 0.9, 0.82, 0.65, 0.38)
            view:drawRect(x + 3, mb - 6, 3, 2, 0.9, 0.82, 0.65, 0.38)
        end
    end

    local count = stack.count
    if count and count > 1 then
        local text = countStrings[count]
        if not text then
            text = tostring(count)
            countStrings[count] = text
        end
        local ct = (colors and colors.COUNT_TEXT) or FALLBACK_COUNT_TEXT
        local cs = colors and colors.COUNT_SHADOW
        if cs then
            local off = floor(Style.SCALE + 0.5)
            if off < 1 then off = 1 end
            view:drawText(text, x + 2 + off, y + off,
                cs.r, cs.g, cs.b, cs.a or 1, UIFont.Small)
        end
        view:drawText(text, x + 2, y, ct.r, ct.g, ct.b, ct.a or 1, UIFont.Small)
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

local FALLBACK_OVERLAY = { r = 0.0, g = 0.0, b = 0.0, a = 0.72 }
local FALLBACK_EDGE = { r = 0.95, g = 0.80, b = 0.25, a = 0.90 }

function StackRenderer.currentActionOf(playerNum)
    local playerObj = playerNum ~= nil and getSpecificPlayer(playerNum) or nil
    if playerObj == nil then return nil end
    local queues = ISTimedActionQueue.queues
    local q = queues ~= nil and queues[playerObj] or nil
    local list = q ~= nil and q.queue or nil
    return list ~= nil and list[1] or nil
end

function StackRenderer.jobDeltaOf(item, currentAction)
    if item == nil then return nil end
    local d = item:getJobDelta()
    if d ~= nil and d > 0 then return d end
    if currentAction ~= nil and currentAction.item == item
            and currentAction.getJobDelta ~= nil then
        local ok, ad = pcall(currentAction.getJobDelta, currentAction)
        if ok and type(ad) == "number" then
            if ad < 0 then ad = 0 end
            return ad
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
    local ov = (colors and colors.TRANSFER_OVERLAY) or FALLBACK_OVERLAY
    local ed = (colors and colors.TRANSFER_EDGE) or FALLBACK_EDGE
    view:drawRect(x + 2, y + 2, inner, coverH,
        ov.a or 0.72, ov.r or 0, ov.g or 0, ov.b or 0)
    view:drawRect(x + 2, y + coverH, inner, 2,
        ed.a or 0.9, ed.r or 0.95, ed.g or 0.80, ed.b or 0.25)
end

function StackRenderer.rampColor(frac)
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    return BAR_COLORS[floor(frac * 100 + 0.5)]
end

function StackRenderer.overlayInfo(item)
    if item == nil then return nil, nil, nil end
    local td = typeDataFor(item,
        (item.getFullType and item:getFullType()) or "?")
    local frac = statusBarFraction(item, td, nil)
    local col = nil
    if frac ~= nil then
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        col = BAR_COLORS[floor(frac * 100 + 0.5)]
    end
    return frac, col, ammoTextFor(item, td)
end

function StackRenderer.jobOverlayFor(stack, front, jobs, currentAction)
    local hit, best = false, 0
    if jobs ~= nil then
        for id, jobItem in pairs(jobs) do
            if stack.itemIDs[id] then
                hit = true
                local d = jobItem:getJobDelta()
                if d ~= nil and d > best then best = d end
                if best > 0 then break end
            end
        end
    end
    if not hit then
        local d = StackRenderer.jobDeltaOf(front, currentAction)
        if d ~= nil then hit, best = true, d end
    end
    return hit, best
end
