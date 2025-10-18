local Enums = require(game.ReplicatedStorage.Enums)

local Party = require(game.ServerScriptService.Entities.Party)
local Unit = require(game.ServerScriptService.Entities.Unit)

local Units = require(game.ReplicatedStorage.GameData.Units)

local ServerMod = require(game.ServerScriptService.ServerMod)

local UserPartyManager = {}
UserPartyManager.__index = UserPartyManager

function UserPartyManager.new(user)
	local self = setmetatable({}, UserPartyManager)

	self.user = user

	self.party = nil
	self.demons = {}
	self.formation = { type = Enums.FormationType.Wedge, spacing = 6 }

	self._lastLeaderPosition = Vector3.zero
	self._slotRefreshDist2 = 1.5 * 1.5
	self._lastFacingDirection = Vector3.new(0, 0, -1)

	return self
end

function UserPartyManager:start()
	local leaderUnit = self:_ensureLeaderUnit()
	self.leaderUnitId = leaderUnit.id

	self.party = Party.new({
		leaderUnit = leaderUnit,
		teamId = leaderUnit.teamId,
		formation = self.formation.type,
		spacing = self.formation.spacing,
	})

	local equippedDemons = self.user.demonInventory:getEquippedDemons()
	for _, demon in ipairs(equippedDemons) do
		local demon = self:spawnDemon(demon)
		table.insert(self.demons, demon)
	end

	self.party:tick(0)
end

function UserPartyManager:tick(dt: number): ()
	if not self.party then
		return
	end

	local changed = self:_mirrorLeader()

	self.party:tick(dt)
end

function UserPartyManager:spawnDemon(member)
	if not self.party then
		return
	end
	local leaderPosition = self.party.leaderUnit.position or Vector3.zero
	local position = leaderPosition + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))

	local unit = ServerMod.unitManager:spawnUnit({
		kind = "Demon",
		faction = "Player_" .. self.user.id, -- Use player UserId for faction
		teamId = self.party.teamId,
		name = member.name,
		unitIdentifier = member.name,
		unitId = member.GUID,
		leader = self.party.leaderUnit,
		facing = Vector3.new(0, 0, -1),
		position = position,
		level = member.level,
	}, CFrame.new(position))

	local demon = ServerMod.demonManager:getDemonById(unit.id)

	self.party:addMember(demon)

	demon:enqueueOrder({ kind = "Follow" })

	return demon
end

function UserPartyManager:_ensureLeaderUnit(): ()
	if self.leaderUnitId then
		return ServerMod.unitManager:getUnitById(self.leaderUnitId)
	end

	local teamId = self.teamId or 1
	local unit = ServerMod.unitManager:spawnUnit({
		id = "Unit_" .. self.user.id,
		unitId = self.user.id,
		kind = "Player",
		teamId = teamId,
		faction = "Player_" .. self.user.id, -- Use player UserId for faction
		position = Vector3.zero,
		facing = Vector3.new(0, 0, -1),
		unitIdentifier = "Player_" .. self.user.id,
	}, CFrame.new(self._lastLeaderPosition))
	unit.mirrored = true
	return unit
end

function UserPartyManager:_mirrorLeader(): boolean
	local leader = ServerMod.unitManager:getUnitById(self.leaderUnitId)
	if not leader then
		return false
	end

	local character = self.user.rig
	if not character then
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	local newCFrame = hrp.CFrame
	local humanoid = character:FindFirstChild("Humanoid")
	local hp: number = humanoid and humanoid.Health or 100
	local maxHp: number = humanoid and humanoid.MaxHealth or 100

	local oldPosition: Vector3 = leader.position or Vector3.zero
	local newPosition = newCFrame.Position

	leader.position = newPosition
	leader.hp = hp
	leader.maxHp = maxHp

	local moved = (oldPosition - newPosition).Magnitude > 0.001

	if moved then
		local movementVector = newPosition - oldPosition
		if movementVector.Magnitude > 0.1 then
			local newFacing = movementVector.Unit
			self._lastFacingDirection = self._lastFacingDirection:Lerp(newFacing, 0.3)
			leader.facing = self._lastFacingDirection
		end
		self._lastLeaderPosition = newPosition
	end

	return moved
end

function UserPartyManager:getParty(): Party
	return self.party
end

function UserPartyManager:getPartyAsync(): Party
	local party = self:getParty()
	if not party then
		repeat
			task.wait()
			party = self:getParty()
		until party
	end
	return party
end

return UserPartyManager
