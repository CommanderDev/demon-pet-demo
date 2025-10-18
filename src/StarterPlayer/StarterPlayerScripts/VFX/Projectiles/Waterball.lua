local ProjectileEffectBase = require(script.Parent.Parent.ProjectileEffectBase)

local Waterball = setmetatable({}, ProjectileEffectBase)
Waterball.__index = Waterball

function Waterball.new()
	local self = ProjectileEffectBase.new()
	self.projectileSize = Vector3.new(2, 2, 2)
	self.projectileColor = Color3.fromRGB(100, 150, 255)
	self.projectileMaterial = Enum.Material.ForceField
	self.trailEnabled = true
	self.particleEnabled = true
	return setmetatable(self, Waterball)
end

function Waterball:OnProjectileInit()
	self.projectileSize = Vector3.new(2, 2, 2)
	self.projectileColor = Color3.fromRGB(100, 150, 255)
	self.projectileMaterial = Enum.Material.ForceField
	self.trailEnabled = true
	self.particleEnabled = true
end

function Waterball:OnProjectileStart(context)
	if context.effectData then
		self.projectileSize = context.effectData.size or self.projectileSize
		self.projectileColor = context.effectData.color or self.projectileColor
		self.trailEnabled = context.effectData.trailEnabled ~= nil and context.effectData.trailEnabled
			or self.trailEnabled
		self.particleEnabled = context.effectData.particleEnabled ~= nil and context.effectData.particleEnabled
			or self.particleEnabled
	end
end

function Waterball:CreateProjectileVisual(context)
	local projectile = Instance.new("Part")
	projectile.Name = "Waterball"
	projectile.Size = self.projectileSize or Vector3.new(2, 2, 2)
	projectile.Color = self.projectileColor or Color3.fromRGB(100, 150, 255)
	projectile.Material = self.projectileMaterial or Enum.Material.ForceField
	projectile.Shape = Enum.PartType.Ball
	projectile.CanCollide = false
	projectile.Anchored = true
	projectile.Position = self._startPosition

	local parent = workspace.CurrentCamera or workspace
	projectile.Parent = parent

	if self.trailEnabled then
		local trail = Instance.new("Trail")
		trail.Parent = projectile
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 200, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 150, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 100, 255)),
		})
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.Lifetime = 1.0
		trail.MinLength = 0
		trail.FaceCamera = true
	end

	if self.particleEnabled then
		local attachment = Instance.new("Attachment")
		attachment.Parent = projectile

		local water = Instance.new("ParticleEmitter")
		water.Parent = attachment
		water.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		water.Color = ColorSequence.new(Color3.fromRGB(100, 150, 255))
		water.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		water.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		water.Lifetime = NumberRange.new(0.5, 1.0)
		water.Rate = 50
		water.SpreadAngle = Vector2.new(45, 45)
		water.Speed = NumberRange.new(5, 10)

		local bubble = Instance.new("ParticleEmitter")
		bubble.Parent = attachment
		bubble.Texture = "rbxasset://textures/particles/bubble.png"
		bubble.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
		bubble.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		bubble.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		bubble.Lifetime = NumberRange.new(0.3, 0.8)
		bubble.Rate = 30
		bubble.SpreadAngle = Vector2.new(30, 30)
		bubble.Speed = NumberRange.new(2, 5)
	end

	return projectile
end

function Waterball:DestroyProjectileVisual(projectile)
	if projectile then
		local splashPart = Instance.new("Part")
		splashPart.Name = "WaterSplash"
		splashPart.Size = Vector3.new(8, 0.2, 8)
		splashPart.Color = Color3.fromRGB(100, 150, 255)
		splashPart.Material = Enum.Material.ForceField
		splashPart.Transparency = 0.5
		splashPart.CanCollide = false
		splashPart.Anchored = true
		splashPart.Position = projectile.Position
		splashPart.Parent = workspace

		local tween = game:GetService("TweenService"):Create(
			splashPart,
			TweenInfo.new(1.0, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ Transparency = 1, Size = Vector3.new(12, 0.1, 12) }
		)
		tween:Play()

		task.delay(1.5, function()
			splashPart:Destroy()
		end)
		projectile:Destroy()
	end
end

function Waterball:OnProjectileHit(hitData)
	if self._projectileInstance then
		-- Create water ripple effect
		local ripple = Instance.new("Part")
		ripple.Name = "WaterRipple"
		ripple.Size = Vector3.new(1, 0.1, 1)
		ripple.Color = Color3.fromRGB(100, 150, 255)
		ripple.Material = Enum.Material.ForceField
		ripple.Transparency = 0.7
		ripple.CanCollide = false
		ripple.Anchored = true
		ripple.Position = self._projectileInstance.Position
		ripple.Parent = workspace

		-- Animate ripple expansion
		local tween = game:GetService("TweenService"):Create(
			ripple,
			TweenInfo.new(0.8, Enum.EasingStyle.Out, Enum.EasingDirection.Out),
			{ Transparency = 1, Size = Vector3.new(8, 0.1, 8) }
		)
		tween:Play()

		task.delay(1, function()
			ripple:Destroy()
		end)
	end
end

return Waterball
