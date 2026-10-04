-- Player houses in a ring inside the curb (spec §6, §10). Each plot has a porch facing the curb with
-- two Showcase pads and porch lights, a hamster wheel, two Vault incubators and ten Vault display pads.
-- Players spawn on their porch. Owner-only prompts carry the `Plot` and `Audience` attributes that the
-- client PromptFilter reads.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Models = require(script.Parent.Models)
local Notify = require(script.Parent.Notify)
local PlayerState = require(script.Parent.PlayerState)

local Plots = {}

local frames: { CFrame } = {}
local models: { Model } = {}
local owners: { [number]: Player } = {}

-- Plot-local layout: -Z faces outward (porch side), +Z faces the district centre (Vault side).
local LOCAL = {
	spawn = CFrame.new(0, 4, -14),
	wheel = Vector3.new(-12, 1.1, -8),
	-- Spacing has to clear the largest Chonk a plot can hold: body d = 4 * max SizeScale (8.4),
	-- times the widest species profile (1.24) -- call it 10.4 across, 10.1 deep. The incubators
	-- were 6 apart and a max-size burrito is 9.2 long, so two of them interpenetrated.
	incubators = { Vector3.new(5, 1.6, -8), Vector3.new(15, 1.6, -8) },
	-- Derived from Config.Vault.displaySpacing below, so there is one place to change the grid.
	displayColumns = 5,
	-- Rows pushed as far apart as the room allows: the back wall's inner face is at z 19 and the
	-- wheel and incubators sit at z -8, so the pair straddles z 8.5.
	displayRowCentre = 8.5,
	-- The porch strip is z -20..-12; x = 0 is the spawn, so the slots sit either side of it.
	showcase = { Vector3.new(-8, 1.3, -16), Vector3.new(8, 1.3, -16) },
	-- Standing on the front ends of the knee walls (top at y 3.5), not sunk into them.
	porchLights = { Vector3.new(-19.5, 4.45, -19.5), Vector3.new(19.5, 4.45, -19.5) },
	cooldownSign = Vector3.new(0, 6.75, -19.5), -- hangs under the porch beam (beam bottom 7.8)
}

-- One saturated wall colour per plot, so eight houses in a ring are told apart at a glance and a
-- raider can say "the teal one". Trim stays white on all of them, which is what holds the ring
-- together as one street.
local HOUSE_COLORS = {
	Color3.fromRGB(236, 94, 104),
	Color3.fromRGB(246, 150, 58),
	Color3.fromRGB(248, 202, 70),
	Color3.fromRGB(104, 198, 124),
	Color3.fromRGB(72, 186, 190),
	Color3.fromRGB(84, 150, 232),
	Color3.fromRGB(160, 122, 224),
	Color3.fromRGB(230, 116, 180),
}

local PORCH_LIGHT = Color3.fromRGB(255, 226, 160)
-- The hamster wheel's rim radius and width, round the treadle (Config.Wheel.radius is the treadle).
local WHEEL_RADIUS = 5.5
local WHEEL_WIDTH = 5
Plots.PORCH_LIGHT = PORCH_LIGHT

-- Marks a prompt for the client PromptFilter: shown to the plot's owner ("owner") or everyone else ("others").
function Plots.tagPrompt(prompt: ProximityPrompt, plotIndex: number, audience: "owner" | "others")
	prompt:SetAttribute("Plot", plotIndex)
	prompt:SetAttribute("Audience", audience)
end

-- Every printed copy of the house name (Models.signText lines named "OwnerName").
local function ownerLabel(index: number)
	local owner = owners[index]
	local value = if owner then `{owner.DisplayName}'s house` else "Empty lot"
	for _, d in models[index]:GetDescendants() do
		if d.Name == "OwnerName" and d:IsA("TextLabel") then
			d.Text = value
		end
	end
end

