-- Janitor
-- Stephen Leitnick
-- October 16, 2021

local FN_MARKER = newproxy()

local RunService = game:GetService("RunService")

local function GetObjectCleanupFunction(object, cleanupMethod)
	local t = typeof(object)
	if t == "function" then
		return FN_MARKER
	end
	if cleanupMethod then
		return cleanupMethod
	end
	if t == "Instance" then
		return "Destroy"
	elseif t == "RBXScriptConnection" then
		return "Disconnect"
	elseif t == "table" then
		if typeof(object.Destroy) == "function" then
			return "Destroy"
		elseif typeof(object.Disconnect) == "function" then
			return "Disconnect"
		end
	end
	error("Failed to get cleanup function for object " .. t .. ": " .. tostring(object))
end

--[=[
	@class Janitor
	A Janitor is helpful for tracking any sort of object during
	runtime that needs to get cleaned up at some point.
]=]
local Janitor = {}
Janitor.__index = Janitor

--[=[
	Constructs a Janitor object.
]=]
function Janitor.new()
	local self = setmetatable({}, Janitor)
	self._objects = {}
	return self
end

--[=[
	@param class table | (...any) -> any
	@param ... any
	@return any
	Constructs a new object from either the
	table or function given.

	If a table is given, the table's `new`
	function will be called with the given
	arguments.

	If a function is given, the function will
	be called with the given arguments.
	
	The result from either of the two options
	will be added to the Janitor.

	```lua
	local Signal = require(somewhere.Signal)

	-- All of these are identical:
	local s = Janitor:Construct(Signal)
	local s = Janitor:Construct(Signal.new)
	local s = Janitor:Construct(function() return Signal.new() end)
	local s = Janitor:Add(Signal.new())

	-- Even Roblox instances can be created:
	local part = Janitor:Construct(Instance, "Part")
	```
]=]
function Janitor:Construct(class, ...)
	local object = nil
	local t = type(class)
	if t == "table" then
		object = class.new(...)
	elseif t == "function" then
		object = class(...)
	end
	return self:Add(object)
end

--[=[
	@param signal RBXScriptSignal
	@param fn (...: any) -> any
	@return RBXScriptConnection
	Connects the function to the signal, adds the connection
	to the Janitor, and then returns the connection.

	```lua
	Janitor:Connect(workspace.ChildAdded, function(instance)
		print(instance.Name .. " added to workspace")
	end)
	```
]=]
function Janitor:Connect(signal, fn)
	return self:Add(signal:Connect(fn))
end

--[=[
	@param name string
	@param priority number
	@param fn (dt: number) -> nil
	Calls `RunService:BindToRenderStep` and registers a function in the
	Janitor that will call `RunService:UnbindFromRenderStep` on cleanup.

	```lua
	Janitor:BindToRenderStep("Test", Enum.RenderPriority.Last.Value, function(dt)
		-- Do something
	end)
	```
]=]
function Janitor:BindToRenderStep(name: string, priority: number, fn: (dt: number) -> nil)
	RunService:BindToRenderStep(name, priority, fn)
	self:Add(function()
		RunService:UnbindFromRenderStep(name)
	end)
end

--[=[
	@param object any -- Object to track
	@param cleanupMethod string? -- Optional cleanup name override
	@return object: any
	Adds an object to the Janitor. Once the Janitor is cleaned or
	destroyed, the object will also be cleaned up.

	The object must be any of the following:
	- Roblox instance (e.g. Part)
	- RBXScriptConnection (e.g. `workspace.ChildAdded:Connect(function() end)`)
	- Function
	- Table with either a `Destroy` or `Disconnect` method
	- Table with custom `cleanupMethod` name provided

	Returns the object added.

	```lua
	-- Add a part to the Janitor, then destroy the Janitor,
	-- which will also destroy the part:
	local part = Instance.new("Part")
	Janitor:Add(part)
	Janitor:Destroy()

	-- Add a function to the Janitor:
	Janitor:Add(function()
		print("Cleanup!")
	end)
	Janitor:Destroy()

	-- Standard cleanup from table:
	local tbl = {}
	function tbl:Destroy()
		print("Cleanup")
	end
	Janitor:Add(tbl)

	-- Custom cleanup from table:
	local tbl = {}
	function tbl:DoSomething()
		print("Do something on cleanup")
	end
	Janitor:Add(tbl, "DoSomething")
	```
]=]
function Janitor:Add(object: any, cleanupMethod: string?): any
	local cleanup = GetObjectCleanupFunction(object, cleanupMethod)
	table.insert(self._objects, { object, cleanup })
	return object
end

--[=[
	@param object any -- Object to remove
	Removes the object from the Janitor and cleans it up.

	```lua
	local part = Instance.new("Part")
	Janitor:Add(part)
	Janitor:Remove(part)
	```
]=]
function Janitor:Remove(object: any): boolean
	local objects = self._objects
	for i, obj in ipairs(objects) do
		if obj[1] == object then
			local n = #objects
			objects[i] = objects[n]
			objects[n] = nil
			self:_cleanupObject(obj[1], obj[2])
			return true
		end
	end
	return false
end

--[=[
	Cleans up all objects in the Janitor. This is
	similar to calling `Remove` on each object
	within the Janitor.
]=]
function Janitor:Clean()
	for _, obj in ipairs(self._objects) do
		self:_cleanupObject(obj[1], obj[2])
	end
	table.clear(self._objects)
end

function Janitor:_cleanupObject(object, cleanupMethod)
	if cleanupMethod == FN_MARKER then
		object()
	else
		object[cleanupMethod](object)
	end
end

--[=[
	@param instance Instance
	@return RBXScriptConnection
	Attaches the Janitor to a Roblox instance. Once this
	instance is removed from the game (parent or ancestor's
	parent set to `nil`), the Janitor will automatically
	clean up.

	:::caution
	Will throw an error if `instance` is not a descendant
	of the game hierarchy.
	:::
]=]
function Janitor:AttachToInstance(instance: Instance)
	assert(instance:IsDescendantOf(game), "Instance is not a descendant of the game hierarchy")
	return self:Connect(instance.AncestryChanged, function(_child, parent)
		if not parent then
			self:Destroy()
		end
	end)
end

--[=[
	Destroys the Janitor object. Forces `Clean` to run.
]=]
function Janitor:Destroy()
	self:Clean()
end

return Janitor
