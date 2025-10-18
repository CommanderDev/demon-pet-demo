-- CallbackQueue
-- Author(s): Jesse Appleton
-- Date: 02/22/2022

--[[
    Creates a queue of callbacks that execute in the sequence they were added.
    Waits until the callback has completed or the timeout has been reached to move on to the next one.

    FUNCTION    CallbackQueue.new( processTimeout: number? = 60 ) -> {}
    FUNCTION    CallbackQueue:Add( fn: ()->(), ...: any ) -> ( Promise )
    FUNCTION    CallbackQueue:AddAsync( fn: ()->(), ...: any ) -> ( ...any )
]]

---------------------------------------------------------------------

-- Constants
local DEFAULT_TIMEOUT = 60 -- How long can a process in the queue take before it times out, by default?

-- Knit
local Janitor = require(script.Parent.Janitor)
local Promise = require(script.Parent.Promise)
local t = require(script.Parent.t)

-- Modules

-- Roblox Services
local RunService = game:GetService("RunService")

-- Variables

---------------------------------------------------------------------

local CallbackQueue = {}
CallbackQueue.__index = CallbackQueue

local tNew = t.tuple(t.optional(t.numberPositive))
function CallbackQueue.new(processTimeout: number?): table
	assert(tNew(processTimeout))

	processTimeout = processTimeout or DEFAULT_TIMEOUT

	local self = setmetatable({}, CallbackQueue)
	self._janitor = Janitor.new()

	self._queue = {}

	local processingPromise: {}?
	local function ProcessNext(): ()
		if processingPromise ~= nil then
			return
		end
		local nextCallback: () -> ()? = self._queue[1]
		if nextCallback then
			processingPromise = Promise.new(function(resolve)
				resolve(nextCallback.Callback(table.unpack(nextCallback.Args)))
			end)
				:timeout(processTimeout)
				:catch(warn)
				:andThen(function(...)
					nextCallback.ResolvePromise(...)
				end)
				:finally(function()
					table.remove(self._queue, 1)
					task.defer(function()
						processingPromise = nil
					end)
				end)
		end
	end

	task.spawn(function()
		while (not self._destroyed) and (task.wait()) do
			ProcessNext()
		end
	end)

	return self
end

local tAdd = t.tuple(t.callback)
function CallbackQueue:Add(callback: () -> (), ...: any): Promise
	assert(tAdd(callback))
	assert(not self._destroyed, "Attempted to add to a destroyed CallbackQueue!")

	-- This is super ugly, but I am unsure if there is a better way to do this?
	local resolvePromise: () -> ()
	local finishPromise = Promise.new(function(resolve)
		resolvePromise = resolve
	end):catch(warn)

	table.insert(self._queue, {
		Callback = callback,
		Args = { ... },
		ResolvePromise = resolvePromise,
	})

	return finishPromise
end

function CallbackQueue:AddAsync(callback: () -> (), ...: any): ...any
	local finishPromise: {} = self:Add(callback, ...)

	local result: {} = {
		finishPromise:await(),
	}
	table.remove(result, 1)

	return table.unpack(result)
end

function CallbackQueue:Destroy(): ()
	self._destroyed = true
	self._janitor:Destroy()
end

return CallbackQueue
