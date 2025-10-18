--!strict 

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Root = script.Parent.Parent
local Types = require(Root.Core.Types)
local ParamSchema = require(Root.Core.ParamSchema)

type Node = Types.Node

ParamSchema.register("notifyAppear", { type = "string", default = "slideDown"})
ParamSchema.register("notifyDuration", {type = "number", default = 0.18})
ParamSchema.register("notifyOffset", {type = "number", default = 20})
ParamSchema.register("notifyLifetime", {type = "number", default = 2.5})
ParamSchema.register("notifyDismissKey", {type = "string", default = "F"})

local EasingStyle = Enum.EasingStyle.Quad
local EasingDirection = Enum.EasingDirection.Out

local NotificationController = {}
NotificationController.__index = NotificationController

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


function NotificationController.Init(self, node: Node, _tree): ()
    self.node = node
    self.instance = node.Instance :: GuiObject
    self.basePosition = self.instance.Position
    self.baseSize = self.instance.Size
    self._dead = false
end

local function fade(root: GuiObject, to: number, dur: number)
	local info = TweenInfo.new(dur, EasingStyle, EasingDirection)
	local tweens = {}

	local function add(gui: GuiObject)
		if typeof((gui :: any).BackgroundTransparency) == "number" then
			table.insert(tweens, TweenService:Create(gui, info, { BackgroundTransparency = to }))
		end
		if gui:IsA("TextLabel") or gui:IsA("TextButton") then
			table.insert(tweens, TweenService:Create(gui, info, { TextTransparency = to }))
		end
		if gui:IsA("ImageLabel") or gui:IsA("ImageButton") then
			table.insert(tweens, TweenService:Create(gui, info, { ImageTransparency = to }))
		end
		local stroke = gui:FindFirstChildOfClass("UIStroke")
		if stroke then
			table.insert(tweens, TweenService:Create(stroke, info, { Transparency = to }))
		end
	end

	add(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then add(d) end
	end

	for _, t in ipairs(tweens) do t:Play() end
	local last = tweens[#tweens]
	if last then last.Completed:Wait() end
end

function NotificationController.OnOpen(self)
    if self._dead then return end
    local p = self.node.Params
    local appear = p.notifyAppear or "slideDown"
    local duration = p.notifyDuration or 0.18:: number
    local offset = p.notifyOffset or 20 :: number
    local lifetime = p.notifyLifetime or 2.5 :: number

    self.instance.Visible = true
    if appear == "fade" then
        fade(self.instance, 1, 0)
    elseif appear == "pop" then 
        self.instance.Position = self.basePosition
		self.instance.Size = UDim2.new(self.baseSize.X.Scale * 0.96, self.baseSize.X.Offset, self.baseSize.Y.Scale * 0.96, self.baseSize.Y.Offset)
		fade(self.instance, 1, 0)
    else
        self.instance.Position = computeStartPos(appear, self.basePosition, offset)
		fade(self.instance, 1, 0)
    end

    if appear == "fade" then 
        fade(self.instance, 0, duration)
    elseif appear == "pop" then 
		TweenService:Create(self.instance, TweenInfo.new(dur, EasingStyle, EasingDirection), { Size = self.baseSize }):Play()
    else
        TweenService:Create(self.instance, TweenInfo.new(dur, EasingStyle, EasingDirection), { Position = self.basePosition }):Play()
        fade(self.instance, 0, duration)
    end

    task.delay(lifetime, function()
        if self._dead or not self.node.Open then return end
        self.node.Tree:Close(self.node.Key)
    end)

    local keyName = tostring(p.notifyDismissKey or "F")
	local ok, keyEnum = pcall(function() return Enum.KeyCode[keyName] end)
	if ok and keyEnum then
		self._keyConnection = UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end
			if input.KeyCode == keyEnum and self.node.Open then
				self.node.Tree:Close(self.node.Key)
			end
		end)
	end
end

function NotificationController.OnClose(self)
    if self._dead then return end
    local p = self.node.Params
    local appear = p.notifyAppear or "slideDown"
    local duration = p.notifyDuration or 0.18 :: number
    local offset = p.notifyOffset or 20 :: number

    self.instance.Visible = true
    if appear == "fade" then 
        fade(self.instance, 1, duration)
    elseif appear == "pop" then 
        TweenService:Create(self.instance, TweenInfo.new(duration, EasingStyle, EasingDirection), {
            Size = UDim2.new(self.baseSize.X.Scale * 0.96, self.baseSize.X.Offset, self.baseSize.Y.Scale * 0.96, self.baseSize.Y.Offset)
        }):Play()
        fade(self.instance, 1, duration)
    else
        TweenService:Create(self.instance, TweenInfo.new(duration, EasingStyle, EasingDirection), {
            Position = computeStartPos(appear, self.basePosition, offset)
        }):Play()
        fade(self.instance, 1, duration)
    end

    if self._keyConn then
        self._keyConn:Disconnect()
        self._keyConn = nil
    end
    
    self.instance.Visible = false
    self.instance.Position = self.basePosition
    self.instance.Size = self.baseSize
    if self._keyConnection and self._keyConnection.Connected then
        self._keyConnection:Disconnect()
        self._keyConnection = nil
    end
end

function NotificationController.OnDestroy(self)
    self._dead = true
    if self._keyConnection and self._keyConnection.Connected then
        self._keyConnection:Disconnect()
        self._keyConnection = nil
    end
end