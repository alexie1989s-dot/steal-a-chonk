# Current handoff

Updated: 2026-10-01 by Claude Code. The vertical-slice greybox prototype was built on 2026-09-24; the Showcase heist (Alpha step 1) was built on top of it on 2026-09-27; the presentation pass landed on 2026-09-29. The Codex art notes further down (2026-09-07) are history: art is paused during the prototype.

## 2026-10-01 Render pop-in investigated; the idle bob was broken (Claude Code)

The user reported that "renders adjust poorly and draw on screen" when moving, said they do not see
it in live games, and asked whether Studio can test everything.

**It is not part streaming.** `workspace.StreamingEnabled` is **false** (Rojo builds the place with
the engine default, and nothing in `default.project.json` turns it on), so no part is streaming in
or out. `ModelLevelOfDetail` is `Automatic` on all 501 Models but that only applies under streaming.

**Performance is not the problem either.** Measured on the client: 60 FPS standing still and 60 FPS
running a lap across the field, worst frame about 20 ms, zero hitches over 50 ms.

**The likely cause is Roblox's automatic quality adjustment reacting to Studio's unstable frame
rate.** `UserGameSettings.SavedQualityLevel` is `Automatic`, so the renderer continuously steps
render distance, shadow detail and lighting fidelity up and down to hold a frame budget. Studio's
frame rate here is not stable: **the same scene measured 15.0 FPS and then 60.0 FPS minutes apart,
with Studio unfocused both times**, and at 15 FPS three very different render loads all reported
exactly 15.0, which is a throttle rather than a measurement. A live client has a steady frame budget
and the player's own quality setting, which is why the user does not see it there.

A caution for the next person: **a frame-rate number taken from Studio over the MCP bridge is not
evidence.** Studio throttles when it is not the foreground window, and the first round of
measurements in this session was invalid for that reason.

**Found and fixed while looking: the idle bob was mostly not running at all.**
`Idle.track` returned early when `model.PrimaryPart` was nil, and **the `ChonkIdle` tag replicates
to the client before `PrimaryPart` does**, so almost every Vault display was dropped and never
animated. Instrumenting it showed `tracked=1` against 11 tagged models. It now waits on
`GetPropertyChangedSignal("PrimaryPart")` and tracks the model when the property lands.
Verified: a near model's pivot drifts 0.062 studs over a third of a second where it used to read
0.000 across five samples. This had been "verified" on 2026-09-29 from a single sample that must
have caught the one model that won the race.

**Two cost reductions made at the same time, both measured as counts rather than frame rates:**

- `Idle` now animates only models within `Config.Idle.maxDistance` (70 studs) of the camera. It was
  re-pivoting every tagged Chonk every frame, which with eight filled plots is about 96 models of 13
  to 32 welded parts each, most of them off screen. Verified: a model beyond the range holds still.
- Shadow casting is off for the flat ground discs and grass patches (their shadows are underneath
  them) and for the whole boundary, which sits 350 to 520 studs out past the shadow map's useful
  range. Casters went from 4319 to 3407 with no visible change.

**What Studio cannot test**, which is the user's actual question: its renderer shares the GPU with
the editor and throttles in the background; Play Solo runs server and client in one process so
replication timing is unreal; mobile input, mobile GPUs and real network conditions are absent.
`Test > Clients and Servers` gets closer for replication. The only way to see what a player sees is
to publish to a private or unlisted place and open it in the Roblox client.

## 2026-10-01 Clipping fixed and the camera zoom bounded (Claude Code)

The user reported clipping "here and there" and asked for a proper camera zoom range, with
unlimited zoom kept for debugging only.

**Clipping was measured, not eyeballed.** `.claude/tools/studio/clip_check.luau` fills a plot at the
largest size the catalog can roll, then reports axis-aligned overlaps between every model on the
pads and oriented-box tests against the plot's walls, trim and roof. `fillVault` now takes an
optional size so the worst case can be set up.

| Found | Fix |
| --- | --- |
| **14 model-to-model intersections, worst 1.95 studs.** Ten max-size Chonks on the Vault pads fused into one mass | Below |
| **Incubators 6 studs apart, a max-size burrito 9.2 long** | Moved to local x 5 and 15, 10 apart |
| **Carried Chonk sat 1.5 studs above the root**, which is inside the avatar's head and hair (a tester feel note) | `Config.Carry.liftAboveRoot = 2.9`; measured clearance above the avatar is now 0.81 studs |
| **A max-size practice Chonk went through the practice house roof** (it would top out at 9.7 and the roof bottom was 7.5) | Walls 7 -> 10 tall, roof 8 -> 11, sign 12 -> 15. Clearance is now 0.8 studs |
| Display rows were 8 studs apart | 11, the widest the room allows between the z -8 equipment row and the back wall |

**The Vault grid needed a ruling and got one.** Five columns need 10.4 studs each (42 total) and the
house interior is 38, so **ten full-size Chonks cannot fit in a 40-stud house** -- no grid of ten
fits, which was checked rather than assumed. The user was given four options (cap the sizes, bigger
houses, fewer pads, or a display-only scale) and **chose to cap the sizes (user, 2026-10-01)**:
`Config.SizeScale` goes `{1, 1.15, 1.3, 1.5, 1.75, 2.1}` -> `{1, 1.07, 1.14, 1.21, 1.28, 1.35}`.
A size 6 Chonk is no longer dramatically bigger than a size 3; that is the accepted cost.
`sizeScale` is purely visual, so no economy number moved.

To stop it drifting back: the pad grid is now derived from `Config.Vault.displaySpacing` in one
place, `Config.WidestBodyProfile` records the widest `wide` in Models' SPECIES table, and a Lune
test asserts `4 * sizeScale(6) * WidestBodyProfile` fits inside the spacing on both axes.
**Re-measured: 0 model-to-model and 0 model-into-structure intersections at the largest size.**

**Camera zoom is bounded.** `Config.Camera.minZoom = 8`, `maxZoom = 36`, against Roblox's defaults
of 0.5 and 400 which let a player sit inside their own avatar or pull back past the boundary hills.
`Config.Debug.freeCamera` restores 0.5/400 and is toggled by `DevHooks:Invoke("freeCamera", true)`;
it is off by default, so players never get it.

A gotcha worth keeping: **StarterPlayer seeds `CameraMinZoomDistance`/`CameraMaxZoomDistance` when a
player joins and overwrites anything set at `PlayerState.Added`.** The limits are applied again once
the character exists. Verified: a fresh join reads 8/36, `freeCamera(true)` reads 0.5/400, and
`freeCamera(false)` puts it back.

