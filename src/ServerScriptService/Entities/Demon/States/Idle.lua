local Idle = {}
Idle.__index = Idle

local ENEMY_DETECTION_RANGE = 30
local DETECTION_CHECK_INTERVAL = 0.5

function Idle.new(demon)
	local self = setmetatable({}, Idle)
	self.demon = demon
	self.lastDetectionCheck = 0
	return self
end

function Idle:enter(demon)
	self.lastDetectionCheck = 0
end

function Idle:exit(demon) end

function Idle:tick(demon, dt: number): string?
	if self.demon.unit.leader then
		return "FollowLeader"
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

	return nil
end

return Idle
