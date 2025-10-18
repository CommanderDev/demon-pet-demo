local ServerMod = require(game.ServerScriptService.ServerMod)

local Common = require(game.ReplicatedStorage.Common)

local ServerEventManager = {}

function ServerEventManager:init(): ()
	self:addMainEvent()
	self:addCons()
end

function ServerEventManager:addMainEvent(): ()
	local event = Instance.new("RemoteEvent")
	event.Name = "MainEvent"
	event.Parent = game.ReplicatedStorage.Events
	self.mainEvent = event
end

function ServerEventManager:addCons(): ()
	local event = self.mainEvent
	event.OnServerEvent:Connect(function(player: Player, request: string, ...): ()
		local fullData = { ... }
		local data = fullData[1]
		self:handleRequest(player, request, data)
	end)
end

function ServerEventManager:handleRequest(player: Player, request: string, data: { any }): () end

return ServerEventManager
