local Projectile = require(game.ServerScriptService.Entities.Projectile)
local ServerMod = require(game.ServerScriptService.ServerMod)

local ProjectileManager = {}

function ProjectileManager:init()
	self.activeProjectiles = {}
	self._cleanupConnections = {}
end

function ProjectileManager:start() end

function ProjectileManager:addProjectile(projectile)
	self.activeProjectiles[projectile:getId()] = projectile

	projectile.onDestroy:Connect(function(data)
		self.activeProjectiles[projectile:getId()] = nil
	end)

	-- Connect visual effect requests to the broadcaster
	projectile.onVisualEffectRequest:Connect(function(effectData)
		local visualEffectId = effectData.effectClass or "BasicProjectile"
		local context = {
			position = effectData.position,
			direction = effectData.direction,
			speed = effectData.speed,
			targetPosition = effectData.targetPosition,
			effectData = effectData.effectData,
			eventType = effectData.eventType,
		}

		if ServerMod.visualEffectsBroadcaster then
			ServerMod.visualEffectsBroadcaster:playEffectForAll(visualEffectId, context)
		else
			warn("ProjectileManager: No visualEffectsBroadcaster found!")
		end
	end)

	projectile:start(ServerMod.unitManager)
end

function ProjectileManager:removeProjectile(projectileId)
	local projectile = self.activeProjectiles[projectileId]
	if projectile then
		projectile:cleanup()
		self.activeProjectiles[projectileId] = nil
	end
end

function ProjectileManager:getActiveProjectiles()
	return self.activeProjectiles
end

function ProjectileManager:cleanup()
	for projectileId, projectile in pairs(self.activeProjectiles) do
		projectile:cleanup()
	end
	table.clear(self.activeProjectiles)
end

return ProjectileManager
