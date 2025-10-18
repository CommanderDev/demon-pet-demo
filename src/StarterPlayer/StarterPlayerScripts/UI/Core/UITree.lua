--!strict

local UITree = {}

local Root = script.Parent.Parent
local Types = require(Root.Core.Types)
local Maid = require(Root.Core.Maid)
local Signal = require(Root.Core.Signal)
local Params = require(Root.Core.Params)

local PresetRegistry = require(Root.Core.PresetRegistry)
local BehaviorRegistry = require(Root.Core.BehaviorRegistry)
local PolicyRegistry = require(Root.Core.PolicyRegistry)

local UpdateHub = require(Root.Core.UpdateHub)
local HotkeyRouter = require(Root.Core.HotkeyRouter)
local ZIndexManager = require(Root.Core.ZIndexManager)
local Transactions = require(Root.Core.Transactions)

type Node = Types.Node
type Tree = Types.Tree

local UITree = {}
UITree.__index = UITree

local function strAttr(instance: Instance, key: string): string?
	local value: string? = instance:GetAttribute(key)
	if typeof(value) == "string" then
		return value
	end
	return nil
end

local function boolAttr(inst: Instance, key: string, default: boolean?): boolean
	local v = inst:GetAttribute(key)
	if typeof(v) == "boolean" then
		return v
	end
	return default == true
end

local function eachSpace(s: string): { string }
	local out = {}
	for tok in string.gmatch(s, "([^%s]+)") do
		table.insert(out, tok)
	end
	return out
end

local function findMenuAncestor(inst: Instance): GuiObject?
	local cur = inst
	while cur and cur:IsA("GuiObject") do
		if cur:GetAttribute("UI_Node") and ((strAttr(cur, "UI_Kind") or "panel"):lower() == "menu") then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

local function newNode(instance: GuiObject, parent: Node?, tree: Tree): Node
	local node: any = {}
	node.Tree = tree
	node.Instance = instance
	node.Key = strAttr(instance, "UI_Key") or instance.Name
	node.Kind = (strAttr(instance, "UI_Kind") or "panel") :: any
	node.Group = strAttr(instance, "UI_Group")
	node.PolicyName = strAttr(instance, "UI_GroupPolicy")

	node.Parent = parent
	node.Children = {}
	node.Open = false
	node.Maid = Maid.new()
	node._behState = { locks = {} }
	node._behHandles = nil
	node.Controller = nil

	function node:Tick(fn, opts): ()
		local d = UpdateHub.Add("tick", self, fn, opts or {})
		self.Maid:GiveTask(d)
	end

	function node:Render(fn, opts): ()
		local d = UpdateHub.Add("render", self, fn, opts or {})
		self.Maid:GiveTask(d)
	end

	function node:TickSecond(fn, opts): ()
		local d = UpdateHub.Add("second", self, fn, opts or {})
		self.Maid:GiveTask(d)
	end

	function node:Lock(prop: string, owner: string, priority: number): boolean
		local cur = self._behState.locks[prop]
		if not cur or (priority or 0) >= cur.priority then
			self._behState.locks[prop] = { owner = owner, priority = priority or 0 }
			return true
		end
		return false
	end

	function node:Unlock(prop: string, owner: string): ()
		local cur = self._behState.locks[prop]
		if cur and cur.owner == owner then
			self._behState.locks[prop] = nil
		end
	end

	return (node :: any) :: Node
end

-- Class/Preset --

local function resolvePreset(instance: Instance)
	local classesAttr = strAttr(instance, "UI_Class")
	local classes = {}
	if classesAttr and classesAttr ~= "" then
		classes = eachSpace(classesAttr)
	end
	return PresetRegistry.Resolve(classes) -- { behaviors, params}
end

local function resolveBehaviorsForNode(
	instance: Instance,
	parentBehaviors: { string }?
): ({
	inherited: { string }?,
	preset: { string }?,
	overrides: string,
}, { string })
	local inherit = boolAttr(instance, "UI_InheritBehaviors", true)
	local inherited = inherit and (parentBehaviors or {}) or {}

	local preset = resolvePreset(instance).behaviors or {}
	local overrides = strAttr(instance, "UI_Behaviors")
	local bundle = {
		inheritted = inherited,
		preset = preset,
		overrides = overrides,
	}

	local final = BehaviorRegistry.ResolveList(bundle)

	return bundle, final
end

-- UITree Core ---

