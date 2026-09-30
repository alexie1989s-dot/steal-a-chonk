# Vertical-Slice Greybox Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Execution note (2026-09-24):** the user asked Claude Code to build this directly in the current session ("you can start building it"), so it runs natively, task by task. Implementation code is written during execution, not copied here. This plan fixes the contracts, the tests and the verification scripts. Commits happen only when the user asks, with the repository's secret/path scan first (see `AGENTS.md`).

**Goal:** a playable greybox of spec §23 step 1 in Roblox Studio. It has one zone, one guardian type, ten Chonks, the Vault only, the hamster wheel, carrying and the bat, and the reveal card. Two testers can play the whole loop: train, grab, carry, get chased, bat, unwrap, reveal and earn.

**Architecture:** Rojo syncs `src/` into Studio. Pure rules live in `src/shared` and have no Roblox API calls. They use string requires (`require("./X")`, verified in both Studio and Lune on 2026-09-24), so Lune can unit-test them headlessly. Server services in `src/server` own all state. They follow spec §20: clients send intents only, and state reaches clients through Player attributes and RemoteEvents. The map is generated from code at server start, so nothing depends on hand edits in Studio.

**Tech Stack:** Luau, Rojo 7.7.0, Lune 0.10.5 (unit tests), Selene 0.31.0, StyLua 2.5.2, and Roblox Studio with the built-in Studio MCP for integration checks.

**Spec:** [docs/superpowers/specs/2026-09-06-steal-a-chonk-design.md](../specs/2026-09-06-steal-a-chonk-design.md), mainly §5–§10, §18–§20, §23 and §25.

## Global Constraints

- Server authority: "all grabs, carries, drops, reveals, incomes, shield states, and purchases are computed on the server. Client sends intents only." (§20)
- "Carry speed is enforced server-side; a client moving faster than allowed while carrying is snapped back." (§20)
- "All numbers live in `src/shared/Config.luau` and are tuned, never hard-coded in systems." (§25)
- "All strings live in one shared strings module for filtering, editing, and localization." (§18)
- "Guardians chase for as long as you hold the egg, stopping only at the boundary between field and bases." (§3)
- "If caught, you drop the burrito at your feet and are knocked back; anyone can pick it up, including you." (§7)
- "Nothing is ever deleted. Value only moves between players." (§2) A dropped burrito lies on the ground; it is never destroyed.
- "The base is fully safe; all PvP theft is in the field while carrying." (§3) The bat only works on carriers in the field.
- Mobile first: "Big one-thumb buttons in the lower corners. Grab, Bat… as the only field buttons." (§19) The reveal card is "dismissable in one tap." (§19)
- Economy seeds (§25): Common 1 cash/s at A Fine Boi; ×5 per tier; size income 1, 1.5, 2.5, 4, 7, 12; unwrap Common 20 s … Secret 20 min, × size factor 1 to 3; Zone 1 needs 0 Zoomies.
- Carry multipliers (§9): Common 80 %, Rare 60 %, Legendary 40 %, Secret waddle.
- Original IP only; no real people, no brand parodies (§22). No media feeds (§3).
- Placeholder art: greybox parts only. No partner-accepted art exists, and this slice does not change art status.

### Prototype decisions the spec does not settle (proposals, tune or overrule freely)

| Decision | Choice for the slice | Why |
| --- | --- | --- |
| Guardian type | **Patroller** (waddles a circle around the nest; chases the carrier) | Its behavior is unambiguous. Sleeper's walk-versus-sprint rule needs a sprint mechanic the slice does not have. |
| Ten Chonks | Common: Cat, Hamster, Frog, Pigeon · Uncommon: Corgi, Penguin, Seal · Rare: Capybara, Axolotl · Epic: Panda | Spread across the four tiers Zone 1 can plausibly drop |
| Names and bios | Draft copy in `Strings`/`Catalog`, following §8's naming grammar | Needs partner review |
| Zone 1 tier weights | Common 70, Uncommon 22, Rare 7, Epic 1 | Not specified |
| Size weights | 50, 25, 13, 7, 4, 1 | Not specified |
| Unwrap seconds by tier | 20, 40, 80, 160, 320, 640, 1200 | Geometric fill between §25's endpoints |
| Size unwrap factor | 1, 1.4, 1.8, 2.2, 2.6, 3 | Linear fill of §25's 1–3 |
| Carry multipliers not in §9 | Uncommon 70 %, Epic 50 %, Mythic 30 %, Secret 20 % | Interpolated |
| Speed curve | WalkSpeed = 16 + 6·log10(1 + Zoomies/10), capped at 60 | The Zoomies thresholds are exponential, so the speed you feel grows with log(Zoomies) |
| Guardian speed Zone 1 | 17 studs/s (a rookie walks at 16) | §7: "slightly faster than a rookie's base Zoomies" |
| Wheel | Standing on it: +1 Zoomie/s. "Pedal" prompt: +2 per press, 5 presses/s max | Aims for §25's first 1K in about 45 min of mixed play |
| Vault | 2 incubators (§10), 10 display slots | The spec does not give base capacity |
| Nest respawn | Common 180 s, Uncommon 240 s, Rare 300 s, Epic 360 s | §7: 3–6 min, "longer for higher-value nests" |
| Loose burrito | Returns to its nest after 60 s untouched | Nothing deleted; keeps the field full |
| Bat rules | Range 8 studs, target in front (dot ≥ 0.2) or within 3 studs; 1 s cooldown; a carrier cannot bat | Hands are full |
| Persistence | **Session-only**; no DataStore in the slice | §23's slice omits it; the Data service arrives with the Alpha |
| Plots | 8 plots in a ring; a 9th player spawns at the centre with a notice | Two testers needed |

