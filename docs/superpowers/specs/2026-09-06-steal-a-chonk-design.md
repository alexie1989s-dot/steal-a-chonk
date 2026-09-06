# Steal a Chonk — Design Spec

Date: 2026-09-06
Status: Draft for review by both developers
Team: two developers, full time. Roblox Studio, Rojo, Blender, GPT Image 2, Claude Code.

---

## 1. Thesis

The "Steal a ..." genre's loop is proven: acquire in the field, carry home, earn passively, get faster, unlock farther. Its weaknesses are also proven: rookies get farmed, the same fast player wins every event, loss is pure and unrevenged, the late-game base is a scoreboard, and the humor is borrowed. We keep the loop and fix the weaknesses. The theme, an original line of ultra-round animals called Chonks, is ours outright.

The game is not trying to be clever about acquisition. It is trying to be the funniest, fairest, and most re-playable game in its genre.

## 2. Pillars (priority order)

1. **Zoomies are the power fantasy.** Speed is the one progression you feel in your hands. Every system makes going faster more fun.
2. **Loss is always a choice.** Nobody loses anything they chose to protect. Drama comes from what players volunteer to risk.
3. **Every theft has a second act.** Being robbed gives you a mission. Robbing makes you a target.
4. **Nobody leaves their base for free.** Every Chonk is carried home through the field by a player. No safe acquisition exists anywhere.
5. **Nothing is ever deleted.** Value only moves between players.
6. **Every system ships with a joke.** Names, bios, notifications, broadcasts, and size stamps are written to make players laugh out loud. Humor is affectionate, never mocking.

## 3. Ground truth and non-goals

Verified facts about Steal an Egg (confirmed by the partner who has played it) that we build on or deliberately diverge from:

- No conveyor. Eggs spawn in guarded nests in biomes. We adopt field acquisition.
- Guardians chase for as long as you hold the egg, stopping only at the boundary between field and bases. We adopt this exactly.
- The base is fully safe; all PvP theft is in the field while carrying. We keep a safe Vault and add an opt-in raidable Showcase.
- Hatch time scales with rarity and size. We adopt.
- No temperature or upkeep chores. We have none.
- The treadmill raises Speed only. Ours raises Zoomies only.
- The secret egg has a daily chance to spawn. Our Big Chonk uses the same scarcity model.
- Steal an Egg was temporarily removed by Roblox on 2026-08-28 for an autoplaying video feed. We ship no media feeds of any kind.

Explicitly not building: conveyor belts, safe acquisition of any kind, base locks, body swap, item deletion, offline raids, failure cooldowns, upkeep chores, crews, media feeds, borrowed IP or names of real people.

## 4. Player fantasy and tone

You are a kid with Zoomies in a sleepy neighborhood where enormous round animals nap everywhere. You collect them, show them off on your porch, and occasionally borrow one from the neighbors. Chonks are proud, loved, and completely unbothered. The world is cozy, sunny, and slightly absurd. Nothing is scary. The only villain is a grumpy Mama Chonk who wants her blanket back.

## 5. Core loop

1. Leave your base on foot (warp pads unlock mid-game) into a zone you have the Zoomies for.
2. Find a nest. Grab its blanket burrito. The Mama Chonk wakes and rolls after you until you cross the boundary line into the base district.
3. Carry the burrito home. Other players can bat it out of your hands in the field.
4. At your base choose where to unwrap it: Vault incubator (safe, slow, two slots) or Showcase (fast, unlimited, stealable while unwrapping).
5. The reveal shows a Chonk with a tier, a size, and possibly a mutation, plus a bio card.
6. The Chonk earns cash per second. Spend cash on tools, shields, defenses, and base upgrades.
7. Train Zoomies on the hamster wheel to unlock the next zone.
8. Rebirth for a permanent multiplier, a new zone, better nest pools, and a feature unlock.

## 6. World and map

