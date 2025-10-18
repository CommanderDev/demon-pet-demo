--!strict

--[[
    Description: Resolves UI_Class spec-separated names into a mergeed
    Supports namespaced presets in UI/Presets (e.g., "Buttons/Primary)
]]

local Root = script.Parent.Parent
local PresetsFolder = Root:WaitForChild("Presets")

local Types = require(Root.Core.Types)
local Params = require(Root.Core.Params)

type Preset = Types.Preset

local PresetRegistry = {}
PresetRegistry.__index = PresetRegistry

local Cache: {[string]: PresetModule | false} = {}
local Warned: {[string]: boolean} = {}

local function split(path: string): {string}
	local parts = {}
	for seg in string.gmatch(path, "([^/]+)") do
		table.insert(parts, seg)
	end
	return parts
end

local function findModule(path: string): ModuleScript?
	local cur: Instance = PresetsFolder
	for _, seg in ipairs(split(path)) do
		local n = cur:FindFirstChild(seg)
		if not n then return nil end
		cur = n
	end
	return cur:IsA("ModuleScript") and cur or nil
end

local function load(path: string): Preset?
	if Cache[path] ~= nil then
		return (Cache[path] or nil) :: Preset?
	end
	local mod = findModule(path)
	if not mod then
		if not Warned[path] then
			Warned[path] = true
			warn(string.format("[UI] Preset '%s' not found under NovaUI/Presets", path))
		end
		Cache[path] = false
		return nil
	end
	local ok, def = pcall(require, mod)
	if not ok or type(def) ~= "table" then
		warn(string.format("[UI] Failed requiring preset '%s': %s", path, tostring(def)))
		Cache[path] = false
		return nil
	end
	local preset: Preset = {
		behaviors = (def.behaviors and table.clone(def.behaviors)) or {},
		params    = (def.params and table.clone(def.params)) or {},
	}
	Cache[path] = preset
	return preset
end

local function dedupe(list: {string}): {string}
	local out, seen = {}, {}
	for _, name in ipairs(list) do
		if not seen[name] then
			seen[name] = true
			table.insert(out, name)
		end
	end
	return out
end

-- classes: {"PrimaryButton}, "Large") or with namespaces {"Buttons/Primary}, Buttons/Large}

function PresetRegistry.Resolve(classes: {string}): Preset
    local accBehaviors: {string} = {}
    local accParams: {[string]: any} = {}

    for _, class in ipairs(classes) do
        local p =load(class)
        if p then 
            for _, behavior in ipairs(p.behaviors) do
                table.insert(accBehaviors, behavior)
            end

            accParams = Params.merge(accParams, p.params or {})
        end
    end

    return {
        behaviors = dedupe(accBehaviors),
        params = accParams
    }
end

return PresetRegistry