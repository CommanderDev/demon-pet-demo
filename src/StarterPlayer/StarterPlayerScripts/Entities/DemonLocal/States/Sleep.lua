local Sleep = {}
Sleep.__index = Sleep

function Sleep.new(demonLocal): ()
	local self = setmetatable({}, Idle)

	return self
end

function Sleep:enter(demonLocal): ()
	demonLocal:setIdleAnimationEnabled(true)

	if demonLocal.root then
		local currentPos = demonLocal.root.Position
		local currentFacing = demonLocal.root.CFrame.LookVector
		demonLocal:setGoal(currentPos, currentFacing)
	end
end

function Sleep:exit(demonLocal): () end

function Sleep:tick(demonLocal, dt: number): () end

return Sleep