-- The house name printed on one face of a board.
local function nameSign(board: BasePart, face: Enum.NormalId)
	local panel = Models.signFace(board, face)
	Models.signText(panel, "OwnerName", "Empty lot", Color3.new(1, 1, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
end

local function buildPlot(index: number, frame: CFrame, parent: Instance): Model
	local size = Config.Base.plotSize
	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model:SetAttribute("PlotIndex", index)

	local function at(localPos: Vector3): CFrame
		return frame * CFrame.new(localPos)
	end

	model.PrimaryPart = Models.part({
		Name = "Floor",
		Size = Vector3.new(size, 1, size),
		CFrame = at(Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(206, 160, 104),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	Models.part({
		Name = "Porch",
		Size = Vector3.new(size, 0.2, 8),
		CFrame = at(Vector3.new(0, 1.1, -size / 2 + 4)),
		Color = Color3.fromRGB(230, 188, 130),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	-- Walls on the back and sides; the porch side stays open. The house is deliberately left
	-- open at the top: the Vault display pads are inside it, and a roof over them would fight
	-- the player's camera every time they walked in to sort their Chonks.
	local WALL = HOUSE_COLORS[(index - 1) % #HOUSE_COLORS + 1]
	local TRIM = Color3.fromRGB(255, 250, 242)
	local BASE = Models.shade(WALL, -0.28)
	local wallTop = 8
	for _, wall in
		{
			{ Vector3.new(0, 4.5, size / 2 - 0.5), Vector3.new(size, 7, 1) },
			{ Vector3.new(-size / 2 + 0.5, 4.5, 4), Vector3.new(1, 7, size - 8) },
			{ Vector3.new(size / 2 - 0.5, 4.5, 4), Vector3.new(1, 7, size - 8) },
		}
	do
		Models.part({
			Name = "Wall",
			Size = wall[2],
			CFrame = at(wall[1]),
			Color = WALL,
			Parent = model,
		})
	end
	-- The yard walls in two tones: a darker band along the foot of every inside face, and posts down
	-- the outside of the side walls, so a forty-stud wall reads as built rather than as one flat slab.
	local BAND = Models.shade(WALL, -0.18)
	for _, band in
		{
			{ Vector3.new(0, 2.3, size / 2 - 1.1), Vector3.new(size - 2, 2.6, 0.2) },
			{ Vector3.new(-size / 2 + 1.1, 2.3, 4), Vector3.new(0.2, 2.6, size - 8) },
			{ Vector3.new(size / 2 - 1.1, 2.3, 4), Vector3.new(0.2, 2.6, size - 8) },
		}
	do
		Models.part({
			Name = "WallBand",
			Size = band[2],
			CFrame = at(band[1]),
			Color = BAND,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
	end
	for _, side in { -1, 1 } do
		for z = -12, 20, 8 do
			Models.part({
				Name = "WallPost",
				Size = Vector3.new(0.5, 7.2, 1),
				CFrame = at(Vector3.new(side * (size / 2 + 0.2), 4.6, z)),
				Color = Color3.fromRGB(255, 250, 242),
				CanCollide = false,
				CanQuery = false,
				Parent = model,
			})
		end
	end

	-- Knee walls either side of the porch bay, low enough to leave the Showcase in plain sight.
	for _, side in { -1, 1 } do
		Models.part({
			Name = "Wall",
			Size = Vector3.new(1, 2.5, 8),
			CFrame = at(Vector3.new(side * (size / 2 - 0.5), 2.25, -16)),
			Color = WALL,
			Parent = model,
		})
	end

	-- Scenery from here down: never collides, never blocks a prompt raycast.
	local function decor(props: { [string]: any }): BasePart
		props.CanCollide = false
		props.CanQuery = false
		props.Parent = model
		return Models.part(props)
	end

	-- A capping trim all round the wall tops, and a shallow gable over the back wall so the
	-- house reads as a house from out in the field.
	for _, trim in
		{
			{ Vector3.new(0, wallTop, size / 2 - 0.5), Vector3.new(size + 1.4, 0.8, 2) },
			{ Vector3.new(-size / 2 + 0.5, wallTop, 4), Vector3.new(2, 0.8, size - 8 + 1.4) },
			{ Vector3.new(size / 2 - 0.5, wallTop, 4), Vector3.new(2, 0.8, size - 8 + 1.4) },
		}
	do
		decor({ Name = "Trim", Size = trim[2], CFrame = at(trim[1]), Color = TRIM })
	end
	-- A cottage behind the back wall, its front on the plaza, so the ring reads as a street of houses
	-- with their yards rather than as eight open boxes; seen from the porch its roof rises over the
	-- back wall. It replaces a gable that floated over the wall and read as red ribbons from the
	-- plaza. The yard itself stays unroofed. Every visible piece is decoration (no collision, no
	-- raycasts, so the camera never pops on it); one invisible block stops anyone walking into it.
	local ROOF = WALL:Lerp(Color3.fromRGB(58, 40, 52), 0.55)
	local GLASS = Color3.fromRGB(176, 226, 255)
	local cHalf, cDepth, cHeight, cRise = 15, 10, 13, 7
	local cBack = size / 2 -- the back wall's outer face; the cottage starts here
	local cMid = cBack + cDepth / 2
	local cFront = cBack + cDepth -- the face on the plaza
	decor({
		Name = "Cottage",
		Size = Vector3.new(cHalf * 2, cHeight, cDepth),
		CFrame = at(Vector3.new(0, cHeight / 2, cMid)),
		Color = WALL,
	})
	Models.part({
		Name = "CottageBlock",
		Size = Vector3.new(cHalf * 2, cHeight, cDepth),
		CFrame = at(Vector3.new(0, cHeight / 2, cMid)),
		Transparency = 1,
		Parent = model,
	})
	decor({
		Name = "CottagePlinth",
		Size = Vector3.new(cHalf * 2 + 0.6, 1.4, cDepth + 0.6),
		CFrame = at(Vector3.new(0, 0.7, cMid)),
		Color = BASE,
	})
	decor({
		Name = "CottageBand",
		Size = Vector3.new(cHalf * 2 + 0.8, 0.8, cDepth + 0.8),
		CFrame = at(Vector3.new(0, cHeight, cMid)),
		Color = TRIM,
	})
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			decor({
				Name = "CottageCorner",
				Size = Vector3.new(0.9, cHeight, 0.9),
				CFrame = at(Vector3.new(sx * cHalf, cHeight / 2, cMid + sz * cDepth / 2)),
				Color = TRIM,
			})
		end
	end
	-- The roof: two slabs meeting at a ridge that runs front to back, with eaves past the walls.
	-- Rotating about Z lifts a slab's +X end, so the -X slab takes the positive angle.
	local eave = cHeight + 0.4
	local run = cHalf + 1.2
	local slope = math.atan2(cRise, run)
	for _, side in { -1, 1 } do
		decor({
			Name = "Roof",
			Size = Vector3.new(math.sqrt(run * run + cRise * cRise), 1.2, cDepth + 2.4),
			CFrame = at(Vector3.new(side * run / 2, eave + cRise / 2, cMid)) * CFrame.Angles(0, 0, -side * slope),
			Color = ROOF,
		})
	end
	decor({
		Name = "RoofRidge",
		Size = Vector3.new(1.4, 1, cDepth + 2.6),
		CFrame = at(Vector3.new(0, eave + cRise + 0.25, cMid)),
		Color = Models.shade(ROOF, -0.2),
	})
	-- Gable ends: a wedge each side of the ridge, tall edge at the middle. A wedge is full height at
	-- its local +Z, so turning it -90 degrees about Y puts that edge towards -X (the right half).
	for _, z in { cBack + 0.3, cFront - 0.3 } do
		for _, side in { -1, 1 } do
			decor({
				ClassName = "WedgePart",
				Name = "Gable",
				Size = Vector3.new(0.6, cRise + 0.4, cHalf),
				CFrame = at(Vector3.new(side * cHalf / 2, cHeight + (cRise + 0.4) / 2, z))
					* CFrame.Angles(0, -side * math.pi / 2, 0),
				Color = WALL,
			})
		end
	end
	decor({
		Name = "Chimney",
		Size = Vector3.new(2.4, 7, 2.4),
		CFrame = at(Vector3.new(8.5, eave + 3.2, cMid + 2)),
		Color = BASE,
	})
	decor({
		Name = "ChimneyCap",
		Size = Vector3.new(3, 0.6, 3),
		CFrame = at(Vector3.new(8.5, eave + 6.9, cMid + 2)),
		Color = TRIM,
	})
	-- The front on the plaza: a door, two windows with flower boxes, a round window in the gable
	-- and the house name over the door.
	decor({
		Name = "FrontDoorFrame",
		Size = Vector3.new(6.4, 9, 0.3),
		CFrame = at(Vector3.new(0, 4.9, cFront + 0.15)),
		Color = TRIM,
	})
	decor({
		Name = "FrontDoor",
		Size = Vector3.new(5, 8, 0.3),
		CFrame = at(Vector3.new(0, 4.6, cFront + 0.3)),
		Color = Color3.fromRGB(150, 98, 74),
		Material = Enum.Material.Wood,
	})
	decor({
		Name = "FrontKnob",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.6,
		CFrame = at(Vector3.new(1.6, 4.4, cFront + 0.55)),
		Color = Color3.fromRGB(255, 214, 64),
	})
	for _, side in { -1, 1 } do
		local x = side * 9.5
		decor({
			Name = "FrontWindowFrame",
			Size = Vector3.new(6.2, 5.6, 0.3),
			CFrame = at(Vector3.new(x, 7.4, cFront + 0.15)),
			Color = TRIM,
		})
		decor({
			Name = "FrontWindow",
			Size = Vector3.new(5, 4.4, 0.3),
			CFrame = at(Vector3.new(x, 7.4, cFront + 0.3)),
			Color = GLASS,
			Material = Enum.Material.Glass,
			Transparency = 0.15,
		})
		decor({
			Name = "FrontMullion",
			Size = Vector3.new(0.3, 4.4, 0.35),
			CFrame = at(Vector3.new(x, 7.4, cFront + 0.35)),
			Color = TRIM,
		})
		decor({
			Name = "FrontSill",
			Size = Vector3.new(6.8, 0.45, 0.9),
			CFrame = at(Vector3.new(x, 4.5, cFront + 0.45)),
			Color = TRIM,
		})
		decor({
			Name = "FlowerBox",
			Size = Vector3.new(6, 1.2, 1.2),
			CFrame = at(Vector3.new(x, 3.7, cFront + 0.7)),
			Color = BASE,
		})
		for i = 1, 5 do
			decor({
				Name = "Flower",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.9,
				CFrame = at(Vector3.new(x - 3 + i, 4.5, cFront + 0.75)),
				Color = if i % 2 == 0 then Color3.fromRGB(255, 150, 170) else Color3.fromRGB(255, 240, 150),
			})
		end
	end
	decor({
		Name = "GableWindowFrame",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 3.8, 3.8),
		CFrame = at(Vector3.new(0, cHeight + 3, cFront + 0.1)) * CFrame.Angles(0, math.pi / 2, 0),
		Color = TRIM,
	})
	decor({
		Name = "GableWindow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 3, 3),
		CFrame = at(Vector3.new(0, cHeight + 3, cFront + 0.2)) * CFrame.Angles(0, math.pi / 2, 0),
		Color = GLASS,
		Material = Enum.Material.Glass,
	})
	local frontSign = decor({
		Name = "FrontSign",
		Size = Vector3.new(13, 2.4, 0.4),
		CFrame = at(Vector3.new(0, 10.5, cFront + 0.25)),
		Color = TRIM,
	})
	nameSign(frontSign, Enum.NormalId.Back)
	decor({
		Name = "Doormat",
		Size = Vector3.new(6, 0.3, 2.2),
		CFrame = at(Vector3.new(0, 0.3, cFront + 1.2)),
		Color = BASE,
	})
	-- Two small windows on the yard side, above the back wall.
	for _, side in { -1, 1 } do
		decor({
			Name = "YardWindowFrame",
			Size = Vector3.new(4.6, 3.4, 0.3),
			CFrame = at(Vector3.new(side * 8, 10.8, cBack - 0.1)),
			Color = TRIM,
		})
		decor({
			Name = "YardWindow",
			Size = Vector3.new(3.6, 2.4, 0.3),
			CFrame = at(Vector3.new(side * 8, 10.8, cBack - 0.2)),
			Color = GLASS,
			Material = Enum.Material.Glass,
			Transparency = 0.15,
		})
	end

	-- A door and two windows on the inside face of the back wall.
	decor({
		Name = "Door",
		Size = Vector3.new(7, 7, 0.5),
		CFrame = at(Vector3.new(0, 4.5, size / 2 - 1.2)),
		Color = Color3.fromRGB(150, 98, 74),
		Material = Enum.Material.WoodPlanks,
	})
	decor({
		Name = "Knob",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.7,
		CFrame = at(Vector3.new(2.4, 4.4, size / 2 - 1.6)),
		Color = Color3.fromRGB(255, 214, 64),
		Material = Enum.Material.Metal,
	})
	for _, side in { -1, 1 } do
		decor({
			Name = "Window",
			Size = Vector3.new(6, 4, 0.5),
			CFrame = at(Vector3.new(side * 12, 5.4, size / 2 - 1.2)),
			Color = Color3.fromRGB(168, 224, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.25,
		})
		decor({
			Name = "WindowFrame",
			Size = Vector3.new(7, 5, 0.3),
			CFrame = at(Vector3.new(side * 12, 5.4, size / 2 - 1.45)),
			Color = TRIM,
		})
	end

	-- A porch pergola: posts and a beam, with no deck above them, so a raider coming in off
	-- the field can still see what is sitting on the Showcase pads.
	for _, side in { -1, 1 } do
		decor({
			Name = "PorchPost",
			Size = Vector3.new(1.4, 7, 1.4),
			CFrame = at(Vector3.new(side * 16, 4.5, -19.5)),
			Color = TRIM,
		})
	end
	decor({
		Name = "PorchBeam",
		Size = Vector3.new(34, 1.2, 1.6),
		CFrame = at(Vector3.new(0, 8.4, -19.5)),
		Color = TRIM,
	})
	-- A step down off the porch, so the front edge is not a cliff.
	decor({
		Name = "Step",
		Size = Vector3.new(16, 0.6, 3),
		CFrame = at(Vector3.new(0, 0.9, -21.5)),
		Color = TRIM,
	})

	-- The treadle is the gameplay part (Wheel reads its position); the wheel stands over it.
	local wheel = Models.part({
		Name = "Wheel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, Config.Wheel.radius * 2, Config.Wheel.radius * 2),
		CFrame = at(LOCAL.wheel) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(72, 66, 90),
		Parent = model,
	})
	-- The hamster wheel: two rims of short segments joined by rungs, with spokes to a hub, on an
	-- A-frame. The player on the treadle stands inside it. Rims, rungs, spokes and hub are one
	-- tagged Model that the client spins while somebody is on the treadle (Wheels); the frame stays.
	local radius, width = WHEEL_RADIUS, WHEEL_WIDTH
	local centre = LOCAL.wheel + Vector3.new(0, 0.2 + radius, 0)
	local rig = Instance.new("Model")
	rig.Name = "WheelRig"
	local function rigPart(props: { [string]: any }): BasePart
		props.CanCollide = false
		props.CanQuery = false
		props.Parent = rig
		return Models.part(props)
	end
	local segments = 16
	local segmentLength = 2 * math.pi * radius / segments + 0.3
	for _, z in { -width / 2, width / 2 } do
		for i = 1, segments do
			local theta = 2 * math.pi * (i - 0.5) / segments
			rigPart({
				Name = "Rim",
				Size = Vector3.new(segmentLength, 0.6, 0.5),
				CFrame = at(centre + Vector3.new(radius * math.cos(theta), radius * math.sin(theta), z))
					* CFrame.Angles(0, 0, theta + math.pi / 2),
				Color = WALL,
			})
		end
		for i = 1, 6 do
			local phi = 2 * math.pi * i / 6
			rigPart({
				Name = "Spoke",
				Size = Vector3.new(radius, 0.3, 0.3),
				CFrame = at(centre + Vector3.new(radius / 2 * math.cos(phi), radius / 2 * math.sin(phi), z))
					* CFrame.Angles(0, 0, phi),
				Color = TRIM,
			})
		end
	end
	for i = 1, segments, 2 do
		local theta = 2 * math.pi * (i - 0.5) / segments
		rigPart({
			Name = "Rung",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(width, 0.34, 0.34),
			CFrame = at(centre + Vector3.new((radius - 0.1) * math.cos(theta), (radius - 0.1) * math.sin(theta), 0))
				* CFrame.Angles(0, math.pi / 2, 0),
			Color = TRIM,
		})
	end
	rig.PrimaryPart = rigPart({
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(width + 1.6, 1, 1),
		CFrame = at(centre) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.fromRGB(80, 74, 100),
	})
	rig:AddTag("SpinWheel")
	rig.Parent = model
	-- The A-frame: two legs a side, from the floor out to the axle.
	for _, z in { -(width / 2 + 0.8), width / 2 + 0.8 } do
		for _, sx in { -1, 1 } do
			local foot = Vector3.new(centre.X + sx * 3.4, 1, centre.Z + z)
			local top = Vector3.new(centre.X, centre.Y, centre.Z + z)
			local d = top - foot
			decor({
				Name = "WheelLeg",
				Size = Vector3.new(0.6, d.Magnitude, 0.6),
				CFrame = at((foot + top) / 2) * CFrame.Angles(0, 0, math.atan2(-d.X, d.Y)),
				Color = Color3.fromRGB(80, 74, 100),
			})
		end
	end

	local pedal = Instance.new("ProximityPrompt")
	pedal.Name = "PedalPrompt"
	pedal.ActionText = Strings.Prompts.pedal
	pedal.ObjectText = Strings.Prompts.wheelObject
	pedal.HoldDuration = 0
	pedal.MaxActivationDistance = Config.Wheel.promptDistance
	pedal.RequiresLineOfSight = false
	Plots.tagPrompt(pedal, index, "owner")
	pedal.Parent = wheel

	for slot, pos in LOCAL.showcase do
		Models.part({
			Name = `Showcase{slot}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 6, 6),
			CFrame = at(pos) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(252, 240, 214),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		-- A ring under the pad and a light over it: this is the shop window of the whole game
		-- (spec §12), so it should look like something is meant to stand there.
		decor({
			Name = "ShowcaseRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.18, 6.7, 6.7),
			CFrame = at(pos - Vector3.new(0, 0.16, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(236, 184, 64),
		})
		-- Only a holder for the spotlight: as a visible box it floated in mid air over the pad.
		local spot = decor({
			Name = "ShowcaseSpot",
			Size = Vector3.new(1, 1, 1),
			CFrame = at(Vector3.new(pos.X, 7.6, pos.Z)),
			Transparency = 1,
		})
		local beamLight = Instance.new("SpotLight")
		beamLight.Face = Enum.NormalId.Bottom
		beamLight.Angle = 70
		beamLight.Range = 16
		beamLight.Brightness = 2
		beamLight.Color = Color3.fromRGB(255, 240, 210)
		beamLight.Parent = spot
	end
	-- Porch lanterns: a lamp between a cap and a foot. Plain plastic rather than Neon, which bloomed
	-- into a white box up close; the theft alarm still flashes them red (Showcase).
	for _, pos in LOCAL.porchLights do
		local light = Models.part({
			Name = "PorchLight",
			Size = Vector3.new(0.9, 1.2, 0.9),
			CFrame = at(pos),
			Color = PORCH_LIGHT,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
			Parent = model,
		})
		local glow = Instance.new("PointLight")
		glow.Color = PORCH_LIGHT
		glow.Range = 12
		glow.Parent = light
		for _, dy in { 0.75, -0.72 } do
			decor({
				Name = "LanternCap",
				Size = Vector3.new(1.3, 0.3, 1.3),
				CFrame = at(pos + Vector3.new(0, dy, 0)),
				Color = Color3.fromRGB(70, 62, 84),
			})
		end
	end
	-- The raid-cooldown plaque hangs under the porch beam, hidden until a theft starts one.
	local cooldown = decor({
		Name = "CooldownSign",
		Size = Vector3.new(11, 1.8, 0.4),
		CFrame = at(LOCAL.cooldownSign),
		Color = Color3.fromRGB(214, 52, 52),
		Transparency = 1,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local panel = Models.signFace(cooldown, face)
		panel.BackgroundColor3 = Color3.fromRGB(150, 24, 30)
		panel.Parent.Enabled = false
		Models.signText(panel, "Line", "", Color3.new(1, 1, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	end

	for slot, pos in LOCAL.incubators do
		Models.part({
			Name = `Incubator{slot}`,
			Size = Vector3.new(4, 1.2, 4),
			CFrame = at(pos),
			Color = Color3.fromRGB(150, 220, 255),
			Material = Enum.Material.Glass,
			Parent = model,
		})
		decor({
			Name = "IncubatorBase",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.1, 5.6, 5.6),
			CFrame = at(pos - Vector3.new(0, 1.0, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = BASE,
		})
		decor({
			Name = "IncubatorDome",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4.6, 5.4, 4.6),
			CFrame = at(pos + Vector3.new(0, 1.2, 0)),
			Color = Color3.fromRGB(180, 232, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.6,
		})
	end
	local gap = Config.Vault.displaySpacing
	local displayXs, displayZs = {}, {}
	for i = 1, LOCAL.displayColumns do
		table.insert(displayXs, (i - (LOCAL.displayColumns + 1) / 2) * gap.x)
	end
	for _, side in { -1, 1 } do
		table.insert(displayZs, LOCAL.displayRowCentre + side * gap.z / 2)
	end
	local display = 0
	for _, z in displayZs do
		for _, x in displayXs do
			display += 1
			Models.part({
				Name = `Display{display}`,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 5, 5),
				CFrame = at(Vector3.new(x, 1.15, z)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = Color3.fromRGB(246, 238, 222),
				Parent = model,
			})
			decor({
				Name = "DisplayRing",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, 6.2, 6.2),
				CFrame = at(Vector3.new(x, 1.0, z)) * CFrame.Angles(0, 0, math.pi / 2),
				Color = BASE,
			})
		end
	end

	-- The house name on a board standing on the porch beam, framed in the house's own colour and
	-- printed on both faces: outward for anyone coming in off the field, inward for the owner.
	local sign = decor({
		Name = "OwnerSign",
		Size = Vector3.new(16, 3.4, 0.5),
		CFrame = at(Vector3.new(0, 9 + 1.7, -19.5)),
		Color = WALL,
	})
	nameSign(sign, Enum.NormalId.Front)
	nameSign(sign, Enum.NormalId.Back)

	model.Parent = parent
	return model
end

-- Shows `value` on a plot's raid-cooldown plaque, or hides the plaque when it is nil.
function Plots.setCooldown(index: number, value: string?)
	local board = Plots.part(index, "CooldownSign")
	board.Transparency = if value then 0 else 1
	for _, gui in board:GetChildren() do
		if gui:IsA("SurfaceGui") then
			gui.Enabled = value ~= nil
			local line = gui:FindFirstChild("Line", true) :: TextLabel?
			if line and value then
				line.Text = value
			end
		end
	end
end

function Plots.frame(index: number): CFrame
	return frames[index]
end

function Plots.part(index: number, name: string): BasePart
	return models[index]:FindFirstChild(name) :: BasePart
end

function Plots.model(index: number): Model
	return models[index]
end

function Plots.ownerOf(index: number): Player?
	return owners[index]
end

function Plots.count(): number
	return #models
end

-- How many porch Showcase pads each plot has. The layout above is the authority, not Config.
function Plots.showcasePads(): number
	return #LOCAL.showcase
end

function Plots.spawnCFrame(index: number): CFrame
	return frames[index] * LOCAL.spawn
end

-- True when the player's root is over the plot square, plus a 2-stud margin.
function Plots.isOnPlot(player: Player, index: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local frame = frames[index]
	if not (root and frame) then
		return false
	end
	local p = frame:PointToObjectSpace(root.Position)
	local half = Config.Base.plotSize / 2 + 2
	return math.abs(p.X) <= half and math.abs(p.Z) <= half
end

local function sendToPorch(player: Player, character: Model)
	local state = PlayerState.get(player)
	if not (state and state.plot) then
		return
	end
	-- CharacterAdded fires before the character is parented and placed at a SpawnLocation;
	-- wait for both, or the default spawn placement overrides the porch teleport.
	local deadline = os.clock() + 5
	while not character.Parent and os.clock() < deadline do
		task.wait()
	end
	character:WaitForChild("HumanoidRootPart", 5)
	task.wait()
	if character.Parent and state.plot then
		character:PivotTo(Plots.spawnCFrame(state.plot))
	end
end

function Plots.start()
	local root = workspace:WaitForChild("World")
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = root
	for index, p in Layout.plotFrames() do
		local center = Vector3.new(p.x, 0, p.z)
		local outward = Vector3.new(math.cos(p.yaw), 0, math.sin(p.yaw))
		frames[index] = CFrame.lookAt(center, center + outward)
		models[index] = buildPlot(index, frames[index], folder)
	end

	PlayerState.Added:Connect(function(player: Player)
		local state = PlayerState.get(player)
		for index = 1, #models do
			if not owners[index] then
				owners[index] = player
				if state then
					state.plot = index
				end
				ownerLabel(index)
				break
			end
		end
		if state and not state.plot then
			task.delay(2, function()
				Notify.toast(player, "noPlot")
			end)
		end
		player.CharacterAdded:Connect(function(character)
			sendToPorch(player, character)
		end)
		if player.Character then
			task.spawn(sendToPorch, player, player.Character)
		end
	end)

	PlayerState.Removing:Connect(function(player: Player)
		for index, owner in owners do
			if owner == player then
				owners[index] = nil
				ownerLabel(index)
			end
		end
	end)
end

return Plots