**Still there, not clipping:** two name-tag plates can overlap each other when two Chonks line up
behind one another from the camera's angle. That is billboard crowding, not geometry.

## 2026-10-01 The map is enclosed (Claude Code)

The user pointed out that the map edges looked open: past the tree scatter the grass ran flat to a
hard horizon with the baseplate edge showing, which reads as "the level stopped here". The field is
now a valley.

**Built** in `World.luau` as `boundary()`, called from `World.build`:

- **One invisible wall** -- 72 segments at `fieldOuterRadius + 4` (324), 70 studs tall,
  `Transparency = 1` and `CanQuery = false`, so it is solid to a player but invisible to every
  raycast. **This is a behaviour change:** a player could previously run out of the field across the
  open baseplate, and now stops at the boundary. Verified: walking outward ends at r = 322.
- **A near rim of 44 wooded hills.** Each is a half-buried dome pushed out far enough that its foot
  lands just outside the wall, so a player running at the boundary stops where the ground begins to
  rise. 2 to 4 trees are planted up each slope at the dome's true surface height.
- **A far ridge of 48 taller hills** at one fixed radius so they always overlap, lerped toward the
  sky colour for aerial perspective. An earlier version varied the ridge radius and left gaps you
  could see the open horizon through from a raised camera.

**Everything visible is still `CanCollide` and `CanQuery` false.** Only the wall collides, which
keeps the repository's scenery rule intact and means a player can never be wedged between two
boundary pieces. Guardian models do not collide either, so a chase is unaffected.

**Three things found by looking at screenshots, not by reasoning:**

- Hills this large **cast hard black pockets onto each other**, which read as holes in the
  landscape. They are now `CastShadow = false`: lit by sun and sky, casting nothing.
- `GRASS_DARK` was far too dark for a face this size -- the side turned away from the sun went
  almost black and the rim read as a wall. The hills have their own lighter greens now, and
  `OutdoorAmbient` was raised from 0.36 to 0.66 so a big shaded face is filled by the sky rather
  than going flat black. `ClockTime` moved 14.3 -> 13.2 for the same reason.
- Trees on the slopes were placed from their **radial** offset alone, but the angular jitter moves
  them sideways along the dome where the surface is lower, so some stood with their trunks buried
  and a single leaf floating in the sky. They now use the planar distance to the dome's centre.

**Verified.** 76 Lune tests, StyLua, Selene, Rojo build. In Studio on a rebuilt place: the smoke
test is unchanged (385 plot parts, 16 prompts, 10 idle-tagged Chonks), the deferred-minors
verification still passes end to end, containment stops the player at r = 322, and the horizon is
closed at player height and from a 90-stud camera at every bearing checked.
**Cost:** 684 parts for the boundary; the whole workspace is 4080 parts with no plot filled.

A trap for whoever drives Studio next: a `screen_capture` taken a few seconds after `start_stop_play`
can come back showing a half-built world (one shot here had no boundary in it at all, while the
server reported 92 hills present). Re-shoot before believing a frame.

## 2026-10-01 Second presentation pass: the genre look (Claude Code)

The user asked for a larger polish so the prototype can be shown to the mates, aiming at the look
and style of the reference game while keeping our own systems. Still **part-craft only**: Studio
primitives, materials and Lighting properties. No Blender, no Meshy, no Studio AI generation, no
Creator Store, and no asset ids. Nothing here is accepted art.

**What the reference actually looks like, and how that was established.** The four images on the
reference game's Roblox store page and the hero image on its beginner guide were fetched and looked
at directly (`games.roblox.com/v2/games/<universeId>/media` -> `thumbnails.roblox.com`). **All five
are promotional renders, not in-game captures** -- no in-game screenshot source was found, and the
game's own wiki says its gameplay gallery is not populated yet. So they establish the *brand*
language the genre sells on, not the shipped frame:

- saturated, high-contrast colour with a deep blue sky; no grey haze;
- big chunky blocky creatures, flat-shaded, two or three tones each, read entirely by silhouette;
- glow and rim light used sparingly as the accent;
- heavy outlined display type, bright green money figures, strong per-biome colour blocking.

Text sources separately describe fenced per-player plots and pets on display generating income,
which is what we already build. **The partner's play experience is still the ground truth for how
the reference game actually plays and looks; this is colour direction, not a mechanics source.**

**Changes.**

| Area | Change |
| --- | --- |
| `default.project.json` Lighting | Atmosphere haze 1.4 -> 0.3 and density 0.32 -> 0.16 with a saturated blue decay. The haze was greying every colour past about 40 studs and was the single biggest cause of the washed-out look. brightness 2.8 -> 3.0 with the sky's `OutdoorAmbient` raised to fill shaded faces, ColorCorrection saturation 0.22 -> 0.38, bloom threshold 1.5 -> 1.95 so only neon blooms, depth of field pushed back |
| `default.project.json` Baseplate | `LeafyGrass` -> `Grass` and a brighter, more saturated green; the old olive read brown next to the district |
| `Plots.luau` | Eight saturated house colours, one per plot, white trim kept; warm oak decking in place of the pale cream. Eight houses in a ring are now told apart at a glance |
| `World.luau` | District paving warmed from near-white to sand with a lighter accent ring; the zone signpost raised clear of the tree line and its post cut to reach the ground from any height |
| `Models.luau` | New `Models.pill`, the house style for world text: dark rounded plate, accent rim, padding. `nameLabel` uses it with the tier colour as the rim, so rarity reads across the district |
| `Plots.luau`, `DummyBase.luau` | Owner nameplates and the practice-house sign use the same plate; the practice sign is one plate holding a heading and a body |
| `World.luau` | The zone billboard was sized in **pixels**, so it kept its screen size at any range and ballooned over the whole district from the field. Now sized in studs |
| `Strings.luau` | The practice sign no longer repeats its own title in the body (a tester feel note) |

**Verified.** 76 Lune tests, `stylua --check src tests`, `selene src`, `rojo build`, JSON valid.
In Studio, the place was **rebuilt and reopened** (Rojo does not live-apply project property
changes) and played solo: smoke test unchanged at 385 plot parts, 16 prompts, 10 Chonk models all
idle-tagged. Screenshots taken before and after at district scale and at player height.

**Not verified:** the field itself -- nests, guardians and scatter -- was not re-captured after the
grass change, because the Studio window was minimised and `screen_capture` renders the 3D view
black while it is. The field uses the same materials and lighting as the district, so it is
expected to be fine, but nobody has looked. Two-player behaviour remains untested as before.

