local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Signal = require(game.ReplicatedStorage.Libraries.Signal)

local Projectile = {}
Projectile.__index = Projectile

function Projectile.new(projectileData)
	local self = setmetatable({}, Projectile)

	self.id = projectileData.id or HttpService:GenerateGUID(false)
	self.caster = projectileData.caster
	self.target = projectileData.target
	self.startPosition = projectileData.startPosition or Vector3.zero
	self.endPosition = projectileData.endPosition or Vector3.zero
	self.speed = projectileData.speed or 50
	self.maxDistance = projectileData.maxDistance or 1000
	self.hitRadius = projectileData.hitRadius or 5
	self.canPierce = projectileData.canPierce or false
	self.maxPierceTargets = projectileData.maxPierceTargets or 1
	self.visualEffectClass = projectileData.visualEffectClass
	self.visualEffectData = projectileData.visualEffectData or {}

	self.onHit = Signal.new()
	self.onReachDestination = Signal.new()
	self.onDestroy = Signal.new()
	self.onVisualEffectRequest = Signal.new()

	self.currentPosition = self.startPosition
	self.direction = (self.endPosition - self.startPosition).Unit
	self.distanceTraveled = 0
	self.hitTargets = {}
	self.isDestroyed = false

	self._connection = nil

	return self
end

function Projectile:getId(): string
	return self.id
end

function Projectile:getCaster()
	return self.caster
end

function Projectile:getTarget()
	return self.target
end

function Projectile:getCurrentPosition(): Vector3
	return self.currentPosition
end

function Projectile:getDirection(): Vector3
	return self.direction
end

function Projectile:getSpeed(): number
	return self.speed
end

function Projectile:isDestroyed(): boolean
	return self.isDestroyed
end

function Projectile:hasHitTarget(targetId: string): boolean
	return self.hitTargets[targetId] == true
end

function Projectile:canHitTarget(targetId: string): boolean
	if targetId == self.caster.id then
		return false
	end

	local UnitHelper = require(game.ReplicatedStorage.Helpers.UnitHelper)
	if not UnitHelper.areEnemies(self.caster.id, targetId) then
		return false
	end

	if not self.canPierce and self.hitTargets[targetId] then
		return false
	end

	local pierceCount = 0
	for _, _ in pairs(self.hitTargets) do
		pierceCount = pierceCount + 1
	end

	return pierceCount < self.maxPierceTargets
end

function Projectile:markTargetHit(targetId: string): ()
	self.hitTargets[targetId] = true
end

function Projectile:updatePosition(dt: number): ()
	if self.isDestroyed then
		return
	end

	local moveDistance = self.speed * dt
	self.currentPosition = self.currentPosition + (self.direction * moveDistance)
	self.distanceTraveled = self.distanceTraveled + moveDistance

	if self.distanceTraveled >= self.maxDistance then
		self:destroy("MaxDistance")
		return
	end

	local distanceToTarget = (self.endPosition - self.currentPosition).Magnitude
	if distanceToTarget <= self.hitRadius then
		self:destroy("ReachedDestination")
		return
	end
end

function Projectile:checkCollisions(unitManager): ()
	if self.isDestroyed then
		return
	end

	for unitId, unit in unitManager:iterAll() do
		if self:canHitTarget(unitId) then
			local distanceToUnit = (unit.position - self.currentPosition).Magnitude
			if distanceToUnit <= self.hitRadius then
				self.onHit:Fire({
					projectile = self,
					target = unit,
					hitPosition = self.currentPosition,
					distanceTraveled = self.distanceTraveled,
				})

				self:markTargetHit(unitId)

				if not self.canPierce then
					self:destroy("HitTarget")
					return
				end
			end
		end
	end
end

function Projectile:start(unitManager): ()
	if self._connection then
		warn("Projectile already started")
		return
	end

	self:requestVisualEffect("Start")

	self._connection = RunService.Heartbeat:Connect(function(dt)
		self:updatePosition(dt)
		self:checkCollisions(unitManager)
	end)
end

function Projectile:stop(): ()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

function Projectile:requestVisualEffect(eventType: string): ()
	if self.visualEffectClass then
		self.onVisualEffectRequest:Fire({
			projectileId = self.id,
			effectClass = self.visualEffectClass,
			effectData = self.visualEffectData,
			eventType = eventType,
			position = self.currentPosition,
			direction = self.direction,
			speed = self.speed,
			targetPosition = self.endPosition,
		})
	end
end

function Projectile:destroy(reason: string?): ()
	if self.isDestroyed then
		return
	end

	self.isDestroyed = true
	self:stop()

	if reason == "ReachedDestination" then
		self:requestVisualEffect("ReachDestination")
		self.onReachDestination:Fire({
			projectile = self,
			position = self.currentPosition,
			distanceTraveled = self.distanceTraveled,
		})
	elseif reason == "HitTarget" then
		self:requestVisualEffect("HitTarget")
	elseif reason == "MaxDistance" then
		self:requestVisualEffect("MaxDistance")
	elseif reason == "Cleanup" then
		self:requestVisualEffect("Cleanup")
	end

	self.onDestroy:Fire({
		projectile = self,
		reason = reason,
		position = self.currentPosition,
		distanceTraveled = self.distanceTraveled,
	})
end

function Projectile:cleanup(): ()
	self:destroy("Cleanup")
	self.onHit:Destroy()
	self.onReachDestination:Destroy()
	self.onDestroy:Destroy()
	self.onVisualEffectRequest:Destroy()
end

return Projectile
