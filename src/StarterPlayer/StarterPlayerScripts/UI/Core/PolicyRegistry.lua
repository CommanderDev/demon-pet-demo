--!strict

--[[
    Description: Loads group policy modules by name, with a safe default ("Mutex")
]]

local Root = script.Parent.Parent
local PoliciesFolder = Root:WaitForChild("Policies")

local Types = require(Root.Core.Types)

type PolicyModule = Types.PolicyModule

local PolicyRegistry = {}
PolicyRegistry.__index = PolicyRegistry

local Cache: {[string]: PolicyModule | false} = {}
local Warned: {[string]: boolean} = {}
local DEFAULT = "Mutex"

local function findModule(name: string): ModuleScript?
	local cur: Instance = PoliciesFolder
	for seg in string.gmatch(name, "([^/]+)") do
		local n = cur:FindFirstChild(seg)
		if not n then return nil end
		cur = n
	end
	return cur:IsA("ModuleScript") and cur or nil
end

local function load(name: string): PolicyModule?
	if Cache[name] ~= nil then
		return (Cache[name] or nil) :: PolicyModule?
	end
	local mod = findModule(name)
	if not mod then
		if not Warned[name] then
			Warned[name] = true
			warn(string.format("[UI] Policy '%s' not found; falling back to '%s'", name, DEFAULT))
		end
		Cache[name] = false
		return nil
	end
	local ok, lib = pcall(require, mod)
	if not ok or type(lib) ~= "table" then
		warn(string.format("[UI] Failed requiring policy '%s': %s", name, tostring(lib)))
		Cache[name] = false
		return nil
	end
	Cache[name] = (lib :: any)
	return lib
end

function PolicyRegistry.Get(name: string?): PolicyModule
    local chosen = name or DEFAULT
    local lib = load(chosen)
    if lib then return lib end
    local def = load(DEFAULT)
	assert(def, string.format("[UI] Default policy '%s' missing", DEFAULT))
    return def
end

return PolicyRegistry