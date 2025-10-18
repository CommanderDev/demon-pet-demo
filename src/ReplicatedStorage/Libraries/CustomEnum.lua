--!strict
-- CustomEnum.lua
-- Create Roblox-style enums with nice tostring and quick lookups.

local CustomEnum = {}
CustomEnum.__index = CustomEnum

export type EnumItem = {
	Name: string,
	Value: number,
	EnumType: any,
}

-- Internal metatable for individual enum items
local EnumItemMT = {}
EnumItemMT.__index = EnumItemMT
function EnumItemMT:__tostring()
	-- Example: Enum.PartyOrders.FOLLOW
	local enumType = (self :: any).EnumType
	local typeName = enumType and enumType.__name or "Unknown"
	return ("Enum.%s.%s"):format(typeName, (self :: any).Name)
end

-- Metatable for an EnumType object
local EnumTypeMT = {}
EnumTypeMT.__index = EnumTypeMT

function EnumTypeMT:__tostring()
	return ("Enum.%s"):format((self :: any).__name)
end

-- Luau: allow `pairs(MyEnum)` to iterate items in ascending Value
function EnumTypeMT:__iter()
	local selfTbl = self :: any
	local items = selfTbl.__itemsOrdered
	local i = 0
	return function()
		i += 1
		local v = items[i]
		if v then
			return v
		end
		return nil
	end
end

-- Fallback for vanilla Lua iteration (works in Luau too)
function EnumTypeMT.__pairs(selfTbl)
	-- Iterate key = Name, value = EnumItem
	local list = selfTbl.__itemsOrdered
	local i = 0
	return function()
		i += 1
		local item = list[i]
		if item then
			return item.Name, item
		end
		return nil
	end
end

-- === Public EnumType API ===

function EnumTypeMT:GetName(): string
	return (self :: any).__name
end

function EnumTypeMT:GetEnumItems(): { EnumItem }
	return (self :: any).__itemsOrdered
end

function EnumTypeMT:FromName(name: string): EnumItem?
	return (self :: any).__byName[name]
end

function EnumTypeMT:FromValue(value: number): EnumItem?
	return (self :: any).__byValue[value]
end

-- Indexing sugar:
--   MyEnum.RED  -> EnumItem
--   MyEnum[1]   -> EnumItem (by numeric value)
function EnumTypeMT:__index(key)
	local selfTbl = rawget(EnumTypeMT, key)
	if selfTbl ~= nil then
		return selfTbl
	end

	local store = self :: any
	if typeof(key) == "string" then
		local item = store.__byName[key]
		if item then
			return item
		end
	elseif typeof(key) == "number" then
		local item = store.__byValue[key]
		if item then
			return item
		end
	end

	return rawget(EnumTypeMT, key)
end

-- Prevent accidental writes
function EnumTypeMT:__newindex()
	error("Enum types are read-only", 2)
end

-- === Factory ===

type CreateOptions = {
	startAt: number?, -- default 0, used if values aren’t provided
	freeze: boolean?, -- default true
}

local function makeEnumItem(name: string, value: number, enumType: any): EnumItem
	local obj = table.freeze(setmetatable({
		Name = name,
		Value = value,
		EnumType = enumType,
	}, EnumItemMT))
	return obj :: any
end

-- Accepts either:
-- 1) Array style: { "IDLE", "MOVE", "ATTACK" }             -- auto values
-- 2) Map style:   { IDLE = 0, MOVE = 1, ATTACK = 2 }       -- explicit values
-- 3) Mixed/objects ignored except string/number pairs/entries
function CustomEnum.create(name: string, def: any, options: CreateOptions?): any
	options = options or {}
	local startAt = options.startAt
	if startAt == nil then
		startAt = 0
	end
	local freeze = options.freeze
	if freeze == nil then
		freeze = true
	end

	local byName: { [string]: EnumItem } = {}
	local byValue: { [number]: EnumItem } = {}
	local itemsOrdered: { EnumItem } = {}

	local assigned = startAt - 1

	local function add(nameStr: string, valueNum: number)
		if byName[nameStr] then
			error(("Duplicate enum name '%s' in Enum.%s"):format(nameStr, name), 2)
		end
		if byValue[valueNum] then
			error(("Duplicate enum value %d in Enum.%s"):format(valueNum, name), 2)
		end
		local placeholder = {} :: any -- temporary, EnumType filled after table exists
		local item = makeEnumItem(nameStr, valueNum, placeholder)
		byName[nameStr] = item
		byValue[valueNum] = item
		table.insert(itemsOrdered, item)
	end

	if #def > 0 then
		-- Array style (auto-assign)
		for i = 1, #def do
			local entry = def[i]
			if typeof(entry) == "string" then
				assigned += 1
				add(entry, assigned)
			elseif typeof(entry) == "table" and typeof(entry.name) == "string" then
				-- Optional { name = "IDLE", value = 7 }
				local v = entry.value
				if typeof(v) ~= "number" then
					assigned += 1
					v = assigned
				end
				add(entry.name, v)
			end
		end
	else
		-- Map style (explicit)
		for k, v in pairs(def) do
			if typeof(k) == "string" and typeof(v) == "number" then
				add(k, v)
			end
		end
	end

	table.sort(itemsOrdered, function(a, b)
		return a.Value < b.Value
	end)

	local enumType = setmetatable({
		__name = name,
		__byName = byName,
		__byValue = byValue,
		__itemsOrdered = itemsOrdered,
	}, EnumTypeMT)

	-- Patch EnumType references now that enumType exists
	for i = 1, #itemsOrdered do
		local item = itemsOrdered[i] :: any
		-- Recreate with correct EnumType reference
		itemsOrdered[i] = setmetatable({
			Name = item.Name,
			Value = item.Value,
			EnumType = enumType,
		}, EnumItemMT)
		byName[item.Name] = itemsOrdered[i]
		byValue[item.Value] = itemsOrdered[i]
		table.freeze(itemsOrdered[i])
	end

	if freeze then
		table.freeze(byName)
		table.freeze(byValue)
		table.freeze(itemsOrdered)
		table.freeze(enumType)
	end

	return enumType
end

return CustomEnum
