local player = game.Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local ClientMod = require(playerScripts.ClientMod)

local FACING_LERP = 0.05 -- Reduced for smoother, more subtle rotation
local ATTACK_RANGE = 10
local MOVE_SPEED = 8

local Attack = {}
Attack.__index = Attack

function Attack.new(demon)
	local self = setmetatable({}, Attack)
	return self
end

function Attack:enter(demon)
	demon:setIdleAnimationEnabled(false)
end

function Attack:exit(demon)
	demon:setIdleAnimationEnabled(true)
end

function Attack:_getTargetPosition(demon): Vector3?
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

function Attack:tick(demon, dt: number): ()
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
		if distance > ATTACK_RANGE then
			goalPos = targetPos - (direction * (ATTACK_RANGE - 2))
		else
			goalPos = currentPos
		end

		demon._currentFacing = demon._currentFacing:Lerp(direction, FACING_LERP)
		demon:setGoal(goalPos, demon._currentFacing)
	end
end

return Attack
