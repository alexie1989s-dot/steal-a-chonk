# Steal a Chonk: project context

Onboarded 2026-09-06; current asset update 2026-09-07; vertical-slice prototype 2026-09-24; Showcase heist 2026-09-27; presentation pass 2026-09-29; art paused for the prototype 2026-09-25; repository public on GitHub since 2026-09-25. This is a source-based project summary, not a new game design proposal.

## Art paused during the prototype (2026-09-25)

The user directed that Blender work be set aside for now: the prototype is the priority, built and tested in Roblox Studio with what Studio offers. Placeholder visuals use Studio's built-in parts and materials. No Chonk art work happens until the user resumes the art track. This supersedes, for now, the Meshy direction and the 2026-09-07 Blender retry described below; both are history. Meshy is on hold, not installed. The user describes the Blender corgi work as an experiment. It stays untracked and set aside (see `AGENTS.md`).

On 2026-09-25 Claude Code misread this direction and generated three corgi test meshes with Studio's AI tools. They were removed from the place and are not used anywhere. The generations remain in the user's Roblox inventory as "Roblox Generated Object" models. The acceptance gate is unchanged: nothing generated is accepted art.

## Presentation pass, part-craft only (2026-09-29)

The user said the prototype looked "ugly and unfinished" and asked for it to feel close to a
finished game, and asked whether better models were possible without Blender. Offered three
scopes, the user chose **part-craft only**: models and scenery built from Studio's own primitives
and materials, with **no Blender, no Meshy, no Studio AI generation and no Creator Store or other
third-party assets**. This does not resume the art track. It is the 2026-09-25 "built-in parts and
materials as placeholders" allowance, taken seriously rather than left at greybox.

What this does and does not settle:

- **Still placeholder.** Nothing here is accepted art. The art milestone is unchanged: one
  partner-accepted Chonk, then a second to prove repeatability. A file in Git is not acceptance.
- **The catalog's `species` field now drives shape**, not just flavour text. The ten slice Chonks
  have distinct silhouettes. The names, bios and tier colours are still draft copy for partner
  review.
- **No rules changed.** The heist proposals listed below are still unruled, and the two-player
  checklist in `HANDOFF.md` still stands as written.
- **A geometry contract is now load-bearing** and is written at the top of `Models.luau`: a Chonk's
  body Y extent is exactly `d = 4 * sizeScale(size)` and the model pivot is the body centre,
  because Vault, Showcase and DummyBase all place Chonks with `pad.Y + d / 2` and hang name tags at
  `d / 2 + 1.5`. Anything that changes body proportions must keep that.
- **The house play area is deliberately left unroofed.** The Vault display pads sit inside the
  house, and a roof over them fights the player camera. This is a decision, not an omission.
- **Field scenery never collides.** All dressing is `CanCollide` and `CanQuery` false so it cannot
  block a chase, a juke, or a prompt raycast (spec §11).

**Open, needs a ruling: sound.** The prototype has no audio whatsoever, and it is now the largest
remaining gap in how finished it feels. Audio cannot be part-crafted -- every route needs an
uploaded asset id, which falls outside "part-craft only". Roblox's own official free SFX library is
the obvious candidate, but using it is a third-party-asset decision the user has not been asked for.

## Chonk display size: 2026-10-01 (user ruling)

Ten Vault display pads cannot hold ten max-size Chonks in a 40-stud house: five columns need 10.4
studs each and the interior is 38. No grid of ten fits, which was measured rather than assumed.

- Offered: cap the sizes, enlarge the houses, cut the pad count, or scale the model down on Vault
  pads only. **The user chose to cap the sizes.** `Config.SizeScale` is now
  `{1, 1.07, 1.14, 1.21, 1.28, 1.35}`, down from a 2.1 top.
- **The accepted cost:** a size 6 Chonk no longer looks dramatically bigger than a size 3. If the
  size fantasy matters more later, the other three options are still open and the houses are the
  one that keeps it intact.
