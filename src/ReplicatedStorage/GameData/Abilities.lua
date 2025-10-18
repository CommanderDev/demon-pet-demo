local Schemas = require(game.ReplicatedStorage.Combat.Schemas)
local Enums = require(game.ReplicatedStorage.Enums)

export type AbilityConfig = Schemas.AbilityConfig
export type AbilitiesTable = { [string]: AbilityConfig }

local Templates = {
	MeleeAttack = {
		kind = "Attack",
		school = "Physical",
		cooldown = 0,
		targeting = { type = "Enemy", range = 10, maxTargets = 1 },
		instant = true,
		multiplier = 1.0,
		effects = { { type = "MeleeAttack" } },
		auto = { interval = NumberRange.new(1.2, 1.8) },
		ai = {
			positioning = Enums.AIPositioning.Melee,
			optimalRange = NumberRange.new(6, 10),
			priority = 3,
			useWhen = Enums.AIUseWhen.Always,
		},
	},

	RangedAttack = {
		kind = "Attack",
		cooldown = 5,
		charges = 1,
		multiplier = 1.5,
		resource = { type = "Mana", cost = 10 },
		targeting = { type = "Enemy", range = 30, maxTargets = 1 },
		castTime = 1,
		instant = true,
		effects = { { type = "ProjectileAttack" } },
		ai = {
			positioning = Enums.AIPositioning.KeepDistance,
			optimalRange = NumberRange.new(20, 25),
			priority = 6,
			useWhen = Enums.AIUseWhen.Always,
		},
	},

	Defensive = {
		kind = "Defense",
		cooldown = 10,
		charges = 1,
		resource = { type = "Mana", cost = 20 },
		targeting = { type = "Self" },
		instant = true,
		ai = {
			positioning = Enums.AIPositioning.Flexible,
			priority = 4,
			useWhen = Enums.AIUseWhen.LowHP,
		},
	},

	Control = {
		kind = "Control",
		cooldown = 12,
		multiplier = 0.8,
		resource = { type = "Mana", cost = 35 },
		targeting = { type = "Enemy", range = 20 },
		instant = true,
		effects = {
			{ type = "Interrupt" },
			{ type = "ApplyStatus", statusId = "SILENCE", duration = 2.5 },
		},
		ai = {
			positioning = Enums.AIPositioning.Flexible,
			priority = 7,
			useWhen = Enums.AIUseWhen.Always,
		},
	},
}

local function extendTemplate(template, overrides)
	local result = {}

	-- Deep copy template
	for key, value in pairs(template) do
		if type(value) == "table" and not value.Min then -- Not a NumberRange
			result[key] = table.clone(value)
		else
			result[key] = value
		end
	end

	for key, value in pairs(overrides) do
		if type(value) == "table" and type(result[key]) == "table" and not result[key].Min then
			for subKey, subValue in pairs(value) do
				result[key][subKey] = subValue
			end
		else
			result[key] = value
		end
	end

	return result
end

for _, template in pairs(Templates) do
	template.extend = extendTemplate
end

