local AbilityEffects = {}

local effectHandlers = {}

function AbilityEffects.register(effectName: string, handler: (any, any, any, any) -> ())
	if effectHandlers[effectName] then
		warn("Effect handler already registered: " .. effectName)
	end
	effectHandlers[effectName] = handler
end

function AbilityEffects.execute(effectName: string, caster, target, effect, context)
	local handler = effectHandlers[effectName]
	if not handler then
		warn("No effect handler registered for: " .. effectName)
		return false
	end

	local success, result = pcall(handler, caster, target, effect, context)
	if not success then
		warn("Effect handler failed for " .. effectName .. ": " .. tostring(result))
		return false
	end

	return result ~= false
end

AbilityEffects.register("ProjectileAttack", function(caster, target, effect, context)
	local Projectile = require(game.ServerScriptService.Entities.Projectile)

	local projectileData = {
		caster = caster,
		target = target,
		startPosition = caster.position,
		endPosition = target.position,
		speed = effect.speed or 50,
		maxDistance = effect.maxDistance or 1000,
		hitRadius = effect.hitRadius or 5,
		canPierce = effect.canPierce or false,
		maxPierceTargets = effect.maxPierceTargets or 1,
		visualEffectClass = effect.visualEffectClass or "BasicProjectile",
		visualEffectData = effect.visualEffectData or {},
	}

	local projectile = Projectile.new(projectileData)

	projectile.onHit:Connect(function(hitData)
		if effect.onHitCallback then
			effect.onHitCallback(hitData, context)
		else
			local attackData = {
				abilityId = context.ability.id,
				abilityMultiplier = context.ability.multiplier or 1,
			}
			context.attackSystem:performAttack(caster.id, hitData.target.id, attackData)
		end
	end)

	projectile.onReachDestination:Connect(function(data)
		if effect.onReachDestinationCallback then
			effect.onReachDestinationCallback(data, context)
		end
	end)

	projectile.onDestroy:Connect(function(data)
		if effect.onDestroyCallback then
			effect.onDestroyCallback(data, context)
		end
	end)

	if context.projectileManager then
		context.projectileManager:addProjectile(projectile)
	else
		warn("No projectile manager found in context")
	end

	return true
end)

AbilityEffects.register("MeleeAttack", function(caster, target, effect, context)
	local attackData = {
		abilityId = context.ability.id,
		abilityMultiplier = context.ability.multiplier or 1,
	}
	return context.attackSystem:performAttack(caster.id, target.id, attackData)
end)

AbilityEffects.register("Heal", function(caster, target, effect, context)
	local healAmount = effect.amount or 0

	if healAmount == 0 and effect.formula and type(effect.formula) == "function" then
		healAmount = effect.formula(caster.stats or {})
	end

	target:heal(healAmount)
	return true
end)

AbilityEffects.register("Shield", function(caster, target, effect, context)
	if effect.statusId then
		target:applyStatus(effect.statusId, effect.duration or 5, caster.id)
	end
	return true
end)

AbilityEffects.register("ApplyStatus", function(caster, target, effect, context)
	if effect.statusId then
		target:applyStatus(effect.statusId, effect.duration or 5, caster.id)
	end
	return true
end)

AbilityEffects.register("Interrupt", function(caster, target, effect, context)
	if target:isCasting() then
		target:cancelCast()
	end
	return true
end)

AbilityEffects.register("Cleanse", function(caster, target, effect, context)
	return true
end)

AbilityEffects.register("Knockback", function(caster, target, effect, context)
	local distance = effect.distance or 10
	local direction = (target.position - caster.position).Unit
	target.position = target.position + (direction * distance)
	return true
end)

AbilityEffects.register("Teleport", function(caster, target, effect, context)
	local destination = effect.position or target.position
	local range = effect.range or 50
	if (destination - caster.position).Magnitude <= range then
		caster.position = destination
		return true
	end
	return false
end)

AbilityEffects.register("Summon", function(caster, target, effect, context)
	local unitType = effect.unitType or "BASIC_DEMON"
	local count = effect.count or 1
	local duration = effect.duration or 30
	print("Summoning " .. count .. " " .. unitType .. " for " .. duration .. " seconds")
	return true
end)

AbilityEffects.register("AoEDamage", function(caster, target, effect, context)
	local radius = effect.radius or 10
	local center = effect.center or target.position
	for unitId, unit in context.attackSystem:iterAll() do
		if unitId ~= caster.id then
			local distance = (unit.position - center).Magnitude
			if distance <= radius then
				local attackData = {
					abilityId = context.ability.id,
					abilityMultiplier = context.ability.multiplier or 1,
				}
				context.attackSystem:performAttack(caster.id, unitId, attackData)
			end
		end
	end
	return true
end)

AbilityEffects.register("Chain", function(caster, target, effect, context)
	local maxJumps = effect.maxJumps or 3
	local jumpRange = effect.jumpRange or 15
	local damageReduction = effect.damageReduction or 0.8
	local currentTarget = target
	local damageMultiplier = 1.0

	for i = 1, maxJumps do
		local attackData = {
			abilityId = context.ability.id,
			abilityMultiplier = (context.ability.multiplier or 1) * damageMultiplier,
		}
		context.attackSystem:performAttack(caster.id, currentTarget.id, attackData)

		local nextTarget = nil
		local nearestDistance = math.huge
		for unitId, unit in context.attackSystem:iterEnemies(caster.id) do
			if unitId ~= currentTarget.id then
				local distance = (unit.position - currentTarget.position).Magnitude
				if distance <= jumpRange and distance < nearestDistance then
					nearestDistance = distance
					nextTarget = unit
				end
			end
		end

		if not nextTarget then
			break
		end
		currentTarget = nextTarget
		damageMultiplier = damageMultiplier * damageReduction
	end
	return true
end)

return AbilityEffects
