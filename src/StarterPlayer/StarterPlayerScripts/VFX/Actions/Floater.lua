local ActionEffectBase = require(script.Parent.Parent.ActionEffectBase)
local TweenService = game:GetService("TweenService")

local ANIMATION_PROFILES = {
	FloatUp = {
		movement = { direction = "up", distance = 1.5, easing = "Quad", easingDir = "Out" },
		visual = { type = "fade", scale = false },
		duration = 0.6,
	},

	FloatDown = {
		movement = { direction = "down", distance = 1.2, easing = "Quad", easingDir = "In" },
		visual = { type = "fade", scale = false },
		duration = 0.5,
	},

	PopUp = {
		movement = { direction = "up", distance = 1.5, easing = "Back", easingDir = "Out" },
		visual = { type = "pop", scale = true, scaleFrom = 0.5, scaleTo = 1.2 },
		duration = 0.6,
	},

	PopDown = {
		movement = { direction = "down", distance = 1, easing = "Back", easingDir = "In" },
		visual = { type = "pop", scale = true, scaleFrom = 1.5, scaleTo = 0 },
		duration = 0.4,
	},

	FloatUpPop = {
		movement = { direction = "up", distance = 2, easing = "Elastic", easingDir = "Out" },
		visual = { type = "popFade", scale = true, scaleFrom = 0.5, scaleTo = 1.2 },
		duration = 0.8,
	},

	Arc = {
		movement = { direction = "arc", distance = 1.5, arcHeight = 0.8, easing = "Sine", easingDir = "InOut" },
		visual = { type = "fade", scale = false },
		duration = 1.0,
	},

	Bounce = {
		movement = { direction = "up", distance = 1, easing = "Bounce", easingDir = "Out" },
		visual = { type = "fade", scale = false },
		duration = 0.8,
	},
}

Floater = setmetatable({}, ActionEffectBase)
Floater.__index = Floater

function Floater.new(): ()
	local self = ActionEffectBase.new()
	return setmetatable(self, Floater)
end

local function getAnimationConfig(animationInput)
	local profileName = "FloatUp"
	local overrides = {}

	if type(animationInput) == "string" then
		profileName = animationInput
	elseif type(animationInput) == "table" then
		profileName = animationInput.profile or "FloatUp"
		overrides = animationInput.overrides or {}
	end

	local profile = ANIMATION_PROFILES[profileName] or ANIMATION_PROFILES.FloatUp

	local config = {
		movement = {},
		visual = {},
		duration = overrides.duration or profile.duration,
	}

	for key, value in pairs(profile.movement) do
		config.movement[key] = overrides[key] or value
	end

	for key, value in pairs(profile.visual) do
		config.visual[key] = overrides[key] or value
	end

	return config
end

local function createMovementTween(part, startCFrame, config)
	local movement = config.movement
	local duration = config.duration
	local distance = movement.distance or 1.5

	local easingStyle = Enum.EasingStyle[movement.easing] or Enum.EasingStyle.Quad
	local easingDir = Enum.EasingDirection[movement.easingDir] or Enum.EasingDirection.Out
	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDir)

	local targetCFrame
	if movement.direction == "up" then
		targetCFrame = startCFrame + Vector3.new(0, distance, 0)
	elseif movement.direction == "down" then
		targetCFrame = startCFrame - Vector3.new(0, distance, 0)
	elseif movement.direction == "arc" then
		local arcHeight = movement.arcHeight or 0.8
		targetCFrame = startCFrame + Vector3.new(0, arcHeight, 0)
	else
		targetCFrame = startCFrame + Vector3.new(0, distance, 0)
	end

	return TweenService:Create(part, tweenInfo, { CFrame = targetCFrame })
end

local function createVisualTweens(label, config)
	local visual = config.visual
	local duration = config.duration
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

	local tweens = {}

	if visual.type == "fade" or visual.type == "popFade" then
		local fadeTween = TweenService:Create(label, tweenInfo, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		table.insert(tweens, fadeTween)
	end

	if visual.scale and (visual.type == "pop" or visual.type == "popFade") then
		local scaleFrom = visual.scaleFrom or 1
		local scaleTo = visual.scaleTo or 1.2

		label.Size = UDim2.fromOffset(100 * scaleFrom, 50 * scaleFrom)

		local scaleTween = TweenService:Create(label, tweenInfo, {
			Size = UDim2.fromOffset(100 * scaleTo, 50 * scaleTo),
		})
		table.insert(tweens, scaleTween)
	end

	return tweens
end

function Floater:OnPlayAction(context): ()
	local parent = context.parent or workspace
	local origin = context.origin or Vector3.zero
	local color = context.color or Color3.fromRGB(255, 200, 100)
	local amount = context.amount or 0
	local text = context.text or tostring(amount)

	local animConfig = getAnimationConfig(context.animation)

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Parent = parent
	self._janitor:Add(part)

	local randomOffset = Vector3.new(math.random(-2, 2) / 5, math.random() / 2, math.random(-2, 2) / 5)
	local startCFrame = CFrame.new(origin + randomOffset)
	part.CFrame = startCFrame

	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = part
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.new(0, 100, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.Parent = parent
	self._janitor:Add(billboard)

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.Size = UDim2.fromOffset(100, 50)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Parent = billboard

	local movementTween = createMovementTween(part, startCFrame, animConfig)
	movementTween:Play()
	self._janitor:Add(function()
		movementTween:Cancel()
	end)

	local visualTweens = createVisualTweens(label, animConfig)
	for _, tween in ipairs(visualTweens) do
		tween:Play()
		self._janitor:Add(function()
			tween:Cancel()
		end)
	end

	-- Use a flag-based cleanup mechanism to avoid thread cancellation issues
	local shouldStop = false
	task.delay(animConfig.duration, function()
		if not shouldStop and self._isPlaying then
			self:Stop()
		end
	end)
	self._janitor:Add(function()
		shouldStop = true
	end)
end

return Floater