- **Base district** in the center: player houses arranged in a ring, each with a porch (Showcase), a basement (Vault), a hamster wheel, and later a warp pad.
- **Boundary line**: a visible painted curb around the base district. Guardians stop here. Crossing it with a burrito is the finish line of every heist and is celebrated with a sound and a small confetti pop.
- **Zones** radiate outward in a contiguous ring. Zone 1 borders the curb. Reaching Zone 3 on foot means running back through two zones carrying. Distance is the early difficulty.
- Launch: Zones 1 to 3. Zone 4 in the first month. Themes: Backyards (Zone 1), The Park (Zone 2), The Bakery District (Zone 3), The Mall (Zone 4), later Beach, Snowy Hills, Space Station.
- Each zone has a Zoomies requirement, roughly ten times the previous zone.
- Map is designed for the rolling chase: gentle slopes, wide lanes, a few obstacles to juke around. Mama Chonks are slowed by corners; players are not.

## 7. Acquisition (field only)

### Nests
- Each zone has 8 to 14 nests. A nest holds one blanket burrito and respawns on a timer of 3 to 6 minutes, longer for higher-value nests.
- Burrito glow and size hint at tier but hide the exact Chonk. Legendary and above purr audibly through the blanket.

### Guardians (Mama Chonks), three types per zone
- **Sleeper**: asleep next to the nest. Approach slowly (walk, not sprint) to grab without waking. Sprint or bump and she wakes. Teaches stealth.
- **Patroller**: waddles a fixed route around the nest. Time the window. Teaches timing.
- **Alarmer**: always awake, screams when you grab, and marks you with an arrow on every nearby player's screen for 20 seconds. Teaches risk assessment.
- All guardians chase until the boundary line, moving slightly faster than a rookie's base Zoomies in their own zone. Guardian speed is fixed per zone, so veterans outrun early guardians trivially. If caught, you drop the burrito at your feet and are knocked back; anyone can pick it up, including you.

### Rare Rush
- Every 5 minutes an Epic-tier burrito spawns at a marked spot in each zone, announced to players in that zone only. Small, frequent contest that keeps the field busy.

### The Big Chonk (daily-chance drop)
- Once per real day, each server has a chance (tuned, target around 60 percent) to trigger a Secret-tier drop.
- Trigger: the sky darkens, a growing shadow appears on the ground at a random field location, every screen reads **OH LAWD HE COMIN** with a 60-second countdown.
- A huge parachuting burrito lands. Carrying it slows the carrier to a waddle regardless of Zoomies. Hit the carrier and it drops for anyone. Nothing is destroyed.
- Whoever unwraps it at their base gets max Wanted for 10 minutes. The drop starts a siege, not an ending.
- Any player who has never owned a Secret gets an invisible 15 percent carry-speed bonus for the Big Chonk only.

### Hidden pity
- Each reveal below Legendary adds a small hidden bonus to the player's next Legendary-or-above odds. Resets on a Legendary. Never displayed.

## 8. Chonks

### Tiers (seven)
Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret. Base income roughly 5x per tier. Legendary and above trigger a 2-second server-wide camera cut to the owner's porch with the Chonk's name in giant letters.

### Launch roster (40)
| Tier | Count | Animals |
|---|---|---|
| Common | 10 | Cat, Hamster, Frog, Pigeon, Guinea Pig, Rabbit, Duck, Mouse, Chicken, Pug |
| Uncommon | 8 | Corgi, Seal, Penguin, Hedgehog, Sheep, Pig, Turtle, Owl |
| Rare | 7 | Capybara, Axolotl, Otter, Raccoon, Koala, Quokka, Red Panda |
| Epic | 6 | Panda, Walrus, Manatee, Sloth, Wombat, Highland Cow |
| Legendary | 4 | Polar Bear, Hippo, Elephant Seal, Bison |
| Mythic | 3 | Blue Whale, Moon Bear, Woolly Mammoth |
| Secret | 2 | The Absolute Unit (species unclear), STEVE (hippo) |

Secrets at launch come only from the Big Chonk and Global Events.

### Size scale (six)
A Fine Boi, He Chomnk, A Heckin' Chonker, HEFTYCHONK, MEGACHONKER, OH LAWD HE COMIN. Size multiplies income and unwrap time and scales the model. The top stamp prints in red with a shaking card.

