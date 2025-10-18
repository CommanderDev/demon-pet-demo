local Demon = require(game.ServerScriptService.Entities.Demon)

local DemonManager = {
	_entries = {},
}

function DemonManager:init(): () end

function DemonManager:spawnDemon(unit): ()
	local demon = Demon.new(unit)
	self._entries[unit.id] = demon

	if unit.onDied then
		unit.onDied:Connect(function()
			self:removeDemon(unit.id)
		end)
	end
end

function DemonManager:removeDemon(id: string): ()
	local demon = self._entries[id]
	if not demon then
		return
	end

	if demon.party then
		demon.party:removeMember(demon)
	end

	demon:destroy()

	self._entries[id] = nil
end

function DemonManager:getDemonById(id: number): ()
	return self._entries[id]
end

function DemonManager:tick(dt: number)
	for _, entry in pairs(self._entries) do
		entry:tick(dt)
	end
end

return DemonManager
