-- The starter bat (spec §11, §13): knocks a burrito out of a carrier's hands in the field.
-- The client only says "I swung"; the server picks the target from its own positions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BatRules = require(ReplicatedStorage.Shared.BatRules)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Carry = require(script.Parent.Carry)
local Models = require(script.Parent.Models)
local PlayerState = require(script.Parent.PlayerState)

local Bat = {
	swingsProcessed = 0,
}

local lastSwing: { [Player]: number } = {}

local function bonk(at: Vector3)
	local anchor = Models.part({
		Name = "Bonk",
		Size = Vector3.one,
		Position = at + Vector3.new(0, 4, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = workspace,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 60)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 214, 64)
	label.TextStrokeTransparency = 0.2
	label.Text = Strings.Bat.bonk
	label.Parent = gui
	task.delay(1, function()
		anchor:Destroy()
	end)
end

-- Returns the player that was hit, if any. Swings inside the cooldown are ignored entirely.
function Bat.swing(player: Player): Player?
	local now = os.clock()
	if now - (lastSwing[player] or -math.huge) < Config.Bat.cooldownSeconds then
		return nil
	end
	lastSwing[player] = now
	Bat.swingsProcessed += 1

	local state = PlayerState.get(player)
	local root = Carry.rootOf(player)
	if not (state and root) then
		return nil
	end
	local candidates, byId = {}, {}
	for other, otherState in PlayerState.all() do
		local otherRoot = other ~= player and Carry.rootOf(other)
		if otherRoot then
			table.insert(candidates, {
				id = other.UserId,
				x = otherRoot.Position.X,
				z = otherRoot.Position.Z,
				carrying = otherState.carrying ~= nil,
				inField = Carry.inField(other),
			})
			byId[other.UserId] = other
		end
	end
	local look = root.CFrame.LookVector
	local targetId = BatRules.pickTarget({
		x = root.Position.X,
		z = root.Position.Z,
		lookX = look.X,
		lookZ = look.Z,
		carrying = state.carrying ~= nil,
	}, candidates)
	local target = targetId and byId[targetId]
	if not target then
		return nil
	end
	local targetRoot = Carry.rootOf(target)
	Carry.drop(target, "batted")
	Carry.knockback(target, root.Position)
	if targetRoot then
		bonk(targetRoot.Position)
	end
	local toast = Remotes.get("Toast")
	toast:FireClient(target, Strings.Toasts.batted)
	toast:FireClient(player, Strings.Toasts.youBatted)
	return target
end

function Bat.start()
	Remotes.get("BatSwing").OnServerEvent:Connect(function(player: Player)
		Bat.swing(player)
	end)
	PlayerState.Removing:Connect(function(player: Player)
		lastSwing[player] = nil
	end)
end

return Bat
