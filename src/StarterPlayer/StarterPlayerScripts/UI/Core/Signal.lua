local CreateSignal = require(game.ReplicatedStorage.Libraries.SignalPlus)

local Signal = {}

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

function Signal.new<Parameters...>(): any
	return CreateSignal() :: any
end

return Signal
