-- Shared look for the client's own UI: glossy bubble buttons and glass panels, the style most
-- Roblox games give the things you press. Built from plain GUI instances (gradients, strokes,
-- corners) and the engine's bundled fonts, so it needs no image assets.
--
-- Layering: each helper puts its decoration at a ZIndex relative to the shape it decorates, and
-- every ScreenGui and BillboardGui that uses them runs in Sibling mode, where a child always draws
-- over its parent and siblings stack by ZIndex.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Sfx = require(script.Parent.Sfx)

local Ui = {}

Ui.INK = Color3.fromRGB(18, 15, 28)
Ui.PANEL = Color3.fromRGB(34, 30, 46)

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
-- How long one glint takes to cross a shape, in seconds.
local SWEEP = 0.65
-- A narrow bright band in the middle of an otherwise clear gradient.
local STREAK = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.42, 1),
	NumberSequenceKeypoint.new(0.5, 0.5),
	NumberSequenceKeypoint.new(0.58, 1),
	NumberSequenceKeypoint.new(1, 1),
})

-- Towards white (f > 0) or black (f < 0) by that fraction.
function Ui.shade(color: Color3, f: number): Color3
	return if f >= 0 then color:Lerp(WHITE, f) else color:Lerp(BLACK, -f)
end

function Ui.corner(parent: Instance, radius: UDim): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
	return c
end

function Ui.stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function sheenColors(color: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Ui.shade(color, 0.3)),
		ColorSequenceKeypoint.new(0.5, color),
		ColorSequenceKeypoint.new(1, Ui.shade(color, -0.2)),
	})
end

-- The body colour of a glossy shape: lighter at the top, the colour itself through the middle and
-- deeper at the bottom. A UIGradient multiplies the background, so the background turns white and
-- the gradient carries the colour.
function Ui.sheen(shape: GuiObject, color: Color3): UIGradient
	shape.BackgroundColor3 = WHITE
	local g = Instance.new("UIGradient")
	g.Name = "Sheen"
	g.Rotation = 90
	g.Color = sheenColors(color)
	g.Parent = shape
	return g
end

-- Recolours a shape that was given a sheen (a tier band, a tone chip).
function Ui.recolor(shape: GuiObject, color: Color3)
	local g = shape:FindFirstChild("Sheen")
	if g and g:IsA("UIGradient") then
		g.Color = sheenColors(color)
	else
		shape.BackgroundColor3 = color
	end
end

-- The wet highlight across the top of a rounded shape: a white cap, inset and rounded like the
-- shape, that fades out downwards, so it reads as light on a curved surface. On a fully rounded
-- shape the cap is narrower: at 0.86 its upper corners poked past a circle's edge into the outline.
function Ui.gloss(shape: GuiObject, radius: UDim, strength: number?): Frame
	local cap = Instance.new("Frame")
	cap.Name = "Gloss"
	cap.AnchorPoint = Vector2.new(0.5, 0)
	cap.Position = UDim2.fromScale(0.5, 0.07)
	cap.Size = UDim2.fromScale(if radius.Scale >= 0.5 then 0.78 else 0.86, 0.45)
	cap.BackgroundColor3 = WHITE
	cap.BorderSizePixel = 0
	cap.ZIndex = shape.ZIndex + 1
	cap.Parent = shape
	Ui.corner(cap, radius)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(1 - (strength or 0.55), 1)
	fade.Parent = cap
	return cap
end

-- A thin light line just inside the edge: the detail that makes a shape read as glass.
function Ui.rim(shape: GuiObject, radius: UDim, transparency: number?): Frame
	local ring = Instance.new("Frame")
	ring.Name = "Rim"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, -6, 1, -6)
	ring.BackgroundTransparency = 1
	ring.ZIndex = shape.ZIndex + 1
	ring.Parent = shape
	Ui.corner(ring, radius)
	Ui.stroke(ring, WHITE, 1.5, transparency or 0.6)
	return ring
end

type Glint = { gradient: UIGradient, period: number, start: number }
local glints: { Glint } = {}

-- A bright diagonal streak that sweeps across a shape every `period` seconds. It is a full-size
-- copy of the shape's outline, so the shape's rounded corners clip it.
function Ui.glint(shape: GuiObject, radius: UDim, period: number?): Frame
	local streak = Instance.new("Frame")
	streak.Name = "Glint"
	streak.Size = UDim2.fromScale(1, 1)
	streak.BackgroundColor3 = WHITE
	streak.BorderSizePixel = 0
	streak.ZIndex = shape.ZIndex + 2
	streak.Parent = shape
	Ui.corner(streak, radius)
	local g = Instance.new("UIGradient")
	g.Rotation = 24
	g.Transparency = STREAK
	g.Offset = Vector2.new(-1, 0)
	g.Parent = streak
	local every = period or 5
	-- Staggered, so a row of buttons never flashes in step.
	table.insert(glints, { gradient = g, period = every, start = os.clock() - math.random() * every })
	return streak
