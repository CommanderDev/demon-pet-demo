local ServerMod = require(game.ServerScriptService.ServerMod)
local UnitHelper = require(game.ReplicatedStorage.Helpers.UnitHelper)
local Units = require(game.ReplicatedStorage.GameData.Units)
local Abilities = require(game.ReplicatedStorage.GameData.Abilities)

local Chase = {}
Chase.__index = Chase

local ATTACK_RANGE = 10
local CHASE_TIMEOUT = 10
local COUNTER_ATTACK_DELAY = 0.4
local TARGET_RECHECK_INTERVAL = 1.0

function Chase.new(demon)
	local self = setmetatable({}, Chase)
	self.demon = demon
	self.targetId = nil
	self.lastAttackTime = 0
	self.nextAutoAttackTime = 0
	self.chaseStartTime = os.clock()
	self.lastTargetCheck = 0
	self.lastStateSwitch = 0 -- Prevent rapid state switching
	return self
end

function Chase:enter(): ()
	self.chaseStartTime = os.clock()
	self.lastAttackTime = 0
	self.nextAutoAttackTime = 0
end

function Chase:exit(): () end

function Chase:_findTarget(): string?
	if self.demon._forcedTargetId then
		local target = self.demon:resolveUnitById(self.demon._forcedTargetId)
		if target and target:isAlive() then
			return self.demon._forcedTargetId
		end
		self.demon._forcedTargetId = nil
	end

	local partyFocus = self.demon:getPartyFocus()
	if partyFocus then
		local target = self.demon:resolveUnitById(partyFocus)
		if target and target:isAlive() then
			return partyFocus
		end
	end

	local nearestId = nil
	local nearestDist = math.huge

	for _, unit in pairs(ServerMod.unitManager._byId) do
		if unit.id ~= self.demon.unit.id and unit:isAlive() then
			if UnitHelper.areEnemies(self.demon.unit.id, unit.id) then
				local dist = (unit.position - self.demon.unit.position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestId = unit.id
				end
			end
		end
	end

	return nearestId
end

function Chase:_tryAttack(targetId: string): boolean
	local target = self.demon:resolveUnitById(targetId)
	if not target or not target:isAlive() then
		return false
	end

	local distance = (target.position - self.demon.unit.position).Magnitude
	if distance > ATTACK_RANGE then
		return false
	end

	local now = os.clock()

	local myUnit = self.demon.unit
	if not myUnit:isMyTurnInCombat(targetId) then
		return false
	end

	if now < self.nextAutoAttackTime then
		return false
	end

	local unitConfig = Units[self.demon.unit.unitIdentifier]
	local autoAbilityId = unitConfig and unitConfig.auto and unitConfig.auto.abilityId or "BASIC_STRIKE"

	local attackSys = ServerMod.combatManager and ServerMod.combatManager:GetAttackSystem()
	if attackSys then
		local success, result = attackSys:performAttack(self.demon.unit.id, targetId, { abilityId = autoAbilityId })

		if success then
			self.lastAttackTime = now

			myUnit:giveOpponentTurn(targetId)

			self.nextAutoAttackTime = now + COUNTER_ATTACK_DELAY

			return true
		end
	end

	return false
end

function Chase:_isBoxOccupied(position: Vector3, unit): boolean
	local BOX_SIZE = 2.5 -- Box around path waypoint

	for _, otherUnit in pairs(ServerMod.unitManager._byId) do
		if otherUnit.id ~= unit.id and otherUnit:isAlive() then
			local isFriendly = not UnitHelper.areEnemies(unit.id, otherUnit.id)
			if isFriendly then
				local distance = (position - otherUnit.position).Magnitude
				if distance < BOX_SIZE then
					return true
				end
			end
		end
	end

	return false
end

function Chase:_findBestApproachAngle(unit, targetPosition: Vector3): Vector3
	local directDirection = (targetPosition - unit.position).Unit
	local CHECK_DISTANCE = 4
	local NUM_ANGLES = 7 -- Check: straight, ±25°, ±45°, ±70°

	-- Try different approach angles
	local angles = { 0, math.rad(25), math.rad(-25), math.rad(45), math.rad(-45), math.rad(70), math.rad(-70) }

	for _, angleOffset in ipairs(angles) do
		-- Rotate around Y axis
		local cosA = math.cos(angleOffset)
		local sinA = math.sin(angleOffset)
		local testDir = Vector3.new(
			directDirection.X * cosA - directDirection.Z * sinA,
			directDirection.Y,
			directDirection.X * sinA + directDirection.Z * cosA
		).Unit

		-- Check if the path ahead is clear
		local checkPosition = unit.position + testDir * CHECK_DISTANCE

		if not self:_isBoxOccupied(checkPosition, unit) then
			return testDir
		end
	end

	-- If all paths blocked, return direct direction anyway
	return directDirection
end

function Chase:tick(demon, dt: number): string?
	local unit = self.demon.unit
	local now = os.clock()

	local returnState = unit.leader and "FollowLeader" or "Idle"

	if now - self.chaseStartTime > CHASE_TIMEOUT then
		return returnState
	end

	if not self.targetId or (now - self.lastTargetCheck >= TARGET_RECHECK_INTERVAL) then
		self.lastTargetCheck = now
		self.targetId = self:_findTarget()
	end

	if not self.targetId then
		return returnState
	end

	local target = self.demon:resolveUnitById(self.targetId)
	if not target or not target:canBeTargeted() then
		self.targetId = nil
		return returnState
	end

	local distance = (target.position - unit.position).Magnitude

	-- Get the unit's preferred ability to determine optimal range
	local preferredRange = ATTACK_RANGE
	local unitConfig = Units[unit.unitIdentifier]
	if unitConfig and unitConfig.abilities then
		-- Find the highest priority ability that's ready
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

		-- Use the ability's optimal range if available
		if bestAbility and bestAbility.ai and bestAbility.ai.optimalRange then
			local optimalRange = bestAbility.ai.optimalRange
			if typeof(optimalRange) == "NumberRange" then
				preferredRange = (optimalRange.Min + optimalRange.Max) / 2
			end
		elseif bestAbility and bestAbility.targeting.range then
			preferredRange = bestAbility.targeting.range * 0.8 -- Stay within 80% of max range
		end
	end

	-- Chase state logic

	if distance < preferredRange then
		local now = os.clock()
		-- Prevent rapid state switching (minimum 1 second between switches)
		if now - self.lastStateSwitch < 1.0 then
			return nil
		end
		self.lastStateSwitch = now
		self.demon._forcedTargetId = self.targetId
		return "Attack"
	end

	local maxSpeed = unit.maxSpeed or 16
	local targetDistance = preferredRange - 1
	local moveAmount = math.min(maxSpeed * dt, math.max(0, distance - targetDistance))

	-- Moving towards target

	if moveAmount > 0 then
		-- Find the best approach angle that avoids occupied boxes
		local direction = self:_findBestApproachAngle(unit, target.position)
		unit.position = unit.position + (direction * moveAmount)
		unit.facing = direction
	end

	return nil
end

return Chase
