local UPDATE_HZ: number = 60

local Zone = require(script.Parent.Zone)

local AmbientSpawner = {}
AmbientSpawner.__index = AmbientSpawner

function AmbientSpawner.new(zoneDatas)
	local self = setmetatable({}, AmbientSpawner)
	self.zones = {}
	for _, data in ipairs(zoneDatas or {}) do
		for _, zonePart in pairs(workspace.SpawnZones:GetChildren()) do
			if zonePart.Name == data.id then
				table.insert(self.zones, Zone.new(data, zonePart))
			end
		end
	end

	self._conn = nil
	self._accum = 0
	return self
end

function AmbientSpawner:tick(dt): ()
	self._accum += dt
	if self._accum >= (1 / UPDATE_HZ) then
		self._accum = 0
		for _, zone in ipairs(self.zones) do
			zone:tick()
		end
	end
end

return AmbientSpawner
