-- EventManagerLocal
-- Author(s): Jesse Appleton
-- Date 2025/09/23

local player = game.Players.LocalPlayer
local playerScripts = player.PlayerScripts
local playerGui = player.PlayerGui

local Common = require(game.ReplicatedStorage.Common)
local len, routine, wait = Common.len, Common.routine, Common.wait

local ClientMod = require(playerScripts.ClientMod)

local mainEvent = game.ReplicatedStorage.Events.MainEvent

local EventManagerLocal = {}

function EventManagerLocal:init()
	self:addCons()
end

function EventManagerLocal:addCons()
	mainEvent.OnClientEvent:Connect(function(request: string, data: { any }): ()
		self:handleRequest(request, data)
	end)
end

function EventManagerLocal:handleRequest(request: string, data: { any }): ()
	if request == "syncDemon" then
		ClientMod.demonManager:syncDemon(data)
	elseif request == "destroyDemon" then
		ClientMod.demonManager:destroyDemon(data)
	elseif request == "OnHit" then
		ClientMod.demonManager:onAttackHit(data)
	elseif request == "playEffect" then
		ClientMod.visualEffectsManager:Play(data.id, data.context)

	-- Dungeon Controller
	elseif request == "enteredDungeon" then
		ClientMod.UI:Publish("EnteredDungeon", data)
	elseif request == "updateWave" then
		ClientMod.UI:Publish("UpdateWave", data)
	end
end

return EventManagerLocal
