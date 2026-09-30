# Showcase Heist (Alpha step 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Convention (same as the slice plan):** this plan fixes the contracts, the Lune tests and the Studio verification steps. Server and client code is written during execution. Commit only when the user asks, after the secret/path scan in `AGENTS.md`.

**Goal:** the first Alpha item on top of the vertical slice. Players can unwrap on their porch Showcase (faster, +50 % income) and move Chonks between Vault and porch. Neighbours can steal porch Chonks and carry them home. An NPC dummy house teaches the heist risk-free. Victims get an alarm and a two-minute raid cooldown, and nothing is ever deleted.

**Architecture:** the new pure rules (`Slots`, `ShowcaseRules`, plus `VaultRules` and `Format` additions) are tested headlessly in Lune. The server first gets two small refactors: one registry for every physical item (`Carry.Item`: a nest burrito or a Chonk), and Vault pads keyed by slot, so Chonks can leave a pad. A new `Showcase` service owns the porch slots, stealing and returns. A new `DummyBase` service owns the practice house. A client `PromptFilter` hides prompts meant for someone else. Studio behaviour is verified through `ServerStorage.DevHooks`, as in the slice.

**Tech Stack:** Luau, Rojo 7.7.0, Lune 0.10.5, Selene 0.31.0, StyLua 2.5.2, Roblox Studio with the Studio MCP.

**Spec:** [docs/superpowers/specs/2026-09-06-steal-a-chonk-design.md](../specs/2026-09-06-steal-a-chonk-design.md), mainly §2, §5 step 4, §10, §11, §18, §20 and §23. It builds on [the vertical-slice plan](2026-09-24-vertical-slice-prototype.md).

## Global Constraints

- "**Showcase (porch)**: raidable. +50 percent income. … Unlimited incubation, faster unwrap, stealable while unwrapping. Starts at 2 slots, grows to 8 by Legend stage." (§10)
- "Moving Chonks between Vault and Showcase is free and instant while standing on your base. Not possible remotely." (§10)
- "**Showcase**: grab an unshielded Chonk and carry it home under the same carry rules. The victim's porch lights flash red and their Alarm fires." (§11)
- "**Nothing deleted**: if a victim leaves the server while their Chonk is being carried, it returns to the victim's inventory. If a carrier leaves, the item returns to its last owner." (§11)
- "**Dummy base**: an NPC house near spawn with a stealable Common on its porch and a tutorial prompt. Teaches theft risk-free at minute two." (§11)
- "**Raid cooldown**: after a Showcase theft, two minutes of Showcase immunity. No chain robbing." (§11)
- "Theft notification: 'Greg has been stolen. Greg is not surprised.'" (§18) All strings live in `Strings`; all numbers live in `Config`.
- Server authority (§20): clients send intents only, and every prompt handler re-checks reach and ownership on the server.
- Pillars 2 and 5: loss only by choice (the Vault stays unstealable), and nothing is ever deleted.
- The slice's rules stay: the bat works only in the field, guardians never cross the curb, persistence is session-only, and art is greybox parts.
- Out of scope, so later Alpha plans own them: shields and the away timer, defenses (Alarm item, Bear Trap, Guard, Decoy), Grudge and Wanted, the rookie shield (it needs rebirth), porch growth beyond 2 slots, leaderboards and broadcasts, alarm sound.

### Prototype decisions the spec does not settle (proposals, tune or overrule freely)

| Decision | Proposal | Why |
| --- | --- | --- |
| Porch incubation | Every free porch slot can unwrap. The burrito unwraps in place and the Chonk stays on that slot | Reads "unlimited incubation" (§10) as no incubator cap on the porch, only the 2-slot cap |
| Porch unwrap speed | × 0.5 of the Vault time | §10 says "faster" and gives no number |
| Steal prompt | Hold 1.5 s within 8 studs | Gives the owner a beat to notice. §11 is silent |
| What can be stolen | Revealed porch Chonks and burritos unwrapping on the porch | §10 "stealable while unwrapping" |
| Stolen burrito progress | Keeps its unwrap fraction, and resumes at that fraction wherever it is deposited | Nothing lost, simple to explain |
| Depositing a carried Chonk | The Vault prompt ("Put in Vault") stashes it on a free Vault pad with no unwrap. A porch slot shows it off | Same carry rules as burritos (§11) |
| Bat inside the district | Unchanged: field only. In this step a thief crossing the district cannot be stopped | §3 keeps the base safe. Shields, defenses and Grudge are the counterplay in later Alpha plans. Testers should judge the feel |
| Dropped stolen item | Anyone may pick it up. After 60 s untouched it returns to its last owner: porch first, then Vault, else it waits | §11 field rule plus nothing deleted |
| Victim leaves mid-theft | The carried item disappears with the victim | Session-only prototype: the victim's inventory leaves with them (§11 "returns to the victim's inventory") |
| Alarm | The victim's porch lights flash red for 6 s. Victim and thief get the theft toasts | §11 and §18. No audio assets exist yet |
| Dummy house | At the district centre (0, 24), next to the fallback spawn. It holds a random Common. Each player may keep one dummy Chonk per session. The Chonk respawns 45 s after it is taken | "Near spawn" for every porch. Once per player stops farming free Commons |

