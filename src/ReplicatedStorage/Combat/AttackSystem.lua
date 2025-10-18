local RunService = game:GetService("RunService")

local Signal = require(game.ReplicatedStorage.Libraries.Signal)

local UnitHelper = require(game.ReplicatedStorage.Helpers.UnitHelper)
local Abilities = require(game.ReplicatedStorage.GameData.Abilities)

local AttackSystem = {}
AttackSystem.__index = AttackSystem

export type AutoSpec = { interval: NumberRange, abilityId: string }
export type AttackData = {
	id: string,
	period: number,
	windup: number,
	recovery: number,
	range: number,
	maxTargets: number,
	damage: number,
}

local systems = {}

local DEFAULT_CRIT_CHANCE = 0.05
local DEFAULT_CRIT_MULT = 1.5

function AttackSystem.new(name)
	local self = setmetatable({}, AttackSystem)
	self.name = name or "AttackSystem"
	self._units = {}
	self.onDamage = Signal.new()
	self.onHit = Signal.new()
	self.onUnitRegistered = Signal.new()
	self.onUnitUnregistered = Signal.new()
	systems[self] = true
	return self
end

function AttackSystem:registerUnit(unit)
	assert(unit and unit.id, "registerUnit requires unit with id")
	self._units[unit.id] = {
		ref = unit,
		id = unit.id,
	}
	self.onUnitRegistered:Fire(unit.id)
end

function AttackSystem:unregisterUnit(unitId: string)
	if self._units[unitId] then
		self._units[unitId] = nil
		self.onUnitUnregistered:Fire(unitId)
	end
end

function AttackSystem:_resolveUnit(unitId: string): ()
	local cached = self._units[unitId]
	if not cached then
		print("AttackSystem:_resolveUnit - unit not found:", unitId, "total units:", self:_getRegisteredCount())
		return nil
	end

	if cached and cached.ref then
		if cached.ref.ref and cached.ref.ref.canBeTargeted then
			return cached.ref.ref
		else
			return cached.ref
		end
	end

	print("AttackSystem:_resolveUnit - cached but no ref:", unitId)
	return nil
end

function AttackSystem:getBaseAttackFor(unitId: string)
	local unit = self:_resolveUnit(unitId)
	if not unit then
		return
	end

	local base = {}

	if unit.stats and unit.stats.ATK then
		base.power = unit.stats.ATK
	else
		base.power = UnitHelper.getStat(unitId, "ATK") or 0
	end

	if unit.stats and unit.stats.CritChance then
		base.critChance = unit.stats.CritChance
	else
		base.critChance = UnitHelper.getStat(unitId, "critChance") or DEFAULT_CRIT_CHANCE
	end

	if unit.stats and unit.stats.CritMult then
		base.critMult = unit.stats.CritMult
	else
		base.critMult = UnitHelper.getStat(unitId, "critMult") or DEFAULT_CRIT_MULT
	end

	base.type = (unit.baseAttack and unit.baseAttack.type) or "Physical"
	base.pierce = (unit.baseAttack and unit.baseAttack.pierce) or 0

	return base
end

function AttackSystem:_computeDamage(attackerId: string, targetId: string, attackData)
	local attacker = self:_resolveUnit(attackerId)
	local target = self:_resolveUnit(targetId)
	if not attacker or not target then
		return 0, { reason = "invalid_unit" }
	end

	local baseAtk = attackData.base
		or self:getBaseAttackFor(attackerId)
		or { power = 0, critChance = 0, critMult = 0, type = "Physical", pierce = 0 }

	local abilityMult = attackData.abilityMultiplier or 1
	local raw = (baseAtk.power or 0) * abilityMult

	local critRoll = math.random()
	local isCrit = critRoll < (baseAtk.critChance or DEFAULT_CRIT_CHANCE)
	if isCrit then
		raw = raw * (baseAtk.critMult or DEFAULT_CRIT_MULT)
	end

	local defense = 0
	if target then
		defense = UnitHelper.getStat(targetId, "DEF") or UnitHelper.getStat(targetId, "ARMOR") or 0
	elseif target and target.defense then
		defense = target.defense
	end

	local pierce = baseAtk.pierce or 0
	local effectiveDefense = defense * (1 - pierce)
	local final = 0
	if (raw + effectiveDefense) > 0 then
		final = raw * (raw / (raw + effectiveDefense))
	else
		final = math.max(1, raw * 0.1)
	end

	final = math.floor(final + 0.5)
	if final < 0 then
		final = 0
	end

	local meta = {
		raw = raw,
		defense = defense,
		effectiveDefense = effectiveDefense,
		isCrit = isCrit,
		abilityId = attackData.abilityId,
		attackType = baseAtk.type,
	}

	return final, meta