- `sizeScale` is visual only, so no economy number moved.
- Guarded against drift: the pad grid derives from `Config.Vault.displaySpacing`,
  `Config.WidestBodyProfile` mirrors the widest `wide` in Models' SPECIES table, and a Lune test
  asserts the largest body fits the spacing. Raising the top of `SizeScale` fails that test until
  the spacing, the plot size or the slot count moves with it.

## Visual direction: 2026-10-01

The user asked the prototype to look like the reference game while keeping our own systems, so it
can be shown to the mates. Recorded so nobody re-derives it:

- **The reference's look was established from five promotional renders** (its Roblox store media
  and a guide hero image), fetched and looked at directly. **None is an in-game capture** and no
  in-game source was found; its own wiki says its gameplay gallery is not populated. They give the
  brand language, not the shipped frame: saturated high-contrast colour, no grey haze, chunky
  flat-shaded creatures read by silhouette, glow used as an accent, heavy outlined display type.
- **This is colour direction only.** The partner's play experience remains the ground truth for how
  the reference game plays and looks. Do not let a thumbnail become a mechanics claim.
- **Still part-craft only** (user, 2026-09-29, unchanged): Studio primitives, materials and Lighting.
  Nothing in the presentation passes is accepted art, and the art milestone is untouched.
- **There is a ceiling here.** The genre's look leans on custom meshes and textures. Lighting,
  colour, type and silhouette can be taken a long way with primitives, and have been; matching
  mesh-quality creatures cannot. Lifting the art pause is the user's call, not an implementation
  detail to decide while polishing.
- The house style for world text is `Models.pill`: a dark rounded plate with an accent rim. Use it
  for any new world label rather than floating outlined text, which disappears against bright
  grass, a pale wall or the sky depending on where the player stands.

## Showcase heist (Alpha step 1): 2026-09-27

Built by Claude Code from [the heist plan](../docs/superpowers/plans/2026-09-25-showcase-heist.md) on `prototype/vertical-slice`: the porch Showcase (§10), porch theft with the alarm and raid cooldown (§11), the Practice House (§11 "Dummy base"), and the "nothing deleted" returns. Verified solo; see [HANDOFF.md](HANDOFF.md).

- **Prototype proposals, not adopted design** (the user never ruled on them; built as written, tune or overrule freely):

  | Decision | Built as |
  | --- | --- |
  | Porch incubation | Every free porch slot unwraps; the Chonk stays on that slot |
  | Porch unwrap speed | × 0.5 of the Vault time |
  | Steal prompt | Hold 1.5 s within 8 studs |
  | What can be stolen | Revealed porch Chonks and burritos unwrapping on the porch |
  | Stolen burrito progress | Keeps its unwrap fraction and resumes wherever it is deposited |
  | Depositing a carried Chonk | "Put in Vault" stashes it on a free pad with no unwrap; a porch slot shows it off |
  | Bat inside the district | Unchanged: field only, so a thief crossing the district cannot be stopped yet |
  | Dropped stolen item | Anyone may pick it up; after 60 s untouched it returns to its last owner, porch first, then Vault, else it waits |
  | Victim leaves mid-theft | The carried item leaves with the victim (session-only) |
  | Alarm | Porch lights blink red for 6 s; victim and thief get the theft toasts; no sound yet |
  | Practice House | At the district centre (0, 24), a random Common, one kept per player per session, refilled 45 s after it is taken |

- **Rulings made while building** (the plan left these open):
  - "Put here" on a porch pad uses that pad when it is free, else the first free slot.
  - Theft toasts name a Chonk by its Catalog name, but a burrito as "Blanket Burrito", so a theft never spoils what is inside.
  - A burrito returning to a full porch goes into a free Vault incubator and resumes its unwrap; a Chonk goes to a free Vault pad.
  - The alarm runs 6 real seconds, independent of the Studio time-scale hook.
  - Draft copy for the heist is in `Strings.luau` (`Toasts`, `Theft`, `Prompts`, `Showcase`) and needs partner review.
