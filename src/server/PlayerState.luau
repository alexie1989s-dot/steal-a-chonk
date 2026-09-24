-- Per-player session state. Server-only truth; clients see it through Player attributes.
-- Session-only in the vertical slice: nothing persists after leaving (the Data service is Alpha work).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

export type ChonkRecord = { uid: number, chonkId: string, tier: string, size: number }
export type State = {
	cash: number,
	zoomies: number,
	plot: number?,
	carrying: any?, -- Burrito (owned by Nests/Carry)
	inBase: boolean,
	vault: { ChonkRecord },
	incubators: { [number]: any }, -- slot -> incubation record (Vault)
	nextUid: number,
}

local PlayerState = {
	Added = Signal.new(),
	Removing = Signal.new(),
}

local states: { [Player]: State } = {}

function PlayerState.get(player: Player): State?
	return states[player]
end

function PlayerState.all(): { [Player]: State }
	return states
end

-- Mirrors the numbers clients may display into attributes.
function PlayerState.sync(player: Player)
	local state = states[player]
	if not state then
		return
	end
	player:SetAttribute("Cash", math.floor(state.cash))
	player:SetAttribute("Zoomies", math.floor(state.zoomies))
	player:SetAttribute("CarryTier", if state.carrying then state.carrying.roll.tier else nil)
	player:SetAttribute("InBase", state.inBase)
	player:SetAttribute("Plot", state.plot)
end

local function add(player: Player)
	if states[player] then
		return
	end
	states[player] = {
		cash = 0,
		zoomies = 0,
		plot = nil,
		carrying = nil,
		inBase = true,
		vault = {},
		incubators = {},
		nextUid = 1,
	}
	PlayerState.Added:Fire(player)
	PlayerState.sync(player)
end

-- Call after other services have connected to Added, so existing players are announced to them.
function PlayerState.start()
	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(function(player)
		if states[player] then
			PlayerState.Removing:Fire(player)
			states[player] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		add(player)
	end
end

return PlayerState
