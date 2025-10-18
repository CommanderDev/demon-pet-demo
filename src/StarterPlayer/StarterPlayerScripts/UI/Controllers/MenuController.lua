--!strict

--[[
    Description: Plays a simple appear/disappear animation for menus/panels
]]

local TweenService = game:GetService("TweenService")

local DEFAULT_APPEAR: number = "fade"
local DEFAULT_DURATION: number = 0.18
local DEFAULT_OFFSET: number = 24

local EasingStyle = {
    Quad = Enum.EasingStyle.Quad,
    Sine = Enum.EasingStyle.Sine,
    Cubic = Enum.EasingStyle.Cubic,
    Back = Enum.EasingStyle.Back,
    Linear = Enum.EasingStyle.Linear,
}

local EasingDirection = {
    Out = Enum.EasingDirection.Out,
    In = Enum.EasingDirection.In,
    InOut = Enum.EasingDirection.InOut,
}

local function readStyle(p: any)
	return EasingStyle[tostring(p or "")] or Enum.EasingStyle.Quad
end
local function readDir(p: any)
	return EasingDirection[tostring(p or "")] or Enum.EasingDirection.Out
end

local function gatherGuiObjects(root: GuiObject): {GuiObject}
	local list: {GuiObject} = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then
			table.insert(list, d)
		end
	end
	return list
end

local function snapshotAlpha(root: GuiObject)
	local base = {}

	local function capOne(gui: GuiObject)
		local e = { inst = gui }
		if typeof((gui :: any).BackgroundTransparency) == "number" then
			e.bg = (gui :: any).BackgroundTransparency
		end
		if gui:IsA("TextLabel") or gui:IsA("TextButton") then
			e.text = gui.TextTransparency
		end
		if gui:IsA("ImageLabel") or gui:IsA("ImageButton") then
			e.image = gui.ImageTransparency
		end
		local stroke = gui:FindFirstChildOfClass("UIStroke")
		if stroke then
			e.stroke = stroke.Transparency
			e.strokeRef = stroke
		end
		table.insert(base, e)
	end

	capOne(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then capOne(d) end
	end
	return base
end

local function setAlphaInstant(root: GuiObject, base, alpha: number)
	for _, e in ipairs(base) do
		local gui = e.inst
		if e.bg ~= nil then
			(gui :: any).BackgroundTransparency = e.bg + (1 - e.bg) * alpha
		end
		if e.text ~= nil and (gui:IsA("TextLabel") or gui:IsA("TextButton")) then
			gui.TextTransparency = e.text + (1 - e.text) * alpha
		end
		if e.image ~= nil and (gui:IsA("ImageLabel") or gui:IsA("ImageButton")) then
			gui.ImageTransparency = e.image + (1 - e.image) * alpha
		end
		if e.strokeRef and e.stroke ~= nil then
			e.strokeRef.Transparency = e.stroke + (1 - e.stroke) * alpha
		end
	end
end

local function tweenAlphaTo(root: GuiObject, base, toAlpha: number, dur: number, style, dir): {Tween}
	local TweenService = game:GetService("TweenService")
	local info = TweenInfo.new(dur, style, dir)
	local tweens = {}

	for _, e in ipairs(base) do
		local gui = e.inst
		local tgtBg   = e.bg    ~= nil and (e.bg    + (1 - e.bg)     * toAlpha) or nil
		local tgtText = e.text  ~= nil and (e.text  + (1 - e.text)   * toAlpha) or nil
		local tgtImg  = e.image ~= nil and (e.image + (1 - e.image)  * toAlpha) or nil
		local tgtStroke = e.stroke ~= nil and (e.stroke + (1 - e.stroke) * toAlpha) or nil

		local props = {}
		if tgtBg   ~= nil then props.BackgroundTransparency = tgtBg end
		if tgtText ~= nil and (gui:IsA("TextLabel") or gui:IsA("TextButton")) then props.TextTransparency = tgtText end
		if tgtImg  ~= nil and (gui:IsA("ImageLabel") or gui:IsA("ImageButton")) then props.ImageTransparency = tgtImg end

		if next(props) then
			table.insert(tweens, TweenService:Create(gui, info, props))
		end
		if e.strokeRef and tgtStroke ~= nil then
			table.insert(tweens, TweenService:Create(e.strokeRef, info, { Transparency = tgtStroke }))
		end
	end

	for _, t in ipairs(tweens) do t:Play() end
	return tweens
end

local MenuController = {}
MenuController.__index = MenuController

function MenuController.Init(self, node, tree)
    self.node = node
    self.tree = tree
    self.instance = node.Instance :: GuiObject
    self.basePosition = (self.instance :: GuiObject).Position
    self.baseSize = (self.instance :: GuiObject).Size
    self.animPlaying = false
	self._alphaBase = snapshotAlpha(self.instance)
	self._currentTweens = {}
	self._wasOpen = false
end

local function computeStartPos(kind: string, base: UDim2, offsetPx: number): UDim2
	if kind == "slideUp" then
		return UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset + offsetPx)
	elseif kind == "slideDown" then
		return UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset - offsetPx)
	elseif kind == "slideLeft" then
		return UDim2.new(base.X.Scale, base.X.Offset + offsetPx, base.Y.Scale, base.Y.Offset)
	elseif kind == "slideRight" then
		return UDim2.new(base.X.Scale, base.X.Offset - offsetPx, base.Y.Scale, base.Y.Offset)
	else
		return base
	end
