local PhysicsService = game:GetService("PhysicsService")
local players = game:GetService("Players")

local Common = require(game.ReplicatedStorage.Common)
local len, routine, wait = Common.len, Common.routine, Common.wait

local ServerMod = {
	step = 0,

	------ GLOBAL TABLES --------
	users = {},
	leaders = {},

	-- set as -1 first
	playerCount = -1,
}

function ServerMod:init()
	self:registerPhysics()
end

function ServerMod:tick(timeRatio)
	self.step += 1 * timeRatio
end

function ServerMod:registerPhysics()
	-- register groups
end

function ServerMod:refreshPlayerCount()
	local lst = players:GetPlayers()
	local count = len(lst)
	self.playerCount = count
end

function ServerMod:checkDeveloper(user)
	return Common.checkDeveloper(user.userId)
end

function ServerMod:getRandomPlayer(): Player
	local list = players:GetPlayers()
	return list[math.random(1, #list)]
end

function ServerMod:checkAdmin(user)
	return Common.checkAdmin(user.userId)
end

function ServerMod:FireClient(player, req, ...)
	self:FireClient_Default(player, req, ...)
end

function ServerMod:FireAllClients(req, ...)
	self:FireAllClients_Default(req, ...)
end

function ServerMod:FireClient_Default(player, ...)
	local event = game.ReplicatedStorage.Events.MainEvent
	event:FireClient(player, ...)
end

function ServerMod:InvokeClient(player, func, ...)
	local remoteFunction = self:getRemoteFunction(func)
	if not remoteFunction then
		warn("Remote function not found: " .. func)
		return
	end

	return remoteFunction:InvokeClient(player, ...)
end

function ServerMod:bindRemoteFunction(functionName: string, callback: (...any) -> ())
	local remoteFunction = self:getRemoteFunction(functionName)
	remoteFunction.OnServerInvoke = callback
end

function ServerMod:getRemoteFunction(functionName: string)
	local event = game.ReplicatedStorage.Events
	return event:FindFirstChild(functionName) or self:addRemoteFunction(functionName)
end

function ServerMod:getUserAsync(player)
	local user = self.users[player.Name]
	if not user then
		repeat
			task.wait()
			user = self.users[player.Name]
		until user
	end
	return user
end

function ServerMod:addRemoteFunction(functionName: string)
	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = functionName
	remoteFunction.Parent = game.ReplicatedStorage.Events
	return remoteFunction
end
function ServerMod:FireAllClients_Default(...)
	for _, player in pairs(players:GetPlayers()) do
		local user = ServerMod.users[player.Name]
		if not user then
			continue
		end

		local event = game.ReplicatedStorage.Events.MainEvent
		event:FireClient(player, ...)
	end
end

ServerMod:init()

return ServerMod