- **Fixed:** `default.project.json` used `Position`, which Rojo does not serialise, so built places buried the map under the Baseplate. It now uses `CFrame`.
- **Known minor issues from the final review: all seven fixed on 2026-10-01** (Claude Code; see
  [HANDOFF.md](HANDOFF.md) for the evidence). They were:
  - A stolen burrito keeping its model under the victim's plot. Carried items now live in `Workspace.World.Carried`, and an incubating one moves under the plot unwrapping it.
  - The loose-return and practice-respawn loops not isolating errors per item. Each step now runs through a pcall that warns once per distinct fault.
  - Porch lights able to flicker when a robbed owner leaves and a new owner is robbed within 6 s. Alarm tokens now never repeat. **The two-player case itself is still unverified.**
  - `Vault.addRecord`'s "no pad" result going unchecked before an item was forgotten. Callers now ask `Vault.freePad` before letting go of an item, and `returnToOwner` records the Chonk before forgetting it.
  - `Config.Showcase.slots` above 2 erroring at boot. `ShowcaseRules.usableSlots` clamps it to the pads `Plots` builds, and boot warns once. **This is a guard, not porch growth: growing past 2 slots still needs the pads built and remains later Alpha work.**
  - Two reach configs for the same steal. `Carry.pickUp` now takes the reach from the item's status; both numbers are still 8.
  - A Chonk colliding until it had been carried once. Chonk bodies are `CanCollide` false from the start, so a seated Chonk never blocks a player on their own porch.
- Unchanged: the spec's open questions below. Shields, defences, Grudge/Wanted, the rookie shield and porch growth past 2 slots remain later Alpha work.

## Vertical-slice prototype: 2026-09-24

On 2026-09-24 the user decided to build the spec §23 vertical slice as a Roblox Studio greybox before any art is accepted. This changes the saved milestone order: "accepted corgi → second Chonk → implementation plan". The art track continues independently, and the prototype uses placeholder parts only.

- **Implemented (Claude Code):**
  - Rojo/Rokit toolchain, `src/{shared,server,client}` and `tests/` (Lune).
  - One zone (Backyards) with 10 nests and Patroller guardians.
  - Ten Chonks, the hamster wheel/Zoomies, and carrying plus the bat.
  - The Vault (2 incubators, 10 display pads), the reveal card and income.
  - Server authority, with a carry-speed anti-cheat baseline.
  - The plan: [2026-09-24 vertical-slice plan](../docs/superpowers/plans/2026-09-24-vertical-slice-prototype.md). Current verification and outstanding checks: [HANDOFF.md](HANDOFF.md).
- **Prototype proposals, not adopted design:** the plan's "Prototype decisions" table covers:
  - Patroller as the one slice guardian, the ten species, and the tier and size weights;
  - unwrap fill values, the carry multipliers between §9's anchors, and the speed curve;
  - guardian speed 17, the wheel rates, Vault capacity 10, and the respawn and loose-return times;
  - the bat rules, session-only persistence, and 8 plots.

  Numbers live in `src/shared/Config.luau`. Names, bios and toasts in `src/shared/Catalog.luau` / `Strings.luau` are draft copy for partner review.
- **Rulings made while building** (recorded in the local ledger, summarised here):
  - A burrito loose on the ground whose nest has already refilled is removed; it was never owned by anyone.
  - Any incubator prompt on your plot uses the first free incubator.
  - "Vault full" is checked before "incubators busy".
  - A guardian heading home after a chase moves at 12 studs/s.
- Unchanged: the spec's open questions and the design inconsistencies listed at the end of this file. The slice avoided them, because rebirth, Showcase, streak/referral rewards and broadcasts are all out of slice scope.

## Blender retry: 2026-09-07 (set aside 2026-09-25)

After onboarding, the user explicitly asked to run Blender with its MCP server and redesign the rejected corgi, then asked to continue trying. This is a scoped exception to the historical stop/Meshy direction below. No permanent pipeline change or art acceptance has been recorded.

