local AbilityEffects = require(game.ReplicatedStorage.Combat.AbilityEffects)

AbilityEffects.register("DamageOverTime", function(caster, target, effect, context)
	local duration = effect.duration or 10
	local damagePerSecond = effect.damagePerSecond or 5
	target:applyStatus("DOT_" .. (effect.statusId or "BURN"), duration, caster.id)
	return true
end)

AbilityEffects.register("Projectile", function(caster, target, effect, context)
	local projectileSpeed = effect.speed or 50
	local projectileType = effect.projectileType or "FIREBALL"
	print("Creating " .. projectileType .. " projectile from " .. caster.id .. " to " .. target.id)
	return true
end)

AbilityEffects.register("CreateWall", function(caster, target, effect, context)
	local wallLength = effect.length or 10
	local wallHeight = effect.height or 5
	local wallDuration = effect.duration or 30
	local direction = (target.position - caster.position).Unit
	local wallCenter = caster.position + (direction * (wallLength / 2))
	print("Creating wall at " .. tostring(wallCenter) .. " for " .. wallDuration .. " seconds")
	return true
end)

AbilityEffects.register("PositionSwap", function(caster, target, effect, context)
	local maxRange = effect.maxRange or 30
	local distance = (target.position - caster.position).Magnitude
	if distance <= maxRange then
		local casterPos = caster.position
		caster.position = target.position
		target.position = casterPos
		return true
	end
	return false
end)

AbilityEffects.register("HealingZone", function(caster, target, effect, context)
	local radius = effect.radius or 10
	local healPerSecond = effect.healPerSecond or 20
	local duration = effect.duration or 15
	local center = effect.center or caster.position
	print("Creating healing zone at " .. tostring(center) .. " for " .. duration .. " seconds")
	return true
end)

AbilityEffects.register("DamageReflect", function(caster, target, effect, context)
	local reflectPercent = effect.reflectPercent or 50
	local duration = effect.duration or 10
	target:applyStatus("DAMAGE_REFLECT", duration, caster.id)
	return true
end)

return CustomEffects
