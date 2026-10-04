-- The practice house (spec §11 "Dummy base"): an NPC house near spawn with a stealable Common on its porch.
-- It teaches the heist risk-free. Each player may keep one practice Chonk per session; the porch refills
-- `Config.DummyBase.respawnSeconds` after its Chonk is taken.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Rolls = require(ReplicatedStorage.Shared.Rolls)
local ShowcaseRules = require(ReplicatedStorage.Shared.ShowcaseRules)
local Strings = require(ReplicatedStorage.Shared.Strings)
local VaultRules = require(ReplicatedStorage.Shared.VaultRules)
local Carry = require(script.Parent.Carry)
local Models = require(script.Parent.Models)
local Notify = require(script.Parent.Notify)
local PlayerState = require(script.Parent.PlayerState)
local Showcase = require(script.Parent.Showcase)

type Item = Carry.Item

local DummyBase = {}

local rng = Random.new()
local house: Model
local pad: BasePart
local frame: CFrame
local current: Item? -- the Chonk on the porch, if any
local respawnAt: number? -- when the porch refills; nil while full or when a returning Chonk was reseated

local toast = Notify.toast

-- One step of the respawn loop, isolated: a single bad item must not stop the practice house for the session.
local reported: { [string]: true } = {} -- each distinct fault is warned about once, not four times a second
local function guarded(what: string, fn: (...any) -> ...any, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		local line = `[DummyBase] {what} failed: {err}`
		if not reported[line] then
			reported[line] = true
			warn(`{line} (reported once)`)
		end
	end
end

local function build(parent: Instance)
	-- Local -Z faces the district centre (the porch side), as on the player plots.
	local origin = Vector3.new(Config.DummyBase.x, 0, Config.DummyBase.z)
	frame = CFrame.lookAt(origin, Vector3.new(0, 0, 0))
	local function at(localPos: Vector3): CFrame
		return frame * CFrame.new(localPos)
	end
	house = Instance.new("Model")
	house.Name = "DummyHouse"
	house.PrimaryPart = Models.part({
		Name = "Floor",
		Size = Vector3.new(16, 1, 14),
		CFrame = at(Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(205, 190, 165),
		Material = Enum.Material.WoodPlanks,
		Parent = house,
	})
	-- Tall enough to clear the largest Chonk the porch can hold: the pad top is 1.3 and a max-size
	-- body is 4 * 2.1 studs, so anything under 10 studs of headroom puts its head through the roof.
	for _, wall in
		{
			{ Vector3.new(0, 5.5, 6.5), Vector3.new(16, 10, 1) },
			{ Vector3.new(-7.5, 5.5, 2.5), Vector3.new(1, 10, 9) },
			{ Vector3.new(7.5, 5.5, 2.5), Vector3.new(1, 10, 9) },
		}
	do
		Models.part({
			Name = "Wall",
			Size = wall[2],
			CFrame = at(wall[1]),
			Color = Color3.fromRGB(170, 190, 230),
			Parent = house,
		})
	end
	Models.part({
		Name = "Roof",
		Size = Vector3.new(18, 1, 11),
		CFrame = at(Vector3.new(0, 11, 2.5)),
		Color = Color3.fromRGB(120, 130, 170),
		Parent = house,
	})
	-- Trim in the cottages' style: corner posts and a fascia round the roof.
	local trim = Color3.fromRGB(255, 250, 242)
	for _, x in { -7.9, 7.9 } do
		for _, z in { -2, 6.9 } do
			Models.part({
				Name = "Post",
				Size = Vector3.new(0.9, 10, 0.9),
				CFrame = at(Vector3.new(x, 5.5, z)),
				Color = trim,
				CanCollide = false,
				CanQuery = false,
				Parent = house,
			})
		end
	end
	Models.part({
		Name = "Fascia",
		Size = Vector3.new(18.6, 0.5, 11.6),
		CFrame = at(Vector3.new(0, 10.4, 2.5)),
		Color = trim,
		CanCollide = false,
		CanQuery = false,
		Parent = house,
	})
	pad = Models.part({
		Name = "DummyPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 6, 6),
		CFrame = at(Vector3.new(0, 1.15, -3.5)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 196, 120),
		Material = Enum.Material.SmoothPlastic,
		Parent = house,
	})

	-- The sign stands on the front edge of the roof, printed on both faces, so it reads from the
	-- plaza and from the houses behind it.
	local sign = Models.part({
		Name = "DummySign",
		Size = Vector3.new(15, 5.4, 0.5),
		CFrame = at(Vector3.new(0, 11.5 + 2.7, -3)),
		Color = Color3.fromRGB(255, 214, 64),
		CanCollide = false,
		CanQuery = false,
		Parent = house,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local panel = Models.signFace(sign, face)
		Models.signText(
			panel,
			"Title",
			string.upper(Strings.Showcase.dummyHouse),
			Color3.fromRGB(255, 214, 64),
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 0.44)
		)
		local body = Models.signText(
			panel,
			"Text",
			Strings.Showcase.dummySign,
			Color3.new(1, 1, 1),
			UDim2.fromScale(0, 0.48),
			UDim2.fromScale(1, 0.52)
		)
		body.TextWrapped = true
	end

	house.Parent = parent
end

-- Puts a practice Chonk on the porch with its Steal prompt (shown to everyone: no Audience). Never yields.
local function seat(item: Item)
	local d = 4 * Formulas.sizeScale(item.roll.size)
	item.model:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 0.15 + d / 2, 0)) * frame.Rotation)
	item.dummy = true
	item.owner = nil
	item.looseAt = nil
	Carry.setStatus(item, "showcase")
	local card = VaultRules.revealCard({ chonkId = item.roll.chonkId, tier = item.roll.tier, size = item.roll.size })
	if not (item.model.PrimaryPart :: BasePart):FindFirstChild("NameTag") then
		Models.nameLabel(item.model, card.displayName, Models.rgb(Config.TierColors[item.roll.tier]), d / 2 + 1.5)
	end
	local steal = Showcase.newStealPrompt(card.displayName, function(player: Player)
		DummyBase.steal(player)
	end)
	steal.Parent = item.model.PrimaryPart
	item.model.Parent = house
	current = item
	respawnAt = nil
