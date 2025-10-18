local ProjectileEffectBase = require(script.Parent.Parent.ProjectileEffectBase)

local BasicProjectile = setmetatable({}, ProjectileEffectBase)
BasicProjectile.__index = BasicProjectile

function BasicProjectile:OnProjectileInit()
	self.projectileSize = Vector3.new(1, 1, 1)
	self.projectileColor = Color3.fromRGB(255, 255, 255)
	self.projectileMaterial = Enum.Material.Neon
	self.trailEnabled = false
end

function BasicProjectile:OnProjectileStart(context)
	if context.effectData then
		self.projectileSize = context.effectData.size or self.projectileSize
		self.projectileColor = context.effectData.color or self.projectileColor
		self.projectileMaterial = context.effectData.material or self.projectileMaterial
		self.trailEnabled = context.effectData.trailEnabled or self.trailEnabled
	end
end

function BasicProjectile:CreateProjectileVisual(context)
	local projectile = Instance.new("Part")
	projectile.Name = "BasicProjectile"
	projectile.Size = self.projectileSize
	projectile.Color = self.projectileColor
	projectile.Material = self.projectileMaterial
	projectile.Shape = Enum.PartType.Ball
	projectile.CanCollide = false
	projectile.Anchored = true
	projectile.Position = self._startPosition

	local parent = workspace.CurrentCamera or workspace
	projectile.Parent = parent

	if self.trailEnabled then
		local trail = Instance.new("Trail")
		trail.Parent = projectile
		trail.Color = ColorSequence.new(self.projectileColor)
		trail.Transparency = NumberSequence.new(0.5)
		trail.Lifetime = 0.5
		trail.MinLength = 0
		trail.FaceCamera = true
	end

	return projectile
end

function BasicProjectile:DestroyProjectileVisual(projectile)
	if projectile then
		projectile:Destroy()
	end
end

function BasicProjectile:OnProjectileHit(hitData)
	if self._projectileInstance then
		local explosion = Instance.new("Explosion")
		explosion.Position = self._projectileInstance.Position
		explosion.BlastRadius = 10
		explosion.BlastPressure = 0
		explosion.Parent = workspace
	end
end

return BasicProjectile
