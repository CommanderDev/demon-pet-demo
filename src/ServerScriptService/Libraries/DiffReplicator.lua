--[[
    Name: DiffReplicator
    Author: Jesse Appleton
    Date: 2025/09/22
    
    Only replicates data on change. This is a networking optimization module    
]]

export type Options = {
	id: string,
	send: (payload: { any }) -> (),
	pickKeys: { [string]: boolean }?, -- Whitelist keys that fire replication
	ignoreKeys: { [string]: boolean }?, -- Blacklist keys so these won't trigger replication
	numericBucket: { [string]: number }?, -- key -> bucket size (e.g. progress=1.0),
	numericEpsilon: { [string]: number }?, -- key -> epsilon (e.g. rateScale=0.05)
	customCompare: { [string]: (a: any, b: any) -> boolean }?, -- key -> returns true if equal
	transform: ((input: { any }) -> table)?, -- pre-send projector to reshape the table before diff
	deep: boolean?, -- deep compare(default true)
	throttleSeconds: number?, -- min seconds between sends(default 0)
}

local DiffReplicator = {}
DiffReplicator.__index = DiffReplicator

local function deepCopy(t): { any }
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for key, value in pairs(t) do
		out[deepCopy(key)] = deepCopy(value)
	end
	return out
end

local function bucketize(value: number, bucket: number): number
	if bucket <= 0 then
		return value
	end
	local q = value / bucket
	return (q >= 0) and math.floor(q) or math.ceil(q)
end

local function approxEqual(a, b, eps): boolean
	if a == b then
		return true
	end
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) <= (eps or 0)
	end
	return false
end

local function shallowCopyPicked(src, pick, ignore): { any }
	if not pick and not ignore then
		return src
	end
	local out = {}
	for key, value in pairs(src) do
		if (not pick or pick[key]) and (not ignore or not ignore[key]) then
			out[key] = value
		end
	end
	return out
end

local function normalizeNumberByRules(tbl: { any }, numericBucket: { any }, numericEpsilon: { any }): { any }
	if (not numericBucket) and not numericEpsilon then
		return tbl
	end
	local out = {}
	for key, value in pairs(tbl) do
		local t = type(value)
		if t == "number" then
			if numericBucket and numericBucket[key] then
				out[key] = bucketize(value, numericBucket[key])
			else
				out[key] = value
			end
		elseif t == "table" then
			out[key] = normalizeNumberByRules(value, numericBucket, numericEpsilon)
		else
			out[key] = value
		end
	end
	return out
end

local function deepEqual(a, b, opts, customCompare)
	if a == b then
		return true
	end
	local ta, tb = type(a), type(b)
	if ta ~= tb then
		return false
	end
	if ta ~= "table" or opts.deep == false then
		return a == b
	end

	-- compare keys in a
	for key, aValue in pairs(a) do
		local bValue = b[key]
		if customCompare and customCompare[key] then
			if not customCompare[key](aValue, bValue) then
				return false
			end
		else
			-- epsilon compare for numbers
			if type(aValue) == "number" and type(bValue) == "number" then
				local eps = (opts.numericEpsilon and opts.numericEpsilon[key]) or 0
				if not approxEqual(aValue, bValue, eps) then
					return false
				end
			else
				if not deepEqual(aValue, bValue, opts, customCompare) then
					return false
				end
			end
		end
	end

	-- keys in b not in a?
	for key, _ in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function DiffReplicator.new(options: Options)
	assert(type(options) == "table" and options.send, "DiffReplicator: options.send is required")
	local self = setmetatable({}, DiffReplicator)
	self.id = options.id
	self.sendFn = options.send
	self.pick = options.pickKeys
	self.ignore = options.ignoreKeys
	self.numericBucket = options.numericBucket
	self.numericEpsilon = options.numericEpsilon
	self.customCompare = options.customCompare
	self.transform = options.transform
	self.deep = (options.deep ~= false)
	self.throttle = options.throttleSeconds or 0
	self._lastSent = nil
	self._lastSentTime = 0
	return self
end

-- Consider sending a new state table. This should only send when effective change is detecte
function DiffReplicator:consider(nextTable: { any })
	local now = os.clock()

	local projected = nextTable
	if self.transform then
		projected = self.transform(projected)
	end

	projected = shallowCopyPicked(projected, self.pick, self.ignore)
	projected = normalizeNumberByRules(projected, self.numericBucket, self.numericEpsilon)

	if self._lastSent and self.throttle > 0 and (now - self._lastSentTime) < self.throttle then
		-- Only bypass throttle if there's a different state in the data
		if not deepEqual(projected, self._lastSent, self, self.customCompare) then
			-- Send on any meaningful change. Comment this out to hard-throttle
			self.sendFn(projected)
			self._lastSent = deepCopy(projected)
			self._lastSentTime = now
		end
		return
	end

	if not self._lastSent or not deepEqual(projected, self._lastSent, self, self.customCompare) then
		self.sendFn(projected)
		self._lastSent = deepCopy(projected)
		self._lastSentTime = now
	end

	return true
end

function DiffReplicator:force(nextTable: { any }): ()
	local now = os.clock()
	local payload = nextTable
	if self.transform then
		payload = self.transform(payload)
	end

	payload = shallowCopyPicked(payload, self.pick, self.ignore)
	payload = normalizeNumberByRules(payload, self.numericBucket, self.numericEpsilon)

	self.sendFn(payload)
	self._lastSent = deepCopy(payload)
	self._lastSentTime = now
end

function DiffReplicator:reset(): ()
	self._lastSent = nil
	self._lastSentTime = 0
end

return DiffReplicator
