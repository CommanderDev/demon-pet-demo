--!strict

--[[
    Description: Centralizes all key/gamepad bindings
]]
    
local UserInputService = game:GetService("UserInputService")

local HotkeyRouter = {}
HotkeyRouter.__index = HotkeyRouter

export type Binding = {
    key: Enum.KeyCode | Enum.UserInputType,
    action: { cmd: "open" | "close" | "toggle", arg: string},
    scope: "global" | "node" | "group",
    targetKey: string?,
    groupName: string?,
    requireOpen: boolean?,
    consume: boolean?,
}

type BindingEntry = Binding & {dead: boolean?}

function HotkeyRouter.new(tree: any)
    local self = setmetatable({
        _tree = tree,
        _list = {} :: {BindingEntry},
        _conn = nil :: RBXScriptConnection?,
    }, HotkeyRouter)

    self._connection = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end
        self:_handleInput(input)
    end)
end

function HotkeyRouter:_handleInput(input: InputObject)
	local keyCode = input.KeyCode
	local inputType = input.UserInputType

	for i = #self._list, 1, -1 do
		local b = self._list[i]
		if b.dead then
			table.remove(self._list, i)
		else
			local hit =
				(typeof(b.key) == "EnumItem" and b.key.EnumType == Enum.KeyCode and keyCode == b.key)
				or (typeof(b.key) == "EnumItem" and b.key.EnumType == Enum.UserInputType and inputType == b.key)

			if hit then
				self:_runBinding(b)
			end
		end
	end
end

function HotkeyRouter:_runBinding(b: Binding)
	local tree = self._tree
	local cmd = b.action.cmd
	local arg = b.action.arg

	if b.scope == "node" then
		local node = tree:Get(b.targetKey or arg)
		if not node then return end
		if b.requireOpen and not node.Open then return end
		if cmd == "open" then tree:Open(node.Key)
		elseif cmd == "close" then tree:Close(node.Key)
		elseif cmd == "toggle" then tree:Toggle(node.Key) end
	elseif b.scope == "group" then
		if cmd == "open" then tree:Open(arg)
		elseif cmd == "close" then tree:Close(arg)
		elseif cmd == "toggle" then tree:Toggle(arg) end
	else -- global
		if cmd == "open" then tree:Open(arg)
		elseif cmd == "close" then tree:Close(arg)
		elseif cmd == "toggle" then tree:Toggle(arg) end
	end
end

function HotkeyRouter:Add(binding: Binding): () -> ()
    local entry: BindingEntry = table.clone(binding) :: any
    table.insert(self._list, entry)
    return function() entry.dead = true end
end

function HotkeyRouter:Destroy(): ()
    for index = #self._list, 1, -1 do
        self._list[index].dead = true
        table.remove(self._list, index)
    end
    if self._connection then 
        self._connection:Disconnect()
        self._connection = nil
    end
end

return HotkeyRouter