--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.9.2
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"
ComfyGrid = ComfyGrid or {}
ComfyGrid.UI = ComfyGrid.UI or {}

local EquipDock = {}
ComfyGrid.UI.EquipDock = EquipDock

local function screenOrigin(playerNum)
    local left = getPlayerScreenLeft ~= nil
        and getPlayerScreenLeft(playerNum) or 0
    local top = getPlayerScreenTop ~= nil
        and getPlayerScreenTop(playerNum) or 0
    return left, top
end
EquipDock.screenOrigin = screenOrigin

local function screenRect(playerNum)
    local left, top = screenOrigin(playerNum)
    local width = getPlayerScreenWidth ~= nil
        and getPlayerScreenWidth(playerNum) or 0
    local height = getPlayerScreenHeight ~= nil
        and getPlayerScreenHeight(playerNum) or 0
    return left, top, width, height
end
EquipDock.screenRect = screenRect

local function flushLootPage(playerNum, page)
    local ok, data = pcall(getPlayerData, playerNum)
    if not ok or data == nil then return nil end
    local loot = data.lootInventory
    if loot == nil or loot.getIsVisible == nil or not loot:getIsVisible() then
        return nil
    end
    local gap = loot:getX() - (page:getX() + page:getWidth())
    if gap < -2 or gap > 2 then return nil end
    return loot
end

function EquipDock.makeRoom(win, page)
    local previousReceipt = type(win.push) == "table" and win.push or nil

    if previousReceipt ~= nil and previousReceipt.page ~= nil
            and previousReceipt.page:getX() ~= previousReceipt.pageX then
        previousReceipt = nil
    end
    win.pushWidth = win.preferredWidth or win.width
    win.push = previousReceipt or false
    local screenLeft, _, screenWidth = screenRect(win.playerNum)
    local missingWidth = (win.preferredWidth or win.width)
        - (page:getX() - screenLeft) - 1
    if missingWidth <= 0 or screenWidth <= 0 then return end
    local loot = flushLootPage(win.playerNum, page)
    local rightMost = loot ~= nil and (loot:getX() + loot:getWidth())
        or (page:getX() + page:getWidth())
    local slack = (screenLeft + screenWidth) - rightMost

    if missingWidth > slack then return end
    page:setX(page:getX() + missingWidth)
    if loot ~= nil then loot:setX(loot:getX() + missingWidth) end

    win.push = { page = page, pageX = page:getX(),
        amount = missingWidth
            + (previousReceipt ~= nil and previousReceipt.amount or 0),
        loot = loot, lootX = loot ~= nil and loot:getX() or nil }
end

function EquipDock.keepSavedSpot(win)
    win.pushWidth = win.preferredWidth or win.width
    win.push = false
end

function EquipDock.giveBackRoom(win)
    local receipt = win.push
    win.push = nil
    win.pushWidth = nil
    if type(receipt) ~= "table" then return end
    if receipt.page ~= nil and receipt.page:getX() == receipt.pageX then
        receipt.page:setX(receipt.pageX - receipt.amount)
    end
    if receipt.loot ~= nil and receipt.loot:getX() == receipt.lootX then
        receipt.loot:setX(receipt.lootX - receipt.amount)
    end
end

local function placePage(page, x, width)
    if page == nil then return end
    if page:getX() ~= x then page:setX(x) end
    if width > 0 and page:getWidth() ~= width then page:setWidth(width) end
end

function EquipDock.padRestore(page)
    local playerNum = page.player
    local screenLeft, _, screenWidth = screenRect(playerNum)
    if screenWidth <= 0 then return end
    local halfWidth = math.floor(screenWidth / 2)
    placePage(page, screenLeft, halfWidth)
    local ok, loot = pcall(getPlayerLoot, playerNum)
    if ok and loot ~= nil and loot ~= page then
        placePage(loot, screenLeft + halfWidth, screenWidth - halfWidth)
    end
end

function EquipDock.padSplit(win, page)
    local playerNum = win.playerNum
    local screenLeft, _, screenWidth = screenRect(playerNum)
    local windowWidth = win.preferredWidth or win.width
    if screenWidth <= 0 or windowWidth <= 0 or screenWidth - windowWidth < 200 then

        return false
    end
    local sideWidth = math.floor((screenWidth - windowWidth) / 2)
    placePage(page, screenLeft, sideWidth)
    local ok, loot = pcall(getPlayerLoot, playerNum)
    if ok and loot ~= nil and loot ~= page then
        placePage(loot, screenLeft + sideWidth + windowWidth,
            screenWidth - sideWidth - windowWidth)
    end

    win.dockSide = "centre"
    if win.width ~= windowWidth then win:setWidth(windowWidth) end
    if win.x ~= screenLeft + sideWidth then win:setX(screenLeft + sideWidth) end
    local y = page:getY()
    if win.y ~= y then win:setY(y) end
    return true
end

function EquipDock.dockTo(win, page)

    if win.preferredWidth ~= nil and win.width ~= win.preferredWidth then
        win:setWidth(win.preferredWidth)
    end
    local left, top = screenOrigin(win.playerNum)
    local x = page:getX() - win.width + 1
    local y = page:getY()
    if x >= left then
        win.dockSide = "left"
    else
        local above = page:getY() - win.height + 1
        if above >= top then

            win.dockSide, x, y = "above", page:getX(), above
        else

            win.dockSide, x, y = "above", page:getX(), top
        end
    end
    if win.x ~= x then win:setX(x) end
    if win.y ~= y then win:setY(y) end
end

return EquipDock