Blender 5.1.1 and the installed Blender MCP add-on were exercised successfully. Codex has no registered Blender MCP tool in this session; `assets/tools/blender_mcp_client.py` talks to the installed add-on's existing JSON socket bridge on `127.0.0.1:9876`. `start_blender_mcp.py` was fixed to check the actual process-local listener rather than trusting a stale flag saved in a `.blend` file. The fixed helper was rerun successfully with the server active; a fresh-process startup of that revision has not yet been tested.

The new study uses the original high-resolution generated corgi as its shape source, welds split seams before reduction, repairs damaged eye surfaces, and rebuilds the sleepy expression and continuous coat markings. It reuses the project's orange and cream fur images. Original concepts and prototype assets remain unchanged.

The [redesign directory and reproduction notes](../assets/chonks/corgi/codex_redesign/README.md) contain an editable `.blend`, an optimized `.blend`, a GLB, a baked base-color atlas, four export views, and verification reports. The GLB was reimported into Blender and measured at **7,270 triangles, one mesh, one material, one 2048-square atlas**. This is an unrigged review candidate; no Studio import, mobile performance test, or partner approval has occurred. See [HANDOFF.md](HANDOFF.md) for the current resume point.

## Historical onboarding source map and precedence

| Source read | What it establishes |
| --- | --- |
| [Design spec, all 26 sections](../docs/superpowers/specs/2026-09-06-steal-a-chonk-design.md) | Full game design, roster, intended architecture, roadmap, proposed economy, open questions. Header still says **Draft for review by both developers**. |
| `.claude/knowledge-mental_map.md` (local, ignored) | Later decisions: Meshy for hero art, rejected corgi, stopped Blender texturing, partner authority, repository hygiene. Calls the design settled. |
| `.claude/knowledge-last_working_memory.md` (local, ignored) | Previous stopping point, next corgi experiment, acceptance gate, historical setup blocker and roadmap. |
| Claude project memory referenced by those notes | Read the index and all five linked notes: `game-is-steal-a-chonk.md`, `steal-an-egg-ground-truth.md`, `verify-genre-facts-with-partners.md`, `chonk-art-pipeline.md`, `git-hygiene-no-coauthor-scan-before-push.md`. Relevant decisions are preserved here and in `AGENTS.md`; these external files are not required on another machine. |
| `.gitignore`, Git history/status, all six `assets/tools/*.py`, local asset inventory | What actually exists and is versioned. Scripts were read, not executed. |
| Corgi concept sheet, front concept crop, markings sheet, face image, both saved model renders | Visual reference and prototype evidence. A `.blend` scene was not opened or validated. |

Use the current user instruction first. For historical direction, the later explicit stop/Meshy decision supersedes the older art-pipeline memo and the scripted hero-model approach in spec section 21. Do not infer that every conflicting part of the design has been approved. The early theme memo's abbreviated size names are superseded by the spec's six named sizes.

The legacy memories also contain dated service prices, credit estimates, external game claims, and installed-tool claims. They were read as history, not revalidated online during this documentation task. Recheck any such claim before using it for purchasing, integration, compliance, or a new design dependency.

## Game understanding

**Steal a Chonk** is an original Roblox collection/theft game for two full-time developers. Players bring blanket burritos home from guarded field nests, unwrap lovable round animals, earn cash, train speed (Zoomies), and unlock farther zones. The cozy neighborhood, rolling Mama Chonks, deadpan names, and reveal cards give the game its identity.

The six pillars, in priority order: Zoomies as the power fantasy; loss only by choosing risk; theft creates a second act; acquisition requires leaving base and carrying home; value moves rather than being deleted; every system includes affectionate humor.

