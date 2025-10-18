--!strict

--[[
    Description: How a small "x" close affordance on hover. Click to close this node
]]

local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Types = require(Root.Core.Types)
local ParamSchema = require(Root.Core.ParamSchema)

type Node = Types.Node

local function effectiveZ(node: Types.Node): number
	local sg = node.Instance:FindFirstAncestorOfClass("ScreenGui")
	local display = sg and sg.DisplayOrder or 0
	return display * 100000 + (node.Instance.ZIndex or 0)
end

local function topInStack(tree: Types.Tree, group: string): Types.Node?
	local stacks = (tree :: any)._stacks
	if not stacks then return nil end
	local s = stacks[group]
	if not s or #s == 0 then return nil end
	for i = #s, 1, -1 do
		if s[i].Open then return s[i] end
	end
	return nil
end

local function isTopMost(node: Types.Node): boolean
	if node.Group and (node.Tree :: any)._stacks and (node.Tree :: any)._stacks[node.Group] then
		return topInStack(node.Tree, node.Group) == node
	end
	local sg = node.Instance:FindFirstAncestorOfClass("ScreenGui")
	local best: Types.Node? = nil
	local bestZ = -math.huge
	for _, n in pairs(node.Tree.Index) do
		if n.Open and n.Instance.Visible and n.Instance:IsDescendantOf(sg) then
			local z = effectiveZ(n)
			if z > bestZ then
				best, bestZ = n, z
			end
		end
	end
	return best == node
end

local HoverClose = {}

function HoverClose.Attach(node: Node): ()
    local instance = node.Instance
    if not instance:IsA("GuiObject") then return end

    local p = node.Params
    local padding = tonumber(p.hoverClosePadding or 8) :: number
	local sizePx = tonumber(p.hoverCloseSize or 20) :: number
	local zBias  = tonumber(p.hoverCloseZBias or 2) :: number
	local always = (p.hoverCloseAlwaysVisible == true)

    local btn = Instance.new("TextButton")
	btn.Name = "_HoverClose_" .. node.Key
	btn.AnchorPoint = Vector2.new(1, 0)
	btn.Position = UDim2.new(1, -padding, 0, padding)
	btn.Size = UDim2.fromOffset(sizePx, sizePx)
	btn.BackgroundTransparency = 0.25
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	btn.Text = "×"
	btn.TextScaled = true
	btn.TextColor3 = Color3.fromRGB(240, 240, 245)
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Visible = always
	btn.ZIndex = instance.ZIndex + zBias
	btn.Parent = instance

	-- rounded corner + subtle stroke
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.floor(sizePx/2))
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Transparency = 0.2
	stroke.Color = Color3.fromRGB(255,255,255)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn

    local function show()
		if btn.Visible then return end
		btn.Visible = true
		TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.25, TextTransparency = 0 }):Play()
	end
	local function hide()
		if always then return end
		TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		task.delay(0.12, function() if not always then btn.Visible = false end end)
	end

    local enterConnection = instance.MouseEnter:Connect(function()
        if not node.Open then return end
        if not isTopMost(node) then return end
        show()
    end)

    local leaveConnection = instance.MouseLeave:Connect(function()
        hide()
    end)

    local zConnection = instance:GetPropertyChangedSignal("ZIndex"):Connect(function()
        btn.ZIndex = instance.ZIndex + zBias
    end)

    local clickConnection = btn.Activated:Connect(function()
        if not node.Open then return end
        if not isTopMost(node) then return end
        node.Tree:Close(node.Key)
    end)

    local changedConnection = node.Tree.Changed:Connect(function(changed)
        if changed ~= node then return end
        if node.Open then 
            if always then btn.Visible = true else btn.Visible = false end
        else
            btn.Visible = false
        end
    end)

    if not node.Open and not always then
		btn.Visible = false
		btn.BackgroundTransparency = 1
		btn.TextTransparency = 1
	end

    return {
        Disconnect = function()
            if enterConnection.Connected then enterConnection:Disconnect() end
            if leaveConnection.Connected then leaveConnection:Disconnect() end
            if zConnection.Connected then zConnection:Disconnect() end
            if clickConnection.Connected then clickConnection:Disconnect() end
            if changedConnection.Connected then changedConnection:Disconnect() end
            btn:Destroy()
        end,
    }
end

function HoverClose.Detach(node: Node, handle)
    if handle and type(handle) == "table" and type(handle.Disconnect) == "function" then
        handle:Disconnect()
    end
end

return HoverClose
