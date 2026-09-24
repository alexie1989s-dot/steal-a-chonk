-- One Patroller Mama Chonk per nest (spec §7). Decisions come from the pure GuardianBrain; this
-- module feeds it the carrier's position, renders the rolling model and applies catches.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GuardianBrain = require(ReplicatedStorage.Shared.GuardianBrain)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Carry = require(script.Parent.Carry)
local Models = require(script.Parent.Models)
local Nests = require(script.Parent.Nests)

type Guardian = {
	index: number,
	brain: GuardianBrain.Brain,
	model: Model,
	body: BasePart,
	rollers: { BasePart },
	deco: { BasePart },
	roll: CFrame,
	wakeGui: BillboardGui,
}

local Guardians = {}

local guardians: { Guardian } = {}

function Guardians.all(): { Guardian }
	return guardians
end

local function wakeBubble(body: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Mrrp"
	gui.Size = UDim2.fromOffset(160, 60)
	gui.StudsOffset = Vector3.new(0, Config.Guardian.radius + 2.5, 0)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 120, 100)
	label.TextStrokeTransparency = 0.2
	label.Text = Strings.Guardian.wake
	label.Parent = gui
	return gui
end

local function render(guardian: Guardian)
	local brain = guardian.brain
	local radius = Config.Guardian.radius
	local position = Vector3.new(brain.x, radius, brain.z)
	local frame = CFrame.lookAt(position, position + Vector3.new(brain.headingX, 0, brain.headingZ))
	if brain.moved > 0 then
		-- Roll forward: distance travelled over radius, about the axis across the direction of travel.
		guardian.roll = CFrame.fromAxisAngle(frame.RightVector, -brain.moved / radius) * guardian.roll
	end
	local rolled = CFrame.new(position) * guardian.roll
	for _, part in guardian.rollers do
		part.CFrame = rolled
	end
	for _, part in guardian.deco do
		part.CFrame = frame * (part:GetAttribute("Offset") :: CFrame)
	end
	guardian.wakeGui.Enabled = brain.mode == "waking"
end

local function tick(dt: number)
	dt = math.min(dt, 0.1)
	local zoneSpeed = Config.Zones[1].guardianSpeed
	for _, guardian in guardians do
		local carrier = Nests.carrierFrom(guardian.index)
		local root = carrier and Carry.rootOf(carrier)
		local input = {
			carrierX = root and root.Position.X,
			carrierZ = root and root.Position.Z,
			carrierInField = carrier ~= nil and root ~= nil and Carry.inField(carrier),
			dt = dt,
			zoneSpeed = zoneSpeed,
		}
		local event = GuardianBrain.step(guardian.brain, input)
		if event == "caught" and carrier then
			Carry.drop(carrier, "caught")
			Carry.knockback(carrier, Vector3.new(guardian.brain.x, 0, guardian.brain.z))
			Remotes.get("Toast"):FireClient(carrier, Strings.Toasts.caught)
		end
		render(guardian)
	end
end

function Guardians.start(nestPositions: { Vector3 })
	local folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = workspace:WaitForChild("World")

	for index, nest in nestPositions do
		local model = Models.mama()
		model.Name = `MamaChonk{index}`
		local body = model.PrimaryPart :: BasePart
		local rollers, deco = {}, {}
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") then
				if part:GetAttribute("Offset") ~= nil then
					table.insert(deco, part)
				elseif part == body or part:GetAttribute("Rolls") then
					table.insert(rollers, part)
				end
			end
		end
		local guardian: Guardian = {
			index = index,
			brain = GuardianBrain.new(nest.X, nest.Z, index * 1.7),
			model = model,
			body = body,
			rollers = rollers,
			deco = deco,
			roll = CFrame.identity,
			wakeGui = wakeBubble(body),
		}
		render(guardian)
		model.Parent = folder
		table.insert(guardians, guardian)
	end

	RunService.Heartbeat:Connect(tick)
end

return Guardians
