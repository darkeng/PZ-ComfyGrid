--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
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
    [192] = 97, [193] = 97, [194] = 97, [195] = 97, [196] = 97, [197] = 97,
    [224] = 97, [225] = 97, [226] = 97, [227] = 97, [228] = 97, [229] = 97,
    [199] = 99, [231] = 99,
    [200] = 101, [201] = 101, [202] = 101, [203] = 101,
    [232] = 101, [233] = 101, [234] = 101, [235] = 101,
    [204] = 105, [205] = 105, [206] = 105, [207] = 105,
    [236] = 105, [237] = 105, [238] = 105, [239] = 105,
    [209] = 110, [241] = 110,
    [210] = 111, [211] = 111, [212] = 111, [213] = 111, [214] = 111,
    [242] = 111, [243] = 111, [244] = 111, [245] = 111, [246] = 111,
    [217] = 117, [218] = 117, [219] = 117, [220] = 117,
    [249] = 117, [250] = 117, [251] = 117, [252] = 117,
    [221] = 121, [253] = 121, [255] = 121,
}

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
        local plainCode = ACCENT_FOLD[string.byte(lowered, charIndex)]
        if plainCode ~= nil then
            pieces[charIndex] = string.char(plainCode)
        else
            pieces[charIndex] = string.sub(lowered, charIndex, charIndex)
        end
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
