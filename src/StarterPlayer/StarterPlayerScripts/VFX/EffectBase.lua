local Janitor = require(game.ReplicatedStorage.Libraries.Janitor)

local EffectBase = {}
EffectBase.__index = EffectBase

function EffectBase.new()
	local self = setmetatable({}, EffectBase)
	self._janitor = Janitor.new()
	self._isPlaying = false
	self._onComplete = nil

	if self.OnInit then
		self:OnInit()
	end

	return self
end

function EffectBase:Play(context, onComplete: (() -> ())?)
	self._isPlaying = true
	self._onComplete = onComplete

	if self.OnPlay then
		self:OnPlay(context)
	end
	return {
		Stop = function()
			self:Stop()
		end,
	}
end

function EffectBase:Stop(): ()
	if not self._isPlaying then
		return
	end

	self._isPlaying = false
	if self.OnStop then
		self:OnStop()
	end
	self._janitor:Clean()
	if self._onComplete then
		self._onComplete()
	end
end

return EffectBase
