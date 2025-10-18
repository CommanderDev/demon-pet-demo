local Dungeons = {}

for _, dungeon in pairs(script:GetChildren()) do
	Dungeons[dungeon.Name] = require(dungeon)
end

return Dungeons
