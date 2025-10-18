local Root = script.Parent.Parent

local Types = require(Root.Core.Types)
local ParamSchema = require(Root.Core.ParamSchema)
local ZIndexManager = require(Root.Core.ZIndexManager)

type Tree = Types.Tree
type Node = Types.Node

ParamSchema.register("modalBackdropColor", {type = "color3", default = Color3.fromRGB(0, 0, 0)})
ParamSchema.register("modalBackdropTransparency", {type = "number", default = 0.35})
ParamSchema.register("modalBackdropFade", {type = "number", default = 0.15})

local TweenService = game:GetService("TweenService")

local store: {[ScreenGui]: {[string]: Frame}} = {}
local backdropGeneration: {[Frame]: number} = {}
local activeTweens: {[Frame]: Tween} = {}

local function getScreenGui(node: Node): ScreenGui?
	return node.Instance:FindFirstAncestorOfClass("ScreenGui")
end

local function ensureBackdrop(node: Node): Frame?
	local screenGui: ScreenGui? = getScreenGui(node)
	if not screenGui then return nil end
	store[screenGui] = store[screenGui] or {}
	local group = node.Group or "_global"
	local existing = store[screenGui][group]
	
	if existing then
		local isValid = pcall(function() return existing.Parent end)
		if not isValid then
			store[screenGui][group] = nil
			activeTweens[existing] = nil
			backdropGeneration[existing] = nil
			existing = nil
		elseif not existing.Parent then
			existing.Parent = screenGui
		end
		
		if existing then
			return existing
		end
	end

	local f = Instance.new("Frame")
	f.Name = "_ModalBackdrop_" .. group
	f.BackgroundColor3 = node.Params.modalBackdropColor or Color3.new(0,0,0)
	f.BackgroundTransparency = 1
	f.Active = false   
	f.Selectable = false
	f.Size = UDim2.fromScale(1,1)
	f.Position = UDim2.fromScale(0,0)
	f.Visible = false
	f.ZIndex = 0
	f.Parent = screenGui

	f.Destroying:Connect(function()
		if store[screenGui] then
			store[screenGui][group] = nil
		end
		activeTweens[f] = nil
		backdropGeneration[f] = nil
	end)

	store[screenGui][group] = f
	return f
end

local function anyOtherOpenInGroup(tree: Tree, node: Node): boolean
	if not node.Group then return false end
	for _, n in pairs(tree.Groups[node.Group] or {}) do
		if n ~= node and n.Open then
			return true
		end
	end
	return false
end

local Modal = {}

function Modal.onOpen(tree: Tree, node: Node): ()
	if not node.Group then return end

	ZIndexManager.BringToFront(node)

	local backdrop = ensureBackdrop(node)
	if not backdrop then return end
	
	if activeTweens[backdrop] then
		activeTweens[backdrop]:Cancel()
		activeTweens[backdrop] = nil
	end
	
	backdrop.ZIndex = math.max(0, node.Instance.ZIndex - 1)
	backdrop.BackgroundColor3 = node.Params.modalBackdropColor or Color3.fromRGB(0, 0, 0)
	local targetT: number = node.Params.modalBackdropTransparency or 0.35
	local fadeDuration: number = node.Params.modalBackdropFade or 0.15

	backdropGeneration[backdrop] = (backdropGeneration[backdrop] or 0) + 1
	
	backdrop.Visible = true
	local tween = TweenService:Create(backdrop, TweenInfo.new(fadeDuration), { BackgroundTransparency = targetT })
	activeTweens[backdrop] = tween
	tween:Play()
end

function Modal.onClose(tree: Tree, node: Node): ()
	if not node.Group then return end
	if anyOtherOpenInGroup(tree, node) then
		local top: Node?
		for _, node in pairs(tree.Groups[node.Group] or {}) do 
			if node.Open and (not top or node.Instance.ZIndex > top.Instance.ZIndex) then 
				top = node
			end
		end
		local screenGui: ScreenGui? = getScreenGui(node)
		local bd = screenGui and store[screenGui] and store[screenGui][node.Group]
		if top and bd then 
			bd.ZIndex = math.max(0, top.Instance.ZIndex - 1)
		end
		return
	end

	local screenGui: ScreenGui? = getScreenGui(node)
	local bd = screenGui and store[screenGui] and store[screenGui][node.Group]
	if not bd then return end

	if activeTweens[bd] then
		activeTweens[bd]:Cancel()
		activeTweens[bd] = nil
	end

	local closeGeneration = backdropGeneration[bd] or 0
	
	local fadeDuration: number = node.Params.modalBackdropFade or 0.15
	local tween = TweenService:Create(bd, TweenInfo.new(fadeDuration), {BackgroundTransparency = 1})
	activeTweens[bd] = tween
	
	tween.Completed:Once(function(playbackState)
		if activeTweens[bd] == tween then
			activeTweens[bd] = nil
		end
		
		local bdValid = pcall(function() return bd.Parent end)
		if playbackState == Enum.PlaybackState.Completed 
			and bdValid
			and bd.Parent
			and backdropGeneration[bd] == closeGeneration then
			bd.Visible = false
		end
	end)
	
	tween:Play()
end

return Modal
