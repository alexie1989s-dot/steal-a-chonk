# Big Uneven Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the map bigger and uneven, the way the user asked on 2026-10-04 ("a larger uneven map that is not a perfect circle"), while keeping the play surface dead flat so nothing ever floats (user ruling, 2026-10-04). It gets an irregular edge, Terrain hills and a far ridge past the wall, a small lake seen through a dip in the hills, and upgraded lighting.

**Architecture:** Two pure, Lune-tested modules describe the land. `Layout.outlineRadius` gives the field's uneven edge. `Ground.height` is 0 everywhere inside that edge and rises into hills only past it. A third pure module, `LandGrid`, cuts the land into Terrain chunks and fills their voxel arrays. The server's `Landscape` writes them with `Terrain:WriteVoxelChannels` at boot, in the background while the scenery packs download, and `Main` lets nobody in until the land is down. `World` then builds its wall along the outline and plants woods on the hills, and the old Baseplate and part domes go. Lighting moves to Future, with dynamic clouds and animated grass.

**Tech Stack:** Luau, Roblox Terrain (`WriteVoxelChannels`, `SetMaterialColor`, water properties), Lighting, Atmosphere and Clouds, Rojo 7.7 (project-file Terrain properties), Lune 0.10, StyLua, Selene, Studio MCP and the window-capture tools.

**Spec:** `docs/superpowers/specs/2026-09-06-steal-a-chonk-design.md`: §6 (world and map), §7 (nests), §20 and §22 (performance). User requests and rulings of 2026-10-04 (below).

**Part of a three-plan polish pass:** 1. glossy UI (done, uncommitted on `polish/glossy-ui`); **2. this plan**; 3. VFX, ambient life and a phone performance pass.

## Decisions (user, 2026-10-04)

- **The play surface stays flat.** The user's words: "keep surface flat, else things will start floating". Everything inside the wall is y = 0: district, field, nests. The land only rises past the wall, where nothing is carried, dropped or chased. So guardians, dropped burritos, nests, teleports and the field scatter need no ground maths.
- **The rest of the proposal is approved** ("rest all is fine"):

| Decision | Before | Now |
| --- | --- | --- |
| Field edge | circle, wall at 324 | uneven: wall 378 to 479 from the centre (mean 440), about twice the field area |
| Nests | 10, 135 to 230 out | 12 (spec §7 allows 8 to 14), 150 to 330 out |
| Hedges to juke round | 12 | 16 |
| Edge of the map | part domes and a part ridge | Terrain: a rim of hills 23 to 45 high just past the wall, a far ridge 104 to 163 high |
| Water | none | a small lake past the wall, seen through a dip in the rim, behind a low fence; nobody can reach it |
| Lighting | ShadowMap, 13:12 | Future (phones scale it down themselves), sun at 14:36, Roblox's dynamic clouds in place of the low-poly cloud meshes, animated grass |

- **What the bigger nest band costs.** This was measured with `GuardianBrain` on a carrier running straight home with a Common:
  - A brand-new player with 0 Zoomies now gets home on **15%** of grabs. It was 46%.
  - With 30 Zoomies (seconds on the wheel) it is **81%**. It was 93%.
  - From 100 Zoomies up it is 100%, before and after.
  - The far nests are therefore something the wheel unlocks (spec §6: "Distance is the early difficulty").

## Measured in Studio before planning (2026-10-04, play-mode spike)

These shaped the code. Nothing from the spike was saved.

- **Roblox draws a terrain surface half a voxel (2 studs) above its filled height.** Measured on flat 96-stud slabs: +2.00 at every fill level from 0.1 to 1.0, on Grass, LeafyGrass, Ground, Mud, Sand and Pavement. So `LandGrid` fills every column to `LIFT = 2` below `Ground.height`. To sit at y = 0, the field is filled to y = −2: full voxels to −4 and a half-filled voxel above.
- **Water has no lift.** A liquid fill draws exactly at its filled height. The pond is filled to its waterline.
- **Rock and Slate are roughened on purpose.** A flat Rock slab drew 1.1 to 2.0 studs high, and Slate 1.7 to 2.0. Rock is only used on faces steeper than 45 degrees, past the wall, where nothing is planted.
- **Slopes are accurate to about 0.2 studs at slope 0.25, and 0.5 studs at slope 0.5.** This was measured on ramps filled to `h − 2`.
- **Speed:** the whole land is 463 chunks and 2.3 M voxels. Building the arrays took 0.35 s and writing them 0.09 s on the Studio server.
- **Terrain physics updates a frame after a write.** A raycast in the same frame misses. Probes run after the game has booted.
- **Not scriptable:** `Terrain.Decoration` and `GrassLength` are NotScriptable, and `Lighting.Technology` is RobloxScriptSecurity. They live in `default.project.json` and need a rebuilt place. Rojo 7.7 builds the `Terrain` node's properties and a `Clouds` child (checked with a test project).

## Global Constraints

- **Spec §6:** "Map is designed for the rolling chase: gentle slopes, wide lanes, a few obstacles to juke around." The flat ruling overrides "gentle slopes" for the play surface.
- **Spec §6:** "Boundary line: a visible painted curb around the base district." The district and curb stay as they are.
- **Spec §7:** "Each zone has 8 to 14 nests."
- **Performance (§20, §22):** "target 60 fps on mid-range phones with 20 players"; "Mobile-first performance budget is a launch gate, not a polish item." The part count may not grow by more than 15% over the Task 0 baseline. Plan 3 measures on a phone.
- **Assets (user ruling 2026-10-04):** engine built-ins and Roblox-official or licensed assets only. Terrain, Clouds and lighting are engine built-ins, and no new asset ids are added.
- **Scenery never collides.** The only exceptions are the invisible `FieldWall` and each plot's `CottageBlock`.
- **The map is built by code at server start.** Nothing hand-built in Studio is saved, and the land is no exception.
- **Chonk models are untouched:** art is paused.
- **Repository:** commit and push only when the user asks. Never add a `Co-Authored-By` trailer. Scan before any commit. `README.md` and `codex/HANDOFF.md` change in the same push. `.luau`, `.json` and `.toml` files are written with LF line endings.

## Review Focus

1. **An old built place, or `rojo serve` on one, still has the flat Baseplate.** The land must replace it, so no slab shows. Task 3's probe checks that no `Baseplate` remains. The open Studio place has one today, so the check starts red.
2. **A player who joins while the land is still being written.** They must never fall through. Task 3: chunks go nearest-first (Lune), `Main` admits players only after the land is down, and the probe compares `LandReadyAt` with `PlayersAdmittedAt`.
3. **Anything standing in the field floating or buried after the change.** Task 4's probe measures every dressing piece, hedge and nest against y = 0, and every rim tree against `Ground.height`.
4. **Walking into the uneven edge** at its nearest point, its farthest point, and across the pond's gap. The player must be stopped right at the wall. Task 4 and Task 5: `wall_walk.luau`.
5. **Water spilling into the field, or water that can be reached.** Task 5 covers this in Lune (the hollow lies wholly past the wall and its banks stand above the waterline) and with `pond_check.luau` (no liquid inside the wall).

---

### Task 0: Baseline and probe tooling

**Files (local, git-ignored):**
- Create: `.claude/tools/studio/views.luau`, `land_check.luau`, `world_check.luau`, `wall_walk.luau`, `pond_check.luau`
- Create: `.superpowers/sdd/2026-10-04-big-uneven-map/checks.sh` and `progress.md`

- [ ] **Step 1: Write the probes.** The probes are the five files under "Probe sources" at the end of this plan. Each returns one line, which starts with `PASS` or `FAIL`. `views.luau` prints `name=startMs:holdMs` marks for `pick.py`.
- [ ] **Step 2: Write the gate.** `checks.sh <task>` runs the headless suite, then that task's probes:

```bash
#!/usr/bin/env bash
# Per-task gate for plan 2026-10-04-big-uneven-map: the headless suite, then that task's Studio
# probes (play mode, bridge running). Usage: checks.sh <task 1-6>
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
export PATH="$HOME/.rokit/bin:$PATH"
ST="python .claude/tools/studio/st.py"
stylua --check src tests
selene src | tail -3
lune run tests/run | tail -1
rojo build default.project.json -o build/prototype.rbxl | tail -1
probe() { out=$($ST lua "$1" ".claude/tools/studio/$2.luau" 2>&1 | tail -1); echo "$out"; echo "$out" | grep -q "PASS"; }
case "$1" in
	1 | 2) ;;
	3) probe Server land_check ;;
	4) probe Server land_check && probe Server world_check && probe Server wall_walk ;;
	5) probe Server pond_check && probe Server wall_walk ;;
	6) probe Server land_check && probe Server world_check ;;
esac
```

- [ ] **Step 3: Record the baseline** on the current build. Run `perf_probe.luau` on the Client and note the parts and shadow casters in `progress.md`. Then capture the views with `burst.ps1` in the background (`-Seconds 25`) while running `views.luau` on the Client, and pick the frames with `pick.py` into the scratchpad `before/` folder.

---

### Task 1: The uneven edge and the wider nest band

**Files:**
- Modify: `src/shared/Config.luau` (`Config.Zones[1].nestCount`, `Config.Base`, new `Config.Map`)
- Modify: `src/shared/Layout.luau`
- Test: `tests/Layout.spec.luau`

**Interfaces:**
- Produces: `Layout.outlineRadius(angle: number): number`, where `angle` is `math.atan2(z, x)`.
- Produces: `Layout.isInsideField(x: number, z: number, margin: number): boolean`, with the margin measured along the radius.
- Produces: `Config.Map.outline = { mean: number, harmonics: { { k, amplitude, phase } } }`.

- [ ] **Step 1: Write the failing tests.** In `tests/Layout.spec.luau`, the obstacle test now bounds by the outline:

```lua
		T.expectTrue(
			d > Config.Base.curbRadius + 10 and Layout.isInsideField(o.x, o.z, 20 - 1e-6),
			"obstacle band " .. i
		)
```

and these tests go before `return {}`:

```lua
T.test("outline: an uneven ring with no jumps, the same every time", function()
	local outline = Config.Map.outline
	local reach = 0
	for _, h in outline.harmonics do
		reach += h.amplitude
	end
	local low, high = math.huge, 0
	local previous = Layout.outlineRadius(0)
	for i = 1, 3600 do
		local r = Layout.outlineRadius(2 * math.pi * i / 3600)
		low, high = math.min(low, r), math.max(high, r)
		T.expectTrue(math.abs(r - previous) < 1, `jump at bearing step {i}`)
		previous = r
	end
	T.expectTrue(low >= outline.mean * (1 - reach) - 1e-6, `pinched to {low}`)
	T.expectTrue(high <= outline.mean * (1 + reach) + 1e-6, `bulges to {high}`)
	T.expectTrue(high - low >= outline.mean * 0.1, `too round: {low}..{high}`)
	T.expectEqual(Layout.outlineRadius(1.234), Layout.outlineRadius(1.234))
end)

T.test("isInsideField measures in from the edge along the radius", function()
	local angle = 0.8
	local edge = Layout.outlineRadius(angle)
	local function at(r: number): (number, number)
		return r * math.cos(angle), r * math.sin(angle)
	end
	T.expectTrue(Layout.isInsideField(0, 0, 10), "the centre")
	local x, z = at(edge - 11)
	T.expectTrue(Layout.isInsideField(x, z, 10), "11 in")
	x, z = at(edge - 9)
	T.expectTrue(not Layout.isInsideField(x, z, 10), "9 in")
	x, z = at(edge + 1)
	T.expectTrue(not Layout.isInsideField(x, z, 0), "past the edge")
end)

T.test("every nest and its Mama's patrol ring sit well inside the field", function()
	local margin = Config.Guardian.patrolRadius + Config.Guardian.radius + 10
	for i, n in Layout.nestPositions() do
		T.expectTrue(Layout.isInsideField(n.x, n.z, margin), "nest " .. i)
	end
end)
```

- [ ] **Step 2: Run `lune run tests/run`.** Expected: the four Layout tests fail, because `Config.Map` and `Layout.outlineRadius` do not exist yet.
- [ ] **Step 3: Implement.** In `Config.luau`:
  - Set `nestCount = 12, -- §7 allows 8 to 14; map proposal (plan 2026-10-04-big-uneven-map)`.
  - In `Config.Base`, replace `nestInner`/`nestOuter`/`obstacleCount` with the block below. Keep `fieldOuterRadius = 320` until Task 4.

```lua
	-- The band the nests are spread over. Far nests are a long carry home, so a rookie needs some
	-- Zoomies before they can bring one back (spec §6: "Distance is the early difficulty"). Map
	-- proposal; the numbers behind it are in the big-uneven-map plan.
	nestInner = 150,
	nestOuter = 330,
	fieldOuterRadius = 320,
	obstacleCount = 16,
}

-- The shape of the land (spec §6). The field's edge is a circle bent by a few low harmonics, so it
-- is uneven without pinches or spikes; Layout.outlineRadius reads it. Map proposal, plan
-- docs/superpowers/plans/2026-10-04-big-uneven-map.md.
Config.Map = {
	outline = {
		mean = 440, -- studs from the centre to the boundary wall, on average
		-- Each one bends the circle by `amplitude` of the mean, `k` times round.
		harmonics = {
			{ k = 2, amplitude = 0.07, phase = 0.6 },
			{ k = 3, amplitude = 0.05, phase = 2.2 },
			{ k = 5, amplitude = 0.025, phase = 4.1 },
		},
	},
}
```

In `Layout.luau`, add these before `Layout.plotFrames`:

```lua
-- The field's edge: how far the boundary wall stands from the centre at a bearing (radians, as
-- math.atan2(z, x) gives it). A circle bent by Config.Map.outline's harmonics.
function Layout.outlineRadius(angle: number): number
	local outline = Config.Map.outline
	local f = 1
	for _, h in outline.harmonics do
		f += h.amplitude * math.sin(h.k * angle + h.phase)
	end
	return outline.mean * f
end

-- True when (x, z) is at least `margin` studs inside the field's edge, measured along the radius.
function Layout.isInsideField(x: number, z: number, margin: number): boolean
	return Layout.planarDistance(0, 0, x, z) <= Layout.outlineRadius(math.atan2(z, x)) - margin
end
```

In `Layout.obstaclePositions`, bound the band by the outline at each candidate's bearing:

```lua
	local inner = base.curbRadius + 20
	local obstacles = {}
	local candidate = 0
	while #obstacles < base.obstacleCount and candidate < 1000 do
		candidate += 1
		local angle = candidate * GOLDEN_ANGLE + GOLDEN_ANGLE / 2
		local outer = Layout.outlineRadius(angle) - 20
		local t = (candidate % 7 + 0.5) / 7
		local r = inner + t * (outer - inner)
		local x, z = r * math.cos(angle), r * math.sin(angle)
```

- [ ] **Step 4: Run `bash .superpowers/sdd/2026-10-04-big-uneven-map/checks.sh 1`.** Expected: StyLua and Selene clean, and `93 passed, 0 failed`.

---

### Task 2: The height of the land

**Files:**
- Create: `src/shared/Ground.luau`
- Modify: `src/shared/Config.luau` (more of `Config.Map`)
- Test: `tests/Ground.spec.luau`, registered in `tests/run.luau`

**Interfaces:**
- Consumes: `Layout.outlineRadius`, `Layout.isInBase`, `Layout.nestPositions`, `Layout.planarDistance`.
- Produces: `Ground.height(x, z): number` (0 inside the outline), `Ground.slope(x, z): number` (rise over run) and `Ground.material(x, z, slope): string`. The materials are `"Pavement" | "Ground" | "Rock" | "LeafyGrass" | "Grass"`, and Task 5 adds `"Mud"` and `"Sand"`.

- [ ] **Step 1: Write the failing test** `tests/Ground.spec.luau`. It is the final file listed under "Ground.spec.luau" in Task 5, without the pond parts: no `inPondGap` (the rim assertion is unconditional), and no Mud or Sand lines in the materials test. Register it in `tests/run.luau` after `TouchLayout`:

```lua
	{
		name = "Ground",
		load = function()
			require("./Ground.spec")
		end,
	},
```

- [ ] **Step 2: Run `lune run tests/run`.** Expected: `FAIL Ground (load)`, because the module does not exist yet.
- [ ] **Step 3: Implement.** Append to `Config.Map`:

```lua
	-- Hills past the wall. The rim climbs from the wall to its crest `crest` studs out and falls
	-- away behind it; the ridge climbs from `start` studs out over `rise` studs and stays up.
	rim = {
		height = 34,
		crest = 75,
		vary = { { k = 4, amplitude = 7, phase = 0.7 }, { k = 7, amplitude = 4, phase = 2.9 } },
	},
	ridge = {
		height = 125,
		start = 140,
		rise = 120,
		vary = { { k = 3, amplitude = 18, phase = 1.9 }, { k = 5, amplitude = 12, phase = 5.2 } },
	},
	-- The land stops this far past the wall, behind the ridge's crest where nobody sees the cut.
	extent = 300,
	-- The bottom of the Terrain, a multiple of 4 with room for a full voxel under the lowest ground.
	floor = -16,
	-- Faces steeper than this, as rise over run, are bare rock.
	rockSlope = 0.85,
	-- The radius of bare earth round every nest.
	nestDirt = 7.5,
```

`src/shared/Ground.luau` (the pre-pond form; Task 5 replaces the file):

```lua
-- The height of the land everywhere on the map (spec §6). Pure and deterministic: the server writes
-- Terrain from it, and the scenery planted on the hills asks it for a Y.
--
-- Everything inside the boundary wall (Layout.outlineRadius) is dead flat at y = 0: the district,
-- the field, the nests (user ruling 2026-10-04: a flat surface, so nothing floats). The land only
-- rises past the wall, where nothing is carried or dropped:
--   rim    hills climbing from the wall to a crest and falling away behind it
--   ridge  taller hills further out that close the horizon
local Config = require("./Config")
local Layout = require("./Layout")

local Ground = {}

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- A raised-cosine hump: 1 at offset 0, easing to 0 at |offset| = half and flat beyond.
local function hump(offset: number, half: number): number
	if math.abs(offset) >= half then
		return 0
	end
	return 0.5 + 0.5 * math.cos(math.pi * offset / half)
end

type Harmonic = { k: number, amplitude: number, phase: number }

local function harmonics(list: { Harmonic }, angle: number): number
	local v = 0
	for _, h in list do
		v += h.amplitude * math.sin(h.k * angle + h.phase)
	end
	return v
end

-- The rim and the ridge, `u` studs past the wall at this bearing.
local function beyond(angle: number, u: number): number
	local map = Config.Map
	local rim = map.rim.height + harmonics(map.rim.vary, angle)
	local ridge = map.ridge.height + harmonics(map.ridge.vary, angle)
	return rim * hump(u - map.rim.crest, map.rim.crest) + ridge * smoothstep((u - map.ridge.start) / map.ridge.rise)
end

-- The surface height at (x, z).
function Ground.height(x: number, z: number): number
	local angle = math.atan2(z, x)
	local u = math.sqrt(x * x + z * z) - Layout.outlineRadius(angle)
	if u <= 0 then
		return 0
	end
	return beyond(angle, u)
end

-- How steep the ground is at (x, z), as rise over run: 0 is flat, 1 is 45 degrees.
function Ground.slope(x: number, z: number): number
	local dx = (Ground.height(x + 1, z) - Ground.height(x - 1, z)) / 2
	local dz = (Ground.height(x, z + 1) - Ground.height(x, z - 1)) / 2
	return math.sqrt(dx * dx + dz * dz)
end

local nestSpots: { { x: number, z: number } }? = nil

-- The terrain material for the column at (x, z), given its slope there. A name rather than an
-- Enum.Material keeps this pure; the server maps the names.
function Ground.material(x: number, z: number, slope: number): string
	local map = Config.Map
	-- Under the district's paving. Not grass, so no grass blades poke up through the plaza.
	if Layout.isInBase(x, z) then
		return "Pavement"
	end
	if nestSpots == nil then
		nestSpots = Layout.nestPositions()
	end
	for _, n in nestSpots :: { { x: number, z: number } } do
		if Layout.planarDistance(x, z, n.x, n.z) < map.nestDirt then
			return "Ground"
		end
	end
	if slope > map.rockSlope then
		return "Rock"
	end
	-- Loose patches of a deeper, leafier grass, so the field is not one flat green.
	local patch = math.sin(x / 41 + 1.7) * math.sin(z / 53 + 0.4) + 0.5 * math.sin((x + z) / 29)
	if patch > 0.55 then
		return "LeafyGrass"
	end
	return "Grass"
end

return Ground
```

- [ ] **Step 4: Run `checks.sh 2`.** Expected: clean, and `97 passed, 0 failed`.