### Mutations (one slot)
Golden, Cosmic, Rainbow, Snowy, Lava, Glitch, Candy. Skin plus multiplier from 1.5x to 10x. New mutation roughly monthly via Saturday drops.

### Traits (up to three)
Sleepy, Snacky, Zoomy, Loud, Shiny, plus event-only traits. Small stackable multipliers.

### Naming grammar
- Names are food or household words, or human office names. Beans, Loaf, Gravy, Gary, Kevin, Susan.
- Rarity adds titles: Sir, Lord, Baron, Her Majesty, His Roundness.
- Mutation prefixes the display name; size suffixes it: "Cosmic Beans the HEFTYCHONK".
- Escalation lines: the same animal recurs across tiers with an increasingly unhinged name (Steve → Big Steve → Steve, Enormous → STEVE; Gary → Sir Gary → Gary, Destroyer of Couches → Gary the Inevitable; Kevin → Kevin Prime → Kevin, Now With Legs; Beans → Cosmic Beans).
- Every Chonk has a one-sentence deadpan bio shown on the reveal card and in the index.
- Meme phrases are allowed. Real people's names and brand parodies are not.

### Idle behavior
Chonks on the porch nap, roll over, yawn, and occasionally fall off the porch and bounce back. Cheap animations that build attachment.

## 9. Zoomies (Speed)

- Second currency. Raised only on the hamster wheel at base: stand on it for passive gain, tap for a bonus. No cash from the wheel. No media on or near it.
- Exponential curve. Zone thresholds multiply by ten. Zone 1: 0. Zone 2: about 1,000. Zone 3: about 10,000. Zone 4: about 100,000. Tuned against the play log.
- Feedback: camera field of view widens, a blur trail appears, wind sound rises, a short screen kick on each milestone.
- Milestone broadcasts at 10K, 100K, 1M with names: Zoomin', Absolutely Zoomin', He Fast, OH LAWD HE FAST.
- Carrying reduces the carrier to a fraction of Zoomies by tier: Common 80 percent, Rare 60, Legendary 40, Secret waddle. A carrier is always catchable by an empty-handed player of similar Zoomies.
- Guardians scale with the zone, not the player. Veterans feel godlike in early zones; rookies see what is coming.

## 10. Base

- **Vault (basement)**: safe forever, online or offline. Normal income. Two incubator slots, slow unwrap. Where most Chonks live. Capacity grows with rebirth.
- **Showcase (porch)**: raidable. +50 percent income. Only Showcase Chonks count for leaderboards and broadcasts. Unlimited incubation, faster unwrap, stealable while unwrapping. Starts at 2 slots, grows to 8 by Legend stage.
- Moving Chonks between Vault and Showcase is free and instant while standing on your base. Not possible remotely.
- **Hamster wheel**: Zoomies training device.
- **Warp pad**: appears at Raider stage.
- Per-base visual budget: hard cap on active particle emitters and animated Chonks rendered at distance; distant porches show static low-poly stand-ins.

## 11. Theft rules

- **Field**: bat a carrier and the burrito drops for anyone, owner included.
- **Showcase**: grab an unshielded Chonk and carry it home under the same carry rules. The victim's porch lights flash red and their Alarm fires.
- **Nothing deleted**: if a victim leaves the server while their Chonk is being carried, it returns to the victim's inventory. If a carrier leaves, the item returns to its last owner.
- **Rookie shield**: until Showcase value crosses a threshold or 30 minutes of total play, players more than two rebirths above cannot hit you while carrying or rob your Showcase. You can still rob anyone. Displayed as a small halo so veterans know not to bother.
- **Dummy base**: an NPC house near spawn with a stealable Common on its porch and a tutorial prompt. Teaches theft risk-free at minute two.
- **Raid cooldown**: after a Showcase theft, two minutes of Showcase immunity. No chain robbing.

## 12. Grudge and Wanted

