local RunService = game:GetService("RunService")

local player = game.Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local playerGui = player:WaitForChild("PlayerGui")

local ClientMod = require(playerScripts:WaitForChild("ClientMod"))

local Common = require(game.ReplicatedStorage.Common)

local len, routine, wait = Common.len, Common.routine, Common.wait

local tickManagers = {} -- Managers with a tick function
local renderManagers = {} -- Managers with a tickRender function

local function loadManagers(): ()
	local startTime = os.clock()

	local managers = playerScripts:WaitForChild("ClientManagers")

	for _, moduleInfo in ipairs(managers:GetChildren()) do
		local module = require(moduleInfo)
		if module.init then
			module:init()
		end
		routine(function()
			if module.start then
				module:start()
			end
		end)
		local moduleName = moduleInfo.Name
		local localSplit = string.split(moduleName, "Local")
		if localSplit then
			local key = localSplit[1]
			if key and #key > 0 then
				key = string.sub(key, 1, 1):lower() .. string.sub(key, 2)
				ClientMod[key] = module
			end
		end
		if module.tick then
			table.insert(tickManagers, module)
		end
		if module.tickRender then
			table.insert(renderManagers, module)
		end
	end

	local endTime = os.clock()
	print(string.format("Loaded Client Managers in %.2f seconds", endTime - startTime))
end

local function loadUsers(): ()
	ClientMod.userManager:addUser({
		name = player.Name,
		player = player,
	})
end

loadManagers()

RunService.Heartbeat:Connect(function(dt)
	for _, manager in pairs(tickManagers) do
		manager:tick(dt)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	for _, manager in pairs(renderManagers) do
		manager:tickRender(dt)
	end
end)

local root = script.Parent
local UITree = require(root.UI.Core.UITree)
local Diagnostics = require(root.UI.Core.Diagnostics)
local UI = UITree.new(playerGui)
local Diagnostics = Diagnostics.new(UI)
ClientMod.UI = UI
ClientMod.Diagnostics = Diagnostics
