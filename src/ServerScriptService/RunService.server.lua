local RunService = game:GetService("RunService")

local ServerMod = require(game.ServerScriptService.ServerMod)

local Common = require(game.ReplicatedStorage.Common)
local len, routine, wait = Common.len, Common.routine, Common.wait

local User = require(game.ServerScriptService.Entities.User)

local tickManagers = {}

local function loadManagers(): ()
	local startTime = os.clock()
	for _, managerInfo in ipairs(game.ServerScriptService.ServerManagers:GetChildren()) do
		local manager = require(managerInfo)
		if manager.init then
			manager:init()
		end
		routine(function()
			if manager.start then
				manager:start()
			end
		end)
		if manager.tick then
			table.insert(tickManagers, manager)
		end

		local key = managerInfo.Name
		key = string.sub(key, 1, 1):lower() .. string.sub(key, 2)
		ServerMod[key] = manager
	end
	local endTime = os.clock()
	print(string.format("Loaded Server Managers in %.2f seconds", endTime - startTime))
end

local function initFolders(): ()
	local workspaceFolders: { string } = {
		"UserRigs",
	}
	for _, folderName: string in ipairs(workspaceFolders) do
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = workspace
	end

	local replicatedStorageFolders: { string } = {
		"Events",
	}
	for _, folderName: string in pairs(replicatedStorageFolders) do
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = game.ReplicatedStorage
	end
end

local function addUser(player)
	if ServerMod.users[player.Name] then
		warn("ALREADY HAVE THIS USER", player.Name)
		return
	end

	local user = User.new(player)
	ServerMod.users[user.name] = user
	user:init()
end

local function onPlayerAdded(player)
	addUser(player)
end

local function onHeartbeat(dt: number): ()
	-- Tick all server managers
	for _, tickManager in pairs(tickManagers) do
		tickManager:tick(dt)
	end

	-- Tick all users (for party management, position updates, etc.)
	for _, user in pairs(ServerMod.users) do
		if user and user.tick then
			user:tick(dt)
		end
	end
end

initFolders()
loadManagers()

for _, player in pairs(game.Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
game.Players.PlayerAdded:Connect(onPlayerAdded)
RunService.Heartbeat:Connect(onHeartbeat)
