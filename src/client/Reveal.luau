-- The reveal card (spec §8, §19): full-screen, screenshot-ready, dismissed with one tap.
-- Reveals that arrive while a card is open wait their turn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)

local Reveal = {}

local PANEL = Color3.fromRGB(40, 36, 52)
local STAMP_RED = Color3.fromRGB(235, 60, 60)

local function text(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextWrapped = true
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

function Reveal.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Reveal"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.35
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.8, 0.8)
	card.BackgroundColor3 = PANEL
	card.Active = false
	card.Parent = backdrop
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 0.78
	aspect.Parent = card
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(460, 590)
	sizeLimit.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 24)
	corner.Parent = card
	local scale = Instance.new("UIScale")
	scale.Parent = card

	local band = Instance.new("Frame")
	band.Name = "Band"
	band.Size = UDim2.fromScale(1, 0.14)
	band.BorderSizePixel = 0
	band.Parent = card
	local bandCorner = Instance.new("UICorner")
	bandCorner.CornerRadius = UDim.new(0, 24)
	bandCorner.Parent = band
	local tier = text(band, "Tier", {
		Size = UDim2.fromScale(0.9, 0.7),
		Position = UDim2.fromScale(0.05, 0.15),
		TextColor3 = PANEL,
	})
	local species = text(card, "Species", {
		Size = UDim2.fromScale(0.9, 0.07),
		Position = UDim2.fromScale(0.05, 0.17),
		TextColor3 = Color3.fromRGB(200, 195, 215),
	})
	local name = text(card, "DisplayName", {
		Size = UDim2.fromScale(0.9, 0.2),
		Position = UDim2.fromScale(0.05, 0.25),
	})
	local stamp = text(card, "SizeStamp", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.1),
		Position = UDim2.fromScale(0.5, 0.52),
		TextColor3 = Color3.fromRGB(255, 214, 64),
	})
	local bio = text(card, "Bio", {
		Size = UDim2.fromScale(0.86, 0.2),
		Position = UDim2.fromScale(0.07, 0.6),
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(230, 226, 240),
	})
	local income = text(card, "Income", {
		Size = UDim2.fromScale(0.9, 0.07),
		Position = UDim2.fromScale(0.05, 0.82),
		TextColor3 = Color3.fromRGB(255, 214, 64),
	})
	text(card, "Dismiss", {
		Size = UDim2.fromScale(0.9, 0.05),
		Position = UDim2.fromScale(0.05, 0.92),
		TextColor3 = Color3.fromRGB(170, 165, 190),
		Text = Strings.Reveal.dismiss,
	})

	local queue = {}
	local showing = false
	local shake: RBXScriptConnection?

	local function showNext()
		local payload = table.remove(queue, 1)
		if not payload then
			showing = false
			gui.Enabled = false
			return
		end
		showing = true
		local color = Config.TierColors[payload.tier] or { 255, 255, 255 }
		band.BackgroundColor3 = Color3.fromRGB(color[1], color[2], color[3])
		tier.Text = string.upper(payload.tier)
		species.Text = payload.species
		name.Text = payload.displayName
		stamp.Text = payload.sizeStamp
		bio.Text = payload.bio
		income.Text = string.format(Strings.Reveal.incomeFormat, Format.rate(payload.incomePerSecond))

		if shake then
			shake:Disconnect()
			shake = nil
		end
		stamp.Rotation = 0
		-- The top size prints in red on a shaking card (spec §8).
		if payload.size >= 6 then
			stamp.TextColor3 = STAMP_RED
			shake = RunService.RenderStepped:Connect(function()
				stamp.Rotation = math.sin(os.clock() * 40) * 4
				card.Rotation = math.sin(os.clock() * 31) * 1.2
			end)
		else
			stamp.TextColor3 = Color3.fromRGB(255, 214, 64)
			card.Rotation = 0
		end

		gui.Enabled = true
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	backdrop.Activated:Connect(function()
		if shake then
			shake:Disconnect()
			shake = nil
		end
		card.Rotation = 0
		showNext()
	end)

	Remotes.get("Reveal").OnClientEvent:Connect(function(payload)
		table.insert(queue, payload)
		if not showing then
			showNext()
		end
	end)
end

return Reveal