## Review Focus

1. **Two thieves finish holding Steal on the same porch item in the same frame.** Exactly one carries it, the other gets "taken", and the slot empties once. Test: Task 4 "double steal".
2. **The thief resets, is batted or leaves while carrying.** The item never vanishes. After a reset it lies loose and later returns to its last owner. After a leave it returns immediately. Test: Task 5 "robMe" and "kick".
3. **The victim leaves while a thief carries their Chonk.** The item leaves with the victim, the thief's speed resets and nothing errors. Test: Task 6 two-player checklist. The owner-leaves server path is exercised solo in Task 5 step 5.
4. **A thief gets home with a full Vault and a full porch.** The deposit is refused with a message, the thief keeps carrying, and nothing is lost. Test: Task 4 "full house".
5. **The owner moves a porch Chonk to the Vault while a thief is holding Steal on it.** Exactly one of them wins. The steal re-checks availability when the hold completes, and the move removes the item in one step. Test: Task 4 "move versus steal".

---

## File structure

```
src/shared/
  Slots.luau          NEW  helpers for slot maps with holes
  ShowcaseRules.luau  NEW  porch placement, steal checks, porch unwrap/income, returns, moves, theft copy
  VaultRules.luau     +hasRoom, +canStash
  Format.luau         +clock (m:ss countdowns)
  Config.luau         +Showcase, +DummyBase
  Strings.luau        +toasts, +Theft, +prompts, +Showcase
src/server/
  Carry.luau          Item registry (register/forget/items/setStatus), generic grab prompt, pickUp from the porch
  Nests.luau          uses the Carry registry; guardians and loose returns only for unowned nest burritos
  Vault.luau          pad-keyed records, addRecord/removeRecord, stash Chonks, resume burrito progress
  PlayerState.luau    vault as pad map, +showcase, +immuneUntil, +dummyTaken
  Models.luau         welded Chonk model, progressLabel/nameLabel helpers
  Plots.luau          porch slot pads, porch lights, cooldown sign, isOnPlot
  Showcase.luau       NEW  porch slots, porch unwrap, moves, steal, alarm, raid cooldown, returns
  DummyBase.luau      NEW  practice house and its Chonk
  DevActions.luau     +items, porch, toVault, toPorch, steal, robMe, dummy state
  Main.server.luau    boot order: … Vault → Showcase → DummyBase → Bat …
src/client/
  PromptFilter.luau   NEW  hides prompts whose Audience does not include the local player
  Main.client.luau    starts PromptFilter
tests/
  Slots.spec.luau, ShowcaseRules.spec.luau  NEW; VaultRules.spec.luau, Format.spec.luau extended; run.luau lists the new suites
```

## Shared contracts

```luau
-- Carry (server). Every physical item is one of these, whether it is in a nest, carried, loose, incubating or on a porch.
export type Item = {
	id: number,
	kind: "burrito" | "chonk",
	roll: { chonkId: string, tier: string, size: number }, -- chonks: the record's fields
	model: Model,
	status: "ready" | "carried" | "loose" | "incubating" | "showcase",
	carrier: Player?,
	looseAt: number?,
	nest: number?, -- nest burritos only
	owner: Player?, -- last owner; nil for field burritos and the dummy Chonk
	dummy: boolean?, -- the dummy house's Chonk until someone keeps it
	uid: number?, -- chonks: record uid in the owner's sequence
	progress: number?, -- burritos: unwrap fraction already done, 0..1
}
export type Burrito = Item
Carry.register(fields): Item      -- assigns id, adds the GrabPrompt, parents nothing
Carry.forget(item)                 -- removes from the registry and destroys the model
Carry.items(): { [number]: Item }
Carry.setStatus(item, status)      -- the only way to change status; the GrabPrompt is enabled only when "ready" or "loose"
Carry.pickUp(player, item): (boolean, string?) -- accepts "ready", "loose" and "showcase"; status is checked first
-- Carry.drop / take / inField / knockback / placeOnGround: unchanged signatures.

-- PlayerState.State additions and changes
vault: { [number]: ChonkRecord }  -- display pad → record, holes allowed
showcase: { [number]: Carry.Item } -- porch slot → item
immuneUntil: number               -- os.clock() when the raid cooldown ends; 0 = never robbed
dummyTaken: boolean

-- Showcase (server)
Showcase.Stolen: Signal            -- (thief: Player?, victim: Player?, item: Item)
Showcase.place(player, plotIndex): (boolean, string?)
Showcase.toVault(player, slot): (boolean, any) -- (true, pad) or (false, reason)
Showcase.toPorch(player, pad): (boolean, any)  -- (true, slot) or (false, reason)
Showcase.steal(player, plotIndex, slot): (boolean, string?)
Showcase.returnToOwner(item): boolean -- porch first, then Vault; false = no room yet

-- DummyBase (server)
DummyBase.steal(player): (boolean, string?)
DummyBase.item(): Item?
DummyBase.reseat(item)             -- a dummy Chonk came back; drops it if the porch refilled

-- Vault (server) additions
Vault.addRecord(player, record): number?   -- first free pad, places the display
Vault.removeRecord(player, pad): ChonkRecord?
Vault.startIncubation(player, slot, item) -- honours item.progress
```

