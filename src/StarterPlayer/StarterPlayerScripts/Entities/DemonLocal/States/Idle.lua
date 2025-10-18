local Idle = {}
Idle.__index = Idle

function Idle.new(demonLocal): ()
	local self = setmetatable({}, Idle)

	return self
end

function Idle:enter(demonLocal): ()
	demonLocal:setIdleAnimationEnabled(true)

	if demonLocal.root then
		local currentPos = demonLocal.root.Position
		local currentFacing = demonLocal.root.CFrame.LookVector
		demonLocal:setGoal(currentPos, currentFacing)
	end
end

function Idle:exit(demonLocal): () end

function Idle:tick(demonLocal, dt: number): () end

return Idle