A working note: `.claude/tools/studio/tune_light.luau` patches Lighting in the open place for fast
grading; the numbers it holds are the ones now in `default.project.json`, so it is only useful when
trying new values.

## 2026-10-01 The seven deferred minors, fixed and verified (Claude Code)

All seven "known minor issues, deferred" from the heist review in
[PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) are fixed. No new feature work; no design question was
decided.

| Was | Now |
| --- | --- |
| `Config.Showcase.slots` above 2 errored at boot on a `Showcase3` pad that is never built | `Plots.showcasePads()` reports the pads that exist, the new pure `ShowcaseRules.usableSlots` takes the smaller of the two, and `Showcase.slots()` feeds every slot loop. Boot warns once and carries on |
| `Vault.addRecord`'s "no pad" result was unchecked, so a Chonk could be forgotten | Callers ask `Vault.freePad` **before** letting go of the item (`Showcase.toVault`, `Vault.deposit`), and `returnToOwner` puts the record on its pad before forgetting the item |
| The loose-return and practice-respawn loops would stop for the session on one bad item | Each step runs through a `guarded` pcall that warns once per distinct fault; the cooldown sign and the porch unwrap are now their own named steps. A failed practice respawn waits a full interval instead of retrying every tick |
| The alarm token restarted from 0, so an owner change could hand a new alarm a token an older thread still thought was its own | One counter that never repeats |
| A stolen item kept its model parented under the victim's plot | `Carry` owns `Workspace.World.Carried`; `pickUp` moves the model there, and `Vault.startIncubation` moves it under the plot that is unwrapping it |
| Two reach configs: the steal re-check read `Config.Nest.grabDistance`, the prompt read `Config.Showcase.placeDistance` | `Carry.pickUp` picks the reach from the item's status -- a porch item uses the Showcase distance, everything else the nest's. Both are 8, so behaviour is unchanged |
| A Chonk collided until it had been carried once, then never again | The Chonk body is `CanCollide` false from the start, like the burrito body and every decoration, so a seated Chonk can never block a player on their own porch. The geometry contract records why |

`DevActions`' `porch` hook had the same slot bug and now uses `Showcase.slots()` too.

**Verified.** Headless: 76 Lune tests (3 new, covering `usableSlots` and `canPlace` honouring the
capacity it is given), `stylua --check src tests`, `selene src`, `rojo build`. In Studio, solo play
through `ServerStorage.DevHooks` and the live instance tree
(`.claude/tools/studio/verify_minors.luau`):

- a stolen practice Chonk sits in `World.Carried`, not under the house it came from, with
  `CanCollide` false; a Vault display Chonk reads `CanCollide` false too;
- `toVault` with 10 of 10 pads used returns `false, "vaultFull"`, the Vault stays at 10 and the
  Chonk is still on porch slot 1 -- nothing is lost;
- `robMe` turns the porch lights dark red, the raid-cooldown sign counts down, and after the alarm
  the lights read 255,226,160 again;
- the sign switches **off** once the cooldown lapses, which only the background loop does, so the
  loop was still alive after handling the loose item; the robbed Chonk came home to porch slot 1;
- `Config.Showcase.slots = 3` now boots with
  `[Showcase] Config.Showcase.slots is 3 but Plots builds 2 porch pads; using 2.` and plays
  normally (same 385 plot parts, 16 prompts, 10 idle-tagged Chonks as the 2026-09-29 baseline).
  Config was put back to 2 and the place rebuilt and re-smoked.

**Not verified, unchanged from before:** the alarm flicker needed a robbed owner leaving and a new
owner being robbed within 6 s, which takes two players. The fix is a one-line token change and
reads correctly, but like everything two-player it is on the testers' list. The error path inside
`guarded` was exercised by the loop surviving its real work, not by an injected fault.

A note for whoever drives Studio next: `require(ServerScriptService.Server.X)` from an
`execute_luau` script evaluates a **fresh copy** of that module, not the one the running server
booted, so `PlayerState.get` comes back empty and every module-level table looks blank. Drive the
game through `ServerStorage.DevHooks` and read the instance tree, as `AGENTS.md` already says.
Studio's version folder moved again, to `version-76e1a02649ad4f35`; resolve it, never hardcode it.

**Next step:** unchanged -- the testers run the two-player checklist and judge the feel, the devs
rule on the heist proposals, and someone needs to rule on where game audio comes from.

## 2026-09-30 Integrated into main (Claude Code)

The heist and the presentation pass were committed as `9013474` and merged into `main` as
`a19b496`; `898f279` then reworded the README. **`main` and `prototype/vertical-slice` now point
at the same commit** and both are pushed, so a collaborator can clone and run without choosing a
branch. The `README.md` add/add conflict was resolved by keeping the branch version and rewriting
its front matter and Branches table.

Added in the merge: a root `.gitattributes` pinning `*.luau`, `*.toml` and `*.json` to LF. StyLua
is configured `line_endings = "Unix"` while `core.autocrlf` is true on Windows, so a fresh clone
failed `stylua --check` on every file with a diff showing identical text on both sides. The README
says how to fix an older clone. The local working tree was renormalised the same way.

The README also gained the collaborator notes the user asked for: a read-this-in-this-order
orientation section, how the pieces fit (server authority, why `src/shared` is pure and headlessly
testable, the code-generated map, `Carry` as the one item registry) and a "things that will bite
you" list (Rojo dropping `Position`, Rojo not live-applying project property changes, the Chonk
geometry contract, scenery that must not collide).

**Pre-push scan, reported as required:** 30 committed files, all text, no new binaries. No emails,
credentials, tokens or Roblox asset ids. The 17 tracked binaries were checked including inflated
PNG `tEXt`/`zTXt`/`iTXt` chunks and `corgi.blend` fully decompressed across every zstd frame
(1.99 MB compressed, 6.14 MB raw; a single-frame read only reaches the first 67 KB, so read across
frames or the check is worthless). Its 21 embedded paths all read `c:\Users\username\...`, the
placeholder left by the earlier history scrub -- no real username.

Deleted after the commit: the heist execution ledger at `.superpowers/sdd/2026-09-25-showcase-heist/`.

Still excluded from Git on purpose: `assets/tools/start_blender_mcp.py` (modified) and the untracked
Blender corgi redesign set. Those remain the user's set-aside experiment.

**Next step:** unchanged -- the testers run the two-player checklist and judge the feel, the devs
rule on the heist proposals, and someone needs to rule on where game audio comes from.

