local Players = game:GetService("Players")

local AttackSystem = require(game.ReplicatedStorage.Combat.AttackSystem)
local UnitHelper = require(game.ReplicatedStorage.Helpers.UnitHelper)
local Abilities = require(game.ReplicatedStorage.GameData.Abilities)

local ServerMod = require(game.ServerScriptService.ServerMod)

local CombatManager = {}
CombatManager.__index = CombatManager

local COOLDOWN_DEFAULT = 0.85
local RATE_LIMIT = 1.
local RATE_LIMIT_MAX = 6
local MAX_ATTACK_RANGE = 150
local POSITION_TTL = 1.0
local MAX_SYNC_RATE_HZ = 20
local LOS_REQUIRED = false
local DO_SERVER_AOE = true
local PVP_REQUIRES_TOGGLE = true

local cooldowns = {}
local rateBuckets = {}
local unitOwner = {}
local registry = {}
local syncRate = {}
local lastSeenByUser = {}
local attackSys = nil

local RATE_LIMIT_WINDOW = 1.0
local MAX_SPEED_STUDS_S = 100

local function now()
	return os.clock()
end

local function getAbilityCooldown(abilityId: string)
	if not abilityId then
		return COOLDOWN_DEFAULT
	end
	local ability = Abilities.get(abilityId)
	return ability and ability.cooldown or COOLDOWN_DEFAULT
end

local function abilityKey(abilityId: string)
	return abilityId or "_BASE_"
end

local function canUseAbility(unitId: string, abilityId: string)
	local t = cooldowns[unitId]
	local key = abilityKey(abilityId)
	local tNow = now()
	if not t then
		return true
	end
	local nextAt = t[key]
	return (not nextAt) or (tNow >= nextAt)
end

local function stampCooldown(unitId: string, abilityId: string): ()
	local key = abilityKey(abilityId)
	cooldowns[unitId] = cooldowns[unitId] or {}
	cooldowns[unitId][key] = now() + getAbilityCooldown(abilityId)
end

local function rateLimit(player: Player): boolean
	local userId: number = player.UserId
	local bucket = rateBuckets[userId]
	local tNow = now()
	if not bucket then
		rateBuckets[userId] = { count = 1, bucketStart = tNow }
		return true
	end

	if tNow - bucket.bucketStart > RATE_LIMIT_WINDOW then
		bucket.count = 1
		bucket.bucketStart = tNow
		return true
	else
		bucket.count += 1
		return bucket.count <= RATE_LIMIT_MAX
	end
end

local function rateLimitSync(userId: number): ()
	local bucket = syncRate[userId]
	local t = now()
	if not bucket or (t - bucket.t0) >= 1 then
		syncRate[userId] = { count = 1, t0 = t }
		return true
	end

	bucket.count += 1
	return bucket.count <= MAX_SYNC_RATE_HZ
end

local function ownsUnit(userId, unitId): boolean
	local owner = unitOwner[unitId]
	if owner then
		return owner == userId
	end
	local r = registry[unitId]
	if r and r.ownerUserId then
		unitOwner[unitId] = r.ownerUserId
		return r.ownerUserId == userId
	end

	return tostring(unitId) == tostring(userId)
end

local function posFresh(r)
	return r.pos and r.tPos and (now() - r.tPos) <= POSITION_TTL
end

local function distanceOK(attackerId: string, targetId: string)
	local a = registry[attackerId]
	local t = registry[targetId]
	if not a or not t or not posFresh(a) or not posFresh(t) then
		return false, "stale_or_missing_pos"
	end
	return (a.pos - t.pos).Magnitude <= MAX_ATTACK_RANGE, "out_of_range"
end

function CombatManager:_bindAttackSystem()
	if attackSys then
		return
	end
	attackSys = AttackSystem.new("ServerCombat")
	self.attackSys = attackSys

	attackSys.onDamage:Connect(function(targetId, sourceId, damage, meta)
		ServerMod:FireAllClients("OnDamage", {
			targetId = targetId,
			sourceId = sourceId,
			damage = damage,
			meta = meta,
		})
	end)

	attackSys.onHit:Connect(function(attackerId: string, targetId: string, hitPayload)
		ServerMod:FireAllClients("OnHit", {
			attackerId = attackerId,
			targetId = targetId,
			hitPayload = hitPayload,
		})
	end)
end

function CombatManager:init()
	self:_bindAttackSystem()
	ServerMod:bindRemoteFunction("RequestAttack", function(player: Player, payload)
		return self:_onClientAttackRequest(player, payload)
	end)

	game.Players.PlayerRemoving:Connect(function(player: Player)
		rateBuckets[player.UserId] = nil
		syncRate[player.UserId] = nil
		for userId, owner in pairs(unitOwner) do
			if owner == player.UserId then
				unitOwner[userId] = nil
			end
		end
	end)