---

### Task 3: Writing the land

**Files:**
- Create: `src/shared/LandGrid.luau`, `src/server/Landscape.luau`
- Modify: `src/server/Main.server.luau`, `default.project.json` (the Baseplate goes)
- Test: `tests/LandGrid.spec.luau`, registered in `tests/run.luau`; probe `land_check.luau`

**Interfaces:**
- Consumes: `Ground.height`, `Ground.material`, `Layout.outlineRadius`, `Config.Map.extent`, `Config.Map.floor`.
- Produces: `LandGrid.VOXEL = 4`, `LandGrid.CHUNK = 16` and `LandGrid.LIFT = 2`.
- Produces: `LandGrid.hasLand(x, z)`, `LandGrid.halfSide()`, `LandGrid.chunks(): { Chunk }` (nearest first) and `LandGrid.voxels(chunk, toMaterial): ChunkVoxels`.
- Produces: `Landscape.build()`, which sets the workspace attributes `LandReady`, `LandReadyAt` and `LandSeconds`. `Main` sets `PlayersAdmittedAt`.

- [ ] **Step 1: Write the failing test** `tests/LandGrid.spec.luau`. Use the file under "LandGrid.spec.luau" at the end of this plan. Register it after `Ground`.
- [ ] **Step 2: Run `lune run tests/run`.** Expected: `FAIL LandGrid (load)`.
- [ ] **Step 3: Implement `src/shared/LandGrid.luau`.** Use the final file at the end of this plan, without the pond parts:
  - no `liquid` field in `ChunkVoxels`
  - no `water`, `wet` or `anyWet` in `voxels`
  - no `li` arrays
  - a return of `{ layers = layers, material = material, solid = solid }`
- [ ] **Step 4: Implement `src/server/Landscape.luau`.** Use the final file at the end of this plan, without `Mud` and `Sand`, the water look, and the `LiquidOccupancy` channel.
- [ ] **Step 5: Boot order in `Main.server.luau`.**
  - Add `local Landscape = require(Server.Landscape)` before `Props`.
  - Right after `Remotes.createAll()`, add:

```lua
-- The land is written in the background while the scenery packs download, nearest the district
-- first. Nobody is let in until all of it is down (below).
local landReady = false
task.spawn(function()
	local ok, err = pcall(Landscape.build)
	if not ok then
		warn(`[Landscape] the land was not written: {err}`)
	end
	landReady = true
end)
```

  - Replace the bare `PlayerState.start()` at the end with:

```lua
while not landReady do
	task.wait()
end
workspace:SetAttribute("PlayersAdmittedAt", os.clock())
PlayerState.start()
```

- [ ] **Step 6: Delete the `"Baseplate"` entry** under `Workspace` in `default.project.json`. Keep `SpawnLocation`.
- [ ] **Step 7: Headless, then Studio.** Run `checks.sh 3` with the bridge running. First stop play, then run `sync.py`, then start play.
  - Expected: `PASS land_check: field max ≤ 0.05 …`
  - The probe starts red on the open place: it still has the Baseplate and no land.
  - Between this task and Task 4, the scenery still uses the old 320 band. That is expected.

---

### Task 4: The map on the new land

**Files:**
- Modify: `src/server/World.luau`, `src/shared/Config.luau` (`fieldOuterRadius` goes)
- Probes: `world_check.luau`, `wall_walk.luau`

- [ ] **Step 1: Run the probes on the Task 3 build.** Expected: `FAIL world_check`, with 72 wall segments, part hills present, and the apron present.
- [ ] **Step 2: Edit `World.luau`.**
  - Add `local Ground = require(ReplicatedStorage.Shared.Ground)`.
  - Add the constants `WALL_SEGMENTS = 144`, `WALL_SINK = 10`, `RIM_TREES = 170` and `DRESSING = 460`, with their comments.
  - Delete `HILL` and `RIDGE`.
  - Replace `boundary()` with the version below. The final version at the end of this plan adds the pond's tree skip and fence in Task 5.

```lua
-- The field's edge. Past the wall the land itself rises into hills (Ground: the rim, then the
-- ridge), so the field reads as a valley rather than as "the level stopped here".
--
-- One invisible wall along the outline does all of the containing. Every visible piece stays
-- CanCollide false, so nothing can wedge a player, and the wall is invisible to every raycast.
local function boundary(root: Instance, rng: Random)
	local fence = Instance.new("Folder")
	fence.Name = "Boundary"
	fence.Parent = root

	local function edge(angle: number): Vector3
		local r = Layout.outlineRadius(angle)
		return Vector3.new(r * math.cos(angle), 0, r * math.sin(angle))
	end
	for i = 1, WALL_SEGMENTS do
		local a = edge(2 * math.pi * (i - 1) / WALL_SEGMENTS)
		local b = edge(2 * math.pi * i / WALL_SEGMENTS)
		local middle = (a + b) / 2 + Vector3.new(0, WALL_HEIGHT / 2 - WALL_SINK, 0)
		Models.part({
			Name = "FieldWall",
			Size = Vector3.new(4, WALL_HEIGHT, (b - a).Magnitude + 2),
			CFrame = CFrame.lookAt(middle, middle + (b - a)),
			Transparency = 1,
			CanQuery = false, -- solid to a player, invisible to every raycast
			Parent = fence,
		})
	end

	-- Woods up the rim's near slope and over its crest, so it reads as wooded hills rather than a
	-- bank. Never on a rock face.
	for i = 1, RIM_TREES do
		local angle = 2 * math.pi * (i - 0.5) / RIM_TREES + (rng:NextNumber() - 0.5) * 0.02
		local r = Layout.outlineRadius(angle) + 8 + rng:NextNumber() * 92
		local x, z = r * math.cos(angle), r * math.sin(angle)
		local slope = Ground.slope(x, z)
		if slope < 0.6 then
			-- Sunk a little extra, and more on a slope, so no trunk shows daylight: Roblox draws
			-- crests and hollows up to half a stud below Ground.height (measured 2026-10-05).
			local ground = Ground.height(x, z) - 0.3 - 1.5 * slope
			tree(Vector3.new(x, ground, z), 1 + rng:NextNumber() * 0.6, rng, fence, WOODS)
		end
	end

	-- The whole boundary sits past the shadow map's useful range, so nothing in it casts.
	for _, d in fence:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
end
```

  - In `World.build`, delete the `BaseApron` disc, since the Terrain's own grass replaces it. Change the comment to say "The grass round it is the Terrain's own (Landscape)".
  - Make the dressing loop run `for candidate = 1, DRESSING`, with its band bounded by the outline:

```lua
	local inner = base.curbRadius + 14
	local placed = 0
	for candidate = 1, DRESSING do
		local angle = candidate * GOLDEN_ANGLE
		local t = (candidate % 11 + 0.5) / 11
		local r = inner + t * (Layout.outlineRadius(angle) - 6 - inner)
		local x, z = r * math.cos(angle), r * math.sin(angle)
```

- [ ] **Step 3: Delete `fieldOuterRadius = 320,`** from `Config.Base`. No caller is left.
- [ ] **Step 4: Run `checks.sh 4`.** Expected:
  - `PASS world_check`, with 144 walls under 1.5 off the outline, 100 or more rim trees, nothing floating, and a part count within 15% of the baseline.
  - `PASS wall_walk`: the player stops within 8 studs inside the wall at both the near and far bearings.

---

### Task 5: The pond

**Files:**
- Modify: `src/shared/Config.luau` (`Config.Map.pond`), `src/shared/Ground.luau` (replaced by the final file), `src/shared/LandGrid.luau` (water channel), `src/server/Landscape.luau`, `src/server/World.luau`
- Test: `tests/Pond.spec.luau` (new, registered after `LandGrid`), `tests/Ground.spec.luau` (rim gap, Mud and Sand); probe `pond_check.luau`

**Interfaces:**
- Produces: `Ground.pond(): Pond?`, where `Pond = { x, z, radius, level, plateau }`.
- Produces: `ChunkVoxels.liquid` (present only in wet chunks, with no lift).

- [ ] **Step 1: Write the failing tests.**
  - `tests/Pond.spec.luau` is the final file at the end of this plan.
  - In `Ground.spec.luau`, add `inPondGap`, guard the rim assertion with it, and add the Mud and Sand lines (the final file at the end).
  - Expected: Pond load fails, since `Ground.pond` is nil.
- [ ] **Step 2: Implement.**
  - Append `pond = { … }` to `Config.Map`. The block, with its comment, is in the final `Config.Map` at the end.
  - Replace `Ground.luau` with the final file.
  - Make the `LandGrid.voxels` water additions. Every hunk is marked in the final file: `water`, `wet`, `anyWet`, `top` raised to the waterline, `li` filled to the waterline with no lift, and `liquid` returned.
  - In `Landscape`, add `Mud` and `Sand` to `MATERIALS` and `COLORS`, add the water look, and add the `LiquidOccupancy` channel when `v.liquid` is set.
  - In `World.boundary`, skip trees in the hollow and build the fence across the gap (the final `boundary` at the end).
- [ ] **Step 3: Run `checks.sh 5`.** Expected:
  - `104 passed`
  - `PASS pond_check`: the water lies within 0.1 of the waterline, with mud under it, sand round it, and no wet voxels inside the wall.
  - `PASS wall_walk`, including the pond bearing.

---

### Task 6: Lighting and sky

**Files:** `default.project.json`, `src/server/World.luau` (the mesh clouds go)

- [ ] **Step 1: Edit `default.project.json`.**
  - Under `Lighting.$properties`, set `"Technology": "Future"` and `"ClockTime": 14.6`.
  - Under `Atmosphere`, set `"Density": 0.2`, `"Offset": 0.12` and `"Haze": 0.4`. The other values stay.
  - Under `Workspace`, add:

```json
			"Terrain": {
				"$properties": {
					"Decoration": true,
					"GrassLength": 0.6
				},
				"Clouds": {
					"$className": "Clouds",
					"$properties": {
						"Cover": 0.45,
						"Density": 0.35,
						"Color": [1, 1, 1]
					}
				}
			},
```

- [ ] **Step 2: Remove the mesh clouds from `World.luau`.** Delete the `CLOUDS` list, the `clouds()` function and the `clouds(root, rng)` call. The dynamic clouds replace them.
- [ ] **Step 3: Rebuild and reopen.** These properties cannot be set by script, so the open place has to be replaced.
  - Run `rojo build`.
  - Ask the user once before reopening Studio on `build/prototype.rbxl`.
  - Put the window back at the user's size with `winsize.ps1` (x 699, y 108, 1632×1161).
  - Run `checks.sh 6`.
