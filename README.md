# Steal a Chonk

An original Roblox steal game about enormous, round, sleepy animals called **Chonks**. Sneak into the field, grab a blanket burrito from a guarded nest, outrun the grumpy Mama Chonk back to your house, and unwrap whatever was inside. Train your **Zoomies** on the hamster wheel to run faster and reach farther zones. Built mobile-first, with affectionate humour.

> **You are on `prototype/vertical-slice`**, the first playable greybox of the game. It has not been merged into `main` yet.

## Where we are (updated 25 Sep 2026)

- **Playable:** a greybox *vertical slice* with one zone, one kind of guardian, ten Chonks, your Vault, the hamster wheel, carrying, the bat and the reveal card.
- **Checked:** 56 automated tests of the game rules pass, and solo playtests in Studio ran the whole loop end to end: grab, chase, carry home, unwrap, reveal, earn.
- **Not checked yet:** two players at once, phones and touch controls, performance. Nothing is saved between sessions yet.
- **Art is paused on purpose.** Everything you see is placeholder Studio parts until the game plays well.
- **Next:** the Showcase heist, the first Alpha feature. Its plan is written and waiting for review ([see below](#whats-next-the-showcase-heist)).

## Play it in Studio

You need Roblox Studio and [Rokit](https://github.com/rojo-rbx/rokit), which installs the right versions of Rojo and the other tools.

1. Clone the repo and switch to this branch: `git checkout prototype/vertical-slice`
2. In the repo folder, run `rokit install`
3. Build the place:
   ```
   mkdir build
   rojo build default.project.json -o build/prototype.rbxl
   ```
4. Open `build/prototype.rbxl` in Studio and press **Play**.

To edit code while Studio is open, run `rojo plugin install` once, then `rojo serve default.project.json`, and click **Plugins → Rojo → Connect** in Studio. Script changes then sync live.

### Controls

| Do this | Keyboard | Touch / gamepad |
| --- | --- | --- |
| Grab a burrito, unwrap it, pedal the wheel | **E** at the prompt | Tap the prompt |
| Bat someone carrying a burrito (field only) | **F** | Bat button / **X** |

### What happens in the slice

1. You spawn on your own porch. Eight houses sit in a ring inside a painted curb.
2. Stand on the hamster wheel for Zoomies (+1 a second), or hit **Pedal** for +2. More Zoomies means faster running.
3. Walk out into the Backyards and **Grab** a blanket burrito from one of ten nests. The glow hints at the rarity and the burrito's size hints at the Chonk's size.
4. A Patroller Mama Chonk yells MRRP and rolls after you. Carrying slows you down.
5. If she catches you, the burrito drops and anyone can pick it up, you included.
6. She stops at the curb. Cross it with the burrito for confetti.
7. Other players can **Bat** you in the field to knock the burrito loose.
8. At home, **Unwrap** it in one of your two incubators. A reveal card shows what you got: rarity, species, name, size, a short bio and its income.
9. The Chonk sits on a Vault pad and earns cash every second.

## What we need from testers

1. **Two-player bat check.** In Studio, use **Test → Clients and Servers** with 2 players. One carries a burrito in the field and the other presses **F** in front of them. Expected: the burrito drops, with a knockback and "BONK". Then try it inside the curb, where nothing should happen.
2. **Feel.** Is the chase fun? Right now a brand-new player is slower than the Mama Chonk and can only escape by grabbing while she is on the far side of her loop. Reaching the ~150 Zoomies that outrun her took a few minutes on the wheel, slower than the design's "first burrito by minute 2".
3. **Numbers and names.** Every value the design left open is a proposal in the [slice plan's decisions table](docs/superpowers/plans/2026-09-24-vertical-slice-prototype.md#prototype-decisions-the-spec-does-not-settle-proposals-tune-or-overrule-freely). The numbers live in [`Config.luau`](src/shared/Config.luau). Chonk names, bios and pop-up text are draft copy in [`Catalog.luau`](src/shared/Catalog.luau) and [`Strings.luau`](src/shared/Strings.luau). Change or overrule anything.
4. **A phone**, if you can. The touch buttons exist but haven't been tried on a real device.

## What's next: the Showcase heist

The first Alpha feature (design §10–11). It is planned in [the heist plan](docs/superpowers/plans/2026-09-25-showcase-heist.md) and not built yet.

- Unwrap on your **porch Showcase** (2 slots) instead of the Vault: faster, and +50 % income, but other players can steal from it.
- Move Chonks between your Vault and porch for free while you're home.
- **Steal** a Chonk from someone else's porch and carry it home under the normal carry rules. The victim's porch lights flash red, and their porch is safe for two minutes afterwards.
- A practice **dummy house** near spawn with a free Common to steal, so new players learn the heist without risk.
- Nothing is ever deleted: a dropped or abandoned stolen Chonk goes back to its last owner.

A few rules the design doesn't settle are proposals for us to decide, in the plan's [decisions table](docs/superpowers/plans/2026-09-25-showcase-heist.md#prototype-decisions-the-spec-does-not-settle-proposals-tune-or-overrule-freely). The big ones:

- The bat still works only in the field, so a thief walking through the houses can't be stopped yet. Shields and defences come in later Alpha steps.
- Stealing is a 1.5-second hold.
- Each player gets one free dummy Chonk per session.

## Art

Art is **paused** while we get the prototype right (decided 25 Sep 2026). Everything in the game is Studio's built-in parts and materials.

- The corgi model and renders in `assets/chonks/corgi/` are a **rejected** early attempt, kept for reference.
- The corgi concept art is in `concepts/`.
- The earlier art plans (Meshy image-to-3D, and a Blender redesign experiment kept off GitHub) are on hold. The history is in [PROJECT_CONTEXT.md](codex/PROJECT_CONTEXT.md).

## Branches

| Branch | What's on it |
| --- | --- |
| `main` | The design, the corgi concept art and the early art experiments. No game code yet. |
| `prototype/vertical-slice` (this one) | Everything on `main`, plus the playable greybox, its tests and the shared working notes. |

## What's where

| Path | What it is |
| --- | --- |
| [Design spec](docs/superpowers/specs/2026-09-06-steal-a-chonk-design.md) | The full game design, 26 sections. Still marked draft. |
| [`docs/superpowers/plans/`](docs/superpowers/plans/) | Build plans: the vertical slice (done) and the Showcase heist (next). |
| [`src/shared/`](src/shared/) | Game rules, all the numbers, the Chonk catalog and all the text. |
| [`src/server/`](src/server/) | The server: world, nests, guardians, carrying, Vault, wheel, bat. |
| [`src/client/`](src/client/) | The HUD, reveal card, camera, effects and input. |
| [`tests/`](tests/) | Automated tests for the rules in `src/shared/`. |
| [`codex/HANDOFF.md`](codex/HANDOFF.md) | Detailed latest status: what was verified, what's outstanding, what's next. |
| [`codex/PROJECT_CONTEXT.md`](codex/PROJECT_CONTEXT.md) | Decisions, their history and the open design questions. |
| [`AGENTS.md`](AGENTS.md) | Working rules for the AI coding assistants (Claude Code and Codex). |
| `concepts/`, `assets/` | Concept art, the rejected corgi and the old Blender scripts. |

## Working on the code

- The server is in charge. Players' clients only send requests, and the server checks every one.
- Every number lives in `src/shared/Config.luau`, and every line of player-facing text in `src/shared/Strings.luau`.
- Change scripts in the repo, not in Studio: Rojo overwrites script edits made inside Studio.
- The map is generated by code, so anything built by hand in Studio isn't saved.
- In a Studio playtest, `ServerStorage.DevHooks` has test shortcuts (grab, deposit, faster timers, fill the Vault). See [HANDOFF.md](codex/HANDOFF.md).
- Before you push, run `lune run tests/run`, `stylua --check src tests` and `selene src`, and update this README so everyone can see what changed.
- The repo is **public**, so never commit passwords, tokens or files that contain your computer's user folder path. Blender files and renders can hide one.
