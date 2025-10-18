local PLAYER_CHECK_INTERVAL: number = 1.0

local Units = require(game.ReplicatedStorage.GameData.Units)

local ServerMod = require(game.ServerScriptService.ServerMod)

local Zone = {}
Zone.__index = Zone

local function distance2(a, b)
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return dx * dx + dy * dy + dz * dz
end

local function pickWeighted(list)
	local total = 0
	for _, e in ipairs(list) do
		total += (e.weight or 1)
	end
	if total <= 0 then
		return list[1]
	end
	local r, acc = math.random() * total, 0
	for _, e in ipairs(list) do
		acc += (e.weight or 1)
		if r <= acc then
			return e
		end
	end
	return list[#list]
end

local function randomPointInCircle(circlePart: BasePart)
	local radius = math.max(circlePart.Size.X, circlePart.Size.Z) / 2
	local theta = math.random() * 2 * math.pi
	local r = math.sqrt(math.random()) * radius
	local x = circlePart.Position.X + r * math.cos(theta)
	local z = circlePart.Position.Z + r * math.sin(theta)
	return Vector3.new(x, circlePart.Position.Y, z)
end

function Zone.new(data, zonePart: BasePart)
	local self = setmetatable({}, Zone)
	for key, value in pairs(data) do
		self[key] = value
	end

	self._zonePart = zonePart

	self.alive = {}
	self.pendingRespawns = {}
	self._aliveList = {}
	self._lastPlayerCheck = 0
	self._active = false
	return self
end

function Zone:_center(): Vector3
	return self._zonePart.CFrame.Position
end

function Zone:_arePlayersNearby(): boolean
	local now = os.clock()
	if now - self._lastPlayerCheck < PLAYER_CHECK_INTERVAL then
		return self._active
	end
	self._lastPlayerCheck = now
	local center = self:_center()
	local r2 = (self.playerActivationRadius or 100) ^ 2
	for _, player in ipairs(game.Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and distance2(root.Position, center) < r2 then
			self._active = true
			return true
		end
	end
	self._active = false
	return false
end

function Zone:_tooClose(p): boolean
	local min2 = self.minSeperation * self.minSeperation
	for _, pos in ipairs(self._aliveList) do
		if distance2(p, pos) < min2 then
			return true
		end
	end
	return false
end

function Zone:_candidateCFrame(): CFrame?
	local p = randomPointInCircle(self._zonePart)
	if not self:_tooClose(p) then
		return CFrame.new(p)
	end
	return nil
end

function Zone:_recordAlive(runtime): ()
	self.alive[runtime] = true
	if runtime.onDied then
		runtime.onDied:Connect(function()
			self.alive[runtime] = nil
			-- rebuild aliveList (cheap enough at this scale)
			self._aliveList = {}
			for ru, _ in pairs(self.alive) do
				if ru and ru.position then
					table.insert(self._aliveList, ru.position)
				end
			end
			table.insert(self.pendingRespawns, os.clock() + self.respawnDelay)
		end)
	end
end

function Zone:getAmountAlive(): number
	local count: number = 0
	for _ in pairs(self.alive) do
		count += 1
	end
	return count
end

function Zone:tick(dt): ()
	if not self:_arePlayersNearby() then
		return
	end

	if #self.pendingRespawns > 0 then
		local now = os.clock()
		local index = 1
		while index <= #self.pendingRespawns do
			if self.pendingRespawns[index] <= now then
				table.remove(self.pendingRespawns, index)
			else
				index += 1
			end
		end
	end

	local deficit = self.maxAlive - self:getAmountAlive()
	local toSpawn = math.clamp(deficit, 0, self.spawnBatch)
	for _ = 1, toSpawn do
		local pick = pickWeighted(self.roster)
		if pick and pick.unit then
			local cf = self:_candidateCFrame()
			if cf then
				local runtime = ServerMod.unitManager:spawnUnit({
					kind = "Demon",
					faction = "Wild",
					teamId = "Wild",
					name = pick.unit,
					id = pick.unit,
				}, cf)
				self:_recordAlive(runtime)
			end
		end
	end
end

return Zone