- [ ] **Step 4: Capture and judge.** Run `views.luau` with `burst.ps1` again into `after/`. Compare with `before/`.
  - **Acceptance, by eye:**
    - The plaza's colours are not washed out (no grey haze).
    - Grass blades show in the field but not through the paving.
    - The rim reads as wooded hills, and the far ridge as bluer and further away.
    - The pond reads as water through the gap, with the fence in front.
    - The sky has soft clouds.
    - Nests, hedges and trees sit on the ground.
  - If the clouds clash with the low-poly look, put the mesh clouds back further out (radius 600 to 900, height 220 to 300) and record it.
- [ ] **Step 5: Run `perf_probe`.** Record the parts, the shadow casters and the lights against the baseline.

---

### Task 7: Record it

- [ ] **Step 1:** Add a dated top section to `codex/HANDOFF.md`. Cover what changed, the measured terrain facts (the lift, water, Rock), what was verified (tests, probes, captures, counts), what was not (phones, two players), and the next step (plan 3).
- [ ] **Step 2:** In `codex/PROJECT_CONTEXT.md`, record:
  - the ruling "the play surface stays flat" (2026-10-04)
  - the approved map numbers, with the rookie trade-off
- [ ] **Step 3:** Update `README.md` only when pushing: "The map is bigger, with an uneven edge, wooded hills, a pond and a new sky; the ground you play on stays flat."

---

## Final sources

These are the files as they stand after Task 5; Tasks 2 and 3 use the forms described in their steps. All of them passed `lune run tests/run` (104 tests), `selene src` and `stylua --check`, and the probes passed in Studio (2026-10-05). The rulings made while building are in the plan's ledger; the code here includes them.

### `src/shared/Config.luau`: the final `Config.Map`

```lua
Config.Map = {
	outline = {
		mean = 440, -- studs from the centre to the boundary wall, on average
		-- Each one bends the circle by `amplitude` of the mean, `k` times round.
		harmonics = {
			{ k = 2, amplitude = 0.07, phase = 0.6 },
			{ k = 3, amplitude = 0.05, phase = 2.2 },
			{ k = 5, amplitude = 0.025, phase = 4.1 },
		},
	},
	-- Hills past the wall. The rim climbs from the wall to its crest `crest` studs out and falls
	-- away behind it; the ridge climbs from `start` studs out over `rise` studs and stays up.
	rim = {
		height = 34,
		crest = 75,
		vary = { { k = 4, amplitude = 7, phase = 0.7 }, { k = 7, amplitude = 4, phase = 2.9 } },
	},
	ridge = {
		height = 125,
		start = 140,
		rise = 120,
		vary = { { k = 3, amplitude = 18, phase = 1.9 }, { k = 5, amplitude = 12, phase = 5.2 } },
	},
	-- The land stops this far past the wall, behind the ridge's crest where nobody sees the cut.
	extent = 300,
	-- The bottom of the Terrain, a multiple of 4 with room for a full voxel under the lowest ground.
	floor = -16,
	-- Faces steeper than this, as rise over run, are bare rock.
	rockSlope = 0.85,
	-- The radius of bare earth round every nest.
	nestDirt = 7.5,
	-- A small lake in a hollow past the wall, seen from the field through a dip in the rim. Nobody
	-- can reach it. `beyond` is how far past the wall its centre lies; the water is `radius` across
	-- the middle, `depth` deep at the centre and `bankRise` below the flat bank round it, which is
	-- `shore` wide; the land eases back up to its own height over `blend`. The rim dips by
	-- `gapDepth` of its height within `gapHalfAngle` radians of the pond's bearing.
	pond = {
		angle = 2.25,
		beyond = 95,
		radius = 40,
		depth = 7,
		bankRise = 1.5,
		shore = 10,
		blend = 22,
		gapHalfAngle = 0.24,
		gapDepth = 0.85,
	},
}
```

### `src/shared/Ground.luau`

```lua
-- The height of the land everywhere on the map (spec §6). Pure and deterministic: the server writes
-- Terrain from it, and the scenery planted on the hills asks it for a Y.
--
-- Everything inside the boundary wall (Layout.outlineRadius) is dead flat at y = 0: the district,
-- the field, the nests (user ruling 2026-10-04: a flat surface, so nothing floats). The land only
-- rises past the wall, where nothing is carried or dropped:
--   rim    hills climbing from the wall to a crest and falling away behind it
--   ridge  taller hills further out that close the horizon
--   pond   a small lake in a hollow past the wall, seen through a dip in the rim (Map.pond)
local Config = require("./Config")
local Layout = require("./Layout")

local Ground = {}

local TAU = 2 * math.pi

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- A raised-cosine hump: 1 at offset 0, easing to 0 at |offset| = half and flat beyond.
local function hump(offset: number, half: number): number
	if math.abs(offset) >= half then
		return 0
	end
	return 0.5 + 0.5 * math.cos(math.pi * offset / half)
end

-- The signed difference between two bearings, in -pi..pi.
local function bearingDiff(a: number, b: number): number
	return (a - b + math.pi) % TAU - math.pi
end

type Harmonic = { k: number, amplitude: number, phase: number }

local function harmonics(list: { Harmonic }, angle: number): number
	local v = 0
	for _, h in list do
		v += h.amplitude * math.sin(h.k * angle + h.phase)
	end
	return v
end

-- The rim and the ridge, `u` studs past the wall at this bearing.
local function beyond(angle: number, u: number): number
	local map = Config.Map
	local rim = map.rim.height + harmonics(map.rim.vary, angle)
	-- The rim dips where the pond is, so the water can be seen from the field.
	local spec = map.pond
	if spec then
		rim *= 1 - spec.gapDepth * hump(bearingDiff(angle, spec.angle), spec.gapHalfAngle)
	end
	local ridge = map.ridge.height + harmonics(map.ridge.vary, angle)
	return rim * hump(u - map.rim.crest, map.rim.crest) + ridge * smoothstep((u - map.ridge.start) / map.ridge.rise)
end

-- The land before the pond's hollow is cut into it.
local function natural(x: number, z: number): number
	local angle = math.atan2(z, x)
	local u = math.sqrt(x * x + z * z) - Layout.outlineRadius(angle)
	if u <= 0 then
		return 0
	end
	return beyond(angle, u)
end

export type Pond = { x: number, z: number, radius: number, level: number, plateau: number }
local pond: Pond? = nil

-- The lake past the wall, or nil when Config.Map.pond is not set. It lies in a hollow: the land
-- round it eases down to a flat bank at `plateau`, just under the lowest natural height on the
-- hollow's rim, and the water lies `bankRise` below the bank.
function Ground.pond(): Pond?
	local spec = Config.Map.pond
	if not spec then
		return nil
	end
	if pond == nil then
		local r = Layout.outlineRadius(spec.angle) + spec.beyond
		local x, z = r * math.cos(spec.angle), r * math.sin(spec.angle)
		local outer = spec.radius + spec.shore + spec.blend
		local lowest = math.huge
		for i = 1, 180 do
			local a = TAU * i / 180
			lowest = math.min(lowest, natural(x + outer * math.cos(a), z + outer * math.sin(a)))
		end
		local plateau = lowest - 0.25
		pond = { x = x, z = z, radius = spec.radius, level = plateau - spec.bankRise, plateau = plateau }
	end
	return pond
end

-- The surface height at (x, z).
function Ground.height(x: number, z: number): number
	local h = natural(x, z)
	local water = Ground.pond()
	if water then
		local spec = Config.Map.pond
		local d = Layout.planarDistance(x, z, water.x, water.z)
		if d < water.radius then
			local t = d / water.radius
			return water.level - spec.depth * (1 - t * t)
		elseif d < water.radius + spec.shore then
			return water.level + spec.bankRise * smoothstep((d - water.radius) / spec.shore)
		elseif d < water.radius + spec.shore + spec.blend then
			local t = smoothstep((d - water.radius - spec.shore) / spec.blend)
			return water.plateau + math.max(h - water.plateau, 0) * t
		end
	end
	return h
end

-- How steep the ground is at (x, z), as rise over run: 0 is flat, 1 is 45 degrees.
function Ground.slope(x: number, z: number): number
	local dx = (Ground.height(x + 1, z) - Ground.height(x - 1, z)) / 2
	local dz = (Ground.height(x, z + 1) - Ground.height(x, z - 1)) / 2
	return math.sqrt(dx * dx + dz * dz)
end

local nestSpots: { { x: number, z: number } }? = nil

-- The terrain material for the column at (x, z), given its slope there. A name rather than an
-- Enum.Material keeps this pure; the server maps the names.
function Ground.material(x: number, z: number, slope: number): string
	local map = Config.Map
	-- Under the district's paving. Not grass, so no grass blades poke up through the plaza.
	if Layout.isInBase(x, z) then
		return "Pavement"
	end
	local water = Ground.pond()
	if water then
		local d = Layout.planarDistance(x, z, water.x, water.z)
		if d < water.radius then
			return "Mud"
		elseif d < water.radius + map.pond.shore then
			return "Sand"
		end
	end
	if nestSpots == nil then
		nestSpots = Layout.nestPositions()
	end
	for _, n in nestSpots :: { { x: number, z: number } } do
		if Layout.planarDistance(x, z, n.x, n.z) < map.nestDirt then
			return "Ground"
		end
	end
	if slope > map.rockSlope then
		return "Rock"
	end
	-- Loose patches of a deeper, leafier grass, so the field is not one flat green.
	local patch = math.sin(x / 41 + 1.7) * math.sin(z / 53 + 0.4) + 0.5 * math.sin((x + z) / 29)
	if patch > 0.55 then
		return "LeafyGrass"
	end
	return "Grass"
end

return Ground
```

### `src/shared/LandGrid.luau`

