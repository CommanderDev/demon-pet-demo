-- unitManager
-- Author(s): Jesse Appleton
-- Date 2025/09/23

local Common = require(game.ReplicatedStorage.Common)
local len, routine, wait = Common.len, Common.routine, Common.wait

local ServerMod = require(game.ServerScriptService.ServerMod)

local Signal = require(game.ReplicatedStorage.Libraries.Signal)

local Units = require(game.ReplicatedStorage.GameData.Units)

local Unit = require(game.ServerScriptService.Entities.Unit)
local Demon = require(game.ServerScriptService.Entities.Demon)

local unitManager = {
	_byId = {},
}

function unitManager:init() end

function unitManager:spawnUnit(params, spawnCFrame: CFrame): ()
	local unitIdentifier = params.name or params.unitIdentifier
	local unitInfo = Units[unitIdentifier]
	if unitInfo then
		local savedParams = {
			unitId = params.unitId,
			unitIdentifier = params.unitIdentifier,
			position = params.position,
			facing = params.facing,
			leader = params.leader,
			kind = params.kind,
			faction = params.faction,
			teamId = params.teamId,
			level = params.level,
		}

		local unitData = table.clone(unitInfo)
		for key, value in pairs(unitData) do
			params[key] = value
		end

		-- Restore critical params
		for key, value in pairs(savedParams) do
			if value ~= nil then
				params[key] = value
			end
		end
	end

	params.position = spawnCFrame.Position + Vector3.new(0, 5, 0)
	params.facing = spawnCFrame.LookVector
	local unit = Unit.new(params)
	if params.kind == "Demon" then
		ServerMod.demonManager:spawnDemon(unit)
	end
	self._byId[unit.id] = unit

	ServerMod.combatManager:RegisterUnit({
		id = unit.id,
		ref = unit,
		position = unit.position,
		faction = unit.teamId,
		stats = params.stats,
	})

	if unit.onDied then
		unit.onDied:Connect(function()
			self:removeUnit(unit.id)
		end)
	end

	return unit
end

function unitManager:removeUnit(unitId: string): ()
	local unit = self._byId[unitId]
	if not unit then
		return
	end

	unit:markAsPermanentlyDead()

	self._byId[unitId] = nil

	if unit.kind == "Demon" then
		ServerMod.demonManager:removeDemon(unitId)
	end

	if ServerMod.combatManager then
		ServerMod.combatManager:UnregisterUnit(unitId)
	end

	ServerMod:FireAllClients("destroyDemon", { id = unitId })
end

function unitManager:getUnitById(id: string): ()
	return self._byId[id]
end

function unitManager:iterAll()
	return pairs(self._byId)
end

return unitManager
