local player = game.Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local ClientMod = require(playerScripts.ClientMod)
local Formation = require(game.ReplicatedStorage.Helpers.Formation)
local FactionHelper = require(game.ReplicatedStorage.Helpers.FactionHelper)

local NumberUtility = require(game.ReplicatedStorage.Libraries.NumberUtility)
local DemonLocal = {}
DemonLocal.__index = DemonLocal

function DemonLocal.new(snap)
	local self = setmetatable({}, DemonLocal)

	self.id = snap.id
	self.seq = snap.seq or 0

	self.state = "Idle"
	self.smooth = 0.12
	self.stopDist = 2

	self._states = {}
	for _, mod in ipairs(script.States:GetChildren()) do
		if mod:IsA("ModuleScript") then
			self._states[mod.Name] = require(mod)
		end
	end

	self.model = self:_buildModelFromSnap(snap)
	self.root = self.model.PrimaryPart or self.model:FindFirstChildWhichIsA("BasePart")

	local pos = snap.pos or snap.position or Vector3.zero
	local facing = (snap.facing and snap.facing.Magnitude > 0) and snap.facing.Unit or Vector3.new(0, 0, -1)
	self.targetPosition = pos
	self.targetFacing = facing
	self._currentFacing = facing

	self.hp = snap.hp
	self.maxHp = snap.maxHp
	self.name = snap.name
	self.level = snap.level or 1
	self.unitIdentifier = snap.unitIdentifier
	self.faction = snap.faction or "Neutral"
	self.resources = snap.resources or {}
	self.statuses = snap.statuses or {}
	self.cooldowns = snap.cooldowns or {}
	self.charges = snap.charges or {}
	self.casting = snap.casting

	-- Reconstruct leaderRef from primitive values
	if snap.leaderId and snap.leaderKind then
		self._leaderRef = {
			id = snap.leaderId,
			kind = snap.leaderKind,
		}
	end

	-- Formation data for client-side computation
	self.formationSlotIndex = snap.formationSlotIndex
	self.formationMemberCount = snap.formationMemberCount
	self.formationType = snap.formationType
	self.formationSpacing = snap.formationSpacing
	if self.formationSlotIndex and self.formationMemberCount and self.formationType then
		self.slotOffset = Formation.computeSlotOffset(self.formationSlotIndex, self.formationMemberCount, {
			type = self.formationType,
			spacing = self.formationSpacing or 5,
		})
	end

	-- Goal-based positioning system
	self._goalPosition = pos
	self._goalFacing = facing
	self._positionThreshold = 0.1 -- studs - don't update if within this distance
	self._facingThreshold = 0.02 -- dot product threshold for facing
	self._basePosition = pos -- Position without idle animation applied

	self._attackAnim = {
		active = false,
		startTime = 0,
		windupDuration = 0.15, -- Time to wind up (lean back)
		lungeDuration = 0.2, -- Time to lunge forward
		returnDuration = 0.25, -- Time to return to normal
		windupAngle = -8, -- Degrees to lean back (negative = backward) - reduced for subtlety
		lungeAngle = 15, -- Degrees to lunge forward (positive = forward) - reduced for subtlety
	}

	-- Idle floating animation
	self._idleAnim = {
		enabled = true, -- Can be toggled on/off
		amplitude = 0.1, -- How far up/down to float (in studs)
		frequency = 0.5, -- How many cycles per second
		offset = math.random() * math.pi * 2,
	}

	self:_createDemonPlate()

	self:setState(snap.state or "Idle")
	return self
end

function DemonLocal:_getPlayerFaction(): string
	return "Player_" .. tostring(player.UserId)
end

function DemonLocal:_getHealthBarColor(): Color3
	local playerFaction = self:_getPlayerFaction()
	local relation = FactionHelper.getRelation(playerFaction, self.faction)

	if relation == FactionHelper.Relation.ALLY then
		return Color3.fromRGB(100, 255, 100) -- Bright Green
	elseif relation == FactionHelper.Relation.HOSTILE then
		return Color3.fromRGB(255, 80, 80) -- Bright Red
	else
		return Color3.fromRGB(200, 200, 100) -- Muted Yellow (Neutral)
	end
end

