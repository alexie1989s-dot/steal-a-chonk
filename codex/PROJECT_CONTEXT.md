# Steal a Chonk: project context

Onboarded 2026-09-06; current asset update 2026-09-07; vertical-slice prototype 2026-09-24. This is a source-based project summary, not a new game design proposal.

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

## Current Blender retry: 2026-09-07

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
