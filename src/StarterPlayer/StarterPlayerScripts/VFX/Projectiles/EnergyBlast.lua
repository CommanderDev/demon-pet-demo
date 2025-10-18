local ProjectileEffectBase = require(script.Parent.Parent.ProjectileEffectBase)

local EnergyBlast = setmetatable({}, ProjectileEffectBase)
EnergyBlast.__index = EnergyBlast

function EnergyBlast:OnProjectileInit()
	self.projectileSize = Vector3.new(0.5, 0.5, 3)
	self.projectileColor = Color3.fromRGB(0, 150, 255)
	self.projectileMaterial = Enum.Material.ForceField
	self.beamEnabled = true
	self.pulseEnabled = true
end

function EnergyBlast:OnProjectileStart(context)
	if context.effectData then
		self.projectileSize = context.effectData.size or self.projectileSize
		self.projectileColor = context.effectData.color or self.projectileColor
		self.beamEnabled = context.effectData.beamEnabled ~= nil and context.effectData.beamEnabled or self.beamEnabled
		self.pulseEnabled = context.effectData.pulseEnabled ~= nil and context.effectData.pulseEnabled
			or self.pulseEnabled
	end
end

function EnergyBlast:CreateProjectileVisual(context)
	local projectile = Instance.new("Part")
	projectile.Name = "EnergyBlast"
	projectile.Size = self.projectileSize
	projectile.Color = self.projectileColor
	projectile.Material = self.projectileMaterial
	projectile.Shape = Enum.PartType.Cylinder
	projectile.CanCollide = false
	projectile.Anchored = true
	projectile.Position = self._startPosition
	projectile.CFrame = CFrame.lookAt(self._startPosition, self._endPosition)

	local parent = workspace.CurrentCamera or workspace
	projectile.Parent = parent

	if self.pulseEnabled then
		local pulse = Instance.new("ParticleEmitter")
		pulse.Parent = projectile
		pulse.Color = ColorSequence.new(self.projectileColor)
		pulse.Size = NumberSequence.new(0.1, 0.5)
		pulse.Lifetime = NumberRange.new(0.5, 1.0)
		pulse.Rate = 50
		pulse.SpreadAngle = Vector2.new(45, 45)
		pulse.Speed = NumberRange.new(5, 10)
	end

	if self.beamEnabled then
		local attachment0 = Instance.new("Attachment")
		attachment0.Parent = projectile

		local attachment1 = Instance.new("Attachment")
		attachment1.Parent = projectile
		attachment1.Position = Vector3.new(0, 0, -projectile.Size.Z / 2)

		local beam = Instance.new("Beam")
		beam.Parent = projectile
		beam.Attachment0 = attachment0
		beam.Attachment1 = attachment1
		beam.Color = ColorSequence.new(self.projectileColor)
		beam.Transparency = NumberSequence.new(0.3)
		beam.Width0 = 0.5
		beam.Width1 = 0.5
		beam.FaceCamera = true
	end

	return projectile
end

function EnergyBlast:DestroyProjectileVisual(projectile)
	if projectile then
		local explosion = Instance.new("Explosion")
		explosion.Position = projectile.Position
		explosion.BlastRadius = 8
		explosion.BlastPressure = 0
		explosion.Parent = workspace

		projectile:Destroy()
	end
end

function EnergyBlast:OnProjectileHit(hitData)
	if self._projectileInstance then
		local energyBurst = Instance.new("Explosion")
		energyBurst.Position = self._projectileInstance.Position
		energyBurst.BlastRadius = 12
		energyBurst.BlastPressure = 0
		energyBurst.Parent = workspace

		for i = 1, 10 do
			local spark = Instance.new("Part")
			spark.Name = "EnergySpark"
			spark.Size = Vector3.new(0.2, 0.2, 0.2)
			spark.Color = self.projectileColor
			spark.Material = Enum.Material.Neon
			spark.Shape = Enum.PartType.Ball
			spark.CanCollide = false
			spark.Anchored = false
			spark.Position = self._projectileInstance.Position
			spark.Velocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
			spark.Parent = workspace

			game:GetService("Debris"):AddItem(spark, 2)
		end
	end
end

return EnergyBlast