function UITree.new(playerGui: PlayerGui): Tree
	local self: any = setmetatable({}, UITree)
	self.PlayerGui = playerGui
	self.RootNodes = {}
	self.Index = {}
	self.Groups = {}
	self._stacks = {} -- Used by stack policy if needed

	self._globalMaid = Maid.new()
	self.Changed = Signal.new()

	self._subscriptions = {}

	self._hotkeys = HotkeyRouter.new(self)

	self._tx = Transactions.new()
	for _, screenGui in ipairs(playerGui:GetChildren()) do
		if screenGui:IsA("ScreenGui") then
			self:_scanScreenGui(screenGui)
		end
	end

	self._globalMaid:GiveTask(playerGui.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") then
			self:_scanScreenGui(child)
		end
	end))

	for _, node in pairs(self.Index) do
		local startOpen = node.Instance:GetAttribute("StartOpen")
		if typeof(startOpen) == "boolean" and startOpen then
			self:_applyOpen(node, true, true)
		else
			if (string.lower(node.Kind) == "menu") or (string.lower(node.Kind) == "overlay") then
				self:_applyOpen(node, false, true)
			end
		end
	end

	return (self :: any) :: Tree
end

-- Scan a ScreenGui and create nodes for descendants with UI_Node=true

function UITree:_scanScreenGui(screenGui: ScreenGui): ()
	local instanceToNode: { [Instance]: Node } = setmetatable({}, { __mode = "k" })

	local function create(instance: Instance): ()
		if not (instance:IsA("GuiObject") and instance:GetAttribute("UI_Node")) then
			return
		end

		local parentInstance = instance.Parent
		local parentNode = parentInstance and instanceToNode[parentInstance]

		if
			not parentNode
			and parentInstance
			and parentInstance:IsA("GuiObject")
			and parentInstance:GetAttribute("UI_Node")
		then
			create(parentInstance)
			parentNode = instanceToNode[parentInstance]
		end

		local node = newNode(instance, parentNode, self)
		local preset = resolvePreset(instance)
		local parentParams = parentNode and parentNode.Params or nil
		node.Params = Params.resolve(parentParams, preset.params or {}, instance:GetAttribute("UI_Params"), instance)

		local controllerName = strAttr(instance, "UI_Controller")
		if controllerName and controllerName ~= "" then
			local controllers = Root:FindFirstChild("Controllers")
			local mod: ModuleScript? = nil
			if controllers then
				mod = controllers:FindFirstChild(controllerName, true) :: ModuleScript?
			end
			if mod and mod:IsA("ModuleScript") then
				local ok, controllerClass = pcall(require, mod)
				if ok and type(controllerClass) == "table" then
					-- Create a new instance for this node using setmetatable
					local controllerInstance = setmetatable({}, controllerClass)
					node.Controller = controllerInstance
					if controllerClass.Init then
						local ok2, err = pcall(controllerClass.Init, controllerInstance, node, self)
						if not ok2 then
							warn(string.format("[UI] Controller '%s' Init error: %s", controllerName, tostring(err)))
						end
					end
				end
			end
		end
		-- Register in tree
		instanceToNode[instance] = node
		self.Index[node.Key] = node
		if parentNode then
			table.insert(parentNode.Children, node)
		else
			table.insert(self.RootNodes, node)
		end

		-- Group map
		if node.Group then
			self.Groups[node.Group] = self.Groups[node.Group] or {}
			self.Groups[node.Group][node.Key] = node
		end

		-- Behaviors
		local parentBehaviors = (parentNode :: any) and (parentNode :: any)._finalBehaviors or nil
		local bundle, finalList = resolveBehaviorsForNode(instance, parentBehaviors)
		node._finalBehaviors = finalList
		BehaviorRegistry.AttachForNode(node, bundle)

		self:_wireActionOn(instance)

		node.Maid:TieToInstance(instance)
	end

	for _, d in ipairs(screenGui:GetDescendants()) do
		create(d)
		self:_wireActionOn(d)
	end

	self._globalMaid:GiveTask(screenGui.DescendantAdded:Connect(function(d)
		create(d)
		self:_wireActionOn(d)
	end))

	self._globalMaid:GiveTask(screenGui.DescendantRemoving:Connect(function(d)
		local node = instanceToNode[d]
		if node then
			BehaviorRegistry.DetachAll(node)
			self.Index[node.Key] = nil
			if node.Group and self.Groups[node.Group] then
				self.Groups[node.Group][node.Key] = nil
			end

			if node.Controller and node.Controller.OnDestroy then
				pcall(node.Controller.OnDestroy, node.Controller)
			end

			if node.Parent then
				for index = #node.Parent.Children, 1, -1 do
					if node.Parent.Children[index] == node then
						table.remove(node.Parent.Children, index)
						break
					end
				end
			else
				for index = #self.RootNodes, 1, -1 do
					if self.RootNodes[index] == node then
						table.remove(self.RootNodes, index)
						break
					end
				end
			end
			node.Maid:DoCleaning()
			instanceToNode[d] = nil
		end
	end))
