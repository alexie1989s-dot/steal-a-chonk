-- Greybox model builders. Placeholder art only (no accepted Chonk art exists yet).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)

local Models = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end
Models.rgb = rgb

-- Anchored, smooth part with the given properties; Parent is applied last.
function Models.part(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- A rolled blanket whose glow hints at the tier and whose size hints at the Chonk's size (spec §7).
function Models.burrito(tier: string, size: number): Model
	local scale = Formulas.sizeScale(size)
	local model = Instance.new("Model")
	model.Name = "Burrito"
	local body = Models.part({
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3.2, 2.2, 2.2) * scale,
		Color = Color3.fromRGB(235, 225, 205),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = model,
	})
	local band = Models.part({
		Name = "Band",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 2.3, 2.3) * scale,
		Color = rgb(Config.TierColors[tier]),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	band.CFrame = body.CFrame
	-- Keeps the band on the body once Carry unanchors the model.
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = band
	weld.Parent = body
	local light = Instance.new("PointLight")
	light.Color = rgb(Config.TierColors[tier])
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = body
	model.PrimaryPart = body
	return model
end

-- A round Chonk: body sphere, two ears, two eyes, tinted by the catalog colour.
function Models.chonk(entry: { color: { number } }, size: number): Model
	local scale = Formulas.sizeScale(size)
	local d = 4 * scale
	local model = Instance.new("Model")
	model.Name = "Chonk"
	local body = Models.part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * d,
		Color = rgb(entry.color),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	model.PrimaryPart = body
	for _, side in { -1, 1 } do
		local ear = Models.part({
			Name = "Ear",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * d * 0.32,
			Color = rgb(entry.color),
			CanCollide = false,
			Parent = model,
		})
		ear.CFrame = body.CFrame * CFrame.new(side * d * 0.3, d * 0.42, 0)
		local eye = Models.part({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * d * 0.12,
			Color = Color3.fromRGB(25, 25, 30),
			CanCollide = false,
			Parent = model,
		})
		eye.CFrame = body.CFrame * CFrame.new(side * d * 0.17, d * 0.1, -d * 0.46)
	end
	return model
end

-- The Mama Chonk guardian. Body rolls; ears and eyes keep an upright offset (the "Offset" attribute)
-- that Guardians applies each frame relative to the unrolled frame.
function Models.mama(): Model
	local d = Config.Guardian.radius * 2
	local model = Instance.new("Model")
	model.Name = "MamaChonk"
	local body = Models.part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * d,
		Color = Color3.fromRGB(214, 170, 150),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = model,
	})
	model.PrimaryPart = body
	local stripe = Models.part({
		Name = "Stripe",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, d * 1.02, d * 1.02),
		Color = Color3.fromRGB(180, 120, 110),
		CanCollide = false,
		Parent = model,
	})
	stripe:SetAttribute("Rolls", true)
	local function deco(name: string, sizeFactor: number, color: Color3, offset: CFrame)
		local part = Models.part({
			Name = name,
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * d * sizeFactor,
			Color = color,
			CanCollide = false,
			Parent = model,
		})
		part:SetAttribute("Offset", offset)
	end
	for _, side in { -1, 1 } do
		deco("Ear", 0.3, Color3.fromRGB(214, 170, 150), CFrame.new(side * d * 0.3, d * 0.45, 0))
		deco("Eye", 0.11, Color3.fromRGB(25, 25, 30), CFrame.new(side * d * 0.16, d * 0.12, -d * 0.47))
	end
	return model
end

return Models
