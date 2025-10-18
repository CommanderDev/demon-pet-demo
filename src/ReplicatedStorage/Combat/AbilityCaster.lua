--[[
	AbilityCaster - Core ability casting system
	
	Responsibilities:
	- Validate ability cast requirements (cooldown, resources, range, etc.)
	- Execute ability casts (consume resources, start cooldowns, apply effects)
	- Handle cast time mechanics
	- Coordinate with AttackSystem for damage abilities
]]

local Abilities = require(game.ReplicatedStorage.GameData.Abilities)
local AttackSystem = require(game.ReplicatedStorage.Combat.AttackSystem)
local AbilityEffects = require(game.ReplicatedStorage.Combat.AbilityEffects)
local ServerMod = require(game.ServerScriptService.ServerMod)

local AbilityCaster = {}
AbilityCaster.__index = AbilityCaster

export type CastResult = {
	success: boolean,
	reason: string?,
	damage: number?,
	meta: any?,
}

function AbilityCaster.new(attackSystem)
	local self = setmetatable({}, AbilityCaster)
	self.attackSystem = attackSystem
	return self
end

function AbilityCaster:canCast(caster, abilityId: string, targetId: string?): (boolean, string?)
	-- Check if ability can be cast
	if not caster or not caster.id then
		return false, "invalid_caster"
	end

	-- Get ability config
	local ability = Abilities.get(abilityId)
	if not ability then
		return false, "invalid_ability"
	end

	if not caster:isAlive() then
		return false, "caster_dead"
	end

	local isHealingAbility = false
	for _, effect in ipairs(ability.effects) do
		if effect.type == "Heal" then
			isHealingAbility = true
			break
		end
	end

	if caster:isSleeping() and not isHealingAbility then
		return false, "caster_sleeping"
	end

	if caster:isCasting() then
		return false, "already_casting"
	end

	if caster:hasStatus("Stunned") then
		return false, "stunned"
	end

	if caster:hasStatus("Silenced") and ability.kind ~= "Defense" then
		return false, "silenced"
	end

	if not caster:cooldownReady(abilityId) then
		return false, "on_cooldown"
	end

	if
		ability.charges
		and ability.charges ~= nil
		and ability.charges ~= false
		and not caster:chargesReady(abilityId)
	then
		return false, "no_charges"
	end

	if ability.resource and ability.resource ~= false then
		if not caster:hasResource(ability.resource.type, ability.resource.cost) then
			return false, "insufficient_resources"
		end
	end

	if ability.targeting.type ~= "Self" then
		if not targetId then
			return false, "no_target"
		end

		local target = self:_resolveUnit(targetId)
		if not target then
			return false, "invalid_target"
		end

		if not target:canBeTargeted() then
			return false, "target_not_targetable"
		end

		local distance = (target.position - caster.position).Magnitude
		local range = ability.targeting.range or 10
		if distance > range then
			return false, "out_of_range"
		end

		if ability.targeting.type == "Enemy" then
			local UnitHelper = require(game.ReplicatedStorage.Helpers.UnitHelper)
			if not UnitHelper.areEnemies(caster.id, targetId) then
				return false, "not_enemy"
			end
		elseif ability.targeting.type == "Ally" then
			local UnitHelper = require(game.ReplicatedStorage.Helpers.UnitHelper)
			if UnitHelper.areEnemies(caster.id, targetId) then
				return false, "not_ally"
			end
		end
	end

	return true
end

function AbilityCaster:_resolveUnit(unitId: string)
	return self.attackSystem:_resolveUnit(unitId)
end

function AbilityCaster:cast(caster, abilityId: string, targetId: string?): CastResult
	local canCast, reason = self:canCast(caster, abilityId, targetId)
	if not canCast then
		return {
			success = false,
			reason = reason,
		}
	end

	local ability = Abilities.get(abilityId)
	if not ability then
		return {
			success = false,
			reason = "invalid_ability",
		}
	end

	if ability.resource then
		caster:spendResource(ability.resource.type, ability.resource.cost)
	end

	if ability.cooldown and ability.cooldown > 0 then
		caster:startCooldown(abilityId, ability.cooldown)
	end

	if ability.charges and ability.charges ~= nil and ability.charges ~= false then
		caster:consumeCharge(abilityId)
	end

	if ability.castTime and ability.castTime > 0 and not ability.instant then
		print("Beginning cast for " .. abilityId)
		caster:beginCast(abilityId, { targetId })
		task.wait(ability.castTime)

		if caster:isInterrupted() then
			caster:_exitCasting(true)
			return {
				success = false,
				reason = "interrupted",
			}
		end
	end

	local result = self:_executeAbility(caster, ability, targetId)

	if caster:isCasting() then
		caster:_exitCasting(false)
	end

	return result
end

function AbilityCaster:_executeAbility(caster, ability, targetId: string?): CastResult
	local results = {}
	local success = false

	local target = targetId and self:_resolveUnit(targetId) or caster
	if not target then
		return { success = false, reason = "invalid_target" }
	end

	-- Create context for effects
	local context = {
		ability = ability,
		attackSystem = self.attackSystem,
		caster = caster,
		target = target,
		projectileManager = ServerMod.projectileManager,
	}

	-- Execute each effect
	for _, effect in ipairs(ability.effects) do
		local effectSuccess = AbilityEffects.execute(effect.type, caster, target, effect, context)
		if effectSuccess then
			success = true
		end
	end

	return {
		success = success,
		damage = results.damage,
		heal = results.heal,
		meta = results.meta,
	}
end

return AbilityCaster