## Review Focus

1. **A carrier leaves the server or resets while carrying.** The burrito must drop where they were, never vanish (§2, §11). Test: Task 5 step "leave and reset".
2. **Two players trigger Grab on the same burrito in the same frame.** Exactly one gets it, and the other sees nothing break. Test: Task 5 step "double grab".
3. **The guardian must never enter the base district,** even when the carrier runs along the curb or circles back out and in. Test: Task 6 step "curb clamp".
4. **Deposit when both incubators are busy, when the Vault is full, or at someone else's house.** The deposit is refused with a message, and the player keeps the burrito. Test: Task 7 step "refusals".
5. **A knocked-back player immediately re-grabs their dropped burrito.** Allowed ("including you"), and the guardian resumes the chase. Test: Task 6 step "re-grab".

---

## File structure

```
src/shared/
  Config.luau        all tunable numbers (edit to tune)
  Catalog.luau       the ten Chonks (data only)
  Strings.luau       every player-facing string
  Signal.luau        tiny pure event helper
  Formulas.luau      speed, carry speed, income, unwrap time, model scale
  Rolls.luau         weighted picks, burrito roll
  Naming.luau        display names, size stamps
  Layout.luau        ring/plot/nest positions, curb tests (plain numbers)
  BatRules.luau      bat target selection (plain numbers)
  Remotes.luau       RemoteEvent names; get-or-create helpers (Roblox only)
  Version.luau       exists
src/server/
  Main.server.luau   boot order
  World.luau         generates the ground, curb, field, nests and obstacles
  Models.luau        greybox builders: burrito, Chonk, Mama Chonk, house parts
  PlayerState.luau   per-player session state + attribute sync
  Plots.luau         plot assignment, house build, spawn on porch
  Movement.luau      WalkSpeed from Zoomies/carry; carry anti-cheat
  Wheel.luau         Zoomies gain: standing + Pedal prompt
  Carry.luau         carrying, dropping, knockback, curb crossing
  Nests.luau         burritos: spawn, grab prompt, loose, return, respawn
  Guardians.luau     Patroller Mama Chonks
  Vault.luau         incubators, unwrap, reveal roll, display, income
  Bat.luau           bat intent → validated drop
  DevHooks.luau      Studio-only BindableFunction for MCP verification
src/client/
  Main.client.luau   boot controllers
  Hud.luau           cash / Zoomies / speed readout, toasts
  Reveal.luau        full-screen reveal card
  Input.luau         Bat action (F key, gamepad X, touch button)
  CameraFx.luau      field of view widens with speed
tests/
  TestLib.luau       tiny test API
  run.luau           runs every *.spec.luau, exits non-zero on failure
  *.spec.luau        one per pure module
```

`default.project.json` also changes: the baseplate grows to 800 × 800 so it covers the field. The `Workspace` spawn stays as a centre fallback.

## Shared contracts

These are used across tasks; names are exact.

```luau
-- Tier names, ordered; tier index = position (Common = 1).
Config.Tiers = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
-- Size is an integer 1..6 (A Fine Boi .. OH LAWD HE COMIN).

type CatalogEntry = { id: string, species: string, tier: string, name: string, bio: string, color: { number } } -- color = {r,g,b} 0..255
type BurritoRoll = { chonkId: string, tier: string, size: number }
type ChonkRecord = { uid: number, chonkId: string, tier: string, size: number }

Formulas.tierIndex(tier: string): number
Formulas.walkSpeed(zoomies: number): number
Formulas.carrySpeed(zoomies: number, tier: string): number
Formulas.incomePerSecond(tier: string, size: number): number
Formulas.unwrapSeconds(tier: string, size: number): number
Formulas.sizeScale(size: number): number

Rolls.pickWeighted(order: { string }, weights: { [string]: number }, r: number): string   -- r in [0,1)
Rolls.pickIndexWeighted(weights: { number }, r: number): number
Rolls.rollBurrito(zone: number, rand: () -> number): BurritoRoll

Naming.sizeStamp(size: number): string
Naming.displayName(entry: CatalogEntry, size: number, mutation: string?): string

Layout.planarDistance(ax: number, az: number, bx: number, bz: number): number
Layout.isInBase(x: number, z: number): boolean                 -- inside the curb
Layout.clampOutsideCurb(x: number, z: number, margin: number): (number, number)
Layout.plotFrames(): { { x: number, z: number, yaw: number } } -- yaw faces outward
Layout.nestPositions(): { { x: number, z: number } }
Layout.obstaclePositions(): { { x: number, z: number } }

BatRules.pickTarget(attacker: BatAttacker, candidates: { BatCandidate }): number?  -- candidate id
type BatAttacker = { x: number, z: number, lookX: number, lookZ: number, carrying: boolean }
type BatCandidate = { id: number, x: number, z: number, carrying: boolean, inField: boolean }

Signal.new() -> { Connect: (self, fn) -> () -> (), Fire: (self, ...any) -> () }
```