Prompt attributes (server sets them, and the client `PromptFilter` reads them): `Plot` (number) and `Audience` (`"owner"` or `"others"`). A prompt with no `Audience` is shown to everyone. The server never toggles `Enabled` on audience prompts; it creates and destroys them. Pedal, incubator, porch-slot, move and steal prompts all get the attributes. This also closes the slice's deferred "other players' prompts are visible".

DevHooks additions: `porch(name)`, `toVault(name, slot)`, `toPorch(name, pad)`, `steal(name, plotIndex, slot)` (`plotIndex` 0 is the dummy house), `robMe(name, slot)`. They return what the real path returns. `state` gains `items` and `dummy` (`{ id, status }` or false). Each player entry gains:
- `showcase`: slot → `{ kind, status, tier, size, remaining }`, where `remaining` is set for unwrapping burritos;
- `immuneFor`: seconds left, 0 when not immune;
- `dummyTaken`.

All hooks teleport first, unless a trailing `stayPut` is true, then run the real path. Remember `setTimeScale` multiplies durations: 0.05 is 20× faster.

---

### Task 1: Pure rules, config and copy

**Files:** create `src/shared/Slots.luau`, `src/shared/ShowcaseRules.luau`, `tests/Slots.spec.luau`, `tests/ShowcaseRules.spec.luau`. Modify `src/shared/{VaultRules,Format,Config,Strings}.luau`, `tests/VaultRules.spec.luau`, `tests/Format.spec.luau` and `tests/run.luau`.

**Interfaces:**
- Produces:
  - `Slots.count(map): number`
  - `Slots.firstFree(map, capacity): number?`
  - `VaultRules.hasRoom(vaultCount, incubating): boolean`. `canDeposit` keeps its behaviour and uses it.
  - `VaultRules.canStash({ carrying, atOwnIncubator, vaultCount, incubating })`
  - `Format.clock(seconds): string`: `m:ss`, rounded up, so a live countdown never shows 0:00.
  - `Config.Showcase`: `slots = 2, unwrapFactor = 0.5, incomeMultiplier = 1.5, placeDistance = 8, stealHoldSeconds = 1.5, raidCooldownSeconds = 120, alarmSeconds = 6`.
  - `Config.DummyBase`: `x = 0, z = 24, respawnSeconds = 45`.
  - `ShowcaseRules`: `canPlace`, `canSteal`, `canKeep`, `unwrapSeconds`, `progressAt`, `remainingSeconds`, `incomePerSecond`, `returnPlan`, `canMoveToPorch`, `canMoveToVault` and `theftMessages`, with the signatures the tests below use.
- Strings:
  - `Toasts.porchFull`, `yours`, `immune`, `dummyDone`, `awayFromHome`, `stashed`, `onPorch`;
  - `Theft.stolen` = `"%s has been stolen. %s is not surprised."`, plus `Theft.youStole`, `Theft.wentHome`, `Theft.cameBack`;
  - `Prompts.place`, `porchObject`, `steal`, `toVault`, `toPorch`, `vaultDeposit` (replaces `unwrap` on incubators), `chonkObject`;
  - `Showcase.raidCooldown` (`"Raid cooldown %s"`), `Showcase.dummySign`, `Showcase.dummyHouse`.

- [ ] **Step 1: Write the failing tests.**

`tests/Slots.spec.luau`:

