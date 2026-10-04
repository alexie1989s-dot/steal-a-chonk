-- The reveal card (spec §8, §19): full-screen, screenshot-ready, dismissed with one tap.
-- Reveals that arrive while a card is open wait their turn.
--
-- The card shows the Chonk itself: the server sends the model it just placed, and a copy of it
-- sways on a turntable in a ViewportFrame. Everything here is built from plain GUI instances in
-- the HUD's style -- dark panel, ink outline, tier-coloured accents -- with no image assets.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Sfx = require(script.Parent.Sfx)
local Ui = require(script.Parent.Ui)

local Reveal = {}

local PANEL = Color3.fromRGB(34, 30, 46)
local PANEL_TOP = Color3.fromRGB(62, 56, 82)
local INK = Color3.fromRGB(18, 15, 28)
local GOLD = Color3.fromRGB(255, 214, 64)
local STAMP_RED = Color3.fromRGB(235, 60, 60)
local RAYS = 12
-- From this tier up, or at the top size, the card gets the bigger fanfare.
local BIG_TIER = table.find(Config.Tiers, "Epic") :: number

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

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

-- A copy of a world Chonk fit for a ViewportFrame: no prompts, tags, lights or idle tag, resting at
-- the origin facing the camera (-Z is the face, see Models).
local function portraitOf(model: Model): Model?
	local ok, copy = pcall(function()
		return model:Clone()
	end)
	if not (ok and copy) then
		return nil
	end
	-- Tags travel with a clone, and the idle bob would otherwise adopt the copy.
	for _, tag in CollectionService:GetTags(copy) do
		CollectionService:RemoveTag(copy, tag)
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("Light") or d:IsA("LuaSourceContainer") then
			d:Destroy()
		else
			for _, tag in CollectionService:GetTags(d) do
				CollectionService:RemoveTag(d, tag)
			end
		end
	end
	copy:PivotTo(CFrame.new())
	return copy
end

