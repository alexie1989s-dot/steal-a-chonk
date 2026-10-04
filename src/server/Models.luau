-- Greybox model builders, part-crafted from Studio primitives. Placeholder art only
-- (no accepted Chonk art exists yet, and the art track is paused: spec §23, AGENTS.md).
--
-- Chonk geometry contract, relied on by Vault, Showcase and DummyBase:
--   * PrimaryPart is "Body", so the model pivot is the body centre.
--   * The body's Y extent is exactly `d = 4 * Formulas.sizeScale(size)`, so a caller can
--     rest a Chonk on a pad with `pad.Y + d / 2` and hang a name tag at `d / 2 + 1.5`.
--   * Nothing dips below `-d / 2`; ears and frills may rise above it.
--   * -Z is the face. Plots orient a plot frame with its LookVector pointing outward, so a
--     Chonk placed with that rotation looks out over the curb at whoever is coming for it.
-- Every decoration is CanCollide false and welded to the body, so a model survives Carry
-- unanchoring it. The body is CanCollide false too: a seated Chonk must never block a player on
-- their own porch, and Carry turns collision off anyway when it lifts one, so leaving it on made a
-- fresh Chonk solid and a once-carried one not.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)

local Models = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local EYE = Color3.fromRGB(28, 26, 34)
local BLUSH = Color3.fromRGB(255, 150, 160)

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end
Models.rgb = rgb

-- Lightens towards white for f > 0, darkens towards black for f < 0.
local function shade(color: Color3, f: number): Color3
	return color:Lerp(if f >= 0 then WHITE else BLACK, math.abs(f))
end
Models.shade = shade

-- Anchored, smooth part with the given properties; Parent is applied last.
-- `ClassName` picks the instance type (default "Part"), for WedgePart and friends.
function Models.part(props: { [string]: any }): BasePart
	local part = Instance.new(props.ClassName or "Part") :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	for key, value in props do
		-- Shape only exists on Part, so a shared builder can still pass it for a WedgePart.
		if key == "Parent" or key == "ClassName" or (key == "Shape" and not part:IsA("Part")) then
			continue
		end
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function weldTo(body: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = body
end
Models.weldTo = weldTo

-- ---------------------------------------------------------------------------
-- Chonk construction
-- ---------------------------------------------------------------------------

-- A build context. Offsets and sizes are given in fractions of the body's half extents,
-- so a feature stays on the surface whatever the species' body proportions are.
type Chonk = {
	model: Model,
	body: BasePart,
	d: number,
	half: Vector3,
	color: Color3,
	-- name, size (fractions of d), offset (fractions of the half extents), colour, extra props
	piece: (string, Vector3, Vector3, Color3, { [string]: any }?) -> BasePart,
}

local function newChonk(color: Color3, d: number, wide: number, deep: number): Chonk
	local model = Instance.new("Model")
	model.Name = "Chonk"
	local size = Vector3.new(d * wide, d, d * deep)
	local body = Models.part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = size,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = model,
	})
	model.PrimaryPart = body
	local half = size / 2

	local self: Chonk
	self = {
		model = model,
		body = body,
		d = d,
		half = half,
		color = color,
		piece = function(name, pieceSize, offset, pieceColor, props): BasePart
			local part = Models.part({
				ClassName = (props and props.ClassName) or "Part",
				Name = name,
				Shape = (props and props.Shape) or Enum.PartType.Ball,
				Size = pieceSize * d,
				Color = pieceColor,
				Material = (props and props.Material) or Enum.Material.SmoothPlastic,
				Transparency = (props and props.Transparency) or 0,
				CanCollide = false,
				CanQuery = false,
				Parent = model,
			})
			local rotation = props and props.Rotation
			part.CFrame = body.CFrame
				* CFrame.new(offset.X * half.X, offset.Y * half.Y, offset.Z * half.Z)
				* (rotation or CFrame.identity)
			weldTo(body, part)
			return part
		end,
	}
	return self
end

-- Two eyes with a catchlight each, the single strongest readability cue on a round face.
-- `scale` grows the whole eye, `spread` moves the pair apart, `lift` raises them.
local function eyes(c: Chonk, scale: number, spread: number, lift: number)
	for _, side in { -1, 1 } do
		local eye = c.piece("Eye", Vector3.one * 0.13 * scale, Vector3.new(side * spread, lift, -0.93), EYE)
		local shine = c.piece("EyeShine", Vector3.one * 0.045 * scale, Vector3.zero, WHITE)
		shine.CFrame = eye.CFrame * CFrame.new(-side * 0.035 * c.d * scale, 0.04 * c.d * scale, -0.05 * c.d * scale)
		weldTo(c.body, shine)
	end
