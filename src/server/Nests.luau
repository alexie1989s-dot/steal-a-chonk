-- Zone 1 nests (spec §7): each holds one blanket burrito and respawns on a timer after it leaves.
-- Burritos are Carry items. A wild burrito (from a nest, never owned) that lies untouched returns to
-- its nest; if the nest has already refilled, the stray burrito is removed (it never belonged to anyone).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rolls = require(ReplicatedStorage.Shared.Rolls)
local Carry = require(script.Parent.Carry)
local Models = require(script.Parent.Models)

type Item = Carry.Item
type NestState = {
	index: number,
	position: Vector3,
	burrito: Item?,
	emptiedAt: number?,
	respawnSeconds: number,
}

local Nests = {}

local nests: { NestState } = {}
local rng = Random.new()
local folder: Folder

-- Guardians and loose returns care only about burritos nobody has owned yet.
local function isWild(item: Item): boolean
	return item.kind == "burrito" and item.nest ~= nil and item.owner == nil
end

local function seat(burrito: Item, nest: NestState)
	Carry.placeOnGround(burrito, nest.position.X, nest.position.Z)
	burrito.model:PivotTo(burrito.model:GetPivot() + Vector3.new(0, 0.6, 0))
	Carry.setStatus(burrito, "ready")
	burrito.looseAt = nil
	nest.burrito = burrito
	nest.emptiedAt = nil
end

local function spawnBurrito(nest: NestState)
	local roll = Rolls.rollBurrito(1, function()
		return rng:NextNumber()
	end)
	local burrito = Carry.register({
		kind = "burrito",
		nest = nest.index,
		roll = roll,
		model = Models.burrito(roll.tier, roll.size),
		status = "ready",
	})
	seat(burrito, nest)
	burrito.model.Parent = folder
end

function Nests.all(): { NestState }
	return nests
end

-- The carrier of the wild burrito that came from nest `index`, if any.
function Nests.carrierFrom(index: number): Player?
	for _, item in Carry.items() do
		if isWild(item) and item.nest == index and item.status == "carried" then
			return item.carrier
		end
	end
	return nil
end

-- The grab path shared by the prompt and DevHooks: the nest's burrito, or its wild one lying loose.
function Nests.grab(player: Player, index: number): (boolean, string?)
	local nest = nests[index]
	if not nest then
		return false, "noNest"
	end
	local target = nest.burrito
	if not target then
		for _, item in Carry.items() do
			if isWild(item) and item.nest == index and item.status ~= "incubating" then
				target = item
				break
			end
		end
	end
	if not target then
		return false, "empty"
	end
	return Carry.pickUp(player, target)
end

function Nests.start(positions: { Vector3 })
	folder = Instance.new("Folder")
	folder.Name = "Burritos"
	folder.Parent = workspace:WaitForChild("World")

	for index, position in positions do
		nests[index] = { index = index, position = position, respawnSeconds = 0 }
		spawnBurrito(nests[index])
	end

	Carry.PickedUp:Connect(function(_player: Player, item: Item)
		local nest = item.nest and nests[item.nest]
		if nest and nest.burrito == item then
			nest.burrito = nil
			nest.emptiedAt = os.clock()
			nest.respawnSeconds = Config.Nest.respawnSeconds[item.roll.tier]
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now, scale = os.clock(), Config.Debug.timeScale
			for _, item in table.clone(Carry.items()) do
				if isWild(item) and item.status == "loose" and item.looseAt then
					if now - item.looseAt >= Config.Nest.looseReturnSeconds * scale then
						local nest = nests[item.nest :: number]
						if nest.burrito == nil and nest.emptiedAt ~= nil then
							seat(item, nest)
						else
							Carry.forget(item)
						end
					end
				end
			end
			for _, nest in nests do
				if nest.burrito == nil and nest.emptiedAt and now - nest.emptiedAt >= nest.respawnSeconds * scale then
					spawnBurrito(nest)
				end
			end
		end
	end)
end

return Nests
