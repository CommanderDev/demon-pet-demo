local player = game.Players.LocalPlayer
local playerScripts = player.PlayerScripts
local DemonLocal = require(playerScripts.Entities.DemonLocal)

local DemonManager = {
	_entries = {},
}

function DemonManager:init(): () end

function DemonManager:syncDemon(data: { any }): ()
	local isNew = not self._entries[data.id]

	if isNew then
		self._entries[data.id] = DemonLocal.new(data)
	end
	self._entries[data.id]:sync(data)
end

function DemonManager:destroyDemon(data: { any }): ()
	local demon = self._entries[data.id]
	if not demon then
		return
	end

	-- Clean up the demon visual
	demon:destroy()

	-- Remove from registry
	self._entries[data.id] = nil
end

function DemonManager:onAttackHit(data: { any }): ()
	-- data contains: attackerId, targetId, hitPayload
	local attackerId = data.attackerId
	local hitPayload = data.hitPayload

	if not attackerId or not hitPayload then
		return
	end

	-- Only play animation on successful hits
	if not hitPayload.hit then
		return
	end

	local demon = self._entries[attackerId]
	if demon then
		demon:playAttackAnimation()
	end
end

function DemonManager:getDemonById(id: string)
	return self._entries[id]
end

function DemonManager:tick(dt: number): ()
	for _, demon in pairs(self._entries) do
		demon:tick(dt)
	end
end

return DemonManager