end

-- Soft cheek blush. Cheap, and it does a lot of the "affectionate" work in spec §1.
local function blush(c: Chonk, spread: number, lift: number)
	for _, side in { -1, 1 } do
		c.piece("Blush", Vector3.new(0.17, 0.10, 0.07), Vector3.new(side * spread, lift, -0.82), BLUSH, {
			Transparency = 0.35,
		})
	end
end

-- A lighter chest patch, as a wide shallow lens rather than an oval stuck on the front.
-- Working in half-extent units, where the body is the unit sphere: a lens sphere of radius r
-- whose centre sits `a` from the origin stands `a + r - 1` proud, and covers a patch of angular
-- radius `acos((1 + a^2 - r^2) / 2a)`. Holding `a + r` just over 1 and making r large gives a
-- broad patch that only just breaks the surface, so it looks painted on instead of bolted on.
-- `lift` aims the patch: negative for a low belly, near 0 for a chest panel.
local function belly(c: Chonk, scale: number, lift: number, color: Color3?)
	local r = math.min(0.80 * scale, 0.95)
	local a = math.max(1.09 - r, 0.10)
	local dir = Vector3.new(0, lift, -1).Unit * a
	c.piece("Belly", Vector3.new(r, r * 0.92, r), dir, color or shade(c.color, 0.45))
end

-- A rounded muzzle with a nose and a hint of a mouth.
local function muzzle(c: Chonk, size: number, drop: number, noseColor: Color3?, color: Color3?)
	c.piece("Muzzle", Vector3.new(0.30, 0.22, 0.20) * size, Vector3.new(0, drop, -0.88), color or shade(c.color, 0.5))
	c.piece("Nose", Vector3.new(0.10, 0.08, 0.08) * size, Vector3.new(0, drop + 0.06, -1.02), noseColor or EYE)
	c.piece("Mouth", Vector3.new(0.14, 0.05, 0.04) * size, Vector3.new(0, drop - 0.10, -1.0), shade(c.color, -0.55))
end

-- Little feet that peek out at the front. Kept above -d/2 so a Chonk still sits flush on a pad.
local function feet(c: Chonk, size: number, spread: number, color: Color3?)
	for _, side in { -1, 1 } do
		c.piece(
			"Foot",
			Vector3.new(0.15, 0.09, 0.19) * size,
			Vector3.new(side * spread, -0.72, -0.52),
			color or shade(c.color, -0.2)
		)
	end
end

local function roundEars(c: Chonk, size: number, spread: number, inner: Color3?, color: Color3?)
	for _, side in { -1, 1 } do
		c.piece("Ear", Vector3.one * 0.30 * size, Vector3.new(side * spread, 0.78, 0.02), color or c.color)
		c.piece("EarInner", Vector3.one * 0.16 * size, Vector3.new(side * spread, 0.80, -0.20), inner or BLUSH)
	end
end

-- Pointed ears, built as a short stack of shrinking spheres leaning up and out. Flat shapes
-- were tried first and both failed: a WedgePart vanishes edge-on, and a square turned 45
-- degrees still reads as a square once the head stops hiding its lower corner. A taper of
-- spheres has no bad angle, and the lowest sphere sinks into the skull so the ear joins on.
local function pointedEars(c: Chonk, size: number, spread: number, lean: number, inner: Color3?, color: Color3?)
	for _, side in { -1, 1 } do
		local dir = Vector3.new(side * (0.30 + lean), 0.95, 0).Unit
		-- Four spheres, each stepping less than the sum of neighbouring radii, so they fuse into
		-- one taper instead of reading as a row of beads.
		for i = 1, 4 do
			local step = (i - 1) * 0.22 * size
			c.piece(
				"Ear",
				Vector3.one * (0.27 - (i - 1) * 0.055) * size,
				Vector3.new(side * spread + dir.X * step, 0.44 + dir.Y * step, 0.02),
				color or c.color
			)
		end
		c.piece(
			"EarInner",
			Vector3.one * 0.12 * size,
			Vector3.new(side * spread + dir.X * 0.26 * size, 0.44 + dir.Y * 0.26 * size, -0.15),
			inner or BLUSH
		)
	end
end

