local DiffReplicator = require(game.ServerScriptService.Libraries.DiffReplicator)

local ServerMod = require(game.ServerScriptService.ServerMod)

local Demon = {}
Demon.__index = Demon

function Demon.new(unit)
	local self = setmetatable({}, Demon)

	if not unit.unitIdentifier then
		error("Demon.new - unitIdentifier is nil " .. unit.name)
	end

	self._states = {}
	self._orderQueue = {}

	self.unit = unit
	self.unit.entity = self -- Store reference back to Demon for replication

	for _, state in pairs(script.States:GetChildren()) do
		self._states[state.Name] = require(state)
	end

	self.demonReplicator = DiffReplicator.new({
		id = "Demon_" .. unit.id,
		send = function(payload)
			self:sync(payload)
		end,
		pickKeys = {
			["id"] = true,
			["name"] = true,
			["hp"] = true,
			["maxHp"] = true,
			["state"] = true,
			["position"] = true,
			["facing"] = true,
			["unitIdentifier"] = true,
			["targetId"] = true,
			["leaderId"] = true,
			["leaderKind"] = true,
			["formationSlotIndex"] = true,
			["formationMemberCount"] = true,
			["formationType"] = true,
			["formationSpacing"] = true,
			["resources"] = true,
			["statuses"] = true,
			["cooldowns"] = true,
			["casting"] = true,
			["charges"] = true,
			["sleeping"] = true,
			["faction"] = true,
			["level"] = true,
		},
	})
	self:setState("Idle")

	return self
end

function Demon:resolveUnitById(id: string)
	if not id then
		return
	end
	return ServerMod.unitManager:getUnitById(id)
end

function Demon:getPartySlot()
	return (self.party and self.party:getSlotFor(self.unit.id))
end

function Demon:getPartyFocus(): string?
	return (self.party and self.party:getFocusTargetId()) or nil
end

function Demon:getPartyRally(): Vector3
	return (self.party and self.party:getRallyPoint()) or self.unit.position
end

function Demon:sync(payload): ()
	-- Create a clean copy of the payload to avoid circular references
	local cleanPayload = {}
	for key, value in pairs(payload) do
		local valueType = typeof(value)
		-- Copy primitive values and Vector3
		if type(value) == "string" or type(value) == "number" or type(value) == "boolean" or value == nil then
			cleanPayload[key] = value
		elseif valueType == "Vector3" then
			cleanPayload[key] = Vector3.new(value.X, value.Y, value.Z)
		elseif type(value) == "table" then
			-- Shallow copy tables (resources, statuses, cooldowns, etc.)
			cleanPayload[key] = table.clone(value)
		else
			-- Debug: log unexpected types
			warn(("Demon:sync - Skipping key '%s' with unexpected type: %s"):format(tostring(key), valueType))
		end
	end
	ServerMod:FireAllClients("syncDemon", cleanPayload)
end

function Demon:_detectNearbyEnemies(detectionRange: number): string?
	local nearestId = nil
	local nearestDist = math.huge

	for _, unit in pairs(ServerMod.unitManager._byId) do
		if unit.id ~= self.unit.id and unit:canBeTargeted() then
			local UnitHelper = require(game.ReplicatedStorage.Helpers.UnitHelper)
			local areEnemies = UnitHelper.areEnemies(self.unit.id, unit.id)
			if areEnemies then
				local dist = (unit.position - self.unit.position).Magnitude
				if dist < detectionRange and dist < nearestDist then
					nearestDist = dist
					nearestId = unit.id
				end
			end
		end
	end

	return nearestId
end

function Demon:_checkForRetaliation(): ()
	if self._forcedTargetId then
		return
	end

	local partyFocus = self:getPartyFocus()
	if partyFocus then
		return
	end

	local recentAttacker = self.unit:getRecentAttacker()
	if not recentAttacker then
		return
	end

	local attacker = self:resolveUnitById(recentAttacker)
	if not attacker or not attacker:canBeTargeted() then
		return
	end

	local currentState = self._currentState and self._currentState.name
	if currentState == "Idle" or currentState == "FollowLeader" then
		self._forcedTargetId = recentAttacker
		self:setState("Chase")
	end
end

function Demon:setState(stateName: string): ()
	if self._currentState then
		self._currentState:exit()
	end

	self._currentState = self._states[stateName].new(self)
	self._currentState.name = stateName
	self._currentState:enter()
end

function Demon:enqueueOrder(order): ()
	if
		self._lastEnqueued
		and self._lastEnqueued.kind
		and not (order.point or (self._lastEnqueued.point and (self._lastQneueud.point - order.point).Magnitude < 0.1))
		and (order.targetId == nil or self._lastEnqueued.targetId == order.targetId)
	then
		return
	end
	table.insert(self._orderQueue, order)
	self._lastEnqueued = order
end

function Demon:_peekOrder(): { any }
	return self._orderQueue[1]
end

function Demon:_popOrder()
	if #self._orderQueue == 0 then
		return
	end
	local order = table.remove(self._orderQueue, 1)
	if #self._orderQueue == 0 then
		self._lastEnqueued = nil
	end
	return order
end

function Demon:getLeaderRef(): { id: string, kind: string }
	if not self.unit.leader then
		return nil
	end

	return {
		id = self.unit.leader.id,
		kind = self.unit.leader.kind,
	}
end

function Demon:clearOrders(): ()
	table.clear(self._orderQueue)
	self._lastEnqueued = nil
end

