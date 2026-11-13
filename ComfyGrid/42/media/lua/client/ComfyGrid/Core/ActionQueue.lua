--[[
    Comfy Grid - Tile Inventory [B42]
    Author:  Darkeng
    Version: 1.10.1
    GitHub:  https://github.com/darkeng
    Steam:   https://steamcommunity.com/id/_darkeng_
]]

require "ComfyGrid/ComfyGrid"

ComfyGrid = ComfyGrid or {}
ComfyGrid.Core = ComfyGrid.Core or {}
local ActionQueue = {}
ComfyGrid.Core.ActionQueue = ActionQueue

function ActionQueue.queuedActions(character)
    if character == nil or ISTimedActionQueue == nil then return nil end
    local queues = ISTimedActionQueue.queues
    local characterQueue = queues ~= nil and queues[character] or nil
    return characterQueue ~= nil and characterQueue.queue or nil
end

function ActionQueue.runningAction(character)
    local actions = ActionQueue.queuedActions(character)
    return actions ~= nil and actions[1] or nil
end

return ActionQueue
