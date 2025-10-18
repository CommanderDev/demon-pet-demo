local ServerMod = require(game.ServerScriptService.ServerMod)
local UnitHelper = require(game.ReplicatedStorage.Helpers.UnitHelper)

local FollowLeader = {}
FollowLeader.__index = FollowLeader

local ENEMY_DETECTION_RANGE = 30
local DETECTION_CHECK_INTERVAL = 0.5

function FollowLeader.new(demon)
	local self = setmetatable({}, FollowLeader)
	self.demon = demon
	self.lastDetectionCheck = 0
	return self
end

function FollowLeader:enter(demon)
	self.lastDetectionCheck = 0
end

function FollowLeader:_isBoxOccupied(position: Vector3, unit): boolean
	local BOX_SIZE = 2.5 -- Box around path waypoint

	for _, otherUnit in pairs(ServerMod.unitManager._byId) do
		if otherUnit.id ~= unit.id and otherUnit:isAlive() then
			local isFriendly = not UnitHelper.areEnemies(unit.id, otherUnit.id)
			if isFriendly then
				local distance = (position - otherUnit.position).Magnitude
				if distance < BOX_SIZE then
					return true
				end
			end
		end
	end

	return false
end

function FollowLeader:_findClearPathDirection(unit, targetPosition: Vector3): Vector3
	local directDirection = (targetPosition - unit.position).Unit
	local CHECK_DISTANCE = 4

	-- Try different angles to find a clear path
	local angles = { 0, math.rad(30), math.rad(-30), math.rad(50), math.rad(-50), math.rad(75), math.rad(-75) }

	for _, angleOffset in ipairs(angles) do
		-- Rotate around Y axis
		local cosA = math.cos(angleOffset)
		local sinA = math.sin(angleOffset)
		local testDir = Vector3.new(
			directDirection.X * cosA - directDirection.Z * sinA,
			directDirection.Y,
			directDirection.X * sinA + directDirection.Z * cosA
		).Unit

		-- Check if the path ahead is clear
		local checkPosition = unit.position + testDir * CHECK_DISTANCE

		if not self:_isBoxOccupied(checkPosition, unit) then
			return testDir
		end
	end

	-- If all paths blocked, return direct direction
	return directDirection
end

function FollowLeader:tick(demon, dt): ()
	local focusId = demon:getPartyFocus()
	if focusId then
		local target = demon:resolveUnitById(focusId)
		if target and target:canBeTargeted() then
			self.demon._forcedTargetId = focusId
			return "Chase"
		end
	end

	local now = os.clock()
	if now - self.lastDetectionCheck >= DETECTION_CHECK_INTERVAL then
		self.lastDetectionCheck = now

		local enemyId = self.demon:_detectNearbyEnemies(ENEMY_DETECTION_RANGE)
		if enemyId then
			self.demon._forcedTargetId = enemyId
			return "Chase"
		end
	end

	local goal = demon:getPartySlot() or demon:getPartyRally()
	local stopDist = demon.unit.followStopDist or 2.5
	local distance = (goal - demon.unit.position).Magnitude

	if distance <= stopDist then
		demon.unit.position = goal
		demon.unit:stopMove()
	else
		local maxSpeed = demon.unit.maxSpeed or 16
		local moveAmount = math.min(maxSpeed * dt, distance)
		-- Find a clear path that avoids occupied boxes
		local direction = self:_findClearPathDirection(demon.unit, goal)
		demon.unit.position = demon.unit.position + (direction * moveAmount)
		demon.unit.facing = direction
	end

	return nil
end

function FollowLeader:exit(demon): () end

return FollowLeader
