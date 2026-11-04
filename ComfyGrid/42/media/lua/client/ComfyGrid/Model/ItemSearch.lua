--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.10
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
require "ComfyGrid/Core/Log"
require "ComfyGrid/Core/Util"
ComfyGrid = ComfyGrid or {}
ComfyGrid.Model = ComfyGrid.Model or {}
local ItemSearch = {}
ComfyGrid.Model.ItemSearch = ItemSearch

local Log = ComfyGrid.Core.Log

local REFRESH_MS = 250
local MAX_BAG_DEPTH = 8
local FOLDED_NAME_LIMIT = 4096
local STACK_MEMO_LIMIT = 4096

local wipe = ComfyGrid.Core.Util.wipe

local ACCENT_FOLD = {
    [192] = "a", [193] = "a", [194] = "a", [195] = "a", [196] = "a", [197] = "a",
    [198] = "ae", [199] = "c", [200] = "e", [201] = "e", [202] = "e", [203] = "e",
    [204] = "i", [205] = "i", [206] = "i", [207] = "i", [208] = "d", [209] = "n",
    [210] = "o", [211] = "o", [212] = "o", [213] = "o", [214] = "o", [216] = "o",
    [217] = "u", [218] = "u", [219] = "u", [220] = "u", [221] = "y", [222] = "th",
    [223] = "ss", [224] = "a", [225] = "a", [226] = "a", [227] = "a", [228] = "a",
    [229] = "a", [230] = "ae", [231] = "c", [232] = "e", [233] = "e", [234] = "e",
    [235] = "e", [236] = "i", [237] = "i", [238] = "i", [239] = "i", [240] = "d",
    [241] = "n", [242] = "o", [243] = "o", [244] = "o", [245] = "o", [246] = "o",
    [248] = "o", [249] = "u", [250] = "u", [251] = "u", [252] = "u", [253] = "y",
    [254] = "th", [255] = "y", [256] = "a", [257] = "a", [258] = "a", [259] = "a",
    [260] = "a", [261] = "a", [262] = "c", [263] = "c", [264] = "c", [265] = "c",
    [266] = "c", [267] = "c", [268] = "c", [269] = "c", [270] = "d", [271] = "d",
    [272] = "d", [273] = "d", [274] = "e", [275] = "e", [276] = "e", [277] = "e",
    [278] = "e", [279] = "e", [280] = "e", [281] = "e", [282] = "e", [283] = "e",
    [284] = "g", [285] = "g", [286] = "g", [287] = "g", [288] = "g", [289] = "g",
    [290] = "g", [291] = "g", [292] = "h", [293] = "h", [294] = "h", [295] = "h",
    [296] = "i", [297] = "i", [298] = "i", [299] = "i", [300] = "i", [301] = "i",
    [302] = "i", [303] = "i", [304] = "i", [305] = "i", [306] = "ij", [307] = "ij",
    [308] = "j", [309] = "j", [310] = "k", [311] = "k", [312] = "k", [313] = "l",
    [314] = "l", [315] = "l", [316] = "l", [317] = "l", [318] = "l", [319] = "l",
    [320] = "l", [321] = "l", [322] = "l", [323] = "n", [324] = "n", [325] = "n",
    [326] = "n", [327] = "n", [328] = "n", [330] = "n", [331] = "n", [332] = "o",
    [333] = "o", [334] = "o", [335] = "o", [336] = "o", [337] = "o", [338] = "oe",
    [339] = "oe", [340] = "r", [341] = "r", [342] = "r", [343] = "r", [344] = "r",
    [345] = "r", [346] = "s", [347] = "s", [348] = "s", [349] = "s", [350] = "s",
    [351] = "s", [352] = "s", [353] = "s", [354] = "t", [355] = "t", [356] = "t",
    [357] = "t", [358] = "t", [359] = "t", [360] = "u", [361] = "u", [362] = "u",
    [363] = "u", [364] = "u", [365] = "u", [366] = "u", [367] = "u", [368] = "u",
    [369] = "u", [370] = "u", [371] = "u", [372] = "w", [373] = "w", [374] = "y",
    [375] = "y", [376] = "y", [377] = "z", [378] = "z", [379] = "z", [380] = "z",
    [381] = "z", [382] = "z", [383] = "s",

    [536] = "s", [537] = "s", [538] = "t", [539] = "t",
    [1025] = string.char(1077), [1105] = string.char(1077),
}