```lua
-- Cuts the land into Terrain chunks and fills each chunk's voxel arrays from Ground. Pure, so Lune
-- checks exactly what the server writes; Landscape only turns the names into Enum.Material and
-- writes them with Terrain:WriteVoxelChannels.
--
-- A voxel is 4 studs. Each column is a stack of voxels from Config.Map.floor up: full voxels, then
-- one part-filled voxel, then air. Roblox draws a column's surface half a voxel above the top of what
-- is filled (measured in Studio on 2026-10-04: +2.00 studs at every fill level, on every smooth
-- material), so each column is filled to LIFT below Ground.height and drawn exactly at it. Water is
-- drawn exactly at its filled height, so the pond is filled to its waterline with no lift.
local Config = require("./Config")
local Ground = require("./Ground")
local Layout = require("./Layout")

local LandGrid = {}

LandGrid.VOXEL = 4
LandGrid.CHUNK = 16 -- columns along each side of a chunk: 64 studs
LandGrid.LIFT = 2 -- how far above the filled height Roblox draws the surface

local VOXEL, CHUNK, LIFT = LandGrid.VOXEL, LandGrid.CHUNK, LandGrid.LIFT
local SPAN = VOXEL * CHUNK

export type Chunk = { x: number, z: number } -- the chunk's lower corner, in studs

export type ChunkVoxels = {
	layers: number, -- voxel layers from Config.Map.floor up
	material: { { { any } } }, -- [x][y][z], from toMaterial
	solid: { { { number } } }, -- [x][y][z], 0 to 1
	liquid: { { { number } } }?, -- [x][y][z], 0 to 1; only when the chunk holds water
}

-- True when the column centred on (x, z) holds land: inside the field's edge, or in the hills past it.
function LandGrid.hasLand(x: number, z: number): boolean
	return Layout.planarDistance(0, 0, x, z) <= Layout.outlineRadius(math.atan2(z, x)) + Config.Map.extent
end

-- Half the side of the square the land is written in, rounded up to whole chunks.
function LandGrid.halfSide(): number
	local far = 0
	for i = 0, 719 do
		far = math.max(far, Layout.outlineRadius(2 * math.pi * i / 720))
	end
	return math.ceil((far + Config.Map.extent) / SPAN) * SPAN
end

-- How close a chunk comes to the centre of the map.
local function nearest(chunk: Chunk): number
	local x = math.clamp(0, chunk.x, chunk.x + SPAN)
	local z = math.clamp(0, chunk.z, chunk.z + SPAN)
	return Layout.planarDistance(0, 0, x, z)
end

-- Every chunk with land in it, nearest the centre first, so the district is written before the
-- field and the field before the hills.
function LandGrid.chunks(): { Chunk }
	local half = LandGrid.halfSide()
	local list = {}
	for x = -half, half - SPAN, SPAN do
		for z = -half, half - SPAN, SPAN do
			local chunk = { x = x, z = z }
			local any = false
			-- The land never reaches `half` from the centre, so the square's far corners are skipped.
			if nearest(chunk) <= half then
				for i = 1, CHUNK do
					for k = 1, CHUNK do
						if LandGrid.hasLand(x + (i - 0.5) * VOXEL, z + (k - 0.5) * VOXEL) then
							any = true
							break
						end
					end
					if any then
						break
					end
				end
			end
			if any then
				table.insert(list, chunk)
			end
		end
	end
	table.sort(list, function(a: Chunk, b: Chunk): boolean
		local da, db = nearest(a), nearest(b)
		if da ~= db then
			return da < db
		end
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.z < b.z
	end)
	return list
end

-- The voxel arrays for one chunk. `toMaterial` turns Ground's material names, and "Air", into what
-- is written: Enum.Material on the server, the names themselves in tests.
function LandGrid.voxels(chunk: Chunk, toMaterial: (string) -> any): ChunkVoxels
	local floor = Config.Map.floor
	local function centre(i: number, k: number): (number, number)
		return chunk.x + (i - 0.5) * VOXEL, chunk.z + (k - 0.5) * VOXEL
	end
	-- Heights on the chunk's columns and a one-column border round them, for each column's slope.
	local heights = {}
	for i = 0, CHUNK + 1 do
		local row = {}
		for k = 0, CHUNK + 1 do
			row[k] = Ground.height(centre(i, k))
		end
		heights[i] = row
	end
	local water = Ground.pond()
	local top = floor + VOXEL
	local land, wet = {}, {}
	local anyWet = false
	for i = 1, CHUNK do
		land[i], wet[i] = {}, {}
		for k = 1, CHUNK do
			local x, z = centre(i, k)
			land[i][k] = LandGrid.hasLand(x, z)
			if land[i][k] then
				top = math.max(top, heights[i][k] - LIFT)
			end
			wet[i][k] = land[i][k] and water ~= nil and Layout.planarDistance(x, z, water.x, water.z) < water.radius
			if wet[i][k] then
				anyWet = true
				top = math.max(top, (water :: Ground.Pond).level)
			end
		end
	end
	local layers = math.ceil((top - floor) / VOXEL)

	local air = toMaterial("Air")
	local material, solid = table.create(CHUNK), table.create(CHUNK)
	local liquid = if anyWet then table.create(CHUNK) else nil
	for i = 1, CHUNK do
		local mi, si = table.create(layers), table.create(layers)
		local li = if liquid then table.create(layers) else nil
		for j = 1, layers do
			mi[j], si[j] = table.create(CHUNK), table.create(CHUNK)
			if li then
				li[j] = table.create(CHUNK)
			end
		end
		for k = 1, CHUNK do
			local columnMaterial = air
			if land[i][k] then
				local dx = (heights[i + 1][k] - heights[i - 1][k]) / (2 * VOXEL)
				local dz = (heights[i][k + 1] - heights[i][k - 1]) / (2 * VOXEL)
				local x, z = centre(i, k)
				columnMaterial = toMaterial(Ground.material(x, z, math.sqrt(dx * dx + dz * dz)))
			end
			for j = 1, layers do
				local bottom = floor + (j - 1) * VOXEL
				local fill = if land[i][k] then math.clamp((heights[i][k] - LIFT - bottom) / VOXEL, 0, 1) else 0
				mi[j][k] = if fill > 0 then columnMaterial else air
				si[j][k] = fill
				if li then
					local level = if wet[i][k] then (water :: Ground.Pond).level else bottom
					li[j][k] = math.clamp((level - bottom) / VOXEL, 0, 1)
				end
			end
		end
		material[i], solid[i] = mi, si
		if liquid then
			liquid[i] = li
		end
	end
	return { layers = layers, material = material, solid = solid, liquid = liquid }
end

return LandGrid
```

### `src/server/Landscape.luau`

```lua
-- Writes the land as Terrain when the server starts, from the pure height map in Ground (spec §6).
-- Nothing about the land is saved in the place: every server builds the same land from the same
-- numbers, so the repository stays the one source of truth, as it is for the rest of the map.
--
-- LandGrid cuts the land into chunks, nearest the district first, and fills their voxel arrays;
-- this module names the materials and writes them. It yields between chunks so the server keeps
-- running, and Main lets nobody in until the last chunk is down.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LandGrid = require(ReplicatedStorage.Shared.LandGrid)

local Landscape = {}

-- How long the writer works before it lets a frame pass, in seconds.
local BUDGET = 1 / 60

local MATERIALS: { [string]: Enum.Material } = {
	Air = Enum.Material.Air,
	Grass = Enum.Material.Grass,
	LeafyGrass = Enum.Material.LeafyGrass,
	Ground = Enum.Material.Ground,
	Rock = Enum.Material.Rock,
	Pavement = Enum.Material.Pavement,
	Mud = Enum.Material.Mud,
	Sand = Enum.Material.Sand,
}

-- The colours of the materials Ground uses, set before anything is written. Close to the old
-- Baseplate's grass, so the district's surroundings keep their look.
local COLORS: { [Enum.Material]: Color3 } = {
	[Enum.Material.Grass] = Color3.fromRGB(104, 166, 74),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(92, 148, 64),
	[Enum.Material.Ground] = Color3.fromRGB(150, 114, 80),
	[Enum.Material.Rock] = Color3.fromRGB(140, 136, 128),
	[Enum.Material.Pavement] = Color3.fromRGB(206, 188, 160),
	[Enum.Material.Mud] = Color3.fromRGB(112, 88, 64),
	[Enum.Material.Sand] = Color3.fromRGB(226, 204, 156),
}

local function toMaterial(name: string): Enum.Material
	local material = MATERIALS[name]
	if not material then
		error(`[Landscape] no terrain material for "{name}"`)
	end
	return material
end

function Landscape.build()
	local started = os.clock()
	local terrain = workspace.Terrain
	terrain:Clear()
	-- A place built before the land existed still has the old flat Baseplate. Left in, its top would
	-- show through every hollow in the field.
	local stale = workspace:FindFirstChild("Baseplate")
	if stale then
		stale:Destroy()
	end
	for material, color in COLORS do
		terrain:SetMaterialColor(material, color)
	end
	-- A clear, calm pond.
	terrain.WaterColor = Color3.fromRGB(64, 156, 178)
	terrain.WaterTransparency = 0.45
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.06
	terrain.WaterWaveSpeed = 6

	local VOXEL, CHUNK, floor = LandGrid.VOXEL, LandGrid.CHUNK, Config.Map.floor
	local chunks = LandGrid.chunks()
	local written, slice = 0, os.clock()
	for _, chunk in chunks do
		local v = LandGrid.voxels(chunk, toMaterial)
		local region = Region3.new(
			Vector3.new(chunk.x, floor, chunk.z),
			Vector3.new(chunk.x + CHUNK * VOXEL, floor + v.layers * VOXEL, chunk.z + CHUNK * VOXEL)
		)
		local channels: { [string]: any } = { SolidMaterial = v.material, SolidOccupancy = v.solid }
		if v.liquid then
			channels.LiquidOccupancy = v.liquid
		end
		terrain:WriteVoxelChannels(region, VOXEL, channels)
		written += CHUNK * CHUNK * v.layers
		if os.clock() - slice > BUDGET then
			task.wait()
			slice = os.clock()
		end
	end

	local seconds = os.clock() - started
	workspace:SetAttribute("LandSeconds", math.round(seconds * 100) / 100)
	workspace:SetAttribute("LandReadyAt", os.clock())
	workspace:SetAttribute("LandReady", true)
	print(`[Landscape] {#chunks} chunks, {written} voxels written in {string.format("%.2f", seconds)} s`)
end

return Landscape
```

### src/server/World.luau: the final `boundary`

```lua
-- The field's edge. Past the wall the land itself rises into hills (Ground: the rim, then the
-- ridge), so the field reads as a valley rather than as "the level stopped here".
--
-- One invisible wall along the outline does all of the containing. Every visible piece stays
-- CanCollide false, so nothing can wedge a player, and the wall is invisible to every raycast.
local function boundary(root: Instance, rng: Random)
	local fence = Instance.new("Folder")
	fence.Name = "Boundary"
	fence.Parent = root

	local function edge(angle: number): Vector3
		local r = Layout.outlineRadius(angle)
		return Vector3.new(r * math.cos(angle), 0, r * math.sin(angle))
	end
	for i = 1, WALL_SEGMENTS do
		local a = edge(2 * math.pi * (i - 1) / WALL_SEGMENTS)
		local b = edge(2 * math.pi * i / WALL_SEGMENTS)
		local middle = (a + b) / 2 + Vector3.new(0, WALL_HEIGHT / 2 - WALL_SINK, 0)
		Models.part({
			Name = "FieldWall",
			Size = Vector3.new(4, WALL_HEIGHT, (b - a).Magnitude + 2),
			CFrame = CFrame.lookAt(middle, middle + (b - a)),
			Transparency = 1,
			CanQuery = false, -- solid to a player, invisible to every raycast
			Parent = fence,
		})
	end

	-- Woods up the rim's near slope and over its crest, so it reads as wooded hills rather than a
	-- bank. Never on a rock face, and never in the pond's hollow.
	local water = Ground.pond()
	for i = 1, RIM_TREES do
		local angle = 2 * math.pi * (i - 0.5) / RIM_TREES + (rng:NextNumber() - 0.5) * 0.02
		local r = Layout.outlineRadius(angle) + 8 + rng:NextNumber() * 92
		local x, z = r * math.cos(angle), r * math.sin(angle)
		local slope = Ground.slope(x, z)
		local dry = not water
			or Layout.planarDistance(x, z, water.x, water.z) > water.radius + Config.Map.pond.shore + 6
		if slope < 0.6 and dry then
			-- Sunk a little extra, and more on a slope, so no trunk shows daylight: Roblox draws
			-- crests and hollows up to half a stud below Ground.height (measured 2026-10-05).
			local ground = Ground.height(x, z) - 0.3 - 1.5 * slope
			tree(Vector3.new(x, ground, z), 1 + rng:NextNumber() * 0.6, rng, fence, WOODS)
		end
	end

	-- A low wooden fence along the wall where the rim dips for the pond, so the open view reads as
	-- the field's edge rather than a way out. Scenery: the invisible wall does the stopping.
	local spec = Config.Map.pond
	if spec then
		local posts, half = 22, spec.gapHalfAngle * 0.85
		local previous: Vector3? = nil
		for i = 0, posts do
			local angle = spec.angle - half + 2 * half * i / posts
			local r = Layout.outlineRadius(angle) - 3
			local at = Vector3.new(r * math.cos(angle), 0, r * math.sin(angle))
			prop({
				Name = "FencePost",
				Size = Vector3.new(0.8, 3.6, 0.8),
				CFrame = CFrame.new(at + Vector3.new(0, 1.8, 0)),
				Color = BARK,
				Material = Enum.Material.Wood,
				Parent = fence,
			})
			if previous then
				for _, y in { 1.4, 2.8 } do
					local a, b = previous + Vector3.new(0, y, 0), at + Vector3.new(0, y, 0)
					prop({
						Name = "FenceRail",
						Size = Vector3.new(0.4, 0.4, (b - a).Magnitude + 0.6),
						CFrame = CFrame.lookAt((a + b) / 2, b),
						Color = Color3.fromRGB(150, 112, 78),
						Material = Enum.Material.Wood,
						Parent = fence,
					})
				end
			end
			previous = at
		end
	end

	-- The whole boundary sits past the shadow map's useful range, so nothing in it casts.
	for _, d in fence:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