## 2026-09-29 Presentation pass (Claude Code)

The user asked for the prototype to stop looking "ugly and unfinished" and to read as close to a
finished game as possible, and asked whether better models were possible without Blender. They
were: **everything below is built from Studio primitives only.** Asked how far to bend the paused
art track, the user chose **part-craft only** -- no Blender, no Meshy, no Studio AI generation, no
Creator Store assets. See `PROJECT_CONTEXT.md` for the ruling.

**This is still placeholder greybox art.** No Chonk has been accepted by the partner devs, and the
art milestone (one accepted Chonk, then a second to prove repeatability) is untouched. What changed
is how the prototype presents itself so the loop can be judged on its own terms.

**What changed:**
1. **Lighting.** `default.project.json` set no `Lighting` properties at all, so the prototype ran on
   Studio's flat defaults. It now sets ShadowMap shadows, a mid-afternoon `ClockTime`, warm ambient
   and colour shift, and carries an `Atmosphere`, a `Sky`, and Bloom, ColorCorrection, SunRays and
   DepthOfField effects. This was the single biggest change per line of code.
2. **Ten distinct Chonks.** `Models.chonk` was a sphere with two ears and two eyes (5 parts). It now
   reads the catalog's existing `species` field and builds a per-species silhouette from 13-32 parts:
   the frog's eyes ride on top of its head, the penguin has a tuxedo front and a tapering beak, the
   capybara's snout is an actual box, the axolotl has three frills a side, the corgi's legs plainly
   do not reach the ground, the panda has patches and a saddle. Eye catchlights, blush and a muzzle
   do most of the "affectionate" work (spec §1).
3. **Geometry contract kept.** Vault, Showcase and DummyBase all rest a Chonk with `pad.Y + d / 2`
   and hang its tag at `d / 2 + 1.5`, where `d = 4 * sizeScale(size)`. The body's Y extent is still
   exactly `d` and the pivot is still the body centre, so no caller changed.
4. **Burrito and guardian.** The burrito is a smooth bundle with rounded ends and a neon tier bow;
   Mama Chonk gained a brow, pupils, a snout and teeth so she reads as a threat (spec §11).
5. **World.** Layered paving with a centre medallion, a striped kerb with rounded caps, a safe-side
   neon line and lamp posts, woven nest bowls with twig rims, rounded hedges, and a deterministic
   scatter of trees, rocks, flower patches and grass patches over the field (seeded, so both devs see
   the same field). A real signpost replaces the floating zone text. The baseplate went 800 -> 2400
   because its edge was visible from the district.
6. **Houses.** Taller walls with capping trim, a red gable roof over the back wall, a door, windows,
   a porch pergola, a step, lit Showcase pedestals, ringed Vault pads, glass incubator domes and a
   stand for the wheel. **The play area is deliberately left unroofed:** the Vault pads are inside
   the house and a roof over them fights the camera every time a player walks in to sort Chonks.
7. **HUD.** Stat pills with chip icons, gradients, strokes and drop shadows; counters that roll up
   and flash on a gain; a toast that drops in. A `UIScale` shrinks the bar on narrow screens (§2).
8. **Idle motion.** A new client `Idle` module bobs and sways seated Chonks. It is decoration only:
   the models are anchored and the server never moves them. `Carry.setStatus` is the single status
   writer, so it adds the `ChonkIdle` tag when a Chonk is seated and removes it the moment the
   server takes it back, which is what stops a carried model being pinned to a remembered pose.
9. **Readability fix.** Ten Vault pads sit seven studs apart and at the old 80-stud tag range all ten
   name tags overlapped into one smear. `Models.nameLabel` takes a range; the Vault passes 30
   (`Config.Vault.labelDistance`) while porch bait keeps the long range on purpose.

**Verified:** `lune run tests/run` 74 passed; `stylua --check src tests` clean; `selene src` 0 warnings;
`rojo build` clean. In Studio (solo play, via the local MCP bridge): clean boot with no errors;
`fillVault` + `toPorch` gave plot 1, Vault 9, Showcase 1, 10 Chonk models, 10 idle-tagged, 385 plot
parts, 16 prompts; cash ticked; a client sample of a tagged model's height moved 3.362 -> 3.490 over
five frames, so the idle bob is running. Screenshots were taken at each step and the geometry was
corrected against them, not guessed.

**Found by looking rather than by reasoning** (each was wrong in the first build and fixed after a
screenshot): belly patches were entirely buried inside the body sphere; `WedgePart` ears vanished
edge-on and a 45-degree square still read as a square; the kerb caps had a doubled rotation and stood
up as bollards; the gable slabs' rotation sign was matched to `side`, which built a valley instead of
a roof; the wheel stand was aligned to the flat treadle instead of the upright ring.

**Not done, and why:** **sound.** The game still has no audio at all, and that is the biggest single
thing still missing. Every route to it needs an uploaded asset id, which is outside "part-craft
only", so it needs a ruling first -- Roblox's own official free SFX library is the obvious candidate.

**Next step:** unchanged -- the testers run the two-player checklist below and judge the feel, and the
devs rule on the heist proposals. The presentation pass touched no rules, so that checklist still
stands as written.

## 2026-09-27 Showcase heist (Claude Code)

Built from [the heist plan](../docs/superpowers/plans/2026-09-25-showcase-heist.md) on `prototype/vertical-slice`, with its proposals as written (see `PROJECT_CONTEXT.md`). Verified solo; the two-player checks below are still open.

**What a player can now do, on top of the slice:**
1. Press **Put here** (E) on one of two porch pads to unwrap a burrito there at half the Vault time, or to show off a Chonk. Porch Chonks earn +50 %.
2. Press **To Vault** on a porch Chonk or **To Porch** on a Vault Chonk while standing at home.
3. Hold **Steal** (E, 1.5 s) on a neighbour's porch item and carry it home under the normal carry rules; **Put in Vault** at an incubator stashes a carried Chonk straight onto a Vault pad.
4. Practise on the **Practice House** at the district centre: one free Common per player per session, refilled 45 s after it is taken.
5. As the victim: porch lights blink red for 6 s, both players get a toast ("Beans has been stolen. Beans is not surprised."), and the porch is immune for 2 minutes with a countdown sign.
6. Nothing is deleted while its owner is on the server: a dropped stolen item walks home after 60 s (porch first, then Vault), and an item whose carrier leaves goes straight back. When an owner leaves, their items leave with them (session-only prototype).

