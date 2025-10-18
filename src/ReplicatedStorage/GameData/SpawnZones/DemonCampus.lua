--[[
    Zone example:

    {
        id = "ExampleZone", -- the id the zone is dedicated to. Keep this the same as the one inside workspace.SpawnZones
        shape = { type = "circle", center = Vector3.zero, radius = 80}, -- How big the radius of the zone is.
        playerActivationRadius = 120, -- Only active if a player is within this radius
        maxAlive = 8, -- Zone tries to keep up to this many demons alive
        spawnBatch = 2, -- Spawn in small bursts until maxAlive is reached
        respawnDelay = 8, -- seconds after a unit dies before filling its slot
        minSeperation = 7, -- Keeps spawns at least this far apart
        roster = { -- The units that spawn and how frequently they spawn
            { unit = "GUARD", weight = 60},
            { unit = "EMBER_PUP", weight = 30},
            { unit = "AQUA_WISP", weight = 10}, 
        },
    }
]]

return {
	{
		id = "Courtyard",
		playerActivationRadius = 120,
		maxAlive = 8,
		spawnBatch = 2,
		respawnDelay = 8,
		minSeperation = 7,
		roster = {
			{ unit = "EMBER_PUP", weight = 60 },
			{ unit = "AQUA_WISP", weight = 30 },
			{ unit = "AEGIS_BEETLE", weight = 10 },
		},
	},

	{
		id = "Gym",
		playerActivationRadius = 120,
		maxAlive = 8,
		spawnBatch = 2,
		respawnDelay = 8,
		minSeperation = 7,
		roster = {
			{ unit = "EMBER_PUP", weight = 30 },
			{ unit = "AQUA_WISP", weight = 10 },
			{ unit = "AEGIS_BEETLE", weight = 60 },
		},
	},
}
