--[[
    Description: Maps effect ids -> { class = <EffectClass>, defaults = <table> }
]]

local Registry = {}
local _map: { [string]: { class: any, defaults: table } } = {}

function Registry.Register(id: string, class: any, defaults: table?)
	_map[id] = { class = class, defaults = defaults or {} }
end

function Registry.Unregister(id: string): boolean
	if _map[id] then
		_map[id] = nil
		return true
	end

	return false
end

function Registry.Get(id: string)
	return _map[id]
end

function Registry.Exists(id: string): boolean
	return _map[id] ~= nil
end

function Registry.List(): { string }
	local out = {}
	for id, _ in pairs(_map) do
		table.insert(out, id)
	end
	return out
end

local function clone(t: { [any]: any }): { [any]: any }
	if not t then
		return {}
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return c
end

function Registry.MergeDefaults(id: string, context: { [any]: any }): table
	local entry = _map[id]
	local merged = {}

	-- start with defaults
	if entry then
		for k, v in pairs(entry.defaults) do
			if k == "params" and type(v) == "table" then
				merged.params = clone(v)
			else
				merged[k] = v
			end
		end
	end

	context = context or {}
	for k, v in pairs(context) do
		if k == "params" and type(v) == "table" then
			merged.params = merged.params or {}
			for pk, pv in pairs(v) do
				merged.params[pk] = pv
			end
		else
			merged[k] = v
		end
	end

	return merged
end

return Registry
