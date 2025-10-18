--[[
	AutoCastManager - Manages auto-casting abilities for units
	
	Responsibilities:
	- Track last cast times for auto-cast abilities
	- Determine when a unit should auto-cast
	- Respect auto.interval timing from ability configs
	- Reset timers when manual abilities are cast
]]

local Abilities = require(game.ReplicatedStorage.GameData.Abilities)
local Units = require(game.ReplicatedStorage.GameData.Units)

local AutoCastManager = {}
AutoCastManager.__index = AutoCastManager

function AutoCastManager.new(unit)
	local self = setmetatable({}, AutoCastManager)
	self.unit = unit
	self.lastAbilityCastTime = 0
	self.nextAutoTime = 0
	self._jitter = (tonumber(string.byte(unit.id, 1) or 0) % 17) / 17
	return self
end

function AutoCastManager:onAbilityCast(abilityId: string)
	local now = os.clock()
	self.lastAbilityCastTime = now

	local ability = Abilities.get(abilityId)
	if not ability or not ability.auto then
		return
	end

	local interval = ability.auto.interval
	local minClamp = 0.2
	if typeof(interval) == "NumberRange" then
		local base = math.max(interval.Min, minClamp)
		local span = math.max(interval.Max - base, 0)
		local randomDelay = base + (self._jitter + math.random()) % 1 * span
		self.nextAutoTime = now + randomDelay
	elseif type(interval) == "number" then
		self.nextAutoTime = now + math.max(interval, minClamp)
	end
end

function AutoCastManager:shouldAutoCast(): (boolean, string?)
	local now = os.clock()

	if now < self.nextAutoTime then
		return false, nil
	end

	local unitConfig = Units[self.unit.unitIdentifier]
	if not unitConfig or not unitConfig.abilities then
		return false, nil
	end

	local autoCastAbilities = {}
	for _, abilityId in ipairs(unitConfig.abilities) do
		local ability = Abilities.get(abilityId)
		if ability and ability.auto then
			local cooldownReady = self.unit:cooldownReady(abilityId)
			if cooldownReady then
				local hasResources = not ability.resource
					or ability.resource == false
					or self.unit:hasResource(ability.resource.type, ability.resource.cost)
				if hasResources then
					local hasCharges = not ability.charges
						or ability.charges == nil
						or ability.charges == false
						or self.unit:chargesReady(abilityId)
					if hasCharges then
						table.insert(autoCastAbilities, {
							id = abilityId,
							ability = ability,
							priority = ability.ai and ability.ai.priority or 0,
						})
					end
				end
			end
		end
	end

	if #autoCastAbilities == 0 then
		return false, nil
	end

	table.sort(autoCastAbilities, function(a, b)
		return a.priority > b.priority
	end)

	for _, abilityData in ipairs(autoCastAbilities) do
		local canCast = self:_canCastAbility(abilityData.id, abilityData.ability)
		if canCast then
			local interval = abilityData.ability.auto.interval
			local minClamp = 0.2
			if typeof(interval) == "NumberRange" then
				local base = math.max(interval.Min, minClamp)
				local span = math.max(interval.Max - base, 0)
				local randomDelay = base + (self._jitter + math.random()) % 1 * span
				self.nextAutoTime = now + randomDelay
			elseif type(interval) == "number" then
				self.nextAutoTime = now + math.max(interval, minClamp)
			else
				self.nextAutoTime = now + 1.5
			end

			return true, abilityData.id
		end
	end

	return false, nil
end

function AutoCastManager:_canCastAbility(abilityId: string, ability: any): boolean
	local TargetResolver = require(game.ReplicatedStorage.Combat.TargetResolver)
	local ServerMod = require(game.ServerScriptService.ServerMod)

	local attackSys = ServerMod.combatManager and ServerMod.combatManager:GetAttackSystem()
	if not attackSys then
		return false
	end

	local targetId = TargetResolver.findTarget(self.unit, ability, attackSys)
	if not targetId then
		return false
	end

	local target = ServerMod.unitManager and ServerMod.unitManager:getUnitById(targetId) or nil
	if not target or not target:canBeTargeted() then
		return false
	end

	local distance = (target.position - self.unit.position).Magnitude
	local abilityRange = ability.targeting.range or 10
	if distance > abilityRange then
		return false
	end

	local timeSinceLastAttack = os.clock() - self.lastAbilityCastTime
	local isRangedAbility = ability.targeting.type == "Ranged"
	local canBypassTurn = isRangedAbility or (timeSinceLastAttack > 0.5)

	if not canBypassTurn and not self.unit:isMyTurnInCombat(targetId) then
		return false
	end

	return true
end

function AutoCastManager:reset()
	self.lastAbilityCastTime = 0
	self.nextAutoTime = 0
end

function AutoCastManager:getNextAutoTime(): number
	return self.nextAutoTime
end

return AutoCastManager
