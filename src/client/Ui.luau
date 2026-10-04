-- Shared look for the client's own buttons: a chunky coloured face on a dark drop shadow, an ink
-- outline, heavy outlined type, and a squash when pressed. Built from plain GUI instances and the
-- engine's bundled fonts, so it needs no image assets.
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)

local Ui = {}

Ui.INK = Color3.fromRGB(18, 15, 28)
Ui.PANEL = Color3.fromRGB(34, 30, 46)

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

-- Lighter at the top, the colour itself at the bottom: reads as a raised face.
function Ui.sheen(parent: Instance, color: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color)
	g.Rotation = 90
	g.Parent = parent
end

-- Heavy display type with an ink outline, the genre's lettering.
function Ui.label(parent: Instance, text: string, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font or Enum.Font.LuckiestGuy
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.ZIndex = 4
	label.Parent = parent
	local outline = Instance.new("UIStroke")
	outline.Color = Ui.INK
	outline.Thickness = 2
	outline.Parent = label
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

-- Returns the clickable face and its label. The click sound plays on every press; connect
-- `Activated` for the action.
function Ui.button(spec: ButtonSpec): (TextButton, TextLabel)
	local holder = Instance.new("Frame")
	holder.Name = spec.name
	holder.Size = spec.size
	holder.Position = spec.position
	holder.AnchorPoint = spec.anchor or Vector2.zero
	holder.BackgroundTransparency = 1
	holder.Parent = spec.parent
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local radius = if spec.round then UDim.new(0.5, 0) else UDim.new(0.28, 0)

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(0, 4)
	shadow.BackgroundColor3 = Ui.INK
	shadow.BackgroundTransparency = 0.35
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = holder
	Ui.corner(shadow, radius)

	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = spec.color
	face.BorderSizePixel = 0
	face.AutoButtonColor = false
	face.Text = ""
	face.ZIndex = 2
	face.Parent = holder
	Ui.corner(face, radius)
	Ui.stroke(face, Ui.INK, 3)
	Ui.sheen(face, spec.color)
	local label = Ui.label(face, string.upper(spec.text))

	local function to(value: number, time: number)
		TweenService:Create(scale, TweenInfo.new(time, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = value,
		}):Play()
	end
	face.MouseEnter:Connect(function()
		to(1.06, 0.15)
	end)
	face.MouseLeave:Connect(function()
		to(1, 0.15)
	end)
	face.MouseButton1Down:Connect(function()
		to(0.9, 0.08)
	end)
	face.MouseButton1Up:Connect(function()
		to(1, 0.2)
	end)
	face.Activated:Connect(function()
		Sfx.play("click")
	end)
	return face, label
end

return Ui