Player attributes (server writes, client reads): `Cash` (number), `Zoomies` (number), `CarryTier` (string or nil), `InBase` (boolean), `Plot` (number or nil).

RemoteEvents in `ReplicatedStorage.Remotes`:
- `BatSwing`: client → server, no arguments.
- `Reveal`: server → client, `{ displayName, species, tier, sizeStamp, size, bio, incomePerSecond }`.
- `Toast`: server → client, `(text: string)`.
- `Knockback`: server → client, `(dirX, dirZ)`.
- `Celebrate`: server → client, no arguments.

`DevHooks`: a `BindableFunction` at `ServerStorage.DevHooks`, created only when `RunService:IsStudio()`. The MCP's `execute_luau` (Server context) calls `:Invoke(action, ...)`:
- `"state"` → `{ players = {[name] = {cash, zoomies, plot, carrying, inBase, vault, incubating}}, nests = {{index, status, tier}}, guardians = {{index, mode}} }`
- `"setZoomies", name, n`
- `"setTimeScale", n`: scales unwrap, respawn and loose-return timers.
- `"teleport", name, x, z`
- `"grab", name, nestIndex` → `ok, reason`: teleports next to the nest, then runs the real grab path.
- `"deposit", name` → `ok, reason`: teleports to the player's incubator, then runs the real deposit path.
- `"drop", name`

---

### Task 1: Test harness, Config and Formulas

**Files:** create `tests/TestLib.luau`, `tests/run.luau`, `tests/Formulas.spec.luau`, `src/shared/Config.luau`, `src/shared/Formulas.luau`.

**Interfaces:** produces `Config` (all tables named in the decisions table: `Tiers`, `Economy`, `SizeIncome`, `SizeUnwrap`, `SizeScale`, `UnwrapSeconds`, `CarryMultiplier`, `Speed`, `Zones`, `SizeWeights`, `Wheel`, `Vault`, `Carry`, `Bat`, `Guardian`, `AntiCheat`, `Base`, `Nest`, `Camera`, `Debug`) and `Formulas` as in the shared contracts.

- [ ] **Step 1: Write the harness.** `TestLib` exports `test(name, fn)`, `expectEqual(actual, expected, msg?)`, `expectNear(actual, expected, eps, msg?)`, `expectTrue(v, msg?)` and `results()`. `run.luau` requires each spec file by string path, runs the registered tests with `pcall`, prints `PASS`/`FAIL name: message` and a total, and calls `process.exit(1)` if anything failed.
- [ ] **Step 2: Write the failing tests** in `tests/Formulas.spec.luau`:

```luau
local T = require("./TestLib")
local Formulas = require("../src/shared/Formulas")
local Config = require("../src/shared/Config")

T.test("tierIndex orders tiers", function()
	T.expectEqual(Formulas.tierIndex("Common"), 1)
	T.expectEqual(Formulas.tierIndex("Secret"), 7)
end)
T.test("rookie walk speed is the Roblox default", function()
	T.expectNear(Formulas.walkSpeed(0), 16, 1e-9)
end)
T.test("walk speed rises with zoomies and is capped", function()
	T.expectTrue(Formulas.walkSpeed(1000) > Formulas.walkSpeed(100))
	T.expectNear(Formulas.walkSpeed(1e30), Config.Speed.max, 1e-9)
end)
T.test("carrying slows you by tier", function()
	T.expectNear(Formulas.carrySpeed(0, "Common"), 16 * 0.8, 1e-9)
	T.expectNear(Formulas.carrySpeed(0, "Rare"), 16 * 0.6, 1e-9)
	T.expectNear(Formulas.carrySpeed(0, "Legendary"), 16 * 0.4, 1e-9)
end)
T.test("a carrying rookie is slower than the Zone 1 guardian", function()
	T.expectTrue(Formulas.carrySpeed(0, "Common") < Config.Zones[1].guardianSpeed)
end)
T.test("a little wheel time lets a Common carrier outrun the Zone 1 guardian", function()
	T.expectTrue(Formulas.carrySpeed(150, "Common") > Config.Zones[1].guardianSpeed)
end)
T.test("income follows section 25", function()
	T.expectNear(Formulas.incomePerSecond("Common", 1), 1, 1e-9)
	T.expectNear(Formulas.incomePerSecond("Uncommon", 1), 5, 1e-9)
	T.expectNear(Formulas.incomePerSecond("Common", 6), 12, 1e-9)
	T.expectNear(Formulas.incomePerSecond("Epic", 4), 125 * 4, 1e-9)
end)
T.test("unwrap time spans 20 s to 20 min times size factor 1 to 3", function()
	T.expectNear(Formulas.unwrapSeconds("Common", 1), 20, 1e-9)
	T.expectNear(Formulas.unwrapSeconds("Secret", 1), 1200, 1e-9)
	T.expectNear(Formulas.unwrapSeconds("Common", 6), 60, 1e-9)
end)
T.test("model scale grows with size", function()
	T.expectNear(Formulas.sizeScale(1), 1, 1e-9)
	T.expectTrue(Formulas.sizeScale(6) > Formulas.sizeScale(5))
end)
return nil
```