```luau
local T = require("./TestLib")
local Slots = require("../src/shared/Slots")

T.test("count ignores holes", function()
	T.expectEqual(Slots.count({ [1] = "a", [3] = "b" }), 2)
	T.expectEqual(Slots.count({}), 0)
end)

T.test("firstFree returns the lowest empty slot within capacity", function()
	T.expectEqual(Slots.firstFree({ [1] = "a", [3] = "b" }, 4), 2)
	T.expectEqual(Slots.firstFree({}, 2), 1)
	T.expectEqual(Slots.firstFree({ [1] = "a", [2] = "b" }, 2), nil)
end)

return {}
```

`tests/ShowcaseRules.spec.luau`:

```luau
local T = require("./TestLib")
local Config = require("../src/shared/Config")
local Formulas = require("../src/shared/Formulas")
local ShowcaseRules = require("../src/shared/ShowcaseRules")

local function steal(overrides)
	local c = { available = true, isOwner = false, carrying = false, now = 100, immuneUntil = 0, isDummy = false, dummyTaken = false }
	for k, v in overrides or {} do
		c[k] = v
	end
	return c
end

T.test("a free-handed neighbour may steal an available porch item", function()
	T.expectEqual(ShowcaseRules.canSteal(steal()), true)
end)

T.test("steal refusals name their reason, availability first", function()
	T.expectEqual(select(2, ShowcaseRules.canSteal(steal({ available = false, isOwner = true }))), "taken")
	T.expectEqual(select(2, ShowcaseRules.canSteal(steal({ isOwner = true }))), "yours")
	T.expectEqual(select(2, ShowcaseRules.canSteal(steal({ carrying = true }))), "alreadyCarrying")
	T.expectEqual(select(2, ShowcaseRules.canSteal(steal({ immuneUntil = 100.5 }))), "immune")
	T.expectEqual(select(2, ShowcaseRules.canSteal(steal({ isDummy = true, dummyTaken = true }))), "dummyDone")
end)

T.test("immunity ends exactly at immuneUntil", function()
	T.expectEqual(ShowcaseRules.canSteal(steal({ now = 220, immuneUntil = 220 })), true)
end)

T.test("placing on your porch takes the first free slot", function()
	T.expectEqual(select(2, ShowcaseRules.canPlace({ carrying = "burrito", atOwnPlot = true, slots = {} })), 1)
	T.expectEqual(select(2, ShowcaseRules.canPlace({ carrying = "chonk", atOwnPlot = true, slots = { [1] = true } })), 2)
end)

T.test("placing refusals", function()
	local full = {}
	for slot = 1, Config.Showcase.slots do
		full[slot] = true
	end
	T.expectEqual(select(2, ShowcaseRules.canPlace({ carrying = nil, atOwnPlot = true, slots = {} })), "notCarrying")
	T.expectEqual(select(2, ShowcaseRules.canPlace({ carrying = "burrito", atOwnPlot = false, slots = {} })), "notYourBase")
	T.expectEqual(select(2, ShowcaseRules.canPlace({ carrying = "burrito", atOwnPlot = true, slots = full })), "porchFull")
end)

T.test("a second dummy Chonk cannot be kept", function()
	T.expectEqual(ShowcaseRules.canKeep(false, true), true)
	T.expectEqual(ShowcaseRules.canKeep(true, false), true)
	T.expectEqual(select(2, ShowcaseRules.canKeep(true, true)), "dummyDone")
end)

T.test("the porch unwraps faster than the Vault", function()
	local vault = Formulas.unwrapSeconds("Rare", 3)
	T.expectNear(ShowcaseRules.unwrapSeconds("Rare", 3, true), vault * Config.Showcase.unwrapFactor, 1e-9)
	T.expectNear(ShowcaseRules.unwrapSeconds("Rare", 3, false), vault, 1e-9)
end)

T.test("unwrap progress carries over and is clamped", function()
	T.expectNear(ShowcaseRules.progressAt(0, 10, 40, 30), 0.5, 1e-9)
	T.expectNear(ShowcaseRules.progressAt(0.5, 10, 40, 60), 1, 1e-9)
	T.expectNear(ShowcaseRules.progressAt(0.25, 10, 40, 5), 0.25, 1e-9)
	T.expectNear(ShowcaseRules.remainingSeconds(0.25, 80), 60, 1e-9)
end)

T.test("porch Chonks earn half again", function()
	local vault = { [1] = { tier = "Common", size = 1 } }
	local porch = { [2] = { tier = "Uncommon", size = 1 } }
	T.expectNear(ShowcaseRules.incomePerSecond(vault, porch), 1 + 5 * Config.Showcase.incomeMultiplier, 1e-9)
	T.expectNear(ShowcaseRules.incomePerSecond({}, {}), 0, 1e-9)
end)

T.test("a returning item goes to the porch first, then the Vault", function()
	local where, slot = ShowcaseRules.returnPlan(2, 5)
	T.expectEqual(where, "showcase")
	T.expectEqual(slot, 2)
	where, slot = ShowcaseRules.returnPlan(nil, 5)
	T.expectEqual(where, "vault")
	T.expectEqual(slot, 5)
	T.expectEqual(ShowcaseRules.returnPlan(nil, nil), nil)
end)

T.test("moving between Vault and porch only works at home and with room", function()
	T.expectEqual(select(2, ShowcaseRules.canMoveToPorch({ onOwnPlot = true, porchFree = 2 })), 2)
	T.expectEqual(select(2, ShowcaseRules.canMoveToPorch({ onOwnPlot = false, porchFree = 2 })), "awayFromHome")
	T.expectEqual(select(2, ShowcaseRules.canMoveToPorch({ onOwnPlot = true, porchFree = nil })), "porchFull")
	T.expectEqual(ShowcaseRules.canMoveToVault({ onOwnPlot = true, vaultCount = 0, incubating = 0 }), true)
	T.expectEqual(
		select(2, ShowcaseRules.canMoveToVault({ onOwnPlot = false, vaultCount = 0, incubating = 0 })),
		"awayFromHome"
	)
	T.expectEqual(
		select(2, ShowcaseRules.canMoveToVault({ onOwnPlot = true, vaultCount = Config.Vault.displaySlots - 1, incubating = 1 })),
		"vaultFull"
	)
end)

T.test("theft messages follow the comedy voice", function()
	local victim, thief = ShowcaseRules.theftMessages("Greg")
	T.expectEqual(victim, "Greg has been stolen. Greg is not surprised.")
	T.expectTrue(string.find(thief, "Greg", 1, true) ~= nil)
end)

return {}
```

