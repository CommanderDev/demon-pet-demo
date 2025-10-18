local Schemas = {}

-- Enumerations (string literal unions for clarity)
export type AbilityKind = "Attack" | "Defense" | "Control" | "Utility" | "Ultimate"
export type TargetType = "Self" | "Ally" | "Enemy" | "AoE" | "Cone" | "Chain"
export type EffectType = "Damage" | "Heal" | "Shield" | "ApplyStatus" | "Cleanse" | "Knockback" | "Interrupt"

-- Core stats used by DamageCalc
export type StatBlock = {
	HP: number,
	ATK: number,
	DEF: number,
	ARMOR: number,
	CritChance: number,
	CritMult: number,
	Haste: number,
}

export type ResourceCost = { type: "Mana" | "Energy" | "DemonPower", cost: number }
export type Targeting = {
	type: TargetType,
	range: number?,
	radius: number?,
	width: number?,
	maxTargets: number?,
}

export type Cooldown = number | NumberRange

export type EffectSpec = {
	type: EffectType,
	-- Optional formula string evaluated server-side (e.g., "ATK*1.2 + 15").
	formula: string?,
	statusId: string?,
	duration: number?,
	potency: number?,
	scaling: { stat: StatBlock, mult: number }?,
}

export type AIHints = {
	positioning: string?, -- AIPositioning enum: Melee, KeepDistance, Flexible
	optimalRange: NumberRange?, -- Preferred distance from target
	priority: number?, -- Higher = cast more often (0-10)
	useWhen: string?, -- AIUseWhen enum: Always, LowHP, MultipleEnemies, SingleTarget, Emergency
}

export type AbilityConfig = {
	id: string,
	name: string,
	icon: string?,
	kind: AbilityKind,
	school: string?, -- NEW (e.g. "Physical", "Fire", "Water")
	cooldown: Cooldown,
	charges: number?,
	resource: ResourceCost?,
	targeting: Targeting,
	castTime: number?,
	instant: boolean?,
	tags: { string }?, -- renamed from flags
	comboTags: { requires: { string }?, grants: { string }? }?,
	effects: { EffectSpec },
	auto: { interval: NumberRange }?, -- Auto-cast configuration
	ai: AIHints?, -- AI behavior hints
}

export type StatusConfig = {
	id: string,
	kind: "Buff" | "Debuff" | "DoT" | "HoT",
	tick: number?, -- for periodic effects
	base: string?, -- optional base formula per tick
	stacks: { max: number, behavior: "refresh" | "refresh_and_add" }?,
	dispellable: boolean?,
	school: string?,
}

export type UnitConfig = {
	id: string,
	name: string,
	rarity: string,
	stats: StatBlock,
	auto: { interval: NumberRange, abilityId: string },
	abilities: { string },
	tags: { string },
}

-- Utility: runtime, shared type guards
function Schemas.isNumberRange(v: any): boolean
	return typeof(v) == "NumberRange"
end

return Schemas