- [ ] **Step 3: Run and see it fail.** `lune run tests/run` → FAIL (module not found).
- [ ] **Step 4: Implement** `Config.luau` (values from the decisions table and §25) and `Formulas.luau`. `Formulas` requires `./Config`, clamps `size` to 1..6, and errors on an unknown tier.
- [ ] **Step 5: Run and pass.** `lune run tests/run` → all PASS. `stylua --check src tests` and `selene src` → clean.

### Task 2: Catalog, Strings, Naming, Rolls, Signal

**Files:** create `src/shared/Catalog.luau`, `Strings.luau`, `Naming.luau`, `Rolls.luau`, `Signal.luau`, `tests/Catalog.spec.luau`, `tests/Naming.spec.luau`, `tests/Rolls.spec.luau`, `tests/Signal.spec.luau`; register them in `tests/run.luau`.

**Interfaces:** `Catalog.entries: { CatalogEntry }`, `Catalog.byId: { [string]: CatalogEntry }`, `Catalog.byTier: { [string]: { CatalogEntry } }`. `Strings` holds `SizeStamps` (6), `SizeSuffix` (6), `Toasts` table, `Guardian.wake`, `Reveal` labels, `Hud` labels and `Bat.bonk`. `Naming`, `Rolls` and `Signal` are as in the shared contracts.

- [ ] **Step 1: Write the failing tests:**

```luau
-- tests/Catalog.spec.luau
local T = require("./TestLib")
local Catalog = require("../src/shared/Catalog")
local Config = require("../src/shared/Config")
T.test("slice ships exactly ten Chonks", function() T.expectEqual(#Catalog.entries, 10) end)
T.test("every entry is complete and uses a real tier", function()
	local tiers = {}
	for _, t in Config.Tiers do tiers[t] = true end
	local ids = {}
	for _, e in Catalog.entries do
		T.expectTrue(tiers[e.tier], e.id .. " tier")
		T.expectTrue(#e.name > 0 and #e.bio > 0 and #e.species > 0, e.id .. " text")
		T.expectEqual(#e.color, 3, e.id .. " color")
		T.expectTrue(not ids[e.id], "duplicate id " .. e.id)
		ids[e.id] = true
	end
end)
T.test("every tier Zone 1 can roll has at least one Chonk", function()
	for tier, w in Config.Zones[1].tierWeights do
		if w > 0 then T.expectTrue(Catalog.byTier[tier] and #Catalog.byTier[tier] > 0, tier) end
	end
end)
return nil

-- tests/Naming.spec.luau
local T = require("./TestLib")
local Naming = require("../src/shared/Naming")
local Catalog = require("../src/shared/Catalog")
T.test("six size stamps in spec order", function()
	T.expectEqual(Naming.sizeStamp(1), "A Fine Boi")
	T.expectEqual(Naming.sizeStamp(4), "HEFTYCHONK")
	T.expectEqual(Naming.sizeStamp(6), "OH LAWD HE COMIN")
end)
T.test("display name: mutation prefixes, size suffixes", function()
	local e = { id = "x", species = "Cat", tier = "Common", name = "Beans", bio = "b", color = { 1, 2, 3 } }
	T.expectEqual(Naming.displayName(e, 4, "Cosmic"), "Cosmic Beans the HEFTYCHONK")
	T.expectEqual(Naming.displayName(e, 1, nil), "Beans, A Fine Boi")
end)
T.test("every catalog entry names cleanly at every size", function()
	for _, e in Catalog.entries do
		for size = 1, 6 do T.expectTrue(#Naming.displayName(e, size, nil) > #e.name) end
	end
end)
return nil

-- tests/Rolls.spec.luau
local T = require("./TestLib")
local Rolls = require("../src/shared/Rolls")
local Catalog = require("../src/shared/Catalog")
T.test("pickWeighted respects cumulative bands", function()
	local order, w = { "A", "B" }, { A = 3, B = 1 }
	T.expectEqual(Rolls.pickWeighted(order, w, 0.0), "A")
	T.expectEqual(Rolls.pickWeighted(order, w, 0.74), "A")
	T.expectEqual(Rolls.pickWeighted(order, w, 0.76), "B")
	T.expectEqual(Rolls.pickWeighted(order, w, 0.999999), "B")
end)
T.test("zero-weight entries are never picked", function()
	T.expectEqual(Rolls.pickWeighted({ "A", "B", "C" }, { A = 0, B = 1, C = 0 }, 0.0), "B")
	T.expectEqual(Rolls.pickWeighted({ "A", "B", "C" }, { A = 0, B = 1, C = 0 }, 0.99), "B")
end)
T.test("pickIndexWeighted", function()
	T.expectEqual(Rolls.pickIndexWeighted({ 1, 1 }, 0.49), 1)
	T.expectEqual(Rolls.pickIndexWeighted({ 1, 1 }, 0.51), 2)
end)
T.test("rollBurrito returns a consistent catalog Chonk", function()
	local seq, i = { 0.1, 0.5, 0.2 }, 0
	local roll = Rolls.rollBurrito(1, function() i += 1; return seq[i] end)
	local entry = Catalog.byId[roll.chonkId]
	T.expectTrue(entry ~= nil)
	T.expectEqual(entry.tier, roll.tier)
	T.expectTrue(roll.size >= 1 and roll.size <= 6)
end)
T.test("1000 random rolls stay inside Zone 1's tiers", function()
	local rng = 12345
	local function rand() rng = (rng * 1103515245 + 12345) % 2147483648; return rng / 2147483648 end
	for _ = 1, 1000 do
		local r = Rolls.rollBurrito(1, rand)
		T.expectTrue(r.tier == "Common" or r.tier == "Uncommon" or r.tier == "Rare" or r.tier == "Epic", r.tier)
	end
end)
return nil

-- tests/Signal.spec.luau
local T = require("./TestLib")
local Signal = require("../src/shared/Signal")
T.test("fire reaches listeners; disconnect stops them", function()
	local s, got = Signal.new(), {}
	local off = s:Connect(function(v) table.insert(got, v) end)
	s:Fire(1); off(); s:Fire(2)
	T.expectEqual(#got, 1); T.expectEqual(got[1], 1)
end)
return nil
```

