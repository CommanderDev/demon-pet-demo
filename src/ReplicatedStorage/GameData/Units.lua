local Schemas = require(game.ReplicatedStorage.Combat.Schemas)

export type UnitConfig = Schemas.UnitConfig
export type UnitsTable = { [string]: UnitConfig }

local Units: UnitsTable = {
	EMBER_PUP = {
		id = "EMBER_PUP",
		name = "Ember Pup",
		rarity = "Common",
		stats = {
			HP = 150,
			ATK = 80,
			DEF = 30,
			ARMOR = 20,
			CritChance = 0.1,
			CritMult = 1.5,
			Haste = 0.0,
			ACCURACY = 1,
			EVASION = 0,
		},
		abilities = {
			"FIRE_BALL",
			"BASIC_STRIKE",
		},
		tags = { "student", "melee", "fire" },
	},
	AQUA_WISP = {
		id = "AQUA_WISP",
		name = "Aqua Wisp",
		rarity = "Rare",
		stats = {
			HP = 300,
			ATK = 80,
			DEF = 30,
			ARMOR = 20,
			CritChance = 0.1,
			CritMult = 1.5,
			Haste = 0.0,
			ACCURACY = 1,
			EVASION = 0,
		},
		abilities = {
			"FIRE_BALL",
			"BASIC_STRIKE",
		},
		tags = { "student", "caster", "water", "support" },
	},

	AEGIS_BEETLE = {
		id = "AEGIS_BEETLE",
		name = "Aegis Beetle",
		rarity = "Rare",
		stats = {
			HP = 500,
			ATK = 60,
			DEF = 60,
			ARMOR = 35,
			CritChance = 0.05,
			CritMult = 1.35,
			Haste = -0.05,
			ACCURACY = 1,
			EVASION = 0,
		},
		abilities = {
			"FIRE_BALL",
			"BASIC_STRIKE",
		},
		tags = { "demon", "tank", "earth" },
	},

	WATER_HOUND = {
		id = "WATER_HOUND",
		name = "Water Hound",
		rarity = "Legendary",
		stats = {
			HP = 500,
			ATK = 60,
			DEF = 60,
			ARMOR = 35,
			CritChance = 0.05,
			CritMult = 1.35,
			Haste = -0.05,
			ACCURACY = 1,
			EVASION = 0,
		},
		abilities = {
			"WATER_BALL",
			"BASIC_STRIKE",
		},
		tags = { "demon", "tank", "earth" },
	},
}

function Units.get(id: string): UnitConfig?
	return Units[id]
end

return Units
