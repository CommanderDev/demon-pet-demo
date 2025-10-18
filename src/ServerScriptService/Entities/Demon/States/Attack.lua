local ServerMod = require(game.ServerScriptService.ServerMod)
local UnitHelper = require(game.ReplicatedStorage.Helpers.UnitHelper)
local Units = require(game.ReplicatedStorage.GameData.Units)
local Abilities = require(game.ReplicatedStorage.GameData.Abilities)
local AbilityCaster = require(game.ReplicatedStorage.Combat.AbilityCaster)
local AutoCastManager = require(game.ReplicatedStorage.Combat.AutoCastManager)
local TargetResolver = require(game.ReplicatedStorage.Combat.TargetResolver)

local Attack = {}
Attack.__index = Attack

local ATTACK_RANGE = 10
local COUNTER_ATTACK_DELAY = 0.1
local WAITING_CHECK_INTERVAL = 0.1
local CHASE_RANGE = ATTACK_RANGE + 3

function Attack.new(demon)
	local self = setmetatable({}, Attack)
	self.demon = demon
	self.targetId = nil
	self.lastAttackTime = 0
	self.nextAutoAttackTime = 0
	self.lastStateSwitch = 0
	self.lastRepositionTime = 0

	if not self.demon.autoCastManager then
		self.demon.autoCastManager = AutoCastManager.new(self.demon.unit)
	end

	return self
end

function Attack:enter(): ()
	self.lastAttackTime = 0
	self.nextAutoAttackTime = 0
	self.targetId = self.demon._forcedTargetId

	if self.demon.autoCastManager then
		self.demon.autoCastManager:reset()
	end
end

function Attack:exit(): () end

function Attack:_tryAttack(targetId: string): boolean
	local now = os.clock()

	if now < self.nextAutoAttackTime then
		return false
	end

	local myUnit = self.demon.unit

	local timeSinceLastAttack = now - self.lastAttackTime

	local attackSys = ServerMod.combatManager and ServerMod.combatManager:GetAttackSystem()
	if not attackSys then
		return false
	end

	local abilityCaster = AbilityCaster.new(attackSys)

	local shouldCast, abilityId = self.demon.autoCastManager:shouldAutoCast()

	if not shouldCast or not abilityId then
		return false
	end

	local ability = Abilities.get(abilityId)
	if not ability then
		warn("Ability not found: " .. abilityId)
		return false
	end

	local abilityTarget = TargetResolver.findTarget(myUnit, ability, attackSys, targetId)
	if not abilityTarget then
		return false
	end

	local target = self.demon:resolveUnitById(abilityTarget)
	if not target or not target:canBeTargeted() then
		return false
	end

	local distance = (target.position - myUnit.position).Magnitude
	local abilityRange = ability.targeting.range or ATTACK_RANGE
	if distance > abilityRange then
		return false
	end

	local isRanged = ability.targeting and ability.targeting.range and ability.targeting.range > ATTACK_RANGE
	local timeSinceLastAttack = now - self.lastAttackTime
	local canBypassTurn = isRanged or timeSinceLastAttack > 0.5
	if not canBypassTurn and not myUnit:isMyTurnInCombat(abilityTarget) then
		return false
	end

	local result = abilityCaster:cast(myUnit, abilityId, abilityTarget)
	if result.success then
		self.lastAttackTime = now
		myUnit:giveOpponentTurn(abilityTarget)
		self.nextAutoAttackTime = now + COUNTER_ATTACK_DELAY

		self.demon.autoCastManager:onAbilityCast(abilityId)

		return true
	else
		if
			result.reason == "invalid_caster"
			or result.reason == "invalid_ability"
			or result.reason == "caster_dead"
		then
			self.demon.autoCastManager:reset()
		end
	end

	return false
end

function Attack:_isPositionOccupied(position: Vector3, unit, target): boolean
	local OCCUPIED_BOX_SIZE = 3.0

	for _, otherUnit in pairs(ServerMod.unitManager._byId) do
		if otherUnit.id ~= unit.id and otherUnit.id ~= target.id and otherUnit:isAlive() then
			local isFriendly = not UnitHelper.areEnemies(unit.id, otherUnit.id)
			if isFriendly then
				local distance = (position - otherUnit.position).Magnitude
				if distance < OCCUPIED_BOX_SIZE then
					return true
				end
			end
		end
	end

	return false
end

function Attack:_isTooCrowded(unit, target): boolean
	local CROWDING_THRESHOLD = 3
	local nearbyAllies = 0

	for _, otherUnit in pairs(ServerMod.unitManager._byId) do
		if otherUnit.id ~= unit.id and otherUnit.id ~= target.id and otherUnit:isAlive() then
			local isFriendly = not UnitHelper.areEnemies(unit.id, otherUnit.id)
			if isFriendly then
				local distance = (unit.position - otherUnit.position).Magnitude
				if distance < 8 then
					nearbyAllies = nearbyAllies + 1
				end
			end
		end
	end

	return nearbyAllies >= CROWDING_THRESHOLD
end