- [ ] **Step 2: Run and see it fail** (missing modules).
- [ ] **Step 3: Implement.** The Catalog uses the ten decided species with draft names and bios in §8's voice. Rare adds "Sir" and Epic adds "Baron". `Strings.SizeSuffix` = `", A Fine Boi"`, `", He Chomnk"`, `", A Heckin' Chonker"`, `" the HEFTYCHONK"`, `" the MEGACHONKER"`, `", OH LAWD HE COMIN"`. `Rolls.rollBurrito` draws `rand()` three times: tier, then species within the tier, then size.
- [ ] **Step 4: Run and pass;** lint and format are clean.

### Task 3: Layout, world generation, boot, DevHooks skeleton

**Files:** create `src/shared/Layout.luau`, `tests/Layout.spec.luau`, `src/server/World.luau`, `src/server/Models.luau`, `src/server/DevHooks.luau`; modify `src/server/Main.server.luau` and `default.project.json` (baseplate 800 × 800 × 20).

**Interfaces:** `Layout` as in the shared contracts; geometry comes from `Config.Base` (`plotCount = 8`, `plotRingRadius = 70`, `curbRadius = 105`, `nestInner = 135`, `nestOuter = 230`, `fieldOuterRadius = 320`). `World.build(): { nests: { Vector3 }, curbRadius: number }` creates `Workspace.World`, which holds the curb (a ring of 64 yellow segments), the Zone 1 ground tint, 10 nest bowls, 12 hedge obstacles and a "BACKYARDS" sign. `Models.burrito(tier, size): Model`, `Models.chonk(entry, size): Model`, `Models.mama(): Model` and `Models.part(props): Part`. `DevHooks.register(action, fn)` and `DevHooks.start()`.

- [ ] **Step 1: Write the failing tests:**

```luau
local T = require("./TestLib")
local Layout = require("../src/shared/Layout")
local Config = require("../src/shared/Config")
T.test("inside/outside the curb", function()
	T.expectTrue(Layout.isInBase(0, 0))
	T.expectTrue(not Layout.isInBase(Config.Base.curbRadius + 1, 0))
end)
T.test("clampOutsideCurb pushes points out and leaves field points alone", function()
	local x, z = Layout.clampOutsideCurb(10, 0, 4)
	T.expectNear(Layout.planarDistance(0, 0, x, z), Config.Base.curbRadius + 4, 1e-6)
	local fx, fz = Layout.clampOutsideCurb(200, 50, 4)
	T.expectEqual(fx, 200); T.expectEqual(fz, 50)
	local cx, cz = Layout.clampOutsideCurb(0, 0, 4) -- exact centre still lands on the ring
	T.expectNear(Layout.planarDistance(0, 0, cx, cz), Config.Base.curbRadius + 4, 1e-6)
end)
T.test("plots: count, inside the curb, far enough apart", function()
	local plots = Layout.plotFrames()
	T.expectEqual(#plots, Config.Base.plotCount)
	for i, p in plots do
		T.expectTrue(Layout.isInBase(p.x, p.z), "plot " .. i)
		local q = plots[i % #plots + 1]
		T.expectTrue(Layout.planarDistance(p.x, p.z, q.x, q.z) > 45, "spacing " .. i)
	end
end)
T.test("nests: zone count, all in the field band, not overlapping", function()
	local nests = Layout.nestPositions()
	T.expectEqual(#nests, Config.Zones[1].nestCount)
	for i, n in nests do
		local d = Layout.planarDistance(0, 0, n.x, n.z)
		T.expectTrue(d >= Config.Base.nestInner - 1e-6 and d <= Config.Base.nestOuter + 1e-6, "band " .. i)
		for j = i + 1, #nests do
			T.expectTrue(Layout.planarDistance(n.x, n.z, nests[j].x, nests[j].z) > 2 * Config.Guardian.patrolRadius + 8, ("gap %d-%d"):format(i, j))
		end
	end
end)
T.test("obstacles sit in the field and never on a nest", function()
	for i, o in Layout.obstaclePositions() do
		T.expectTrue(not Layout.isInBase(o.x, o.z), "obstacle " .. i)
		for _, n in Layout.nestPositions() do
			T.expectTrue(Layout.planarDistance(o.x, o.z, n.x, n.z) > Config.Guardian.patrolRadius + 6, "obstacle near nest " .. i)
		end
	end
end)
return nil
```

