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

type Entry = {
	gui: BillboardGui,
	alpha: number,
	target: number,
	label: TextLabel?,
	stroke: UIStroke?,
	baseBackground: number,
	baseStroke: number,
}

local entries: { [BillboardGui]: Entry } = {}

local function watch(instance: Instance)
	if instance.Name == TAG_NAME and instance:IsA("BillboardGui") and not entries[instance] then
		-- Starts hidden and fades in once the first pass finds it a clear spot, so a Chonk placed
		-- in front of another never flashes two tags on top of each other.
		entries[instance] =
			{ gui = instance, alpha = 0, target = 0, label = nil, stroke = nil, baseBackground = 0, baseStroke = 0 }
		instance.Enabled = false
	end
end

-- The plate is the TextLabel that Models.pill styles. Its resting transparencies are read the
-- first time it is seen, before anything here has written to it.
local function apply(entry: Entry)
	local gui = entry.gui
	gui.Enabled = entry.alpha > 0
	if not entry.label then
		local label = gui:FindFirstChildOfClass("TextLabel")
		if not label then
			return
		end
		entry.label = label
		entry.baseBackground = label.BackgroundTransparency
		local stroke = label:FindFirstChildOfClass("UIStroke")
		entry.stroke = stroke
		entry.baseStroke = if stroke then stroke.Transparency else 0
	end
	local a = entry.alpha
	local label = entry.label :: TextLabel
	label.TextTransparency = 1 - a
	label.BackgroundTransparency = 1 - a * (1 - entry.baseBackground)
	if entry.stroke then
		entry.stroke.Transparency = 1 - a * (1 - entry.baseStroke)
	end
end

-- Screen pixels per stud at a given depth, for a billboard sized partly in studs.
local function pixelsPerStud(camera: Camera, depth: number): number
	return camera.ViewportSize.Y / (2 * depth * math.tan(math.rad(camera.FieldOfView) / 2))
end

local function layout(camera: Camera)
	local eye = camera.CFrame
	local plates: { Declutter.Plate } = {}
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
		if point.Z <= 0 or (part.Position - eye.Position).Magnitude > gui.MaxDistance then
			-- Out of range or behind the camera: Roblox would not draw it anyway. Dropped at once
			-- rather than faded, so it comes back through the clear-spot check like a new tag.
			if entry.alpha > 0 or entry.target > 0 then
				entry.target, entry.alpha = 0, 0
				apply(entry)
			end
			continue
		end
		local perStud = pixelsPerStud(camera, point.Z)
		table.insert(plates, {
			key = gui,
			x = point.X,
			y = point.Y,
			w = gui.Size.X.Offset + gui.Size.X.Scale * perStud,
			h = gui.Size.Y.Offset + gui.Size.Y.Scale * perStud,
			depth = point.Z,
			shown = entry.target > 0,
		})
	end
	for gui, show in Declutter.choose(plates, MARGIN) do
		entries[gui].target = if show then 1 else 0
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
