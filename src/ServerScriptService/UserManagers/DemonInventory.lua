local InventoryHelper = require(game.ReplicatedStorage.Helpers.InventoryHelper)

local Enums = require(game.ReplicatedStorage.Enums)

local DemonInventory = {}
DemonInventory.__index = DemonInventory

function DemonInventory.new(user)
	local self = setmetatable({}, DemonInventory)

	self.user = user

	return self
end

function DemonInventory:init(user)
	self:loadState()
	self:addDemon({
		name = "WATER_HOUND",
		level = 10,
		_equipped = true,
	})
	self:addDemon({
		name = "WATER_HOUND",
		level = 100,
		_equipped = true,
	})

	self:addDemon({
		name = "WATER_HOUND",
		level = 100,
		_equipped = true,
	})
	self:addDemon({
		name = "WATER_HOUND",
		level = 10,
		_equipped = true,
	})
end

function DemonInventory:addDemon(demonData)
	local _, entry = InventoryHelper.AddToInventory(self.data.demons, demonData)
end

function DemonInventory:getEquippedDemons(): { any }
	return InventoryHelper.GetInventoryEntriesWithFilter(self.data.demons, {
		_equipped = true,
	})
end

function DemonInventory:getDefaultState(): { any }
	return {
		demons = {},
	}
end

function DemonInventory:loadState()
	self.data = self.user.store:get(self.moduleAlias .. "Info") or self:getDefaultState()
end

function DemonInventory:saveState()
	self.user.store:set(self.moduleAlias .. "Info", self.data)
end

return DemonInventory
