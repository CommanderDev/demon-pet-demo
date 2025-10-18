--!strict

local Tx = {}
Tx.__index = Tx

export type Transactions = {
    Begin: (self: Transactions) -> (),
    Commit: (self: Transactions) -> (),
    Rollback: (self: Transactions) -> (),
    InTransaction: (self: Transactions) -> boolean,
    Enqueue: (self: Transactions, fn: () -> ()) -> (),
}

function Tx.new(): Transactions
    local self = setmetatable({
        _depth = 0,
        _queue = {} :: {() -> ()}
    }, Tx)
    return (self :: any) :: Transactions
end

function Tx:Begin(): ()
    self._depth += 1
end

function Tx:Commit()
	if self._depth == 0 then return end
	self._depth -= 1
	if self._depth == 0 then
		local q = self._queue
		self._queue = {}
		for i = 1, #q do
			local fn = q[i]
			local ok, err = pcall(fn)
			if not ok then warn("[UI][Tx] queued op error:", err) end
		end
	end
end

function Tx:Rollback()
	self._queue = {}
	self._depth = 0
end

function Tx:InTransaction(): boolean
	return self._depth > 0
end

function Tx:Enqueue(fn: () -> ())
	if self:InTransaction() then
		table.insert(self._queue, fn)
	else
		local ok, err = pcall(fn)
		if not ok then warn("[UI][Tx] op error:", err) end
	end
end

return Tx