local SpawnZones = {}

for _, zone in pairs(script:GetChildren()) do
	local module = require(zone)
	SpawnZones[zone.Name] = module
end

return SpawnZones