| Area / spec sections | Intended behavior |
| --- | --- |
| Loop and world, 4-7 | Central ring of houses with a visible curb; zones extend outward. Grab a burrito, evade guardians and players, cross the curb, choose where to unwrap, earn, train, rebirth. Guardians stop at the field/base boundary. Zones 1-3 at launch; Zone 4 later. |
| Acquisition, 7 | 8-14 nests per zone; Sleeper, Patroller, Alarmer guardians. Rare Rush every five minutes per zone. Big Chonk is a daily-chance Secret drop with a 60-second warning and a slow carry, not an automatic five-minute Secret. Hidden Legendary pity. |
| Catalog, 8 | 40 launch animals: Common 10, Uncommon 8, Rare 7, Epic 6, Legendary 4, Mythic 3, Secret 2. Corgi and Penguin are Uncommon. Secrets: The Absolute Unit and STEVE. See the spec for the full roster. |
| Variation, 8 | Six sizes: A Fine Boi, He Chomnk, A Heckin' Chonker, HEFTYCHONK, MEGACHONKER, OH LAWD HE COMIN. One mutation slot (Golden, Cosmic, Rainbow, Snowy, Lava, Glitch, Candy), up to three traits. Food/household/office names, tier titles, deadpan bios, sleepy idle behavior. |
| Zoomies, 9 | Hamster wheel grants speed only, with passive gain and tap bonus. Tier-dependent carry slowdown; zone-fixed guardian speed. Exponential progression, audio/camera feedback and milestone broadcasts. |
| Base and theft, 10-11 | Vault is safe online/offline, with normal income and slow incubation. Showcase is opt-in risk, +50% income, faster incubation, stealable occupants. Field hits drop carried items for anyone. Disconnects return carried owned items per the spec. Rookie shield, dummy tutorial base, two-minute post-theft Showcase immunity. |
| Grudge/Wanted, 12 | Victim gets a ten-minute tracker and revenge payout; theft raises decaying Wanted, making the thief a more valuable target. |
| Protection/tools, 13 | Unbreakable, non-stacking shields; cooldown equals duration. Expiry away exposes the Showcase. Alarm, trap, guard, decoy; bat, coil, smoke, grapple, cloak. Return Beacon restricts high-tier carrying. |
| Progression, 14 | Rookie, Runner, Raider, Veteran, Legend. Feature unlocks and rebirth; warps begin at Raider and are disabled while carrying. Index persists; weekly Showcase/steal leaderboards reward cosmetics/titles. |
| Events/retention, 15-16 | Daily Global Event, weekly Saturday drops, seasonal dressing; onboarding milestones, daily streak, two-hour offline Vault income cap, capped friend bonus, referral rewards. Retention targets are goals, not observed results. |
| Monetization, 17 | Luck/income boosts, slots, shield/beacon stacks, cosmetics, private servers, bundles. No direct Chonk sales or power that defeats shields; earnability and balance remain design requirements. |
| Comedy/UI, 18-19 | Shared strings module, humorous reveal/theft/broadcast text. Mobile-first controls with four field actions, progressive HUD, one-tap reveal dismissal, readable timer bars, scaled PC layout. |
| Constraints, 3/22 | Original IP; affectionate tone. No conveyors, base locks, body swap, offline raids, upkeep chores, crews, media feeds, or real-person/brand references. Mobile performance is a launch gate. Platform compliance still needs current verification at implementation/launch. |

Economy section 25 is explicitly provisional: Common income 1/sec; approximately 5x per tier; size income factors 1/1.5/2.5/4/7/12; first rebirth around two hours; +50% compounding income per rebirth; initial Big Chonk chance 60% per server/day. These are tuning inputs, not tested balance. Full numbers belong in the planned `src/shared/Config.luau`.

## Intended implementation (the full design; the 2026-09-24 slice implements a subset)

Spec section 20 calls for Rokit, Rojo, Luau LSP, Selene, StyLua and Wally. Rojo syncs repository code into Studio; Studio handles map work, playtesting and publishing.

- `src/server/`: Data, Economy, Nests, Guardians, Carry, Theft, Shields, GrudgeWanted, Events, Rebirth, Leaderboards, Analytics services.
- `src/client/`: HUD, Reveal, Input, Camera, Notifications, Audio controllers.
- `src/shared/`: data-only catalog, strings, configuration, remotes and types.
- Session-locked persistence such as ProfileStore; versioned schema/migrations; reconciliation and carried-item resolution before saving.
- Server owns grabs, carry/drop/reveal, money, shields and purchases; clients send intents. Server speed/position checks and remote limits.
- Streaming, bounded base visuals, simple server guardian movement with client interpolation; target 60 fps on mid-range phones with 20 players. Neither performance nor multiplayer behavior has been tested here.
- Asset-to-Roblox-ID manifest, economy sheets, play logs and analytics are planned, not present in this checkout.

