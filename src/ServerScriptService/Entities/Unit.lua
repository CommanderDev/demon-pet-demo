local HttpService = game:GetService("HttpService")

local Signal = require(game.ReplicatedStorage.Libraries.Signal)

local ServerMod = require(game.ServerScriptService.ServerMod)

local LevelProgression = require(game.ReplicatedStorage.GameData.LevelProgression)
local Units = require(game.ReplicatedStorage.GameData.Units)
local Unit = {}
Unit.__index = Unit

function Unit.new(unitData)
	local self = setmetatable({}, Unit)

	self.id = unitData.unitId or HttpService:GenerateGUID(false)
	self.unitIdentifier = unitData.id
	self.name = unitData.name
	self.displayName = unitData.name
	self.kind = unitData.kind or "Demon"
	self.teamId = unitData.teamId
	self.leader = unitData.leader
	self.faction = unitData.faction or unitData.teamId or "Neutral"

	self.level = unitData.level or 1

	local unitInfo = Units.get(self.unitIdentifier)
	if unitInfo then
		stats = unitInfo.stats
	else
		stats = {}
	end
	self.stats = LevelProgression.getStatsByLevel(stats, self.level)

	local maxHpValue = unitData.maxHp or unitData.MaxHP or (self.stats and self.stats.HP) or 100
	self.maxHp = maxHpValue
	self.hp = unitData.hp or unitData.HP or maxHpValue

	self.resources = unitData.resources or {}
	self.statuses = {}
	self.cooldowns = {}
	self.charges = {}
	self.casting = nil

	self:_initializeAbilityCharges()

	self.baseAttack = {
		power = (self.stats and self.stats.ATK) or 10,
		critChance = (self.stats and self.stats.CritChance) or 0.05,
		critMult = (self.stats and self.stats.CritMult) or 1.5,
		type = "Physical",
		pierce = 0,
	}

	self.position = unitData.position
	self.facing = unitData.facing
	self.onDied = Signal.new()

	self._recentAttackers = {}
	self._lastAttackedTime = 0

	self._combatEngagement = nil

	return self
end

function Unit:_initializeAbilityCharges()
	-- Initialize charges for abilities that use them
	local Units = require(game.ReplicatedStorage.GameData.Units)
	local Abilities = require(game.ReplicatedStorage.GameData.Abilities)

	local unitConfig = Units[self.unitIdentifier]
	if not unitConfig or not unitConfig.abilities then
		return
	end

	for _, abilityId in ipairs(unitConfig.abilities) do
		local ability = Abilities.get(abilityId)
		if ability and ability.charges then
			self.charges[abilityId] = ability.charges
		end
	end
end

function Unit:getId(): string
	return self.id
end

function Unit:getKind(): string
	return self.kind
end

function Unit:getTeamId(): number
	return self.teamId
end

function Unit:getLeader()
	return self.leader
end

function Unit:getHp(): number
	return self.hp or 0
end

