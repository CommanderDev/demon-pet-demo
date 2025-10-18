--[[
    Description: Shared adapter over runtime unit store + gGameData
    Server is authoritative, client gets a replicated snapshot
]]

type Health = { current: number, max: number }
type Unit = {
	id: string,
	typeId: string,
	faction: string,
	model: Model?,
	hp: Health,
	stats: any?,
	bb: any?,
	combatEnabled: boolean?,
}

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Units = require(game.ReplicatedStorage.GameData.Units)

local Signal = require(game.ReplicatedStorage.Libraries.Signal)

local UnitHelper = {}
UnitHelper.UnitAdded = Signal.new()
UnitHelper.UnitRemoved = Signal.new()

local store: { [string]: Unit } = {}

function UnitHelper.add(unit: Unit): ()
	store[unit.id] = unit
end

function UnitHelper.remove(unit: Unit): ()
	if store[id] then
		store[id] = nil
		UnitHelper.UnitRemoved:Fire(unit)
	end
end

function UnitHelper.spawn(params: {
	id: string?,
	typeId: string,
	faction: string?,
	model: Model?,
	hp: Health?,
	stats: any?,
	bb: any?,
	combatEnabled: boolean?,
}): string
	local id = params.id or HttpService:GenerateGUID(false)
	local unit: Unit = {
		id = id,
		typeId = params.typeId,
		faction = params.faction or (UnitData[params.typeId] and UnitData[params.typeId].faction) or "Neutral",
		model = params.model,
		hp = params.hp or {
			current = (
				UnitData[params.typeId]
				and UnitData[params.typeId].baseStats
				and UnitData[params.typeId].baseStats.hp
			) or 100,
			max = (
				UnitData[params.typeId]
				and UnitData[params.typeId].baseStats
				and UnitData[params.typeId].baseStats.hp
			) or 100,
		},
		stats = params.stats,
		bb = params.bb,
		combatEnabled = (params.combatEnabled == nil) and true or params.combatEnabled,
	}
	UnitHelper.add(unit)
	return id
end

function UnitHelper._applyReplicaPatch(patch: { [string]: Unit } | nil): ()
	if not patch then
		return
	end
	for id, data in pairs(patch) do
		if not data then
			UnitHelper.remove(id)
		elseif store[id] then
			store[id] = data
			UnitHelper.UnitAdded:Fire(id)
		else
			store[id] = data
		end
	end
end

function UnitHelper.forAllAsync(fn: (string) -> ()): ()
	for id, _ in pairs(store) do
		task.spawn(fn, id)
	end
end

function UnitHelper.forEnemiesAsync(faction: string, fn): ()
	for id, unit in pairs(store) do
		if unit and unit.faction ~= faction then
			task.spawn(fn, id)
		end
	end
end

function UnitHelper.get(id: string): Unit?
	return store[id]
end

function UnitHelper.resolveUnit(id: string): Unit?
	return store[id]
end

function UnitHelper.resolveUnitById(id: string): Unit?
	return store[id]
end

function UnitHelper.position(id: string): Vector3
	local unit = store[id]
	if not unit or not unit.model then
		return nil
	end
	return unit.model:GetPivot().Position
end

function UnitHelper.getModel(id: string): Model?
	local unit = store[id]
	return unit and unit.model or nil
end

function UnitHelper.alive(id: string): boolean
	local unit = store[id]
	return unit and unit.hp and unit.hp.current > 0
end

function UnitHelper.faction(id: string): string
	local unit = store[id]
	return (unit and unit.faction) or "Neutral"
end

function UnitHelper.combatEnabled(id: string): boolean
	local unit = store[id]
	if not unit then
		return false
	end
	if unit.combatEnabled == nil then
		return true
	end
	return unit.combatEnabled
end

function UnitHelper.stats(id: string): any?
	local unit = store[id]
	return unit and unit.stats or nil
end

function UnitHelper.auto(id: string)
	local unit = store[id]
	if not unit then
		return nil
	end
	local def = Units[unit.typeId]
	return def and def.auto or nil
end

function UnitHelper.dead(id: string): boolean
	local unit = store[id]
	return unit and unit.hp and unit.hp.current <= 0
end

function UnitHelper.hasStatus(id: string, statusId: string): boolean
	local unit = store[id]
	return unit and unit.statuses and unit.statuses[statusId]
end

function UnitHelper.applyDamage(id: string, damage: number, meta: any?): boolean
	local unit = store[id]
	if not unit then
		return false
	end
	if unit.hp then
		unit.hp.current = unit.hp.current - damage
	end
	return true
end

function UnitHelper.getHealth(id: stirng): Health?
	local unit = store[id]
	return unit and unit.hp or nil
end

function UnitHelper.setHealth(id: string, hp: Health): ()
	local unit = store[id]
	if unit then
		unit.hp = hp
	end
end

function UnitHelper.kill(id: string, sourceId: string?, context: any?)
	local unit = store[id]
	if not unit then
		return
	end
	if unit.hp then
		unit.hp.current = 0
	end
	UnitHelper.remove(id)
end

function UnitHelper.blackboard(id: string): any?
	local unit = store[id]
	return unit and unit.bb or nil
end

function UnitHelper.setBlackboard(id: string, bb: any?): ()
	local unit = store[id]
	if unit then
		unit.bb = bb
	end
end

function UnitHelper.getStat(id: string, stat: string): number
	local unit = store[id]
	if not unit then
		return 0
	end
	local stats = unit.stats or {}
	return stats[stat] or 0
end

function UnitHelper.areEnemies(attackerId: string, targetId: string): boolean
	if attackerId == targetId then
		return false
	end

	local attacker = store[attackerId]
	local target = store[targetId]

	if not attacker or not target then
		local RunService = game:GetService("RunService")
		if RunService:IsServer() then
			local ServerMod = require(game.ServerScriptService.ServerMod)
			if ServerMod.unitManager then
				attacker = attacker or ServerMod.unitManager:getUnitById(attackerId)
				target = target or ServerMod.unitManager:getUnitById(targetId)
			end
		end
	end

	if not attacker or not target then
		return false
	end

	if attacker.kind == "Player" or target.kind == "Player" then
		return false
	end

	local attackerFaction = attacker.faction or attacker.teamId or "Neutral"
	local targetFaction = target.faction or target.teamId or "Neutral"

	if attackerFaction == "Neutral" or targetFaction == "Neutral" then
		return false
	end

	if attacker.entity and target.entity then
		local attackerParty = attacker.entity.party
		local targetParty = target.entity.party
		if attackerParty and targetParty and attackerParty == targetParty then
			return false
		end
	end

	if attackerFaction == targetFaction then
		return false
	end

	local FactionHelper = require(game.ReplicatedStorage.Helpers.FactionHelper)
	return FactionHelper.areHostile(attackerFaction, targetFaction)
end

return UnitHelper
