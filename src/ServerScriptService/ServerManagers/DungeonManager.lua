local DungeonWorld = require(game.ServerScriptService.Entities.DungeonWorld)
local DungeonsData = require(game.ReplicatedStorage.GameData.Dungeons)

local ServerMod = require(game.ServerScriptService.ServerMod)

local ActiveDungeons = Instance.new("Folder")
ActiveDungeons.Name = "ActiveDungeons"
ActiveDungeons.Parent = workspace

local DungeonManager = {
	_worlds = {} :: { [string]: any },
}

function DungeonManager:getWorld(dungeonId: string)
	return self._worlds[dungeonId]
end

function DungeonManager:getOrCreateWorld(dungeonId: string)
	local world = DungeonManager:getWorld(dungeonId)
	if world then
		return world
	end
	assert(DungeonsData[dungeonId], "Dungeon data not found for " .. dungeonId)

	world = DungeonWorld.new(dungeonId)
	world:init()
	DungeonManager._worlds[dungeonId] = world
	return world
end

function DungeonManager:teleportUsers(dungeonId: string, usersArray): ()
	local world = self:getOrCreateWorld(dungeonId)
	local cf = world:getPlayerSpawnCFrame()
	for _, user in ipairs(usersArray) do
		task.spawn(function()
			local userPartyManager = user.userPartyManager
			if not userPartyManager then
				repeat
					task.wait()
					userPartyManager = user.userPartyManager
				until userPartyManager
			end
			local party = userPartyManager:getPartyAsync()
			party:teleportPartyTo(cf)
		end)
		world:registerUser(user)
	end
end

function DungeonManager:start(): ()
	for _, dungeon in ipairs(DungeonsData) do
		self:getOrCreateWorld(dungeon.id)
	end

	for _, portal in pairs(workspace.DungeonPortals:GetChildren()) do
		local dungeonId = portal.Name
		local dungeonNamePlate = game.ReplicatedStorage.Assets.General.UI.DungeonNamePlate:Clone()
		dungeonNamePlate.Name = dungeonId
		dungeonNamePlate.Parent = portal.Zone
		local debounce = {}
		portal.Zone.Touched:Connect(function(hit)
			local player = game.Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end

			if debounce[player.Name] then
				return
			end
			debounce[player.Name] = true
			task.delay(1, function()
				debounce[player.Name] = false
			end)

			local user = ServerMod:getUserAsync(player)
			local dungeon = self:getOrCreateWorld(dungeonId)
			if dungeon:hasUser(user) then
				return
			end

			self:teleportUsers("Air", { user })
		end)
	end
end

function DungeonManager:tick(dt: number): ()
	for _, world in pairs(self._worlds) do
		world:tick(dt)
	end
end

return DungeonManager
