local HttpService = game:GetService("HttpService")

local Enums = require(game.ReplicatedStorage.Enums)
local Formation = require(game.ReplicatedStorage.Helpers.Formation)

local Party = {}
Party.__index = Party

function Party.new(args)
	local self = setmetatable({}, Party)

	self.id = HttpService:GenerateGUID()
	self.teamId = args.teamId
	self.leaderUnit = args.leaderUnit
	self.members = {}
	self.memberUnits = {}
	self.blackboard = {
		formation = { type = args.formation or "Wedge", spacing = args.spacing or 5 },
		rallyPoint = self.leaderUnit.position,
		focusTargetId = nil,
		orderVersion = 0,
	}
	self._slotMap = {}
	return self
end

function Party:addMember(demon): ()
	table.insert(self.members, demon)
	table.insert(self.memberUnits, demon.unit)
	demon.party = self
	self:_recomputeSlots()
end

function Party:removeMember(demon): ()
	for index, member in ipairs(self.members) do
		if member == demon then
			table.remove(self.members, index)
			table.remove(self.memberUnits, index)
			break
		end
	end
	demon.party = nil
	self:_recomputeSlots()
end

function Party:_recomputeSlots(): ()
	if not self.leaderUnit then
		return
	end

	local leaderPosition: Vector3 = self.leaderUnit.position
	local forward = self.leaderUnit.facing or Vector3.new(0, 0, -1)
	local slots = Formation.compute(leaderPosition, forward, self.memberUnits, self.blackboard.formation)

	self._slotMap = {}
	for index, unit in ipairs(self.memberUnits) do
		-- Store absolute position in slot map for server-side pathfinding
		self._slotMap[unit.id] = slots[index]
		-- Store slot index and formation count for client-side computation
		unit.formationSlotIndex = index
		unit.formationMemberCount = #self.memberUnits
	end
	self.blackboard.orderVersion += 1
end

function Party:getSlotFor(unitId: string | number): Vector3
	-- Compute slot position dynamically based on current leader position
	if not self.leaderUnit then
		return Vector3.zero
	end

	-- Find the unit's slot index
	local slotIndex = nil
	for index, unit in ipairs(self.memberUnits) do
		if unit.id == unitId then
			slotIndex = index
			break
		end
	end

	if not slotIndex then
		return Vector3.zero
	end

	-- Recompute all slots with current leader position
	local leaderPosition: Vector3 = self.leaderUnit.position
	local forward = self.leaderUnit.facing or Vector3.new(0, 0, -1)
	local slots = Formation.compute(leaderPosition, forward, self.memberUnits, self.blackboard.formation)

	return slots[slotIndex]
end

function Party:teleportPartyTo(cframe: CFrame): ()
	for _, member in ipairs(self.members) do
		member:setState("FollowLeader")
	end

	self.leaderUnit:pivotTo(cframe)
	for _, memberUnit in ipairs(self.memberUnits) do
		memberUnit:pivotTo(cframe)
	end
	self:_recomputeSlots()
end

function Party:getFocusTargetId(): string?
	return self.blackboard.focusTargetId
end

function Party:getRallyPoint(): Vector3?
	return self.blackboard.rallyPoint
end

function Party:getVersion(): number
	return self.blackboard.orderVersion
end

function Party:getFormationConfig(): table
	return self.blackboard.formation
end

-- High level orders
function Party:issueOrder(order: number, payload: { any }): ()
	self.blackboard.orderVersion += 1
	if order == Enums.PartyOrder.Formation then
		self.blackboard.formation = {
			type = payload.type or self.blackboard.formation.type,
			spacing = payload.spacing or self.blackboard.formation.spacing,
		}
		self._recomputeSlots()
	elseif order == Enums.PartyOrder.Hold then
		self.blackboard.rallyPoint = self.leaderUnit.position
		for _, member in ipairs(self.members) do
			member:enqueueOrder({ kind = "Hold" })
		end
	elseif order == Enums.PartyOrder.Retreat then
		self.blackboard.rallyPoint = payload.point or self.leaderUnit.position
		for _, member in ipairs(self.members) do
			member:enqueueOrder({ kind = "Retreat", point = self.blackboard.rallyPoint })
		end
	elseif order == Enums.PartyOrder.AttackMove then
		for _, member in ipairs(self.members) do
			member:enqueueOrder({ king = "AttackMove", point = payload.point })
		end
	elseif order == Enums.PartyOrder.FocusTarget then
		self.blackboard.focusTargetId = payload.targetId
	elseif order == Enums.PartyOrder.Disband then
		for _, member in ipairs(self.members) do
			member:enqueueOrder({ kind = "Hold" })
			-- TODO Add disband logic
		end
	end
end

function Party:tick(dt: number): ()
	local toRemove = {}
	for index, demon in ipairs(self.members) do
		if demon.unit and not demon.unit:isAlive() then
			table.insert(toRemove, demon)
		end
	end

	for _, demon in ipairs(toRemove) do
		self:removeMember(demon)
	end

	-- Note: Formation slots are computed dynamically in getSlotFor()
	-- based on current leader position, so no need to recompute every tick
end

return Party
