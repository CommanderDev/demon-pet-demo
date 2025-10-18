--!strict

local Schemas = require(game.ReplicatedStorage.Combat.Schemas)

export type StatusConfig = Schamas.StatusConfig
export type StatusesTable = { [string]: StatusConfig }

local Statuses: StatusesTable = {
	--============================================================
	-- Shields / Defensive
	--============================================================
	GUARD = {
		id = "GUARD",
		kind = "Buff",
		formula = 100,
		stacks = { max = 1, behavior = "refresh" },
		school = "Physical",
		tags = { "dispellable" },
	},

	--============================================================
	-- Debuffs / Control
	--============================================================

	SILENCE = {
		id = "SILENCE",
		kind = "Debuff",
		school = "Mind",
		stacks = { max = 1, behavior = "refresh" },
		tags = { "dispellable" },
	},

	--============================================================
	-- Damage over time
	--============================================================
	BURN = {
		id = "BURN",
		kind = "DoT",
		tick = 1.0,
		formula = function(stats): number
			return stats.ATK * 0.2 + 2
		end,
		stacks = { max = 3, behavior = "refresh_and_add" },
		school = "Fire",
		tags = { "dispellable" },
	},
	--============================================================
	-- Buffs
	--============================================================
	HASTE_UP = {
		id = "HASTE_UP",
		kind = "Buff",
		base = 0.2,
		stacks = { max = 1, behavior = "refresh" },
		school = "Aura",
		tags = { "dispellable" },
	},
}

return Statuses
