-- ZoneManager
-- Author(s): Jesse Appleton
-- Date 2025/09/23

local Common = require(game.ReplicatedStorage.Common)
local len, routine, wait = Common.len, Common.routine, Common.wait

local Zones = require(game.ReplicatedStorage.GameData.SpawnZones)

local AmbientSpawner = require(game.ServerScriptService.Entities.AmbientSpawner)

local ServerMod = require(game.ServerScriptService.ServerMod)

local ZoneManager = {
	_spawners = {},
}

function ZoneManager:init()
	self:createSpawner("DemonCampus")
end

function ZoneManager:createSpawner(zoneName: string): ()
	local zonesData = Zones[zoneName]
	local spawner = AmbientSpawner.new(zonesData)
	table.insert(self._spawners, spawner)
end

function ZoneManager:tick(dt)
	for _, spawner in pairs(self._spawners) do
		spawner:tick(dt)
	end
end

return ZoneManager
