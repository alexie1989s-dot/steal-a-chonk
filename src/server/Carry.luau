-- Carrying items home (spec §5, §7, §11). The server decides every pickup, drop and hand-off.
-- Every physical item is registered here, a nest burrito or a Chonk, wherever it is.
-- A dropped item lies where it fell and anyone may pick it up, the dropper included.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShowcaseRules = require(ReplicatedStorage.Shared.ShowcaseRules)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Movement = require(script.Parent.Movement)
local PlayerState = require(script.Parent.PlayerState)

export type Item = {
	id: number,
	kind: "burrito" | "chonk",
	roll: { chonkId: string, tier: string, size: number }, -- chonks: the record's fields
	model: Model,
	status: "ready" | "carried" | "loose" | "incubating" | "showcase",
	carrier: Player?,
	looseAt: number?,
	nest: number?, -- nest burritos only
	owner: Player?, -- last owner; nil for field burritos and the dummy Chonk
	dummy: boolean?, -- the dummy house's Chonk until someone keeps it
	uid: number?, -- chonks: record uid in the owner's sequence
	progress: number?, -- burritos: unwrap fraction already done, 0..1
}
export type Burrito = Item

local Carry = {
	PickedUp = Signal.new(), -- (player, item)
	Dropped = Signal.new(), -- (item, player, reason)
	CrossedHome = Signal.new(), -- (player, item)
}

local CARRY_WELD = "CarryWeld"

local items: { [number]: Item } = {}
local nextId = 1

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end
Carry.rootOf = rootOf

local function toast(player: Player, key: string)
	local text = Strings.Toasts[key]
	if text then
		Remotes.get("Toast"):FireClient(player, text)
	end
end