end

-- Sweeps a glint across now, on top of its own rhythm (a reveal card arriving).
function Ui.sweep(streak: Frame)
	local g = streak:FindFirstChildOfClass("UIGradient")
	for _, glint in glints do
		if glint.gradient == g then
			glint.start = os.clock()
		end
	end
end

-- How many glints are being driven, for the leak check in Studio.
function Ui.glintCount(): number
	return #glints
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = #glints, 1, -1 do
		local glint = glints[i]
		local g = glint.gradient
		-- Destroying a gui sets every descendant's Parent to nil: that glint is finished.
		if g.Parent == nil then
			table.remove(glints, i)
			continue
		end
		local t = (now - glint.start) % glint.period
		g.Offset = Vector2.new(if t < SWEEP then -1 + 2 * t / SWEEP else -1, 0)
	end
end)

-- A glossy round chip for an icon or a key. The caller sets its size, position and anchor.
function Ui.bubble(parent: Instance, color: Color3, zIndex: number): Frame
	local chip = Instance.new("Frame")
	chip.Name = "Bubble"
	chip.BorderSizePixel = 0
	chip.ZIndex = zIndex
	chip.Parent = parent
	local round = UDim.new(0.5, 0)
	Ui.corner(chip, round)
	Ui.stroke(chip, Ui.INK, 2)
	Ui.sheen(chip, color)
	Ui.gloss(chip, round, 0.7)
	return chip
end

