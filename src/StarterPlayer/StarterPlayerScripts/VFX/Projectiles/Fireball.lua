local ProjectileEffectBase = require(script.Parent.Parent.ProjectileEffectBase)

local Fireball = setmetatable({}, ProjectileEffectBase)
Fireball.__index = Fireball

function Fireball.new()
	local self = ProjectileEffectBase.new()
	self.projectileSize = Vector3.new(2, 2, 2)
	self.projectileColor = Color3.fromRGB(255, 100, 0)
	self.projectileMaterial = Enum.Material.Neon
	self.trailEnabled = true
	self.particleEnabled = true
	return setmetatable(self, Fireball)
end

function Fireball:OnProjectileInit()
	self.projectileSize = Vector3.new(2, 2, 2)
	self.projectileColor = Color3.fromRGB(255, 100, 0)
	self.projectileMaterial = Enum.Material.Neon
	self.trailEnabled = true
	self.particleEnabled = true
end

function Fireball:OnProjectileStart(context)
	if context.effectData then
		self.projectileSize = context.effectData.size or self.projectileSize
		self.projectileColor = context.effectData.color or self.projectileColor
		self.trailEnabled = context.effectData.trailEnabled ~= nil and context.effectData.trailEnabled
			or self.trailEnabled
		self.particleEnabled = context.effectData.particleEnabled ~= nil and context.effectData.particleEnabled
			or self.particleEnabled
	end
end

function Fireball:CreateProjectileVisual(context)
	local projectile = Instance.new("Part")
	projectile.Name = "Fireball"
	projectile.Size = self.projectileSize or Vector3.new(2, 2, 2)
	projectile.Color = self.projectileColor or Color3.fromRGB(255, 100, 0)
	projectile.Material = self.projectileMaterial or Enum.Material.Neon
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
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 0)),
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

		local fire = Instance.new("Fire")
		fire.Parent = projectile
		fire.Color = Color3.fromRGB(255, 255, 0)
		fire.SecondaryColor = Color3.fromRGB(255, 50, 0)
		fire.Heat = 25
		fire.Size = 5

		local sparkles = Instance.new("Sparkles")
		sparkles.Parent = projectile
		sparkles.SparkleColor = Color3.fromRGB(255, 255, 0)
	end

	return projectile
end

function Fireball:DestroyProjectileVisual(projectile)
	if projectile then
		local explosion = Instance.new("Explosion")
		explosion.Position = projectile.Position
		explosion.BlastRadius = 15
		explosion.BlastPressure = 0
		explosion.Parent = workspace

		projectile:Destroy()
	end
end

function Fireball:OnProjectileHit(hitData)
	if self._projectileInstance then
		local fireEffect = Instance.new("Fire")
		fireEffect.Parent = workspace.Terrain
		fireEffect.Color = Color3.fromRGB(255, 100, 0)
		fireEffect.SecondaryColor = Color3.fromRGB(255, 0, 0)
		fireEffect.Heat = 25
		fireEffect.Size = 5

		task.delay(3, function()
			fireEffect:Destroy()
		end)
	end
end

return Fireball
