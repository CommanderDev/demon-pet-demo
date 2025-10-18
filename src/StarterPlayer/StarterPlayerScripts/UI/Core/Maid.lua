--!strict

--[[
    Description: A tiny cleanup helper
]]

local Maid = {}
Maid.__index = Maid

export type Maid = {
    __index: Maid,
    _tasks: {[any]: true},

    GiveTask: (self: Maid, task: any) -> (),
    Remove: (self: Maid, task: any) -> (),
    TieToInstance: (self: Maid, inst: Instance) -> (),
    DoCleaning: (self: Maid) -> (),
    Destroy: (self: Maid) -> (),
}

local function _cleanup(task: any): ()
    local t = typeof(task)
    if t == "RBXScriptConnection" then 
        if task.Connected then task:Disconnect() end
    elseif t == "Instance" then
        if task.Destroy then task:Destroy() end
    elseif t == "function" then 
        task()
    elseif type(task) == "table" then
        if typeof(task) == "table" then 
            if type(task.Disconnect) == "function" then task:Disconnect() return end
            if type(task.Destroy) == "function" then task:Destroy() return end
            if type(task.DoCleaning) == "function" then task:DoCleaning() return end
        end
    end
end

function Maid.new(): Maid
    return setmetatable({_tasks = {}}, Maid)
end

function Maid:GiveTask(task: any): any
	if task == nil then return nil end
	self._tasks[task] = true
	return task
end

function Maid:Remove(task: any)
	if task and self._tasks[task] then
		self._tasks[task] = nil
		_cleanup(task)
	end
end

-- Cleans when the instance is destroyed or removed from the game.
function Maid:TieToInstance(inst: Instance)
	if not inst then return end
	-- Prefer Destroying (fires exactly once). Fallback to AncestryChanged for older contexts.
	local con
	if inst.Destroying then
		con = inst.Destroying:Connect(function() self:DoCleaning() end)
	else
		con = inst.AncestryChanged:Connect(function(_, parent)
			if parent == nil then self:DoCleaning() end
		end)
	end
	self:GiveTask(con)
end

function Maid:DoCleaning()
	-- clean deterministically
	for task, _ in pairs(self._tasks) do
		self._tasks[task] = nil
		_cleanup(task)
	end
end

function Maid:Destroy()
	self:DoCleaning()
	setmetatable(self, nil) -- help catch accidental reuse
end

return Maid