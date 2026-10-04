-- The game's own look for every ProximityPrompt: a key chip and the action in heavy outlined type on
-- the HUD's dark plate, with a fill that tracks a hold (the 1.5 s Steal).
--
-- Only the drawing changes. Each prompt is switched to the Custom style on this client alone; the
-- engine still reads the key, the server still times holds and re-checks every trigger.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Ui)

local Prompts = {}

local WIDTH, PLATE, CAPTION = 210, 52, 20
local GOLD = Color3.fromRGB(255, 214, 64)
local HOLD_FILL = Color3.fromRGB(255, 120, 80)
local CAPTION_INK = Color3.fromRGB(226, 220, 240)
local GAMEPAD_KEYS = { ButtonX = "X", ButtonY = "Y", ButtonA = "A", ButtonB = "B" }
local TAP = utf8.char(0x1F446)

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return TAP
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return GAMEPAD_KEYS[prompt.GamepadKeyCode.Name] or prompt.GamepadKeyCode.Name
	end
	local text = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	return if text ~= "" then text else prompt.KeyboardKeyCode.Name
end

-- Builds the billboard for one showing of a prompt; returns a function that takes it down.
local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): () -> ()
	local connections: { RBXScriptConnection } = {}
	local board = Instance.new("BillboardGui")
	board.Name = "Prompt"
	board.AlwaysOnTop = true
	board.ResetOnSpawn = false
	board.Active = true
	board.Size = UDim2.fromOffset(WIDTH, PLATE + CAPTION)
	board.SizeOffset = Vector2.new(prompt.UIOffset.X / WIDTH, prompt.UIOffset.Y / (PLATE + CAPTION))
	board.Adornee = prompt.Parent :: Instance
	local scale = Instance.new("UIScale")
	scale.Parent = board

	if prompt.ObjectText ~= "" then
		local caption = Instance.new("TextLabel")
		caption.Name = "Object"
		caption.Size = UDim2.new(1, 0, 0, CAPTION)
		caption.BackgroundTransparency = 1
		caption.Font = Enum.Font.FredokaOne
		caption.Text = prompt.ObjectText
		caption.TextScaled = true
		caption.TextColor3 = CAPTION_INK
		caption.Parent = board
		Ui.stroke(caption, Ui.INK, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	end

	-- The plate is a button so a tap or click works the prompt too.
	local plate = Instance.new("TextButton")
	plate.Name = "Plate"
	plate.Position = UDim2.fromOffset(0, CAPTION)
	plate.Size = UDim2.new(1, 0, 0, PLATE)
	plate.BackgroundColor3 = Ui.PANEL
	plate.BorderSizePixel = 0
	plate.AutoButtonColor = false
	plate.Text = ""
	plate.ClipsDescendants = true
	plate.Parent = board
	Ui.corner(plate, UDim.new(0.5, 0))
	Ui.stroke(plate, Ui.INK, 3)
	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new(Color3.fromRGB(62, 56, 82), Ui.PANEL)
	sheen.Rotation = 90
	sheen.Parent = plate

	local fill = Instance.new("Frame")
	fill.Name = "Hold"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = HOLD_FILL
	fill.BackgroundTransparency = 0.25
	fill.BorderSizePixel = 0
	fill.Parent = plate
	Ui.corner(fill, UDim.new(0.5, 0))

	local chip = Instance.new("Frame")
	chip.Name = "Key"
	chip.AnchorPoint = Vector2.new(0, 0.5)
	chip.Position = UDim2.new(0, 5, 0.5, 0)
	chip.Size = UDim2.fromOffset(PLATE - 10, PLATE - 10)
	chip.BackgroundColor3 = GOLD
	chip.BorderSizePixel = 0
	chip.ZIndex = 2
	chip.Parent = plate
	Ui.corner(chip, UDim.new(0.5, 0))
	Ui.stroke(chip, Ui.INK, 2)
	Ui.sheen(chip, GOLD)
	local key = Ui.label(chip, keyText(prompt, inputType))
	if inputType == Enum.ProximityPromptInputType.Touch then
		key.Font = Enum.Font.FredokaOne
	end

	-- Luckiest Guy's lower case is a set of small capitals that sit at odd heights ("PeDAL!"), so
	-- the action is always set in capitals.
	local action = Ui.label(plate, string.upper(prompt.ActionText))
	action.Position = UDim2.fromOffset(PLATE, 0)
	action.Size = UDim2.new(1, -PLATE - 8, 1, 0)
	action.TextXAlignment = Enum.TextXAlignment.Left

	local function holdTo(fraction: number, seconds: number)
		TweenService:Create(fill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(fraction, 1),
		}):Play()
	end
	if prompt.HoldDuration > 0 then
		table.insert(
			connections,
			prompt.PromptButtonHoldBegan:Connect(function()
				holdTo(1, prompt.HoldDuration)
			end)
		)
		table.insert(
			connections,
			prompt.PromptButtonHoldEnded:Connect(function()
				holdTo(0, 0.15)
			end)
		)
	end
	table.insert(
		connections,
		prompt.Triggered:Connect(function()
			scale.Scale = 1.15
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end)
	)

	if prompt.ClickablePrompt then
		table.insert(
			connections,
			plate.InputBegan:Connect(function(input)
				local kind = input.UserInputType
				if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
					if input.UserInputState ~= Enum.UserInputState.Change then
						prompt:InputHoldBegin()
					end
				end
			end)
		)
		table.insert(
			connections,
			plate.InputEnded:Connect(function(input)
				local kind = input.UserInputType
				if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
					prompt:InputHoldEnd()
				end
			end)
		)
	end

	-- Pops up from the object it belongs to.
	scale.Scale = 0.5
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	board.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	return function()
		for _, c in connections do
			c:Disconnect()
		end
		board:Destroy()
	end
end

local function claim(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		instance.Style = Enum.ProximityPromptStyle.Custom
	end
end

function Prompts.start()
	workspace.DescendantAdded:Connect(claim)
	for _, d in workspace:GetDescendants() do
		claim(d)
	end
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local takeDown = show(prompt, inputType)
		prompt.PromptHidden:Wait()
		takeDown()
	end)
end

return Prompts