Append to `tests/VaultRules.spec.luau` (before `return {}`):

```luau
T.test("stashing a Chonk needs room, not an incubator", function()
	local function stash(o)
		local c = { carrying = true, atOwnIncubator = true, vaultCount = 0, incubating = 2 }
		for k, v in o or {} do
			c[k] = v
		end
		return c
	end
	T.expectEqual(VaultRules.canStash(stash()), true)
	T.expectEqual(select(2, VaultRules.canStash(stash({ carrying = false }))), "notCarrying")
	T.expectEqual(select(2, VaultRules.canStash(stash({ atOwnIncubator = false }))), "notYourBase")
	T.expectEqual(select(2, VaultRules.canStash(stash({ vaultCount = Config.Vault.displaySlots - 2 }))), "vaultFull")
end)

T.test("vault income ignores holes between pads", function()
	local pads = { [1] = { tier = "Common", size = 1 }, [4] = { tier = "Common", size = 2 } }
	T.expectNear(VaultRules.incomePerSecond(pads), 1 + 1.5, 1e-9)
end)
```

Append to `tests/Format.spec.luau` (before `return {}`):

```luau
T.test("clock prints m:ss and rounds up", function()
	T.expectEqual(Format.clock(0), "0:00")
	T.expectEqual(Format.clock(61), "1:01")
	T.expectEqual(Format.clock(119.2), "2:00")
end)
```

Add `Slots` and `ShowcaseRules` suites to `tests/run.luau`.

- [ ] **Step 2: Run to see them fail.** `export PATH="$HOME/.rokit/bin:$PATH"; lune run tests/run`. Expected: load failures for `Slots` and `ShowcaseRules`, and failures for `canStash` and `clock`.
- [ ] **Step 3: Implement.** Write `Slots`, `ShowcaseRules`, `VaultRules.hasRoom`/`canStash`, `Format.clock`, and the Config and Strings entries. `ShowcaseRules` uses `Slots`, `Formulas`, `VaultRules`, `Config` and `Strings` only.
  - `canSteal` checks, in order: `available` → `"taken"`, `isOwner` → `"yours"`, `carrying` → `"alreadyCarrying"`, `now < immuneUntil` → `"immune"`, `isDummy and dummyTaken` → `"dummyDone"`.
  - `progressAt(p, startedAt, duration, now) = clamp(p + max(now - startedAt, 0) / duration, 0, 1)`.
  - `returnPlan(porchFree, vaultFree)` returns `"showcase", porchFree`, else `"vault", vaultFree`, else nil.
- [ ] **Step 4: Run to see them pass.** `lune run tests/run` must report 0 failed. Also run `stylua --check src tests` and `selene src`.

### Task 2: One item registry and pad-keyed Vault (refactor, no behaviour change)

**Files:** modify `src/server/{Carry,Nests,Vault,PlayerState,Models,DevActions}.luau`.