function DemonLocal:_createDemonPlate(): ()
	local plate = game.ReplicatedStorage.Assets.General.UI.DemonPlate:Clone()
	plate.Name = string.format("%s_%s", self.name, self.id)
	plate.Holder.NameLabel.Text = self.name

	local barColor = self:_getHealthBarColor()
	if plate.Holder.Bar.Progress then
		plate.Holder.Bar.Progress.BackgroundColor3 = barColor
	end

	plate.Parent = self.root
	self.plate = plate
	self:updateHealth(self.hp, self.maxHp)
	self:updateLevel(self.level)
end

function DemonLocal:updateLevel(level: number): ()
	self.plate.Holder.LevelLabel.Text = "Lv. " .. level
end

function DemonLocal:_buildModelFromSnap(snap): Model
	local demonsFolder = game.ReplicatedStorage.Assets.General.Demons

	local demonModel = demonsFolder:FindFirstChild(snap.unitIdentifier)
	assert(demonModel, ("Missing demon asset '%s'"):format(tostring(snap.unitIdentifier)))

	demonModel = demonModel:Clone()
	if not demonModel.PrimaryPart then
		demonModel.PrimaryPart = demonModel:FindFirstChildWhichIsA("BasePart")
	end
	assert(demonModel.PrimaryPart, ("Demon model '%s' must have a PrimaryPart"):format(tostring(snap.name)))

	demonModel.Name = string.format("%s_%s", snap.name, self.id)

	local position = snap.position or Vector3.zero
	local forward = (snap.facing and snap.facing.Magnitude > 0) and snap.facing.Unit or Vector3.new(0, 0, -1)
	demonModel:PivotTo(CFrame.lookAt(position, position + forward))
	for _, descendant in ipairs(demonModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Demon"
		end
	end

	demonModel.Parent = workspace

	return demonModel
end

function DemonLocal:applySnapshot(snap): ()
	if snap.seq and snap.seq <= (self.seq or 0) then
		return
	end
	self.seq = snap.seq or self.seq

	local formationChanged = false
	if snap.formationSlotIndex and snap.formationSlotIndex ~= self.formationSlotIndex then
		self.formationSlotIndex = snap.formationSlotIndex
		formationChanged = true
	end
	if snap.formationMemberCount and snap.formationMemberCount ~= self.formationMemberCount then
		self.formationMemberCount = snap.formationMemberCount
		formationChanged = true
	end
	if snap.formationType and snap.formationType ~= self.formationType then
		self.formationType = snap.formationType
		formationChanged = true
	end
	if snap.formationSpacing and snap.formationSpacing ~= self.formationSpacing then
		self.formationSpacing = snap.formationSpacing
		formationChanged = true
	end

	if formationChanged and self.formationSlotIndex and self.formationMemberCount and self.formationType then
		self.slotOffset = Formation.computeSlotOffset(self.formationSlotIndex, self.formationMemberCount, {
			type = self.formationType,
			spacing = self.formationSpacing or 5,
		})
	end

	if snap.position then
		local currentPos = self._basePosition or self._goalPosition
		local distance = (snap.position - currentPos).Magnitude

		if distance > 50 then
			self._goalPosition = snap.position
			self._basePosition = snap.position
			if self.root then
				local facing = self._goalFacing or Vector3.new(0, 0, -1)
				self.model:PivotTo(CFrame.lookAt(snap.position, snap.position + facing))
			end
		else
			self:setGoal(snap.position, nil)
		end
	end

	if snap.facing and snap.facing.Magnitude > 0 then
		self.targetFacing = snap.facing.Unit
		self:setGoal(nil, snap.facing.Unit)
	end

	if snap.state then
		self:setState(snap.state)
	end

	if snap.leaderId and snap.leaderKind then
		self._leaderRef = {
			id = snap.leaderId,
			kind = snap.leaderKind,
		}
	elseif snap.leaderId == nil then
		self._leaderRef = nil
	end

	if snap.hp ~= nil then
		local oldHp = self.hp
		self.hp = snap.hp
		if oldHp ~= self.hp then
			self:updateHealth(self.hp, oldHp)
		end
	end
	if snap.maxHp ~= nil then
		self.maxHp = snap.maxHp
	end
	if snap.name then
		self.name = snap.name
	end
	if snap.resources then
		self.resources = snap.resources
	end
	if snap.statuses then
		self.statuses = snap.statuses
	end
	if snap.cooldowns then
		self.cooldowns = snap.cooldowns
	end
	if snap.casting then
		self.casting = snap.casting
	end
	if snap.charges then
		self.charges = snap.charges
	end
	if snap.unitIdentifier then
		self.unitIdentifier = snap.unitIdentifier
	end
	if snap.faction then
		self.faction = snap.faction
	end

	if snap.targetId ~= nil then
		self.targetId = snap.targetId
	end

	if snap.level then
		self.level = snap.level
		self:updateLevel(self.level)
	end
end

function DemonLocal:setState(stateName)
	if not stateName or self.state == stateName then
		return
	end

	if self._currentState and self._currentState.exit then
		self._currentState:exit(self)
	end

	local nextState = self._states[stateName]
	if not nextState then
		warn(("DemonLocal %s missing state '%s'"):format(self.id, tostring(stateName)))
		return
	end

	self._currentState = nextState
	self.state = stateName
	if self._currentState.enter then
		self._currentState:enter(self)
	end
end

function DemonLocal:_mapServerStateToPose(state)
	if state == "Cast" then
		return "Anticipate"
	elseif state == "Attack" then
		return "Attack"
	elseif state == "Dead" then
		return "Dead"
	elseif state == "FollowLeader" or state == "Chase" then
		return "Run"
	else
		return "Idle"
	end
end

function DemonLocal:stopMove(): ()
	self._move = nil
end

function DemonLocal:setMoveDirection(direction: Vector3, speed: number?): ()
	self._move = { kind = "direction", direction = direction.Unit, speed = speed or self.moveSpeed }
end

function DemonLocal:moveTo(point: Vector3, speed: number?): ()
	self._move = { kind = "point", goal = point, speed = speed or self.moveSpeed, arrive = 3 }
end

function DemonLocal:_sendMoveIntent(vel: Vector3): ()
	ClientMod:FireServer("MoveDemon", {
		id = self.id,
		vel = vel,
		clientTime = os.clock(),
	})
end

function DemonLocal:sync(data)
	self:applySnapshot(data)
end

function DemonLocal:updateHealth(newHp: number, oldHp: number): ()
	if self.plate then
		local relation = FactionHelper.getRelation(self:_getPlayerFaction(), self.faction)
		local animationName = "FloatUp"
		if relation == FactionHelper.Relation.ALLY then
			animationName = "FloatDown"
		end

		if oldHp and newHp < oldHp then
			ClientMod.visualEffectsManager:Play("Floater", {
				origin = self.root.Position,
				amount = NumberUtility.FormatCurrency(math.floor(oldHp - newHp)),
				color = Color3.fromRGB(255, 0, 0),
				animation = {
					profile = animationName,
					overrides = { duration = 1 },
				},
			})
		elseif oldHp and newHp > oldHp then
			ClientMod.visualEffectsManager:Play("Floater", {
				origin = self.root.Position,
				amount = NumberUtility.FormatCurrency(math.floor(newHp - oldHp)),
				color = Color3.fromRGB(0, 255, 0),
				animation = {
					profile = animationName,
					overrides = { duration = 1 },
				},
			})
		end
		local healthPercent = math.clamp(newHp / self.maxHp, 0, 1)
		self.plate.Holder.Bar.Progress.Size = UDim2.fromScale(healthPercent, 1)

		local barColor = self:_getHealthBarColor()
		if self.plate.Holder.Bar.Progress then
			self.plate.Holder.Bar.Progress.BackgroundColor3 = barColor
		end
	end
end

function DemonLocal:_computeFollowGoal(): Vector3?
	if not self._leaderRef or not self.slotOffset then
		return nil
	end
	local leaderCFrame = self:getLeaderCFrame(self._leaderRef)
	if not leaderCFrame then
		return nil
	end

	return leaderCFrame:PointToWorldSpace(self.slotOffset)
end

function DemonLocal:getLeaderCFrame(leaderRef: { id: string, kind: string }): CFrame
	if not leaderRef then
		return nil
	end

	if leaderRef.kind == "Player" then
		local player = game.Players:GetPlayerByUserId(leaderRef.id)
		local character = player and player.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		return humanoidRootPart and humanoidRootPart.CFrame or nil
	end
end

function DemonLocal:setGoal(position: Vector3?, facing: Vector3?): ()
	if position then
		self._goalPosition = position
	end
	if facing and facing.Magnitude > 0 then
		self._goalFacing = facing.Unit
	end
end

function DemonLocal:_hasReachedGoal(): boolean
	if not self.root then
		return true
	end

	local currentPos = self._basePosition
	local currentFacing = self.root.CFrame.LookVector

	local posDistance = (self._goalPosition - currentPos).Magnitude
	if posDistance > self._positionThreshold then
		return false
	end

	local facingDot = currentFacing:Dot(self._goalFacing)
	if facingDot < (1.0 - self._facingThreshold) then
		return false
	end

	return true
end

function DemonLocal:playAttackAnimation(): ()
	self._attackAnim.active = true
	self._attackAnim.startTime = os.clock()
end

function DemonLocal:setIdleAnimationEnabled(enabled: boolean): ()
	self._idleAnim.enabled = enabled
end

function DemonLocal:setIdleAnimationParams(amplitude: number?, frequency: number?): ()
	if amplitude then
		self._idleAnim.amplitude = amplitude
	end
	if frequency then
		self._idleAnim.frequency = frequency
	end
end

function DemonLocal:_updateAttackAnimation(): CFrame?
	if not self._attackAnim.active then
		return nil
	end

	local elapsed = os.clock() - self._attackAnim.startTime
	local anim = self._attackAnim
	local totalDuration = anim.windupDuration + anim.lungeDuration + anim.returnDuration

	if elapsed >= totalDuration then
		self._attackAnim.active = false
		return nil
	end

	local tiltAngle = 0

	if elapsed < anim.windupDuration then
		local progress = elapsed / anim.windupDuration
		tiltAngle = anim.windupAngle * progress
	elseif elapsed < (anim.windupDuration + anim.lungeDuration) then
		local lungeElapsed = elapsed - anim.windupDuration
		local progress = lungeElapsed / anim.lungeDuration
		tiltAngle = anim.windupAngle + (anim.lungeAngle - anim.windupAngle) * progress
	else
		local returnElapsed = elapsed - (anim.windupDuration + anim.lungeDuration)
		local progress = returnElapsed / anim.returnDuration
		tiltAngle = anim.lungeAngle * (1 - progress)
	end

	return CFrame.Angles(math.rad(tiltAngle), 0, 0)
end

function DemonLocal:_updateIdleAnimation(): number
	if not self._idleAnim.enabled then
		return 0
	end

	local time = os.clock()
	local anim = self._idleAnim

	local phase = (time * anim.frequency * math.pi * 2) + anim.offset
	local yOffset = math.sin(phase) * anim.amplitude

	return yOffset
end

function DemonLocal:tick(dt): ()
	if not self.model or not self.root then
		return
	end

	if self._currentState and self._currentState.tick then
		self._currentState:tick(self, dt)
	end

	local idleYOffset = self:_updateIdleAnimation()

	local needsUpdate = not self:_hasReachedGoal() or self._attackAnim.active or idleYOffset ~= 0

	if needsUpdate then
		local currentPos = self._basePosition
		local currentFacing = self.root.CFrame.LookVector

		local posDistance = (self._goalPosition - currentPos).Magnitude
		local moveSpeed = 20 -- studs per second
		local maxMove = moveSpeed * dt

		local newBasePos
		if posDistance > maxMove then
			local direction = (self._goalPosition - currentPos).Unit
			newBasePos = currentPos + (direction * maxMove)
		else
			newBasePos = self._goalPosition
		end

		self._basePosition = newBasePos

		local visualPos = newBasePos + Vector3.new(0, idleYOffset, 0)

		local facingSpeed = (self.state == "Attack") and 4 or 8
		local newFacing = currentFacing:Lerp(self._goalFacing, math.min(dt * facingSpeed, 1))

		local baseTransform = CFrame.lookAt(visualPos, visualPos + newFacing)

		local attackTilt = self:_updateAttackAnimation()
		if attackTilt then
			local finalTransform = baseTransform * attackTilt
			self.model:PivotTo(finalTransform)
		else
			self.model:PivotTo(baseTransform)
		end
	end
end

function DemonLocal:destroy(): ()
	if self._currentState and self._currentState.exit then
		self._currentState:exit(self)
	end

	if self.model then
		self.model:Destroy()
		self.model = nil
		self.root = nil
	end

	if self.plate then
		self.plate = nil
	end

	self._states = nil
	self._currentState = nil
	self._move = nil
	self._leaderRef = nil
	self.targetId = nil
end

return DemonLocal
