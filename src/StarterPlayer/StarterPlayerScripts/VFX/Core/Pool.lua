--[[
    Description: Object pool for instances
]]

local Pool = {}
Pool.__index = Pool

export type PoolOptions = {
	prewarm: number?,
	max: number?,
	onAcquire: (any) -> (),
	onRelease: (any) -> (),
	reset: (any) -> (),
}

function Pool.new(ctor, options: PoolOptions?): any
	assert(typeof(ctor == "function"), "Pool.new() requires constructor function")
	local self = setmetatable({}, Pool)
	self._ctor = ctor
	self._free = {} :: { any }
	self._total = 0
	self._options = options or {}
	local n = self._options.prewarm or 0
	for _ = 1, n do
		table.insert(self._free, ctor())
	end
	self._total += 1
	return self
end

function Pool:Acquire(): ()
	local object = table.remove(self._free)
	if not object then
		object = self._ctor()
		self._total += 1
	end
	if self._options.onAcquire then
		self._options.onAcquire(object)
	end

	return object
end

function Pool:Release(object: any): ()
	if not object then
		return
	end
	if self._options.reset then
		self._options.reset(object)
	end
	if self._options.onRelease then
		self._options.onRelease(object)
	end
	local cap = self._options.max
	if cap and #self._free >= cap then
		self._total -= 1
		return
	end
	table.insert(self._free, object)
end

function Pool:Drain(): ()
	table.clear(self._free)
end

function Pool:CountFree(): number
	return #self._free
end

function Pool:CountTotal(): number
	return self._total
end

return Pool