-- A tapering beak, same trick as the ears: flat plates read as cards stuck to the face.
local function beak(c: Chonk, size: number, lift: number, color: Color3)
	for i = 1, 3 do
		c.piece(
			"Beak",
			Vector3.one * (0.20 - (i - 1) * 0.05) * size,
			Vector3.new(0, lift - (i - 1) * 0.05, -0.86 - (i - 1) * 0.20),
			color
		)
	end
end

local function whiskers(c: Chonk, count: number, color: Color3?)
	for _, side in { -1, 1 } do
		for i = 1, count do
			local angle = (i - (count + 1) / 2) * 0.22
			c.piece(
				"Whisker",
				Vector3.new(0.34, 0.015, 0.015),
				Vector3.new(side * 0.28, -0.02, -0.86),
				color or WHITE,
				{
					Shape = Enum.PartType.Cylinder,
					Rotation = CFrame.Angles(0, 0, angle) * CFrame.new(side * 0.16 * c.d, 0, 0),
				}
			)
		end
	end
end

local function tailNub(c: Chonk, size: number, color: Color3?)
	c.piece("Tail", Vector3.one * size, Vector3.new(0, -0.22, 0.96), color or shade(c.color, 0.15))
end

-- Per-species silhouettes. Each gets the same round base, then the two or three cues that
-- make it read as that animal at a glance on a phone screen.
-- `wide` must stay at or under Config.WidestBodyProfile: the Vault pad spacing is checked against
-- it, and a wider Chonk would overlap its neighbour on the display.
local SPECIES: { [string]: { wide: number, deep: number, build: (Chonk) -> () } } = {
	Cat = {
		wide = 1.06,
		deep = 1.0,
		build = function(c)
			pointedEars(c, 1, 0.42, 0.28)
			eyes(c, 1, 0.36, 0.16)
			muzzle(c, 1, -0.06, Color3.fromRGB(240, 140, 150))
			blush(c, 0.62, -0.08)
			whiskers(c, 3)
			belly(c, 1.0, -0.42)
			feet(c, 1, 0.34)
			-- A curl of tail, three beads following the flank round to the back.
			for i = 1, 3 do
				c.piece(
					"Tail",
					Vector3.one * (0.19 - i * 0.02),
					Vector3.new(0.35 + i * 0.16, -0.30 + i * 0.16, 0.86),
					shade(c.color, -0.12)
				)
			end
		end,
	},
	Hamster = {
		wide = 1.12,
		deep = 0.98,
		build = function(c)
			roundEars(c, 0.8, 0.40)
			eyes(c, 0.9, 0.32, 0.18)
			muzzle(c, 0.85, -0.10, Color3.fromRGB(230, 130, 140))
			-- The sandwich in the cheeks (Gary's bio): oversized pouches either side of the face.
			for _, side in { -1, 1 } do
				c.piece("Cheek", Vector3.new(0.34, 0.30, 0.28), Vector3.new(side * 0.62, -0.20, -0.62), c.color)
			end
			blush(c, 0.70, -0.30)
			whiskers(c, 2)
			belly(c, 0.95, -0.44, shade(c.color, 0.5))
			feet(c, 0.85, 0.30)
			tailNub(c, 0.11)
		end,
	},
	Frog = {
		wide = 1.24,
		deep = 0.94,
		build = function(c)
			-- Eyes ride on top of the head in two domes, the way a frog's do.
			for _, side in { -1, 1 } do
				c.piece("EyeDome", Vector3.one * 0.32, Vector3.new(side * 0.42, 0.74, -0.30), c.color)
				local eye = c.piece("Eye", Vector3.one * 0.19, Vector3.new(side * 0.44, 0.86, -0.40), EYE)
				local shine = c.piece("EyeShine", Vector3.one * 0.06, Vector3.zero, WHITE)
				shine.CFrame = eye.CFrame * CFrame.new(-side * 0.05 * c.d, 0.05 * c.d, -0.05 * c.d)
				weldTo(c.body, shine)
			end
			-- A wide grin instead of a muzzle.
			c.piece("Mouth", Vector3.new(0.62, 0.05, 0.05), Vector3.new(0, -0.18, -0.94), shade(c.color, -0.5), {
				Shape = Enum.PartType.Cylinder,
			})
			c.piece("Nostril", Vector3.new(0.05, 0.04, 0.04), Vector3.new(-0.16, 0.16, -0.98), shade(c.color, -0.45))
			c.piece("Nostril", Vector3.new(0.05, 0.04, 0.04), Vector3.new(0.16, 0.16, -0.98), shade(c.color, -0.45))
			blush(c, 0.70, -0.06)
			belly(c, 1.15, -0.40, Color3.fromRGB(226, 232, 180))
			-- Webbed feet, splayed wide.
			for _, side in { -1, 1 } do
				c.piece("Foot", Vector3.new(0.26, 0.08, 0.24), Vector3.new(side * 0.52, -0.70, -0.42), c.color)
			end
		end,
	},
	Pigeon = {
		wide = 1.0,
		deep = 1.06,
		build = function(c)
			eyes(c, 0.8, 0.40, 0.30)
			-- Beak: two small wedges meeting at a point.
			beak(c, 0.95, 0.10, Color3.fromRGB(240, 170, 90))
			-- The iridescent neck, a pigeon's one piece of glamour.
			c.piece("Collar", Vector3.new(1.10, 0.34, 1.10), Vector3.new(0, -0.14, -0.06), Color3.fromRGB(96, 150, 160))
			for _, side in { -1, 1 } do
				c.piece(
					"Wing",
					Vector3.new(0.14, 0.52, 0.62),
					Vector3.new(side * 0.86, -0.14, 0.08),
					shade(c.color, -0.2)
				)
				c.piece(
					"Foot",
					Vector3.new(0.10, 0.07, 0.20),
					Vector3.new(side * 0.26, -0.72, -0.50),
					Color3.fromRGB(226, 120, 110)
				)
			end
			c.piece("Crest", Vector3.one * 0.14, Vector3.new(0, 0.86, -0.10), shade(c.color, -0.25))
			c.piece("Tail", Vector3.new(0.40, 0.10, 0.44), Vector3.new(0, -0.34, 0.96), shade(c.color, -0.2))
		end,
	},
	Corgi = {
		wide = 1.04,
		deep = 1.12,
		build = function(c)
			pointedEars(c, 1.15, 0.44, 0.16, Color3.fromRGB(250, 205, 190))
			eyes(c, 1, 0.34, 0.16)
			muzzle(c, 1.15, -0.08, EYE, WHITE)
			blush(c, 0.64, -0.14)
			-- The white chest blaze a corgi wears.
			belly(c, 0.95, -0.34, Color3.fromRGB(250, 248, 244))
			-- "Loaf's legs are decorative": four stubs that plainly do not reach the ground.
			for _, side in { -1, 1 } do
				c.piece("Foot", Vector3.new(0.16, 0.12, 0.20), Vector3.new(side * 0.36, -0.70, -0.46), WHITE)
				c.piece("Foot", Vector3.new(0.16, 0.12, 0.20), Vector3.new(side * 0.36, -0.70, 0.42), WHITE)
			end
			c.piece("Tail", Vector3.one * 0.26, Vector3.new(0, -0.10, 0.94), shade(c.color, 0.35))
		end,
	},
	Penguin = {
		wide = 0.96,
		deep = 0.98,
		build = function(c)
			eyes(c, 0.95, 0.30, 0.30)
			-- The tuxedo: a big pale front panel, the bird's whole read at distance.
			belly(c, 1.15, -0.30, Color3.fromRGB(250, 248, 240))
			beak(c, 1.05, 0.12, Color3.fromRGB(246, 168, 70))
			blush(c, 0.58, 0.06)
			for _, side in { -1, 1 } do
				c.piece("Flipper", Vector3.new(0.13, 0.56, 0.30), Vector3.new(side * 0.92, -0.18, 0.0), c.color, {
					Rotation = CFrame.Angles(0, 0, side * 0.22),
				})
				c.piece(
					"Foot",
					Vector3.new(0.22, 0.08, 0.26),
					Vector3.new(side * 0.30, -0.72, -0.46),
					Color3.fromRGB(246, 168, 70)
				)
			end
		end,
	},
	Seal = {
		wide = 1.02,
		deep = 1.20,
		build = function(c)
			-- No ears, just the two dots where they would be.
			for _, side in { -1, 1 } do
				c.piece("EarDot", Vector3.one * 0.06, Vector3.new(side * 0.66, 0.50, -0.26), shade(c.color, -0.3))
			end
			eyes(c, 1.25, 0.34, 0.14)
			muzzle(c, 1.1, -0.12, EYE, shade(c.color, 0.35))
			blush(c, 0.62, -0.18)
			whiskers(c, 3, shade(c.color, 0.5))
			belly(c, 1.05, -0.40, Color3.fromRGB(240, 238, 232))
			-- Front flippers, and a fluke at the back: Pudding's applause equipment.
			for _, side in { -1, 1 } do
				c.piece(
					"Flipper",
					Vector3.new(0.30, 0.10, 0.34),
					Vector3.new(side * 0.74, -0.56, -0.36),
					shade(c.color, -0.1),
					{
						Rotation = CFrame.Angles(0, side * 0.5, 0),
					}
				)
				c.piece(
					"Fluke",
					Vector3.new(0.34, 0.09, 0.20),
					Vector3.new(side * 0.22, -0.34, 0.92),
					shade(c.color, -0.1),
					{
						Rotation = CFrame.Angles(0, -side * 0.6, 0),
					}
				)
			end
		end,
	},
	Capybara = {
		wide = 1.08,
		deep = 1.10,
		build = function(c)
			roundEars(c, 0.6, 0.52, shade(c.color, -0.35))
			eyes(c, 0.85, 0.40, 0.26)
			-- A capybara's snout is famously boxy, so this one is an actual box.
			c.piece("Snout", Vector3.new(0.32, 0.25, 0.24), Vector3.new(0, -0.14, -0.82), shade(c.color, -0.12), {
				Shape = Enum.PartType.Block,
			})
			c.piece(
				"Nose",
				Vector3.new(0.14, 0.09, 0.06),
				Vector3.new(0, -0.06, -0.98),
				EYE,
				{ Shape = Enum.PartType.Block }
			)
			c.piece("Mouth", Vector3.new(0.18, 0.04, 0.04), Vector3.new(0, -0.30, -0.96), shade(c.color, -0.5))
			blush(c, 0.68, -0.22)
			belly(c, 1.0, -0.46, shade(c.color, 0.3))
			feet(c, 1.1, 0.36, shade(c.color, -0.3))
		end,
	},
	Axolotl = {
		wide = 1.06,
		deep = 1.02,
		build = function(c)
			-- Three feathery frills a side: the axolotl's whole silhouette.
			for _, side in { -1, 1 } do
				for i = 1, 3 do
					local lift = 0.34 + (i - 1) * 0.28
					c.piece(
						"FrillStalk",
						Vector3.new(0.22, 0.05, 0.05),
						Vector3.new(side * 0.78, lift, 0.04),
						shade(c.color, -0.1),
						{
							Shape = Enum.PartType.Cylinder,
						}
					)
					c.piece(
						"Frill",
						Vector3.one * 0.17,
						Vector3.new(side * 1.02, lift + 0.06, 0.04),
						shade(c.color, 0.2)
					)
				end
			end
			eyes(c, 1.15, 0.38, 0.14)
			-- Sir Noodle smiles at all times, even while thinking about taxes.
			c.piece("Smile", Vector3.new(0.34, 0.05, 0.05), Vector3.new(0, -0.24, -0.92), shade(c.color, -0.45), {
				Shape = Enum.PartType.Cylinder,
			})
			c.piece("Nostril", Vector3.new(0.04, 0.04, 0.04), Vector3.new(-0.12, -0.06, -0.99), shade(c.color, -0.4))
			c.piece("Nostril", Vector3.new(0.04, 0.04, 0.04), Vector3.new(0.12, -0.06, -0.99), shade(c.color, -0.4))
			blush(c, 0.64, -0.12)
			belly(c, 1.0, -0.42, shade(c.color, 0.35))
			for _, side in { -1, 1 } do
				c.piece(
					"Arm",
					Vector3.new(0.13, 0.10, 0.22),
					Vector3.new(side * 0.44, -0.68, -0.46),
					shade(c.color, 0.1)
				)
			end
			c.piece("Tail", Vector3.new(0.10, 0.34, 0.34), Vector3.new(0, -0.24, 0.96), shade(c.color, 0.1))
		end,
	},
	Panda = {
		wide = 1.08,
		deep = 1.02,
		build = function(c)
			local coal = Color3.fromRGB(38, 38, 44)
			roundEars(c, 1.0, 0.44, shade(coal, 0.25), coal)
			-- The patches go on before the eyes, so the eyes read as sitting inside them.
			for _, side in { -1, 1 } do
				c.piece("Patch", Vector3.new(0.26, 0.30, 0.16), Vector3.new(side * 0.36, 0.14, -0.88), coal, {
					Rotation = CFrame.Angles(0, 0, side * 0.3),
				})
			end
			eyes(c, 0.85, 0.36, 0.16)
			muzzle(c, 1.0, -0.12, coal, WHITE)
			blush(c, 0.70, -0.16)
			-- Arm and leg bands, the rest of the panda pattern.
			for _, side in { -1, 1 } do
				c.piece("Arm", Vector3.new(0.20, 0.34, 0.26), Vector3.new(side * 0.88, -0.30, -0.24), coal, {
					Rotation = CFrame.Angles(0, 0, side * 0.2),
				})
				c.piece("Foot", Vector3.new(0.18, 0.12, 0.22), Vector3.new(side * 0.36, -0.70, -0.46), coal)
			end
			c.piece("Saddle", Vector3.new(1.04, 0.46, 0.82), Vector3.new(0, 0.16, 0.30), coal)
		end,
	},
}

-- Fallback for a species with no profile yet: the plain round Chonk.
local GENERIC = {
	wide = 1.05,
	deep = 1.0,
	build = function(c: Chonk)
		roundEars(c, 1, 0.40)
		eyes(c, 1, 0.34, 0.16)
		muzzle(c, 1, -0.08)
		blush(c, 0.64, -0.12)
		belly(c, 1.0, -0.42)
		feet(c, 1, 0.34)
		tailNub(c, 0.13)
	end,
}

-- A round Chonk, tinted by the catalog colour and shaped by its species.
function Models.chonk(entry: { color: { number }, species: string? }, size: number): Model
	local scale = Formulas.sizeScale(size)
	local d = 4 * scale
	local profile = (entry.species and SPECIES[entry.species]) or GENERIC
	local c = newChonk(rgb(entry.color), d, profile.wide, profile.deep)
	profile.build(c)
	return c.model
end

-- A rolled blanket whose glow hints at the tier and whose size hints at the Chonk's size (spec §7).
-- The Y half extent stays 1.1 * scale: Showcase rests a burrito on a pad with it.
function Models.burrito(tier: string, size: number): Model
	local scale = Formulas.sizeScale(size)
	local tierColor = rgb(Config.TierColors[tier])
	local model = Instance.new("Model")
	model.Name = "Burrito"
	local cloth = Color3.fromRGB(240, 231, 212)
	local body = Models.part({
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3.2, 2.2, 2.2) * scale,
		Color = cloth,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = model,
	})
	model.PrimaryPart = body

	local function deco(props: { [string]: any }): BasePart
		props.CanCollide = false
		props.CanQuery = false
		props.Parent = model
		local part = Models.part(props)
		weldTo(body, part)
		return part
	end

	-- Rounded ends, so it reads as a bundle rather than a pipe. An earlier version added fold and
	-- twist rings in Fabric; at this size they stacked up and the whole thing read as a metal
	-- spring, so the bundle is kept smooth and does its talking with the tier band.
	for _, side in { -1, 1 } do
		deco({
			Name = "End",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.5, 2.16, 2.16) * scale,
			CFrame = body.CFrame * CFrame.new(side * 1.45 * scale, 0, 0),
			Color = cloth,
			Material = Enum.Material.SmoothPlastic,
		})
		-- A pinched twist at each end, like a wrapped sweet.
		deco({
			Name = "Twist",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.8, 0.85, 0.85) * scale,
			CFrame = body.CFrame * CFrame.new(side * 2.15 * scale, 0, 0),
			Color = shade(cloth, -0.1),
			Material = Enum.Material.SmoothPlastic,
		})
	end
	-- The tier band and its bow.
	deco({
		Name = "Band",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 2.26, 2.26) * scale,
		CFrame = body.CFrame,
		Color = tierColor,
		Material = Enum.Material.Neon,
	})
	deco({
		Name = "Knot",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.6 * scale,
		CFrame = body.CFrame * CFrame.new(0, 1.12 * scale, 0),
		Color = tierColor,
		Material = Enum.Material.Neon,
	})
	for _, side in { -1, 1 } do
		deco({
			Name = "Ribbon",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.34, 0.5, 0.7) * scale,
			CFrame = body.CFrame * CFrame.new(0, 1.42 * scale, side * 0.42 * scale) * CFrame.Angles(side * 0.6, 0, 0),
			Color = tierColor,
			Material = Enum.Material.Neon,
		})
	end

	local light = Instance.new("PointLight")
	light.Color = tierColor
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = body
	return model