end

local function spawnChonk()
	local pool = Catalog.byTier.Common
	local entry = pool[rng:NextInteger(1, #pool)]
	local size = Rolls.pickIndexWeighted(Config.SizeWeights, rng:NextNumber())
	seat(Carry.register({
		kind = "chonk",
		roll = { chonkId = entry.id, tier = "Common", size = size },
		model = Models.chonk(entry, size),
		status = "showcase",
		dummy = true,
	}))
end

function DummyBase.item(): Item?
	return current
end

function DummyBase.pad(): BasePart
	return pad
end

function DummyBase.frame(): CFrame
	return frame
end

-- Steals the practice Chonk. Availability first; the pick-up never yields, so one of two same-frame thieves wins.
function DummyBase.steal(player: Player): (boolean, string?)
	local state = PlayerState.get(player)
	if not state then
		return false, "noState"
	end
	local item = current
	local ok, reason = ShowcaseRules.canSteal({
		available = item ~= nil and item.status == "showcase",
		isOwner = false,
		carrying = state.carrying ~= nil,
		now = os.clock(),
		immuneUntil = 0,
		isDummy = true,
		dummyTaken = state.dummyTaken,
	})
	if not ok then
		toast(player, reason :: string)
		return false, reason
	end
	local taken = item :: Item
	ok, reason = Carry.pickUp(player, taken)
	if not ok then
		toast(player, reason :: string)
		return false, reason
	end
	-- The practice labels stay behind; a porch adds its own name tag, and `seat` restores these on return.
	for _, name in { "StealPrompt", "NameTag" } do
		local child = (taken.model.PrimaryPart :: BasePart):FindFirstChild(name)
		if child then
			child:Destroy()
		end
	end
	current = nil
	respawnAt = os.clock() + Config.DummyBase.respawnSeconds * Config.Debug.timeScale
	Showcase.Stolen:Fire(player, nil, taken)
	return true
end

-- A practice Chonk came back (dropped and left alone, or its carrier left). It goes back on the porch,
-- or is removed if the porch has already refilled.
function DummyBase.reseat(item: Item)
	if current == nil then
		seat(item)
	else
		Carry.forget(item)
	end
end

function DummyBase.start()
	build(workspace:WaitForChild("World"))
	spawnChonk()

	-- A practice Chonk whose carrier leaves goes straight back.
	Carry.Dropped:Connect(function(item: Item, _carrier: Player, reason: string)
		if reason == "left" and item.dummy then
			DummyBase.reseat(item)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now, scale = os.clock(), Config.Debug.timeScale
			-- A dropped practice Chonk left alone walks back to the practice porch.
			for _, item in table.clone(Carry.items()) do
				if
					item.dummy
					and item.status == "loose"
					and item.looseAt
					and now - item.looseAt >= Config.Nest.looseReturnSeconds * scale
				then
					guarded("reseat", DummyBase.reseat, item)
				end
			end
			if current == nil and respawnAt and now >= respawnAt then
				-- Pushed forward first: a build that fails waits a full interval instead of retrying
				-- every tick. `seat` clears it on success.
				respawnAt = now + Config.DummyBase.respawnSeconds * scale
				guarded("respawn", spawnChonk)
			end
		end
	end)
end

return DummyBase