function Unit:isAlive(): boolean
	-- Player demons are considered alive even when HP = 0 (they're sleeping, not dead)
	if self.kind == "Demon" and self.faction and string.find(self.faction, "Player_") == 1 then
		return not self:isPermanentlyDead()
	end

	return self:getHp() > 0
end

function Unit:isSleeping(): boolean
	return self.sleeping == true
end

function Unit:isPermanentlyDead(): boolean
	return self._permanentlyDead == true
end

function Unit:markAsPermanentlyDead(): ()
	self._permanentlyDead = true
end

function Unit:canBeTargeted(): boolean
	return self:isAlive() and not self:isSleeping()
end

function Unit:takeDamage(amount: number, source)
	if not self.hp then
		self.hp = 0
		return
	end

	if self.sleeping then
		return
	end

	self.hp = math.max(self.hp - amount, 0)

	if source then
		self:recordAttacker(source)
		self:setMyTurnInCombat(source)
	end

	if self.hp == 0 then
		local isPlayerDemon = self.kind == "Demon" and self.faction and string.find(self.faction, "Player_") == 1

		if isPlayerDemon then
			if self.entity and self.entity.setState then
				self.entity:setState("Sleep")
			end
		else
			self:die()
		end
	end
end

function Unit:recordAttacker(attackerId: string): ()
	local now = os.clock()
	self._recentAttackers[attackerId] = now
	self._lastAttackedTime = now
end

function Unit:getRecentAttacker(maxAge: number?): string?
	maxAge = maxAge or 5.0
	local now = os.clock()

	local mostRecentId = nil
	local mostRecentTime = 0

	for attackerId, timestamp in pairs(self._recentAttackers) do
		if (now - timestamp) <= maxAge and timestamp > mostRecentTime then
			mostRecentTime = timestamp
			mostRecentId = attackerId
		end
	end

	return mostRecentId
end

function Unit:clearRecentAttackers(): ()
	table.clear(self._recentAttackers)
	self._lastAttackedTime = 0
end

function Unit:setMyTurnInCombat(targetId: string): ()
	self._combatEngagement = {
		targetId = targetId,
		myTurn = true,
		lastTurnTime = os.clock(),
	}
end

function Unit:clearMyTurnInCombat(): ()
	if self._combatEngagement then
		self._combatEngagement.myTurn = false
	end
end

function Unit:giveOpponentTurn(targetId: string): ()
	if self._combatEngagement and self._combatEngagement.targetId == targetId then
		self._combatEngagement.myTurn = false
	end
end

function Unit:isMyTurnInCombat(targetId: string): boolean
	if not self._combatEngagement then
		return true
	end

	if self._combatEngagement.targetId ~= targetId then
		return true
	end

	return self._combatEngagement.myTurn == true
end

function Unit:getCombatTarget(): string?
	return self._combatEngagement and self._combatEngagement.targetId or nil
end

function Unit:endCombatEngagement(): ()
	self._combatEngagement = nil
end

function Unit:die(): ()
	self.hp = 0
	if self.onDied then
		self.onDied:Fire()
	end
end

function Unit:heal(amount: number): ()
	if not self.hp or not self.maxHp then
		return
	end
	self.hp = math.min(self.hp + amount, self.maxHp)
end

function Unit:hasStatus(statusId: string): boolean
	return self.statuses[statusId]
end

function Unit:applyStatus(statusId: string, duration: number, source): ()
	self.statuses[statusId] = {
		appliedAt = os.clock(),
		duration = duration,
		source = source,
	}
end

function Unit:clearStatus(statusId: string): ()
	self.statuses[id] = nil
end

function Unit:cooldownReady(id: string): boolean
	return (self.cooldowns[id] or 0) <= os.clock()
end

function Unit:startCooldown(id: string, duration: number): ()
	self.cooldowns[id] = os.clock() + duration
end

function Unit:chargesReady(id: string)
	return (self.charges[id] or 1) > 0
end

function Unit:consumeCharge(id: string): ()
	self.charges[id] = (self.charges[id] or 1) - 1
end

function Unit:hasResource(kind: string, cost: number): ()
	return (self.resources[kind] or 0) >= cost
end
function Unit:spendResource(kind: string, cost: number): ()
	self.resources[kind] = self.resources[kind] - cost
end

function Unit:beginCast(abilityId: string, targets): ()
	self.casting = { id = abilityId, targets = targets, interrupted = false }
end
function Unit:cancelCast(): ()
	if self.casting then
		self.casting.interrupted = true
	end
end

function Unit:stopMove(reason): ()
	self.vel = Vector3.zero
	self.moveGoal = nil
	self.state = "Idle"
end

function Unit:setMoveGoal(point: Vector3): ()
	self.moveGoal = point
end

function Unit:applyMotion(wantVel: Vector3, dt: number, reason: string?): ()
	dt = math.clamp(dt, 0, 0.2)
	local maxSpeed = self.maxSpeed or 16
	local vel = wantVel.Magnitude > maxSpeed and wantVel.Unit * maxSpeed or wantVel
	local newPos = self.position + vel * dt
	self.position = newPos
	if vel.Magnitude > 0.05 then
		self.facing = vel.Unit
	end
	self.vel = vel
end

function Unit:setPositionFacing(pos: Vector3, facing: Vector3, reason: string?)
	self.pos = pos
	self.facing = (facing.Magnitude > 0) and facing.Unit or self.facing
	self.vel = Vector3.zero
	self.state = "Idle"
end

function Unit:pivotTo(cframe: CFrame): ()
	self.position = cframe.Position
	self.facing = cframe.LookVector

	-- Handle Player units
	if self.kind == "Player" then
		local player = game.Players:GetPlayerByUserId(self.id)
		if player then
			player.Character:PivotTo(cframe)
		end
	end

	-- Handle Demon units - force immediate replication
	if self.entity and self.entity.demonReplicator then
		local position = self.position
		local facing = self.facing
		self.entity.demonReplicator:force({
			["id"] = tostring(self.id),
			["position"] = Vector3.new(position.X, position.Y, position.Z),
			["facing"] = Vector3.new(facing.X, facing.Y, facing.Z),
			["hp"] = tonumber(self.hp) or 0,
			["maxHp"] = tonumber(self.maxHp) or 0,
			["state"] = self.entity._currentState and tostring(self.entity._currentState.name) or "Idle",
			["name"] = tostring(self.name),
			["unitIdentifier"] = tostring(self.unitIdentifier),
			["targetId"] = self.entity._forcedTargetId and tostring(self.entity._forcedTargetId) or nil,
			["leaderId"] = self.entity._leaderRef and tostring(self.entity._leaderRef.id) or nil,
			["leaderKind"] = self.entity._leaderRef and tostring(self.entity._leaderRef.kind) or nil,
			["formationSlotIndex"] = self.formationSlotIndex and tonumber(self.formationSlotIndex) or nil,
			["formationMemberCount"] = self.formationMemberCount and tonumber(self.formationMemberCount) or nil,
			["formationType"] = self.entity._cachedFormationType and tostring(self.entity._cachedFormationType) or nil,
			["formationSpacing"] = self.entity._cachedFormationSpacing and tonumber(
				self.entity._cachedFormationSpacing
			) or nil,
			["resources"] = self.resources,
			["statuses"] = self.statuses,
			["cooldowns"] = self.cooldowns,
			["casting"] = self.casting,
			["charges"] = self.charges,
		})
	end
end

function Unit:isCasting(): boolean
	return self.casting ~= nil
end
function Unit:isInterrupted(): boolean
	return self.casting and self.casting.interrupted
end
function Unit:_exitCasting(interrupted: boolean): ()
	self.casting = nil
end

return Unit