**End-to-end at real speed (timeScale 1), real key and mouse input, DevHooks only for `state`:** walked to the Practice House and held E 1.7 s → carrying a Common at 12.8; walked home and pressed E at the incubator → "Stashed in the Vault", Vault 1, cash ticking; stood on the wheel and pressed E 70 times → 150 Zoomies (speed 23.2); walked to nest 5 and pressed E. The first try was caught by the Patroller right after the grab (she was on the near side of her loop). The retry was timed for the far side and made it home carrying (18.8 vs her 17). E on the porch pad → the burrito showed 9.5 s left against 20 s in the Vault, revealed at 9.8 s, and the reveal card read "Kevin, A Fine Boi … +1.5 cash/s"; a click dismissed it. Income 2.5/s = 1 (Vault Common) + 1.5 (porch Common). The console showed only the boot lines.

**Map fix found during the playtest:** Rojo 7.7 silently drops the `Position` property, so every fresh `rojo build` had put the 20-stud Baseplate at y = 0 and buried the whole map, player houses included, under the grass. `default.project.json` now sets an explicit `CFrame` for the Baseplate (y −10) and the SpawnLocation. The built XML was checked. Anyone with an older built place should rebuild it.

**Final review (fresh reviewer, Opus):** verdict "ready to merge", with no Critical or Important findings as labelled. Three of its minors were re-graded by their effect on players and fixed, each with a test that failed first:
- A practice Chonk shown on a porch had two stacked name tags. Studio check: 2 → 1.
- A player who had already kept a practice Chonk could grab a loose one they could never deposit, and was stuck at carry speed. `Carry.pickUp` now refuses with `dummyDone`. Studio check: grab succeeded → refused.
- The 1.5 s Steal hold was enforced only by the client. The server now times the hold itself (`ShowcaseRules.heldLongEnough`, 0.25 s jitter allowance). A new Lune test covers it (74 tests pass). Real input: a 0.4 s tap took nothing, and a 1.7 s hold stole.

The deferred minors are listed in `PROJECT_CONTEXT.md` under the heist section.

**Two-player checklist for the testers** (Studio → Test → Clients and Servers, 2 players):
1. Only the neighbour sees **Steal**; only the owner sees **Put here**, **To Vault**, **To Porch**, **Put in Vault** and **Pedal!**
2. The neighbour steals a porch Chonk. The victim's porch lights flash red, both toasts appear, and the thief walks home at carry speed and deposits it.
3. A second steal on the same porch within 2 minutes → the "just robbed" toast.
4. The thief resets mid-carry: the Chonk lies loose, then returns to the victim after 60 s.
5. The victim leaves while the thief carries: the Chonk vanishes from the thief's hands, the thief's speed resets, and the thief gets the "went home" toast.
6. The bat in the field still drops a thief's Chonk; inside the curb it does nothing (proposal row "Bat inside the district").
7. The slice's pending check: two-player bat hit in the field (see the slice section below).

**Outstanding:**
- The two-player checklist above has not been run: the Studio MCP only starts solo playtests.
- Persistence is still absent (session-only). No phone test and no performance test yet.

**Feel notes from the runs (for the testers to judge):**
- A rookie still has to time the Patroller, even at ~160 Zoomies: she caught the first grab at 18.8 vs 17.
- A carried size-1 Chonk sits slightly into the avatar's hair (lift 3.6 studs).
- The practice-house sign repeats its title ("Practice House" over "PRACTICE HOUSE: steal the Chonk…"). All heist copy is draft.

**DevHooks added:** `porch(name)`, `toVault(name, slot)`, `toPorch(name, pad)`, `steal(name, plotIndex, slot)` (`plotIndex` 0 = the Practice House), `robMe(name, slot)` (Studio-only victim seam). `state` now has `items` (replacing `burritos`) and `dummy`, and each player has `showcase`, `immuneFor` and `dummyTaken`.

**Next step:** the testers run the two-player checklist and judge the feel; the devs rule on the heist proposals. Then the rest of the Alpha (shields and the away timer, Grudge/Wanted, rebirth and Zone 2, persistence).

Per-task evidence:

- **Task 1 (pure rules):** new `Slots` and `ShowcaseRules`, `VaultRules.hasRoom/canStash`, `Format.clock`, `Config.Showcase/DummyBase` and the heist copy in `Strings`. `lune run tests/run`: 73 passed. StyLua and Selene clean.
- **Task 2 (refactor):** every physical item is one `Carry.Item` registry entry (`register/forget/items/setStatus`); Vault records are keyed by display pad; `Models.chonk` is welded; label helpers moved to `Models`. Studio regression through DevHooks at timeScale 0.05: grab → deposit → Vault 1 after 5.5 s (Uncommon size 5), income 35/s; a carried nest-2 burrito shows `carried` and wakes guardian 2; a dropped burrito is back `ready` at its nest after 3.5 s; `fillVault` then deposit → `false, "vaultFull"` while still carrying. Console showed only the boot lines.
- **Task 3 (porch Showcase):** two `Showcase` pads, porch lights and a hidden raid-cooldown sign per plot; "Put here", "To Vault", "To Porch" and "Put in Vault" prompts; porch unwrap at half the Vault time; porch income ×1.5; a client `PromptFilter` shows owner prompts only to the owner. Studio at timeScale 0.05: a Common size 1 placed on the porch reported 0.50 s left (Vault: 1.0 s) and revealed as a Chonk with the reveal card shown; income 1.5/s on the porch, 1/s after "To Vault"; "To Porch" put it back; "To Vault" from the field → `awayFromHome`; a third item on a full porch → `porchFull` while still carrying. Client: own pedal, incubator, move and place prompts enabled; another plot's place and pedal prompts disabled. Console clean.
- **Task 4 (stealing and the practice house):** neighbours see a 1.5 s "Steal" hold on porch items; a new `DummyBase` builds a practice house at (0, 24) with a random Common on its porch. Carried Chonks can be stashed in the Vault or shown on the porch; a stolen burrito keeps its unwrap fraction. Studio at timeScale 0.05: stealing the practice Chonk at 0 Zoomies gave WalkSpeed 12.8; deposit → Vault +1, `dummyTaken`, income 1/s; a second practice steal → `dummyDone`; stealing from your own porch → `yours`; stealing while carrying → `alreadyCarrying`. Same-call races: two steals → `true` then `taken` with exactly one carried practice Chonk; the owner's "To Vault" then a steal → move `true`, steal `taken`, Chonk only in the Vault. Full Vault and porch → `vaultFull` and `porchFull` while still carrying. The practice porch refilled 2.40 s after the steal (45 s × 0.05 plus the 0.25 s tick). Console clean.
- **Task 5 (victim side, nothing deleted):** a theft starts the victim's raid cooldown (120 s × timeScale), blinks their porch lights red for 6 s, shows a "Raid cooldown m:ss" sign and sends both theft toasts. Dropped owned items walk home after 60 s (porch first, then Vault); an item whose carrier leaves goes straight back; when an owner leaves, their items leave with them and a thief carrying one is told. Studio at timeScale 0.05, through the `robMe` victim seam: a porch burrito robbed at 53 % done lay loose with its owner set; `immuneFor` 6.0; a porch light read red within 1 s and was back to normal at 6.6 s; the sign read "Raid cooldown 0:06", then 0:04, and hid at 6.4 s; the burrito was back on its porch after 3.07 s with 0.22 of its 0.5 s left (resumed, not restarted). Kicking a thief who carried the practice Chonk put the same Chonk (same id) back on the practice porch, with no loose copy. Kicking an owner whose Chonk lay loose and whose burrito was incubating left no owned items, no models on the plot, both "Put here" prompts restored and no incubator label.
- **Tooling note:** after the latest Studio update, Claude Code rejects the Studio MCP's tool list (`ttlMs`/`cacheScope` schema), so its tools do not load. The session drove StudioMCP.exe over stdio through a small local bridge instead. Non-ASCII text in `execute_luau` code arrives mangled, so the Rojo plugin (or byte-escaped strings) is the safe way to sync sources.