function Demon:tick(dt: number): ()
	-- Check if unit should enter sleep state
	if self.unit.hp <= 0 and not self.unit.sleeping then
		local isPlayerDemon = self.unit.kind == "Demon"
			and self.unit.faction
			and string.find(self.unit.faction, "Player_") == 1
		if isPlayerDemon then
			self:setState("Sleep")
		end
	end

	-- Don't allow sleeping demons to take actions
	if self.unit.sleeping then
		-- Only tick the current state (Sleep) and replicate
		local nextState: string? = self._currentState.tick and self._currentState:tick(self, dt)
		if nextState then
			self:setState(nextState)
		end

		-- Replicate state
		local position = self.unit.position
		local facing = self.unit.facing

		self.demonReplicator:consider({
			["id"] = tostring(self.unit.id),
			["hp"] = tonumber(self.unit.hp) or 0,
			["maxHp"] = tonumber(self.unit.maxHp) or 0,
			["state"] = tostring(self._currentState.name),
			["position"] = Vector3.new(position.X, position.Y, position.Z),
			["facing"] = Vector3.new(facing.X, facing.Y, facing.Z),
			["name"] = tostring(self.unit.name),
			["unitIdentifier"] = tostring(self.unit.unitIdentifier),
			["targetId"] = nil,
			["leaderId"] = self._leaderRef and tostring(self._leaderRef.id) or nil,
			["leaderKind"] = self._leaderRef and tostring(self._leaderRef.kind) or nil,
			["formationSlotIndex"] = self.unit.formationSlotIndex and tonumber(self.unit.formationSlotIndex) or nil,
			["formationMemberCount"] = self.unit.formationMemberCount and tonumber(self.unit.formationMemberCount)
				or nil,
			["formationType"] = self._cachedFormationType and tostring(self._cachedFormationType) or nil,
			["formationSpacing"] = self._cachedFormationSpacing and tonumber(self._cachedFormationSpacing) or nil,
			["resources"] = self.unit.resources,
			["statuses"] = self.unit.statuses,
			["cooldowns"] = self.unit.cooldowns,
			["casting"] = self.unit.casting,
			["charges"] = self.unit.charges,
			["sleeping"] = self.unit.sleeping or false,
			["faction"] = tostring(self.unit.faction or "Neutral"),
			["level"] = self.unit.level and tonumber(self.unit.level) or 1,
		})

		return
	end

	self:_checkForRetaliation()

	self._leaderRef = self:getLeaderRef()
	local order = self:_peekOrder()
	if order then
		self:_popOrder()
		if order.kind == "Follow" then
			self:setState("FollowLeader")
		elseif order.kind == "Hold" then
			self.unit:stopMove()
			self:setState("Idle")
		elseif order.kind == "Retreat" then
			self:setState("FollowLeader")
		elseif order.kind == "AttackMove" and order.point then
			self._moveGoal = order.point
			self:setState("MoveToPoint")
		elseif order.kind == "FocusTarget" and order.targetId then
			self._forcedTargetId = order.targetId
			self:setState("Chase")
		end
	end

	-- Cache formation data when party version changes
	if self.party then
		local partyVersion = self.party:getVersion()
		if partyVersion ~= self._seenPartyVersion then
			self._seenPartyVersion = partyVersion
			local formationConfig = self.party:getFormationConfig()
			self._cachedFormationType = formationConfig and formationConfig.type
			self._cachedFormationSpacing = formationConfig and formationConfig.spacing
		end
	end

	local nextState: string? = self._currentState.tick and self._currentState:tick(self, dt)
	if nextState then
		self:setState(nextState)
	end

	-- Create defensive copies to avoid circular references
	local position = self.unit.position
	local facing = self.unit.facing

	self.demonReplicator:consider({
		["id"] = tostring(self.unit.id),
		["hp"] = tonumber(self.unit.hp) or 0,
		["maxHp"] = tonumber(self.unit.maxHp) or 0,
		["state"] = tostring(self._currentState.name),
		["position"] = Vector3.new(position.X, position.Y, position.Z),
		["facing"] = Vector3.new(facing.X, facing.Y, facing.Z),
		["name"] = tostring(self.unit.name),
		["unitIdentifier"] = tostring(self.unit.unitIdentifier),
		["targetId"] = self._forcedTargetId and tostring(self._forcedTargetId) or nil,
		["leaderId"] = self._leaderRef and tostring(self._leaderRef.id) or nil,
		["leaderKind"] = self._leaderRef and tostring(self._leaderRef.kind) or nil,
		["formationSlotIndex"] = self.unit.formationSlotIndex and tonumber(self.unit.formationSlotIndex) or nil,
		["formationMemberCount"] = self.unit.formationMemberCount and tonumber(self.unit.formationMemberCount) or nil,
		["formationType"] = self._cachedFormationType and tostring(self._cachedFormationType) or nil,
		["formationSpacing"] = self._cachedFormationSpacing and tonumber(self._cachedFormationSpacing) or nil,
		["resources"] = self.unit.resources,
		["statuses"] = self.unit.statuses,
		["cooldowns"] = self.unit.cooldowns,
		["casting"] = self.unit.casting,
		["charges"] = self.unit.charges,
		["sleeping"] = self.unit.sleeping or false,
		["faction"] = tostring(self.unit.faction or "Neutral"),
		["level"] = self.unit.level and tonumber(self.unit.level) or 1,
	})
end

function Demon:destroy(): ()
	if self._currentState and self._currentState.exit then
		self._currentState:exit()
	end
	self._currentState = nil

	if self.demonReplicator then
		self.demonReplicator = nil
	end

	self._states = nil
	self._orderQueue = nil
	self._forcedTargetId = nil
	self._moveGoal = nil
	self.party = nil
	self.unit = nil
end

return Demon