end
```

### `tests/Ground.spec.luau`

```lua
local T = require("./TestLib")
local Config = require("../src/shared/Config")
local Ground = require("../src/shared/Ground")
local Layout = require("../src/shared/Layout")

local map = Config.Map
local TAU = 2 * math.pi

-- True when a bearing falls in the dip cut into the rim for the pond.
local function inPondGap(angle: number): boolean
	local spec = map.pond
	if not spec then
		return false
	end
	return math.abs((angle - spec.angle + math.pi) % TAU - math.pi) < spec.gapHalfAngle
end

-- Calls fn(x, z) on a 4-stud grid over every point at least `margin` inside the field's edge.
local function eachFieldPoint(margin: number, fn: (number, number) -> ())
	local far = map.outline.mean * 1.3
	for x = -far, far, 4 do
		for z = -far, far, 4 do
			if Layout.isInsideField(x, z, margin) then
				fn(x, z)
			end
		end
	end
end

T.test("everything inside the wall is dead flat at y = 0", function()
	eachFieldPoint(0, function(x, z)
		T.expectEqual(Ground.height(x, z), 0, `at {x}, {z}`)
	end)
	T.expectEqual(Ground.height(0, 0), 0, "the centre")
end)

T.test("the land has no steps: half-stud neighbours stay close everywhere", function()
	local far = map.outline.mean * 1.3 + map.extent
	for x = -far, far, 7.3 do
		for z = -far, far, 6.1 do
			local h = Ground.height(x, z)
			T.expectTrue(math.abs(Ground.height(x + 0.5, z) - h) <= 1.5, `step along x at {x}, {z}`)
			T.expectTrue(math.abs(Ground.height(x, z + 0.5) - h) <= 1.5, `step along z at {x}, {z}`)
		end
	end
end)

T.test("hills rise just past the wall, and a taller ridge closes the horizon", function()
	for i = 0, 359 do
		local a = TAU * i / 360
		local edge = Layout.outlineRadius(a)
		local function at(u: number): number
			return Ground.height((edge + u) * math.cos(a), (edge + u) * math.sin(a))
		end
		T.expectEqual(at(0), 0, `the field is flat right up to the wall at {i}`)
		T.expectTrue(at(3) < 0.5, `the ground is still low 3 studs past the wall at {i}`)
		local rim, ridge = -math.huge, -math.huge
		for u = 0, 2 * map.rim.crest, 5 do
			rim = math.max(rim, at(u))
		end
		for u = map.ridge.start, map.extent, 5 do
			ridge = math.max(ridge, at(u))
		end
		if not inPondGap(a) then
			T.expectTrue(rim >= 20, `rim only {rim} high at {i}`)
		end
		T.expectTrue(ridge >= 90, `ridge only {ridge} high at {i}`)
	end
end)

T.test("materials: paving in the district, dirt at nests, rock only on steep faces", function()
	T.expectEqual(Ground.material(0, 0, 0), "Pavement")
	T.expectEqual(Ground.material(Config.Base.curbRadius - 3, 0, 0), "Pavement")
	for i, n in Layout.nestPositions() do
		T.expectEqual(Ground.material(n.x, n.z, 0), "Ground", "nest " .. i)
	end
	T.expectEqual(Ground.material(0, Config.Base.curbRadius + 20, 1.2), "Rock")
	local water = Ground.pond() :: Ground.Pond
	T.expectEqual(Ground.material(water.x, water.z, 0), "Mud", "the pond bed")
	T.expectEqual(Ground.material(water.x + water.radius + 2, water.z, 0), "Sand", "the pond's bank")
	local plain = Ground.material(0, Config.Base.curbRadius + 20, 0)
	T.expectTrue(plain == "Grass" or plain == "LeafyGrass", plain)
	local leafy = 0
	eachFieldPoint(2, function(x, z)
		local m = Ground.material(x, z, Ground.slope(x, z))
		T.expectTrue(m == "Grass" or m == "LeafyGrass" or m == "Ground" or m == "Pavement", `{m} in the field`)
		if m == "LeafyGrass" then
			leafy += 1
		end
	end)
	T.expectTrue(leafy > 0, "leafy patches")
end)

return {}
```

### `tests/LandGrid.spec.luau`

```lua
local T = require("./TestLib")
local Config = require("../src/shared/Config")
local Ground = require("../src/shared/Ground")
local LandGrid = require("../src/shared/LandGrid")
local Layout = require("../src/shared/Layout")

local VOXEL, CHUNK = LandGrid.VOXEL, LandGrid.CHUNK
local SPAN = VOXEL * CHUNK

local function named(name: string): string
	return name
end

local function nearestToCentre(c: LandGrid.Chunk): number
	local x, z = math.clamp(0, c.x, c.x + SPAN), math.clamp(0, c.z, c.z + SPAN)
	return math.sqrt(x * x + z * z)
end

-- The chunk holding the point (x, z).
local function chunkAt(x: number, z: number): LandGrid.Chunk
	return { x = math.floor(x / SPAN) * SPAN, z = math.floor(z / SPAN) * SPAN }
end

T.test("chunks sit on the voxel grid, once each, nearest the centre first", function()
	local seen, last = {}, -1
	for i, c in LandGrid.chunks() do
		T.expectEqual(c.x % SPAN, 0, `x off the grid at {i}`)
		T.expectEqual(c.z % SPAN, 0, `z off the grid at {i}`)
		local key = `{c.x},{c.z}`
		T.expectTrue(not seen[key], "twice: " .. key)
		seen[key] = true
		local d = nearestToCentre(c)
		T.expectTrue(d >= last, `out of order at {i}`)
		last = d
	end
	-- the land reaches every bearing's far edge, and a chunk is there to hold it
	for i = 0, 359 do
		local a = 2 * math.pi * i / 360
		local r = Layout.outlineRadius(a) + Config.Map.extent - 3
		local c = chunkAt(r * math.cos(a), r * math.sin(a))
		T.expectTrue(seen[`{c.x},{c.z}`], `no chunk at the far edge, bearing {i}`)
	end
end)

