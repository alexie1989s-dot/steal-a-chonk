-- Licensed scenery: meshes from the Synty packs Roblox publishes for use in any game (Config.Props).
--
-- The packs are loaded once at boot and kept out of the world as a library. Callers ask for a mesh
-- by name; when a pack failed to load, `place` returns nil and the caller builds its part version,
-- so the game never depends on a download succeeding.
--
-- Everything placed is scenery: anchored, never collides, never touched, invisible to raycasts.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Props = {}

local library: { [string]: Instance } = {}

-- Pack children are named "Meshes/<name>"; the prefix is dropped. Meshes that carry a
-- SurfaceAppearance are left out: in these packs those are older leaf-card assets whose texture packs
-- fail to parse ("Failed to parse TexturePack"), one warning per copy.
local function index(pack: Instance, into: Folder)
	for _, child in pack:GetChildren() do
		if child:FindFirstChildWhichIsA("SurfaceAppearance", true) then
			child:Destroy()
			continue
		end
		local name = string.gsub(child.Name, "^Meshes/", "")
		name = string.gsub(name, "%s+$", "")
		child.Name = name
		library[name] = child
		child.Parent = into
	end
end

-- Loads every pack in parallel, waiting at most Config.Props.loadTimeout seconds in all.
function Props.load()
	local folder = Instance.new("Folder")
	folder.Name = "PropLibrary"
	folder.Parent = ServerStorage
	local pending = 0
	for packName, assetId in Config.Props.packs do
		pending += 1
		task.spawn(function()
			local ok, result = pcall(InsertService.LoadAsset, InsertService, assetId)
			if ok then
				-- The packs ship without scripts; anything executable that ever appears is dropped.
				for _, d in result:GetDescendants() do
					if d:IsA("LuaSourceContainer") then
						d:Destroy()
					end
				end
				index(result, folder)
				result:Destroy()
			else
				warn(`[Props] {packName} pack {assetId} did not load; using part scenery. {result}`)
			end
			pending -= 1
		end)
	end
	local deadline = os.clock() + Config.Props.loadTimeout
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	if pending > 0 then
		warn(`[Props] {pending} pack(s) still loading after {Config.Props.loadTimeout}s; using part scenery for them.`)
	end
end

function Props.has(name: string): boolean
	return library[name] ~= nil
end

local function settle(part: BasePart, castShadow: boolean)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = castShadow
end

export type Options = { height: number?, scale: number?, castShadow: boolean? }

-- Places a copy of a library mesh with its base centred on `at` (yaw and all). `height` sets the
-- size outright; `scale` multiplies the mesh's own size. Returns nil if the mesh is not loaded.
function Props.place(name: string, at: CFrame, parent: Instance, options: Options?): Instance?
	local source = library[name]
	if not source then
		return nil
	end
	local opts: Options = options or {}
	local castShadow = if opts.castShadow == nil then true else opts.castShadow
	local copy = source:Clone()
	if copy:IsA("BasePart") then
		local factor = opts.scale or 1
		if opts.height then
			factor = opts.height / copy.Size.Y
		end
		copy.Size *= factor
		copy.CFrame = at * CFrame.new(0, copy.Size.Y / 2, 0)
		settle(copy, castShadow)
	elseif copy:IsA("Model") then
		local _, size = copy:GetBoundingBox()
		local factor = opts.scale or 1
		if opts.height then
			factor = opts.height / size.Y
		end
		copy:ScaleTo(copy:GetScale() * factor)
		local box, scaled = copy:GetBoundingBox()
		local offset = box:ToObjectSpace(copy:GetPivot())
		copy:PivotTo(at * CFrame.new(0, scaled.Y / 2, 0) * offset)
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				settle(d, castShadow)
			end
		end
	end
	copy.Parent = parent
	return copy
end

return Props