end

function CombatManager:RegisterUnit(unitLite)
	assert(unitLite and unitLite.id, "RegisterUnit requires id")
	registry[unitLite.id] = registry[unitLite.id] or {}
	for k, v in pairs(unitLite) do
		registry[unitLite.id][k] = v
	end
	if attackSys then
		attackSys:registerUnit(registry[unitLite.id])
	end
end

function CombatManager:UnregisterUnit(unitId)
	registry[unitId] = nil
	unitOwner[unitId] = nil
	cooldowns[unitId] = nil
	if attackSys then
		attackSys:unregisterUnit(unitId)
	end
end

function CombatManager:GetAttackSystem()
	self:_bindAttackSystem()
	return self.attackSys
end

function CombatManager:onClientSync(player, payload)
	if type(payload) ~= "table" then
		return
	end
	local uid = player.UserId
	if not rateLimitSync(uid) then
		return
	end

	local unitId = payload.unitId
	if not unitId then
		return
	end

	if not ownsUnit(uid, unitId) then
		return
	end

	local r = registry[unitId]
	if not r then
		r = {
			id = unitId,
			ownerUserId = uid,
			faction = payload.faction,
			isPlayer = payload.isPlayer,
			pvpEnabled = payload.pvpEnabled,
			stats = payload.stats or {},
			statuses = payload.statuses or {},
		}
		registry[unitId] = r
		unitOwner[unitId] = uid
		attackSys:registerUnit(r)
	end

	-- Update flags
	if payload.faction ~= nil then
		r.faction = payload.faction
	end
	if payload.isPlayer ~= nil then
		r.isPlayer = payload.isPlayer
	end
	if payload.pvpEnabled ~= nil then
		r.pvpEnabled = payload.pvpEnabled
	end

	if typeof(payload.pos) == "Vector3" then
		local tNow = now()
		if r.pos and r.tPos then
			local dt = math.max(1e-3, tNow - r.tPos)
			local speed = (payload.pos - r.pos).Magnitude / dt
			if speed > (MAX_SPEED_STUDS_S * 3) then
				return
			end
		end
		r.pos = payload.pos
		r.tPos = tNow
		lastSeenByUser[unitId] = uid
	end
end

function CombatManager:_onClientAttackRequest(player, payload)
	local uid = player.UserId
	if not rateLimit(player) then
		return { ok = false, err = "rate_limited" }
	end
	if type(payload) ~= "table" then
		return { ok = false, err = "bad_payload" }
	end

	local unitId = payload.unitId
	local targetId = payload.targetId
	local abilityId = payload.abilityId

	if not unitId or not targetId then
		return { ok = false, err = "missing_params" }
	end
	if not ownsUnit(uid, unitId) then
		return { ok = false, err = "no_authority" }
	end

	local attacker = UnitHelper.resolveUnitById and UnitHelper.resolveUnitById(unitId) or registry[unitId]
	local target = UnitHelper.resolveUnitById and UnitHelper.resolveUnitById(targetId) or registry[targetId]
	if not attacker or not target then
		return { ok = false, err = "invalid_units" }
	end

	if PVP_REQUIRES_TOGGLE and attacker.isPlayer and target.isPlayer then
		if not (attacker.pvpEnabled and target.pvpEnabled) then
			return { ok = false, err = "pvp_disabled" }
		end
	end

	local hostile = UnitHelper.areEnemies and UnitHelper.areEnemies(unitId, targetId)
	if hostile == nil or hostile == false then
		return { ok = false, err = "not_hostile" }
	end

	local inRange, rangeErr = distanceOK(unitId, targetId)
	if not inRange then
		return { ok = false, err = rangeErr }
	end

	local hasStatus = UnitHelper.hasStatus
		or function(id, k)
			local r = registry[id]
			return r and r.statuses and r.statuses[k]
		end

	if hasStatus(unitId, "Stunned") then
		return { ok = false, err = "stunned" }
	end
	if abilityId and hasStatus(unitId, "Silenced") then
		return { ok = false, err = "silenced" }
	end

	if not canUseAbility(unitId, abilityId) then
		return { ok = false, err = "cooldown" }
	end

	if abilityId and Abilities and Abilities.get and not Abilities.get(abilityId) then
		return { ok = false, err = "invalid_ability" }
	end

	stampCooldown(unitId, abilityId)

	local ok, res = pcall(function()
		return attackSys:performAttack(unitId, targetId, abilityId and { abilityId = abilityId } or nil)
	end)
	if not ok then
		warn("[CombatService] performAttack error:", res)
		return { ok = false, err = "server_error" }
	end

	local success, info = res[1], res[2]
	if success then
		return { ok = true, damage = info.damage, meta = info.meta }
	else
		return { ok = false, err = info and (info.reason or "attack_failed") or "attack_failed" }
	end
end

return CombatManager
