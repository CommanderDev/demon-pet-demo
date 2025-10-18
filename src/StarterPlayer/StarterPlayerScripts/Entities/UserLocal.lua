local debris = game:GetService("Debris")

local localPlayer = game.Players.LocalPlayer
local playerScripts = localPlayer.PlayerScripts
local playerGui = localPlayer.PlayerGui

local ClientMod = require(playerScripts.ClientMod)

local Common = require(game.ReplicatedStorage.Common)
local len, routine, wait = Common.len, Common.routine, Common.wait

local User = {}
User.__index = User

function User.new(data)
	local u = {}
	u.data = data

	setmetatable(u, User)
	return u
end

function User:init()
	local data = self.data
	for k, v in pairs(data) do
		self[k] = v
	end

	local player = self.player
	self.userId = player.UserId

	self:addCameraCons()
	self:addRigCons()

	routine(function()
		if self:isPlayerUser() then
			-- self:initGroupRank()
			-- make the server user
			ClientMod:FireServer("makeUser")
		end
	end)
end

function User:initGroupRank()
	if Common.isStudio then
		return
	end

	local player = self.player

	local role
	local startTime = os.clock()
	local success, err = pcall(function()
		role = player:GetRoleInGroup(Common.groupId)
	end)
	if not success then
		role = "Unknown"
	end

	-- local validRoleList = {
	-- 	"Tester",
	-- 	"Developer",
	-- 	"Asset",
	-- 	"Admin",
	-- 	"Owner",
	-- }
	-- if not Common.listContains(validRoleList, role) then
	-- 	player:Kick("You are not authorized to play on this game.")
	-- end

	print("GOT ROLE: ", role, " IN ", os.clock() - startTime, " SECONDS")
end

function User:addCameraCons()
	if not self:isPlayerUser() then
		return
	end

	local player = self.player

	player.CameraMinZoomDistance = 30
	player.CameraMaxZoomDistance = 30
	wait()
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 40 -- 80
end

function User:addRigCons()
	if game.PlaceId == Common.afkPlaceId then
		return
	end

	local player = self.player
	routine(function()
		--local rig = player.Character or player.CharacterAdded:Wait()
		--self:respawn(rig)
	end)
	player.CharacterAdded:Connect(function(rig)
		--self:respawn(rig)
	end)
end

function User:respawn(rig)
	local rootPart = rig:FindFirstChild("HumanoidRootPart")
	local humanoid = rig:FindFirstChild("Humanoid")

	self.rootPart = rootPart
	self.humanoid = humanoid
	self.rig = rig

	self.currFrame = rootPart.CFrame

	-- clear trackMods for animUtils
	self.trackMods = nil
	self.raceTrackMods = nil
	self.animationGroupIndexMap = nil
end

function User:animateJump()
	local rootPart = self.rootPart
	if not rootPart then
		return
	end

	local emitterModel = ClientMod.spellUtils:createEmitterModel({
		spellClass = "DashDust",
	})
	emitterModel.PrimaryPart.Transparency = 1
	emitterModel:PivotTo(CFrame.new(rootPart.Position - Vector3.new(0, 2, 0)))
	debris:AddItem(emitterModel, 4)

	local scale = 1.5 -- 1 (orig) -- 0.5
	ClientMod.spellUtils:shootEmitter({
		emitterModel = emitterModel,
		scale = scale,
	})

	ClientMod.animUtils:animate(self, {
		race = "DoubleJump",
		animationClass = "DoubleJump",
	})
end

function User:tick(timeRatio)
	self:tickCurrFrame(timeRatio)
end

function User:isPlayerUser()
	return self.name == localPlayer.Name
end

function User:tickCurrFrame(timeRatio)
	local rootPart = self.rootPart
	if not rootPart then
		return
	end

	local newCurrFrame = rootPart.CFrame
	self.currFrame = newCurrFrame
end

-- only works if isPlayerUser
function User:finishInit()
	self.initialized = true
end

function User:destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true

	ClientMod.users[self.name] = nil
end

return User