end

function MenuController:_cancelCurrentTweens()
	for _, tween in ipairs(self._currentTweens) do
		if tween and tween.PlaybackState == Enum.PlaybackState.Playing then
			tween:Cancel()
		end
	end
	self._currentTweens = {}
end

function MenuController:_playIn(): ()
	self:_cancelCurrentTweens()
	
	local p = self.node.Params
	local appear = tostring(p.appear or DEFAULT_APPEAR)
	local dur = tonumber(p.appearDuration or DEFAULT_DURATION) :: number
	local offset = tonumber(p.appearOffset or DEFAULT_OFFSET) :: number
	local style = readStyle(p.easingStyle)
	local dir = readDir(p.easingDirection)

	self.instance.Visible = true
	self.animPlaying = true

	if appear == "fade" then
		setAlphaInstant(self.instance, self._alphaBase, 1) 
	elseif appear == "pop" then
		self.instance.Position = self.basePosition
		self.instance.Size = UDim2.new(self.baseSize.X.Scale * 0.96, self.baseSize.X.Offset, self.baseSize.Y.Scale * 0.96, self.baseSize.Y.Offset)
		setAlphaInstant(self.instance, self._alphaBase, 1)
	else
		self.instance.Position = computeStartPos(appear, self.basePosition, offset)
		setAlphaInstant(self.instance, self._alphaBase, 1)
	end

	if appear == "fade" then
		local tweens = tweenAlphaTo(self.instance, self._alphaBase, 0, dur, style, dir)
		for _, t in ipairs(tweens) do 
			table.insert(self._currentTweens, t)
		end
		if tweens[#tweens] then tweens[#tweens].Completed:Wait() end
	elseif appear == "pop" then
		local info = TweenInfo.new(dur, style, dir)
		local sizeTween = TweenService:Create(self.instance, info, { Size = self.baseSize })
		table.insert(self._currentTweens, sizeTween)
		sizeTween:Play()
		local tweens = tweenAlphaTo(self.instance, self._alphaBase, 0, dur, style, dir)
		for _, t in ipairs(tweens) do 
			table.insert(self._currentTweens, t)
		end
		if tweens[#tweens] then tweens[#tweens].Completed:Wait() end
	else
		local info = TweenInfo.new(dur, style, dir)
		local posTween = TweenService:Create(self.instance, info, { Position = self.basePosition })
		table.insert(self._currentTweens, posTween)
		posTween:Play()
		local tweens = tweenAlphaTo(self.instance, self._alphaBase, 0, dur, style, dir)
		for _, t in ipairs(tweens) do 
			table.insert(self._currentTweens, t)
		end
		if tweens[#tweens] then tweens[#tweens].Completed:Wait() end
	end

	self.animPlaying = false
	self._currentTweens = {}
end


function MenuController:_playOut(): ()
	self:_cancelCurrentTweens()
	
	local p = self.node.Params
	local appear = tostring(p.appear or DEFAULT_APPEAR)
	local dur = tonumber(p.appearDuration or DEFAULT_DURATION) :: number
	local offset = tonumber(p.appearOffset or DEFAULT_OFFSET) :: number
	local style = readStyle(p.easingStyle)
	local dir = readDir(p.easingDirection)

	self.instance.Visible = true
	self.animPlaying = true

	if appear == "fade" then
		local tweens = tweenAlphaTo(self.instance, self._alphaBase, 1, dur, style, dir)
		for _, t in ipairs(tweens) do 
			table.insert(self._currentTweens, t)
		end
		if tweens[#tweens] then tweens[#tweens].Completed:Wait() end
	elseif appear == "pop" then
		local info = TweenInfo.new(dur, style, dir)
		local sizeTween = TweenService:Create(self.instance, info, { Size = UDim2.new(self.baseSize.X.Scale * 0.96, self.baseSize.X.Offset, self.baseSize.Y.Scale * 0.96, self.baseSize.Y.Offset) })
		table.insert(self._currentTweens, sizeTween)
		sizeTween:Play()
		local tweens = tweenAlphaTo(self.instance, self._alphaBase, 1, dur, style, dir)
		for _, t in ipairs(tweens) do 
			table.insert(self._currentTweens, t)
		end
		if tweens[#tweens] then tweens[#tweens].Completed:Wait() end
	else
		local info = TweenInfo.new(dur, style, dir)
		local posTween = TweenService:Create(self.instance, info, { Position = computeStartPos(appear, self.basePosition, offset) })
		table.insert(self._currentTweens, posTween)
		posTween:Play()
		local tweens = tweenAlphaTo(self.instance, self._alphaBase, 1, dur, style, dir)
		for _, t in ipairs(tweens) do 
			table.insert(self._currentTweens, t)
		end
		if tweens[#tweens] then tweens[#tweens].Completed:Wait() end
	end

	self.instance.Visible = false
	self.instance.Position = self.basePosition
	self.instance.Size = self.baseSize
	setAlphaInstant(self.instance, self._alphaBase, 0)

	self.animPlaying = false
	self._currentTweens = {}
end


function MenuController.OnOpen(self, data)
    if self._wasOpen then return end
    self._wasOpen = true
    self:_playIn()
end

function MenuController.OnClose(self, data)
    if not self._wasOpen then 
        return 
    end
    self._wasOpen = false
    self:_playOut()
end

function MenuController.OnDestroy(self)
    -- Nothing special
end

return MenuController