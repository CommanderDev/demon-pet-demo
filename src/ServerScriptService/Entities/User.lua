type NotifyMod = {
	txt: string,
	notifyClass: string,
	duration: number,
}
local PolicyService = game:GetService("PolicyService")

local ServerMod = require(game.ServerScriptService.ServerMod)
local Store = require(game.ServerScriptService.SaveModules.Store)

local Common = require(game.ReplicatedStorage.Common)
local len, routine, wait = Common.len, Common.routine, Common.wait

local User = {}
User.__index = User

function User.new(player)
	local u = {}
	u.player = player
	u.name = player.Name
	u.id = player.UserId
	u.respawnTimer = 1

	setmetatable(u, User)
	return u
end
function User:init(): ()
	local player = self.player
	self.userId = player.UserId
	self.displayName = player.DisplayName
	self.user = self

	self._tickManagers = {}

	self:initPlayer()

	routine(function()
		local startTime = os.clock()
		self:initAllModules()
		if ServerMod:checkDeveloper(self) then
			print("#### TIME TO INIT ALL MODULES:", endTime - startTime)
		end

		self:addRigCons()
		self.initialized = true

		local data = {}
		ServerMod:FireClient(self.player, "finishUserInit", data)

		self:syncAllGlobalMods()
	end)
end

function User:notifySuccess(txt: string, duration: number): ()
	local data: NotifyMod = {
		txt = txt,
		notifyClass = "Success",
		duration = duration,
	}
	ServerMod:FireClient(self.player, "addNotify", data)
end

function User:notifyError(txt: string, duration: number): ()
	local data: NotifyMod = {
		txt = txt,
		notifyClass = "BasicError",
		duration = duration,
	}
	ServerMod:FireClient(self.player, "addNotify", data)
end

function User:initPlayer()
	local success, policyMod = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(self.player)
	end)
	if success then
		self.policyMod = policyMod
	end
end

function User:addRigCons(): ()
	local player = self.player

	local function onCharacterAdded(rig: Model)
		self:respawn(rig)
	end

	routine(function()
		local rig = player.Character or player.CharacterAdded:Wait()
		onCharacterAdded(rig)
	end)
	player.CharacterAdded:Connect(onCharacterAdded)
end

function User:respawn(rig: Model): ()
	self.rig = rig
	rig.Parent = workspace.UserRigs

	local humanoid = self.rig:FindFirstChild("Humanoid")
	self.humanoid = humanoid

	local rootPart = rig:FindFirstChild("HumanoidRootPart")
	self.rootPart = rootPart

	self:setWalkSpeed(30)

	self:addHumanoidCons()
end

function User:addHumanoidCons()
	local humanoid = self.humanoid
	if not humanoid then
		return
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	self:refreshWalkspeed()

	humanoid.Died:Connect(function()
		wait(self.respawnTimer)
		self:preventMemoryLeak()
		self.player:LoadCharacter()
	end)
	self.humanoid = humanoid
end

function User:refreshWalkspeed()
	local newWalkspeed = self.walkSpeed

	local humanoid = self.humanoid
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = newWalkspeed
end

function User:setWalkSpeed(newWalkspeed): ()
	self.walkSpeed = newWalkspeed
end

function User:getWalkSpeed(): number
	return self.walkSpeed
end

function User:tickCurrFrame(): ()
	local rootPart = self.rootPart
	if rootPart then
		local currFrame = rootPart.CFrame
		self.currFrame = currFrame
	end
	local humanoid = self.humanoid
	if humanoid then
		humanoid.WalkSpeed = self:getWalkSpeed()
	end
end

function User:initAllModules(): ()
	if self.destroyed then
		return
	end

	local store = Store.new(self)
	store:init()
	self.store = store

	for _, managerInfo in ipairs(game.ServerScriptService.UserManagers:GetChildren()) do
		local manager = require(managerInfo).new(self)
		manager.moduleAlias = managerInfo.Name:sub(1, 1):lower() .. managerInfo.Name:sub(2)
		if manager.init then
			manager:init(self)
		end
		if manager.tick then
			table.insert(self._tickManagers, manager)
		end
		local key = manager.moduleAlias
		self[key] = manager
	end

	for _, manager in pairs(self) do
		if type(manager) == "table" and manager.start then
			task.spawn(function()
				manager:start()
			end)
		end
	end

	self.store:toggleSave(true)
end

function User:tick(dt: number): ()
	for _, manager in pairs(self._tickManagers) do
		manager:tick(dt)
	end
end

function User:sync(otherUser): ()
	local data = {
		name = self.name,
		player = self.player,
	}
	ServerMod:FireClient(otherUser.player, "addGlobalUser", data)
end

function User:syncAllGlobalMods()
	if self.destroyed then
		return
	end
	self:sync(self)

	for _, otherUser in pairs(ServerMod.users) do
		if otherUser == self or not otherUser.initialized or otherUser.destroyed then
			continue
		end
		otherUser:sync(self)
		self:sync(otherUser)
	end

	for _, leader in pairs(ServerMod.leaders) do
		-- print("SYNCING GLOBAL LEADER: ", leader.name)
		leader:sync(self)
	end

	routine(function()
		wait(3)
		-- retry syncing again just to make sure globalUsers are gotten
		if self.destroyed then
			return
		end

		-- retry syncing with self after waiting
		self:sync(self)

		-- retry syncing with others again after waiting
		for userName, otherUser in pairs(ServerMod.users) do
			if otherUser == self or not otherUser.initialized or otherUser.destroyed then
				continue
			end
			otherUser:sync(self)
			self:sync(otherUser)
		end
	end)
end

function User:destroy(): () end

function User:saveAll(): ()
	-- TODO:
end

function User:destroyAllModules(): ()
	local store = self.store
	if store then
		store:release()
	end
	self.plotManager:destroy()
	self.equipmentManager:destroy()
	self.afkManager:destroy()
end

function User:desyncModules(): ()
	for _, otherUser in pairs(ServerMod.users) do
		local data = {
			name = self.name,
		}
		ServerMod:FireClient(otherUser.player, "removeGlobalUser", data)
	end
end

function User:destroy(): ()
	if self.destroyed then
		warn("ALREADY DESTROYED USER HUH: ", self.name)
		return
	end
	self.destroyed = true

	-- remove the GlobalUser for other users
	self:desyncModules()

	ServerMod.users[self.name] = nil

	routine(function()
		self:saveAll()

		self.destroying = true
		self:destroyAllModules()
	end)
end

return User
