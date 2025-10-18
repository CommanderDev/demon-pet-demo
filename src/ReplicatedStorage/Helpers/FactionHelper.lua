local FactionHelper = {}

FactionHelper.Relation = {
	ALLY = "Ally",
	NEUTRAL = "Neutral",
	HOSTILE = "Hostile",
}

local FactionCategory = {
	NEUTRAL = "Neutral",
	WILD = "Wild",
	PLAYER = "Player",
	DUNGEON = "Dungeon_Enemy",
	BOSS = "Boss",
}

FactionHelper.PVP_ENABLED = false

local hostilityRules = {
	[FactionCategory.NEUTRAL] = {
		[FactionCategory.NEUTRAL] = false,
		[FactionCategory.WILD] = false,
		[FactionCategory.PLAYER] = false,
		[FactionCategory.DUNGEON] = false,
		[FactionCategory.BOSS] = false,
	},
	[FactionCategory.WILD] = {
		[FactionCategory.NEUTRAL] = false,
		[FactionCategory.WILD] = false,
		[FactionCategory.PLAYER] = true,
		[FactionCategory.DUNGEON] = false,
		[FactionCategory.BOSS] = false,
	},
	[FactionCategory.PLAYER] = {
		[FactionCategory.NEUTRAL] = false,
		[FactionCategory.WILD] = true,
		[FactionCategory.PLAYER] = "CHECK_TEAM",
		[FactionCategory.DUNGEON] = true,
		[FactionCategory.BOSS] = true,
	},
	[FactionCategory.DUNGEON] = {
		[FactionCategory.NEUTRAL] = false,
		[FactionCategory.WILD] = false,
		[FactionCategory.PLAYER] = true,
		[FactionCategory.DUNGEON] = false,
		[FactionCategory.BOSS] = false,
	},
	[FactionCategory.BOSS] = {
		[FactionCategory.NEUTRAL] = false,
		[FactionCategory.WILD] = false,
		[FactionCategory.PLAYER] = true,
		[FactionCategory.DUNGEON] = false,
		[FactionCategory.BOSS] = false,
	},
}

function FactionHelper.getFactionCategory(faction: string): string
	if not faction then
		return FactionCategory.NEUTRAL
	end

	for _, category in pairs(FactionCategory) do
		if faction == category then
			return category
		end
	end

	local prefix = string.match(faction, "^([^_]+)_")
	if prefix then
		for _, category in pairs(FactionCategory) do
			if prefix == category then
				return category
			end
		end
	end

	return faction
end

function FactionHelper.areHostile(faction1: string, faction2: string): boolean
	if not faction1 or not faction2 then
		return false
	end

	if faction1 == faction2 then
		return false
	end

	local category1 = FactionHelper.getFactionCategory(faction1)
	local category2 = FactionHelper.getFactionCategory(faction2)

	local rule = hostilityRules[category1] and hostilityRules[category1][category2]

	if rule == nil then
		return category1 ~= category2
	elseif rule == "CHECK_TEAM" then
		return FactionHelper.PVP_ENABLED and faction1 ~= faction2
	elseif type(rule) == "boolean" then
		return rule
	end

	return false
end

function FactionHelper.getRelation(faction1: string, faction2: string): string
	if faction1 == faction2 then
		return FactionHelper.Relation.ALLY
	end

	if FactionHelper.areHostile(faction1, faction2) then
		return FactionHelper.Relation.HOSTILE
	end

	return FactionHelper.Relation.NEUTRAL
end

function FactionHelper.isNeutral(faction: string): boolean
	return faction == FactionCategory.NEUTRAL
end

function FactionHelper.addHostilityRule(category1: string, category2: string, hostile: boolean): ()
	if not hostilityRules[category1] then
		hostilityRules[category1] = {}
	end
	hostilityRules[category1][category2] = hostile
end

return FactionHelper
