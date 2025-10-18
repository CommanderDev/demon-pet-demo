local player = game.Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local ClientMod = require(playerScripts.ClientMod)

local MOVE_SPEED = 16
local CHASE_ARRIVE_DIST = 3

local Chase = {}
Chase.__index = Chase

function Chase.new(demon)
	local self = setmetatable({}, Chase)
	return self
end

function Chase:enter(demon)
	demon:setIdleAnimationEnabled(true)
end

function Chase:exit(demon) end

function Chase:_getTargetPosition(demon): Vector3?
	if not demon.targetId then
		return nil
	end

	local demonManager = ClientMod.demonManager
	if demonManager then
		local targetDemon = demonManager:getDemonById(demon.targetId)
		if targetDemon and targetDemon.root then
			return targetDemon.root.Position
		end
	end

	for _, player in pairs(game.Players:GetPlayers()) do
		if tostring(player.UserId) == demon.targetId then
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				return hrp.Position
			end
		end
	end

	return nil
end

function Chase:tick(demon, dt: number): ()
	local root: BasePart = demon.root
	if not root then
		return
	end

	if not demon._currentFacing or demon._currentFacing.Magnitude < 0.1 then
		demon._currentFacing = Vector3.new(0, 0, -1)
	end

	local targetPos = self:_getTargetPosition(demon)

	if targetPos then
		local currentPos = root.Position
		local toTarget = targetPos - currentPos
		local distance = toTarget.Magnitude

		local direction = toTarget.Unit
		local goalPos
		if distance > CHASE_ARRIVE_DIST then
			goalPos = targetPos - (direction * CHASE_ARRIVE_DIST)
		else
			goalPos = currentPos
		end

		demon._currentFacing = demon._currentFacing:Lerp(direction, 0.08)
		demon:setGoal(goalPos, demon._currentFacing)
	end
end

return Chase
