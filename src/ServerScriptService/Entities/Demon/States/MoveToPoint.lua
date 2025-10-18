local ServerMod = require(game.ServerScriptService.ServerMod)
local UnitHelper = require(game.ReplicatedStorage.Helpers.UnitHelper)

local MoveToPoint = {}
MoveToPoint.__index = MoveToPoint

function MoveToPoint.new(demon)
	local self = setmetatable({}, MoveToPoint)
	self.demon = demon
	return self
end

function MoveToPoint:enter(demon) end

function MoveToPoint:_isBoxOccupied(position: Vector3, unit): boolean
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

function MoveToPoint:_findClearPathDirection(unit, targetPosition: Vector3): Vector3
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

function MoveToPoint:tick(demon, dt): string?
	-- break out if party sets a focus target mid-way
	local focusId: string = demon:getPartyFocus()
	if focusId then
		local target = demon:resolveUnitById(focusId)
		if target and target:canBeTargeted() then
			demon.unit.target = target
			return "Chase"
		end
	end

	local goal = demon._moveGoal or demon:getPartyRally()
	local to = (goal - demon.unit.position)
	local arrive = demon.unit.arriveDist or 2.5
	if to.Magnitude <= arrive then
		demon.unit:stopMove()
		return "FollowLeader"
	end

	-- Find a clear path that avoids occupied boxes
	local direction = self:_findClearPathDirection(demon.unit, goal)
	demon.unit:applyMotion(direction * (demon.unit.maxSpeed or 16), dt, "moveTo")
	return nil
end

function MoveToPoint:exit(demon): () end

return MoveToPoint
