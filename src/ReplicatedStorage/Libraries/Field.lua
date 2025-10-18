-- Field
-- Author(s): Jesse Appleton
-- Date: 03/20/2021

--| SETTINGS |--
local MAX_HEIGHT = 50 -- MAX HEIGH PLAYER CAN BE FROM GROUND TO BE IN A FIELD.
local LEAVE_FIELD_ON_DEATH = true -- IF TRUE, WHEN PLAYER DIES, THEY LEAVE THE FIELD THEY ARE IN.

--[[
	
	USAGE
		FieldModule:
			Method FieldModule.new(PartTable) - Returns a FieldInstance
			Method Start()
			Method Stop()
			Bool Running
			Bool Initialized
			
		
		FieldInstance
			Event PlayerEntered(Player)
			Event PlayerLeft(Player)
			Method Destroy()
			Bool Enabled
	
	
	! EXAMPLE USAGE !
	
		local FieldModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Field"));
		
		local lowerfield = FieldModule.new({workspace.lowerpart});
		
		lowerfield.PlayerEntered:Connect(function()
			workspace.lowerpart.Color = Color3.fromRGB(75, 151, 75);
		end)
		
		lowerfield.PlayerLeft:Connect(function()
			workspace.lowerpart.Color = Color3.fromRGB(163, 162, 165);
		end)
		
		FieldModule:Start();
	
]]
--

--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------

local Signal = require(game.ReplicatedStorage.Libraries.Signal)
--[[ Services ]]
---
local RunService = game:GetService("RunService")
local Field = {}

Field.isClient = RunService:IsClient()

Field.__index = Field

function Field.new(PartTable)
	for i, v in pairs(PartTable) do
		if not v:IsA("BasePart") then
			error("Field Module - PartTable can only contain parts!")
		end
	end
	local self = setmetatable({}, Field)
	--|

	self.PlayerEntered = Signal.new()
	self.PlayerLeft = Signal.new()
	self.Initialized = false
	self.Enabled = true
	self.running = false
	self.LastTouchedLog = {}
	self.parts = PartTable -- Table which contains field parts.
	self.heartbeatConnection = nil -- The Connection in which the checks will occur
	-- End this Field instance.
	function self:Destroy()
		self.Enabled = false
		self.PlayerEntered:Destroy()
		self.PlayerLeft:Destroy()
		setmetatable(self, nil)
	end
	--|
	if not self.Initialized then
		if Field.isClient then -- Check only the local player for death.
			self:ConnectDeath(game.Players.LocalPlayer, true)
		else -- Is on the server, so check all players for death.
			-- first, get all existing users.
			for i, playerObject in pairs(game.Players:GetPlayers()) do
				task.spawn(function()
					playerObject.CharacterAdded:Wait()
					self:ConnectDeath(playerObject, true)
				end)
			end
			-- Now when a player joins.
			game.Players.PlayerAdded:Connect(function(Player)
				self:ConnectDeath(Player, false)
			end)
		end
	end
	return self
end

-- FOR WHEN A PLAYER IS NO LONGER IN A FIELD.
function Field:SetFieldNoneWithEvent(Player)
	if self.LastTouchedLog[Player] ~= "None" then
		self.LastTouchedLog[Player].PlayerLeft:Fire(Player)
	end
	self.LastTouchedLog[Player] = "None"
end

-- MAIN FUNCTION TO UPDATE FIELD.

function Field:CheckPlayer(Player)
	if self.LastTouchedLog[Player] == nil then -- Setup last touched log for this player.
		self.LastTouchedLog[Player] = "None"
	end

	if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = self.parts
		raycastParams.IgnoreWater = true
		local ray = workspace:Raycast(
			Player.Character.HumanoidRootPart.Position,
			Vector3.new(0, MAX_HEIGHT * -1, 0),
			raycastParams
		)
		if ray and ray.Instance then
			local isInField = false
			--for a, f in pairs(Field.Fields) do
			if self ~= nil and self.Enabled then
				if table.find(self.parts, ray.Instance) then -- Player is in this field.
					isInField = true
					if self.LastTouchedLog[Player] == self then
						return
					else
						self.LastTouchedLog[Player] = self
						self.PlayerEntered:Fire(Player)
					end
				end
			end
			if not isInField then -- Player is not above a field part.
				self:SetFieldNoneWithEvent(Player)
			end
		else -- Part is nil; didnt find part
			self:SetFieldNoneWithEvent(Player)
		end
	end
end

function Field:Start()
	LEAVE_FIELD_ON_DEATH = true
	self.heartbeatConnection = RunService.Heartbeat:Connect(function()
		if Field.isClient then
			self:CheckPlayer(game.Players.LocalPlayer)
		else
			for index, playerObject in next, game.Players:GetPlayers() do
				self:CheckPlayer(playerObject)
			end
		end
	end)
end

function Field:Stop()
	if self.heartbeatConnection then
		self.heartbeatConnection:Disconnect()
	end
	if LEAVE_FIELD_ON_DEATH then
		LEAVE_FIELD_ON_DEATH = false
	end
end

-- HANDLE PLAYER DEATH.
function Field:PlayerDied(Player)
	if LEAVE_FIELD_ON_DEATH then
		self:SetFieldNoneWithEvent(Player)
	end
end

function Field:ConnectDeath(Player, CheckExisting)
	if CheckExisting then
		local Humanoid = Player.Character:WaitForChild("Humanoid")
		Humanoid.Died:Connect(function()
			self:PlayerDied(Player)
		end)
	end
	Player.CharacterAdded:Connect(function(Character)
		local Humanoid = Character:WaitForChild("Humanoid")
		Humanoid.Died:Connect(function()
			self:PlayerDied(Player)
		end)
	end)
end

return Field
