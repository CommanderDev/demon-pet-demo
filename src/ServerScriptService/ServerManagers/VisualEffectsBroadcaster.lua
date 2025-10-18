--[[
    Description: Broadcasts visual effects with context. 
]]

local Codec = require(game.ReplicatedStorage.Libraries.Codec)

local ServerMod = require(game.ServerScriptService.ServerMod)

local VisualEffectsBroadcaster = {}

local RATE = 32 -- tokens per second (increased from 16)
local BURST = 64 -- bucket size (increased from 32)

type Bucket = { tokens: number, last: number, rate: number, burst: number }

local function mkBucket(): Bucket
	return { tokens = BURST, last = os.clock(), rate = RATE, burst = BURST }
end

local function sanitizeContext(context: { any }): { [any]: any }
	local safe = {}
	for key, value in pairs(context or {}) do
		if typeof(value) ~= "Instance" then
			safe[key] = value
		end
	end

	return Codec.Encode(safe)
end

function VisualEffectsBroadcaster:sendToPlayers(players: { Player }, id: string, context: { any }): ()
	local payload = { id = id, context = sanitizeContext(context) }
	for _, player in ipairs(players) do
		if player and player:IsDescendantOf(game.Players) then
			-- For critical effects like damage/healing, use lower cost
			local cost = (id == "Floater") and 0.5 or 1
			if self:consume(player, cost) then
				ServerMod:FireClient(player, "playEffect", payload)
			end
		end
	end
end

function VisualEffectsBroadcaster:consume(player: Player, cost: number): boolean
	local bucket = self.buckets[player]
	if not bucket then
		bucket = mkBucket()
		self.buckets[player] = bucket
	end

	local now = os.clock()
	local refill = (now - bucket.last) * bucket.rate
	bucket.last = now
	bucket.tokens = math.min(bucket.burst, bucket.tokens + refill)
	if bucket.tokens >= cost then
		bucket.tokens -= cost
		return true
	end
	return false
end

function VisualEffectsBroadcaster:init(): ()
	self.buckets = {}
	game.Players.PlayerRemoving:Connect(function(player: Player)
		self.buckets[player] = nil
	end)
end

function VisualEffectsBroadcaster:playEffectForAll(id: string, context: { any }): ()
	self:sendToPlayers(game.Players:GetPlayers(), id, context)
end

function VisualEffectsBroadcaster:playEffectForPlayer(player: Player, id: string, context: { any }): ()
	if not player then
		return
	end

	self:sendToPlayers({ player }, id, context)
end

function VisualEffectsBroadcaster:playEffectForPlayers(players: { Player }, id: string, context: { any }): ()
	if not players then
		return
	end

	self:sendToPlayers(players, id, context)
end

function VisualEffectsBroadcaster:playEffectInRadius(origin: Vector3, radius: number, id: string, context: { any }): ()
	local list = {}
	for _, player in ipairs(game.Players:GetPlayers()) do
		local character = player.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart and (humanoidRootPart.Position - origin).Magnitude <= radius then
			table.insert(list, player)
		end
	end

	local ctx = context and table.clone(context) or {}
	self:sendToPlayers(list, id, ctx)
end

return VisualEffectsBroadcaster
