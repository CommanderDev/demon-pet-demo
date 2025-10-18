local CollisionManager = {}

function CollisionManager:start()
	local function onPlayerAdded(player: Player)
		local function onCharacterAdded(character: Model)
			local function onDescendantAdded(descendant: Instance)
				if descendant:IsA("BasePart") then
					descendant.CollisionGroup = "Player"
				end
			end

			for _, descendant in ipairs(character:GetDescendants()) do
				task.spawn(onDescendantAdded, descendant)
			end
		end

		if player.Character then
			task.spawn(onCharacterAdded, player.Character)
		end
		player.CharacterAdded:Connect(onCharacterAdded)
	end

	for _, player in ipairs(game.Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	game.Players.PlayerAdded:Connect(onPlayerAdded)
end

return CollisionManager
