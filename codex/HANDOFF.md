# Current handoff

Updated: 2026-09-24 by Claude Code. It built the vertical-slice greybox prototype. The art notes further down come from Codex (2026-09-07) and still apply.

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
3. Open any place, or `rojo build default.project.json -o build/prototype.rbxl` and open that.
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
- **Pre-existing leak already on `main`:** `assets/chonks/corgi/chonk_corgi_front.png` and `chonk_corgi_threequarter.png` embed the same path. Removing it from history needs a rewrite plus a force-push, which is the user's decision.
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
