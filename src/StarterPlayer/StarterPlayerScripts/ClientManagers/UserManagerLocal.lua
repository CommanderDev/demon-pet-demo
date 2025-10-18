local player = game.Players.LocalPlayer
local playerScripts = player.PlayerScripts
local playerGui = player.PlayerGui

local ClientMod = require(playerScripts.ClientMod)

local Common = require(game.ReplicatedStorage.Common)
local len, routine, wait = Common.len, Common.routine, Common.wait

local User = require(playerScripts.Entities.UserLocal)

local UserManager = {}

function UserManager:init() end

function UserManager:addUser(data)
	local name = data["name"]
	if not name then
		return
	end

	local user = ClientMod.users[name]
	if user then
		-- warn("USER ALREADY EXISTS: " .. name)
		return
	end

	user = User.new(data)
	ClientMod.users[data["name"]] = user
	user:init()

	-- ClientMod.shopManager:updateGiftMod({
	-- 	userId = user.userId,
	-- 	userName = user.name,
	-- })
end

function UserManager:removeUser(data)
	local name = data["name"]
	local user = ClientMod.users[name]
	if not user then
		warn("USER NOT FOUND: " .. name)
		return
	end

	user:destroy()
end

UserManager:init()

return UserManager
