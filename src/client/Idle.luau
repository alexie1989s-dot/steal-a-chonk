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

type Tracked = { base: CFrame, phase: number, moved: boolean }

local tracked: { [Model]: Tracked } = {}

local function track(model: Instance)
	if not model:IsA("Model") then
		return
	end
	if not model.PrimaryPart then
		-- The tag replicates before PrimaryPart does, so at this moment most Vault displays have
		-- no PrimaryPart yet. Bailing here silently dropped them and the bob never ran on them;
		-- wait for the property to land instead.
		local conn
		conn = model:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
			conn:Disconnect()
			if model.PrimaryPart and CollectionService:HasTag(model, Idle.TAG) then
				track(model)
			end
		end)
		return
	end
	local base = model:GetPivot()
	-- Phase from the resting position, so neighbouring Chonks are not all in lockstep.
	local p = base.Position
	tracked[model] = { base = base, phase = (p.X * 0.7 + p.Z * 1.3) % (math.pi * 2), moved = false }
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

	-- Only the Chonks near the camera are animated. Everything else is left at its resting pose,
	-- which is what the server believes anyway, so nothing drifts.
	local range = Config.Idle.maxDistance
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		for model, entry in tracked do
			if not (model.Parent and model.PrimaryPart) then
				tracked[model] = nil
				continue
			end
			if (entry.base.Position - eye).Magnitude > range then
				-- Put it back once on the way out, so nothing is left frozen mid-bob.
				if entry.moved then
					entry.moved = false
					model:PivotTo(entry.base)
				end
				continue
			end
			local lift = math.sin(now * BOB_RATE + entry.phase) * BOB
			local turn = math.sin(now * SWAY_RATE + entry.phase) * SWAY
			model:PivotTo(entry.base * CFrame.new(0, lift, 0) * CFrame.Angles(0, turn, 0))
			entry.moved = true
		end
	end)
end

return Idle
