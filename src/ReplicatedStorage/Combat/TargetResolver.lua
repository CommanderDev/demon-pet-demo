--[[
	TargetResolver - Finds valid targets for abilities
	
	Responsibilities:
	- Find targets based on ability targeting config
	- Validate target eligibility (range, faction, alive status)
	- Support different targeting types (Self, Enemy, Ally, AoE, etc.)
]]

local UnitHelper = require(game.ReplicatedStorage.Helpers.UnitHelper)

local TargetResolver = {}

--[[
	Find a valid target for an ability
]]
function TargetResolver.findTarget(caster, ability, attackSystem, preferredTargetId: string?): string?
	local targeting = ability.targeting

	if not targeting then
		return nil
	end

	if targeting.type == "Self" then
		return caster.id
	end

	if preferredTargetId then
		local isValid = TargetResolver.validateTarget(caster, ability, preferredTargetId, attackSystem)
		if isValid then
			return preferredTargetId
		end
	end

	if targeting.type == "Enemy" then
		return TargetResolver._findNearestEnemy(caster, ability, attackSystem)
	end

	if targeting.type == "Ally" then
		return TargetResolver._findNearestAlly(caster, ability, attackSystem)
	end

	-- AoE and other types would be handled differently
	-- For now, return nil for unsupported types
	return nil
end

--[[
	Validate if a specific target is valid for an ability
]]
function TargetResolver.validateTarget(caster, ability, targetId: string, attackSystem): boolean
	if not targetId then
		return false
	end

	local target = attackSystem:_resolveUnit(targetId)
	if not target then
		return false
	end

	-- Check if target can be targeted
	if not target:canBeTargeted() then
		return false
	end

	-- Check range
	local distance = (target.position - caster.position).Magnitude
	local range = ability.targeting.range or 10
	if distance > range then
		return false
	end

	-- Check faction requirements
	if ability.targeting.type == "Enemy" then
		if not UnitHelper.areEnemies(caster.id, targetId) then
			return false
		end
	elseif ability.targeting.type == "Ally" then
		if UnitHelper.areEnemies(caster.id, targetId) then
			return false
		end
		-- Don't target self unless it's Self targeting
		if caster.id == targetId then
			return false
		end
	end

	return true
end

--[[
	Find the nearest enemy within range
]]
function TargetResolver._findNearestEnemy(caster, ability, attackSystem): string?
	local range = ability.targeting.range or 10
	local nearestId = nil
	local nearestDistance = math.huge

	for enemyId, _ in attackSystem:iterEnemies(caster.id) do
		local enemy = attackSystem:_resolveUnit(enemyId)
		if enemy and enemy:canBeTargeted() then
			if UnitHelper.areEnemies(caster.id, enemyId) then
				local distance = (enemy.position - caster.position).Magnitude
				if distance <= range and distance < nearestDistance then
					nearestDistance = distance
					nearestId = enemyId
				end
			end
		end
	end

	return nearestId
end

--[[
	Find the nearest ally within range
]]
function TargetResolver._findNearestAlly(caster, ability, attackSystem): string?
	local range = ability.targeting.range or 10
	local nearestId = nil
	local nearestDistance = math.huge

	for unitId, unit in attackSystem:iterAll() do
		-- Skip self
		if unitId ~= caster.id then
			if unit and unit:canBeTargeted() then
				-- Check if ally (not enemy)
				if not UnitHelper.areEnemies(caster.id, unitId) then
					local distance = (unit.position - caster.position).Magnitude
					if distance <= range and distance < nearestDistance then
						nearestDistance = distance
						nearestId = unitId
					end
				end
			end
		end
	end

	return nearestId
end

--[[
	Get all targets within AoE range
	Returns: array of target IDs
]]
function TargetResolver.findAoETargets(caster, ability, attackSystem): { string }
	local targets = {}
	local targeting = ability.targeting
	local range = targeting.range or 10
	local radius = targeting.radius or 5

	for unitId, unit in attackSystem:iterAll() do
		if unitId ~= caster.id and unit and unit:canBeTargeted() then
			local distance = (unit.position - caster.position).Magnitude
			if distance <= range then
				-- Check faction requirements
				local isEnemy = UnitHelper.areEnemies(caster.id, unitId)
				if targeting.type == "AoE" or (targeting.type == "Enemy" and isEnemy) then
					table.insert(targets, unitId)
				end
			end
		end
	end

	return targets
end

return TargetResolver
