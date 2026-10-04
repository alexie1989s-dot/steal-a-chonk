-- Thins Chonk name tags so two plates never sit on top of each other. When Chonks line up behind
-- one another from the camera's angle -- a Vault shelf seen from the door, a porch pad in front of
-- the shelf -- the nearest tag stays and the ones it would cover fade out until they have a clear
-- spot again. The rule itself is pure and tested (Shared.Declutter); this projects the tags and
-- does the fading.
--
-- Client-only and cosmetic: the server creates every NameTag and never toggles one, so the
-- Enabled and transparency changes made here are local and never fought over.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Declutter = require(ReplicatedStorage.Shared.Declutter)

local NameTags = {}

local TAG_NAME = "NameTag" -- Models.nameLabel
local REFRESH = 0.1 -- seconds between layout passes; the fade runs every frame
local MARGIN = 6 -- pixels of hysteresis, see Declutter
local FADE = 0.15 -- seconds for a full fade in or out
local RANGE_FADE = 0.2 -- the last fifth of a tag's range fades it out instead of cutting it off

-- One fadeable property of one instance in a tag, and its resting value.
type Fader = { instance: Instance, property: string, base: number }

type Entry = {
	gui: BillboardGui,
	alpha: number,
	target: number,
	faders: { Fader }?,
}

local entries: { [BillboardGui]: Entry } = {}

local function watch(instance: Instance)
	if instance.Name == TAG_NAME and instance:IsA("BillboardGui") and not entries[instance] then
		-- Starts hidden and fades in once the first pass finds it a clear spot, so a Chonk placed
		-- in front of another never flashes two tags on top of each other.
		entries[instance] = { gui = instance, alpha = 0, target = 0, faders = nil }
		instance.Enabled = false
	end
end

-- Every transparency in the tag (plate, rim, text and text outlines) is read the first time the tag
-- is seen, before anything here has written to it, and scaled from its resting value after that.
local function collect(gui: BillboardGui): { Fader }
	local faders: { Fader } = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiObject") then
			table.insert(faders, { instance = d, property = "BackgroundTransparency", base = d.BackgroundTransparency })
			if d:IsA("TextLabel") then
				table.insert(faders, { instance = d, property = "TextTransparency", base = d.TextTransparency })
			end
		elseif d:IsA("UIStroke") then
			table.insert(faders, { instance = d, property = "Transparency", base = d.Transparency })
		end
	end
	return faders
end

local function apply(entry: Entry)
	local gui = entry.gui
	gui.Enabled = entry.alpha > 0
	if not entry.faders then
		if #gui:GetChildren() == 0 then
			return -- not replicated yet
		end
		entry.faders = collect(gui)
	end
	local a = entry.alpha
	for _, f in entry.faders :: { Fader } do
		(f.instance :: any)[f.property] = 1 - a * (1 - f.base)
	end
end

-- Screen pixels per stud at a given depth, for a billboard sized partly in studs.
local function pixelsPerStud(camera: Camera, depth: number): number
	return camera.ViewportSize.Y / (2 * depth * math.tan(math.rad(camera.FieldOfView) / 2))
end

local function layout(camera: Camera)
	local eye = camera.CFrame
	local plates: { Declutter.Plate } = {}
	local fades: { [BillboardGui]: number } = {}
	for gui, entry in entries do
		if not gui:IsDescendantOf(workspace) then
			entries[gui] = nil
			continue
		end
		local part = gui.Adornee or gui.Parent
		if not (part and part:IsA("BasePart")) then
			continue
		end
		-- StudsOffset is in camera space; StudsOffsetWorldSpace is not.
		local at = part.Position + eye:VectorToWorldSpace(gui.StudsOffset) + gui.StudsOffsetWorldSpace
		local point = camera:WorldToViewportPoint(at)
		local distance = (part.Position - eye.Position).Magnitude
		if point.Z <= 0 or distance > gui.MaxDistance then
			-- Out of range or behind the camera: Roblox would not draw it anyway. Dropped at once
			-- rather than faded, so it comes back through the clear-spot check like a new tag.
			if entry.alpha > 0 or entry.target > 0 then
				entry.target, entry.alpha = 0, 0
				apply(entry)
			end
			continue
		end
		local perStud = pixelsPerStud(camera, point.Z)
		local w = gui.Size.X.Offset + gui.Size.X.Scale * perStud
		local h = gui.Size.Y.Offset + gui.Size.Y.Scale * perStud
		table.insert(plates, {
			key = gui,
			-- SizeOffset slides the plate off its anchor by a fraction of its size (up is +Y).
			x = point.X + gui.SizeOffset.X * w,
			y = point.Y - gui.SizeOffset.Y * h,
			w = w,
			h = h,
			depth = point.Z,
			shown = entry.target > 0,
		})
		fades[gui] = math.clamp((gui.MaxDistance - distance) / (gui.MaxDistance * RANGE_FADE), 0, 1)
	end
	for gui, show in Declutter.choose(plates, MARGIN) do
		entries[gui].target = if show then fades[gui] or 1 else 0
	end
end

function NameTags.start()
	for _, descendant in workspace:GetDescendants() do
		watch(descendant)
	end
	workspace.DescendantAdded:Connect(watch)

	local sinceLayout = REFRESH
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		sinceLayout += dt
		if sinceLayout >= REFRESH then
			sinceLayout = 0
			layout(camera)
		end
		local step = dt / FADE
		for _, entry in entries do
			if entry.alpha ~= entry.target then
				if entry.target > entry.alpha then
					entry.alpha = math.min(entry.alpha + step, entry.target)
				else
					entry.alpha = math.max(entry.alpha - step, entry.target)
				end
				apply(entry)
			end
		end
	end)
end

return NameTags
