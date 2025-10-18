local EffectBase = require(script.Parent.EffectBase)

AuraEffectBase = setmetatable({}, EffectBase)
AuraEffectBase.__index = AuraEffectBase

AuraEffectBase.Policy = {
	radius = 12,
	followOwner = true,
	tickRate = 0.15,
}

function AuraEffectBase.new(): ()
	local self = EffectBase.new()
	return setmetatable(self, AuraEffectBase)
end

function AuraEffectBase:OnInit(): ()
	self._members = {}
end

function AuraEffectBase:OnPlay(context): ()
	self._context = context
	if self.OnAuraStart then
		self:OnAuraStart(context)
	end
end

function AuraEffectBase:OnTick(dt: number): ()
	self._acc += dt
	if self._acc < self.Policy.tickRate then
		return
	end
	self._acc = 0
end

function AuraEffectBase:_center(): ()
	if self.Policy.followOwner and self._context and self._context.owner and self._context.owner.PrimaryPart then
		return self._context.owner.PrimaryPart.Position
	end
	return (self._context and self._context.origin) or Vector3.zero
end

function AuraEffectBase:OnStop(): ()
	for unit, handle in pairs(self._members) do
		if self.OnMemberExit then
			self:OnMemberExit(unit, handle)
		end
		if handle and handle.Clean then
			handle:Clean()
		end
	end
	table.clear(self._members)
	if self.OnAuraStop then
		self:OnAuraStop()
	end
end

return AuraEffectBase