- **Grudge**: when robbed, the victim gets a tracker arrow to the thief for 10 minutes and double payout for stealing anything from that thief in the window. Tracker text: "Find the person who took Gary. Gary would want this."
- **Wanted**: every Showcase theft raises the thief's Wanted level, shown above their head, decaying over 10 minutes. Robbing a high-Wanted player pays a bonus scaled to their level. Levels: Suspicious, Rascal, Menace, Absolute Menace, HE COMIN FOR YOUR PORCH.
- Griefers become the server's most profitable target. Victims get a mission instead of a loss.

## 13. Protection, offense, and store

Rules: shields cannot be broken, only waited out. Shield cooldown equals duration, so no Showcase is protected more than half the time. Shields never stack. Everything is earnable with cash; Robux buys stacks, never strength.

**Showcase shields**
- Basic: 60 seconds, free, upgradable to 90. The panic button.
- Trip Shield: 3 minutes.
- Long Shield: 10 minutes.

**Away timer**
- Leaving base with a shield up starts a HUD countdown. At 15 seconds left the shield flashes visibly to everyone.
- Expiry while away makes the Showcase **Exposed**: the five nearest players get an arrow and thefts pay +25 percent for 60 seconds.
- Expiry while home announces nothing.
- **Return Beacon**: one-use instant teleport home. Cannot be used while carrying Legendary or above.

**Defenses (placeable, earnable)**
- Alarm: free. Sound plus arrow when someone enters your porch.
- Bear Trap: immobilizes a thief for 3 seconds. Visible.
- Guard Chonk: an NPC that slows any thief carrying inside your base. Three tiers.
- Decoy Chonk: looks Legendary from a distance, worthless. Stealing it gives the thief Wanted and a "Fooled" tag for a minute.

**Offense (earnable)**
- Bat: starter. Knocks a carrier.
- Speed Coil: short sprint boost, cooldown.
- Smoke Bomb: breaks line of sight and Alarm arrows for 5 seconds.
- Grapple: one quick pull toward a target, cooldown.
- Cloak: 8 seconds invisible, long cooldown, fails while carrying Legendary or above.

Never sold: Chonks, specific-Chonk multipliers, anything that beats a shield, body swap, lockpicks.

## 14. Progression

Features are rewards. A new player starts with legs, a bat, and a hamster wheel.

| Stage | Roughly | Gate | Unlocks |
|---|---|---|---|
| Rookie | 0 to 1 h | Zoomies and cash thresholds | Zone 1, second Vault incubator, Alarm, Bear Trap, Showcase with 2 slots |
| Runner | 1 to 6 h | Rebirth 1 | Zone 2, Speed Coil, Basic Shield to 90 s, Showcase 4 slots, mutation index |
| Raider | 6 to 25 h | Rebirth 2 plus cash purchase | Warp pad to Zone 1 only, Trip Shield, Guard Chonk 1, Grapple, Decoy |
| Veteran | 25 to 100 h | Rebirth 4, Zoomies 1M | Warp to Zone 2, Zone 3 access, Long Shield, Guard Chonk 2 and 3, Cloak, Return Beacon |
| Legend | 100 h plus | Rebirth 6 and beyond | Warp to all zones, Zone 4, prestige cosmetics, leaderboard titles |

- **Rebirth**: wipes Chonks and cash, keeps index, cosmetics, Zoomies, and unlocked features. Grants a permanent income multiplier, upgrades nest pools, unlocks the next feature on the ladder. First rebirth around hour two for an average player.
- **Warps**: unlock one zone at a time, each bought with cash on top of the rebirth gate. Disabled while carrying.
- **Collection index**: every Chonk by tier, size, mutation. Visible completion percentage. Bios readable here.
- **Leaderboards**: weekly reset. Showcase value and successful steals, per server and global. Rewards are titles and cosmetics only.
- **No hard caps**: every curve is exponential with soft diminishing returns.

## 15. Events and cadence

- **Rare Rush**: every 5 minutes per zone.
- **Global Event**: once daily at a fixed UTC time, 10 minutes of mutation rain (elevated mutation odds on all reveals) with a themed announcement.
- **Big Chonk**: daily chance, see section 7.
- **Saturday drop**: every week. Two to four new Chonks, sometimes a mutation or event theme. Announced in-game on Friday with a teaser silhouette.
- **Seasonal**: Pumpkin Chonk, Snow Chonk, Beach Chonk rotations with matching zone dressing.