- [ ] **Step 2: Fail, implement `Layout` (golden-angle nest spread, deterministic), pass.**
- [ ] **Step 3: Implement** `Models`, `World` and `DevHooks` (Studio-only, created under `ServerStorage`), plus the `Main` boot: `World.build()` → `DevHooks.start()`. Later tasks add services to the boot list in this order: PlayerState, Plots, Movement, Wheel, Carry, Nests, Guardians, Vault, Bat.
- [ ] **Step 4: Verify in Studio via MCP.** Start a playtest. In Server context, check `#workspace.World.Nests:GetChildren() == 10` and that `ServerStorage.DevHooks` exists. Stop the playtest, then take a `screen_capture` from `camera_position = {0, 260, 260}` looking at the origin: the curb ring, the nest bowls and the hedges should all be visible. The console should be free of errors.

### Task 4: Player session: state, plots, speed, wheel, HUD, camera

**Files:** create `src/shared/Remotes.luau`, `src/server/PlayerState.luau`, `src/server/Plots.luau`, `src/server/Movement.luau`, `src/server/Wheel.luau`, `src/client/Hud.luau`, `src/client/CameraFx.luau`; modify both `Main` files.

**Interfaces:**
- `PlayerState.get(player): State?`. `State = { cash: number, zoomies: number, plot: number?, carrying: Burrito?, vault: { ChonkRecord }, incubators: { [number]: Incubation? }, nextUid: number }`. Also `PlayerState.sync(player)` (writes attributes) and `PlayerState.Added` / `PlayerState.Removing` (Signals).
- `Plots.frame(index): CFrame` and `Plots.part(index, name): BasePart`. Named parts per plot: `Floor`, `Wheel`, `Incubator1`, `Incubator2`, `Display1..10`, `Porch`. `Plots.ownerOf(index): Player?`.
- `Movement.refresh(player)` sets `Humanoid.WalkSpeed`: `Formulas.carrySpeed` while carrying, otherwise `Formulas.walkSpeed`.
- `Wheel`: standing gain is checked every 0.25 s (HumanoidRootPart within `Config.Wheel.radius` of your own wheel). The `Pedal` ProximityPrompt on your own wheel adds `Config.Wheel.pedalBonus`, rate-limited to `pedalMaxPerSecond`. Every gain calls `PlayerState.sync` and `Movement.refresh`.
- `Remotes.get(name): RemoteEvent` (server creates; client waits).
- DevHooks added: `state` (players part), `setZoomies`, `teleport`.

- [ ] **Step 1: Implement** these modules. Players spawn on their porch facing outward (`CharacterAdded` → `PivotTo`). A 9th player gets `Strings.Toasts.noPlot` and spawns at the centre.
- [ ] **Step 2: Verify via MCP.** Start a playtest.
  - `DevHooks:Invoke("state")` shows the player with a plot and `zoomies = 0`, and `Humanoid.WalkSpeed == 16`.
  - `character_navigation` to the player's `Wheel` part and wait 5 s: `zoomies` is at least 4.
  - `setZoomies 1000`: WalkSpeed ≈ `Formulas.walkSpeed(1000)` (28.0), and `Players.LocalPlayer:GetAttribute("Zoomies") == 1000` in Client context.
  - `screen_capture` shows the HUD with cash and Zoomies.
  - The console is free of errors.

### Task 5: Nests and carrying

**Files:** create `src/server/Carry.luau`, `src/server/Nests.luau`; modify `Movement.luau` (anti-cheat), `DevHooks.luau`, the `Main` files, and `Hud.luau` (Toast/Celebrate listeners).