T.test("each column is filled to LIFT under the surface: full, then part-filled, then empty", function()
	local chunks = LandGrid.chunks()
	for _, c in { chunks[1], chunkAt(200, -40), chunkAt(-120, 260), chunkAt(560, 300), chunks[#chunks] } do
		local v = LandGrid.voxels(c, named)
		for i = 1, CHUNK do
			for k = 1, CHUNK do
				local x, z = c.x + (i - 0.5) * VOXEL, c.z + (k - 0.5) * VOXEL
				local filled, settled = 0, true
				for j = 1, v.layers do
					local s = v.solid[i][j][k]
					filled += s * VOXEL
					T.expectTrue((v.material[i][j][k] == "Air") == (s == 0), `material without land at {x}, {z}`)
					if j > 1 and s > v.solid[i][j - 1][k] then
						settled = false
					end
				end
				T.expectTrue(settled, `a gap in the column at {x}, {z}`)
				if LandGrid.hasLand(x, z) then
					T.expectNear(
						Config.Map.floor + filled + LandGrid.LIFT,
						Ground.height(x, z),
						1e-6,
						`column at {x}, {z}`
					)
				else
					T.expectEqual(filled, 0, `land outside the land at {x}, {z}`)
				end
			end
		end
	end
end)

T.test("the district is paving filled to half a voxel under y = 0, so it is drawn at y = 0", function()
	local v = LandGrid.voxels({ x = 0, z = 0 }, named)
	local full = (-LandGrid.LIFT - Config.Map.floor) // VOXEL
	T.expectEqual(v.layers, full + 1)
	for i = 1, CHUNK do
		for k = 1, CHUNK do
			for j = 1, full do
				T.expectEqual(v.solid[i][j][k], 1)
				T.expectEqual(v.material[i][j][k], "Pavement")
			end
			T.expectNear(v.solid[i][full + 1][k], 0.5, 1e-9)
		end
	end
end)

T.test("there is a full voxel of land under every column, however low", function()
	local half = LandGrid.halfSide()
	for x = -half, half, 9 do
		for z = -half, half, 9 do
			if LandGrid.hasLand(x, z) then
				T.expectTrue(Ground.height(x, z) - LandGrid.LIFT >= Config.Map.floor + VOXEL, `too low at {x}, {z}`)
			end
		end
	end
end)

return {}
```

### `tests/Pond.spec.luau`

```lua
local T = require("./TestLib")
local Config = require("../src/shared/Config")
local Ground = require("../src/shared/Ground")
local LandGrid = require("../src/shared/LandGrid")
local Layout = require("../src/shared/Layout")

local map = Config.Map
local TAU = 2 * math.pi
local SPAN = LandGrid.VOXEL * LandGrid.CHUNK

local function named(name: string): string
	return name
end

T.test("the pond lies wholly past the wall, in a hollow that holds its water", function()
	local water = Ground.pond() :: Ground.Pond
	T.expectTrue(water ~= nil, "a pond")
	local spec = map.pond
	local outer = spec.radius + spec.shore + spec.blend
	for i = 0, 179 do
		local a = TAU * i / 180
		local x, z = water.x + outer * math.cos(a), water.z + outer * math.sin(a)
		T.expectTrue(not Layout.isInsideField(x, z, -8), `the hollow reaches the field at {i}`)
		for d = spec.radius, outer + 6, 1 do
			local h = Ground.height(water.x + d * math.cos(a), water.z + d * math.sin(a))
			T.expectTrue(h >= water.level - 1e-6, `land under the waterline at {i}, {d} out`)
		end
	end
	T.expectTrue(Ground.height(water.x, water.z) <= water.level - 2, "deep enough to read as water")
end)

T.test("the rim dips where the pond is, so it can be seen from the field", function()
	local water = Ground.pond() :: Ground.Pond
	local spec = map.pond
	local edge = Layout.outlineRadius(spec.angle)
	for u = 0, spec.beyond - spec.radius, 2 do
		local h = Ground.height((edge + u) * math.cos(spec.angle), (edge + u) * math.sin(spec.angle))
		T.expectTrue(h <= 8, `the rim blocks the view {u} past the wall: {h}`)
	end
	T.expectTrue(water.level <= 0, "the water lies below the field")
end)

T.test("the pond's chunk carries water to the waterline, and only in the pond", function()
	local water = Ground.pond() :: Ground.Pond
	local c = { x = math.floor(water.x / SPAN) * SPAN, z = math.floor(water.z / SPAN) * SPAN }
	local v = LandGrid.voxels(c, named)
	T.expectTrue(v.liquid ~= nil, "the pond's chunk has a water channel")
	local liquid = v.liquid :: { { { number } } }
	for i = 1, LandGrid.CHUNK do
		for k = 1, LandGrid.CHUNK do
			local x, z = c.x + (i - 0.5) * LandGrid.VOXEL, c.z + (k - 0.5) * LandGrid.VOXEL
			local depth = 0
			for j = 1, v.layers do
				depth += liquid[i][j][k] * LandGrid.VOXEL
			end
			if Layout.planarDistance(x, z, water.x, water.z) < water.radius then
				T.expectNear(map.floor + depth, water.level, 1e-6, `water column at {x}, {z}`)
			else
				T.expectEqual(depth, 0, `water outside the pond at {x}, {z}`)
			end
		end
	end
	T.expectTrue(LandGrid.voxels({ x = 128, z = 0 }, named).liquid == nil, "no water in the field")
end)

return {}
```

### Probe: `.claude/tools/studio/land_check.luau` (local, git-ignored)

```lua
-- Plan 2026-10-04-big-uneven-map, Task 3: the land is written where Ground says, the old Baseplate
-- is gone, and nobody was let in before the land was down. Run on the Server in play mode.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Ground = require(ReplicatedStorage.Shared.Ground)
local Layout = require(ReplicatedStorage.Shared.Layout)

local fails = {}
local function check(ok: boolean, message: string)
	if not ok then
		table.insert(fails, message)
	end
end

check(workspace:GetAttribute("LandReady") == true, "LandReady is not set")
check(workspace:FindFirstChild("Baseplate") == nil, "the old Baseplate is still there")
local readyAt, admittedAt = workspace:GetAttribute("LandReadyAt"), workspace:GetAttribute("PlayersAdmittedAt")
check(
	type(readyAt) == "number" and type(admittedAt) == "number" and readyAt <= admittedAt,
	"players were let in before the land was down"
)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
params.IgnoreWater = true
local function surface(x: number, z: number): (number?, Enum.Material?)
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), params)
	return if hit then hit.Position.Y else nil, if hit then hit.Material else nil
end

-- The field: dead flat at y = 0 everywhere a player can stand.
local rng = Random.new(20261004)
local fieldWorst = 0
for _ = 1, 400 do
	local angle = rng:NextNumber() * 2 * math.pi
	local r = rng:NextNumber() * (Layout.outlineRadius(angle) - 3)
	local y = surface(r * math.cos(angle), r * math.sin(angle))
	if y then
		fieldWorst = math.max(fieldWorst, math.abs(y))
	else
		check(false, string.format("no ground at r %.0f, bearing %.2f", r, angle))
	end
end
check(fieldWorst <= 0.05, string.format("the field is off y = 0 by %.3f", fieldWorst))

-- The hills: where Ground says, within what smooth terrain allows. Roblox's mesher rounds crests and
-- valley floors by up to about half a stud (measured 2026-10-05), so each point gets that much plus
-- some per unit of slope, and the average must stay near zero: a systematic offset (like the +2 lift
-- Landscape compensates) shows up there. Rock faces are left out: Roblox roughens Rock on purpose.
local hillWorst, hillAt, hills, hillSum = 0, "", 0, 0
for _ = 1, 400 do
	local angle = rng:NextNumber() * 2 * math.pi
	local r = Layout.outlineRadius(angle) + 4 + rng:NextNumber() * (Config.Map.extent - 12)
	local x, z = r * math.cos(angle), r * math.sin(angle)
	local slope = Ground.slope(x, z)
	if slope < Config.Map.rockSlope - 0.1 then
		local y = surface(x, z)
		if y then
			hills += 1
			local off = y - Ground.height(x, z)
			hillSum += off
			local over = math.abs(off) - (0.6 + 0.6 * slope)
			if over > hillWorst then
				hillWorst, hillAt = over, string.format("(%.0f, %.0f) off by %.2f on slope %.2f", x, z, off, slope)
			end
		end
	end
end
check(hillWorst <= 0, "a hill is off Ground.height at " .. hillAt)
local bias = hillSum / math.max(hills, 1)
check(math.abs(bias) <= 0.2, string.format("the hills sit %.2f off Ground.height on average", bias))

local _, plaza = surface(10, 30)
check(plaza == Enum.Material.Pavement, "the district is not paved: " .. tostring(plaza))
local nest = Layout.nestPositions()[1]
local _, dirt = surface(nest.x, nest.z)
check(dirt == Enum.Material.Ground, "no dirt under nest 1: " .. tostring(dirt))

local summary = string.format(
	"field max %.3f, %d hill samples (mean off %.3f), land written in %s s",
	fieldWorst,
	hills,
	hillSum / math.max(hills, 1),
	tostring(workspace:GetAttribute("LandSeconds"))
)
if #fails == 0 then
	return "PASS land_check: " .. summary
end
return "FAIL land_check: " .. table.concat(fails, "; ") .. " | " .. summary
```

### Probe: `.claude/tools/studio/world_check.luau` (local, git-ignored)

```lua
-- Plan 2026-10-04-big-uneven-map, Task 4: the wall follows the uneven outline and reaches under the
-- ground, the rim is woods on the Terrain (no part domes), nothing in the field floats, and the part
-- count stays in hand. Run on the Server in play mode.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ground = require(ReplicatedStorage.Shared.Ground)
local Layout = require(ReplicatedStorage.Shared.Layout)

local fails = {}
local function check(ok: boolean, message: string)
	if not ok then
		table.insert(fails, message)
	end
end

-- The lowest world-space point of a placed piece of scenery, and the point it stands on. Every part
-- is measured along world Y whatever way it is turned: a nest bowl is a cylinder lying on its side.
local function base(item: Instance): (number, number, number)
	local lowest = math.huge
	local parts = if item:IsA("BasePart") then { item } else item:GetDescendants()
	for _, part in parts do
		if part:IsA("BasePart") then
			local cf, size = part.CFrame, part.Size
			local halfY = (
				math.abs(cf.RightVector.Y) * size.X
				+ math.abs(cf.UpVector.Y) * size.Y
				+ math.abs(cf.LookVector.Y) * size.Z
			) / 2
			lowest = math.min(lowest, cf.Position.Y - halfY)
		end
	end
	local pivot = if item:IsA("PVInstance") then (item :: PVInstance):GetPivot().Position else Vector3.zero
	return lowest, pivot.X, pivot.Z
end

-- The real ground under a point: the Terrain as Roblox draws it, which rounds crests and hollows a
-- little differently from Ground.height.
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
terrainOnly.IgnoreWater = true
local function groundAt(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), terrainOnly)
	return if hit then hit.Position.Y else Ground.height(x, z)
end

