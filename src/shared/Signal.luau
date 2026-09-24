-- Minimal synchronous event. Connect returns a disconnect function.
local Signal = {}
Signal.__index = Signal

type Listener = { fn: (...any) -> (), connected: boolean }

function Signal.new()
	return setmetatable({ _listeners = {} :: { Listener } }, Signal)
end

function Signal:Connect(fn: (...any) -> ()): () -> ()
	local listener = { fn = fn, connected = true }
	table.insert(self._listeners, listener)
	return function()
		listener.connected = false
		local index = table.find(self._listeners, listener)
		if index then
			table.remove(self._listeners, index)
		end
	end
end

function Signal:Fire(...: any)
	-- Iterate a snapshot so listeners may disconnect themselves or others while firing.
	for _, listener in table.clone(self._listeners) do
		if listener.connected then
			listener.fn(...)
		end
	end
end

return Signal