end

-- World text. Two kinds, and nothing else floats in the world:
--
-- * Labels (Chonk name tags, unwrap timers) are billboards sized partly in studs and partly in
--   pixels. The stud part shrinks with distance like the thing labelled; the pixel part is a floor,
--   so a far label stays legible. Pure pixel sizes kept one size at every range, so a far tag
--   swamped its Chonk and piled onto its neighbours. Labels hang by their bottom edge above the
--   object, straight up in world space, and draw on top so a wall or a beam never slices the text.
-- * Signs (house names, the practice house, the zone board, the raid cooldown) are printed onto a
--   face of a real board with a SurfaceGui, so the words sit on the world instead of in front of it.
local LABEL_INK = Color3.fromRGB(24, 20, 36)
local MONEY = Color3.fromRGB(134, 236, 110)
Models.LABEL_INK = LABEL_INK

local function round(gui: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = gui
end

local function outline(gui: GuiObject, color: Color3, thickness: number, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = if gui:IsA("TextLabel")
		then Enum.ApplyStrokeMode.Contextual
		else Enum.ApplyStrokeMode.Border
	stroke.Parent = gui
end

local function text(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

local function capText(label: TextLabel, max: number)
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = max
	cap.MinTextSize = 8
	cap.Parent = label
end

-- A world label anchored `offsetY` studs above whatever it is parented to, sized `studs` + `pixels`.
-- Returned unparented: callers fill it and parent it last, so it replicates whole.
local function label(name: string, studs: Vector2, pixels: Vector2, offsetY: number, range: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.new(studs.X, pixels.X, studs.Y, pixels.Y)
	gui.SizeOffset = Vector2.new(0, 0.5) -- hang by the bottom edge
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = range
	gui.ResetOnSpawn = false
	return gui
end
Models.worldLabel = label

-- The plate every label sits on: dark, rounded, rimmed in an accent colour.
local function plate(parent: Instance, accent: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Plate"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = LABEL_INK
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = parent
	round(frame, UDim.new(0.32, 0))
	outline(frame, accent, 2.5, 0.05)
	return frame
end

-- A floating countdown above an incubator or porch pad: an hourglass and the seconds left on a
-- gold-rimmed plate. Callers set the returned label's Text and destroy its BillboardGui
-- (label.Parent) when done, which takes the plate and the icon with it.
function Models.progressLabel(parent: BasePart): TextLabel
	local gui = label("Unwrap", Vector2.new(1.9, 0.75), Vector2.new(46, 18), 3.2, 70)
	plate(gui, Color3.fromRGB(255, 214, 64))
	local icon = text(gui, "Icon", {
		Position = UDim2.fromScale(0.08, 0.12),
		Size = UDim2.fromScale(0.3, 0.76),
		Text = utf8.char(0x23F3),
	})
	capText(icon, 24)
	local time = text(gui, "Time", {
		Position = UDim2.fromScale(0.36, 0.12),
		Size = UDim2.fromScale(0.54, 0.76),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	capText(time, 26)
	outline(time, LABEL_INK, 1.5)
	gui.Parent = parent
	return time
end

-- A Chonk's name tag, hanging `offsetY` studs above the model's body. `text` is the name, then
-- optionally a newline and a detail line (the income). Tier-coloured: the rim and the name.
-- `maxDistance` sets its range: a Vault packs ten pads close together, so callers there pass less.
function Models.nameLabel(
	model: Model,
	content: string,
	color: Color3,
	offsetY: number,
	maxDistance: number?
): TextLabel
	local name, detail = string.match(content, "^(.-)\n(.*)$")
	name = name or content
	local twoLines = detail ~= nil and detail ~= ""
	local gui = label(
		"NameTag",
		Vector2.new(2.3, if twoLines then 0.62 else 0.42),
		Vector2.new(96, if twoLines then 28 else 18),
		offsetY,
		maxDistance or 80
	)
	local back = plate(gui, color)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.07, 0)
	pad.PaddingRight = UDim.new(0.07, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = back
	local nameLabel = text(back, "Name", {
		Size = UDim2.fromScale(1, if twoLines then 0.58 else 1),
		Text = name,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3),
	})
	capText(nameLabel, 30)
	outline(nameLabel, LABEL_INK, 1.5)
	if twoLines then
		local detailLabel = text(back, "Detail", {
			Position = UDim2.fromScale(0, 0.6),
			Size = UDim2.fromScale(1, 0.4),
			Text = detail,
			TextColor3 = MONEY,
		})
		capText(detailLabel, 22)
	end
	gui.Parent = model.PrimaryPart
	return nameLabel
end

-- A one-word shout over the action (BONK, MRRP): heavy display type with a thick ink outline, no
-- plate, so it reads as a sound effect rather than as a label.
function Models.shout(gui: BillboardGui, word: string, color: Color3): TextLabel
	local line = text(gui, "Shout", {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.LuckiestGuy,
		Text = string.upper(word),
		TextColor3 = color,
	})
	outline(line, LABEL_INK, 3)
	return line
end

-- A printed sign: a SurfaceGui on one face of `board`, holding a dark panel inset from the board's
-- edges so the board itself shows round it as a frame in its own colour. Returns the panel for the
-- caller's text. Faces lit at a quarter strength, so a sign in shade still reads but is not a lamp.
function Models.signFace(board: BasePart, face: Enum.NormalId): Frame
	local gui = Instance.new("SurfaceGui")
	gui.Name = `Sign{face.Name}`
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- Sharp on a small board, capped near 1000 pixels across on a big one.
	local across = if face == Enum.NormalId.Left or face == Enum.NormalId.Right then board.Size.Z else board.Size.X
	gui.PixelsPerStud = math.min(50, 1000 / across)
	gui.LightInfluence = 0.25
	gui.MaxDistance = 500
	gui.Parent = board
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -18, 1, -18)
	panel.BackgroundColor3 = LABEL_INK
	panel.BorderSizePixel = 0
	panel.Parent = gui
	round(panel, UDim.new(0, 10))
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = panel
	return panel
end

-- A line of sign text filling `size` of a sign panel, positioned at `position`.
function Models.signText(
	panel: Frame,
	name: string,
	value: string,
	color: Color3,
	position: UDim2,
	size: UDim2
): TextLabel
	local line = text(panel, name, { Position = position, Size = size, Text = value, TextColor3 = color })
	outline(line, Color3.new(0, 0, 0), 2, 0.4)
	return line
end

-- The Mama Chonk guardian. Body rolls; ears, eyes and brow keep an upright offset (the "Offset"
-- attribute) that Guardians applies each frame relative to the unrolled frame.
function Models.mama(): Model
	local d = Config.Guardian.radius * 2
	local fur = Color3.fromRGB(214, 170, 150)
	local model = Instance.new("Model")
	model.Name = "MamaChonk"
	local body = Models.part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * d,
		Color = fur,
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

	local function deco(name: string, size: Vector3, color: Color3, offset: CFrame, props: { [string]: any }?)
		local part = Models.part({
			ClassName = (props and props.ClassName) or "Part",
			Name = name,
			Shape = (props and props.Shape) or Enum.PartType.Ball,
			Size = size * d,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
		part:SetAttribute("Offset", offset)
		return part
	end

	-- An angry brow and bared teeth: she should read as a threat from across the field (spec §11).
	for _, side in { -1, 1 } do
		deco("Ear", Vector3.one * 0.3, fur, CFrame.new(side * d * 0.3, d * 0.45, 0))
		deco("Eye", Vector3.one * 0.12, Color3.fromRGB(255, 240, 240), CFrame.new(side * d * 0.16, d * 0.12, -d * 0.47))
		deco("Pupil", Vector3.one * 0.07, Color3.fromRGB(180, 20, 20), CFrame.new(side * d * 0.16, d * 0.11, -d * 0.5))
		deco(
			"Brow",
			Vector3.new(0.20, 0.05, 0.05),
			Color3.fromRGB(120, 70, 60),
			CFrame.new(side * d * 0.17, d * 0.25, -d * 0.46) * CFrame.Angles(0, 0, side * 0.5),
			{ Shape = Enum.PartType.Cylinder }
		)
	end
	deco("Snout", Vector3.new(0.26, 0.20, 0.18), Color3.fromRGB(236, 200, 184), CFrame.new(0, -d * 0.04, -d * 0.46))
	deco("Nose", Vector3.new(0.09, 0.07, 0.07), Color3.fromRGB(60, 40, 44), CFrame.new(0, d * 0.02, -d * 0.55))
	for _, side in { -1, 1 } do
		deco(
			"Tooth",
			Vector3.new(0.05, 0.07, 0.05),
			Color3.fromRGB(255, 252, 245),
			CFrame.new(side * d * 0.07, -d * 0.14, -d * 0.5)
		)
	end

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 100)
	glow.Range = 14
	glow.Brightness = 0.8
	glow.Parent = body
	return model
end

return Models
