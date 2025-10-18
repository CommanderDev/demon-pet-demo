--!strict

local UserInputService = game:GetService("UserInputService")

local Diagnostics = {}
Diagnostics.__index = Diagnostics

export type Diagnostics = {
	Toggle: (self: Diagnostics) -> (),
	Show: (self: Diagnostics) -> (),
	Hide: (self: Diagnostics) -> (),
	Destroy: (self: Diagnostics) -> (),
}

local function createGui(parent: PlayerGUi): ScreenGui
    local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "_NovaUIDiagnostics"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.DisplayOrder = 10_000
	ScreenGui.Enabled = false
	ScreenGui.Parent = parent
	return ScreenGui
end

local function makePanel(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = "Panel"
	f.AnchorPoint = Vector2.new(1, 0)
	f.Position = UDim2.fromScale(1, 0)
	f.Size = UDim2.new(0, 420, 0, 340)
	f.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	f.Parent = parent

	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, 8)
	ui.Parent = f

	local pad = Instance.new("UIPadding")
	pad.PaddingTop    = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft   = UDim.new(0, 12)
	pad.PaddingRight  = UDim.new(0, 12)
	pad.Parent = f

	return f
end

local function mkText(parent: Instance, name: string, size: number, bold: boolean?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.FontFace = Font.new(bold and "rbxasset://fonts/families/SourceSansPro.json" or "rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	t.TextSize = size
	t.TextColor3 = Color3.fromRGB(230, 235, 245)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.Size = UDim2.new(1, 0, 0, 0)
	t.Parent = parent
	return t
end

local function mkSection(parent: Instance, title: string): Frame
	local c = Instance.new("Frame")
	c.Name = "Section"
	c.BackgroundTransparency = 1
	c.AutomaticSize = Enum.AutomaticSize.Y
	c.Size = UDim2.new(1, 0, 0, 0)
	c.Parent = parent

	mkText(c, "Title", 16, true).Text = title

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.FillDirection = Enum.FillDirection.Vertical
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = c

	return c
end

local function kvLines(parent: Instance, data: {[string]: any})
	for k, v in pairs(data) do
		local line = mkText(parent, "Row", 14, false)
		local display = typeof(v) == "Color3" and ("Color3(%d,%d,%d)"):format(math.floor(v.R*255), math.floor(v.G*255), math.floor(v.B*255))
			or (typeof(v) == "UDim2" and tostring(v))
			or (typeof(v) == "boolean" and (v and "true" or "false"))
			or tostring(v)
		line.Text = (`{k}: {display}`)
	end
end

function Diagnostics.new(tree: any): Diagnostics
    local self = setmetatable({}, Diagnostics)

    self._tree = tree
    self._playerGui = tree.PlayerGui
    self._screenGui = createGui(self._playerGui)
   self._panel = makePanel(self._screenGui)

   local scroller = Instance.new("ScrollingFrame")
   scroller.Name = "Scroll"
   scroller.BackgroundTransparency = 1
   scroller.BorderSizePixel = 0
   scroller.AutomaticSize = Enum.AutomaticSize.None
   scroller.Size = UDim2.new(1, 0, 1, 0)
   scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
   scroller.ScrollBarThickness = 6
   scroller.Parent = self._panel

   local list = Instance.new("UIListLayout")
   list.Padding = UDim.new(0, 8)
   list.FillDirection = Enum.FillDirection.Vertical
   list.SortOrder = Enum.SortOrder.LayoutOrder
   list.Parent = scroller

   -- rebuild on change
   self._changedConnection = tree.Changed:Connect(function()
       if self._screenGui.Enabled then
           self:_rebuild()
       end
   end)

   self._hotKeyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end
        if input.KeyCode == Enum.KeyCode.U and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then 
            self:Toggle()
        end
    end)

    self:_rebuild()
    return ( self :: any) :: Diagnostics
end

function Diagnostics:_rebuild()
	local scroll = self._panel:FindFirstChild("Scroll") :: ScrollingFrame
	if not scroll then return end
	for _, ch in ipairs(scroll:GetChildren()) do
		if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
	end

	local secTree = mkSection(scroll, "Tree")
	mkText(secTree, "Line", 14, false).Text = ("Root nodes: %d"):format(#self._tree.RootNodes)
	mkText(secTree, "Line", 14, false).Text = ("Index size: %d"):format((function(t)local n=0 for _ in pairs(t) do n+=1 end return n end)(self._tree.Index))

	local secGroups = mkSection(scroll, "Groups")
	for gname, map in pairs(self._tree.Groups) do
		local openKeys = {}
		for _, n in pairs(map) do
			if n.Open then table.insert(openKeys, n.Key) end
		end
		local line = mkText(secGroups, "Line", 14, false)
		line.Text = (`{gname}  |  open: {table.concat(openKeys, ", ")}`)
	end

	local secOpen = mkSection(scroll, "Open Nodes")
	for key, n in pairs(self._tree.Index) do
		if n.Open then
			local row = mkText(secOpen, "Line", 14, false)
			row.Text = (`{key}  ({string.lower(n.Kind)})  Group={tostring(n.Group or "-")}  Policy={tostring(n.PolicyName or "Mutex")}`)
		end
	end

	local secFocus = mkSection(scroll, "Hover Node Params")
	local mouse = game:GetService("Players").LocalPlayer:GetMouse()
	local target: Instance? = mouse.Target or nil
    local guiObjects = self._tree.PlayerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
    local focusNode = nil
    for _, gui in ipairs(guiObjects) do
        local cur = gui
        while cur and cur:IsA("GuiObject") do
            if cur:GetAttribute("UI_Node") then
                local key = cur:GetAttribute("UI_Key") or cur.Name
                focusNode = self._tree.Index[key]
                if focusNode then break end
            end
            cur = cur.Parent
        end
        if focusNode then break end
    end
	if focusNode then
		mkText(secFocus, "Line", 14, true).Text = (`{focusNode.Key}`)
		kvLines(secFocus, focusNode.Params)
	else
		mkText(secFocus, "Line", 14, false).Text = "(move mouse over a UI node)"
	end

	-- adjust canvas
	task.defer(function()
		local total = 0
		for _, ch in ipairs(scroll:GetChildren()) do
			if ch:IsA("Frame") or ch:IsA("TextLabel") then
				total += ch.AbsoluteSize.Y + 8
			end
		end
		scroll.CanvasSize = UDim2.new(0, 0, 0, total)
	end)
end

function Diagnostics:Toggle()
	self._screenGui.Enabled = not self._screenGui.Enabled
	if self._screenGui.Enabled then self:_rebuild() end
end

function Diagnostics:Show()
	self._screenGui.Enabled = true
	self:_rebuild()
end

function Diagnostics:Hide()
	self._screenGui.Enabled = false
end

function Diagnostics:Destroy()
	if self._changedConnection then self._changedConnection:Disconnect() end
	if self._hotkeyConnection then self._hotkeyConnection:Disconnect() end
	if self._screenGui then self._screenGui:Destroy() end
	setmetatable(self, nil)
end

return Diagnostics