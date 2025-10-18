local PartyGroups = require(game.ReplicatedStorage.GameData.PartyGroups)

return {
	levels = {
		-- Early waves using existing party groups
		[1] = PartyGroups["Group_Mob_1"], -- Ember Pups (Level 1)
		[2] = PartyGroups["Group_Mob_2"], -- Aqua Wisps (Level 5)
		[3] = PartyGroups["Group_Mob_3"], -- Aegis Beetles (Level 10)

		-- Scaling waves with mixed units
		[4] = {
			roster = {
				{ unit = "EMBER_PUP", level = 15 },
				{ unit = "AQUA_WISP", level = 15 },
				{ unit = "EMBER_PUP", level = 15 },
			},
		},
		[5] = {
			roster = {
				{ unit = "AQUA_WISP", level = 18 },
				{ unit = "AEGIS_BEETLE", level = 18 },
				{ unit = "AQUA_WISP", level = 18 },
			},
		},
		[6] = {
			roster = {
				{ unit = "AEGIS_BEETLE", level = 20 },
				{ unit = "EMBER_PUP", level = 20 },
				{ unit = "AEGIS_BEETLE", level = 20 },
			},
		},
		[7] = {
			roster = {
				{ unit = "EMBER_PUP", level = 22 },
				{ unit = "AQUA_WISP", level = 22 },
				{ unit = "AEGIS_BEETLE", level = 22 },
				{ unit = "EMBER_PUP", level = 22 },
			},
		},
		[8] = {
			roster = {
				{ unit = "AQUA_WISP", level = 25 },
				{ unit = "AEGIS_BEETLE", level = 25 },
				{ unit = "AQUA_WISP", level = 25 },
				{ unit = "AEGIS_BEETLE", level = 25 },
			},
		},
		[9] = {
			roster = {
				{ unit = "AEGIS_BEETLE", level = 28 },
				{ unit = "EMBER_PUP", level = 28 },
				{ unit = "AQUA_WISP", level = 28 },
				{ unit = "AEGIS_BEETLE", level = 28 },
			},
		},
		[10] = {
			roster = {
				{ unit = "EMBER_PUP", level = 30 },
				{ unit = "AQUA_WISP", level = 30 },
				{ unit = "AEGIS_BEETLE", level = 30 },
				{ unit = "EMBER_PUP", level = 30 },
				{ unit = "AQUA_WISP", level = 30 },
			},
		},
		[11] = {
			roster = {
				{ unit = "AQUA_WISP", level = 32 },
				{ unit = "AEGIS_BEETLE", level = 32 },
				{ unit = "EMBER_PUP", level = 32 },
				{ unit = "AQUA_WISP", level = 32 },
				{ unit = "AEGIS_BEETLE", level = 32 },
			},
		},
		[12] = {
			roster = {
				{ unit = "AEGIS_BEETLE", level = 35 },
				{ unit = "EMBER_PUP", level = 35 },
				{ unit = "AQUA_WISP", level = 35 },
				{ unit = "AEGIS_BEETLE", level = 35 },
				{ unit = "EMBER_PUP", level = 35 },
			},
		},
		[13] = {
			roster = {
				{ unit = "EMBER_PUP", level = 38 },
				{ unit = "AQUA_WISP", level = 38 },
				{ unit = "AEGIS_BEETLE", level = 38 },
				{ unit = "EMBER_PUP", level = 38 },
				{ unit = "AQUA_WISP", level = 38 },
				{ unit = "AEGIS_BEETLE", level = 38 },
			},
		},
		[14] = {
			roster = {
				{ unit = "AQUA_WISP", level = 40 },
				{ unit = "AEGIS_BEETLE", level = 40 },
				{ unit = "EMBER_PUP", level = 40 },
				{ unit = "AQUA_WISP", level = 40 },
				{ unit = "AEGIS_BEETLE", level = 40 },
				{ unit = "EMBER_PUP", level = 40 },
			},
		},
		[15] = {
			roster = {
				{ unit = "AEGIS_BEETLE", level = 42 },
				{ unit = "EMBER_PUP", level = 42 },
				{ unit = "AQUA_WISP", level = 42 },
				{ unit = "AEGIS_BEETLE", level = 42 },
				{ unit = "EMBER_PUP", level = 42 },
				{ unit = "AQUA_WISP", level = 42 },
			},
		},
		[16] = {
			roster = {
				{ unit = "EMBER_PUP", level = 45 },
				{ unit = "AQUA_WISP", level = 45 },
				{ unit = "AEGIS_BEETLE", level = 45 },
				{ unit = "EMBER_PUP", level = 45 },
				{ unit = "AQUA_WISP", level = 45 },
				{ unit = "AEGIS_BEETLE", level = 45 },
				{ unit = "EMBER_PUP", level = 45 },
			},
		},
		[17] = {
			roster = {
				{ unit = "AQUA_WISP", level = 48 },
				{ unit = "AEGIS_BEETLE", level = 48 },
				{ unit = "EMBER_PUP", level = 48 },
				{ unit = "AQUA_WISP", level = 48 },
				{ unit = "AEGIS_BEETLE", level = 48 },
				{ unit = "EMBER_PUP", level = 48 },
				{ unit = "AQUA_WISP", level = 48 },
			},
		},
		[18] = {
			roster = {
				{ unit = "AEGIS_BEETLE", level = 50 },
				{ unit = "EMBER_PUP", level = 50 },
				{ unit = "AQUA_WISP", level = 50 },
				{ unit = "AEGIS_BEETLE", level = 50 },
				{ unit = "EMBER_PUP", level = 50 },
				{ unit = "AQUA_WISP", level = 50 },
				{ unit = "AEGIS_BEETLE", level = 50 },
			},
		},
		[19] = {
			roster = {
				{ unit = "EMBER_PUP", level = 52 },
				{ unit = "AQUA_WISP", level = 52 },
				{ unit = "AEGIS_BEETLE", level = 52 },
				{ unit = "EMBER_PUP", level = 52 },
				{ unit = "AQUA_WISP", level = 52 },
				{ unit = "AEGIS_BEETLE", level = 52 },
				{ unit = "EMBER_PUP", level = 52 },
				{ unit = "AQUA_WISP", level = 52 },
			},
		},
		[20] = {
			roster = {
				{ unit = "AQUA_WISP", level = 55 },
				{ unit = "AEGIS_BEETLE", level = 55 },
				{ unit = "EMBER_PUP", level = 55 },
				{ unit = "AQUA_WISP", level = 55 },
				{ unit = "AEGIS_BEETLE", level = 55 },
				{ unit = "EMBER_PUP", level = 55 },
				{ unit = "AQUA_WISP", level = 55 },
				{ unit = "AEGIS_BEETLE", level = 55 },
			},
		},
	},

	worldPosition = Vector3.new(1000, 50, 1000),
}