**Interfaces:**
- Consumes: `Slots` (Task 1).
- Produces: the `Carry.Item` contract and `PlayerState` state shape above.
  - `Nests.burritos()` and `Nests.consume()` are removed. Callers use `Carry.items()` and `Carry.forget()`.
  - `Nests.carrierFrom(index)` counts only items with `kind == "burrito"`, `nest == index`, `owner == nil` and `status == "carried"`.
  - Nests' loose-return loop handles only those unowned nest burritos.
  - `Models.chonk` welds ears and eyes to the body with `WeldConstraint`s, so it survives being unanchored.
  - `Models.progressLabel(parent)` and `Models.nameLabel(model, text, color, offsetY)` move out of `Vault`.
  - `DevActions` replaces the `burritos` state section with `items`, listing `{ id, kind, status, tier, nest, owner, carrier, dummy }`.

- [ ] **Step 1: Implement the refactor.**
  - `Carry.register` creates the `GrabPrompt` (moved from `Nests.spawnBurrito`).
  - `Carry.setStatus` owns prompt enabling.
  - Vault records live at `state.vault[pad]`. A reveal takes `Slots.firstFree(state.vault, Config.Vault.displaySlots)`, the income loop and `fill` use pad keys, and `DevActions` reports `vault = Slots.count(state.vault)`.
- [ ] **Step 2: Lune, StyLua, Selene.** All pass, with the same count as after Task 1.
- [ ] **Step 3: Regression in Studio.** Start play. In Server context:
  - `setTimeScale 0.05`, `grab` nest 1 and `deposit`. Wait for `vault == 1`; cash then rises by that Chonk's income each second.
  - `grab` nest 2 (the hook leaves the player beside the nest, in the field): `state.items` shows its status `carried`, and `guardians[2].mode` becomes `waking` or `chase` within 2 s.
  - `drop`, then wait 3.5 s at timeScale 0.05: the burrito is `ready` at nest 2 again.
  - `fillVault`, then `grab` and `deposit`: `false, "vaultFull"`.
  - The console shows only the boot lines. Stop play.

### Task 3: Porch Showcase: place, unwrap, earn, move

**Files:** create `src/server/Showcase.luau` and `src/client/PromptFilter.luau`. Modify `src/server/{Plots,Vault,Wheel,DevActions,Main.server}.luau` and `src/client/Main.client.luau`.

**Interfaces:**
- Consumes: `ShowcaseRules`, `Slots`, `VaultRules.hasRoom` and the `Carry` registry.
- Produces:
  - `Showcase.place`, `Showcase.toVault` and `Showcase.toPorch`; `Vault.addRecord` and `Vault.removeRecord`.
  - `Plots.isOnPlot(player, plotIndex): boolean`: the root is inside the plot square, plus 2 studs.
  - `Plots` builds the following. Plot-local −Z is the porch side, and x = 0 is the spawn, so the slots avoid it.
    - Pads `Showcase1` and `Showcase2` at local (−8, 1.3, −16) and (8, 1.3, −16).
    - Two Neon `PorchLight` parts at (±19, 3, −19.5).
    - A disabled `CooldownSign` billboard above the porch.
  - Prompts:
    - Each porch pad has a `PlacePrompt` (`Strings.Prompts.place`, audience owner) that calls `Showcase.place`.
    - A porch Chonk has a `MovePrompt` (`toVault`, audience owner).
    - A Vault display has a `MovePrompt` (`toPorch`, audience owner).
    - Incubator prompts now read `Strings.Prompts.vaultDeposit`.
    - Pedal and incubator prompts gain the `Plot` and `Audience` attributes.
  - Porch unwrap:
    - Duration: `ShowcaseRules.unwrapSeconds(tier, size, true) × timeScale`, resuming from `item.progress`.
    - A progress label shows on the pad.
    - On reveal: `Carry.forget(burrito)`, then register a `chonk` item on the pad, fire `Reveal` with `incomePerSecond × incomeMultiplier`, and give it a name label.
  - Income: the Vault loop pays `ShowcaseRules.incomePerSecond(state.vault, porchRecords)`, where `porchRecords` are the rolls of `chonk` items in `state.showcase`.
  - `PromptFilter` sets `prompt.Enabled` locally from `Plot`/`Audience` against `LocalPlayer`'s `Plot` attribute. It re-runs on `DescendantAdded` and on `Plot` changes.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify place and faster unwrap.** `setTimeScale 0.05`, then `grab` nest 1 and `porch`.
  - `state.players[n].showcase[1]` is a burrito with `status == "showcase"`.
  - The reported remaining time is ≈ half the Vault time for its tier and size, × timeScale.
  - After the reveal, `showcase[1].kind == "chonk"`, and a Reveal card was fired (the card `ScreenGui` is enabled in Client context).
