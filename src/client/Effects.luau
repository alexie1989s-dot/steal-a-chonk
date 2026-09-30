-- Client-side reactions to server events: knockback (the client owns its character's physics)
-- and the curb-crossing confetti pop (spec §6).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Effects = {}

local CONFETTI = {
	Color3.fromRGB(255, 214, 64),
	Color3.fromRGB(255, 120, 100),
	Color3.fromRGB(110, 205, 255),
	Color3.fromRGB(150, 230, 120),
}

local function rootPart(): BasePart?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Effects.start()
	Remotes.get("Knockback").OnClientEvent:Connect(function(dirX: number, dirZ: number)
		local root = rootPart()
		if not root then
			return
		end
		local c = Config.Carry
		root.AssemblyLinearVelocity = Vector3.new(dirX * c.knockbackSpeed, c.knockbackLift, dirZ * c.knockbackSpeed)
	end)

	Remotes.get("Celebrate").OnClientEvent:Connect(function()
		local root = rootPart()
		if not root then
			return
		end
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(0, 2, 0)
		attachment.Parent = root
		for _, color in CONFETTI do
			local emitter = Instance.new("ParticleEmitter")
			emitter.Color = ColorSequence.new(color)
			emitter.Size = NumberSequence.new(0.35)
			emitter.Lifetime = NumberRange.new(1, 1.6)
			emitter.Speed = NumberRange.new(14, 24)
			emitter.SpreadAngle = Vector2.new(60, 60)
			emitter.Acceleration = Vector3.new(0, -30, 0)
			emitter.Rate = 0
			emitter.Parent = attachment
			emitter:Emit(12)
		end
		task.delay(2.5, function()
			attachment:Destroy()
		end)
	end)
end

return Effects
