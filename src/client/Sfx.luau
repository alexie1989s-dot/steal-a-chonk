-- Plays the game's sounds (Sounds catalogue) on this client, and owns the mute switch.
--
-- Interface sounds are 2D one-shots. World sounds the server places (the porch alarm) carry an `Sfx`
-- attribute and are moved into the same SoundGroup, so muting silences those too.
local ContentProvider = game:GetService("ContentProvider")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local Sfx = {}

local group: SoundGroup
local templates: { [string]: Sound } = {}
local muted = false

function Sfx.play(key: string, pitch: number?)
	local template = templates[key]
	if not template then
		return
	end
	-- A fresh copy per play, so two quick toasts overlap instead of cutting each other off.
	local sound = template:Clone()
	if pitch then
		sound.PlaybackSpeed = pitch
	end
	sound.Parent = group
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

function Sfx.isMuted(): boolean
	return muted
end

function Sfx.setMuted(value: boolean)
	muted = value
	group.Volume = if value then 0 else 1
end

local function adopt(instance: Instance)
	if instance:IsA("Sound") and instance:GetAttribute("Sfx") then
		instance.SoundGroup = group
	end
end

function Sfx.start()
	group = Instance.new("SoundGroup")
	group.Name = "Sfx"
	group.Parent = SoundService

	local folder = Instance.new("Folder")
	folder.Name = "SfxTemplates"
	folder.Parent = SoundService
	for key, entry in Sounds.Catalog do
		local sound = Instance.new("Sound")
		sound.Name = key
		sound.SoundId = Sounds.uri(key)
		sound.Volume = entry.volume
		sound.SoundGroup = group
		sound.Parent = folder
		templates[key] = sound
	end
	-- Fetch them all up front, off the main thread, so the first click is not silent.
	task.spawn(function()
		ContentProvider:PreloadAsync(folder:GetChildren())
	end)

	Remotes.get("Sfx").OnClientEvent:Connect(Sfx.play)

	-- Every prompt this player presses answers with a tick at once; the outcome sound follows from
	-- the server when it decides.
	ProximityPromptService.PromptTriggered:Connect(function()
		Sfx.play("tick")
	end)

	workspace.DescendantAdded:Connect(adopt)
	for _, d in workspace:GetDescendants() do
		adopt(d)
	end
end

return Sfx