- [ ] **Step 3: Verify income.** Sample `cash` over 3 s: it grows at `Formulas.incomePerSecond × 1.5`, ±1 per tick.
- [ ] **Step 4: Verify moves.**
  - `toVault 1` → `true, pad`; `showcase[1] == nil` and `vault` +1; income drops to the base rate.
  - `toPorch pad` → `true, slot`; the Chonk is back on the porch.
  - `teleport` to (0, 160), then `toVault 1` with stayPut → `false, "awayFromHome"`.
- [ ] **Step 5: Verify a full porch** (Review Focus 4, porch half). Put a burrito on each of the 2 slots. A third `porch` → `false, "porchFull"`, and `carrying` is still set.
- [ ] **Step 6: Verify the prompt filter.** In Client context, the player's own `Showcase1.PlacePrompt.Enabled == true`, and another plot's `PlacePrompt.Enabled == false`. Lune, StyLua, Selene pass. The console is clean.

### Task 4: Stealing and the dummy house (thief side)

**Files:** create `src/server/DummyBase.luau`. Modify `src/server/{Showcase,Carry,Vault,DevActions,Main.server}.luau`.

**Interfaces:**
- Consumes: `ShowcaseRules.canSteal/canKeep/progressAt`, `VaultRules.canStash` and `Showcase.place`.
- Produces: `Showcase.steal`, `Showcase.Stolen`, `DummyBase.steal/item/reseat`, and a Vault that accepts carried Chonks and honours `progress`.
  - **Steal prompts:** each porch item gets a `StealPrompt` (`Strings.Prompts.steal`, `HoldDuration = Config.Showcase.stealHoldSeconds`, audience others). Its handler:
    1. runs `canSteal` with `available = (item still in that slot and status "showcase")`;
    2. for a burrito, computes `progress` with `progressAt`;
    3. runs `Carry.pickUp`;
    4. only after a successful pick-up, clears the slot and its prompts and labels, then fires `Showcase.Stolen(thief, owner, item)`.
  - **Carry pick-up:** `Carry.pickUp` lifts the model to `math.max(3.6, 1.5 + extents.Y / 2)` above the root.
  - **Deposits:** both deposit paths (the Vault prompt and a porch slot) run `canKeep(item.dummy, state.dummyTaken)` first.
    - Vault, chonk item: `canStash` → `Vault.addRecord` with a fresh uid from the depositor's `nextUid`, then `Carry.forget`.
    - Vault, burrito: incubation via `Vault.startIncubation`, which honours `progress`.
    - Porch: `Showcase.place` handles both kinds.
    - After a deposit: `owner = depositor`, `dummy = nil`, and `dummyTaken = true` if the item was the dummy.
  - **DummyBase:** builds a small greybox house at (`Config.DummyBase.x`, `z`) facing the centre, with one porch pad, the `dummySign` billboard and a `Strings.Showcase.dummyHouse` label.
    - It seats a random Common as a `chonk` item with `status = "showcase"`, `dummy = true`, `owner = nil` and a `StealPrompt` with no `Audience`.
    - When the item leaves, it schedules a respawn after `respawnSeconds × timeScale`. The respawn is skipped if a returning dummy Chonk has already been reseated.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify the solo heist.** `setZoomies 0`, then `steal name 0 1` → true.
  - WalkSpeed = `carrySpeed(0, "Common")` = 12.8.
  - `deposit` → true; `vault` +1, and `dummyTaken == true`.
  - Cash grows by that Common's income.
- [ ] **Step 3: Verify the refusals.**
  - Wait for the dummy respawn: `state.dummy` present after about 2.3 s at timeScale 0.05. `steal name 0 1` → `false, "dummyDone"`.
  - Put a Chonk on the player's own porch: `steal name <ownPlot> 1` → `false, "yours"`.
  - `grab` a nest burrito, then `steal` anything → `false, "alreadyCarrying"`.
- [ ] **Step 4: Verify the double steal** (Review Focus 1). Reset `dummyTaken` via a fresh playtest. In one Server-context call, invoke `steal name 0 1` twice back to back → `true`, then `false, "taken"`. `state.items` shows exactly one carried dummy item.
- [ ] **Step 5: Verify the full house** (Review Focus 4). Carry the dummy Chonk home with `fillVault` done and both porch slots filled. `deposit` → `false, "vaultFull"`, `porch` → `false, "porchFull"`, and `carrying` is still `Common`.
- [ ] **Step 6: Verify move versus steal** (Review Focus 5, one player). Put a Chonk on the porch. In one Server-context call, run the owner's `toVault 1`, then `Showcase.steal` on that slot through the `steal` hook as the same player. The move returns true, and the steal returns `false, "taken"`, not `"yours"`, because availability is checked first. The item ends in the Vault only.
- [ ] **Step 7:** Lune, StyLua and Selene pass. The console is clean.