## 2026-09-25 (Claude Code)

- **Direction:** the user set art aside for the prototype. The work is prototype construction and tests in Studio, with built-in parts as placeholders. The Blender corgi set stays untracked and was not sanitized or committed. See `AGENTS.md` and `PROJECT_CONTEXT.md`.
- A mistaken Studio AI corgi trial was made and then removed from the place; see `PROJECT_CONTEXT.md`. The open place is back to Baseplate, SpawnLocation and Terrain.
- **Verified today:**
  - `lune run tests/run`: 56 passed.
  - Rojo serve was up.
  - Studio playtest smoke test through DevHooks: grab nest 1 → deposit → unwrap → Vault display model → income at 7.5/s for an Uncommon of size factor 1.5. The console showed only the two boot lines.
- **DevHooks note:** `setTimeScale` multiplies durations. Use 0.05 for 20× faster timers; 20 makes them 20× slower.
- **Next build (chosen by the user):** the Showcase heist, Alpha step 1. The plan is [2026-09-25-showcase-heist.md](../docs/superpowers/plans/2026-09-25-showcase-heist.md), with a proposals table for the devs. It was written but not yet executed, pending the user's review.
- **READMEs (user rule):** every branch on GitHub, `main` included, carries a root `README.md` written for the partner devs; the rule is in `AGENTS.md`. Added to `main` and to this branch and pushed. Both branches add the file, so merging this branch into `main` conflicts on `README.md`: keep this branch's version and refresh its Branches table.
- **Fresh-clone fix:** `rojo build` fails when `build/` doesn't exist (it is ignored, so a clone lacks it). The run steps below now create it first.
- **Public repo (user request):** GitHub has no unlisted option, so the user chose public. Before publishing, the Windows username was scrubbed from all history: the `File` text chunk of the two corgi renders, and 22 paths inside `assets/chonks/corgi/corgi.blend`. That file is zstd-compressed, which is why earlier raw scans found nothing. Its paths now read `username`, and nothing else in it changed. Every commit SHA changed; authors, dates and messages did not. GitHub keeps force-pushed commits reachable by SHA, so the scrubbed history went to a fresh public repository at the same URL. The original repository is kept, private, as `steal-a-chonk-private-archive`.

## Vertical-slice prototype (2026-09-24, Claude Code)

**A playable greybox of spec §23 step 1 exists in `src/` and runs in Roblox Studio.** The user asked for it before any art was accepted, and all art is placeholder parts. The plan, including every prototype decision the spec left open, is in [the vertical-slice plan](../docs/superpowers/plans/2026-09-24-vertical-slice-prototype.md). Its "Prototype decisions" table lists the proposals for the developers to tune or overrule.

What a player can do:
1. Spawn on their own porch. There are eight houses in a ring inside a painted curb.
2. Stand on the hamster wheel for Zoomies (+1/s), or press **Pedal** (E) for +2. Speed rises as `16 + 6·log10(1 + Zoomies/10)`, and the field of view widens when moving fast.
3. Walk into the Backyards field and **Grab** (E) a blanket burrito from one of 10 nests. The glow hints at the tier; the size hints at the Chonk's size.
4. A Patroller Mama Chonk says MRRP, then rolls after the carrier. She starts slow and ramps to 17 studs/s; carrying slows the player by tier.
5. If she catches you, the burrito drops at your feet and you are knocked back. Anyone may pick it up, you included.
6. She stops at the curb. Crossing it with the burrito shows confetti and a toast.
7. Other players can **Bat** (F / gamepad X / touch button) a carrier in the field to make them drop it.
8. At home, press **Unwrap** (E) at one of two incubators. The real unwrap time follows §25, then a full-screen reveal card appears: tier, species, name with size, size stamp, bio, income. One tap dismisses it.
9. The Chonk sits on one of ten Vault display pads and earns cash every second.

**Verification actually run:**
- **Lune:** 56 unit tests in `tests/` pass (`lune run tests/run`), covering Formulas, Catalog, Naming, Rolls, Signal, Layout, Format, GuardianBrain, VaultRules and BatRules.
- **StyLua / Selene:** clean on `src` and `tests`.
- **`rojo build`:** succeeds.
- **Studio playtests via the Studio MCP:**
  - porch spawn and respawn;
  - wheel gain and speed;
  - a real E-key grab;
  - curb crossing;
  - death while carrying leaves the burrito at the death spot;
  - loose burritos return to their nest;
  - two same-frame grabs → exactly one wins;
  - the carry anti-cheat snaps back a 60-stud jump;
  - guardian catch, re-grab and escape;
  - live curb clamp: the guardian stayed ≥ 109.3 from the centre (limit 108.5);
  - deposit, unwrap, reveal and income;
  - refusals: `slotsBusy`, `notYourBase`, `vaultFull`;
  - bat key and cooldown.
- **End-to-end at real speed**, using only the `state` hook to observe: pedal to 170 Zoomies, E-grab while the guardian was on the far side, run home, E-deposit, a 28 s unwrap, the reveal card "Kevin, He Chomnk" at +1.5/s, and cash ticking. The console stayed clean.
- The per-step evidence is summarised here. The local execution ledger was deleted once the work was committed.