Spec sections 23-24 stage the work: vertical slice (one zone, one guardian, ten Chonks, Vault, wheel, carry/bat, reveal, two testers); Alpha (Showcase, shields, revenge systems, rebirth, Zone 2, 25 Chonks); Beta (Zone 3, all guardians, events, store, 40 Chonks, leaderboards); launch and weekly drops. Collection sets/Wanted Board, trading with escrow, more zones and localization are later work.

## Recorded art direction and quality gate

Superseded on 2026-09-25 by the Studio-only direction at the top of this file; kept as history.

The partner supplies concept sheets. At onboarding, the recorded direction was Meshy image-to-3D for hero Chonks; primitive hero modeling and the repeated Blender texture-projection fixes were rejected. The saved next experiment was a textured corgi from multiple views, with no auto-split initially, then remeshing if needed and a visible result for the partner. The explicit Blender retry at the top of this file is the current scoped work. Tripo was retained as a secondary possibility for props/guardians, not an active integration.

The earlier recorded asset target is one mesh, roughly 5k-8k triangles, and one 1024-2048 texture. It is a project target, not proven Studio performance. Mutations remain Roblox material swaps plus particle presets per the spec; using paid retextures was left unresolved.

Keep the current corgi as a rejected reference. Claude reported about 6,998 triangles and a saved studio scene; that scene/triangle count was not remeasured during onboarding. The saved renders visibly have fragmented face/ear markings and mismatched texture regions. This supports the recorded rejection, but does not constitute a new partner verdict.

The supplied sheet is Front/Side/Top/3-4, not a complete left/back/right turnaround. The inspected `concept_front.png` crop clips ear tips and includes a divider/adjacent-panel content at the bottom. Check all crop framing and current Meshy input requirements before an eventual upload; do not relabel top or three-quarter views as back views. The flat markings sheet has a different silhouette from the fluffy hero concept and belongs to the abandoned texturing experiment.

Once the partner accepts the first Chonk, the saved sequence is a second Chonk cold run, a repeatable views-to-model-to-Roblox recipe, and then the game implementation plan. Acceptance and a successful Studio import must be recorded as separate evidence.

## Files actually present at onboarding

| Path | Role and status |
| --- | --- |
| `concepts/corgi.png` | Original four-view hero reference sheet. |
| `concepts/corgi/views/concept_{front,side,top,threequarter}.png` | Four existing concept crops; framing/input suitability needs review. |
| `concepts/corgi/face_front.png`, `fur_orange.png`, `fur_cream.png`, `ear_inner.png` | Face and surface inputs from the legacy finisher workflow. |
| `concepts/corgi/markings.png`, `concepts/corgi/views/markings_{front,side,top}.png` | Flat markings source and three prepared views from that experiment. |
| `assets/chonks/corgi/corgi.blend`, `corgi_diffuse.png` | Tracked rejected prototype source and 2048-square baked texture. |
| `assets/chonks/corgi/chonk_corgi_front.png`, `chonk_corgi_threequarter.png` | Tracked saved renders (1600-square / 1920x1440). |
| `assets/chonks/corgi/corgi.fbx` | Local export, ignored because of embedded absolute paths. |
| `assets/chonks/corgi/work/` | Local ignored `chonk_corgi_viewcolor.png` and `corgi_regionmask.png` intermediates. |
| `assets/tools/` | Six retained legacy/experimental scripts described below. |

At onboarding there was no `src/`, Rojo project file, Rokit/Wally configuration, test suite, Roblox place file, asset-ID manifest, Meshy output directory, or Penguin output directory. The 2026-09-24 prototype added `src/`, `tests/`, `default.project.json`, `rokit.toml`, `selene.toml` and `stylua.toml`. The place file is built from the project and ignored. There is still no asset-ID manifest, Meshy output or Penguin output. Do not confuse the intended structure or retained Penguin scripts with implemented content. Ignored local exports/intermediates will not accompany a fresh clone.

