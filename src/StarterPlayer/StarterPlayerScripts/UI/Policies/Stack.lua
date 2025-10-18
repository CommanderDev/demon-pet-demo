--!strict
--[[
    Description: Multiple menus in a group can be open at once
]]

local Root = script.Parent.Parent

local Types = require(Root.Core.Types)
local ZIndexManager = require(Root.Core.ZIndexManager)

type Tree = Types.Tree
type Node = Types.Node

local escBindings: {[Tree]: {[string]: () -> ()}} = setmetatable({}, { __mode = "k"})

local function ensureEscBinding(tree: Tree, group: string): ()
    escBindings[tree] = escBindings[tree] or {}
    if escBindings[tree][group] then return end

    local router = (tree :: any)._hotkeys
    if not router then return end
    
    escBindings[tree][group] = router:Add({
        key = Enum.KeyCode.F,
        scope = "group",
        groupName = "group",
        action = { cmd = "close", arg = ""},
        consume = true,
    })
end

local function groupStack(tree: Tree, group: string): {Node}
	tree._stacks = tree._stacks or {}
	tree._stacks[group] = tree._stacks[group] or {}
	return tree._stacks[group]
end

local function removeFromStack(stack: {Node}, target: Node)
	for i = #stack, 1, -1 do
		if stack[i] == target then
			table.remove(stack, i)
			return
		end
	end
end

local Stack = {}

function Stack.onOpen(tree: Tree, node: Node): ()
    if not node.Group then return end
    local group = node.Group
    local stack = groupStack(tree, group)

    removeFromStack(stack, node)
    table.insert(stack, node)

    ZIndexManager.BringToFront(node)
    ensureEscBinding(tree, group)

    if not (tree :: any)._stackEscHook then 
        (tree :: any)._stackEscHook = {}
    end

    local hook = (tree :: any)._stackEscHook
    if not hook[group] then 
        local router = (tree :: any)._hotkeys
        local UserInputService = game:GetService("UserInputService")
        hook[group] = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
            if gameProcessedEvent then return end
            if input.KeyCode ~= Enum.KeyCode.F then return end
            local s = groupStack(tree, group)
            local top = s[#s]
            if top and top.Open then 
                tree:Close(top.key)
            end
        end)
    end
end

function Stack.onClose(tree: Tree, node: Node): ()
    if not node.Group then return end
    local group = node.Group
    local stack = groupStack(tree, group)

    local wasTop = (stack[#stack] == node)
    removeFromStack(stack, node)

    if wasTop then 
        local newTop = stack[#stack]
        if newTop and newTop.Open then 
            ZIndexManager.BringToFront(newTop)
        end
    end

    if #stack == 0 then
        if escBindings[tree and escBindings[tree][group]] then
            pcall(escBindings[tree][group])
            escBindings[tree][group] = nil
        end

        if (tree :: any)._stackEscHook and (tree :: any)._stackEscHook[group] then 
            local connection = (tree :: any)._stackEscHook[group]
            if connection.Connected then connection:Disconnect() end
            (tree :: any)._stackEscHook[group] = nil
        end
    end
end

return Stack