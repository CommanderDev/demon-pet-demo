local EffectBase = require(script.Parent.EffectBase)
local ActionEffectBase = setmetatable({}, EffectBase)
ActionEffectBase.__index = ActionEffectBase

function ActionEffectBase:OnPlay(context): ()
	if self.OnPlayAction then
		self:OnPlayAction(context)
	end
end

function ActionEffectBase:OnStop(): ()
	if self.OnCancel then
		self:OnCancel()
	end
end

return ActionEffectBase
