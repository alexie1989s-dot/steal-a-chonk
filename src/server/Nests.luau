-- Zone 1 nests (spec §7): each holds one blanket burrito and respawns on a timer after it leaves.
-- An untouched dropped burrito returns to its nest; if the nest has already refilled, the stray
-- burrito is removed (it never belonged to anyone).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rolls = require(ReplicatedStorage.Shared.Rolls)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Carry = require(script.Parent.Carry)
local Models = require(script.Parent.Models)

type Burrito = Carry.Burrito
type NestState = {
	index: number,
	position: Vector3,
	burrito: Burrito?,
	emptiedAt: number?,
	respawnSeconds: number,
}

local Nests = {}

local nests: { NestState } = {}
local burritos: { [number]: Burrito } = {}
local nextId = 1
local rng = Random.new()
local folder: Folder

local function promptOf(burrito: Burrito): ProximityPrompt?
	local body = burrito.model.PrimaryPart
	return body and body:FindFirstChild("GrabPrompt") :: ProximityPrompt?
end

local function seat(burrito: Burrito, nest: NestState)
	Carry.placeOnGround(burrito, nest.position.X, nest.position.Z)
	burrito.model:PivotTo(burrito.model:GetPivot() + Vector3.new(0, 0.6, 0))
	burrito.status = "ready"
	burrito.looseAt = nil
	nest.burrito = burrito
	nest.emptiedAt = nil
end

local function spawnBurrito(nest: NestState)
	local roll = Rolls.rollBurrito(1, function()
		return rng:NextNumber()
	end)
	local model = Models.burrito(roll.tier, roll.size)
	local burrito: Burrito = {
		id = nextId,
		nest = nest.index,
		roll = roll,
		model = model,
		status = "ready",
	}
	nextId += 1
	model.Name = `Burrito{burrito.id}`
	model:SetAttribute("BurritoId", burrito.id)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = Strings.Prompts.grab
	prompt.ObjectText = Strings.Prompts.grabObject
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Nest.grabDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player: Player)
		local ok, reason = Carry.pickUp(player, burrito)
		if not ok and reason and Strings.Toasts[reason] then
			Remotes.get("Toast"):FireClient(player, Strings.Toasts[reason])
		end
	end)

	burritos[burrito.id] = burrito
	seat(burrito, nest)
	model.Parent = folder
end

local function remove(burrito: Burrito)
	burritos[burrito.id] = nil
	burrito.model:Destroy()
end

-- The Vault calls this when a burrito becomes a Chonk.
function Nests.consume(burrito: Burrito)
	remove(burrito)
end

function Nests.all(): { NestState }
	return nests
end

function Nests.burritos(): { [number]: Burrito }
	return burritos
end

-- The carrier of the burrito that came from nest `index`, if any.
function Nests.carrierFrom(index: number): Player?
	for _, burrito in burritos do
		if burrito.nest == index and burrito.status == "carried" then
			return burrito.carrier
		end
	end
	return nil
end

-- The grab path shared by the prompt and DevHooks: the nest's burrito, or its loose one.
function Nests.grab(player: Player, index: number): (boolean, string?)
	local nest = nests[index]
	if not nest then
		return false, "noNest"
	end
	local target = nest.burrito
	if not target then
		for _, burrito in burritos do
			if burrito.nest == index and burrito.status ~= "incubating" then
				target = burrito
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

	Carry.PickedUp:Connect(function(_player: Player, burrito: Burrito)
		local prompt = promptOf(burrito)
		if prompt then
			prompt.Enabled = false
		end
		local nest = nests[burrito.nest]
		if nest.burrito == burrito then
			nest.burrito = nil
			nest.emptiedAt = os.clock()
			nest.respawnSeconds = Config.Nest.respawnSeconds[burrito.roll.tier]
		end
	end)

	Carry.Dropped:Connect(function(burrito: Burrito)
		local prompt = promptOf(burrito)
		if prompt then
			prompt.Enabled = true
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now, scale = os.clock(), Config.Debug.timeScale
			for _, burrito in table.clone(burritos) do
				if burrito.status == "loose" and burrito.looseAt then
					if now - burrito.looseAt >= Config.Nest.looseReturnSeconds * scale then
						local nest = nests[burrito.nest]
						if nest.burrito == nil and nest.emptiedAt ~= nil then
							seat(burrito, nest)
						else
							remove(burrito)
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
