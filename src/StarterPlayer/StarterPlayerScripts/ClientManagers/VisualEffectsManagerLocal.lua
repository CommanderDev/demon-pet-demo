local RunService = game:GetService("RunService")

local player = game.Players.LocalPlayer
local playerScripts = player.PlayerScripts

local Registry = require(playerScripts.VFX.Core.Registry)
local Pool = require(playerScripts.VFX.Core.Pool)
local Codec = require(game.ReplicatedStorage.Libraries.Codec)

export type EffectContext = {
	origin: Vector3,
	cframe: CFrame?,
	parent: Instnce?,
	parentRef: { kind: string, data: any }?,
	owner: Model?,
	layer: "World" | "Screen" | "UI",
	params: { [string]: any }?,
	timeScale: number?,
	tags: { [string]: boolean }?,
}

local VisualEffectsManager = {}

local ENABLED: boolean = true

function VisualEffectsManager:init(): ()
	self._maxConcurrent = 250
	self._activeCount = 0
	self._queue = {} -- Queue for effects when at max capacity
	self._queueMaxSize = 100 -- Maximum queue size

	self._pools = {}
	self._activeEffects = {}

	self.resolver = nil

	for _, object in ipairs(playerScripts.VFX:GetDescendants()) do
		if object:IsA("ModuleScript") then
			local mod = require(object)
			self:Register(object.Name, mod, {})
		end
	end
end

function VisualEffectsManager:start(): () end

function VisualEffectsManager:Register(id: string, class, defaults: { any })
	if Registry.Get(id) then
		warn("[VFX] Re-registering id: " .. id)
	end
	Registry.Register(id, class, defaults)
	self._pools[id] = self._pools[id] or Pool.new(function()
		return class.new()
	end)
end

function VisualEffectsManager:SetResolver(fn: (string, any) -> Instance?)
	self.resolver = fn
end

function VisualEffectsManager:resolveContext(context: EffectContext): EffectContext
	if context and context.parentRef and self.resolver then
		local instance = resolver(context.parentRef.kind, context.parentRef.data)
		if instance then
			context.parent = instance
		end
	end
	return context
end

function VisualEffectsManager:Play(id: string, context: EffectContext): ()
	if not ENABLED then
		return
	end

	context = Codec.Decode(context)

	local entry = Registry.Get(id)
	if not entry then
		warn(("[VFX] Unknown effect id %s"):format(id))
		return
	end

	-- If at max capacity, queue the effect instead of dropping it
	if self._activeCount >= self._maxConcurrent then
		if #self._queue < self._queueMaxSize then
			table.insert(self._queue, { id = id, context = context })
		end
		return
	end

	self:_playEffect(id, context)
end

function VisualEffectsManager:_playEffect(id: string, context: EffectContext): ()
	local entry = Registry.Get(id)
	if not entry then
		return
	end

	local pool = self._pools[id]
	local effect = pool:Acquire()
	self._activeCount += 1

	local merged = Registry.MergeDefaults(id, context or {})
	merged = self:resolveContext(merged)

	local stopToken = effect:Play(merged, function()
		self._activeCount -= 1
		if effect.Recycle then
			effect:Recycle()
		end
		pool:Release(effect)

		-- Remove from active effects array
		for i = #self._activeEffects, 1, -1 do
			if self._activeEffects[i] == effect then
				table.remove(self._activeEffects, i)
				break
			end
		end

		-- Process queued effects when capacity becomes available
		self:_processQueue()
	end)
	table.insert(self._activeEffects, effect)
end

function VisualEffectsManager:_processQueue(): ()
	-- Process multiple queued effects if we have capacity
	while #self._queue > 0 and self._activeCount < self._maxConcurrent do
		local queued = table.remove(self._queue, 1)
		if queued then
			self:_playEffect(queued.id, queued.context)
		else
			break
		end
	end
end

function VisualEffectsManager:StopAll(): ()
	local snapshot = table.clone(self._activeEffects)
	for _, effect in ipairs(snapshot) do
		if effect._isPlaying and effect.Stop then
			effect:Stop()
		end
	end

	table.clear(self._queue)
end

function VisualEffectsManager:tick(dt: number): ()
	for index = 1, #self._activeEffects do
		local effect = self._activeEffects[index]
		if effect and effect._isPlaying and effect.OnTick then
			effect:OnTick(dt)
		end
	end
end

function VisualEffectsManager:tickRender(dt: number): ()
	for indexx = 1, #self._activeEffects do
		local effect = self._activeEffects[indexx]
		if effect and effect._isPlaying and effect.OnRender then
			effect:OnRender(dt)
		end
	end
end

function VisualEffectsManager:GetDebugInfo(): table
	return {
		activeCount = self._activeCount,
		maxConcurrent = self._maxConcurrent,
		queueSize = #self._queue,
		queueMaxSize = self._queueMaxSize,
		activeEffectsCount = #self._activeEffects,
		enabled = ENABLED,
	}
end

return VisualEffectsManager