**Interfaces:**
- `Burrito = { id: number, nest: number, roll: BurritoRoll, model: Model, status: "ready" | "carried" | "loose" | "incubating", carrier: Player?, looseAt: number? }`
- `Carry.pickUp(player, burrito): (boolean, string?)`. Refused if the player is already carrying, has no character, or the burrito is not ready or loose. It sets `burrito.status = "carried"`, welds the model above the head and calls `Movement.refresh`.
- `Carry.drop(player, reason: "caught" | "batted" | "left" | "died" | "dev"): Burrito?`. Places the burrito on the ground at the carrier's feet, marks it `loose` and fires `Carry.Dropped(burrito, player, reason)`.
- `Carry.take(player): Burrito?`. Detaches without dropping; used by the Vault.
- `Carry.inField(player): boolean`.
- Signals: `Carry.PickedUp(player, burrito)`, `Carry.Dropped(...)`, `Carry.CrossedHome(player, burrito)`.
- `Nests.all(): { NestState }`. `NestState = { index, position: Vector3, burrito: Burrito?, respawnAt: number? }`.
- `Nests.grab(player, index): (boolean, string?)` is the path the prompt uses.
- The loose-return loop and the respawn loop are scaled by `Config.Debug.timeScale`.
- Curb crossing: a 0.2 s loop compares `Layout.isInBase` for each carrier. On field → base it fires `CrossedHome`, sends `Celebrate` and a toast, and sets `InBase`.
- Movement anti-cheat: every `Config.AntiCheat.sampleSeconds`, if a carrier's planar speed exceeds `allowed × toleranceFactor + toleranceStuds / sample`, snap them back to the last sample.
- DevHooks added: `grab`, `drop`, `setTimeScale`, and `state` gains `nests`.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify the grab path with real input.** `character_navigation` to nest 1's burrito, then `user_keyboard_input` keyPress `E`. `state` shows `carrying` = the tier, and WalkSpeed = `carrySpeed(z, tier)`.
- [ ] **Step 3: Verify crossing.** Walk home with `character_navigation` to the player's `Floor`. `state.inBase == true`, and the console shows no errors. A `Celebrate` toast appears (`screen_capture` in Client context is optional).
- [ ] **Step 4: Verify leave and reset** (Review Focus 1). `grab` nest 2, then in Server context `player.Character.Humanoid.Health = 0`. `state` shows nest 2's burrito `loose` near the death position, and `workspace.World` still contains its model. Call `setTimeScale 0.05` and wait about 4 s: the burrito is back at its nest (`ready`).
- [ ] **Step 5: Verify double grab** (Review Focus 2). In Server context, call the real grab path twice in the same frame for the same burrito: `Nests.grab` via DevHooks `grab`, then again immediately. Exactly one returns true; the second returns `false, "taken"`.
- [ ] **Step 6: Verify anti-cheat.** While carrying, teleport the character 60 studs in Server context without using DevHooks (`HumanoidRootPart.CFrame += Vector3.new(60, 0, 0)`). Within 1 s the character is back near its previous position.

### Task 6: Guardians (Patroller Mama Chonks)

**Files:** create `src/server/Guardians.luau`; modify `DevHooks.luau` and `Main`.

**Interfaces:**
- One guardian per nest, with `mode: "patrol" | "waking" | "chase" | "return"`.
- **patrol:** circles the nest at `patrolRadius` / `patrolSpeed`.
- **waking:** the carrier of this nest's burrito is in the field. Shows the `Strings.Guardian.wake` billboard ("MRRP") for `wakeDelay`.
- **chase:** speed ramps from `rampStartFactor × guardianSpeed` to `guardianSpeed` over `rampSeconds`, moving straight at the carrier. Every position passes through `Layout.clampOutsideCurb(…, Config.Guardian.radius)`.
- **catch:** planar distance ≤ `catchDistance` → `Carry.drop(player, "caught")`, a `Knockback` remote to that player, and the `caught` toast. Then **return:** back to the patrol circle at patrol speed.
- If the carrier crosses home or the burrito is loose, the guardian goes to return.
- Rolling visual: the sphere rotates by distance / radius about the axis perpendicular to its motion.
- DevHooks `state` gains `guardians`.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify the catch.** `setZoomies 0`, then `grab` nest 1 and stand still for 4 s. `state` shows the burrito `loose` and the guardian in `return`, the console shows no errors, and the knockback toast was sent.
- [ ] **Step 3: Verify the re-grab** (Review Focus 5). Right after the catch, `grab` nest 1 again: it returns true, and within 2 s the guardian mode is `waking` or `chase`.
- [ ] **Step 4: Verify the curb clamp** (Review Focus 3). `setZoomies 100000` (fast). `grab` the nest nearest the curb, then `character_navigation` along a path hugging the curb and back out. Sample the guardian's planar distance from the centre every 0.1 s for 8 s in Server context: the minimum is always ≥ `curbRadius`.
- [ ] **Step 5: Verify the escape.** `setZoomies 150` and `grab` nest 1, then `character_navigation` home at the default speed. You arrive carrying, `CrossedHome` fired, and the guardian returned.

### Task 7: Vault, reveal and income

**Files:** create `src/server/Vault.luau`, `src/client/Reveal.luau`; modify `Plots.luau` (incubator prompts), `DevHooks.luau` and `Main`.