**Not done / outstanding:**
- **The two-player bat hit has not been run.** The Studio MCP only starts solo playtests. Use Test → Clients and Servers with 2 players: one carries in the field, and the other presses F in front of them. Expected: the burrito drops, with a knockback and "BONK". Repeat inside the curb, where nothing should happen.
- **The Pedal rate cap (5/s) is untested.** The tool's key timing was too coarse.
- **Persistence is absent:** everything is session-only. **No mobile device test** has been done: touch buttons exist but were not exercised on a phone. **No performance test** has been done.
- **Feel/tuning notes from the run:**
  - A rookie with 0 Zoomies carries at 12.8 against the guardian's 17. They escape only by grabbing while the Patroller is on the far side of her circle.
  - It took a few minutes on the wheel to reach the ~150 Zoomies that outrun her. That is slower than §16's "minute 2 first burrito".
  - The reveal card shows the size twice: in the name suffix and in the stamp.
- The names, bios and toasts are draft copy for partner review.

**How to run it:**
1. Run `rokit install`.
2. Start `rojo serve default.project.json` from the repo root.
3. Open any place, or run `mkdir build` then `rojo build default.project.json -o build/prototype.rbxl` and open that.
4. Plugins → Rojo → Connect.
5. Press Play.

In Studio, `ServerStorage.DevHooks` (a BindableFunction that exists only in Studio) exposes these test actions: `state`, `setZoomies`, `teleport`, `setTimeScale`, `grab`, `drop`, `deposit`, `fillVault`, `world`.

**Next step:** the two testers play it, including the two-player bat check. Record feel notes and decide on the proposals table, then move to the Alpha scope (§23 step 2). The art track below is unchanged and independent.

## 2026-09-24 check (Claude Code, no art generated)

- No Meshy MCP is registered in Claude Code. The `@meshy-ai/meshy-mcp-server` npm package is still published (0.5.2, modified 2026-09-22). Blender MCP tools are registered in Claude Code; Blender was not running.
- Meshy, from the official help center and API docs: the Free plan (100 credits/month) has neither API keys nor multi-view. Pro costs $20/month for 1,000 credits and includes both. API credit costs are 30 for multi-image-to-3D with a 2K/4K texture, 5 for remesh, 5 for UV unwrap, 5 for auto-rigging, 3 per animation action and 10 for a retexture. The docs do not say whether API calls draw on the web app's credit balance. The earlier Claude notes that assumed remesh and rigging cost 0 were wrong.
- The Codex corgi candidate below still has no user or partner verdict. The resume point is unchanged.

## 2026-09-24 prototype toolchain (Claude Code)

The user chose to start a Roblox Studio prototype before any art has been accepted, using placeholder art.

- **Toolchain:** Rokit 1.2.0 is installed for the user. `rokit.toml` pins Rojo 7.7.0, Selene 0.31.0, StyLua 2.5.2, Lune 0.10.5, luau-lsp 1.70.0 and Wally 0.3.2. Run `rokit install` on a fresh machine.
- **Project:** `default.project.json` maps `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server` and `src/client` → `StarterPlayer.StarterPlayerScripts.Client`. It also defines a grass baseplate (800 × 800) and a centre spawn. The prototype section above describes the scripts. `selene.toml` and `stylua.toml` were added. `.gitignore` now excludes `build/`, Studio lock files, `sourcemap.json` and the Wally package folders.
- **Verified:** StyLua check and Selene both pass. `rojo build default.project.json -o build/prototype.rbxl` succeeds, and Studio opened the built place showing the baseplate and spawn. `rojo plugin install` put the Rojo plugin in Studio's local plugins folder. Rojo live sync (`rojo serve`, port 34872) and the plugin's Connect button have not been exercised yet.
- **Studio:** Roblox Studio was reinstalled; the old version folder was missing. The built-in Studio MCP proxy (`StudioMCP.exe` in the Studio version folder) starts and answers, but lists no tools until the MCP server is enabled in Studio's Assistant settings. That toggle is GUI-only. The user enabled it. Quick connect did not register the VS Code Claude Code, so the server was added by hand at user scope (a local-scope entry was keyed to `C:/...`, and the VS Code session opens `c:/...`, so it never loaded): `claude mcp add --scope user --transport stdio Roblox_Studio -- cmd.exe /c "%LOCALAPPDATA%\Roblox\mcp.bat" --stdio`. Run this from PowerShell, because Git Bash rewrites `/c`. `claude mcp list` reports it Connected, and a direct probe listed 28 tools, including `execute_luau`, `start_stop_play`, `get_console_output` and `screen_capture`. The tools appear after a Claude Code restart.
- **Rojo:** `rojo serve` runs as a detached process (port 34872). Studio's Rojo plugin must be connected once per Studio session (Plugins → Rojo → Connect).
- **End-to-end check (Studio MCP from Claude Code, after the restart):**
  - `list_roblox_studios` found the place.
  - A repo edit to `src/shared/Version.luau` appeared in Studio within 2 seconds, which proves Rojo live sync.
  - `start_stop_play` started a playtest, and `get_console_output` showed the server and client boot lines.
  - The character spawned, and `character_navigation` moved it to about (29, 3, 20), confirmed server-side. `user_keyboard_input` was accepted, but its effect was not checked.
  - The playtest was stopped afterwards.
- **Map geometry:** the built `.rbxl` is ignored, so anything built by hand in Studio is not versioned. Generate prototype geometry from code, or save it into the repo as model files.

## Art state (2026-09-07, Codex)

**The requested Blender/MCP retry produced a reviewable corgi redesign.** The user explicitly authorized this after the initial project-document review. This is a scoped retry of Blender, despite the previous Claude stop/Meshy decision; it does not establish partner acceptance or a permanent replacement pipeline.

Blender 5.1.1 is running with the installed Blender MCP add-on. Its loopback server answered requests after the final bootstrap fix. Codex used a project-local JSON socket client to that add-on, not a registered Codex Blender MCP tool. Scene edits, baking, rendering, export, and GLB reimport all ran through this connection.

At that time the project was at the design/art validation stage, with no Roblox game code. The 2026-09-24 prototype above has since changed that.

## Reviewable output

All new art is in [assets/chonks/corgi/codex_redesign/](../assets/chonks/corgi/codex_redesign/README.md):

