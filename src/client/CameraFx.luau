-- Zoomies feedback (spec §9): the field of view widens as you get faster.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local CameraFx = {}

function CameraFx.start()
	local player = Players.LocalPlayer
	local cam = Config.Camera
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (camera and humanoid) then
			return
		end
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local extra = if moving
			then math.clamp((humanoid.WalkSpeed - Config.Speed.base) * cam.fovPerSpeed, 0, cam.maxExtraFov)
			else 0
		local target = cam.baseFov + extra
		camera.FieldOfView += (target - camera.FieldOfView) * math.min(dt * 4, 1)
	end)
end

return CameraFx