**Interfaces:**
- `Vault.deposit(player): (boolean, string?)`. Requires: carrying, in base, standing at your own plot's incubator, a free incubator slot, and `#vault + incubating < Config.Vault.displaySlots`. On success it calls `Carry.take`, places the burrito on the incubator with `status = "incubating"`, and starts a timer of `Formulas.unwrapSeconds × timeScale` with a progress billboard. On failure it keeps the burrito and sends a toast: `slotsBusy`, `vaultFull`, `notYourBase` or `notCarrying`. The incubator prompt calls this.
- **Reveal:** creates a `ChonkRecord` with the next uid, places a `Models.chonk` on the next free `DisplayN` pad (scaled by `Formulas.sizeScale`, with a name billboard), and fires `Reveal` with the card payload. The burrito's nest was already on its respawn timer from the grab.
- **Income:** a 1 s loop adds the sum of `incomePerSecond` over `vault` to `cash`, then calls `PlayerState.sync`.
- **Client `Reveal`:** a full-screen card with a tier colour band, the display name, the size stamp (red and shaking at size 6), species, bio, "+N cash/s", and a one-tap dismiss. Several reveals queue one after another.
- DevHooks added: `deposit`.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify the whole loop.** `setTimeScale 0.05` and `setZoomies 150`. `grab` nest 1, `character_navigation` home, then `deposit` → true. Wait until the reveal:
  - `state.vault == 1`, and cash increases each second by that Chonk's income;
  - the console shows no errors;
  - `screen_capture` in Client context shows the reveal card, or the card's `ScreenGui` is enabled in `PlayerGui`;
  - one `user_mouse_input` click dismisses it.
- [ ] **Step 3: Verify the refusals** (Review Focus 4).
  - Fill both incubators (two grabs and deposits with timeScale 1). A third deposit returns `false, "slotsBusy"`, and `state.carrying` is still set.
  - `teleport` to another plot's incubator: deposit returns `false, "notYourBase"`.
  - Call DevHooks `fillVault, name` (added in this task; it fills `vault` with Common size-1 records up to `displaySlots`). Deposit returns `false, "vaultFull"`.

### Task 8: Bat

**Files:** create `src/shared/BatRules.luau`, `tests/BatRules.spec.luau`, `src/server/Bat.luau`, `src/client/Input.luau`; modify both `Main` files.

**Interfaces:** `BatRules.pickTarget` as in the shared contracts, with `range`, `arcDot` and `pointBlank` from `Config.Bat`. Server `Bat`: on `BatSwing` it applies the per-player cooldown, reads the attacker's position and look from the server character, builds candidates from all carriers (`inField = Carry.inField`), and on a hit calls `Carry.drop(target, "batted")` plus Knockback and toasts. Client `Input`: `ContextActionService:BindAction("Bat", …, true, Enum.KeyCode.F, Enum.KeyCode.ButtonX)`, with the touch button labelled from `Strings`.

- [ ] **Step 1: Write the failing tests:**

```luau
local T = require("./TestLib")
local BatRules = require("../src/shared/BatRules")
local function attacker(x, z, lx, lz, carrying) return { x = x, z = z, lookX = lx, lookZ = lz, carrying = carrying or false } end
T.test("hits a carrier in front, in range, in the field", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), { { id = 7, x = 5, z = 0, carrying = true, inField = true } }), 7)
end)
T.test("ignores carriers inside the base district", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), { { id = 7, x = 5, z = 0, carrying = true, inField = false } }), nil)
end)
T.test("ignores players who are not carrying", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), { { id = 7, x = 5, z = 0, carrying = false, inField = true } }), nil)
end)
T.test("out of range misses", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), { { id = 7, x = 30, z = 0, carrying = true, inField = true } }), nil)
end)
T.test("behind you misses unless point blank", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), { { id = 7, x = -6, z = 0, carrying = true, inField = true } }), nil)
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), { { id = 7, x = -2, z = 0, carrying = true, inField = true } }), 7)
end)
T.test("a carrier cannot bat", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0, true), { { id = 7, x = 5, z = 0, carrying = true, inField = true } }), nil)
end)
T.test("picks the nearest valid target", function()
	T.expectEqual(BatRules.pickTarget(attacker(0, 0, 1, 0), {
		{ id = 1, x = 7, z = 0, carrying = true, inField = true },
		{ id = 2, x = 4, z = 1, carrying = true, inField = true },
	}), 2)
end)
return nil
```

- [ ] **Step 2: Fail, implement `BatRules`, pass.**
- [ ] **Step 3: Implement the server `Bat` and client `Input`.**
- [ ] **Step 4: Verify via MCP (single player).** Press `F` via `user_keyboard_input` with no carriers nearby: no error and no drop. Press it again within 1 s: it is ignored by the cooldown (a Server-context counter shows exactly one processed swing).
- [ ] **Step 5: Two-player check** (needs the testers). In Studio, Test → Clients and Servers → 2 players: one carries in the field and the other presses F in front of them, and the burrito drops. Then repeat inside the curb: nothing happens. Record the result in HANDOFF as done or outstanding; do not claim it without the run.

### Task 9: End-to-end pass and notes

- [ ] **Step 1:** `lune run tests/run`, `stylua --check src tests` and `selene src` all pass.
- [ ] **Step 2:** One uninterrupted MCP playtest at timeScale 1, with no DevHooks except `state`:
  - pedal on the wheel;
  - walk to a nest and grab with `E`;
  - get chased (and caught, if it happens);
  - reach home and deposit with `E` at the incubator;
  - after the real unwrap time, see the reveal card and watch cash tick.

  Note anything that felt wrong.
- [ ] **Step 3:** Update `codex/HANDOFF.md` with what works, what was verified and how, what is outstanding (the two-player bat check, feel tuning, and that persistence is absent), and the next step. Record the decisions table as prototype proposals in `codex/PROJECT_CONTEXT.md`.
