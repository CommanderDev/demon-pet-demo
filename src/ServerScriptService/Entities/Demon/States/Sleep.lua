local ServerMod = require(game.ServerScriptService.ServerMod)
local AbilityCaster = require(game.ReplicatedStorage.Combat.AbilityCaster)
local Abilities = require(game.ReplicatedStorage.GameData.Abilities)

local Sleep = {}
Sleep.__index = Sleep

local HEAL_INTERVAL = 1.0 -- Heal every second
local HEAL_AMOUNT_PERCENT = 0.05 -- Heal 5% of max HP per tick
local WAKE_HP_PERCENT = 0.5 -- Wake up at 50% HP

function Sleep.new(demon)
	local self = setmetatable({}, Sleep)
	self.demon = demon
	self.lastHealTime = 0
	return self
end

function Sleep:enter()
	self.lastHealTime = os.clock()
	-- Set unit to sleeping status
	self.demon.unit.sleeping = true
	-- Clear any combat targets
	self.demon._forcedTargetId = nil
	self.demon.unit:endCombatEngagement()
	-- Clear any movement goals
	self.demon.unit:stopMove()
end

function Sleep:exit()
	-- Wake up
	self.demon.unit.sleeping = false
end

function Sleep:tick(demon, dt: number): string?
	local unit = self.demon.unit
	local now = os.clock()

	-- Heal over time using ability system with proper cooldown handling
	if now - self.lastHealTime >= HEAL_INTERVAL then
		self.lastHealTime = now

		-- Get attack system and ability caster
		local attackSys = ServerMod.combatManager and ServerMod.combatManager:GetAttackSystem()
		if attackSys then
			local abilityCaster = AbilityCaster.new(attackSys)

			local result = abilityCaster:cast(unit, "SLEEP_HEAL", unit.id)
		end
	end

	-- Check if we should wake up
	local hpPercent = unit.hp / unit.maxHp
	if hpPercent >= WAKE_HP_PERCENT then
		-- Wake up and return to appropriate state
		if unit.leader then
			return "FollowLeader"
		else
			return "Idle"
		end
	end

	return nil
end

return Sleep
