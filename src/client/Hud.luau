-- Minimal HUD (spec §19): cash, Zoomies and speed readouts, the toast stack and the sound switch.
-- Reads server-written Player attributes; sends nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local Hud = {}

local PANEL = Color3.fromRGB(34, 30, 46)
local INK = Color3.fromRGB(18, 15, 28)
local CASH = Color3.fromRGB(255, 214, 64)
local ZOOM = Color3.fromRGB(120, 214, 255)
local SPEED = Color3.fromRGB(162, 240, 150)
local TOAST_WIDTH = 520
local TOAST_HEIGHT = 48
local MAX_TOASTS = 3
-- Each tone's rim colour and icon. Emoji render from the engine's own emoji font.
local TONES = {
	good = { color = Color3.fromRGB(116, 222, 104), icon = utf8.char(0x2728) },
	bad = { color = Color3.fromRGB(255, 96, 96), icon = utf8.char(0x1F4A5) },
	alert = { color = Color3.fromRGB(255, 150, 40), icon = utf8.char(0x1F6A8) },
	info = { color = Color3.fromRGB(120, 190, 255), icon = utf8.char(0x1F43E) },
}
local SOUND_ON = utf8.char(0x1F50A)
local SOUND_OFF = utf8.char(0x1F507)

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

local function pill(parent: Instance, order: number, caption: string, tint: Color3, glyph: string): Pill
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
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.72, 0.72)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.FredokaOne
	icon.Text = glyph
	icon.TextScaled = true
	icon.ZIndex = 4
	icon.Parent = chip

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

	local cash = pill(bar, 1, Strings.Hud.cash, CASH, utf8.char(0x1F4B0))
	local zoomies = pill(bar, 2, Strings.Hud.zoomies, ZOOM, utf8.char(0x26A1))
	local speed = pill(bar, 3, Strings.Hud.speed, SPEED, utf8.char(0x1F45F))

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

	-- The sound switch, on the left edge: the top right belongs to Roblox's player list, which
	-- covered it there.
	local mute, muteLabel = Ui.button({
		name = "Sound",
		size = UDim2.fromOffset(52, 52),
		position = UDim2.new(0, 14, 0.42, 0),
		anchor = Vector2.new(0, 0.5),
		color = Color3.fromRGB(120, 190, 255),
		text = SOUND_ON,
		round = true,
		parent = gui,
	})
	muteLabel.Font = Enum.Font.FredokaOne
	mute.Activated:Connect(function()
		Sfx.setMuted(not Sfx.isMuted())
		muteLabel.Text = if Sfx.isMuted() then SOUND_OFF else SOUND_ON
	end)

	-- Toasts stack under the stat bar, newest on top, each in its tone's colour with its icon.
	local stack = Instance.new("Frame")
	stack.Name = "Toasts"
	stack.AnchorPoint = Vector2.new(0.5, 0)
	stack.Position = UDim2.new(0.5, 0, 0, 66)
	stack.Size = UDim2.fromOffset(TOAST_WIDTH, 3 * (TOAST_HEIGHT + 6))
	stack.BackgroundTransparency = 1
	stack.Parent = gui
	local stackLayout = Instance.new("UIListLayout")
	stackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stackLayout.Padding = UDim.new(0, 6)
	stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stackLayout.Parent = stack
	-- The stack shrinks with the stat bar on a phone.
	local stackScale = Instance.new("UIScale")
	stackScale.Parent = stack
	local function fitStack()
		stackScale.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.X / (TOAST_WIDTH + 40), 0.62, 1)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitStack)
	fitStack()

	local toastSerial = 0
	local live: { Frame } = {}

	local function dismissToast(holder: Frame, body: CanvasGroup)
		local index = table.find(live, holder)
		if not index then
			return
		end
		table.remove(live, index)
		local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(body, info, { GroupTransparency = 1, Position = UDim2.fromOffset(0, -10) }):Play()
		task.delay(0.3, function()
			holder:Destroy()
		end)
	end

	local function showToast(text: string, tone: string?, sound: string?)
		local look = TONES[tone or "info"] or TONES.info
		toastSerial += 1

		local holder = Instance.new("Frame")
		holder.Name = `Toast{toastSerial}`
		holder.LayoutOrder = -toastSerial -- newest first
		holder.Size = UDim2.fromOffset(TOAST_WIDTH, TOAST_HEIGHT)
		holder.BackgroundTransparency = 1
		holder.Parent = stack

		-- A CanvasGroup so the whole toast fades as one, outline and icon included.
		local body = Instance.new("CanvasGroup")
		body.Name = "Body"
		body.Size = UDim2.fromScale(1, 1)
		body.BackgroundColor3 = PANEL
		body.BorderSizePixel = 0
		body.Parent = holder
		corner(body, 14)
		stroke(body, look.color, 3, 0)
		local sheen = Instance.new("UIGradient")
		sheen.Color = ColorSequence.new(Color3.fromRGB(62, 56, 82), PANEL)
		sheen.Rotation = 90
		sheen.Parent = body

		local chip = Instance.new("Frame")
		chip.Name = "Chip"
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.new(0, 7, 0.5, 0)
		chip.Size = UDim2.fromOffset(TOAST_HEIGHT - 14, TOAST_HEIGHT - 14)
		chip.BackgroundColor3 = look.color
		chip.BorderSizePixel = 0
		chip.Parent = body
		corner(chip, (TOAST_HEIGHT - 14) // 2)
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromScale(0.78, 0.78)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Text = look.icon
		icon.TextScaled = true
		icon.Font = Enum.Font.FredokaOne
		icon.Parent = chip

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Position = UDim2.fromOffset(TOAST_HEIGHT, 0)
		label.Size = UDim2.new(1, -TOAST_HEIGHT - 12, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.Text = text
		label.TextScaled = true
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = body
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 22
		cap.Parent = label
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.Parent = label

		-- Drops in from just above with a little overshoot, so it is noticed even mid-chase.
		body.GroupTransparency = 1
		body.Position = UDim2.fromOffset(0, -14)
		TweenService:Create(body, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			GroupTransparency = 0,
			Position = UDim2.fromOffset(0, 0),
		}):Play()

		table.insert(live, holder)
		if #live > MAX_TOASTS then
			local oldest = live[1]
			dismissToast(oldest, oldest:FindFirstChild("Body") :: CanvasGroup)
		end
		-- Long messages stay up a little longer.
		task.delay(math.clamp(2 + #text * 0.04, 2.6, 5), function()
			dismissToast(holder, body)
		end)
		if sound then
			Sfx.play(sound)
		end
	end
	Hud.showToast = showToast
	Remotes.get("Toast").OnClientEvent:Connect(showToast)
end

return Hud
