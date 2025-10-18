local BASE_MOVE_SPEED: number = 20
local MAX_MOVE_SPEED: number = 35
local RUBBER_BAND_DISTANCE: number = 10

local FollowLeader = {}
FollowLeader.__index = FollowLeader

function FollowLeader.new(demon)
	local self = setmetatable({}, FollowLeader)

	return self
end

function FollowLeader:enter(demon)
	demon:setIdleAnimationEnabled(true)
end

function FollowLeader:tick(demon, dt: number): ()
	local root: BasePart = demon.root
	if not root then
		return
	end

	if not demon._currentFacing or demon._currentFacing.Magnitude < 0.1 then
		demon._currentFacing = Vector3.new(0, 0, -1)
	end

	local goal = demon:_computeFollowGoal()
	if goal then
		local to = goal - root.Position
		local dist = to.Magnitude

		demon:setGoal(goal, nil)

		if dist > demon.stopDist then
			local moveDir = to.Unit

			local leaderCFrame = demon:getLeaderCFrame(demon._leaderRef)
			if leaderCFrame then
				local targetFaceDirection = (leaderCFrame.Position - root.Position).Unit
				if targetFaceDirection.Magnitude > 0.1 then
					demon._currentFacing = demon._currentFacing:Lerp(targetFaceDirection, 0.1)
					demon:setGoal(nil, demon._currentFacing)
				end
			end
		else
			local leaderCFrame = demon:getLeaderCFrame(demon._leaderRef)
			if leaderCFrame then
				local targetFaceDirection = (leaderCFrame.Position - root.Position).Unit
				if targetFaceDirection.Magnitude > 0.1 then
					local angleDiff = math.acos(math.clamp(demon._currentFacing:Dot(targetFaceDirection), -1, 1))
					if angleDiff > 0.1 then
						demon._currentFacing = demon._currentFacing:Lerp(targetFaceDirection, 0.05)
						demon:setGoal(nil, demon._currentFacing)
					end
				end
			end
		end
	end
end

return FollowLeader
