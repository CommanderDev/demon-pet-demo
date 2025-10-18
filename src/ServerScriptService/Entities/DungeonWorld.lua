local Dungeons = game.ReplicatedStorage.Assets.General.Dungeons

local DungeonData = require(game.ReplicatedStorage.GameData.Dungeons)
local PartyGroups = require(game.ReplicatedStorage.GameData.PartyGroups)

local ServerMod = require(game.ServerScriptService.ServerMod)

local DungeonWorld = {}
DungeonWorld.__index = DungeonWorld

function DungeonWorld.new(dungeonName: string)
	local self = setmetatable({}, DungeonWorld)

	self._dungeonName = dungeonName

	self._currentLevel = 0

	self._enemies = {}
	self._activeUsers = {}

	return self
end

function DungeonWorld:init()
	local dungeonModel = Dungeons:FindFirstChild(self._dungeonName)
	if not dungeonModel then
		error("Dungeon model not found:", self._dungeonName)
		return
	end

	dungeonModel = dungeonModel:Clone()
	dungeonModel:PivotTo(CFrame.new(DungeonData[self._dungeonName].worldPosition))
	dungeonModel.Parent = workspace
	self.model = dungeonModel
	self:reset()
end

function DungeonWorld:spawnLevel(level: number): ()
	local levelData = DungeonData[self._dungeonName].levels[level]
	if not levelData then
		warn("Level data not found:", level)
		return
	end
end

function DungeonWorld:reset(): ()
	self._currentLevel = 0
	self:cleanupMobs()
	self:advanceLevel()
end

function DungeonWorld:getMobSpawnCFrame(): CFrame
	local mobSpawn = self.model:FindFirstChild("MobZone")
	if not mobSpawn then
		error("Mob spawn not found")
		return
	end

	local size = mobSpawn.Size
	local cf = mobSpawn.CFrame

	local x = (math.random() - 0.5) * size.X
	local z = (math.random() - 0.5) * size.Z
	local y = size.Y / 2

	local offset = Vector3.new(x, y, z)
	local worldPos = (cf * CFrame.new(offset)).Position

	return CFrame.new(worldPos, worldPos + cf.LookVector)
end

function DungeonWorld:getPlayerSpawnCFrame(): CFrame
	local playerSpawn = self.model:FindFirstChild("PlayerSpawn")
	if not playerSpawn then
		error("Player spawn not found")
		return
	end
	return playerSpawn.CFrame + Vector3.new(0, 7.5, 0)
end

function DungeonWorld:cleanupMobs(): ()
	for _, unit in ipairs(self._enemies) do
		unit:destroy()
	end
end

function DungeonWorld:spawnMobsByLevel(level: number): ()
	local levelData = DungeonData[self._dungeonName].levels[level]
	if not levelData then
		warn("Dungeon mob not found:", level)
		return
	end

	local roster
	if type(levelData) == "string" then
		-- Handle old string references to PartyGroups
		local group = PartyGroups[levelData]
		if not group then
			warn("Party group not found:", levelData)
			return
		end
		roster = group.roster
	elseif type(levelData) == "table" and levelData.roster then
		-- Handle new direct roster definitions
		roster = levelData.roster
	else
		warn("Invalid level data format for level:", level)
		return
	end

	for _, mob in ipairs(roster) do
		local unit = ServerMod.unitManager:spawnUnit({
			kind = "Demon",
			faction = "Wild",
			teamId = "Wild",
			name = mob.unit,
			level = mob.level,
			id = mob,
			unitIdentifier = mob.unit,
		}, self:getMobSpawnCFrame())
		table.insert(self._enemies, unit)
	end
end

function DungeonWorld:registerUser(user: User): ()
	table.insert(self._activeUsers, user)
	ServerMod:FireClient(user.player, "enteredDungeon", {
		dungeonName = self._dungeonName,
		wave = self._currentLevel,
		maxWave = #DungeonData[self._dungeonName].levels,
	})
end

function DungeonWorld:hasUser(user: User): boolean
	return table.find(self._activeUsers, user) ~= nil
end

function DungeonWorld:unregisterUser(user: User): ()
	table.remove(self._activeUsers, table.find(self._activeUsers, user))
end

function DungeonWorld:advanceLevel(): ()
	self._currentLevel += 1
	local levelData = DungeonData[self._dungeonName].levels[self._currentLevel]
	if not levelData then
		self:reset()
		return
	end
	for _, user in ipairs(self._activeUsers) do
		ServerMod:FireClient(user.player, "updateWave", {
			wave = self._currentLevel,
			maxWave = #DungeonData[self._dungeonName].levels,
		})
	end

	self:spawnMobsByLevel(self._currentLevel)
end

function DungeonWorld:tick(dt: number): ()
	if #self._enemies == 0 then
		self:advanceLevel()
	end
	for index, enemy in ipairs(self._enemies) do
		if not enemy:isAlive() then
			table.remove(self._enemies, index)
		end
	end
end

function DungeonWorld:getModel(): Model
	return self.model
end

return DungeonWorld
