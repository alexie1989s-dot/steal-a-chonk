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

-- A stat pill: a glossy icon bubble, a caption and a value on a glass panel with a soft shadow.
type Pill = { value: TextLabel, pop: (Color3) -> () }

local function pill(parent: Instance, order: number, caption: string, tint: Color3, glyph: string): Pill
	local holder = Instance.new("Frame")
	holder.Name = caption
	holder.LayoutOrder = order
	holder.Size = UDim2.fromOffset(176, 48)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(0, 4)
	shadow.BackgroundColor3 = Ui.INK
	shadow.BackgroundTransparency = 0.6
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = holder
	Ui.corner(shadow, UDim.new(0.5, 0))

	-- Anchored on its centre, so the payout bump grows evenly rather than to the lower right.
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromScale(1, 1)
	body.ZIndex = 2
	body.Parent = holder
	Ui.glass(body, UDim.new(0.5, 0))

	local chip = Ui.bubble(body, tint, 4)
	chip.AnchorPoint = Vector2.new(0, 0.5)
	chip.Position = UDim2.new(0, 6, 0.5, 0)
	chip.Size = UDim2.fromOffset(36, 36)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.52)
	icon.Size = UDim2.fromScale(0.68, 0.68)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.FredokaOne
	icon.Text = glyph
	icon.TextScaled = true
	icon.ZIndex = 6
	icon.Parent = chip

	local label = Instance.new("TextLabel")
	label.Name = "Caption"
	label.Position = UDim2.fromOffset(50, 6)
	label.Size = UDim2.new(1, -60, 0, 13)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = string.upper(caption)
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(196, 190, 222)
	label.ZIndex = 4
	label.Parent = body

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.AnchorPoint = Vector2.new(0, 1)
	value.Position = UDim2.new(0, 50, 1, -5)
	value.Size = UDim2.new(1, -60, 0, 24)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.FredokaOne
	value.Text = "0"
	value.TextScaled = true
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextColor3 = Color3.new(1, 1, 1)
	value.ZIndex = 4
	value.Parent = body
	Ui.stroke(value, Ui.INK, 1.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	-- A short flash and bump, so a payout is felt rather than just read.
	local function pop(flash: Color3)
		value.TextColor3 = flash
		body.Size = UDim2.fromScale(1.08, 1.08)
		TweenService:Create(value, TweenInfo.new(0.45), { TextColor3 = Color3.new(1, 1, 1) }):Play()
		TweenService:Create(body, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
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
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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

		-- A CanvasGroup so the whole toast fades as one: glass, rim, bubble and text together.
		local body = Instance.new("CanvasGroup")
		body.Name = "Body"
		body.Size = UDim2.fromScale(1, 1)
		body.Parent = holder
		Ui.glass(body, UDim.new(0, 16), look.color)

		local chip = Ui.bubble(body, look.color, 3)
		chip.Name = "Chip"
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.new(0, 7, 0.5, 0)
		chip.Size = UDim2.fromOffset(TOAST_HEIGHT - 12, TOAST_HEIGHT - 12)
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromScale(0.74, 0.74)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.52)
		icon.BackgroundTransparency = 1
		icon.Text = look.icon
		icon.TextScaled = true
		icon.Font = Enum.Font.FredokaOne
		icon.ZIndex = 5
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
		label.ZIndex = 3
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
