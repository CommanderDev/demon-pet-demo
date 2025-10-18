local ActionEffectBase = require(script.Parent.ActionEffectBase)
local EffectBase = require(script.Parent.EffectBase)
local TweenService = game:GetService("TweenService")

local ProjectileEffectBase = setmetatable({}, ActionEffectBase)
ProjectileEffectBase.__index = ProjectileEffectBase

function ProjectileEffectBase.new()
	local self = EffectBase.new()
	return setmetatable(self, ProjectileEffectBase)
end

function ProjectileEffectBase:OnInit()
	ActionEffectBase.OnInit(self)

	self._projectileInstance = nil
	self._tween = nil
	self._isMoving = false
	self._startPosition = Vector3.zero
	self._endPosition = Vector3.zero
	self._speed = 50
	self._direction = Vector3.new(0, 0, -1)

	if self.OnProjectileInit then
		self:OnProjectileInit()
	end
end

function ProjectileEffectBase:OnPlayAction(context)
	self._startPosition = context.position or Vector3.zero
	self._endPosition = context.targetPosition or Vector3.zero
	self._speed = context.speed or 50
	self._direction = context.direction or Vector3.new(0, 0, -1)

	if self.OnProjectileStart then
		self:OnProjectileStart(context)
	end

	self:_createProjectileVisual(context)
	self:_startMovement(context)
end

function ProjectileEffectBase:OnCancel()
	self:_stopMovement()
	self:_destroyProjectileVisual()

	if self.OnProjectileCancel then
		self:OnProjectileCancel()
	end
end

function ProjectileEffectBase:_createProjectileVisual(context)
	if self.CreateProjectileVisual then
		self._projectileInstance = self:CreateProjectileVisual(context)
		self._janitor:Add(self._projectileInstance, "Destroy")
	end
end

function ProjectileEffectBase:_startMovement(context)
	if not self._projectileInstance then
		return
	end

	self._isMoving = true
	local distance = (self._endPosition - self._startPosition).Magnitude
	local duration = distance / self._speed

	if duration <= 0 then
		self:_onMovementComplete()
		return
	end

	self._tween = TweenService:Create(
		self._projectileInstance,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ Position = self._endPosition }
	)

	self._tween.Completed:Connect(function()
		self:_onMovementComplete()
	end)

	self._tween:Play()
	self._janitor:Add(self._tween, "Cancel")
end

function ProjectileEffectBase:_stopMovement()
	self._isMoving = false
	if self._tween then
		self._tween:Cancel()
		self._tween = nil
	end
end

function ProjectileEffectBase:_onMovementComplete()
	self._isMoving = false

	if self.OnProjectileReachDestination then
		self:OnProjectileReachDestination()
	end

	self:_onProjectileComplete("ReachedDestination")
end

function ProjectileEffectBase:_onProjectileComplete(reason)
	if self.OnProjectileComplete then
		self:OnProjectileComplete(reason)
	end

	self:_destroyProjectileVisual()
	self:Stop()
end

function ProjectileEffectBase:_destroyProjectileVisual()
	if self._projectileInstance then
		if self.DestroyProjectileVisual then
			self:DestroyProjectileVisual(self._projectileInstance)
		else
			self._projectileInstance:Destroy()
		end
		self._projectileInstance = nil
	end
end

function ProjectileEffectBase:OnHitTarget(hitData)
	if self.OnProjectileHit then
		self:OnProjectileHit(hitData)
	end

	self:_onProjectileComplete("HitTarget")
end

function ProjectileEffectBase:OnMaxDistance()
	if self.OnProjectileMaxDistance then
		self:OnProjectileMaxDistance()
	end

	self:_onProjectileComplete("MaxDistance")
end

function ProjectileEffectBase:OnCleanup()
	if self.OnProjectileCleanup then
		self:OnProjectileCleanup()
	end

	self:_onProjectileComplete("Cleanup")
end

function ProjectileEffectBase:getProjectileInstance()
	return self._projectileInstance
end

function ProjectileEffectBase:isMoving()
	return self._isMoving
end

function ProjectileEffectBase:getCurrentPosition()
	if self._projectileInstance then
		return self._projectileInstance.Position
	end
	return self._startPosition
end

function ProjectileEffectBase:getDirection()
	return self._direction
end

function ProjectileEffectBase:getSpeed()
	return self._speed
end

return ProjectileEffectBase