function Reveal.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Reveal"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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

	-- A burst of tier-coloured rays behind the card. Each ray turns about its own centre, which is
	-- the card's centre, so the set reads as one slowly spinning sunburst.
	local burst = Instance.new("Frame")
	burst.Name = "Burst"
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.fromScale(0.5, 0.5)
	-- Kept close round the card and faint: full-screen rays at half opacity swamped everything, and
	-- for a Common (grey) they were just a white mess.
	burst.Size = UDim2.fromScale(1.25, 1.25)
	burst.BackgroundTransparency = 1
	burst.Parent = backdrop
	local burstAspect = Instance.new("UIAspectRatioConstraint")
	burstAspect.DominantAxis = Enum.DominantAxis.Height
	burstAspect.Parent = burst
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.44, 0.44)
	glow.BackgroundTransparency = 0.8
	glow.Parent = burst
	corner(glow, UDim.new(0.5, 0))
	local rays: { Frame } = {}
	for i = 1, RAYS do
		local ray = Instance.new("Frame")
		ray.Name = `Ray{i}`
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromScale(if i % 2 == 0 then 0.05 else 0.028, 1)
		ray.BorderSizePixel = 0
		ray.Parent = burst
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.9),
			NumberSequenceKeypoint.new(0.5, 0.8),
			NumberSequenceKeypoint.new(0.8, 0.9),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
		table.insert(rays, ray)
	end

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.8, 0.8)
	card.BackgroundColor3 = Color3.new(1, 1, 1) -- the gradient below multiplies this, so it carries the colour
	card.Active = false
	card.Parent = backdrop
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 0.78
	aspect.Parent = card
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(500, 640)
	sizeLimit.Parent = card
	corner(card, UDim.new(0, 24))
	local rim = stroke(card, GOLD, 4, 0)
	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new(PANEL_TOP, PANEL)
	sheen.Rotation = 90
	sheen.Parent = card
	Ui.rim(card, UDim.new(0, 24), 0.8)
	local cardGlint = Ui.glint(card, UDim.new(0, 24), 7)
	local scale = Instance.new("UIScale")
	scale.Parent = card

	-- The tier ribbon across the top. Its lower corners are squared off by a filler strip, so it
	-- reads as a band on the card rather than a pill floating on it.
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.Size = UDim2.fromScale(1, 0.12)
	band.BorderSizePixel = 0
	band.Parent = card
	corner(band, UDim.new(0, 24))
	local bandFill = Instance.new("Frame")
	bandFill.Name = "Fill"
	bandFill.Position = UDim2.fromScale(0, 0.5)
	bandFill.Size = UDim2.fromScale(1, 0.5)
	bandFill.BorderSizePixel = 0
	bandFill.Parent = band
	local tier = text(band, "Tier", {
		Size = UDim2.fromScale(0.9, 0.62),
		Position = UDim2.fromScale(0.05, 0.2),
		TextColor3 = INK,
		ZIndex = 2,
	})
	tier.ZIndex = 3
	Ui.gloss(band, UDim.new(0, 24), 0.5)

	-- The portrait: a spotlight disc with the Chonk turning on it.
	local spot = Instance.new("Frame")
	spot.Name = "Spot"
	spot.AnchorPoint = Vector2.new(0.5, 0.5)
	spot.Position = UDim2.fromScale(0.5, 0.31)
	spot.Size = UDim2.fromScale(0.34, 0.34)
	spot.BackgroundTransparency = 0.8
	spot.Parent = card
	local spotAspect = Instance.new("UIAspectRatioConstraint")
	spotAspect.DominantAxis = Enum.DominantAxis.Height
	spotAspect.Parent = spot
	corner(spot, UDim.new(0.5, 0))
	local view = Instance.new("ViewportFrame")
	view.Name = "Portrait"
	view.Position = UDim2.fromScale(0.05, 0.13)
	view.Size = UDim2.fromScale(0.9, 0.36)
	view.ZIndex = 2
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(150, 146, 168)
	view.LightColor = Color3.fromRGB(255, 246, 228)
	view.LightDirection = Vector3.new(-0.5, -1, 0.6)
	view.Parent = card
	local lens = Instance.new("Camera")
	lens.FieldOfView = 30
	lens.Parent = view
	view.CurrentCamera = lens

	-- Stamped across the portrait's lower corner, like a rubber stamp on a photo, so it no longer
	-- sits in the line between the picture and the name.
	local stamp = text(card, "SizeStamp", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.56, 0.07),
		Position = UDim2.fromScale(0.7, 0.44),
		TextColor3 = GOLD,
		Rotation = -10,
		ZIndex = 3,
	})
	local stampEdge = Instance.new("UIStroke")
	stampEdge.Color = INK
	stampEdge.Thickness = 3
	stampEdge.Parent = stamp
	local stampScale = Instance.new("UIScale")
	stampScale.Parent = stamp

	local name = text(card, "DisplayName", {
		Size = UDim2.fromScale(0.9, 0.11),
		Position = UDim2.fromScale(0.05, 0.53),
	})
	local species = text(card, "Species", {
		Size = UDim2.fromScale(0.9, 0.045),
		Position = UDim2.fromScale(0.05, 0.645),
		TextColor3 = Color3.fromRGB(184, 176, 206),
	})
	local bio = text(card, "Bio", {
		Size = UDim2.fromScale(0.84, 0.13),
		Position = UDim2.fromScale(0.08, 0.705),
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(230, 226, 240),
	})

	-- Income on its own plate, in the HUD's cash gold, so the number that matters reads first.
	local incomePlate = Instance.new("Frame")
	incomePlate.Name = "IncomePlate"
	incomePlate.AnchorPoint = Vector2.new(0.5, 0)
	incomePlate.Position = UDim2.fromScale(0.5, 0.85)
	incomePlate.Size = UDim2.fromScale(0.64, 0.072)
	incomePlate.BackgroundColor3 = INK
	incomePlate.BackgroundTransparency = 0.2
	incomePlate.Parent = card
	corner(incomePlate, UDim.new(0.5, 0))
	stroke(incomePlate, GOLD, 2, 0.3)
	Ui.rim(incomePlate, UDim.new(0.5, 0), 0.7)
	Ui.gloss(incomePlate, UDim.new(0.5, 0), 0.2)
	local income = text(incomePlate, "Income", {
		Size = UDim2.fromScale(0.86, 0.72),
		Position = UDim2.fromScale(0.07, 0.14),
		TextColor3 = GOLD,
	})
	income.ZIndex = 3

	local dismiss = text(card, "Dismiss", {
		Size = UDim2.fromScale(0.9, 0.04),
		Position = UDim2.fromScale(0.05, 0.94),
		TextColor3 = Color3.fromRGB(170, 165, 190),
		Text = Strings.Reveal.dismiss,
	})

	local queue = {}
	local showing = false
	local shown = 0 -- counts cards, so a delayed step from a card already dismissed does nothing
	local live: RBXScriptConnection?
	local portrait: Model?

	local function clearPortrait()
		if portrait then
			portrait:Destroy()
			portrait = nil
		end
	end

	-- Frames the portrait so the whole Chonk fits whatever its size or species.
	local function frame(model: Model): (Vector3, number)
		local box, size = model:GetBoundingBox()
		-- The largest half-extent, not the bounding sphere: the sphere left the Chonk a third of the
		-- frame. The portrait is wider than it is tall, so the sway never turns it out of view.
		local radius = math.max(size.X, size.Y, size.Z) / 2
		return box.Position, radius / math.tan(math.rad(lens.FieldOfView / 2)) * 1.3
	end

	local function showNext()
		if live then
			live:Disconnect()
			live = nil
		end
		clearPortrait()
		local entry = table.remove(queue, 1)
		if not entry then
			showing = false
			gui.Enabled = false
			return
		end
		showing = true
		shown += 1
		local this = shown
		local payload, model = entry.payload, entry.model
		local rgb = Config.TierColors[payload.tier] or { 255, 255, 255 }
		local tint = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		band.BackgroundColor3 = tint
		bandFill.BackgroundColor3 = tint
		rim.Color = tint
		glow.BackgroundColor3 = tint
		spot.BackgroundColor3 = tint
		for _, ray in rays do
			ray.BackgroundColor3 = tint
		end
		tier.Text = string.upper(payload.tier)
		species.Text = string.upper(payload.species)
		name.Text = payload.displayName
		stamp.Text = payload.sizeStamp
		bio.Text = payload.bio
		income.Text = string.format(Strings.Reveal.incomeFormat, Format.rate(payload.incomePerSecond))

		-- The model may not have arrived (or may be gone already); the card works without it.
		local centre, distance = Vector3.zero, 10
		if typeof(model) == "Instance" and model:IsA("Model") then
			portrait = portraitOf(model)
			if portrait then
				centre, distance = frame(portrait)
				portrait.Parent = view
			end
		end

		-- The top size prints in red on a shaking card (spec §8).
		local top = payload.size >= 6
		stamp.TextColor3 = if top then STAMP_RED else GOLD
		-- A top-size card wobbles the stamp; put it back to rest for the next one.
		stamp.Rotation = -10
		card.Rotation = 0

		gui.Enabled = true
		local big = top or (table.find(Config.Tiers, payload.tier) or 1) >= BIG_TIER
		Sfx.play("whoosh")
		Sfx.play(if big then "revealBig" else "reveal")
		backdrop.BackgroundTransparency = 1
		TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.35 }):Play()
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		Ui.sweep(cardGlint)
		-- The size stamp lands a beat after the card, like a rubber stamp.
		stamp.TextTransparency = 1
		stampEdge.Transparency = 1
		stampScale.Scale = 2.4
		task.delay(0.32, function()
			if not (showing and shown == this) then
				return
			end
			stamp.TextTransparency = 0
			stampEdge.Transparency = 0
			Sfx.play("stamp")
			TweenService:Create(stampScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end)

		local started = os.clock()
		live = RunService.RenderStepped:Connect(function()
			local t = os.clock() - started
			for i, ray in rays do
				ray.Rotation = (i - 1) * (180 / RAYS) + t * 12
			end
			if portrait then
				-- A turntable that sways rather than spins, so the face is showing most of the time.
				local yaw = math.pi + math.sin(t * 0.9) * 0.6
				lens.CFrame = CFrame.new(centre)
					* CFrame.Angles(0, yaw, 0)
					* CFrame.Angles(-0.2, 0, 0)
					* CFrame.new(0, 0, distance)
			end
			dismiss.TextTransparency = 0.25 + math.sin(t * 3) * 0.25
			if top then
				stamp.Rotation = -10 + math.sin(t * 40) * 4
				card.Rotation = math.sin(t * 31) * 1.2
			end
		end)
	end

	backdrop.Activated:Connect(function()
		Sfx.play("click")
		card.Rotation = 0
		showNext()
	end)

	Remotes.get("Reveal").OnClientEvent:Connect(function(payload, model)
		table.insert(queue, { payload = payload, model = model })
		if not showing then
			showNext()
		end
	end)
end

return Reveal
