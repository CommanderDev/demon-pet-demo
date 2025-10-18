local LevelProgression = {}

function LevelProgression.getStatsByLevel(baseStats, level: number)
	local stats = table.clone(baseStats)
	for stat, value in pairs(stats) do
		if stat ~= "ACCURACY" and stat ~= "EVASION" then
			stats[stat] = value * (level * (1.1 ^ 5))
		end
	end
	return stats
end

return LevelProgression