end

function UITree:_wireActionOn(instance: Instance): ()
	if not instance:IsA("GuiObject") then
		return
	end
	local action = strAttr(instance, "UI_Action")
	if not action then
		return
	end
	if not instance:IsA("GuiButton") then
		return
	end

	instance.Activated:Connect(function()
		local cmd, arg = string.match(action, "([^:]+):?(.*)")
		cmd = string.lower(cmd or "")
		arg = arg or ""
		if cmd == "open" then
			self:Open(arg)
		elseif cmd == "close" then
			if arg == "self" then
				local menuRoot = findMenuAncestor(instance)
				if menuRoot then
					local key = strAttr(menuRoot, "UI_Key") or menuRoot.Name
					self:Close(key)
				end
			else
				self:Close(arg)
			end
		elseif cmd == "toggle" then
			self:Toggle(arg)
		end
	end)
end

function UITree:_findOrCreateSubscription(key: string): { signal: Signal, connections: { Connection } }
	local subscription = self._subscriptions[key]
	if not subscription then
		subscription = {
			signal = Signal.new(),
			connections = {},
		}
		self._subscriptions[key] = subscription
	end
	return subscription
end
-- Transactions

function UITree:Begin(): ()
	self._tx:Begin()
end

function UITree:Commit(): ()
	self._tx:Commit()
end

function UITree:Rollback(): ()
	self._tx:Rollback()
end

function UITree:Publish(key: string, payload): boolean
	local subscription = self:_findOrCreateSubscription(key)
	subscription.signal:Fire(payload)
	return true
end

function UITree:Subscribe(key: string, callback: (payload: any) -> ()): Connection
	local subscription = self:_findOrCreateSubscription(key)
	local connection = subscription.signal:Connect(callback)
	table.insert(subscription.connections, connection)
	return connection
end

function UITree:_applyOpen(node: Node, open: boolean, instant: boolean?): ()
	if node.Open == open then
		return
	end

	if open and node.Group then
		local policy = PolicyRegistry.Get(node.PolicyName)
		if policy and policy.onOpen then
			pcall(policy.onOpen, self, node)
		end
	end

	node.Open = open

	self._tx:Enqueue(function()
		if string.lower(node.Kind) == "menu" or string.lower(node.Kind) == "overlay" then
			node.Instance.Visible = open
			if open then
				ZIndexManager.BringToFront(node)
			end
		end
	end)

	-- Skip controller and policy callbacks during initialization (instant=true)
	if not instant then
		if open then
			if node.Controller and node.Controller.OnOpen then
				pcall(node.Controller.OnOpen, node.Controller)
			end
		else
			if node.Controller and node.Controller.OnClose then
				pcall(node.Controller.OnClose, node.Controller)
			end
			if node.Group then
				local policy = PolicyRegistry.Get(node.PolicyName)
				if policy and policy.onClose then
					pcall(policy.onClose, self, node)
				end
			end
		end
	end

	self.Changed:Fire(node)
end

function UITree:Open(key: string, data: any?): ()
	local node = self.Index[key]
	if not node then
		return
	end
	self:_applyOpen(node, true, false)
	if data ~= nil and node.Controller and node.Controller.OnOpen then
		pcall(node.Controller.OnOpen, node.Controller, data)
	end
end

function UITree:Close(key: string): ()
	local node = self.Index[key]
	if not node then
		return
	end
	self:_applyOpen(node, false, false)
end

function UITree:Toggle(key: string): ()
	local node = self.Index[key]
	if not node then
		return
	end
	self:_applyOpen(node, not node.Open, false)
end

function UITree:Get(key: string): Node?
	return self.Index[key]
end

function UITree:SetParams(scopeKey: string, k: string, v: any, includeDescendants: boolean?): ()
	local function applyTo(node: Node): ()
		local prev = node.Params[k]
		if prev == v then
			return
		end
		node.Params[k] = v
		if node.Controller and node.Controller.OnParamChanged then
			pcall(node.Controller.OnParamChanged, node.Controller, k, v)
		end
		self.Changed:Fire(node)
		if includeDescendants ~= false then
			for _, child in ipairs(node.Children) do
				self:SetParam(child.Key, k, v, true)
			end
		end
	end

	if string.sub(scopeKey, 1, 7) == "@group:" then
		local groupName = string.sub(scopeKey, 8)
		for _, node in pairs(self.Groups[groupName] or {}) do
			applyTo(node)
		end
	else
		local node = self.Index[scopeKey]
		if node then
			applyTo(node)
		end
	end
end

return UITree
