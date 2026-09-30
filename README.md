# Steal a Chonk

An original Roblox steal game about enormous, round, sleepy animals called **Chonks**. Sneak into the field, grab a blanket burrito from a guarded nest, outrun the grumpy Mama Chonk back to your house, and unwrap whatever was inside. Train your **Zoomies** on the hamster wheel to run faster and reach farther zones. Built mobile-first, with affectionate humour.

> **Everything lives on `main`.** The playable prototype was merged there on 30 Sep 2026, so the game code, the design and the art history are all in one place. `prototype/vertical-slice` is the branch it was built on and now points at the same commit, so whichever of the two you have checked out, you are not missing anything.

## Where we are (updated 30 Sep 2026)

- **Playable:** a greybox *vertical slice* with one zone, one kind of guardian, ten Chonks, your Vault, the hamster wheel, carrying, the bat and the reveal card.
- **The Showcase heist**, the first Alpha feature. Your porch has two Showcase slots, you can steal from other players' porches, and a Practice House near the middle lets you learn stealing for free ([details below](#the-showcase-heist-new)).
- **New: it now looks like a game.** A presentation pass on 29 Sep gave it proper lighting and sky, ten Chonks you can tell apart at a glance, houses with roofs and porches, a field with trees and flowers, a much better HUD, and a gentle idle bob on Chonks sitting on a pad. **It is all still placeholder**, built from Studio's own bricks and spheres ([more below](#art)).
- **Checked:** 74 automated tests of the game rules pass. Solo playtests in Studio ran the whole loop end to end, including stealing the practice Chonk, stashing it, and unwrapping on the porch, with real key presses.
- **Not checked yet:** two players at once (so real porch theft between people), phones and touch controls, performance. Nothing is saved between sessions yet.
- **There is no sound at all.** That is the biggest thing still missing, and we need to agree where audio comes from before it can be added ([below](#art)).
- **Merged into `main` on 30 Sep 2026.** Everything is on one branch now.
- **Fixed:** built places used to bury the whole map under the grass. If you built the place before 27 Sep, build it again.

## Play it in Studio

You need Roblox Studio and [Rokit](https://github.com/rojo-rbx/rokit), which installs the right versions of Rojo and the other tools.

1. Clone the repo. `main` has everything; you do not need to switch branches.
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
| Grab a burrito, pedal the wheel, put something in your Vault or on your porch, move a Chonk between them | **E** at the prompt | Tap the prompt |
| Steal from a porch | Hold **E** for 1.5 s | Hold the prompt |
| Bat someone carrying a burrito (field only) | **F** | Bat button / **X** |

### What happens in the slice

1. You spawn on your own porch. Eight houses sit in a ring inside a painted curb.
2. Stand on the hamster wheel for Zoomies (+1 a second), or hit **Pedal** for +2. More Zoomies means faster running.
3. Walk out into the Backyards and **Grab** a blanket burrito from one of ten nests. The glow hints at the rarity and the burrito's size hints at the Chonk's size.
4. A Patroller Mama Chonk yells MRRP and rolls after you. Carrying slows you down.
5. If she catches you, the burrito drops and anyone can pick it up, you included.
6. She stops at the curb. Cross it with the burrito for confetti.
7. Other players can **Bat** you in the field to knock the burrito loose.
8. At home, press **Put in Vault** at one of your two incubators. A reveal card shows what you got: rarity, species, name, size, a short bio and its income.
9. The Chonk sits on a Vault pad and earns cash every second.

## The Showcase heist (new)

The first Alpha feature (design §10–11), built from [the heist plan](docs/superpowers/plans/2026-09-25-showcase-heist.md).

1. Your porch has two **Showcase** pads. **Put here** a burrito and it unwraps there in half the Vault time. A Chonk on the porch earns +50 %, but other players can steal it.
2. While you stand at home, **To Vault** and **To Porch** move a Chonk for free.
3. On someone else's porch, hold **Steal** for 1.5 s and carry the item home under the normal carry rules. A stolen burrito keeps its unwrap progress. At home you can put it in your Vault or on your porch.
4. The victim's porch lights flash red, both players get a pop-up, and that porch can't be robbed again for 2 minutes (a countdown sign shows above it).
5. The **Practice House** in the middle of the district has a free Common on its porch. Steal it and carry it home to learn the heist. Each player keeps one per session.
6. Nothing is deleted: a stolen item that gets dropped walks back to its owner after 60 seconds, and if the thief leaves the game it goes straight back.

A few rules the design doesn't settle are proposals for us to decide, in the plan's [decisions table](docs/superpowers/plans/2026-09-25-showcase-heist.md#prototype-decisions-the-spec-does-not-settle-proposals-tune-or-overrule-freely). The big ones:

- The bat still works only in the field, so a thief walking through the houses can't be stopped yet. Shields and defences come in later Alpha steps.
- Stealing is a 1.5-second hold.
- One free practice Chonk per player per session.
- If the victim leaves the game while you carry their Chonk, it leaves with them (nothing is saved yet).

## What we need from testers

1. **Two-player heist check.** In Studio, use **Test → Clients and Servers** with 2 players:
   - Only the neighbour sees **Steal**; only the owner sees **Put here**, **To Vault**, **To Porch**, **Put in Vault** and **Pedal!**
   - Steal a porch Chonk: the victim's porch flashes red, both pop-ups appear, and the thief can carry it home and keep it.
   - Try a second steal on the same porch within 2 minutes: it should refuse.
   - The thief resets while carrying: the Chonk lies on the ground, then goes back to the victim after 60 s.
   - The victim leaves while the thief carries: the Chonk disappears from the thief's hands and the thief is told why.
2. **Two-player bat check.** One player carries something in the field and the other presses **F** in front of them. Expected: it drops, with a knockback and "BONK". Inside the curb, nothing should happen.
3. **Feel.** Is the chase fun? A brand-new player is slower than the Mama Chonk and has to grab while she is on the far side of her loop. Even with ~160 Zoomies she caught one of our grabs. Is stealing fun, and is 1.5 s the right hold?
4. **Numbers and names.** Every value the design left open is a proposal in the decisions tables of the [slice plan](docs/superpowers/plans/2026-09-24-vertical-slice-prototype.md#prototype-decisions-the-spec-does-not-settle-proposals-tune-or-overrule-freely) and the [heist plan](docs/superpowers/plans/2026-09-25-showcase-heist.md#prototype-decisions-the-spec-does-not-settle-proposals-tune-or-overrule-freely). The numbers live in [`Config.luau`](src/shared/Config.luau). Chonk names, bios and pop-up text are draft copy in [`Catalog.luau`](src/shared/Catalog.luau) and [`Strings.luau`](src/shared/Strings.luau). Change or overrule anything.
5. **A phone**, if you can. The touch buttons exist but haven't been tried on a real device.
6. **How it looks.** Can you tell the ten Chonks apart without reading the name tags? Is the base readable when you walk in with a full Vault? Anything that looks wrong, cheap or confusing — say so, it is all placeholder and cheap to change.

## What's next

The rest of the Alpha (design §23): porch shields and the away timer, the Grudge and Wanted system, rebirth and Zone 2, 25 Chonks, and saving your progress between sessions.

## Art

Proper art is still **paused** while we get the prototype right (decided 25 Sep 2026). Nothing you see is final, and no Chonk has been signed off.

What changed on 29 Sep is only *how the placeholder is built*. Everything in the game is still made from Studio's own spheres, blocks and cylinders — no Blender, no Meshy, no AI-generated meshes, nothing downloaded from the Creator Store. The ten Chonks are now 13 to 32 parts each instead of five, so a frog reads as a frog and a penguin as a penguin, and the lighting and scenery were built out to match. If we replace them with real models later, nothing about the game rules has to change.

The one thing that could not be done this way is **sound**, and the game is completely silent. Audio always means using an uploaded sound file, which is outside "build it from Studio parts", so it needs a call from us first. Roblox's own free sound library is the obvious place to start — say the word and it can go in.

- The corgi model and renders in `assets/chonks/corgi/` are a **rejected** early attempt, kept for reference.
- The corgi concept art is in `concepts/`.
- The earlier art plans (Meshy image-to-3D, and a Blender redesign experiment kept off GitHub) are on hold. The history is in [PROJECT_CONTEXT.md](codex/PROJECT_CONTEXT.md).

## Branches

| Branch | What's on it |
| --- | --- |
| `main` | Everything: the playable prototype, the design spec, the tests, the shared notes, the concept art and the old art experiments. **Start here.** |
| `prototype/vertical-slice` | The branch the prototype was built on. Merged into `main` on 30 Sep 2026 and kept at the same commit, so the build history stays readable. Nothing is on it that isn't on `main`. |

## What's where

| Path | What it is |
| --- | --- |
| [Design spec](docs/superpowers/specs/2026-09-06-steal-a-chonk-design.md) | The full game design, 26 sections. Still marked draft. |
| [`docs/superpowers/plans/`](docs/superpowers/plans/) | Build plans: the vertical slice and the Showcase heist (both built). |
| [`src/shared/`](src/shared/) | Game rules, all the numbers, the Chonk catalog and all the text. |
| [`src/server/`](src/server/) | The server: world, nests, guardians, carrying, Vault, porch Showcase, Practice House, wheel, bat. |
| [`src/client/`](src/client/) | The HUD, reveal card, camera, effects, input, the prompt filter and the idle bob on displayed Chonks. |
| [`tests/`](tests/) | Automated tests for the rules in `src/shared/`. |
| [`codex/HANDOFF.md`](codex/HANDOFF.md) | Detailed latest status: what was verified, what's outstanding, what's next. |
| [`codex/PROJECT_CONTEXT.md`](codex/PROJECT_CONTEXT.md) | Decisions, their history and the open design questions. |
| [`AGENTS.md`](AGENTS.md) | Working rules for the AI coding assistants (Claude Code and Codex). |
| `concepts/`, `assets/` | Concept art, the rejected corgi and the old Blender scripts. |

## If you're picking this up cold

Read in this order. It should take about twenty minutes.

1. **This file**, for what the game is and how to run it.
2. **[`codex/HANDOFF.md`](codex/HANDOFF.md)** — the latest state: what was actually built, what was actually verified and how, what's still open. Every work session appends a dated section, newest at the top. If you only read one file, read the top section of this one.
3. **[`codex/PROJECT_CONTEXT.md`](codex/PROJECT_CONTEXT.md)** — why things are the way they are. Decisions, their history, and the design questions nobody has answered yet. Check here before you change a decision; a lot of what looks arbitrary was chosen on purpose.
4. **[The design spec](docs/superpowers/specs/2026-09-06-steal-a-chonk-design.md)** — the full game, 26 sections. Skim it, then read the sections you're touching. It is still marked draft and the code doesn't implement all of it yet.
5. **[`src/shared/Config.luau`](src/shared/Config.luau)** — every tunable number in the game, in one file, commented with which spec section it came from or that it's a proposal.

Then open `src/shared/` and read `ShowcaseRules.luau`. It's small, it's pure, and it shows the pattern the whole codebase follows.

## How it's put together

- **The server decides everything.** Clients send one thing (`BatSwing`) and otherwise only ask. Every prompt handler re-checks reach and ownership server-side, and the Steal hold is timed on the server, not trusted from the client.
- **`src/shared/` is pure rules, and that's deliberate.** Those modules use string requires and touch no Roblox APIs, so [`tests/`](tests/) can run them headlessly under Lune — no Studio, no place file, 74 tests in about a second. When you add a rule, put the decision in `src/shared/` and a test beside it; keep `src/server/` for the parts that move things in the world.
- **The map is built by code at server start**, by `World.luau` (field, kerb, nests, scenery) and `Plots.luau` (the eight houses). Nothing you build by hand in Studio is saved. The field scatter is seeded, so everyone sees the same trees.
- **`src/server/Carry.luau` is the one registry of physical items.** Anything a player can pick up is a `Carry.Item`, and `Carry.setStatus` is the only thing that writes an item's status. Hook new behaviour there rather than tracking items separately.

### Things that will bite you

- **Change scripts in the repo, not in Studio.** Rojo overwrites script edits made inside Studio.
- **Rojo silently drops the `Position` property** in `default.project.json`. Use an explicit `CFrame` block instead, or your part lands at the origin. This buried the entire map once.
- **Rojo does not live-apply `default.project.json` property changes** to an already-open place. Rebuild the place, or patch the open copy to match.
- **Chonk models have a geometry contract**, written at the top of [`src/server/Models.luau`](src/server/Models.luau). The body's height is exactly `d = 4 * sizeScale(size)` and the model pivot is the body's centre, because Vault, Showcase and the Practice House all rest a Chonk with `pad.Y + d / 2` and hang its name tag at `d / 2 + 1.5`. Change the body's proportions all you like; keep that.
- **Scenery must not collide.** Everything decorative is `CanCollide` and `CanQuery` false, so it can't block a chase or swallow a prompt's raycast. If you add props, do the same.
- **In a Studio playtest, `ServerStorage.DevHooks` has shortcuts** — grab, deposit, porch, steal, fill the Vault, and a time multiplier so a 20-second unwrap takes one. Listed in [HANDOFF.md](codex/HANDOFF.md).

### Before you push

- Run `lune run tests/run`, `stylua --check src tests` and `selene src`. All three should be clean. (If StyLua reports every file as changed with identical text on both sides, your clone has CRLF line endings — [`.gitattributes`](.gitattributes) should prevent that, but an older clone may need `git rm -r --cached . && git reset --hard` to pick it up.)
- Update [`codex/HANDOFF.md`](codex/HANDOFF.md) with what you did and what you actually checked, and update this README if what a player sees has changed.
- The repo is **public**, so never commit passwords, tokens or files that contain your computer's user folder path. Blender files and renders can hide one, and so can PNG metadata.