-- A glass panel: dark and a little see-through, a faint reflection over its top half and a thin
-- bright rim inside an outline. `edge` colours the outline (a toast's tone); ink by default.
function Ui.glass(frame: GuiObject, radius: UDim, edge: Color3?)
	frame.BorderSizePixel = 0
	local thickness = if edge then 3 else 2.5
	-- A CanvasGroup needs its glass built inside it. A UIGradient on the group tints everything in
	-- it, text included (a toast's words went dark), and a UIStroke on the group ignores its
	-- GroupTransparency (the edge stayed solid while the toast faded). So the body is a child fill,
	-- inset by the outline's width so the outline drawn round it is still inside the group.
	local body: GuiObject = frame
	if frame:IsA("CanvasGroup") then
		local inset = math.ceil(thickness)
		frame.BackgroundTransparency = 1
		Ui.corner(frame, UDim.new(radius.Scale, radius.Offset + inset))
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.AnchorPoint = Vector2.new(0.5, 0.5)
		fill.Position = UDim2.fromScale(0.5, 0.5)
		fill.Size = UDim2.new(1, -2 * inset, 1, -2 * inset)
		fill.BorderSizePixel = 0
		fill.ZIndex = frame.ZIndex
		fill.Parent = frame
		Ui.corner(fill, radius)
		Ui.stroke(fill, edge or Ui.INK, thickness)
		body = fill
	else
		Ui.corner(frame, radius)
		Ui.stroke(frame, edge or Ui.INK, thickness)
	end
	body.BackgroundTransparency = 0.12
	local g = Instance.new("UIGradient")
	g.Name = "Sheen"
	g.Rotation = 90
	g.Color = ColorSequence.new(Ui.shade(Ui.PANEL, 0.2), Ui.shade(Ui.PANEL, -0.25))
	g.Parent = body
	body.BackgroundColor3 = WHITE
	Ui.rim(frame, radius, 0.78)
	Ui.gloss(frame, radius, 0.14)
end

-- Heavy display type in white with an ink outline and a faint cool tint towards the bottom, the
-- genre's lettering.
function Ui.label(parent: Instance, text: string, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font or Enum.Font.LuckiestGuy
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.ZIndex = (if parent:IsA("GuiObject") then parent.ZIndex else 1) + 4
	label.Parent = parent
	local outline = Instance.new("UIStroke")
	outline.Color = Ui.INK
	outline.Thickness = 2.5
	outline.Parent = label
	local tint = Instance.new("UIGradient")
	tint.Rotation = 90
	tint.Color = ColorSequence.new(WHITE, Color3.fromRGB(222, 230, 255))
	tint.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.14, 0)
	pad.PaddingLeft = UDim.new(0.12, 0)
	pad.PaddingRight = UDim.new(0.12, 0)
	pad.Parent = label
	return label
end

export type ButtonSpec = {
	name: string,
	size: UDim2,
	position: UDim2,
	anchor: Vector2?,
	color: Color3,
	text: string,
	round: boolean?,
	parent: Instance,
}

-- A glossy bubble button: a coloured face with a wet highlight, a bright inner rim and a glint,
-- sitting on a deeper "lip" of its own colour like the side of a sweet. Pressing sinks the face
-- onto the lip with a white flash; releasing springs it back.
--
-- Everything that moves lives in "Art", anchored on its centre so the squash shrinks it about its
-- middle. What you press is a separate invisible button over it that never moves or scales, so a
-- tap near the edge still lands while the face shrinks under it. The press lets go when that input
-- ends anywhere, so a thumb sliding off never leaves the face stuck down.
--
-- Returns the button to connect `Activated` to, and the label. The click sound plays on every press.
function Ui.button(spec: ButtonSpec): (TextButton, TextLabel)
	local holder = Instance.new("Frame")
	holder.Name = spec.name
	holder.Size = spec.size
	holder.Position = spec.position
	holder.AnchorPoint = spec.anchor or Vector2.zero
	holder.BackgroundTransparency = 1
	holder.Parent = spec.parent
	if spec.round then
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = holder
	end
	local radius = if spec.round then UDim.new(0.5, 0) else UDim.new(0.32, 0)
	local depth = if spec.round then 5 else 4

	local art = Instance.new("Frame")
	art.Name = "Art"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundTransparency = 1
	art.ZIndex = 1
	art.Parent = holder
	local scale = Instance.new("UIScale")
	scale.Parent = art

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0)
	shadow.Position = UDim2.new(0.5, 0, 0, depth + 3)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.BackgroundColor3 = Ui.INK
	shadow.BackgroundTransparency = 0.62
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = art
	Ui.corner(shadow, radius)

	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.Position = UDim2.fromOffset(0, depth)
	lip.Size = UDim2.fromScale(1, 1)
	lip.BackgroundColor3 = Ui.shade(spec.color, -0.42)
	lip.BorderSizePixel = 0
	lip.ZIndex = 2
	lip.Parent = art
	Ui.corner(lip, radius)
	Ui.stroke(lip, Ui.INK, 3)

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BorderSizePixel = 0
	face.ZIndex = 3
	face.Parent = art
	Ui.corner(face, radius)
	Ui.stroke(face, Ui.INK, 3)
	Ui.sheen(face, spec.color)
	Ui.rim(face, radius, 0.5)
	Ui.gloss(face, radius, 0.62)
	Ui.glint(face, radius)
	local label = Ui.label(face, string.upper(spec.text))

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = face.ZIndex + 5
	flash.Parent = face
	Ui.corner(flash, radius)

	-- The press target covers the face and the lip below it.
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Size = UDim2.new(1, 0, 1, depth)
	hit.BackgroundTransparency = 1
	hit.AutoButtonColor = false
	hit.Text = ""
	hit.ZIndex = 2
	hit.Parent = holder

	local up = UDim2.fromOffset(0, 0)
	local down = UDim2.fromOffset(0, depth - 1)
	local pressing: InputObject? = nil
	local hovering = false
	local function spring(position: UDim2, size: number, time: number)
		local info = TweenInfo.new(time, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(face, info, { Position = position }):Play()
		TweenService:Create(scale, info, { Scale = size }):Play()
	end
	hit.MouseEnter:Connect(function()
		hovering = true
		if not pressing then
			spring(up, 1.05, 0.15)
		end
	end)
	hit.MouseLeave:Connect(function()
		hovering = false
		if not pressing then
			spring(up, 1, 0.15)
		end
	end)
	hit.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		pressing = input
		local info = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(face, info, { Position = down }):Play()
		TweenService:Create(scale, info, { Scale = 0.95 }):Play()
		flash.BackgroundTransparency = 0.6
		TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	end)
	-- A touch keeps its InputObject from start to end; a mouse button may not, so it matches by kind.
	local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
		local held = pressing
		if not held then
			return
		end
		local mouse = Enum.UserInputType.MouseButton1
		if input == held or (input.UserInputType == mouse and held.UserInputType == mouse) then
			pressing = nil
			spring(up, if hovering then 1.05 else 1, 0.22)
		end
	end)
	holder.Destroying:Connect(function()
		ended:Disconnect()
	end)
	hit.Activated:Connect(function()
		Sfx.play("click")
	end)
	return hit, label
end

return Ui
