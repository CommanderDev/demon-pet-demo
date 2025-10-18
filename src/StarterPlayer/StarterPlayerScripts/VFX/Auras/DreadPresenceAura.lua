local AuraBase = require(script.Parent.Parent.AuraEffectBase)

local DreadPresenceAura = setmetatable({}, AuraBase)
DreadPresenceAura.__index = DreadPresenceAura

DreadPresenceAura.Policy = {
	radius = 18,
	followOwner = true,
	tickRate = 0.2,
}

function DreadPresenceAura.new()
	local self = setmetatable({}, DreadPresenceAura)
	return self
end

function DreadPresenceAura:OnAuraStart(context): ()
	self._folder = Instance.new("Folder")
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Parent = self._folder

	local ad = Instance.new("Decal")
	ad.Face = Enum.NormalId.Top
	ad.Texture = "rbxassetid://11902688876"
	ad.Transparency = 0.35
	ad.Color3 = Color3.fromRGB(60, 0, 60)
	ad.Parent = part

	self._part = part
	self._ad = ad
	self._t = 0

	self._folder.Parent = (ctx.parent or workspace)
	-- janitor cleans up instances when effect stops
	self._janitor:Add(function()
		if self._folder then
			self._folder.Parent = nil
		end
	end)
end

function DreadPresenceAura:OnRender(dt)
	if not self._part then
		return
	end
	local c = self:_center()
	self._part.CFrame = CFrame.new(c + Vector3.new(0, 0.1, 0))
	local s = self.Policy.radius * 2
	self._part.Size = Vector3.new(s, 0.1, s)

	self._t += dt
	if self._ad then
		self._ad.Transparency = 0.35 + math.sin(self._t * 2.0) * 0.05
	end
end

function DreadPresenceAura:OnAuraStop(): ()
	if self._folder then
		self._folder:Destroy()
	end
end

return DreadPresenceAura
