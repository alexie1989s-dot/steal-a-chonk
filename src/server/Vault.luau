-- The Vault (spec §10): two incubators unwrap burritos into Chonks that earn cash forever.
-- Safe: nothing here can be stolen. Session-only in the vertical slice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local VaultRules = require(ReplicatedStorage.Shared.VaultRules)
local Carry = require(script.Parent.Carry)
local Models = require(script.Parent.Models)
local Nests = require(script.Parent.Nests)
local PlayerState = require(script.Parent.PlayerState)
local Plots = require(script.Parent.Plots)

type Incubation = {
	burrito: Carry.Burrito,
	startedAt: number,
	duration: number,
	label: TextLabel,
}

local Vault = {}

-- Display models by player, in vault order.
local displays: { [Player]: { Model } } = {}

local function toast(player: Player, key: string)
	local text = Strings.Toasts[key]
	if text then
		Remotes.get("Toast"):FireClient(player, text)
	end
end

local function progressLabel(parent: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Unwrap"
	gui.Size = UDim2.fromOffset(140, 36)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(40, 36, 52)
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	return label
end

local function placeDisplay(player: Player, record: PlayerState.ChonkRecord, slot: number)
	local state = PlayerState.get(player)
	if not (state and state.plot) then
		return
	end
	local pad = Plots.part(state.plot, `Display{slot}`)
	local entry = Catalog.byId[record.chonkId]
	local model = Models.chonk(entry, record.size)
	model.Name = `Chonk{record.uid}`
	local d = 4 * Formulas.sizeScale(record.size)
	local facing = Plots.frame(state.plot).Rotation
	model:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 0.15 + d / 2, 0)) * facing)

	local card = VaultRules.revealCard(record)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, d / 2 + 1.5, 0)
	gui.MaxDistance = 80
	gui.Parent = model.PrimaryPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Models.rgb(Config.TierColors[record.tier])
	label.TextStrokeTransparency = 0.3
	label.Text = `{card.displayName}\n{string.format(Strings.Reveal.incomeFormat, Format.rate(card.incomePerSecond))}`
	label.Parent = gui

	model.Parent = Plots.model(state.plot)
	displays[player] = displays[player] or {}
	displays[player][slot] = model
end

local function reveal(player: Player, slot: number, incubation: Incubation)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	local roll = incubation.burrito.roll
	local record = { uid = state.nextUid, chonkId = roll.chonkId, tier = roll.tier, size = roll.size }
	state.nextUid += 1
	table.insert(state.vault, record)
	state.incubators[slot] = nil
	incubation.label.Parent:Destroy()
	Nests.consume(incubation.burrito)
	placeDisplay(player, record, #state.vault)
	PlayerState.sync(player)
	Remotes.get("Reveal"):FireClient(player, VaultRules.revealCard(record))
end

-- Deposit path shared by the incubator prompts and DevHooks. `plotIndex` is where the player stands.
function Vault.deposit(player: Player, plotIndex: number): (boolean, string?)
	local state = PlayerState.get(player)
	if not state then
		return false, "noState"
	end
	-- Prompts are triggered by the client, so the server re-checks that an incubator is in reach (spec §20).
	local root = Carry.rootOf(player)
	local reach = Config.Vault.promptDistance + Config.AntiCheat.reachTolerance
	local inReach = false
	for slot = 1, Config.Vault.incubators do
		local pad = Plots.part(plotIndex, `Incubator{slot}`)
		if root and pad and (root.Position - pad.Position).Magnitude <= reach then
			inReach = true
		end
	end
	if not inReach then
		return false, "tooFar"
	end
	local ok, result = VaultRules.canDeposit({
		carrying = state.carrying ~= nil,
		atOwnIncubator = state.plot ~= nil and state.plot == plotIndex,
		incubators = state.incubators,
		vaultCount = #state.vault,
	})
	if not ok then
		toast(player, result)
		return false, result
	end
	local slot = result :: number
	local burrito = Carry.take(player)
	if not burrito then
		return false, "notCarrying"
	end
	burrito.status = "incubating"
	local pad = Plots.part(plotIndex, `Incubator{slot}`)
	burrito.model:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 2.2, 0)))
	state.incubators[slot] = {
		burrito = burrito,
		startedAt = os.clock(),
		duration = Formulas.unwrapSeconds(burrito.roll.tier, burrito.roll.size),
		label = progressLabel(pad),
	}
	toast(player, "unwrapping")
	return true
end

function Vault.fill(player: Player)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	-- Leave room for burritos already incubating: they each need a display pad when they hatch.
	local incubating = 0
	for _ in state.incubators do
		incubating += 1
	end
	while #state.vault + incubating < Config.Vault.displaySlots do
		local record = { uid = state.nextUid, chonkId = "cat_beans", tier = "Common", size = 1 }
		state.nextUid += 1
		table.insert(state.vault, record)
		placeDisplay(player, record, #state.vault)
	end
	PlayerState.sync(player)
end

function Vault.start()
	for plotIndex = 1, Plots.count() do
		for slot = 1, Config.Vault.incubators do
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "UnwrapPrompt"
			prompt.ActionText = Strings.Prompts.unwrap
			prompt.ObjectText = Strings.Prompts.incubatorObject
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = Config.Vault.promptDistance
			prompt.RequiresLineOfSight = false
			prompt.Parent = Plots.part(plotIndex, `Incubator{slot}`)
			prompt.Triggered:Connect(function(player: Player)
				Vault.deposit(player, plotIndex)
			end)
		end
	end

	PlayerState.Removing:Connect(function(player: Player)
		local state = PlayerState.get(player)
		if state then
			for _, incubation: Incubation in state.incubators do
				incubation.label.Parent:Destroy()
				Nests.consume(incubation.burrito)
			end
		end
		for _, model in displays[player] or {} do
			model:Destroy()
		end
		displays[player] = nil
	end)

	-- Unwrap timers and progress labels.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now, scale = os.clock(), Config.Debug.timeScale
			for player, state in PlayerState.all() do
				for slot, incubation: Incubation in table.clone(state.incubators) do
					local remaining = incubation.duration * scale - (now - incubation.startedAt)
					if remaining <= 0 then
						-- Own thread: an error in one reveal must not stop every other incubator.
						state.incubators[slot] = nil
						task.spawn(reveal, player, slot, incubation)
					else
						incubation.label.Text = `{math.ceil(remaining)}s`
					end
				end
			end
		end
	end)

	-- Income: every Vault Chonk earns every second (spec §5 step 6).
	task.spawn(function()
		local period = Config.Economy.incomeTickSeconds
		while true do
			task.wait(period)
			for player, state in PlayerState.all() do
				if #state.vault > 0 then
					state.cash += VaultRules.incomePerSecond(state.vault) * period
					PlayerState.sync(player)
				end
			end
		end
	end)
end

return Vault