## 16. Retention ladder and social

- **Minute 0 to 1**: spawn on your porch facing the hamster wheel and the curb. Zoomies climb immediately. No popups. A single arrow.
- **Minute 2**: first burrito from Zone 1, first reveal card, first steal on the dummy base.
- **First hour**: an unlock every few minutes (see Rookie stage).
- **Hour 2**: first rebirth and Zone 2, ahead of the documented Day 3 cliff.
- **Daily**: streak calendar with the Day 7 exclusive Chonk shown from Day 1. Daily Global Event.
- **Offline**: Vault income accrues for a capped 2 hours. "Your Vault is full" is a true reason to return.
- **Weekly**: Saturday drop, leaderboard reset Monday.
- **Social**: +10 percent income per friend on the server, capped at three. Referral link gives both sides a starter Uncommon.
- Targets: Day 1 above 35 percent, Day 7 above 18 percent (simulator "good" benchmarks). Stretch: 45 and 22.

## 17. Monetization

Sells: luck boosts (timed), permanent income pass, extra Vault and Showcase slots, shield and beacon stacks, cosmetics (porch skins, trails, hats for Chonks), private servers, occasional limited-time bundles.
Never sells: Chonks, power that beats a shield, specific-Chonk multipliers.
Everything paid is earnable slowly. Store copy is in the same comedic voice.

## 18. Comedy system

Where jokes fire, so every system has one:
- Reveal card: name, bio, size stamp.
- Server broadcast on Legendary and above: "SUSAN HAS ENTERED THE PORCH."
- Theft notification: "Greg has been stolen. Greg is not surprised."
- Grudge tracker copy references the stolen Chonk by name.
- Wanted level names, Zoomies milestone names, size stamps.
- Guardian wake-up: a single loud "MRRP" and a comically slow first roll before she accelerates.
- Store item descriptions.
- Loading tips are Chonk facts. "Kevin has never once flown. Refuses."
All strings live in one shared strings module for filtering, editing, and localization.

## 19. UI and UX principles

- Mobile-first. Big one-thumb buttons in the lower corners. Grab, Bat, Shield, Beacon as the only field buttons.
- Nothing on screen a new player does not need in minute one. HUD elements appear as features unlock.
- One consistent rounded visual language. Two accent colors. No unnecessary animation.
- Reveal card is the hero UI: full-screen, satisfying, screenshot-ready, dismissable in one tap.
- Every timer that matters (shield, away, Grudge, Wanted, Big Chonk) is a single readable bar.
- PC gets the same layout scaled with keyboard binds.

## 20. Technical architecture

- **Workflow**: Rojo syncs this repo into Studio. Code is written here. Studio is for map building, testing, and publishing.
- **Toolchain**: Rokit manages Rojo, Luau LSP, Selene, StyLua, Wally (packages). VS Code with Luau LSP extension and Rojo sourcemap.
- **Structure**:
  - `src/server/` — services: Data, Economy, Nests, Guardians, Carry, Theft, Shields, GrudgeWanted, Events, Rebirth, Leaderboards, Analytics.
  - `src/client/` — controllers: HUD, Reveal, Input (mobile and PC), Camera effects, Notifications, Audio.
  - `src/shared/` — Chonk catalog (data-only), strings module, config numbers, remotes definitions, types.
  - `assets/` — Blender sources and exported meshes, textures, audio, with a manifest mapping to Roblox asset IDs.
  - `docs/` — this spec, play logs, economy sheets.
- **Server authority**: all grabs, carries, drops, reveals, incomes, shield states, and purchases are computed on the server. Client sends intents only. Carry speed is enforced server-side; a client moving faster than allowed while carrying is snapped back.
- **Data**: ProfileStore or equivalent session-locked DataStore wrapper. Profile schema: cash, zoomies, rebirth, inventory of Chonks (id, tier, size, mutation, traits, location Vault or Showcase), items, unlocks, streak, index, stats, purchases. Versioned with migrations.
- **Reconciliation**: on join, base is rebuilt from profile. On leave, carried items resolve per section 11 before save.
- **Anti-cheat baseline**: server-side speed and position sanity checks, rate limits on remotes, no client-trusted values, honeypot remotes logged.
- **Performance**: streaming enabled, per-base visual budget, guardians as server-driven simple movers with client interpolation, target 60 fps on mid-range phones with 20 players.
- **Analytics**: Roblox funnel events for onboarding (spawn, first wheel, first grab, first crossing, first reveal, first steal, first rebirth), plus custom events for theft, Grudge revenge, shield use, and Big Chonk outcomes.

