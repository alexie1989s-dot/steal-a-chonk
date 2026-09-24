-- Minimal HUD (spec §19): cash, Zoomies and speed readouts plus a toast line.
-- Reads server-written Player attributes; sends nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)

local Hud = {}

local ACCENT = Color3.fromRGB(255, 214, 64)
local PANEL = Color3.fromRGB(40, 36, 52)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, name: string, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.Size = UDim2.fromOffset(170, 40)
	l.BackgroundColor3 = PANEL
	l.BackgroundTransparency = 0.15
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = parent
	corner(l, 12)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = l
	return l
end

function Hud.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local bar = Instance.new("Frame")
	bar.Name = "Stats"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.Size = UDim2.fromOffset(540, 40)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local cash = label(bar, "Cash", 1)
	cash.TextColor3 = ACCENT
	local zoomies = label(bar, "Zoomies", 2)
	local speed = label(bar, "Speed", 3)

	local function refresh()
		cash.Text = `{Strings.Hud.cash} {Format.number(player:GetAttribute("Cash") or 0)}`
		zoomies.Text = `{Strings.Hud.zoomies} {Format.number(player:GetAttribute("Zoomies") or 0)}`
	end
	player:GetAttributeChangedSignal("Cash"):Connect(refresh)
	player:GetAttributeChangedSignal("Zoomies"):Connect(refresh)
	refresh()

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		speed.Text = `{Strings.Hud.speed} {humanoid and math.floor(humanoid.WalkSpeed + 0.5) or 0}`
	end)

	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 58)
	toast.Size = UDim2.fromOffset(560, 38)
	toast.BackgroundColor3 = PANEL
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toast.Font = Enum.Font.FredokaOne
	toast.TextScaled = true
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.Parent = gui
	corner(toast, 12)

	local toastSerial = 0
	local function showToast(text: string)
		toastSerial += 1
		local serial = toastSerial
		toast.Text = text
		toast.TextTransparency = 0
		toast.BackgroundTransparency = 0.15
		task.delay(2.5, function()
			if serial ~= toastSerial then
				return
			end
			local info = TweenInfo.new(0.4)
			TweenService:Create(toast, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end)
	end
	Hud.showToast = showToast
	Remotes.get("Toast").OnClientEvent:Connect(showToast)
end

return Hud
