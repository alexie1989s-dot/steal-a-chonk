-- Gives Chonks that are standing still a slow breathing bob and sway, so a Vault shelf or a
-- porch pad looks alive rather than like a row of props.
--
-- The motion is client-only. Displayed Chonks are anchored and the server never moves them, so
-- a local pivot is never fought over or replicated; it is decoration, not state. Anything the
-- server does move is untagged first (see Carry.setStatus), because a model welded to a
-- carrier must not also be pinned to a remembered pose.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Idle = {}

Idle.TAG = Config.Tags.chonkIdle

local BOB = 0.19 -- studs, peak to centre
local SWAY = 0.09 -- radians
local BOB_RATE = 1.7
local SWAY_RATE = 0.8

type Tracked = { base: CFrame, phase: number }

local tracked: { [Model]: Tracked } = {}

local function track(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local primary = model.PrimaryPart
	if not primary then
		return
	end
	local base = model:GetPivot()
	-- Phase from the resting position, so neighbouring Chonks are not all in lockstep.
	local p = base.Position
	tracked[model] = { base = base, phase = (p.X * 0.7 + p.Z * 1.3) % (math.pi * 2) }
end

function Idle.start()
	for _, model in CollectionService:GetTagged(Idle.TAG) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal(Idle.TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(Idle.TAG):Connect(function(model)
		local entry = tracked[model :: Model]
		if entry and model:IsA("Model") and model.PrimaryPart then
			-- Put it back where the server thinks it is before letting go of it.
			model:PivotTo(entry.base)
		end
		tracked[model :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for model, entry in tracked do
			if model.Parent and model.PrimaryPart then
				local lift = math.sin(now * BOB_RATE + entry.phase) * BOB
				local turn = math.sin(now * SWAY_RATE + entry.phase) * SWAY
				model:PivotTo(entry.base * CFrame.new(0, lift, 0) * CFrame.Angles(0, turn, 0))
			else
				tracked[model] = nil
			end
		end
	end)
end

return Idle