for combiningMark = 768, 879 do ACCENT_FOLD[combiningMark] = "" end

function ItemSearch.fold(text)
    if text == nil then return "" end
    local lowered = string.lower(text)
    local length = #lowered
    local hasWideCharacter = false
    for charIndex = 1, length do
        if string.byte(lowered, charIndex) > 127 then
            hasWideCharacter = true
            break
        end
    end
    if not hasWideCharacter then return lowered end
    local pieces = {}
    for charIndex = 1, length do
        pieces[charIndex] = ACCENT_FOLD[string.byte(lowered, charIndex)]
            or string.sub(lowered, charIndex, charIndex)
    end
    return table.concat(pieces)
end

function ItemSearch.wordsOf(rawText)
    if rawText == nil then return nil end
    local folded = ItemSearch.fold(rawText)
    local length = #folded
    local words = nil
    local cursor = 1
    while cursor <= length do
        local spaceAt = string.find(folded, " ", cursor, true)
        local wordEnd = spaceAt ~= nil and spaceAt - 1 or length
        if wordEnd >= cursor then
            words = words or {}
            words[#words + 1] = string.sub(folded, cursor, wordEnd)
        end
        cursor = wordEnd + 2
    end
    return words
end

local MIN_WORD_LENGTH = 2
local FIRST_IDEOGRAPHIC_CODE = 0x2E80

local function hasSearchableWord(words)
    for wordIndex = 1, #words do
        local word = words[wordIndex]
        if #word >= MIN_WORD_LENGTH then return true end
        if string.byte(word, 1) >= FIRST_IDEOGRAPHIC_CODE then return true end
    end
    return false
end

function ItemSearch.isSearchable(rawText)
    local words = ItemSearch.wordsOf(rawText)
    return words ~= nil and hasSearchableWord(words)
end

local foldedNames = {}
local foldedNameCount = 0

local function foldedNameOf(item)
    local name = item:getName()
    if name == nil then return "" end
    local folded = foldedNames[name]
    if folded == nil then
        if foldedNameCount >= FOLDED_NAME_LIMIT then
            foldedNames = {}
            foldedNameCount = 0
        end
        folded = ItemSearch.fold(name)
        foldedNames[name] = folded
        foldedNameCount = foldedNameCount + 1
    end
    return folded
end

local function nameMatches(item, words)
    local folded = foldedNameOf(item)
    for wordIndex = 1, #words do
        if string.find(folded, words[wordIndex], 1, true) == nil then return false end
    end
    return true
end

local walkedContainers = {}

local function collectMatches(container, words, marks, depth)
    if container == nil or depth > MAX_BAG_DEPTH then return false end
    local known = walkedContainers[container]
    if known ~= nil then return known end

    walkedContainers[container] = false
    local items = container:getItems()
    local anyMatch = false
    for itemIndex = 0, items:size() - 1 do
        local item = items:get(itemIndex)

        if item ~= nil and not item:isHidden() then
            local marked = nameMatches(item, words)
            if instanceof(item, "InventoryContainer") then
                local innerContainer = item:getInventory()
                if innerContainer ~= nil
                        and collectMatches(innerContainer, words, marks, depth + 1) then
                    marked = true
                end
            end
            if marked then
                marks.itemIds[item:getID()] = true
                anyMatch = true
            end
        end
    end
    walkedContainers[container] = anyMatch
    if anyMatch then marks.containers[container] = true end
    return anyMatch
end

function ItemSearch.matchContainers(containers, rawText)
    local words = ItemSearch.wordsOf(rawText)
    if words == nil then return nil end
    local marks = { itemIds = {}, containers = {}, generation = 0 }
    wipe(walkedContainers)
    for containerIndex = 1, #containers do
        collectMatches(containers[containerIndex], words, marks, 0)
    end
    wipe(walkedContainers)
    return marks
end

local wordsByPage = {}
local marksBySeat = {}
local searchGeneration = 0
local lastWalkError = nil

local function marksOfSeat(playerNum)
    local marks = marksBySeat[playerNum]
    if marks == nil then
        marks = { itemIds = {}, containers = {}, generation = 0,
                  expiresMs = 0, stale = true }
        marksBySeat[playerNum] = marks
    end
    return marks
end

function ItemSearch.setTerm(page, rawText)
    if page == nil then return end
    local words = ItemSearch.wordsOf(rawText)
    if words ~= nil and not hasSearchableWord(words) then words = nil end
    wordsByPage[page] = words
    if page.player ~= nil then marksOfSeat(page.player).stale = true end
end

function ItemSearch.wordsFor(page)
    if page == nil then return nil end
    return wordsByPage[page]
end

local function walkPage(page, words, marks)
    local buttons = page.backpacks
    if type(buttons) ~= "table" then return end
    wipe(walkedContainers)
    for buttonIndex = 1, #buttons do
        local button = buttons[buttonIndex]
        local container = button ~= nil and button.inventory or nil
        if container ~= nil then collectMatches(container, words, marks, 0) end
    end
end

local function rebuildSeatMarks(marks, playerPage, playerWords, lootPage, lootWords)
    wipe(marks.itemIds)
    wipe(marks.containers)
    if playerWords ~= nil then walkPage(playerPage, playerWords, marks) end
    if lootWords ~= nil then walkPage(lootPage, lootWords, marks) end
    wipe(walkedContainers)
    searchGeneration = searchGeneration + 1
    marks.generation = searchGeneration
end

function ItemSearch.marksFor(playerNum)
    if playerNum == nil then return nil end
    local playerPage = getPlayerInventory(playerNum)
    local lootPage = getPlayerLoot(playerNum)
    local playerWords = playerPage ~= nil and wordsByPage[playerPage] or nil
    local lootWords = lootPage ~= nil and wordsByPage[lootPage] or nil
    if playerWords == nil and lootWords == nil then return nil end
    local marks = marksOfSeat(playerNum)
    local nowMs = getTimestampMs()
    if marks.stale or nowMs >= marks.expiresMs then

        local walked, failure = pcall(rebuildSeatMarks, marks, playerPage, playerWords,
            lootPage, lootWords)
        if not walked and failure ~= lastWalkError then
            lastWalkError = failure
            Log.warn("ItemSearch: walk failed: " .. tostring(failure))
        end
        marks.stale = false
        marks.expiresMs = nowMs + REFRESH_MS
    end
    return marks
end

function ItemSearch.marksItem(marks, item)
    if marks == nil or item == nil then return false end
    return marks.itemIds[item:getID()] == true
end

function ItemSearch.marksContainer(marks, container)
    if marks == nil or container == nil then return false end
    return marks.containers[container] == true
end

local stackMemoGeneration = {}
local stackMemoChange = {}
local stackMemoHit = {}
local stackMemoCount = 0

function ItemSearch.marksStack(marks, stack, changeCount)
    if marks == nil or stack == nil or stack.itemIDs == nil then return false end
    if stackMemoGeneration[stack] == marks.generation
            and stackMemoChange[stack] == changeCount then
        return stackMemoHit[stack]
    end
    local hit = false
    local itemIds = marks.itemIds
    for memberId in pairs(stack.itemIDs) do
        if itemIds[memberId] then
            hit = true
            break
        end
    end
    if stackMemoGeneration[stack] == nil then
        if stackMemoCount >= STACK_MEMO_LIMIT then
            stackMemoGeneration, stackMemoChange, stackMemoHit = {}, {}, {}
            stackMemoCount = 0
        end
        stackMemoCount = stackMemoCount + 1
    end
    stackMemoGeneration[stack] = marks.generation
    stackMemoChange[stack] = changeCount
    stackMemoHit[stack] = hit
    return hit
end