local Abilities: AbilitiesTable = {
	FIRE_BALL = Templates.RangedAttack:extend({
		id = "FIRE_BALL",
		name = "Fire Ball",
		icon = "rbxassetid://0",
		cooldown = 3,
		school = "Fire",
		targeting = { type = "Enemy", range = 40, maxTargets = 1 },
		castTime = 0.5,
		instant = true,
		multiplier = 1.8,
		resource = false,
		charges = false,
		effects = {
			{
				type = "ProjectileAttack",
				speed = 60,
				maxDistance = 500,
				hitRadius = 8,
				canPierce = false,
				visualEffectClass = "Fireball",
				visualEffectData = {
					size = Vector3.new(2, 2, 2),
					color = Color3.fromRGB(255, 100, 0),
					trailEnabled = true,
					particleEnabled = true,
				},
			},
		},
		tags = { "fire", "projectile" },
		auto = { interval = NumberRange.new(0.3, 0.8) },
		ai = {
			positioning = Enums.AIPositioning.KeepDistance,
			optimalRange = NumberRange.new(15, 35),
			priority = 3,
			useWhen = Enums.AIUseWhen.Always,
		},
	}),

	WATER_BALL = Templates.RangedAttack:extend({
		id = "WATER_BALL",
		name = "Water Ball",
		icon = "rbxassetid://0",
		school = "Water",
		cooldown = 3,
		instant = true,
		resource = false,
		charges = false,
		multiplier = 1.8,
		targeting = { type = "Enemy", range = 40, maxTargets = 1 },
		effects = {
			{
				type = "ProjectileAttack",
				speed = 60,
				maxDistance = 500,
				hitRadius = 6,
				canPierce = false,
				visualEffectClass = "Waterball",
				visualEffectData = {
					size = Vector3.new(2, 2, 2),
					color = Color3.fromRGB(0, 100, 255),
					trailEnabled = true,
					particleEnabled = true,
				},
			},
		},

		tags = { "water", "projectile" },
		auto = { interval = NumberRange.new(0.3, 0.8) },
		ai = {
			positioning = Enums.AIPositioning.KeepDistance,
			optimalRange = NumberRange.new(15, 35),
			priority = 3,
			useWhen = Enums.AIUseWhen.Always,
		},
	}),

	BASIC_STRIKE = Templates.MeleeAttack:extend({
		id = "BASIC_STRIKE",
		name = "Basic Strike",
		icon = "rbxassetid://0",
		cooldown = 0,
		targeting = { type = "Enemy", range = 15, maxTargets = 1 },
		instant = true,
		effects = {
			{ type = "MeleeAttack" },
		},
		tags = { "blockable" },
		auto = { interval = NumberRange.new(0.2, 0.5) },
		ai = {
			positioning = Enums.AIPositioning.Melee,
			optimalRange = NumberRange.new(8, 12),
			priority = 2,
		},
	}),

	FIRE_SLASH = Templates.RangedAttack:extend({
		id = "FIRE_SLASH",
		name = "Fire Slash",
		icon = "rbxassetid://1234567890",
		school = "Fire",
		cooldown = 8,
		multiplier = 1.3,
		resource = { type = "Mana", cost = 10 },
		targeting = { type = "Enemy", range = 12, maxTargets = 1 },
		castTime = 0.5,
		effects = {
			{ type = "MeleeAttack" },
			{ type = "Interrupt" },
			{ type = "ApplyStatus", statusId = "SILENCE", duration = 2.5 },
		},
		tags = { "interruptible" },
		ai = {
			positioning = Enums.AIPositioning.Flexible,
			optimalRange = NumberRange.new(8, 12),
			priority = 5,
		},
	}),

	ICE_SHIELD = Templates.Defensive:extend({
		id = "ICE_SHIELD",
		name = "Ice Shield",
		icon = "rbxassetid://1234567890",
		school = "Ice",
		resource = { type = "Mana", cost = 20 },
		targeting = { type = "Self", range = 10, maxTargets = 1 },
		castTime = 1,
		tags = { "interruptable" },
		effects = {
			{ type = "Shield", statusId = "ICE_SHIELD", duration = 5, potency = 100 },
		},
	}),

	MIND_BREAK = Templates.Control:extend({
		id = "MIND_BREAK",
		name = "Mind Break",
		icon = "rbxassetid://0",
		school = "Mind",
		tags = { "unblockable" },
	}),

	GUARD = Templates.Defensive:extend({
		id = "GUARD",
		name = "Guard",
		icon = "rbxassetid://1234567890",
		school = "Physical",
		resource = { type = "Mana", cost = 20 },
		targeting = { type = "Self", range = 10, maxTargets = 1 },
		castTime = 1,
		tags = { "blockable" },
		effects = {
			{ type = "Shield", statusId = "GUARD", duration = 5, potency = 100 },
		},
	}),

	STEAM_BURST = {
		id = "STEAM_BURST",
		name = "Steam Burst",
		icon = "rbxassetid://1234567890",
		kind = "Ultimate",
		school = "Ice",
		cooldown = 30,
		charges = 1,
		multiplier = 2.5,
		resource = { type = "DemonPower", cost = 100 },
		targeting = { type = "Enemy", range = 10, radius = 2, width = 1, maxTargets = 1 },
		castTime = 1,
		instant = true,
		tags = { "unblockable" },
		effects = {
			{ type = "Interrupt" },
			{ type = "MeleeAttack" },
		},
		ai = {
			positioning = Enums.AIPositioning.Flexible,
			priority = 9,
			useWhen = Enums.AIUseWhen.Emergency,
		},
	},

	GAIA = {
		id = "GAIA",
		name = "Gaia",
		icon = "rbxassetid://1234567890",
		kind = "Ultimate",
		school = "Earth",
		cooldown = 60,
		charges = 1,
		resource = { type = "DemonPower", cost = 100 },
		targeting = { type = "AoE", range = 10, radius = 4, width = 4, maxTargets = 4 },
		tags = { "unblockable" },
		effects = {
			{
				type = "Heal",
				formula = function(stats)
					return stats.HP * 1.5
				end,
			},
		},
		ai = {
			positioning = Enums.AIPositioning.Flexible,
			priority = 8,
			useWhen = Enums.AIUseWhen.LowHP,
		},
	},

	LIGHTNING_BOLT = Templates.RangedAttack:extend({
		id = "LIGHTNING_BOLT",
		name = "Lightning Bolt",
		icon = "rbxassetid://1234567890",
		school = "Lightning",
		multiplier = 1.8,
		cooldown = 6,
		resource = { type = "Mana", cost = 12 },
		targeting = { type = "Enemy", range = 25, maxTargets = 1 },
		effects = {
			{ type = "Chain", maxJumps = 3, jumpRange = 15, damageReduction = 0.8 },
		},
		ai = {
			priority = 7,
			optimalRange = NumberRange.new(18, 22),
		},
	}),

	TELEPORT_STRIKE = {
		id = "TELEPORT_STRIKE",
		name = "Teleport Strike",
		icon = "rbxassetid://1234567890",
		kind = "Attack",
		school = "Arcane",
		cooldown = 15,
		resource = { type = "Mana", cost = 25 },
		targeting = { type = "Enemy", range = 50, maxTargets = 1 },
		instant = true,
		multiplier = 2.0,
		effects = {
			{ type = "Teleport", range = 50 },
			{ type = "MeleeAttack" },
		},
		ai = {
			positioning = Enums.AIPositioning.Flexible,
			priority = 8,
			useWhen = Enums.AIUseWhen.SingleTarget,
		},
	},

	METEOR_STRIKE = {
		id = "METEOR_STRIKE",
		name = "Meteor Strike",
		icon = "rbxassetid://1234567890",
		kind = "Ultimate",
		school = "Fire",
		cooldown = 45,
		resource = { type = "DemonPower", cost = 100 },
		targeting = { type = "AoE", range = 20, radius = 8, maxTargets = 10 },
		castTime = 3,
		instant = false,
		multiplier = 3.5,
		effects = {
			{ type = "AoEDamage", radius = 8 },
			{ type = "ApplyStatus", statusId = "BURN", duration = 10 },
			{ type = "Knockback", distance = 5 },
		},
		ai = {
			positioning = Enums.AIPositioning.KeepDistance,
			priority = 10,
			useWhen = Enums.AIUseWhen.MultipleEnemies,
		},
	},

	SUMMON_MINION = {
		id = "SUMMON_MINION",
		name = "Summon Minion",
		icon = "rbxassetid://1234567890",
		kind = "Utility",
		school = "Necromancy",
		cooldown = 30,
		resource = { type = "Mana", cost = 40 },
		targeting = { type = "Self" },
		castTime = 2,
		instant = false,
		effects = {
			{ type = "Summon", unitType = "SKELETON_WARRIOR", count = 1, duration = 60 },
		},
		ai = {
			positioning = Enums.AIPositioning.Flexible,
			priority = 6,
			useWhen = Enums.AIUseWhen.MultipleEnemies,
		},
	},

	SLEEP_HEAL = {
		id = "SLEEP_HEAL",
		name = "Sleep Heal",
		icon = "rbxassetid://0",
		kind = "Utility",
		school = "Nature",
		cooldown = 0,
		targeting = { type = "Self" },
		instant = true,
		effects = {
			{
				type = "Heal",
				formula = function(stats)
					return (stats.HP or 100) * 0.05
				end,
			},
		},
	},
}

function Abilities.get(abilityId: string): AbilityConfig?
	return Abilities[abilityId]
end

function Abilities.getAll(): AbilitiesTable
	return Abilities
end

function Abilities.getByKind(kind: string): { AbilityConfig }
	local result = {}
	for _, ability in pairs(Abilities) do
		if ability.kind == kind then
			table.insert(result, ability)
		end
	end
	return result
end

function Abilities.getBySchool(school: string): { AbilityConfig }
	local result = {}
	for _, ability in pairs(Abilities) do
		if ability.school == school then
			table.insert(result, ability)
		end
	end
	return result
end

-- Abilities loaded

return Abilities