### Task 5: Victim side and "nothing deleted"

**Files:** modify `src/server/{Showcase,DummyBase,Carry,DevActions}.luau`.

**Interfaces:**
- Consumes: `Showcase.Stolen`, `ShowcaseRules.returnPlan/theftMessages` and `Format.clock`.
- Produces:
  - **On `Stolen` with a victim:**
    - `victim.immuneUntil = now + raidCooldownSeconds × timeScale`;
    - the victim's `PorchLight`s blink red for `alarmSeconds`, then restore their colour;
    - the victim gets the `Theft.stolen` toast and the thief `Theft.youStole` (both with the Catalog `name`);
    - `CooldownSign` shows `Strings.Showcase.raidCooldown` with `Format.clock(remaining)`, updated each second and hidden at 0.
  - **Owned loose items:** after `looseReturnSeconds × timeScale` untouched, `Showcase.returnToOwner(item)` runs; if there is no room, it retries every tick. Loose dummy items go to `DummyBase.reseat`.
  - **Carrier leaves** (`Carry.Dropped`, reason `"left"`): the item is returned immediately (to its owner, or to the dummy house).
  - **Owner leaves:** any of their items being carried is `Carry.take`n from the carrier, who gets `Theft.wentHome`, and then `forget`; the rest of their items are `forget`ted.
  - **DevHooks `robMe(name, slot)`:** the Studio-only victim seam. It runs the real `Stolen` effects with no thief, then leaves the item loose on the lawn 6 studs in front of the porch, with `progress` recorded for burritos.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify the alarm and cooldown.** `setTimeScale 0.05`; put a burrito on porch slot 1 and wait until about 50 % done; then `robMe name 1`.
  - `immuneFor` ≈ 6 (120 × 0.05).
  - Within 1 s a `PorchLight` colour reads red; after 6 s it is back.
  - `CooldownSign` is enabled while immune and disabled after.
- [ ] **Step 3: Verify the loose return and resumed progress** (Review Focus 2). After `robMe`, the item is `loose` with `owner` = the player. After about 3 s (60 × 0.05) it is back on porch slot 1. Its remaining time is ≈ 50 % of the porch duration × timeScale, not 100 %.
- [ ] **Step 4: Verify a thief leaving** (Review Focus 2). New playtest. `steal name 0 1`, then `Players:GetPlayers()[1]:Kick()` in Server context. `DevHooks state` (no players) shows `dummy` present with the same item id, and no loose dummy items. Stop play.
- [ ] **Step 5: Verify the owner-leaves path** (the server half of Review Focus 3, one player). Put a Chonk on the porch, then `robMe` so it lies loose. Kick the player, which is the real leave path. `state.items` shows no items owned by that player, and the console is clean.
- [ ] **Step 6:** Lune, StyLua and Selene pass.

### Task 6: End-to-end pass, tester checklist and notes

- [ ] **Step 1:** `lune run tests/run`, `stylua --check src tests`, `selene src` and `rojo build default.project.json -o build/prototype.rbxl` all pass.
- [ ] **Step 2: One uninterrupted MCP playtest at timeScale 1,** with DevHooks only for `state`:
  1. walk to the dummy house and hold E on its Chonk (`user_keyboard_input` key down, wait 1.7 s, key up);
  2. walk home, press E at the incubator ("Put in Vault") and see the Chonk on a Vault pad;
  3. pedal, grab a burrito, run home and press E on a porch slot;
  4. watch the porch unwrap at half the Vault time and the reveal card;
  5. check that income includes the +50 %.

  Note anything that felt wrong.
- [ ] **Step 3: Record the two-player checklist in `codex/HANDOFF.md`** for the testers (Test → Clients and Servers, 2 players):
  1. Only the neighbour sees Steal; only the owner sees Put here, To Vault and Pedal.
  2. The neighbour steals a porch Chonk. The victim's porch flashes red, both toasts appear, and the thief walks home at carry speed and deposits.
  3. A second steal on the victim's porch within 2 minutes → "immune" toast.
  4. The thief resets mid-carry: the Chonk lies loose, then returns to the victim after 60 s.
  5. The victim leaves while the thief carries: the Chonk vanishes from the thief's hands, the thief's speed resets, and the thief gets the "went home" toast.
  6. The bat in the field still drops a thief's Chonk; inside the curb it does nothing (proposal row "Bat inside the district").
- [ ] **Step 4: Update `codex/HANDOFF.md`:** what works, what was verified and how, and what is outstanding. That covers the two-player checklist, the slice's pending bat check, feel notes and persistence (still absent). Record the proposals table in `codex/PROJECT_CONTEXT.md` as prototype proposals.