end

function AttackSystem:applyDamage(targetId, sourceId, damage, meta)
	task.spawn(function()
		local applied = false
		applied = UnitHelper.applyDamage(targetId, damage, {
			source = sourceId,
			meta = meta,
		})

		local target = self:_resolveUnit(targetId)
		if target then
			target:takeDamage(damage, sourceId)
		elseif target and target.hp ~= nil then
			target.hp = math.max((target.hp or 0) - damage, 0)
		end

		self.onDamage:Fire(targetId, sourceId, damage, meta)
	end)
end

function AttackSystem:resolveHit(attackerId: string, targetId: string, attackData)
	local attacker = self:_resolveUnit(attackerId)
	local target = self:_resolveUnit(targetId)
	if not attacker or not target then
		return false, { reason = "invalid_unit" }
	end

	if UnitHelper.hasStatus and UnitHelper.hasStatus(targetId, "Invulnerable") then
		return false, { reason = "invulnerable" }
	end

	local evasion = (target.stats and target.stats.EVASION) or target.evasion or 0

	local accuracy = (attacker.stats and attacker.stats.ACCURACY) or attacker.accuracy or 1

	local baseHitChance = math.clamp(accuracy - evasion, 0.05, 0.99)
	local roll = math.random()
	local hit = roll < baseHitChance

	local info = { roll = roll, baseHitChance = baseHitChance, evasion = evasion, accuracy = accuracy }

	return hit, info
end

function AttackSystem:performAttack(attackerId: string, targetId: string, attackData)
	attackData = attackData or {}
	local attacker = self:_resolveUnit(attackerId)
	local target = self:_resolveUnit(targetId)
	if not attacker or not target then
		return false, { reason = "invalid_unit" }
	end

	-- Check if attacker is sleeping (can't attack)
	if attacker.sleeping then
		return false, { reason = "attacker_sleeping" }
	end

	-- Check if target is sleeping (can't be attacked)
	if target.sleeping then
		return false, { reason = "target_sleeping" }
	end

	local abilityId = attackData.abilityId
	local modAttackData = table.clone(attackData)

	local ability = Abilities.get(abilityId)
	if ability then
		if ability.multiplier then
			modAttackData.abilityMultiplier = (modAttackData.abilityMultiplier or 1) * ability.multiplier
		end
	end

	local hit, hitInfo = self:resolveHit(attackerId, targetId, modAttackData)
	if not hit then
		self.onHit:Fire(attackerId, targetId, { hit = false, info = hitInfo })
		return false, hitInfo
	end

	local damage, meta = self:_computeDamage(attackerId, targetId, modAttackData)
	meta.hitInfo = hitInfo

	self.onHit:Fire(attackerId, targetId, { hit = true, damage = damage, meta = meta })

	self:applyDamage(targetId, attackerId, damage, meta)
	return true, { damage = damage, meta = meta }
end

function AttackSystem:iterAll(): () -> ()
	local keys = {}
	for id, _ in pairs(self._units) do
		table.insert(keys, id)
	end

	local index = 0
	return function()
		index += 1
		local id = keys[index]
		if not id then
			return nil
		end
		return id, self._units[id].ref or self._units[id]
	end
end

function AttackSystem:iterEnemies(attackerId: string): () -> ()
	local keys = {}
	for id, _ in pairs(self._units) do
		if id ~= attackerId then
			table.insert(keys, id)
		end
	end

	local index: number = 0

	return function()
		while true do
			index += 1
			local id = keys[index]
			if not id then
				return
			end
			local ok = true
			if UnitHelper.areEnemies(attackerId, id) then
				return id, self._units[id].ref
			end
			-- Otherwise continue loop
		end
	end
end

function AttackSystem:performAoE(attackerId: string, radiusFn, attackData)
	for id, unit in self:iterAll() do
		local pass = false
		local ok, result = pcall(radiusFn, unit)
		if ok and result then
			pass = true
		end

		if pass then
			self:performAttack(attackerId, id, attackData)
		end
	end
end

function AttackSystem:_getRegisteredCount(): number
	local count = 0
	for _ in pairs(self._units) do
		count = count + 1
	end
	return count
end

function AttackSystem:destroy(): ()
	systems[self] = nil
	self.onDamage = nil
	self.onHit = nil
	self._units = nil
end

return AttackSystem
