--!strict

--[[
    Description: Loads & attaches behavior modules by name and computes final behavior lists
    from inherited + preset + DSL overrides
]]

local Root = script.Parent.Parent
local BehaviorsFolder = Root:WaitForChild("Behaviors")

local Types = require(Root.Core.Types)

type Node = Types.Node
type BehaviorHandle = Types.BehaviorHandle
type BehaviorModule = Types.BehaviorModule

local BehaviorRegistry = {}
BehaviorRegistry.__index = BehaviorRegistry

-- Caches
local Cache: {[string]: BehaviorModule | false} = {}
local Warned: {[string]: boolean} = {}

local function trim(s: string): string
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split(path: string): {string}
	local parts = {}
	for seg in string.gmatch(path, "([^/]+)") do
		table.insert(parts, seg)
	end
	return parts
end

local function findModule(folder: Instance, path: string): ModuleScript?
	local cur: Instance = folder
	for _, seg in ipairs(split(path)) do
		local nextChild = cur:FindFirstChild(seg)
		if not nextChild then
			return nil
		end
		cur = nextChild
	end
	if cur:IsA("ModuleScript") then
		return cur
	end
	return nil
end

local function loadBehavior(name: string): BehaviorModule?
	if Cache[name] ~= nil then
		return (Cache[name] or nil) :: BehaviorModule?
	end
	local mod = findModule(BehaviorsFolder, name)
	if not mod then
		if not Warned[name] then
			Warned[name] = true
			warn(string.format("[UI] Behavior '%s' not found under NovaUI/Behaviors", name))
		end
		Cache[name] = false
		return nil
	end
	local ok, lib = pcall(require, mod)
	if not ok or type(lib) ~= "table" then
		warn(string.format("[UI] Failed requiring behavior '%s': %s", name, tostring(lib)))
		Cache[name] = false
		return nil
	end
	Cache[name] = (lib :: any)
	return lib
end

-- Build/Resolve

local function dedupePreserveOrder(list: {string}): {string}
	local out, seen = {}, {}
	for _, name in ipairs(list) do
		if not seen[name] then
			seen[name] = true
			table.insert(out, name)
		end
	end
	return out
end

-- DSL: "+Tooltip -PressDown +Nav/FocusGroup"
local function applyOverrides(base: {string}, dsl: string?): {string}
	if not dsl or dsl == "" then return base end
	local order = {}
	local set = {}
	for _, b in ipairs(base) do
		table.insert(order, b)
		set[b] = true
	end
	for op, name in string.gmatch(dsl, "([%+%-])%s*([^%s,]+)") do
		name = trim(name)
		if op == "+" then
			if not set[name] then
				set[name] = true
				table.insert(order, name)
			end
		else -- '-'
			if set[name] then
				set[name] = nil
				for i = #order, 1, -1 do
					if order[i] == name then
						table.remove(order, i)
						break
					end
				end
			end
		end
	end
	return order
end

local function expandRequires(list: {string}): {string}
	local out, seen = {}, {}

	local function add(name: string)
		if seen[name] then return end
		local lib = loadBehavior(name)
		if lib and lib.Requires then
			for _, req in ipairs(lib.Requires :: {string}) do
				add(req)
			end
		end
		seen[name] = true
		table.insert(out, name)
	end

	for _, name in ipairs(list) do
		add(name)
	end
	return out
end

-- PUBLIC API ---

--[[ Compute the final list before attaching (deterministic order)
    bundle = {
        inherited = {"Hover}
        preset = {"PressDown}, "Hotkey",
        overrides = "+Tooltip -PressDown
    }
}}
]]

function BehaviorRegistry.ResolveList(bundle: {
    inherited: {string}?,
    preset: {string}?,
    overrides: string?,
}): {string}
    local inherited = bundle.inherited or {}
    local preset = bundle.preset or {}
    local merged = {}
    for _, n in ipairs(inherited) do table.insert(merged, n) end
    for _, n in ipairs(preset) do table.insert(merged, n) end
    merged = dedupePreserveOrder(merged)
    merged = applyOverrides(merged, bundle.overrides)
    merged = expandRequires(merged)
    return merged
end

-- Attach/Detach ---

function BehaviorRegistry.AttachForNode(node: Node, bundle: {
    inherited: {string}?,
    preset: {string}?,
    overrides: string?,
}): ()
    local list = BehaviorRegistry.ResolveList(bundle)
    if #list == 0 then return end
    node._behHandles = node._behHandles or {}
    for _, name in ipairs(list) do 
        if node._behHandles[name] then 
            -- Already attached, skip
        else
            local lib = loadBehavior(name)
            if lib and lib.Attach then 
                local handle: BehaviorHandle? = nil
                local ok, res = pcall(lib.Attach, node)
                if not ok then 
					warn(string.format("[UI] Behavior '%s' Attach error: %s", name, tostring(res)))
                else
                    handle = res
                end
                node._behHandles[name] = handle
            end 
        end
    end
end

function BehaviorRegistry.DetachAll(node: Node): ()
    local handles = node._behHandles
    if not handles then return end
    for name, handle in pairs(handles) do 
        local lib = Cache[name]
        if lib and lib ~= false and (lib :: BehaviorModule).Detach then 
            local ok, err = pcall(( lib :: BehaviorModule).Detach, node, handle)
            if not ok then 
                warn(string.format("[UI] Behavior '%s' Detach error: %s", name, tostring(err)))
            end
        else
            if typeof(handle) == "RBXScriptConnection" then
                if (handle :: RBXScriptConnection).Connected then 
                    (handle :: RBXScriptConnection):Disconnect()
                end
            elseif type(handle) == "table" then
                local h = handle :: any
                if type(h.Disconnect) == "function" then
                    h:Disconnect()
                elseif type(h.DoCleaning) == "function" then
                    h:DoCleaning()
                elseif type(h.Destroy) == "function" then
                    h:Destroy()
                end
            end
        end
    end
    node._behHandles = nil
end

return BehaviorRegistry