## Legacy tooling map

All six legacy scripts were read in full at onboarding; none was run during that documentation pass. The later Blender retry ran and fixed `start_blender_mcp.py`, and added the three corgi helpers documented in the redesign README. The other five legacy scripts remain unexecuted in this session. This historical inventory is not an instruction to rerun their defaults.

| Script under `assets/tools/` | Requirements and effect |
| --- | --- |
| `finish_chonk.py` | Blender/Cycles and expected scene objects. Copies, normalizes, decimates and optionally unwraps; applies surface/face projection; bakes diffuse, exports FBX, renders front/three-quarter. Default target is Corgi. |
| `region_from_views.py` | Blender, prepared mesh and UVs. Replaces material with weighted view projections, bakes a view-color image under `work/`, leaves projection cameras. |
| `classify_regions.py` | Standalone Python with NumPy, Pillow and SciPy; explicit source/destination arguments. Turns view colors into R-primary/G-secondary/B-pink region mask and fills unknown areas. Destination directory must exist. |
| `build_penguin.py` | Blender procedural experiment; immediately replaces matching objects and writes Penguin FBX/UV layout. Material helper exists but is not called by the entry sequence. |
| `compose_penguin.py` | NumPy/Pillow procedural black/blue Penguin texture generator. Output directory must exist; save path still uses a Windows backslash. |
| `start_blender_mcp.py` | Blender bootstrap for an already installed add-on named `addon`; enables it and starts/retries its server. Changes application state. |

Legacy root-aware scripts accept `CFG["root"]`, otherwise derive it from `__file__` or fall back to the current directory. The finisher's defaults (`stage="all"`, `unwrap=True`, `fur=None`) do not reproduce the saved configured fur workflow and can overwrite the target/output files. The older guidance preferred preserving generator UVs; the defaults still differ. None of these six legacy scripts saves a `.blend` file; the new export helper does.

If the user ever explicitly resumes these tools, retain the learned constraints: never vertex-smooth generated eye sockets; do not use the generator's 512px diffuse as the fur-color source; uncovered regions must not become black. The actual fur graph falls back to primary fur and uses G/B for secondary/pink; its old black-mask/`dark_rgb` comments are stale. Blender compatibility and output regeneration remain untested in this onboarding pass.

## Open decisions to preserve

The spec's own section 26 still asks for an in-app title check, both developers' reference-game play logs, confirmation of Walls/Alarms/Turrets mechanics, and a Global Event UTC time. These are unresolved; no new research was performed here.

The following are review findings, not adopted design changes. Resolve the relevant item when its system is planned:

| Issue | Conflicting or incomplete source details |
| --- | --- |
| Rebirth and ownership | Sections 2-3 say nothing is deleted; section 14 wipes Chonks on rebirth. |
| Field-only acquisition | Sections 2-3 require every Chonk to be carried home; section 16 grants streak/referral Chonks without specifying field retrieval. Section 13 also leaves sub-Legendary carrying compatible with Return Beacon, which needs reconciliation with the carry-home principle. |
| Zone gates | Sections 6/9/25 give Zone 3 about 10K Zoomies; section 14 associates it with Veteran/Rebirth 4/1M Zoomies. The relationship between thresholds and unlock gates needs definition. |
| Base capacity | Section 10 gives two Vault incubators, but section 14 unlocks the second during Rookie. Unlimited Showcase incubation versus 2-8 Showcase slots needs explicit occupancy rules. |
| Secret event source | Section 8 includes Global Events as a Secret source; section 15 only specifies increased mutation odds. |
| Reveal broadcasts | Section 8 broadcasts Legendary+ reveals; section 10 limits broadcasts to Showcase Chonks. Vault reveal behavior needs definition. |

These uncertainties do not prevent documentation or asset review. They must not become invented implementation rules.