local function setPhysics(model: Model, anchored: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = anchored
			part.CanCollide = false
			part.Massless = not anchored
		end
	end
end

local function detach(item: Item)
	local body = item.model.PrimaryPart
	local weld = body and body:FindFirstChild(CARRY_WELD)
	if weld then
		weld:Destroy()
	end
	setPhysics(item.model, true)
end

local function grabPrompt(item: Item): ProximityPrompt?
	local body = item.model.PrimaryPart
	return body and body:FindFirstChild("GrabPrompt") :: ProximityPrompt?
end

-- The only way to change an item's status. The GrabPrompt is live only while the item lies free.
function Carry.setStatus(item: Item, status: string)
	item.status = status :: any
	local prompt = grabPrompt(item)
	if prompt then
		prompt.Enabled = status == "ready" or status == "loose"
	end
	-- Only a seated Chonk idles. Anything the server is about to move -- carried, loose, back in
	-- an incubator -- loses the tag first, so the client stops holding it to a remembered pose.
	local idling = status == "showcase" and item.kind == "chonk"
	if idling ~= CollectionService:HasTag(item.model, Config.Tags.chonkIdle) then
		if idling then
			CollectionService:AddTag(item.model, Config.Tags.chonkIdle)
		else
			CollectionService:RemoveTag(item.model, Config.Tags.chonkIdle)
		end
	end
end

-- Assigns an id and adds the GrabPrompt. The caller positions and parents the model.
function Carry.register(fields: { [string]: any }): Item
	local item = fields :: Item
	item.id = nextId
	nextId += 1
	item.model.Name = if item.kind == "burrito" then `Burrito{item.id}` else `ChonkItem{item.id}`
	item.model:SetAttribute("ItemId", item.id)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = Strings.Prompts.grab
	prompt.ObjectText = if item.kind == "burrito" then Strings.Prompts.grabObject else Strings.Prompts.chonkObject
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Nest.grabDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = item.model.PrimaryPart
	prompt.Triggered:Connect(function(player: Player)
		Carry.grab(player, item)
	end)

	items[item.id] = item
	Carry.setStatus(item, item.status)
	return item
end

-- The Grab prompt's path, shared with DevHooks. Porch items leave only through the Steal prompt, so this
-- takes free items only.
function Carry.grab(player: Player, item: Item): (boolean, string?)
	local ok, reason = false, "taken"
	if item.status == "ready" or item.status == "loose" then
		ok, reason = Carry.pickUp(player, item)
	end
	if not ok and reason then
		toast(player, reason)
	end
	return ok, reason
end

-- Removes an item from the registry and destroys its model. A carried item is taken from its carrier first.
function Carry.forget(item: Item)
	if item.carrier then
		local state = PlayerState.get(item.carrier)
		if state and state.carrying == item then
			Carry.take(item.carrier)
		end
	end
	items[item.id] = nil
	item.model:Destroy()
end

function Carry.items(): { [number]: Item }
	return items
end

-- Makes `player` the item's owner after a deposit: a Chonk from someone else gets a uid in the new owner's
-- sequence, and a kept dummy Chonk uses up the player's one practice Chonk.
function Carry.adopt(player: Player, item: Item)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	if item.kind == "chonk" and (item.owner ~= player or not item.uid) then
		item.uid = state.nextUid
		state.nextUid += 1
	end
	if item.dummy then
		item.dummy = nil
		state.dummyTaken = true
	end
	item.owner = player
end

-- Rests an item on the ground at (x, z).
function Carry.placeOnGround(item: Item, x: number, z: number)
	local height = 0.5 + 1.1 * Formulas.sizeScale(item.roll.size)
	item.model:PivotTo(CFrame.new(x, height, z))
end

function Carry.pickUp(player: Player, item: Item): (boolean, string?)
	local state = PlayerState.get(player)
	if not state then
		return false, "noState"
	end
	-- Status first: the check and the claim below never yield, so two simultaneous grabs cannot both win.
	if item.status ~= "ready" and item.status ~= "loose" and item.status ~= "showcase" then
		return false, "taken"
	end
	if state.carrying then
		return false, "alreadyCarrying"
	end
	-- A practice Chonk that could never be deposited would leave the player stuck at carry speed.
	local keep, keepReason = ShowcaseRules.canKeep(item.dummy, state.dummyTaken)
	if not keep then
		return false, keepReason
	end
	local root = rootOf(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid and humanoid.Health > 0) then
		return false, "noCharacter"
	end
	-- Prompts are triggered by the client, so the server re-checks reach (spec §20).
	local at = item.model:GetPivot().Position
	if
		Layout.planarDistance(root.Position.X, root.Position.Z, at.X, at.Z)
		> Config.Nest.grabDistance + Config.AntiCheat.reachTolerance
	then
		return false, "tooFar"
	end

	Carry.setStatus(item, "carried")
	item.carrier = player
	item.looseAt = nil
	state.carrying = item

	local model = item.model
	-- Above the head, higher for big Chonks so they never sit inside the carrier.
	local lift = math.max(3.6, 1.5 + model:GetExtentsSize().Y / 2)
	model:PivotTo(root.CFrame * CFrame.new(0, lift, 0))
	setPhysics(model, false)
	local weld = Instance.new("WeldConstraint")
	weld.Name = CARRY_WELD
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart

	Movement.refresh(player)
	PlayerState.sync(player)
	Carry.PickedUp:Fire(player, item)
	return true
end

-- Drops the carried item at the carrier's feet. Returns it, or nil if nothing was carried.
function Carry.drop(player: Player, reason: string): Item?
	local state = PlayerState.get(player)
	local item = state and state.carrying
	if not (state and item) then
		return nil
	end
	local root = rootOf(player)
	local position = if root then root.Position else item.model:GetPivot().Position
	state.carrying = nil
	detach(item)
	Carry.placeOnGround(item, position.X, position.Z)
	Carry.setStatus(item, "loose")
	item.carrier = nil
	item.looseAt = os.clock()

	Movement.refresh(player)
	PlayerState.sync(player)
	Carry.Dropped:Fire(item, player, reason)
	return item
end

-- Removes the carried item from the player without dropping it (the Vault or the porch takes it).
function Carry.take(player: Player): Item?
	local state = PlayerState.get(player)
	local item = state and state.carrying
	if not (state and item) then
		return nil
	end
	state.carrying = nil
	detach(item)
	item.carrier = nil
	Movement.refresh(player)
	PlayerState.sync(player)
	return item
end

function Carry.inField(player: Player): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	return not Layout.isInBase(root.Position.X, root.Position.Z)
end

-- Tells a client to fly back from `from` (spec §7: "knocked back").
function Carry.knockback(player: Player, from: Vector3)
	local root = rootOf(player)
	if not root then
		return
	end
	local away = root.Position - from
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 1e-3 then
		away = Vector3.new(1, 0, 0)
	end
	away = away.Unit
	Remotes.get("Knockback"):FireClient(player, away.X, away.Z)
end

function Carry.start()
	PlayerState.Added:Connect(function(player: Player)
		local function watch(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					Carry.drop(player, "died")
				end)
			end
		end
		player.CharacterAdded:Connect(watch)
		if player.Character then
			task.spawn(watch, player.Character)
		end
	end)
	PlayerState.Removing:Connect(function(player: Player)
		Carry.drop(player, "left")
	end)

	-- Curb crossing: the finish line of every heist (spec §6).
	task.spawn(function()
		while true do
			task.wait(Config.Carry.crossingCheckSeconds)
			for player, state in PlayerState.all() do
				local root = rootOf(player)
				if root then
					local inBase = Layout.isInBase(root.Position.X, root.Position.Z)
					if inBase ~= state.inBase then
						state.inBase = inBase
						PlayerState.sync(player)
						if inBase and state.carrying then
							Carry.CrossedHome:Fire(player, state.carrying)
							Remotes.get("Celebrate"):FireClient(player)
							Remotes.get("Toast"):FireClient(player, Strings.Toasts.madeItHome)
						end
					end
				end
			end
		end
	end)
end

return Carry
