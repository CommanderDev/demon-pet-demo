--!strict

--[[
    Description: Per-Screengui layer allocator to bring nodes to front 
    And assign base layers per group.
]]

local ZIndexManager = {}
ZIndexManager.__index = ZIndexManager

type LayerState = {
    counter: number,
    groupBase: {[string]: number},
}

local screenState: {[ScreenGui]: LayerState} = setmetatable({}, { __mode = "k"})

local function getState(screenGui: ScreenGui): LayerState
    local state = screenState[screenGui]
    if not state then 
        state = { counter = 10, groupBase = {} }
        screenState[screenGui] = state
    end
    return state
end

--- PUBLIC API ---

-- Set the base ZIndex for a group within a ScreenGui
function ZIndexManager.SetLayerBase(screenGui: ScreenGui, groupName: string, base: number): ()
    local state = getState(screenGui)
    state.groupBase[groupName] = base
end

-- Bring a node to the front relative to its ScreenGui
-- Returns the assigned ZIndex

function ZIndexManager.BringToFront(node: any): number
    local instance: GuiObject = node.Instance
    local screenGui: ScreenGui = instance:FindFirstAncestorOfClass("ScreenGui")
    if not screenGui then 
        return instance.ZIndex
    end

    local state = getState(screenGui)
    state.counter += 1
    local base = state.groupBase[node.Group or ""] or 0
    local newZ = base + state.counter
    instance.ZIndex = newZ
    return newZ
end

return ZIndexManager
