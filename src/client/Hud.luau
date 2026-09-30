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

local PANEL = Color3.fromRGB(34, 30, 46)
local INK = Color3.fromRGB(18, 15, 28)
local CASH = Color3.fromRGB(255, 214, 64)
local ZOOM = Color3.fromRGB(120, 214, 255)
local SPEED = Color3.fromRGB(162, 240, 150)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- A stat pill: a coloured chip, a caption and a value, on a panel with a soft drop shadow.
type Pill = { value: TextLabel, pop: (Color3) -> () }

local function pill(parent: Instance, order: number, caption: string, tint: Color3): Pill
	local holder = Instance.new("Frame")
	holder.Name = caption
	holder.LayoutOrder = order
	holder.Size = UDim2.fromOffset(176, 46)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	-- Drop shadow: a second panel sat just behind and below the real one.
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(0, 3)
	shadow.BackgroundColor3 = INK
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = holder
	corner(shadow, 23)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = PANEL
	body.BackgroundTransparency = 0.08
	body.BorderSizePixel = 0
	body.ZIndex = 2
	body.Parent = holder
	corner(body, 23)
	stroke(body, INK, 2, 0.25)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(62, 56, 82), PANEL)
	gradient.Rotation = 90
	gradient.Parent = body

	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.AnchorPoint = Vector2.new(0, 0.5)
	chip.Position = UDim2.new(0, 7, 0.5, 0)
	chip.Size = UDim2.fromOffset(32, 32)
	chip.BackgroundColor3 = tint
	chip.BorderSizePixel = 0
	chip.ZIndex = 3
	chip.Parent = body
	corner(chip, 16)
	stroke(chip, INK, 2, 0.4)

	local label = Instance.new("TextLabel")
	label.Name = "Caption"
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.fromOffset(46, 5)
	label.Size = UDim2.new(1, -54, 0, 14)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = string.upper(caption)
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(184, 176, 206)
	label.ZIndex = 3
	label.Parent = body

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.AnchorPoint = Vector2.new(0, 1)
	value.Position = UDim2.new(0, 46, 1, -4)
	value.Size = UDim2.new(1, -54, 0, 24)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.FredokaOne
	value.Text = "0"
	value.TextScaled = true
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextColor3 = Color3.new(1, 1, 1)
	value.ZIndex = 3
	value.Parent = body

	-- A short flash and bump, so a payout is felt rather than just read.
	local function pop(flash: Color3)
		value.TextColor3 = flash
		body.Size = UDim2.fromScale(1.06, 1.06)
		TweenService:Create(value, TweenInfo.new(0.45), { TextColor3 = Color3.new(1, 1, 1) }):Play()
		TweenService:Create(body, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(1, 1),
		}):Play()
	end

	return { value = value, pop = pop }
end

-- Counts the displayed number towards the real one instead of snapping to it.
local function counter(p: Pill, tint: Color3, format: (number) -> string)
	local shown, target = 0, 0
	local function set(next: number)
		if next > target then
			p.pop(tint)
		end
		target = next
	end
	RunService.RenderStepped:Connect(function(dt)
		if shown == target then
			return
		end
		local gap = target - shown
		if math.abs(gap) < 0.6 then
			shown = target
		else
			shown += gap * math.min(dt * 9, 1)
		end
		p.value.Text = format(shown)
	end)
	return set
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
	bar.Position = UDim2.new(0.5, 0, 0, 10)
	bar.Size = UDim2.fromOffset(560, 46)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 9)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar
	-- Phones are the target (spec §2), so the whole bar shrinks rather than overflowing.
	local scale = Instance.new("UIScale")
	scale.Parent = bar
	local function fitBar()
		local width = workspace.CurrentCamera.ViewportSize.X
		scale.Scale = math.clamp(width / 620, 0.62, 1)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitBar)
	fitBar()

	local cash = pill(bar, 1, Strings.Hud.cash, CASH)
	local zoomies = pill(bar, 2, Strings.Hud.zoomies, ZOOM)
	local speed = pill(bar, 3, Strings.Hud.speed, SPEED)

	local setCash = counter(cash, CASH, function(n)
		return Format.number(math.floor(n))
	end)
	local setZoomies = counter(zoomies, ZOOM, function(n)
		return Format.number(math.floor(n))
	end)

	local function refresh()
		setCash(player:GetAttribute("Cash") or 0)
		setZoomies(player:GetAttribute("Zoomies") or 0)
	end
	player:GetAttributeChangedSignal("Cash"):Connect(refresh)
	player:GetAttributeChangedSignal("Zoomies"):Connect(refresh)
	refresh()

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		speed.value.Text = tostring(humanoid and math.floor(humanoid.WalkSpeed + 0.5) or 0)
	end)

	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 68)
	toast.Size = UDim2.fromOffset(560, 42)
	toast.BackgroundColor3 = PANEL
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toast.Font = Enum.Font.FredokaOne
	toast.TextScaled = true
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.Parent = gui
	corner(toast, 21)
	local toastEdge = stroke(toast, CASH, 2, 1)
	local toastPad = Instance.new("UIPadding")
	toastPad.PaddingLeft = UDim.new(0, 16)
	toastPad.PaddingRight = UDim.new(0, 16)
	toastPad.PaddingTop = UDim.new(0, 8)
	toastPad.PaddingBottom = UDim.new(0, 8)
	toastPad.Parent = toast

	local toastSerial = 0
	local function showToast(text: string)
		toastSerial += 1
		local serial = toastSerial
		toast.Text = text
		toast.TextTransparency = 0
		toast.BackgroundTransparency = 0.1
		toastEdge.Transparency = 0.2
		-- Drop in from just above, so a new toast is noticed even mid-chase.
		toast.Position = UDim2.new(0.5, 0, 0, 52)
		TweenService:Create(toast, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0, 68),
		}):Play()
		task.delay(2.5, function()
			if serial ~= toastSerial then
				return
			end
			local info = TweenInfo.new(0.4)
			TweenService:Create(toast, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			TweenService:Create(toastEdge, info, { Transparency = 1 }):Play()
		end)
	end
	Hud.showToast = showToast
	Remotes.get("Toast").OnClientEvent:Connect(showToast)
end

return Hud