## 21. Art pipeline

- GPT Image 2 generates style sheets and concept turnarounds per Chonk, and base textures.
- Blender builds the modular kit: six body spheres by size, one face rig, a prop library (about 40 props). Chonks are body plus face plus one or two props. Exported as FBX with a single trim-sheet texture to keep draw calls low.
- Mutations are material swaps plus one particle preset. Sizes are uniform scale with a shadow blob.
- Roblox Studio imports meshes, assigns materials, and places them in the catalog via the manifest.
- Target: a new Chonk from concept to in-game in under two hours once the kit exists.

## 22. Constraints and compliance

- Kids and Select rating. No media feeds, no rewarded watching, no gambling framing beyond the genre-standard reveal.
- All display strings checked through the Roblox text filter once before launch.
- Original IP only. No real people, no brand parodies.
- Title: "Steal a Chonk". Developers to confirm no incumbent in the Roblox app search.
- Mobile-first performance budget is a launch gate, not a polish item.

## 23. Launch and iteration plan

1. **Vertical slice**: one zone, one guardian type, ten Chonks, Vault only, hamster wheel, carry and bat, reveal card. Two testers.
2. **Alpha**: Showcase, shields, Grudge and Wanted, rebirth, Zone 2, dummy base, 25 Chonks. Friends and family testing, funnel events live.
3. **Beta**: Zone 3, all guardian types, Big Chonk, Global Event, store, 40 Chonks, leaderboards. Public but unadvertised, watch Day 1 and Day 7.
4. **Launch**: TikTok clips of the Big Chonk and the rolling chase, referral links, small Roblox sponsored test. Saturday drop cadence starts.
5. **First major update**: collection sets with permanent bonuses and a Wanted Board.
6. **Week six**: trading with escrow.

Metrics read weekly: Day 1, Day 7, session length, funnel drop-off per onboarding step, theft-to-revenge rate, shield usage, Big Chonk participation, payer conversion.

## 24. Deferred

Collection sets and Wanted Board (update 1). Trading with escrow (week six). Zone 4 and beyond. Duo bonus if friend-bonus data supports it. Localization.

## 25. Economy numbers (initial proposal, to be tuned against the play log)

- Common income: 1 cash per second at A Fine Boi. Tier multiplier 5x per tier. Size multiplier 1, 1.5, 2.5, 4, 7, 12.
- Unwrap time: Common 20 s to Secret 20 min, times size factor 1 to 3.
- Zone thresholds: 0, 1K, 10K, 100K Zoomies. Zoomies gain on the wheel: exponential with rebirth, first 1K in about 45 minutes of mixed play.
- Shield prices: Basic free, Trip 5 minutes of average income, Long 20 minutes of average income.
- First rebirth cost: about 2 hours of average income. Rebirth multiplier +50 percent per rebirth, compounding.
- Hidden pity: +0.5 percent Legendary odds per non-Legendary reveal, cap +15 percent, reset on hit.
- Big Chonk daily trigger chance: 60 percent per server per day.
All numbers live in `src/shared/Config.luau` and are tuned, never hard-coded in systems.

## 26. Open questions

1. Confirm "Steal a Chonk" has no incumbent in the Roblox app.
2. Play log from both developers: one hour each in Steal an Egg and Steal a Brainrot, timestamps for tense, bored, cheated, thrilled moments. Used to tune sections 9, 14, and 25.
3. Do the base upgrades Walls, Alarms, Turrets exist in Steal an Egg, and what do they do?
4. Global Event fixed time: pick a UTC hour that suits the primary audience region.