function Attack:_findOpenPositionAroundTarget(unit, target): Vector3?
	local ATTACK_DISTANCE = ATTACK_RANGE - 2
	local unitConfig = Units[unit.unitIdentifier]
	if unitConfig and unitConfig.abilities then
		local bestAbility = nil
		local bestPriority = -1

		for _, abilityId in ipairs(unitConfig.abilities) do
			local ability = Abilities.get(abilityId)
			if ability and ability.ai and ability.auto then
				local priority = ability.ai.priority or 0
				if priority > bestPriority and unit:cooldownReady(abilityId) then
					bestPriority = priority
					bestAbility = ability
				end
			end
		end

		if bestAbility and bestAbility.ai and bestAbility.ai.optimalRange then
			local optimalRange = bestAbility.ai.optimalRange
			if typeof(optimalRange) == "NumberRange" then
				ATTACK_DISTANCE = (optimalRange.Min + optimalRange.Max) / 2
			end
		elseif bestAbility and bestAbility.targeting.range then
			ATTACK_DISTANCE = bestAbility.targeting.range * 0.8
		end
	end

	local NUM_POSITIONS = 16

	local currentAngle = nil
	local currentDirection = unit.position - target.position
	if currentDirection.Magnitude > 0.1 then
		currentAngle = math.atan2(currentDirection.Z, currentDirection.X)
	end

	local positions = {}
	for i = 1, NUM_POSITIONS do
		local angle = (i / NUM_POSITIONS) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * ATTACK_DISTANCE
		local testPosition = target.position + offset

		local angleDiff = math.huge
		if currentAngle then
			angleDiff = math.abs(angle - currentAngle)
			if angleDiff > math.pi then
				angleDiff = 2 * math.pi - angleDiff
			end
		end

		table.insert(positions, {
			position = testPosition,
			angle = angle,
			angleDiff = angleDiff,
			distToCurrent = (testPosition - unit.position).Magnitude,
		})
	end

	table.sort(positions, function(a, b)
		return a.angleDiff < b.angleDiff
	end)

	for _, posData in ipairs(positions) do
		if not self:_isPositionOccupied(posData.position, unit, target) then
			return posData.position
		end
	end

	return positions[1] and positions[1].position
end

function Attack:_needsRepositioning(unit, target): boolean
	local POSITION_BOX_SIZE = 1.8

	for _, otherUnit in pairs(ServerMod.unitManager._byId) do
		if otherUnit.id ~= unit.id and otherUnit.id ~= target.id and otherUnit:isAlive() then
			local isFriendly = not UnitHelper.areEnemies(unit.id, otherUnit.id)
			if isFriendly then
				local distance = (unit.position - otherUnit.position).Magnitude
				if distance < POSITION_BOX_SIZE then
					return true
				end
			end
		end
	end

	return false
end

function Attack:tick(demon, dt: number): string?
	local now = os.clock()
	local unit = self.demon.unit

	local returnState = unit.leader and "FollowLeader" or "Idle"

	if not self.targetId then
		return returnState
	end

	local target = self.demon:resolveUnitById(self.targetId)
	if not target or not target:canBeTargeted() then
		self.targetId = nil
		return returnState
	end

	local distance = (target.position - unit.position).Magnitude

	local preferredRange = ATTACK_RANGE
	local unitConfig = Units[unit.unitIdentifier]
	if unitConfig and unitConfig.abilities then
		local bestAbility = nil
		local bestPriority = -1

		for _, abilityId in ipairs(unitConfig.abilities) do
			local ability = Abilities.get(abilityId)
			if ability and ability.ai and ability.auto then
				local priority = ability.ai.priority or 0
				if priority > bestPriority and unit:cooldownReady(abilityId) then
					bestPriority = priority
					bestAbility = ability
				end
			end
		end

		if bestAbility and bestAbility.ai and bestAbility.ai.optimalRange then
			local optimalRange = bestAbility.ai.optimalRange
			if typeof(optimalRange) == "NumberRange" then
				preferredRange = (optimalRange.Min + optimalRange.Max) / 2
			end
		elseif bestAbility and bestAbility.targeting.range then
			preferredRange = bestAbility.targeting.range * 0.8
		end
	end

	local chaseThreshold = preferredRange * 1.5
	if distance > chaseThreshold then
		local now = os.clock()
		if now - self.lastStateSwitch < 1.0 then
			return nil
		end
		self.lastStateSwitch = now
		self.demon._forcedTargetId = self.targetId
		return "Chase"
	end

	local needsRangeRepositioning = false
	local forceBackOff = false
	if preferredRange > 0 then
		if distance < (preferredRange * 0.7) or distance > (preferredRange * 1.3) then
			needsRangeRepositioning = true
		end
		if distance < (preferredRange * 0.6) then
			forceBackOff = true
		end
	end

	self:_tryAttack(self.targetId)

	local baseCooldown = 1.5
	local repositionCooldown = forceBackOff and 0.5 or baseCooldown
	local canReposition = (now - self.lastRepositionTime) > repositionCooldown
	if
		(self:_needsRepositioning(unit, target) or needsRangeRepositioning or forceBackOff)
		and (forceBackOff or not self:_isTooCrowded(unit, target))
		and canReposition
	then
		local openPosition = self:_findOpenPositionAroundTarget(unit, target)
		if openPosition then
			local maxSpeed = unit.maxSpeed or 16
			local repositionSpeed = maxSpeed * 0.8
			local directionToPosition = (openPosition - unit.position).Unit
			local moveDistance = math.min(repositionSpeed * dt, (openPosition - unit.position).Magnitude)

			if moveDistance > 0.1 then
				unit.position = unit.position + (directionToPosition * moveDistance)
				self.lastRepositionTime = now
			end
		end
	end

	local direction = (target.position - unit.position).Unit
	unit.facing = direction

	return nil
end

return Attack
