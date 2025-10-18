--!strict

--[[
    Description: When the node is open, clicking outside closes it
]]

local Root = script.Parent.Parent
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Types = require(Root.Core.Types)
local ParamSchema = require(Root.Core.ParamSchema)

ParamSchema.register("closeOutsideWhenVisibleOnly", { type = "boolean", default = true })

type Node = Types.Node

local CloseOnOutside = {}

-- Global lock to ensure only one node processes each frame's clicks
local currentlyProcessing = false

local function readBool(v: any, default: boolean): boolean
	if typeof(v) == "boolean" then return v end
	return default
end

local function isPointerOverNode(node: Node, screenX: number, screenY: number): boolean
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local objects = playerGui:GetGuiObjectsAtPosition(screenX, screenY)
	for _, gui in ipairs(objects) do
		if gui:IsDescendantOf(node.Instance) then
			return true
		end
	end
	return false
end

local function topOpenNodeInScreenGui(tree, screenGui: ScreenGui)
	local top: Types.Node? = nil
	for _, node in pairs(tree.Index) do
		if node.Open and node.Instance:IsDescendantOf(screenGui) and node.Instance.Visible then
			if not top or node.Instance.ZIndex > top.Instance.ZIndex then
				top = node
			end
		end
	end
	return top
end

function CloseOnOutside.Attach(node: Node)
	local inst = node.Instance
	if not inst:IsA("GuiObject") then return end

	local params = node.Params or {}
	local cfgRoot = inst:FindFirstChild("Behaviors")
	local cfg = (cfgRoot and cfgRoot:FindFirstChild("CloseOnOutside")) or nil

	local whenVisibleOnly = readBool(
		(cfg and cfg:FindFirstChild("WhenVisibleOnly") and (cfg :: any).WhenVisibleOnly.Value)
			or params.closeOutsideWhenVisibleOnly,
		true
	)

	local screenGui = inst:FindFirstAncestorOfClass("ScreenGui")

	local lastOpenedAt = 0
	local lastBecameTopAt = 0
	local changedCon = node.Tree.Changed:Connect(function(changed)
		if changed == node and node.Open then
			lastOpenedAt = os.clock()
		end
		if changed ~= node and node.Open then
			local top = topOpenNodeInScreenGui(node.Tree, screenGui)
			if top == node then
				lastBecameTopAt = os.clock()
			end
		end
	end)

	local clickCon = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or not node.Open then return end
		if whenVisibleOnly and not inst.Visible then return end

		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end

		if currentlyProcessing then
			return
		end

		local top = topOpenNodeInScreenGui(node.Tree, screenGui)
		if top ~= node then 
			return 
		end

		currentlyProcessing = true

		local now = os.clock()
		if now - lastOpenedAt < 0.05 then 
			currentlyProcessing = false
			return 
		end
		if now - lastBecameTopAt < 0.05 then 
			currentlyProcessing = false
			return 
		end

		local pos = input.Position
		if isPointerOverNode(node, pos.X, pos.Y) then 
			currentlyProcessing = false
			return 
		end
		
		node.Tree:Close(node.Key)
		
		task.defer(function()
			currentlyProcessing = false
		end)
	end)

	return {
		Disconnect = function()
			if changedCon.Connected then changedCon:Disconnect() end
			if clickCon.Connected then clickCon:Disconnect() end
		end,
	}
end

function CloseOnOutside.Detach(_node: Node, handle): ()
	if handle and type(handle) == "table" and type(handle.Disconnect) == "function" then
		handle:Disconnect()
	end
end

return CloseOnOutside