local world = workspace:FindFirstChild("World") :: Folder
local boundary = world:FindFirstChild("Boundary") :: Folder
local walls, trees, domes, fence = 0, 0, 0, 0
local wallOff, treeWorst, treeAt = 0, 0, ""
for _, child in boundary:GetChildren() do
	if child.Name == "FieldWall" then
		walls += 1
		local p = (child :: BasePart).Position
		wallOff = math.max(wallOff, math.abs(math.sqrt(p.X ^ 2 + p.Z ^ 2) - Layout.outlineRadius(math.atan2(p.Z, p.X))))
		check(p.Y - (child :: BasePart).Size.Y / 2 < -5, "a wall segment does not reach under the ground")
	elseif child.Name == "Hill" then
		domes += 1
	elseif child.Name == "FencePost" or child.Name == "FenceRail" then
		fence += 1
	else
		trees += 1
		local bottom, x, z = base(child)
		local gap = bottom - groundAt(x, z)
		-- Sunk is fine, floating is not.
		if gap > treeWorst then
			treeWorst, treeAt = gap, string.format("%s at (%.0f, %.0f)", child.Name, x, z)
		end
		check(gap > -6, string.format("%s buried at (%.0f, %.0f)", child.Name, x, z))
	end
end
check(walls == 144, "wall segments: " .. walls)
check(wallOff < 1.5, string.format("a wall segment is %.2f off the outline", wallOff))
check(domes == 0, "part hills are still there: " .. domes)
check(trees >= 100, "only " .. trees .. " trees on the rim")
check(treeWorst <= 0.3, string.format("a rim tree floats %.2f at %s", treeWorst, treeAt))

-- Everything planted in the field stands on y = 0.
local fieldWorst, fieldAt = 0, ""
for _, folderName in { "Dressing", "Obstacles", "Nests" } do
	local folder = world:FindFirstChild(folderName)
	check(folder ~= nil, "no World." .. folderName)
	if folder then
		for _, item in folder:GetChildren() do
			local bottom = base(item)
			if bottom > fieldWorst then
				fieldWorst, fieldAt = bottom, item:GetFullName()
			end
			check(bottom > -3, item:GetFullName() .. " is buried")
		end
	end
end
check(fieldWorst <= 0.3, string.format("%s floats %.2f above the field", fieldAt, fieldWorst))
check(world:FindFirstChild("BaseApron") == nil, "the old green apron disc is still there")

local parts, casting = 0, 0
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d ~= workspace.Terrain then
		parts += 1
		if d.CastShadow then
			casting += 1
		end
	end
end
local summary = string.format(
	"walls %d (worst %.2f off), rim trees %d, fence %d, field worst %.2f, parts %d, casting %d",
	walls,
	wallOff,
	trees,
	fence,
	fieldWorst,
	parts,
	casting
)
if #fails == 0 then
	return "PASS world_check: " .. summary
end
return "FAIL world_check: " .. table.concat(fails, "; ") .. " | " .. summary
```

### Probe: `.claude/tools/studio/wall_walk.luau` (local, git-ignored)

```lua
-- Plan 2026-10-04-big-uneven-map, Task 4: walking out of the field stops at the wall, where the
-- outline is nearest the centre, where it is farthest, and (when there is one) across the pond's
-- gap in the rim. Run on the Server in play mode with one player in the game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)

local hooks = ServerStorage:WaitForChild("DevHooks") :: BindableFunction
local player = Players:GetPlayers()[1]
local near, far = 0, 0
for i = 0, 719 do
	local a = 2 * math.pi * i / 720
	if Layout.outlineRadius(a) < Layout.outlineRadius(near) then
		near = a
	end
	if Layout.outlineRadius(a) > Layout.outlineRadius(far) then
		far = a
	end
end
local bearings = { near = near, far = far }
if Config.Map.pond then
	bearings.pond = Config.Map.pond.angle
end

local fails, lines = {}, {}
for name, angle in bearings do
	local edge = Layout.outlineRadius(angle)
	hooks:Invoke("teleport", player.Name, (edge - 30) * math.cos(angle), (edge - 30) * math.sin(angle))
	task.wait(0.8)
	local character = player.Character :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid:MoveTo(Vector3.new((edge + 60) * math.cos(angle), 2, (edge + 60) * math.sin(angle)))
	task.wait(5)
	local p = character:GetPivot().Position
	local r = math.sqrt(p.X * p.X + p.Z * p.Z)
	table.insert(lines, string.format("%s: wall at %.0f, stopped at %.1f", name, edge, r))
	if not (r <= edge and r >= edge - 8) then
		table.insert(fails, name)
	end
end
-- Back to the porch.
hooks:Invoke("teleport", player.Name, 0, 40)
if #fails == 0 then
	return "PASS wall_walk: " .. table.concat(lines, "; ")
end
return "FAIL wall_walk (" .. table.concat(fails, ", ") .. "): " .. table.concat(lines, "; ")
```

### Probe: `.claude/tools/studio/pond_check.luau` (local, git-ignored)

```lua
-- Plan 2026-10-04-big-uneven-map, Task 5: the pond's water lies at its waterline over a mud bed,
-- sand rings it, and no water is anywhere in the field. Run on the Server in play mode.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ground = require(ReplicatedStorage.Shared.Ground)
local Layout = require(ReplicatedStorage.Shared.Layout)

local fails = {}
local function check(ok: boolean, message: string)
	if not ok then
		table.insert(fails, message)
	end
end
local water = Ground.pond() :: Ground.Pond
local terrain = workspace.Terrain

local wet = RaycastParams.new()
wet.FilterType = Enum.RaycastFilterType.Include
wet.FilterDescendantsInstances = { terrain }
wet.IgnoreWater = false
local dry = RaycastParams.new()
dry.FilterType = Enum.RaycastFilterType.Include
dry.FilterDescendantsInstances = { terrain }
dry.IgnoreWater = true
local function cast(x: number, z: number, params: RaycastParams): RaycastResult?
	return workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), params)
end

local top = cast(water.x, water.z, wet)
check(top ~= nil and top.Material == Enum.Material.Water, "no water at the pond's centre")
if top then
	check(
		math.abs(top.Position.Y - water.level) <= 0.1,
		string.format("water at %.2f, wanted %.2f", top.Position.Y, water.level)
	)
end
local bed = cast(water.x, water.z, dry)
check(bed ~= nil and bed.Material == Enum.Material.Mud, "no mud under the pond")
local bank = cast(water.x + water.radius + 4, water.z, dry)
check(bank ~= nil and bank.Material == Enum.Material.Sand, "no sand round the pond")

-- No water anywhere a player can go: read the liquid in a ring of regions just inside the wall.
local wetSpots = 0
for i = 0, 47 do
	local a = 2 * math.pi * i / 48
	local r = Layout.outlineRadius(a) - 12
	local x, z = math.floor(r * math.cos(a) / 4) * 4, math.floor(r * math.sin(a) / 4) * 4
	local channels = terrain:ReadVoxelChannels(
		Region3.new(Vector3.new(x - 8, -16, z - 8), Vector3.new(x + 8, 8, z + 8)),
		4,
		{ "LiquidOccupancy" }
	)
	for _, plane in channels.LiquidOccupancy do
		for _, row in plane do
			for _, v in row do
				if v > 0 then
					wetSpots += 1
				end
			end
		end
	end
end
check(wetSpots == 0, wetSpots .. " wet voxels inside the wall")

local summary = string.format("pond at (%.0f, %.0f), waterline %.2f", water.x, water.z, water.level)
if #fails == 0 then
	return "PASS pond_check: " .. summary
end
return "FAIL pond_check: " .. table.concat(fails, "; ") .. " | " .. summary
```

### Probe: `.claude/tools/studio/views.luau` (local, git-ignored)

```lua
-- Plan 2026-10-04-big-uneven-map: holds the camera on a fixed set of views for before-and-after
-- captures, with the HUD, prompts, tags and mouse hidden. Prints one `name=startMs:holdMs` mark per
-- view for pick.py. Run on the Client in play mode while burst.ps1 runs in the background.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Layout = require(ReplicatedStorage.Shared.Layout)
local HOLD = 3

-- The field's edge at a bearing, before and after this plan (the old wall stood at 324).
local function edgeAt(angle: number): number
	local outline = (Layout :: any).outlineRadius
	return if outline then outline(angle) else 324
end
local function toward(angle: number, r: number, y: number): Vector3
	return Vector3.new(r * math.cos(angle), y, r * math.sin(angle))
end

local nests = workspace:WaitForChild("World"):WaitForChild("Nests")
local nest = (nests:FindFirstChild("Nest1") :: Model):GetPivot().Position
local views = {
	{ "plaza", CFrame.lookAt(Vector3.new(58, 24, 52), Vector3.new(0, 4, 0)) },
	{ "field", CFrame.lookAt(Vector3.new(0, 20, 112), Vector3.new(0, 6, 320)) },
	{ "nest", CFrame.lookAt(nest + Vector3.new(-20, 12, -20), nest) },
	{ "edge", CFrame.lookAt(toward(0.7, edgeAt(0.7) - 70, 24), toward(0.7, edgeAt(0.7) + 200, 30)) },
	{ "aerial", CFrame.lookAt(Vector3.new(0, 170, -280), Vector3.new(0, 0, 140)) },
	{ "horizon", CFrame.lookAt(toward(3.6, 200, 12), toward(0.46, 400, 20)) },
}
local Config = require(ReplicatedStorage.Shared.Config) :: any
if Config.Map and Config.Map.pond then
	local a = Config.Map.pond.angle
	table.insert(views, { "pond", CFrame.lookAt(toward(a, edgeAt(a) - 60, 22), toward(a, edgeAt(a) + 95, -2)) })
end

-- Hide everything that is not the world.
local player = Players.LocalPlayer
local hidden = {}
for _, gui in player:WaitForChild("PlayerGui"):GetChildren() do
	if gui:IsA("ScreenGui") and gui.Enabled then
		gui.Enabled = false
		table.insert(hidden, gui)
	end
end
for _, d in workspace:GetDescendants() do
	if d:IsA("BillboardGui") and d.Enabled then
		d.Enabled = false
		table.insert(hidden, d)
	end
end
ProximityPromptService.Enabled = false
UserInputService.MouseIconEnabled = false
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)

local cam = workspace.CurrentCamera
local marks = {}
for _, view in views do
	table.insert(marks, `{view[1]}={DateTime.now().UnixTimestampMillis}:{HOLD * 1000}`)
	local stop = os.clock() + HOLD
	while os.clock() < stop do
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = view[2]
		cam.Focus = view[2] * CFrame.new(0, 0, -40)
		RunService.RenderStepped:Wait()
	end
end

cam.CameraType = Enum.CameraType.Custom
for _, gui in hidden do
	(gui :: any).Enabled = true
end
ProximityPromptService.Enabled = true
UserInputService.MouseIconEnabled = true
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
return table.concat(marks, " ")
```