- [Editable source](../assets/chonks/corgi/codex_redesign/corgi_redesign.blend): separated body, repaired eye surfaces, eyes/lids, expression, materials and presentation scene.
- [Optimized Blender scene](../assets/chonks/corgi/codex_redesign/corgi_export.blend) and [GLB](../assets/chonks/corgi/codex_redesign/corgi_redesign.glb): 7,270 triangles, one exported mesh, one material, one 2048-square baked base-color texture.
- [Three-quarter](../assets/chonks/corgi/codex_redesign/export_threequarter.png), [front](../assets/chonks/corgi/codex_redesign/export_front.png), [side](../assets/chonks/corgi/codex_redesign/export_side.png), and [back](../assets/chonks/corgi/codex_redesign/export_back.png) renders; export and reimport reports.

The shape retains the original high-resolution generated corgi. The rebuild welds source seams before reducing geometry, replaces damaged eye surfaces, gives it sleepy eyes and a small smile, and applies continuous orange/cream markings and front-only pink inner ears. It uses the existing fur tiles. Original concepts and prototype files were preserved.

This is an unrigged candidate with a color-only bake and uniform export roughness. It has no normal map or animation. The remaining lower-eye contours and overall likeness should be judged in the supplied views. **Art approval and Roblox Studio validation are still outstanding.**

## Code and connection

- `assets/tools/blender_mcp_client.py`: standard-library loopback client for the already installed add-on; supplies `__file__` for portable script paths.
- `assets/tools/redesign_corgi.py`: deterministic study rebuild; if the generated source is absent, appends that object from the untouched original `.blend`.
- `assets/tools/export_corgi_redesign.py`: saves the editable study, reduces copies, joins/unwraps/bakes, exports GLB and renders four views. New saved scenes omit legacy Blender MCP scene properties and pack their required images.
- `assets/tools/start_blender_mcp.py`: now checks the live listener instead of a stale saved scene flag and avoids re-enabling an active add-on. Tested against the running server; cold startup of this revised helper remains untested.

See the [asset README](../assets/chonks/corgi/codex_redesign/README.md) for exact reproduction commands and dependencies. The new scripts regenerate their own output directory and can replace unsaved scene edits; save any manual revisions separately before rebuilding.

## Git checkpoint

- **2026-09-25:** at the user's request, the prototype was committed as one commit on branch `prototype/vertical-slice` (from `main` at `9b8bc71`) and pushed to `origin`. The commit holds the toolchain, `src/`, `tests/`, the plan, `AGENTS.md`, `CLAUDE.md`, the `codex/` notes and `.gitignore`. It is not merged into `main`; see `git log`.
- **Deliberately left uncommitted:** Codex's Blender corgi redesign (`assets/chonks/corgi/codex_redesign/`), its helpers (`assets/tools/blender_mcp_client.py`, `redesign_corgi.py`, `export_corgi_redesign.py`) and the `start_blender_mcp.py` fix. The pre-commit scan found the absolute machine path, which contains the Windows username, embedded in both `.blend` files and all seven Blender renders; Blender writes the render's source file path into PNG metadata. Before committing them, strip the PNG text metadata, re-save the `.blend` files without the absolute path, and rescan.
- **Leak on `main`, resolved 2026-09-25:** `assets/chonks/corgi/chonk_corgi_front.png`, `chonk_corgi_threequarter.png` and `corgi.blend` embedded the same path. The history was scrubbed before the repository went public; see the 2026-09-25 section at the top.
- Branch inspected at onboarding (2026-09-07): `main`.
- HEAD: `9b8bc71112f6104866b58fe45c008733f02b95c6` (`9b8bc71`), initial design/concepts/Blender-pipeline commit.
- Remote configured: `origin`, the private GitHub repository. Local `origin/main` pointed to HEAD; no fetch or live remote check was performed.
- Working tree was clean at onboarding. Ignored Claude notes, a corgi FBX and work intermediates were present locally.
- This session added `AGENTS.md`, `CLAUDE.md`, `codex/README.md`, `codex/PROJECT_CONTEXT.md`, and this file; `.gitignore` gained the `codex/scratch/` exclusion. The subsequent Blender retry added three helpers and the redesign directory, and fixed the existing bootstrap.
- As of 2026-09-07 all these documentation, script and art changes were local and uncommitted. The first bullet above gives what was committed on 2026-09-25. Check live status before continuing.

## What was reviewed and established

- Read the full 26-section design, both ignored `.claude/knowledge-*.md` documents, their referenced Claude project-memory index and all five linked notes, `.gitignore`, and all six Python tools.
- Checked Git history, tracked files, and the full local inventory including ignored assets.
- Inspected the original corgi sheet, existing front crop, flat markings sheet, face image and both saved Blender renders.
- Preserved prior decisions and marked where they supersede older notes. Recorded unresolved spec details without editing the design.
- Added a shared `AGENTS.md` plus a `CLAUDE.md` entry point importing it. The plain `codex/` notes can be maintained by either assistant and do not depend on external session-memory paths.

See [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) for the complete source map, game summary, asset/tool inventory, and unresolved questions.

## Verification and limits

- Successfully executed the rebuild/export again from the cleaned working scene, exercising automatic loading of the original generated source.
- Export budget assertion passed at 7,270 triangles. Reimport of the GLB into Blender measured one mesh, one material and 7,270 triangles; its render matched the export view.
- Visually inspected front, three-quarter, side, back, and reimport renders. No Studio import or in-game performance test was performed.
- Confirmed the optimized corgi is visible in the running native Blender window; left that scene open for inspection.
- Original-asset SHA-256 checkpoint is local in ignored `codex/scratch/blender/original-assets.sha256.json`; final comparison found no changes to those files.
- Shared Markdown links, Python syntax and Git whitespace checks passed. No automated Roblox test suite exists here.
- No game source, configured game toolchain, Meshy output or Penguin output exists. No Meshy tool is exposed in this Codex session; this does not establish account/plan status or Claude Code's connection state. Historical service/pricing/genre claims were not revalidated.

## Art resume point (2026-09-07; independent of the prototype)

1. Read [../AGENTS.md](../AGENTS.md), this checkpoint, [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md), and the relevant original spec sections; inspect live Git status/diffs.
2. Inspect the new saved model/views and get the user/partner's visual verdict on this concrete study. Follow their next art direction; do not call it accepted based on export checks.
3. If the candidate proceeds, validate an actual Roblox Studio import, scale/orientation, appearance and performance. Studio compatibility is separate from a Blender round trip.
4. After a first accepted and validated Chonk, prove repeatability on a second Chonk, then prepare the implementation plan as requested.

The historical Meshy alternative remains documented in `PROJECT_CONTEXT.md`; this Blender retry does not establish a broader pipeline decision.
