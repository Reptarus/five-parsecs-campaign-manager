# Bug Hunt parity audit — Sep 10 2026

Two axes, both walked:

- **Axis A — rules parity**: code vs the Compendium Bug Hunt chapter, printed **pp.161-223**.
- **Axis B — codebase parity**: Bug Hunt vs the core/Compendium systems it shares or duplicates.

Walked by **PAGE**, not by subsystem. Book text extracted with PyPDF2 (project rule), Compendium
offset **−1** (PyPDF2 index 22 → printed 21), verified on three pages by reading the page tail.

**Scope note:** printed **pp.215-223** (Galactic Timeline, Bug Hunt Index) are **excluded with
reason** — pure setting fiction, no dice, no tables, no mechanics. Recorded rather than skipped,
per *absence of code is only a finding once you have read the page*.

---

## ⚠ Why this audit exists

`docs/RULES_WIRING_AUDIT_2026-08.md:3` — *"Eight parallel auditors, one per subsystem… **Bug Hunt,
Planetfall and Tactics were out of scope by request.**"*

So the standing everyone reads as the rules ground truth — *0 open / 136 fixed / THE LEDGER IS
CLOSED* — **is a statement about Standard 5PFH only**. Bug Hunt had never been audited.

**The one document that claimed otherwise is a false green.** `docs/QA_RULES_ACCURACY_AUDIT.md:1238`
carries §C4 "Bug Hunt (Compendium)", rows **C4-001 … C4-019, all marked VERIFIED (2026-03-30)**. But:

- **C4-001 cites `src/core/systems/BugHuntEnemyGenerator.gd` — a file that does not exist** [[missing]],
  and line 34 of that doc marks it "OK".
- C4-019 asserts *"ContactMarkerPanel added"* — deleted in `5125a0e4`, and CLAUDE.md already records it.
- Line counts are 15-30% wrong (`BugHuntCampaignCore` claimed 476/491; actual 559).

That is the inverse of the trap this project already records. Not a red harness hiding a real bug —
**a green audit row that measured nothing.** §C4 checked extraction and never checked delivery.

Bug Hunt is a **paid SKU** (`src/core/store/StoreManager.gd:46`), so this is rules accuracy in
content people buy.

---

## THE HEADLINE

**The data is nearly perfect. The delivery is broken almost everywhere.**

Verified byte-exact against the book, value by value:

| Table | Rows checked | Result |
|---|---|---|
| Origin / Basic Training / Service History (pp.171-172) | 30 | **0 mismatches** — every D100 range, stat bonus, advantage, combat-op flag |
| Weapons (p.179) | 15 rows × 4 fields | **0 mismatches** in 60/60 fields |
| Enemy table (pp.194-195) | 16 | **0 mismatches** — range, Numbers, Speed, CS, Toughness, Damage, special rule |
| Enemy Variants (p.196) | 6 | exact |
| Pack Leaders (p.197) | 6 | exact (omits only "placed furthest from troopers") |
| Support options (pp.188-189) | 12 | exact — target numbers and full stat lines |
| Special Assignments (p.183) | 12 | exact — targets, compound requirements, every "if lower than N" cap |
| Movie Magic (p.181) | 10 | exact, clause for clause |
| Casualty / Muster-out / XP awards / Advance costs (pp.202-204) | all | exact |
| Operational Progress + Military Life (pp.205-206) | 11 + 20 | exact |

**A value-diff audit would have returned almost entirely clean, and would have been worth nothing.**
That is how §C4 scored 19/19. It is the same signature CLAUDE.md records from the creation-wizard
audit: *"The creation tables were byte-correct against the book; the **wiring** was where it broke."*

### One root cause dominates: the producer/consumer key mismatch

Twelve independent instances. Each has a live reader **or** a live writer, never both — and
`.get(key, default)` on a missing key is a **silent default, never a fault**, so nothing errors,
nothing logs, and no test that builds its own fixture can see it.

| Consumer reads | Producer writes | Consequence |
|---|---|---|
| `cumulative_modifier` | *(nothing)* | **no reachable win condition and no reachable disaster condition** |
| `description` | `effect` | Operational Progress effect text never displayed |
| `campaign_escalation` | `campaign_escalation_option` | **Priority pinned to a hardcoded 3 for the whole campaign** |
| `special_rules` | `special_rule` | every alien's defining rule and its Damage invisible in the browser |
| `objective` | `objectives` | the battle's objective is always `{}` |
| `contact_markers.aggression` | `movement.aggression_die` | Aggression/Chance dice always `{}` |
| `base_count` | *(nothing)* | **+2 phantom spawn points**; Spawn Rating 0 can never disable the rule |
| `"type"` | `"campaign_type"` | save-type detection dead — **also breaks Tactics and Planetfall** |
| *(nothing)* | `extra_contact_bonus` | entrenchment never applies |
| *(nothing)* | `bonus_xp` | "School of hard knocks" XP never granted |
| *(nothing)* | `advanced_care` | the p.203 Reputation-for-Sick-Bay rule is absent |
| *(nothing)* | `missions_in_current_operation`, `extra_support_rolls` | declared, serialized, permanently inert |

**Why 5PFH does not accumulate these:** `src/core/battle/BattleResultNormalizer.gd` is a chokepoint
every 5PFH battle path must cross, forcing producer and consumer onto one shape. **Bug Hunt has no
chokepoint** — it was built panel-first, so the two halves were free to drift apart in silence.

---

## LEDGER

`| Domain | Rule | Fix size | Player-visible effect | Status |`

Buckets: **CONTRADICTS · FABRICATED · WRONG-VALUE · NEVER-FIRES · MISSING · DRIFT · CONFIRMED-OK**.

---

> ⚠ **Citations into `src/core/battle/BattleCalculations.gd` are by SYMBOL, not line.**
> That file was being rewritten *while this audit ran* — observed at
> 2375 → 1717 → 1520 → 1896 → 1797 → 1842 lines within minutes, with no local edit.
> Line numbers taken during that window are wrong; the symbol names are stable. Re-derive
> line numbers with `grep -n` once `git status` on that file is clean.
>
> ⚠ **This block originally blamed Synology Drive sync. That was wrong, and the correction
> is kept rather than quietly edited, because the wrong answer was the plausible one.**
> The cause was a **second Claude Code instance** running a housekeeping task on the same
> repository. A resident `cloud-drive-daemon.exe` is not evidence it did anything, and a
> sync daemon and a concurrent agent produce an identical symptom. Three things
> distinguish them: two recent `.jsonl` transcripts in `~/.claude/projects/<slug>/`
> (measured 16 seconds apart); a **coherent** diff rather than arbitrary truncation; and
> **page-cited** content — the same instance added Core Rules p.151 verbatim quotes to
> `data/black_zone_jobs.json`, and no filesystem writes a page citation.
>
> **The audit is unaffected.** `git status --porcelain | grep -i bug_hunt` returns only this
> audit's own untracked files — no Bug Hunt source or data file was touched by that instance —
> and `BattleCalculations.gd` is the sole overlapping file, already cited by symbol. All six
> cited symbols were re-verified present after its edits.

## ⛔ CONTRADICTS (15) — the app shows a 5PFH rule that is WRONG for Bug Hunt

**This is the most dangerous bucket in the audit.** Dead code is silent; a player never learns the
pack-leader table exists. **Wrong instruction is confidently followed** — and it carries a page cite,
so it looks authoritative.

**The Cheat Sheet is not mode-aware in any way.** A case-insensitive grep for `bug_hunt` or
`battle_mode` over `src/ui/components/battle/CheatSheetPanel.gd` and
`src/ui/components/battle/CheatSheetSections.gd` returns **zero hits**. `_build_sections_data()`
builds the same six 5PFH Core-Rules sections unconditionally, and `TacticalBattleUI` mounts the panel
in the Reference tab with no gate. A Bug Hunt battle definitely reaches it:
`src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd:487` writes `bug_hunt_battle_context` and
routes to `tactical_battle`, which picks it up and builds the full 5PFH toolset.

**Nothing in the codebase cites Compendium pp.174-181.** The Bug Hunt "Main Rules" chapter has no
rules surface at all. The app's only mid-battle reference for a Bug Hunt fight is 5PFH's.

| Domain | Rule | Fix size | Player-visible effect | Status |
|---|---|---|---|---|
| battle-resolution | **Resolving Hits — p.178**: 1D6+Damage **EXCEEDS** Toughness = casualty; **EQUALS** Toughness = knocked back and **Wounded** | small | `src/ui/components/battle/HitResolutionSheet.gd:105` states *"equals or exceeds the Toughness… becomes a casualty"*. Off-by-one at exactly the Toughness value: every figure that should survive Wounded is killed. Repeated at `CheatSheetPanel.gd:422` | OPEN |
| battle-resolution | **Saving throws — p.178**: a successful save = **not Stunned**, knocked back 1" | small | `HitResolutionSheet.gd:256` says the save *"replaces the casualty with a Stun — it does not remove the Stun as well"* and prints *"The figure is still Stunned (p.46)"*. The exact opposite of the Bug Hunt rule, in the live mid-battle hit sheet | OPEN |
| battle-resolution | **Wounded — p.178**: -1 to Brawling, cannot Dash, rest of mission; a second Wound = casualty | small | `CheatSheetPanel.gd:495` prints a 5PFH *campaign* rule under the same word: *"Wounded (crew only) — After battle, roll on the Injury Table (p.122)"* | OPEN |
| battle-resolution | **Stunned enemies — p.178**: must remain in place, unable to act. p.199: enemies carry **no ranged weapons** | small | `CheatSheetPanel.gd:490` prints *"Stunned enemies (p.40) Always fire at the nearest visible target"* — in a game whose enemies have no ranged weapons at all | OPEN |
| battle-resolution | **Stun in a Brawl — p.178**: the Stunned figure fights at **-1**, and may remove 1 marker if it survives | small | `CheatSheetPanel.gd:487` inverts both sign and beneficiary: *"all its Stun markers are removed, but the attacker gets +1 per marker removed"* | OPEN |
| battle-resolution | **Brawl natural 1 — p.178**: if an **enemy** rolls a natural 1 it takes a Hit, and if it survives it immediately rolls again | small | `CheatSheetPanel.gd:412` prints the 5PFH rule instead: *"Natural 1: opponent inflicts an extra Hit on you"* | OPEN |
| battle-resolution | **Brawl modifiers — p.177**: enemies roll 1D6+Combat Skill **with no other modifiers** | medium | `CheatSheetPanel.gd:407` shows natural-6 extra hits, outnumbering +1 and +1 per Stun marker — none of which are Bug Hunt rules. `src/ui/components/battle/BrawlResolverPanel.gd:41` additionally offers the player defender weapon / species / stun / outnumber inputs the book forbids | OPEN |
| battle-resolution | **Two opponents — p.180**: pick one at random, then fight the second immediately at **+1 Combat Skill** | small | The app shows 5PFH outnumbering, which grants +1 to the **other** side — a different rule benefiting the opposite party | OPEN |
| battle-resolution | **No morale — p.200**: *"There is no morale system in Bug Hunt: The enemies don't stop coming until you kill them all"* | small | The full Morale Rules section (Core Rules p.114) and the Bail status entry render in **every** Bug Hunt battle, `CheatSheetPanel.gd:455`. `TacticalBattleUI` suppresses only the morale *tracker* | OPEN |
| battle-setup | **Battle round — p.198**: **four** phases — Quick Action, Enemy Action, Slow Action, **Spawn** | medium | `src/ui/components/battle/BattleRoundTracker.gd:16` is a hard 5-value enum with no Spawn phase and no mode branch, ending in *"End Phase — Morale checks, condition updates, battle events"*. Restated to the player as a 5-step sequence at `CheatSheetPanel.gd:359` | OPEN |
| battle-resolution | **Enemy AI — p.200**: always closes to Brawl, never slows to take cover, no ranged attacks | small | `CheatSheetPanel.gd:301` shows the 5PFH AI codes — *"Cautious — stay in cover, fire at closest"*, Defensive, Tactical — three cover-seeking, ranged-firing behaviours Bug Hunt explicitly rules out | OPEN |
| equipment | **Weapons — p.179**: Bug Hunt has its own 15-weapon table | medium | `CheatSheetPanel.gd:515` prints a 36-row **5PFH** table with conflicting stats for the same names: Hand cannon damage **2** (Bug Hunt: 1), Power claw damage **3** + Clumsy (Bug Hunt: 1, Melee only), Hyper blaster with no traits (Bug Hunt: Overheat). The in-battle weapon display loads `data/equipment_database.json` — the 5PFH list | OPEN |
| battle-resolution | **To Hit — p.177**: exactly three rows — 3+ within 6" open / 5+ in range open / 6+ in cover | small | `CheatSheetPanel.gd:377` shows the three correct thresholds **plus** a fourth 5PFH row ("within 6" and in Cover = 5+") and three modifiers Bug Hunt does not have (Heavy, Snap shot, Bipod) | OPEN |
| battle-resolution | **Snap Fire — pp.198-199**: no to-hit penalty is stated | small | `src/ui/components/battle/CharacterQuickRollPanel.gd:16` applies an unconditional **-1 to hit** citing Core Rules p.113 | OPEN |
| battle-resolution | **Firing near friendlies — p.180**: *"you may NOT fire"* if a **trooper** partly obscures the line | small | `CheatSheetPanel.gd:398` states the 5PFH version applying to both sides, plus a **5+ Area-weapon risk roll** that is not a Bug Hunt rule at all | OPEN |
| equipment | **Overheat — p.179**: the weapon malfunctions if *"all three firing dice score the same number"*; no chance at all if fewer than three dice are rolled | small | `src/core/battle/BattleCalculations.gd` implements its `"hot", "overheat"` case as `"hot", "overheat"` as a **different book's rule** — its own comment reads *"Compendium p.91: If fired in previous round, 1 less Shot (non-cumulative)"*. The Hyper Blaster in `data/bug_hunt/bug_hunt_weapons.json` carries the `overheat` trait, so a Bug Hunt weapon would resolve under the Game Options rule instead of its own. ⚠ Same shape as the `EnemyAI.json` provenance defect: **the code is faithful — to the wrong chapter** | OPEN |
| equipment | **Area — p.179**: resolve Shots at the target point, then roll 1D6 for **every figure within 2"**, hit on **4+** | small | `src/core/battle/BattleCalculations.gd` implements the 5PFH version and its comment explicitly **rejects** the Bug Hunt one as belonging to "the alternative weapon set". Correct for 5PFH; wrong for the mode whose weapons table lists Incinerator and Frag grenade as Area | OPEN |
| equipment | **Aimed — p.179** (+1 to hit if the firer did not move) and **Launcher — p.179** | small | Both traits are present and correct in `data/bug_hunt/bug_hunt_weapons.json` and **neither name appears in the trait resolver's `match` block** — the 5PFH `snap_shot` is there instead. The Sniper Rifle's Aimed bonus and the Mounted Launcher's grenade rule can never resolve | OPEN |

---

## 🔴 FABRICATED (5) — the app invents mechanics

| Domain | Rule | Fix size | Player-visible effect | Status |
|---|---|---|---|---|
| post-battle | Casualties must come from the battle | small | **Casualties are invented from thin air.** `casualty_ids` is always empty (no producer — see NEVER-FIRES), so the fallback branch at `src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd:174` — commented *"should not happen with wiring"* — executes on **every** battle, rolling `randi() % 5 == 0` per active character | OPEN |
| post-battle | **Court Martial — p.201**: only *"if you failed to complete any Objectives at all"* | small | **The player pays 3 real Reputation to avert a consequence that cannot occur.** The card fires after **every** mission including total victories, because `objectives_completed` is always 0. On GUILTY the panel prints *"Squad leader removed from campaign"*, never appends to `mustered_out`, and never calls `remove_main_character` — `BugHuntPostBattlePanel.gd:642` is literally the comment `# Remove leader from mustered_out if we added them`. The 3-Reputation buyout **does** really call `spend_reputation(3)` | OPEN |
| battle-resolution | No "natural 6 = casualty" rule exists in Bug Hunt | one-line | `CheatSheetPanel.gd:422` prints *"Result >= Toughness, **or a natural 6**: Casualty"* | OPEN |
| battle-setup | **Spawn Points — p.199**: the Spawn Rating **is** the number; *"If this rating is 0, this rule is not used"* | one-line | `src/core/battle/BugHuntBattleSetup.gd:177` reads `spawn_config.get("base_count", 2)` against a key that does not exist in the JSON, giving `total = 2 + spawn_rating`. Two spawn points the book does not grant, and rating 0 can never disable the rule | OPEN |
| battle-resolution | No Area-weapon friendly-fire risk roll exists in Bug Hunt | one-line | `CheatSheetPanel.gd:398` adds a 5+ risk roll | OPEN |

---

## 🟠 WRONG-VALUE (15) — a live path produces the wrong number

> The 15th (the default difficulty matching no enemy modifier) was found by the headless run and
> is recorded in the HEADLESS VERIFICATION section below, with the measurement that produced it.

| Domain | Rule | Fix size | Player-visible effect | Status |
|---|---|---|---|---|
| mission-generation | **Campaign Escalation — p.187**: Priority sequence **1-1-2-2-3-4-5-6** | one-line | `BugHuntMissionPanel.gd:335` reads `_missions_data.get("campaign_escalation", {})`; the JSON key is **`campaign_escalation_option`**. Empty dict → the index guard fails → the function returns a **hardcoded 3**. With the escalation toggle on, Priority is exactly 3 for the entire campaign | OPEN |
| mission-generation | **Escalation Spawn Ratings — p.187**: **0-0-1-1-2-3-3-3** | small | `spawn_sequence` has zero consumers; Spawn Rating is always recomputed as Priority−1, i.e. permanently 2 | OPEN |
| post-battle | **Completed Missions — p.203**: +1 *"if the character took the field"*; *"Characters in Sick Bay do not update their tally"* | one-line | **Incremented twice per mission** — `BugHuntPostBattlePanel.gd:307` and `src/core/campaign/BugHuntPhaseManager.gd:179`, both writing the same dictionaries in `campaign.main_characters`. Worse, the two sites use **different eligibility**: the panel correctly skips Sick Bay, the phase manager has no sick-bay test at all. Every veteran's service record inflates at 2× | OPEN |
| post-battle | **Mustering Out — p.203**: threshold keyed on the character's Completed Missions | one-line | `BugHuntPostBattlePanel.gd:462` reads `completed_missions_count + 1` on a tally step 2 has **already** incremented — a character with 8 real missions is checked as 10 | OPEN |
| post-battle | **Mustering Out — p.203**: 15 missions = **Automatic** | small | `BugHuntPostBattlePanel.gd:489` matches the scalar with `==` only, so at **16+ missions no row matches**, the threshold falls to 0 and the check is skipped entirely. Veterans become immortal exactly when the book says they must leave | OPEN |
| post-battle | **Mustering Out — p.203**: check only characters that **increased** their Completed Missions | small | `BugHuntPostBattlePanel.gd:459` loops all main characters, so a trooper who spent the turn in Sick Bay can be discharged | OPEN |
| post-battle | **Sick Bay — p.202**: a wound lasts the rolled number of campaign turns | one-line | `BugHuntPhaseManager.gd:183` adds this turn's entries and `:206` ticks them down **in the same call**. Every wound is one turn shorter than rolled; a "Minor injuries — 1 turn" casualty is out before the next turn begins | OPEN |
| battle-setup | **Reaction dice — p.198**: roll D6 equal to (main characters **+ combat teams**) | medium | `src/ui/screens/battle/TacticalBattleUI.gd:6434` rolls one die per living crew unit, and the Bug Hunt crew is main characters **+ every individual grunt**. A 3-MC + 4-grunt squad rolls **7** dice instead of the book's **4**. `BugHuntCampaignCore.combat_teams` is read by nothing in the battle path | OPEN |
| mission-generation | **Loadout — p.187**: **one** main character may swap for a Hand Cannon | one-line | `BugHuntMissionPanel.gd:314` — `hand_cannon_assigned` is a local **captured by value** into each per-character lambda, so Godot 4 hands every lambda its own `false`. The exclusivity check never triggers; every main character can take one | OPEN |
| battle-resolution | **Brawling — p.177**: +2 Melee **or** +1 Pistol — *"Only one weapon bonus can be counted"* | one-line | The shared trait resolver adds both to the same accumulator: in `src/core/battle/BattleCalculations.gd` the `"melee"` case does `effects["brawl_modifier"] += 2` and the `"pistol"` case does `+= 1`, with no clamp between them, so a Bug Hunt trooper carrying a Boarding Sword and a Service Pistol reaches **+3**. Both sites cite Core Rules p.51, i.e. this is the 5PFH resolver being used unmodified for a mode whose book caps the bonus | OPEN |
| post-battle | **Advancement — p.204**: costs 6 or 8 XP per stat | small | `BugHuntPostBattlePanel.gd:383` builds buttons once from a snapshot and never re-checks affordability. A second purchase in the same pass drives XP negative — two 8-XP advances can be bought with 9 XP. The max-value caps do hold | OPEN |
| post-battle | **R&R — p.206**: entitled after **4 missions in the current operation** | small | `BugHuntPostBattlePanel.gd:586` uses `campaign_turn % 4`. `BugHuntCampaignCore.missions_in_current_operation` is declared and serialized with **zero writers and zero readers** — it diverges the moment a turn has no battle | OPEN |
| compendium-ui | Bug Hunt enemies have **no** Panic, AI type or ranged weapons (p.169, pp.194-195) | small | `src/ui/screens/compendium/CompendiumCategoryView.gd:726` routes Bug Hunt enemies through the 5PFH detail builder: it prints three empty *"Panic: — AI: — Weapons: —"* fields, and **drops the Damage value and the alien's `special_rule`** because it reads the plural key `special_rules` | OPEN |
| mission-generation | **Difficulty — p.194**: Numbers −1 on "I'm too pretty", +1 on Mega-violence / Living Nightmare | small | `data/bug_hunt/bug_hunt_enemies.json` `difficulty_modifiers` uses the id `standard`; `hey_not_too_crazy` and `mess_me_up` are absent, so the ids can never match `BugHuntCampaignCore.difficulty`. Moot today — the block has no consumer | OPEN |

---

## ⚫ NEVER-FIRES — correct code and data, no live path (the largest bucket)

> Two further rows — `set_combat_teams()` and `BugHuntCampaignCore.validate()`, both zero-caller —
> were found by the headless run and are recorded in the HEADLESS VERIFICATION section below.

**The entire Bug Hunt battle payload is inert.** `BugHuntBattleSetup.generate_battle_context()`
returns 15 keys; **14 have zero consumers repo-wide**. Only `battle_mode` is read, and it does
exactly three things: writes a log line, hides the morale tracker, hides Stars of the Story.

The log line is itself false — `TacticalBattleUI` prints *"Bug Hunt mode — morale hidden, **contact
markers active**"*, and there is no contact-marker system anywhere in `src/`.

| Domain | Chapter | Rows dead | Note |
|---|---|---|---|
| mission-generation | Enemy table pp.194-195 | 16 | Compendium **browser only** (`src/core/compendium/CompendiumDataProvider.gd:227`). No generator rolls it; `d100_range` has zero readers |
| mission-generation | Enemy Variants p.196 | 6 | `data/bug_hunt/bug_hunt_alien_subtypes.json` — **zero references repo-wide** |
| mission-generation | Pack Leaders p.197 | 6 | `data/bug_hunt/bug_hunt_alien_leaders.json` — **zero references repo-wide** |
| mission-generation | Contact markers pp.192-193 | ~14 | movement, Aggression/Chance dice, 6"/3" detection, the D6 Contact table, "Beep Sir?" |
| mission-generation | Tactical Locations p.191 | 10 | The D6 **is** rolled at `BugHuntBattleSetup.gd:127`; the result is never consumed |
| mission-generation | Signals p.208 | 6 | `BugHuntBattleSetup.gd:157` fetches `signal_table` into a local and **never uses it** — every Signal is emitted with `"result": {}`. Contrast the Tactical Locations function 30 lines above, which resolves its row correctly |
| battle-setup | Spawn Points p.199 | 5 | Including Closing Down — `grep closing_down src/` returns 0 hits |
| battle-setup | Evac p.201 | 6 | The whole `evac` block is unread: Round 5+, 2D6+objectives, Savvy +1, 10+ success, 3-round loiter, Priority +1 per arrival, drop ship's two LMGs at +1 Combat Skill |
| post-battle | Operational Progress p.205 | 2 sentinels | `below_1` and `above_100` are **unreachable** — see below |
| post-battle | Reputation p.203 | 2 | `objectives_completed` is always 0, so neither the automatic +1 nor the per-objective 5-6 rolls ever fire |
| post-battle | Lost Marine column p.202 | 1 | No producer. Latent typed-assign crash at `BugHuntPostBattlePanel.gd:682` on the null range if it ever were reached |
| campaign-turn | Movie Magic p.181 | 10 | Names listed on the dashboard; the `effect` and `timing` strings are never rendered, and none of the ten is offered **during** a battle |
| equipment | Weapons p.179 | 10 of 15 | Only 5 reach a screen, as hardcoded literals. The `weapon_traits` dict is never rendered anywhere |
| mission-generation | Setup steps p.184 | 9 | `setup_steps` has zero consumers — the player is never shown the 9-step procedure |
| mission-generation | Deployment p.190 | 2 | Random edge / within 3" / Objectives ≥12" from deployment — all unread |
| mission-generation | Vital ×2 / Critical ×3 p.185 | 2 | Correctly detected and displayed pre-battle ("counts as 3!"), never scored |
| battle-setup | 4+ Signals ⇒ −1 Objective p.201 | 1 | A pre-battle warning label, no enforcement |
| battle-setup | `no_morale` flag | 1 | Written at `BugHuntBattleSetup.gd:56`, read by nobody |

### ⭐ The single worst NEVER-FIRES: the campaign cannot be won

**Compendium p.205:** *"All results from this table are cumulative until this particular operation
is over."* The ±5 modifiers **are** the mechanic.

`BugHuntPostBattlePanel.gd:549` sets the modifier from `result.get("cumulative_modifier", 0)` — and
**no row in `data/bug_hunt/bug_hunt_post_battle.json` has a `cumulative_modifier` key**; every entry
carries exactly `d100_range`, `name`, `effect`. So:

- `_results.op_progress_modifier` is permanently **0**
- `BugHuntPhaseManager.gd:202` does `campaign.operational_progress_modifier += 0` forever
- the roll at `BugHuntPostBattlePanel.gd:532` is `(randi() % 100) + 1 + 0` → always **1..100**

Both out-of-band rows are therefore unreachable:

- `"below_1"` — *"Operation is a disaster"*
- `"above_100"` — ***"Time to hold a parade! You've won! The planet is secure."***

**A Bug Hunt campaign has no reachable win condition and no reachable disaster condition.**

The irony is exact: `BugHuntPostBattlePanel.gd:688` — `_find_in_op_progress()` — exists **solely** to
handle those two string sentinels, comment and all, and is dead code. Every other part of the
plumbing is correct: the modifier is exported, serialized, restored, and fed back into the roll.
It carries zero.

**A second dead key in the same function**: `BugHuntPostBattlePanel.gd:541` reads
`result.get("description", "")` while every row stores its text under **`effect`** — so the player
never sees any Operational Progress effect text either.

---

## ⚪ MISSING — no code at all

| Domain | Rule | Fix size | Player-visible effect | Status |
|---|---|---|---|---|
| co-op | **Co-op Campaigns pp.209-211 — entirely absent** | large | No data file, no code: the sector map (3-5 sectors per player), the D100 Factor table (7 rows), the D100 Enemy Moves table (10 rows), resource stashes, the shared Support pool | OPEN |
| battle-resolution | **Rapid Fire — p.177**: every natural 6 grants an extra shot, at the same target or another figure within 2" | medium | `src/core/battle/BattleCalculations.gd` records that `get_rapid_fire_shots()` was **deleted 2026-09-10** (zero callers), and its trait-resolver comment states `"rapid_fire"` appears *"ONLY in the Compendium's Game Options alternative weapon set"* and must not attach to Core Rules weapons. Correct for 5PFH; **but it is a Core Bug Hunt rule (p.177)**, and a Bug Hunt player is never told natural 6s chain | OPEN |
| battle-resolution | **Malfunction — p.177**: two or more natural 1s in a round disables the weapon; repair = a Combat Action, 1D6+Savvy 7+ | medium | No trace. The word "Malfunction" in `src/` refers only to the Core Rules p.127 *campaign event* | OPEN |
| battle-resolution | **The Wounded band — p.178** | medium | The outcome enum in `HitResolutionSheet.gd:33` is only `"down"` / `"stun"`. The Wounded state does not exist in battle | OPEN |
| post-battle | **Military Life effects — p.206**, all 20 rows | large | Text only. `_results.military_life_event` is set and never read; `BugHuntCampaignCore.military_life_modifiers` is serialized with zero writers and zero readers. The four rows that feed Special Assignments (+2, no-assignment, bonus roll, cash-in-a-favor) have no reader either — `SpecialAssignmentsPanel` rolls a bare 2D6 with no modifier term |  OPEN |
| post-battle | **R&R effects — p.206** | medium | No sick-bay reduction, no additional Military Life roll, no "taken" flag, no 1-Reputation early option | OPEN |
| post-battle | **Advanced care — p.203**: 1 Reputation = −1 Sick Bay turn, once per character per turn | small | `advanced_care` has zero readers repo-wide | OPEN |
| post-battle | **Death — p.202**: rows 1-5 and 6-15 are dead or removed from the campaign | medium | `is_dead` is in the data; the panel prints "KILLED IN ACTION" and the character **stays on the roster, fully alive** | OPEN |
| post-battle | **Replacements — p.202** and **retire an injured trooper — p.203** | medium | No replacement generation on the post-battle path, no retire control | OPEN |
| post-battle | **MVP +1 XP — p.204** | small | Printed as a sentence; no control, no XP | OPEN |
| mission-generation | **Reputation levers — p.187**: spend up to 2 Rep to shift Priority; 1 Rep for +1 Support | medium | Both are advisory labels. `spend_reputation()` exists and is never called from the mission panel | OPEN |
| character-creation | **Squad size — p.170**: *"four or even five"* main characters | small | `src/core/character/BugHuntCharacterGeneration.gd:153` hard-caps at 4 and `src/ui/screens/bug_hunt/panels/BugHuntSquadPanel.gd:69` renders 4 name fields, so the core's own 5-cap check at `src/game/campaign/BugHuntCampaignCore.gd:281` is a **permanently-false branch** | OPEN |
| battle-resolution | Movement and terrain — pp.174-176, p.200 | large | LoS 3" rules, cover definition, Dash 3" for enemies, enemy immunity to difficult terrain, drop/leap distances, "enemies may move through each other", enemy activation order, path-length targeting — none delivered. The terrain data in `data/RulesReference/TerrainTables.json` is correct and reachable only through a dead path | OPEN |

---

## 🔵 DRIFT — Bug Hunt vs the core it shares (axis B)

| Finding | Evidence |
|---|---|
| **Eight incompatible ways to ask "which mode is this?"** — the `campaign_type` field; a save read via `SaveFileWriter`; a save read via **raw `FileAccess`**; a bool off `mission_data["battle_mode"]`; a non-empty `_battle_mode_id`; **a substring of a temp-data key name**; duck-typing on a 5PFH-only field; duck-typing on a BH-only field | across `GameState.gd`, `MainMenu.gd`, `TacticalBattleUI.gd`, `CampaignScreenBase.gd` |
| **`get_campaign_info()` emits `campaign_type`; four consumers read `type`** and silently get `""`. Breaks **Tactics and Planetfall** too. The producer's own comment says it exists *"so the two cannot disagree"* | producer `src/core/state/GameState.gd:1354`; consumers `src/ui/screens/bug_hunt/BugHuntDashboard.gd:249`, `src/ui/screens/mainmenu/MainMenu.gd:579` |
| `MainMenu._find_bug_hunt_saves` reads saves with **raw `FileAccess`** — the exact anti-pattern `GameState.gd:1332` documents as campaign-destroying (a truncated primary with a good `.bak` makes the campaign vanish from the menu) | `src/ui/screens/mainmenu/MainMenu.gd:977` |
| **14 core systems have no Bug Hunt reference at all**: `TurnPhaseChecklist`, `KeyboardAvoidance`, `SettingsManager`, `DiceManager`, `EnemyGenerator`, `BattleResolverRouter`, `BattleResultNormalizer`, `BattleSetupRules`, `FPCM_BattlefieldGenerator`, `SalvageLedger`, `EquipmentTransferService`, `CharacterAdvancementService`, `PostBattlePhase` and its 11 processors | grep across all BH files |
| **`DiceManager` bypassed 37×** (raw `randi()`), so no Bug Hunt roll enters the dice feed and **no Bug Hunt roll can be forced by QA tooling** — including the enlistment roll, in a file that routes the Planetfall roll through DiceManager 800 lines later | `src/core/character/CharacterTransferService.gd:98` vs `:894` |
| `BugHuntPhaseManager` does an unguarded `as Array` on `casualties` — the silent abort `BattleResultNormalizer.casualty_count()` exists to prevent, and whose docblock **names Bug Hunt** as a source of the int shape. Kills the Mission-phase journal entry. ⓘ **Scope, measured 2026-09-19**: on HEAD this can only bite on the FALLBACK path, because `_resume_after_battle` (`BugHuntTurnController.gd:404`) jumps straight to POST_BATTLE and **never completes MISSION at all** — see the turn-completion finding below. Fixing the completion without fixing the cast turns a latent abort into a live one | `src/core/campaign/BugHuntPhaseManager.gd:243`, `:247` vs `src/core/battle/BattleResultNormalizer.gd:241` |
| Bug Hunt "Enlist" never calls `remove_character_from_save()` — leaving open the pull-import duplication hole Planetfall and Tactics both closed | `src/ui/screens/bug_hunt/BugHuntDashboard.gd:254` vs `src/ui/screens/planetfall/PlanetfallDashboard.gd:81` |
| `apply_transfer_rewards()` **reports rewards it did not grant** — the patron summary line sits outside the `"patrons" in campaign` guard, and it is called for every mode | `src/core/character/CharacterTransferService.gd:751`, called from `src/ui/screens/campaign/CampaignScreenBase.gd:267` |
| `BugHuntTurnController`, `BugHuntCreationUI` and **all 8 panels extend bare `Control`** ⇒ no touch-scroll sweep and no settings-overlay band, while `PlanetfallTurnController` extends the shared base. Direct sibling-gamemode drift. ⚠ **CORRECTED 2026-09-19: this row also said "no responsive wiring", and that is WRONG.** `ResponsiveManager` is referenced in **10 Bug Hunt files / 13 call sites**, so the mode does adapt to size and orientation. What extending bare `Control` actually costs is the two things the base `_ready()` provides — `TouchScrollOpener.open_subtree()` and `SettingsOverlay.reserve_band_on()`. The overstatement is kept rather than deleted because a reader acting on it would rebuild wiring that already exists | `src/ui/screens/bug_hunt/BugHuntTurnController.gd:1`; `grep -rn ResponsiveManager src/ui/screens/bug_hunt/` |
| `BugHuntDashboard` rebuilds from three paths and **none** re-runs `_fix_touch_scroll_filters()`, which `CampaignScreenBase.gd:123` documents as required after any rebuild. Drag-scroll is dead after any enlist / muster-out | `src/ui/screens/bug_hunt/BugHuntDashboard.gd:25` |
| Duplicated implementations: **8** card factories, **4** `_load_json`, plus its own injury / XP / advancement logic against `InjuryProcessor`, `ExperienceTrainingProcessor` and `CharacterAdvancementService` | see NEVER-FIRES sites |
| `str()` on JSON ints renders **"4.0" / "8.0"** in the advancement cost table. `src/ui/components/common/DisplayText.gd` is the fix and Bug Hunt has not adopted it | `src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd:337` |
| **Zero of the 15 `data/bug_hunt/*.json` carry a `_source` key.** Page cites live in a free-text `description`, so no lint can ever check them — which is why these tables could go dead unnoticed. `data/RulesReference/*.json` carries `_source` | `data/bug_hunt/` |
| **Colour tokens are CLEAN** — every Bug Hunt `COLOR_*` aliases a `UIColors` token; no `#808080` anywhere in `src/ui/screens/bug_hunt/`. The one shared-fix sweep Bug Hunt is fully in on | `src/ui/screens/bug_hunt/` |

---

## 🔴 MEASURED 2026-09-19 — the fail-first pass (Sprint 1, Phase 0 steps 2-3)

Everything above this line is static analysis. These rows were produced by **running** the code:
the real `BugHuntTurnController` scene against a fresh `BugHuntCampaignCore`
(`tests/unit/test_bug_hunt_turn_completion.gd`, 7 cases), and the shipped enlist-source rule against
saves written by the real cores and labelled by the real producer
(`tests/unit/test_bug_hunt_enlist_filter.gd`, 4 cases). Each case was executed **alone** — the
others renamed `off_*` — because gdUnit4 is fail-fast and its case count means *executed*, not
*discovered*.

### ⭐ A Bug Hunt turn can never end

Three independent symptoms, one root: **`BugHuntPhaseManager._complete_turn` (`:104-115`) saves and
emits but never sets or persists `current_phase`.** The 5PFH foundation does both
(`CampaignPhaseManager.gd:1077` sets NONE then calls `_persist_phase()`, defined `:1088-1093`,
also called from `start_phase()` at `:1324`).

Because the phase is never NONE, `BugHuntTurnController`'s NONE branch (`:310-314`) is unreachable
and the Advance button falls through to `panels[current_phase].complete()` (`:317-321`) — i.e.
**pressing "Start Next Turn" re-runs the finished turn's post-battle application.**

Verbatim, from the fail-first run on HEAD:

```text
[4] test_start_next_turn_begins_the_next_turn                     1 case / 0 errors / 2 failures
    line 378: Start Next Turn did not start turn two: campaign_turn is still 1
    line 381: Start Next Turn must open the next turn on Special Assignments
[5] test_start_next_turn_does_not_apply_the_finished_turn_again   1 / 0 / 3
    line 406: Start Next Turn awarded the finished turn's XP again
    line 408: Start Next Turn counted the finished mission again
    line 410: Start Next Turn applied the finished turn's Reputation change again
[6] test_reopening_a_finished_turn_does_not_replay_it             1 / 0 / 1
    line 448: reopening the finished turn put it back on Special Assignments (turn 1, phase 0)
```

| # | Symptom | Status | Site |
|---|---|---|---|
| a | Start Next Turn does not start turn 2 | MEASURED | `src/core/campaign/BugHuntPhaseManager.gd:104` |
| b | Each press re-applies the finished turn: XP, the mission tally, Reputation | MEASURED (case 5) | `src/core/campaign/BugHuntPhaseManager.gd:177`, `:179`, `:199` |
| b′ | The same press also re-applies the Operational Progress modifier, re-ticks Sick Bay and saves again | STATIC (see the OP note below for why (b′) could not be measured) | `src/core/campaign/BugHuntPhaseManager.gd:203`, `:206`, `:104` |
| c | Reopening the save replays turn 1 at Special Assignments — **every HEAD Bug Hunt campaign is stuck on turn 1** | MEASURED (case 6) | `src/ui/screens/bug_hunt/BugHuntTurnController.gd:82` |
| d | `BugHuntPostBattlePanel.complete()` has no re-entry guard; `SpecialAssignmentsPanel` (`:56`) has one | STATIC | `src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd:62` |

⚠ **Case 5's Operational Progress assertion cannot fail on HEAD, and that is the
"campaign cannot be won" row biting a second time.** Every post-battle row lacks a
`cumulative_modifier` key, so the modifier is permanently 0 — and "applied twice" is
indistinguishable from "applied once" when the amount is 0. The assertion is documented in-file as
non-discriminating until the D100 is forced into a ±5 row. See *"The single worst NEVER-FIRES"*
above.

### The MISSION phase is never completed

`BugHuntTurnController._resume_after_battle` (`:387-404`) ends with
`go_to_phase(BugHuntPhaseManager.Phase.POST_BATTLE)` (`:404`), which **skips** MISSION's completion
entirely: `_phase_complete[MISSION]` is never set, `phase_completed` never emits, the journal never
logs the mission, and `BugHuntPhaseManager._apply_phase_results(MISSION)` (`:70`, `:139`) never
runs. On HEAD the only things that complete MISSION are the two fabricated launch-failure fallbacks
(`BugHuntMissionPanel.gd:451`, `:496`) — so deleting those, as Sprint 1 Phase 4 does, would leave
**nothing** completing it.

⚠ `PlanetfallTurnController.gd:727` has the same shape. That makes it a precedent for the
structure, **not** evidence the behaviour is correct — do not cite it as proof.

⚠ `BugHuntPhaseManager._apply_battle_results` (`:150-161`) reads `casualties`, `injury_turns` and
`extra_contact_bonus`. `casualties` is absent from the TacticalBattleUI result vocabulary and the
other two have **zero producers repo-wide** — the documented consumer-without-a-producer shape.

### Two writers for `completed_assignments`

`SpecialAssignmentsPanel` appends directly (`:316-320`, no dedupe) while the core's own mutator
(`BugHuntCampaignCore.gd:318-330`, reached via `BugHuntPhaseManager.gd:136`) dedupes. Today the net
result is one entry, so this is **not** a player-visible defect — it is a one-mutator violation, and
the panel also writes XP (`:307`) and Reputation (`:344-345`) directly. Recorded so the Phase 5
"one mutator" work does not have to rediscover it.

### ⭐ Enlist recruits from a Bug Hunt save — the key mismatch, costed

The LEDGER's root cause (`get_campaign_info()` emits `campaign_type`, consumers read `"type"`) is
now **measured at the one consumer where it costs a player their character.**
`BugHuntDashboard._on_enlist_pressed` filters `info.get("type", "") != "bug_hunt"`, which compares
`""` against `"bug_hunt"`, is **always true**, and returns the first save in the scan — a Bug Hunt
save included.

| # | Case | HEAD | What it proves |
|---|---|---|---|
| 0 | `get_campaign_info` labels the two probe saves | **PASS** | The producer CAN tell them apart: `bug_hunt` / `five_parsecs`, and `bh.has("type")` is FALSE. So this is the wrong KEY, not missing data |
| 1 | Enlist offers the standard save, not the Bug Hunt one | **FAIL** | *"It picked the Bug Hunt save, so a Bug Hunt marine can be enlisted into Bug Hunt as a 5PFH veteran"* |
| 2 | Enlist offers nothing when only Bug Hunt saves exist | **FAIL** | With no standard campaign there is nobody to enlist; HEAD offers the player's other squad |
| 3 | The rule tolerates an empty and a malformed list | **PASS** | The two shapes `get_available_campaigns()` can hand over on a machine with no saves |

⚠ **Case 1 asserts its own ordering premise before it calls the rule.** The filter returns the
FIRST eligible save, so with the 5PFH save placed first HEAD returns the right path *by luck* and
the case passes for the wrong reason. The Bug Hunt save is deliberately first, and that is asserted
— an ordering assumption left implicit is how a detection case goes quietly vacuous.

⚠ **The infos are built by the real producer, not hand-written.** `gs.get_campaign_info(path)` is
called on each probe save, so if the producer's key set ever changes, case 0 fails and this suite
stops pinning a defect that no longer exists. A hand-built fixture would have pinned a shape the app
may not produce — the documented `create_entry()` trap.

⚠ **Side-effect discipline.** Both cores are written with `core.save_to_file()`, never
`GameState.save_campaign()`, which also rewrites `settings.cfg`'s `last_campaign`. Measured:
`settings.cfg` md5 `d943e7733ff09ee85f002b597212580f` before and after, and the `.tmp`/`.bak`
siblings `SaveFileWriter.write_text_atomic()` leaves are removed in both `before_test()` and
`after_test()`, because a run aborted mid-case would otherwise seed the next.

The fix is Sprint 1 Phase 2 step 3 — one key — and Phase 2 step 4 then routes the enlistment through
`CharacterTransferService.remove_character_from_save()` so the veteran leaves the source save
instead of being duplicated.

### Two harness facts found while measuring

- **"Found 3 possible orphan nodes"** is warned on every case from 3 onward, undiagnosed. It does
  not affect any assertion; recorded so the next reader does not treat it as new.
- **The `last_campaign` bleed** that makes suites sensitive to batch composition most likely
  originates in `tests/unit/test_write_safety.gd:133`/`:139`, which writes
  `campaign_id = "lifecycle_flush_t"` to `user://saves/lifecycle_flush_t.save`. `GameState.save_campaign`
  rewrites `settings.cfg`'s `last_campaign`, and `GameState.load_campaign` resets
  `PlanetDataManager` — which is why these cases use `BugHuntCampaignCore.load_from_file` directly.

## 🟢 MEASURED 2026-09-19 — Sprint 1 Phase 1 (screen base, touch sweep, turn completion)

Phase 1 landed the turn-completion fix, so **cases 4-6 of `test_bug_hunt_turn_completion.gd` are
now green and the suite runs 10/10**. Six things were measured on the way that are not visible in
the diff; each is recorded here rather than left in a commit message. Two of them are places where
the code does **not** match the plan's literal wording, recorded so that reads as a decision
rather than an unfinished step.

### The Advance button is disabled for the whole of every phase — so the plan's bullet was not applied literally

`_advance_button.disabled` has exactly two writers:

| Site | Value | Reached when |
|---|---|---|
| [BugHuntTurnController.gd:414](../../src/ui/screens/bug_hunt/BugHuntTurnController.gd#L414) | `not can_forward` | every `navigation_updated` |
| [BugHuntTurnController.gd:357](../../src/ui/screens/bug_hunt/BugHuntTurnController.gd#L357) | `false` | `_on_turn_completed` only |

`can_forward` is `_phase_complete.get(current_phase, false)`
([BugHuntPhaseManager.gd:152](../../src/core/campaign/BugHuntPhaseManager.gd#L152)), and
`_update_navigation()` has **exactly one call site** —
[:102](../../src/core/campaign/BugHuntPhaseManager.gd#L102), inside `_go_to_phase()`, where
`current_phase` has just been set to the phase being ENTERED. `complete_current_phase()` sets
`_phase_complete[N] = true` and then calls `_go_to_phase(N + 1)` in the same breath
([:65-80](../../src/core/campaign/BugHuntPhaseManager.gd#L65)), so no navigation emit ever observes
a completed phase. **`can_forward` is therefore false at every emit**, and Advance is enabled only
between turns.

⚠ **That is why the plan's bullet *"`_on_advance_pressed` stops calling `complete()`"* was NOT
applied literally.** The `panel.complete()` branch
([:372-380](../../src/ui/screens/bug_hunt/BugHuntTurnController.gd#L372)) is unreachable in normal
play — when the button is pressable, `current_phase` is `NONE` and the handler takes the
`start_new_turn()` branch instead. Removing it would have been a no-op on the live path while
deleting the only recovery an enabled state would have. The turn-end defect was fixed at
[`BugHuntPhaseManager._complete_turn`:116](../../src/core/campaign/BugHuntPhaseManager.gd#L116),
which is where the plan's own T9-04 foundation puts it. Recorded because "the plan said remove it"
against "the code still has it" would otherwise read as an unfinished step.

### Two of the ten cases are weaker than their names suggest

- **Case 6** (`test_reopening_a_finished_turn_does_not_replay_it`, :433) asserts a **negative** —
  `not (turn == 1 and phase == SPECIAL_ASSIGNMENTS)`. A wrong-but-different phase satisfies it. It
  is kept because the replay is what a player would feel, but it is not a positive pin.
- **Case 9** (`test_the_second_turn_also_plays_to_its_end`, :552) is, by measurement, the **only**
  detector of a lost turn-END persist: dropping `_persist_phase()` from `_complete_turn()` leaves
  case 6 green (POST_BATTLE survives in the save and resumes there) and fails case 9, which asserts
  the positive `current_turn_phase == NONE`. Dropping the OTHER `_persist_phase()` call site, in
  `_go_to_phase()`, leaves case 9 green and fails cases 7 and 8 — so the two call sites are
  pinned separately. The analysis is repeated in the case's own docblock.

### `_load_campaign()` performs a scene change, which makes the screen unsweepable

[`BugHuntTurnController._load_campaign()`:137-151](../../src/ui/screens/bug_hunt/BugHuntTurnController.gd#L137)
routes to `main_menu` through `SceneRouter` when `GameState.current_campaign` is present but is
**not** a Bug Hunt core — and a 5PFH core is present for most of any test run, because
`GameState` auto-loads `last_campaign` at boot.

A screen whose failure mode is *"replace the current scene"* cannot be built inside a shared test
tree. That is why
[`screen_populator.gd:_pre_bug_hunt()`:483](../../tests/tools/screen_populator.gd#L483) makes
clearing the field its **first act** and leaves it null on every early return.

⚠ **`nodes=1` does not tell you which branch you got.** `_initialize()` bails at
[:67-68](../../src/ui/screens/bug_hunt/BugHuntTurnController.gd#L67) whenever `campaign` is null,
and `_load_campaign()` nulls it in BOTH cases — no campaign at all, and a non-Bug-Hunt campaign,
which additionally calls `navigate_to("main_menu")` on the way past. The tree stops at one node
either way. MEASURED in the unpopulated arm: `nodes=1`, and the 30-screen run still completed —
so the bail-out is what the sweep sees, but the arm does not establish which branch produced it.
Clearing the field first is what makes it the *plain-null* branch by construction, keeping
`navigate_to` off the table rather than relying on it having been harmless.

### The touch-scroll sweep has a per-process screen ceiling

Adding three screens took `test_touch_scroll_sweep.gd` from 27 to 30 and the process died with
**signal 11**. Bisected by prefix length: **K=8 / 16 / 20 / 24 / 25 / 26 all clean, K=27 crashing**
— so no single screen is responsible, and nothing in the three new rows would have named it.

The cause is `auto_free(sv)`, which defers every SubViewport to the END of the case, so all 30
screens (~5,000 nodes; `TacticalBattleUI` alone is 1,235 and `CampaignTurnController` 1,079) were
alive at once. `_sweep()` now `queue_free()`s each SubViewport as soon as its row is computed
([test_touch_scroll_sweep.gd:244](../../tests/unit/test_touch_scroll_sweep.gd#L244)). `auto_free`
stays as the net for the early returns, which is safe because `GdUnitTools.free_instance` opens
with `if not is_instance_valid(instance): return false`
(`addons/gdUnit4/src/core/GdUnitTools.gd:38-39`) — teardown skips an instance already freed in
the loop.

⚠ **Piping matters here.** Redirecting a crashing run to a file loses the buffered stdout; piping
it to `grep` keeps it. Four diagnostic passes were spent before that was noticed.

### The sweep's `built` floor could not see an empty screen

`assert_int(built).is_greater(20)` counts screens that *instantiated*, and a screen that bails out
of `_ready()` still counts. An empty tree has no ScrollContainers, contributes
`STOP-under-scroll=0`, and reads as a clean result — **T11-01 exactly**.

Measured by a one-variable A/B, the POPULATE entry being the only difference between arms:

| Screen | unpopulated | populated | floor |
|---|---|---|---|
| `BugHuntDashboard.tscn` | **9** nodes | **144** | 60 |
| `BugHuntTurnController.tscn` | **1** node | **61** | 30 |
| `BugHuntCreationUI.tscn` | 101 | 101 (no POPULATE entry — it reads no autoload) | 50 |

In that arm both starved rows still count toward `30/30 screens built` and still report
`STOP-under-scroll=0`, so every pre-existing assertion passes with the fixture completely dead.
[`MIN_NODES`:133](../../tests/unit/test_touch_scroll_sweep.gd#L133) is the guard, detection-proven
by deleting only the two POPULATE entries:

```
line 302: these screens built far smaller than their measured populated size, so their
STOP-under-scroll=0 is the empty-tree false green, not a clean result -- the fixture that
fills them has regressed: ["BugHuntDashboard.tscn (9 nodes, floor 60)",
"BugHuntTurnController.tscn (1 nodes, floor 30)"]
```

⚠ `built > 20` itself is **left untightened**, and that is a decision rather than an oversight.
Measured truth is that all 30 build, so `is_equal(SCREENS.size())` would be defensible — but it
would turn a legitimate screen deletion into a red suite (`MissionSelectionUI` was deleted once
already), and re-policying a shared Alpha-1 guard suite is outside this sprint's scope.

### The single save path is `persist()` on the core, not `save_to_file()` on the caller

Plan step 4 reads *"collapse the duplicate save logic in `_on_save_pressed` into
`_campaign.save_to_file()`"*. Grepping for `save_to_file` in the TurnController now finds nothing,
so this is stated here.

The duplication was in **two** functions, not one: `_on_save_pressed` and
`BugHuntPhaseManager._complete_turn` each had their own GameState-then-direct-file pair, and
either could drift over which of them updates `last_campaign` — the key MainMenu's Continue
button reads. Putting the choice on
[`BugHuntCampaignCore.persist()`:328](../../src/game/campaign/BugHuntCampaignCore.gd#L328) makes
the core the single owner and covers both callers; collapsing only the caller named in the plan
would have left the other half free to diverge. The reason is repeated at the call site.

### Phase 1 gates, and why the plan's count check had to be replaced

`tests/unit` headless, 9 batches of 35 (34 in the last): **3383 executed / 0 errors / 1 failure /
0 flaky / 314 suites**. All 8 lints exit 0
(`files=560 reachable_from_product=560 test_only=0 orphans=0 unwired_rules=0`). `git diff -- data/`
touches one file, and it is another instance's cited p.151 additions to `black_zone_jobs.json`, not
this sprint's. All 7 named Alpha-1 guard suites ran exactly once and none failed. The single
failure is `test_bug_hunt_enlist_filter::test_enlist_offers_the_standard_save_not_the_bug_hunt_one`
— Phase 0 step 3's fail-first evidence, whose fix is scheduled at Phase 2 step 3.

⚠ **The plan's gate — *"the count equals the baseline plus the new cases"* — is no longer a
check that can pass.** The 2026-09-14 baseline of 3366/313 has drifted underneath this sprint:
another instance working the same tree has since changed the case count of **six** existing suites
(net −23: `test_battle_calculations` −20, `test_core_appendices` −3, `test_story_point_system`
−2, `test_crew_creation_methods` −1, `test_gun_mods_and_sights` +2, `test_cheat_sheet_from_data`
+1), added five untracked suites of its own, and deleted a 10-case suite
(`test_area_weapon_resolution.gd`, absent by design [[missing]]). Arithmetic against a moving
baseline reports a discrepancy that is real but says nothing about this sprint.

**The replacement check is self-contained and was used instead:** sum `func test_` across the exact
314 files the runner was handed, and reconcile against what executed.

```
true population (func test_ across the 314 suites handed to the runner) = 3385
executed                                                                = 3383
difference                                                              =    2
```

Those 2 are precisely the cases gdUnit4's suite-level fail-fast hides in
`test_bug_hunt_enlist_filter` after case 1 fails (case 0 ran and passed; cases 2-3 never started).
**Every other case in the tree ran.** Prefer this shape over a remembered baseline whenever a
second instance may be editing the same worktree.

ℹ The pre-existing batch-composition bleed —
`test_compendium_mission_types::test_each_generator_stamps_its_dispatch_type`, which failed in the
baseline run and passes 6/6 alone — did **not** reproduce here. Batch boundaries moved when the
suite count changed, which is consistent with it being composition-dependent rather than a defect
in that suite, and is why it is not counted as fixed.


---

## 🟢 MEASURED 2026-09-19 — Sprint 1 Phase 2 (one mode predicate, transfer hub)

Phase 2 is complete. Five plan steps landed: four change behaviour, and the fifth is a
consistency fix that is explicitly **not** a live defect. Running the phase gates afterwards
surfaced a sixth item — a freed-node race in the dashboard's reveal animation — recorded here
with its severity **corrected downward**, because the crash text overstates what a player sees.

Suites: **`test_bug_hunt_mode_predicates.gd` is new (10 cases)**. `test_bug_hunt_enlist_filter.gd`
(4, from Phase 0 step 3) now passes — its two fail-first cases were this phase's target.
`test_bug_hunt_enlistment_transfer.gd` gained 4 cases (6 total) and
`test_character_transfer_hub.gd` gained 2.

### Step 1 — the mode tag was wrong in BOTH directions, and the plan named only one

The plan's ledger row said the Load Campaign tag "works only by path substring". Measured, that
understates it twice over, and the second half is the one nobody had seen.

| Direction | What happens | Why |
|---|---|---|
| **False negative** — the tag has **never** rendered on a real named variant save | Bug Hunt writes to `user://saves/<id>.save` where the id is `<name>_bh_<ts>` for a named campaign ([BugHuntCampaignCore.gd:345](../../src/game/campaign/BugHuntCampaignCore.gd#L345), id at [:137-143](../../src/game/campaign/BugHuntCampaignCore.gd#L137)). **Neither shape contains `bug_hunt`.** Planetfall and Tactics are `_pf_` / `_tac_`, so only their *unnamed* fallback ids (`planetfall_<ts>`, `tactics_<ts>`) ever matched | both arms of every `or` are false |
| **False positive** — a *standard* campaign is tagged `[BH]` | `FiveParsecsCampaignCore` builds its id the same way, so a 5PFH campaign the player names **"Bug Hunt Veterans"** saves as `bug_hunt_veterans_<ts>.save` and is tagged `[BH]` in the one list where the player chooses which campaign to open | the substring is in the *name*, not the *type* |

⚠ **This is why the fix reads the key rather than widening the substring list.** A longer list of
substrings fixes neither direction: it cannot see a named save, and it mis-tags more names.
[`MainMenu.campaign_type_tag()`](../../src/ui/screens/mainmenu/MainMenu.gd#L570) now reads
`info.campaign_type`, the key [`GameState.get_campaign_info()`](../../src/core/state/GameState.gd#L1318)
actually emits, resolved through the shared `campaign_type_from_data`. One change fixes the Bug
Hunt, Tactics and Planetfall tags together.

⭐ **The premise is instrumented, so the suite cannot go quietly vacuous.** Case 0
(`test_the_producer_labels_every_mode_and_writes_no_type_key`) asserts the producer labels all four
modes **and** that `info.has("type")` is FALSE. If a future writer starts emitting `type`, case 0
says so and this suite stops pinning a defect that no longer exists.

⭐ **The fixture ids are generated, never hardcoded.** Every probe sets `campaign_name`, leaves
`campaign_id` empty and asks the core's own `get_campaign_id()` for the id — so the id *shape*
under test is the shipped one. A hardcoded `zz_probe_bh_1` would have pinned the suite to my
transcription of the generator rather than to the generator.

### Step 2 — three byte-identical save scans, and the menu could disagree with the loader

`_find_bug_hunt_saves`, `_find_tactics_saves` and `_find_planetfall_saves` were byte-identical
apart from the mode string and, for Planetfall, the turn section. They are now one parameterised
[`MainMenu.find_saves_of_type()`](../../src/ui/screens/mainmenu/MainMenu.gd#L1022), with
`_VARIANT_TURN_SECTIONS` ([:1008](../../src/ui/screens/mainmenu/MainMenu.gd#L1008)) carrying the one
real difference. The three old names survive as one-line forwarders, so no call site moved.

The collapse was the occasion; the **reader** was the point. The old private `FileAccess` +
`JSON.parse_string` type sniff let the menu and the loader disagree twice:

- **A save recovered from its `.bak` was DROPPED from the menu.** The loader reads through
  `SaveFileWriter.read_json_with_fallback`; the menu did not. A save whose main file an
  interrupted write truncated to 0 bytes **opens fine** and was **invisible in the list**.
  ⚠ That victim is named in `_detect_campaign_type`'s own docblock — the fix had been applied to
  the loader and not to the menu.
- **A save carrying the type only under `meta` was mis-routed.** Synthetic today (every shipped
  core writes the field at root *and* under meta), but `campaign_type_from_data`'s comment says the
  meta branch exists "so a future writer moving the field cannot silently mis-route a save", and
  `test_the_menu_lists_exactly_what_the_loader_would_open_as_bug_hunt` now pins that invariant by
  asserting the two readers agree rather than by restating either one.

### Step 3 — the Enlist filter, and why the test is POSITIVE rather than "not Bug Hunt"

Phase 0 step 3 measured the defect: the filter read `info.get("type", "")`, **a key no producer
writes**, so the comparison was `"" != "bug_hunt"` — permanently true. The first save of *any*
type won, and a player could enlist a Bug Hunt marine into Bug Hunt as a 5PFH veteran; with no
standard campaign on disk at all, HEAD offered the player their other squad.

[`pick_enlist_source()`](../../src/ui/screens/bug_hunt/BugHuntDashboard.gd#L305) now tests
`campaign_type == "five_parsecs"`.

⭐ **The positive test is a rules decision, not a style one.** `!= "bug_hunt"` also admits Tactics
and Planetfall saves, and `CharacterTransferPanel.load_characters_from_save()` reads a **5PFH
crew**. This leg is the 5PFH → Bug Hunt enlistment (Compendium p.171), so the eligible source is a
*standard* campaign, not merely a non-Bug-Hunt one. A colonist or an army-list veteran reaches Bug
Hunt by composing two book-defined legs through the 5PFH canonical — that is
`CharacterTransferService`'s job, and putting it in this picker would have invented a route the
book does not give.

### Step 4 — enlisting now removes the veteran from the source campaign

HEAD appended to `_campaign.main_characters` directly and stopped, so **the veteran existed in both
campaigns afterwards** — the "one item, one home" breach that
[`remove_character_from_save()`](../../src/core/character/CharacterTransferService.gd#L617) was
written to close for the Planetfall and Tactics pull-imports. A duplicate is not merely untidy:
the same veteran can be enlisted **again, and again**, off the source save.

[`_apply_enlistment`](../../src/ui/screens/bug_hunt/BugHuntDashboard.gd#L317) now goes through the
core's own `add_main_character()` and then drops the source. Two further consequences of the raw
append went with it: the campaign's modified time was never touched (the mutator does it,
[:178-179](../../src/game/campaign/BugHuntCampaignCore.gd#L178)), and any invariant that mutator
grows later would have been bypassed.

⚠ **Destination first, then drop the source** — the same ordering muster-out uses and the same as
`PlanetfallDashboard._apply_import` ([:64-87](../../src/ui/screens/planetfall/PlanetfallDashboard.gd#L64)).
Interrupted halfway, the failure is a duplicate the player can delete, never a veteran who exists
nowhere.

⚠ **The source coordinates must not persist.** `CharacterTransferPanel` stamps `_source_path` and
`_source_character_id` on the enlist emit; they are pulled off the copy **before** the character
lands in the squad, so a Bug Hunt save never carries a pointer into a 5PFH one. Pinned by
`test_the_source_coordinates_do_not_persist_into_the_bug_hunt_save`.

### Step 5 — four reward lines announced outside the guard that grants them

[`apply_transfer_rewards()`](../../src/core/character/CharacterTransferService.gd#L709) appends to
`summary_parts` — the text the player is shown as their muster-out result. Four lines
(`+N credits`, `+N Story Point(s)`, `+Sector Government Patron`, `+Ship`) sat **outside** the guard
that performs the grant, while `debt cleared`, the prepayment and `+Rival` sat inside. One
function, two patterns.

⭐ **`+Rival` is what makes the loose form a slip rather than a convention**: it reads from the
same `safe_char` as `+Ship` and is guarded correctly.

⚠ **None of the four could fire on HEAD, so this is a CONSISTENCY fix and NOT a live defect — do
not cite it as one.** A nine-site census settled it: `transfer_character()`'s reward-suppression
rule zeroes the three envelope keys unless the target is 5PFH; the down-converters build fresh dict
literals, so `bonus_ship` never reaches a Bug Hunt or Tactics character; and both
`GameStateManager` methods exist. The guards are still load-bearing, because **each grant can
fail**, and the announcement must never outlive the grant — which is what the two new cases
(`test_the_summary_omits_rewards_the_campaign_cannot_hold`,
`test_the_summary_still_announces_rewards_the_campaign_did_receive`) assert in both directions.

### Step 6 (unplanned) — a rebuild during the dashboard's reveal hands TweenFX a freed node

Surfaced by the Phase 2 gates, not by the plan. The batch-2 run reported:

```
res://tests/unit/test_bug_hunt_enlistment_transfer.gd > test_an_enlistment_without_coordinates_still_adds_the_veteran FAILED
  line 0: Godot Runtime Error !
  Error: 'Invalid type in function 'fade_in' in base 'Node (TweenFX.gd)'. The Object-derived
          class of argument 1 (previously freed) is not a subclass of the expected argument class.'
    at res://src/ui/screens/bug_hunt/BugHuntDashboard.gd:215
```

**The suite passes 5/5 alone**, so the batch is only what makes the timing line up.

[`_stagger_reveal()`](../../src/ui/screens/bug_hunt/BugHuntDashboard.gd#L207) captures
`_content.get_children()` once, zeroes every card's alpha, then suspends **0.04 s per card**. Three
of the four `_build_dashboard()` callers free the whole subtree and rebuild (`:29` transfers
applied, `:329` enlist, `:426` muster out), and `queue_free()` lands at the **end of the frame** —
well inside 0.04 s — so the suspended coroutine wakes holding freed nodes.

⚠ **SEVERITY CORRECTED DOWN, and the correction is the useful part.** My first diagnosis said the
abort "leaves the remaining cards permanently invisible". Reading the code disproved it: the nodes
the stale coroutine still holds are **the ones being destroyed**, and the rebuild starts its own
reveal over the new cards, so the screen ends up correct. What it actually costs is a class-(b)
abort in the log, a **debugger HALT under `--debug`/MCP** (which is how this project does runtime
QA), and a suite that goes red only in a batch. The corrected reading is written into the fix's own
comment so it cannot be re-inflated.

The guard is the **container's identity**, not a generation counter: `_build_dashboard()` rebinds
`_content` as its first act ([:34](../../src/ui/screens/bug_hunt/BugHuntDashboard.gd#L34)), so *"am
I still the live reveal?"* is answerable from state the tree already holds, with nothing to keep in
sync. It is re-checked **after** the await and never before — suspended is the only state in which
the tree can change underneath.

⭐ **A bare `is_instance_valid()` guard would have shipped green, and the second detection arm is
what proves it.** Arm **O2** replaced both guards with a plain `return` — *silencing the crash
completely* — and produced `0 errors | 6 failures`, six cards left at `alpha 0.000000`. So the case
carries two kinds of evidence and needed both arms:

| Arm | Result | What it proves |
|---|---|---|
| **R1** revert the fix (capture `_content` inline, drop both guards) | `1 errors` — **DETECTED**, exact batch message reproduced | gdUnit4's Godot-runtime-error capture is the discriminator for the defect |
| **O2** over-correct (bail the LIVE reveal too) | `0 errors, 6 failures` — **DETECTED** | the explicit alpha assertion is the discriminator for the *mis-fix* |

Both ran behind a clean single-case control (`1 test cases | 0 errors | 0 failures`), guarding
against the documented "0 cases reads as undetectable" trap.

### Phase 2 gates

| Gate | Result |
|---|---|
| 8 lints | **all exit 0** — `files=560 roots=36 reachable_from_product=560 test_only=0 orphans=0 unwired_rules=0`; multiline lint 909 scripts / 0 findings |
| `tests/unit`, 10 batches of 35 | **3118 cases · 1 error · 0 failures · 317 suites** — the one error is step 6 above, now fixed |
| `tests/unit`, post-fix isolated re-run | **3403 cases · 0 errors · 0 failures · 317 suites** — batches 1-8 `3119` + batch 9 `284` (verified by an 18+17 split, see below) + batch 10 `0` (two empty files) |
| Count arithmetic | **closes exactly**: `3371` baseline (2026-09-14, 313 suites) `+30` the four new `test_bug_hunt_*` suites `+2` [test_character_transfer_hub.gd](../../tests/unit/test_character_transfer_hub.gd) (Phase 2 step 5) `= 3403`. Suite count `313 + 4 = 317` confirms only those four were added. The other instance's concurrent test edits are ruled out by measurement: its tracked changes total **−33** cases, and its five untracked suites all carry **2026-09-10** mtimes, i.e. they predate the Sep 14 baseline and are already inside `3371` |
| Detection proofs | every new case proven alone, others renamed `off_*`, reverted from a scratchpad backup (**never** `git restore`) |
| Data diff | **Phase 2 touches no data file.** `git diff -- data/` is not empty, but its one entry — `data/black_zone_jobs.json` (+6, Core Rules p.151 reinforcement and activation cites) — belongs to the other instance sharing this worktree and is present in the session-start porcelain, i.e. it predates this sprint |
| Harness hygiene | detection runs: `settings.cfg` md5 unchanged, no probe saves or `.tmp`/`.bak` siblings left, every edited suite restored byte-identical. ⚠ **Batch runs legitimately rewrite `settings.cfg`** (`last_campaign`), so that md5 guards the isolated proofs only |
| Batch 9 | signal 11, **REPRODUCED and root-caused** — a cumulative-resource cliff at 31 suites, every one of them pre-existing. All 35 suites run and pass: **284 cases · 0 errors · 0 failures**, verified by an 18+17 split. See below |

#### Batch 9's signal 11: a cumulative-resource cliff at 31 suites, not a faulty suite

⚠ **CORRECTED 2026-09-19, and the original wording is restated rather than deleted, because both
of its errors are the kind that cost the next reader a day.** This section first concluded that the
crash *"does not reproduce when batch 9 runs alone, in either arm"* and that the repeated
`_connect_ui_signals` frame was *"a recursion-shaped signature"*. **The crash reproduces on demand,
and that frame is not the faulting one.** Everything below the two-arm table is new measurement.

The full run's batch 9 died with `rc=3221225477` / `CrashHandlerException: Program crashed with
signal 11`, its only visible lead being
`[0] _connect_ui_signals (res://src/ui/screens/world/components/JobOfferComponent.gd:57)` repeated
**11×**. Per the documented protocol, a mega-run crash is never read as *"my edit broke
something"* until the identical batch has run at HEAD in a separate worktree. Batch 9 is entirely
5PFH world-phase/terrain/UI suites, but it contains `test_transfer_xp_and_snapshot.gd` and
`test_touch_scroll_sweep.gd`, both of which reach files this sprint changed — so the control was
load-bearing, not ceremonial.

| Arm | Result |
|---|---|
| **A** — batch 9's exact 35 suites, current working tree (sprint changes **in**) | `284 cases · 0 errors · 0 failures`, **no crash** |
| **B** — the same 35 suites at HEAD in a throwaway worktree (sprint changes **absent**) | `283 cases · 17 errors · 3 failures`, **no crash** |

**Those two arms are real measurements and they no longer hold.** Re-run on 2026-09-19, batch 9
crashes as its own single process with nothing before it — five times out of five (the standard
10-batch run, an isolated 10-batch run, standalone batch 9, and both the `full` and `pre31` arms of
the bisect below). The "not reproduced" verdict was true of the machine on the day and is false
now. **What survives from it is the conclusion, reached for a different reason.**

**The boundary is 31 suites.** Bisecting batch 9's sorted partition for the shortest crashing prefix:

| Prefix | rc | `Overall Summary:` | Verdict |
|---|---|---|---|
| 18 | 101 | yes | clean |
| 27 | 101 | yes | clean |
| 29 | 101 | yes | clean |
| **30** | **101** | **yes** | **clean** |
| **31** | **3221225477** | **no** | **CRASH** |
| 35 | 3221225477 | no | CRASH |

⚠ **`rc=101` is gdUnit4's NORMAL exit on a completed run**, not an error — reading it as one sends
you hunting a failure that is not there. The crash verdict therefore tests **both** a missing
`Overall Summary:` line and a non-zero rc, because a parse failure would instead print
"No test cases found" and exit **0**: the two pathologies have opposite signatures, and neither
test alone separates them.

**The 31st suite is innocent, proven by three arms differing in exactly one variable — how much work
precedes the same suite:**

| Arm | n | Result |
|---|---|---|
| the trigger alone | 1 | 19 cases · 0 err · 0 fail · **0 orphans** — clean |
| the trigger at position 27 | 27 | 223 cases · 0 err · 0 fail · **29 orphans** — clean |
| the other 30 **without** it | 30 | 233 cases · 0 err · 0 fail · **47 orphans** — clean |

`tests/unit/test_world_trait_effects.gd` merely occupies index 31 in the sorted partition; it passes
its 19 cases in every arm. The third arm's 233 cases match the 233 recovered by parsing the crashed
run's per-case lines, which cross-validates that recovery.

**The faulting frame is in teardown, not in any test.** Reading the crash *region* of the log rather
than its tail: the `signal 11` line follows `WARNING: 26 RIDs of type "CanvasItem" were leaked` at
`renderer_canvas_cull.cpp` line 2692 (`_free_rids`). The `_connect_ui_signals` frames are eleven
separate `push_warning` traces — :57 is the `else` branch of that function — flushed into the same
region by earlier suites, alongside an `ERROR: Node not found: "JobOfferContainer/ContentContainer"`
raised from
[test_world_phase_checkpoint_keeps_the_job.gd:56](../../tests/unit/test_world_phase_checkpoint_keeps_the_job.gd#L56)
against [JobOfferComponent.gd:44](../../src/ui/screens/world/components/JobOfferComponent.gd#L44).
Nothing recursive, and nothing this sprint touches. The C++ backtrace is unusable —
`no debug info in PE/COFF executable` ×19 — which is why the log region, and not the backtrace, is
the evidence.

Orphan nodes and RIDs **accumulate across suites within one process** (45 orphans at 18 suites, 47
at 27, 47 at 30), and the process dies during teardown/GC once this particular slice crosses ~31.
**All 35 suites run and all of them pass regardless** — the crash costs the summary line, not a
single test outcome.

**Verified count: 284 cases · 0 errors · 0 failures**, obtained by splitting batch 9 into 18 + 17 so
that each process stays below the cliff (18 asked / 18 ran → 141 cases; 17 asked / 17 ran → 143).

**Still not attributable to this sprint, and now on firmer ground.** Every suite in batch 9 is
pre-existing; the four new `test_bug_hunt_*` suites sort to indices 39-42 and land in **batch 2**.
What the sprint changed is only *which* pre-existing suites share a process: adding four suites
shifted the 35-wide partition, pulling `test_tap_gesture` and three `test_terrain_*` suites into
batch 9 and displacing two empty files into batch 10.

⚠ **Why arms A and B were clean while an identical run crashes today is an AMBIENT difference, and
it is recorded as UNRESOLVED rather than explained away.** The leading candidate is the one this
project has already documented as flipping a timing test red on 2026-09-07: `.godot/imported` now
measures **2193 MB across 7385 entries**, against the 600 MB threshold `CLAUDE.md` sets, and
near-identical to the 2.2 GB / 6,989 entries recorded on that occasion. That is a hypothesis with a
cheap test — delete the cache, re-run batch 9 — and **no measurement behind it yet**. Do not cite it
as the cause.

⚠ **A git worktree does NOT isolate `user://`, and that is a flaw in the protocol as written.**
Godot resolves `user://` from `application/config/name`, never from the project path. Both trees
carry `config/name="Five Parsecs Campaign Manager"` and neither sets `use_custom_user_dir`, so
there is exactly one `app_userdata/Five Parsecs Campaign Manager/` and **both arms read and wrote
the same saves and the same `settings.cfg`.** Arm A ran first, so arm B inherited its state —
which is the most economical reading of arm B's failures: the five `test_terrain_generation_gate`
cases and `test_touch_scroll_sweep` are *precisely* the suites this project has already documented
as campaign-context-sensitive, passing in isolation and failing after another suite has saved a
campaign. **Treat a worktree control as isolating CODE only.** To isolate state too, the worktree
needs its own `custom_user_dir_name`, or `user://` must be snapshotted and restored between arms.

ℹ **Two test files in the tree contain no cases at all**, which is why batch 10 reports
"NO SUMMARY" with `rc=0`: `tests/unit/ui/panels/test_config_panel.gd` (27 lines, 0 `func test_`)
and `tests/unit/ui/screens/campaign/test_upkeep_phase_ui.gd` (**0 bytes — an empty file**).
"No test cases found" is honest there. Hygiene note, not a Bug Hunt finding.

### Three findings OUTSIDE this sprint's file list

All three are recorded rather than fixed. **C** and **D** live in `GameState.gd` and
`CharacterTransferPanel.gd`, neither on the plan's list of shared files this sprint may touch,
and both are 5PFH-facing, i.e. **Alpha-1 surface**. **E** is a harness defect in pre-existing
Tactics suites, found while closing Phase 2's gates.

- **C — a recoverable save vanishes from the Load Campaign dialog.** The load path recovers from
  `.bak` ([`FiveParsecsCampaignCore.gd:1072`](../../src/game/campaign/FiveParsecsCampaignCore.gd#L1072)
  calls `read_json_with_fallback`), but the *listing* path does not:
  [`get_campaign_info()`](../../src/core/state/GameState.gd#L1318) opens the file raw and returns
  `{"valid": false, "reason": "Invalid JSON"}`, so `get_available_campaigns()`
  ([:1306-1310](../../src/core/state/GameState.gd#L1306)) skips it. **A 5PFH save whose main file
  was truncated but whose `.bak` is intact loads fine and is invisible in the menu.** Exactly the
  asymmetry Phase 2 step 2 closed for the *variant* scans — the standard list still has it.
- **D — the enlist picker shows zero characters for the same save.**
  [`CharacterTransferPanel.load_characters_from_save()`](../../src/ui/screens/bug_hunt/panels/CharacterTransferPanel.gd#L60)
  uses `FileAccess.open` + `JSON.new().parse()` with no `.bak` fallback.
- **E — a Tactics suite writes `last_campaign`, and every later test PROCESS inherits it.**
  [`TacticsPhaseManager._complete_turn()`](../../src/core/campaign/TacticsPhaseManager.gd#L193)
  auto-saves through `GameState.save_campaign()`
  ([:196-197](../../src/core/campaign/TacticsPhaseManager.gd#L196)), which writes **both**
  `user://saves/tactics_<unix>.save` and `last_campaign` into `user://settings.cfg` — that key is
  set for all four modes ([GameState.gd:154](../../src/core/state/GameState.gd#L154)).
  [`_try_auto_load_last_campaign()`](../../src/core/state/GameState.gd#L188) then loads that
  campaign at **every** subsequent launch, gated only on `continue_last_campaign_on_launch`
  (default `true`, [:189](../../src/core/state/GameState.gd#L189)). A 5PFH-only suite in a later
  batch therefore measures a `TacticsCampaignCore` and aborts on `get_crew_members`. This is the
  cross-suite bleed `CLAUDE.md` already documents — **what is new here is the named producer.**
  - **Measured cost, this session.** Batch 3 failed with 1 failure and **5 further cases hidden by
    gdUnit4's fail-fast**; neutralising both levers took the same batch to
    `361 cases · 0 failures`. The campaign id is auto-assigned at
    [TacticsCampaignCore.gd:106](../../src/game/campaign/TacticsCampaignCore.gd#L106), so each run
    leaves a *new* file: **134 `tactics_*.save` files** now sit in the user's save directory, 14 of
    them written today across four test runs. Of the suites that can trigger the save, only
    [test_bug_hunt_mode_predicates.gd](../../tests/unit/test_bug_hunt_mode_predicates.gd) — this
    sprint's — cleans up after itself.
  - **The fix is the shape `CLAUDE.md` already prescribes**: pin the campaign context in
    `before_test()` and delete the save in `after_test()`, in
    [test_tactics_campaign_points.gd](../../tests/unit/test_tactics_campaign_points.gd),
    [test_tactics_turn_payload.gd](../../tests/unit/test_tactics_turn_payload.gd),
    [test_tactics_unit_battle_record.gd](../../tests/unit/test_tactics_unit_battle_record.gd) and
    [test_standalone_battle_ownership.gd](../../tests/unit/test_standalone_battle_ownership.gd).
  - ⚠ **Clear only a NON-5PFH core, never unconditionally.** An unconditional clear in
    `before_test()` hands back exactly the false green the pin exists to prevent.
  - ⚠ **Nothing here was deleted.** All 204 files in `user://saves/` are QA artefacts by name
    (`tablet_qa_run_*`, `rollover_check_*`, `fresh_repro_*`, keyboard-mash campaigns), and several
    are cited as evidence by device-deploy records, so the litter is left in place and only the
    *production* of new litter is in question.
  - **Why it is not already done:** all four suites are clean in git (untouched by the other
    instance sharing this worktree), so the only obstacle is scope — they are pre-existing suites
    this sprint does not own. Owner decision.

---

## 🟢 MEASURED 2026-09-19 — Sprint 1 Phase 3 (DiceManager + the QA seam)

Phase 3 is complete. Its purpose was **tooling, not rules**: no Bug Hunt roll could be forced, so
every rare row in the ledger above was unreachable at the desk and on the device. 23 call sites now
route through `DiceManager`, 16 of them are armable from the QA dialog, and the Bug Hunt dashboard
has a QA card. The plan ordered this phase before the post-battle slice for exactly that reason,
and the owner's direction — *"do QA first so you have a comprehensive list of issues to address"* —
is what it discharges.

New suite: **`test_bug_hunt_dice_routing.gd`, 13 cases**, of which **11 are detection-proven**, each
run alone. The phase also **found one live defect with its own new tooling** (finding J) and
recorded four more it does not own.

### The routing, measured rather than quoted

⚠ **The plan's RNG count was wrong, and the correction is what makes the residue auditable.** The
plan said *"38 raw rolls"* with a per-file split of BattleSetup 11. Measured at HEAD with comments
stripped by a throwaway census script: **39 occurrences on 37
lines**. `BugHuntBattleSetup.gd:151` and `:168` each carry **two** `randi()` calls
(`{"row": randi() % 4, "col": randi() % 4}`) — they are the only doubled lines in the five files —
so the plan's 11 was neither the line count (10) nor the occurrence count (12). A counting UNIT
that is never stated cannot be reconciled later.

⚠ **A naive grep over-counts by 2 now.** Two files gained a comment that names `randi()` in order
to explain why the remaining calls are deliberately unrouted
([BattleSetup:220](../../src/core/battle/BugHuntBattleSetup.gd#L220),
[CharGen:410](../../src/core/character/BugHuntCharacterGeneration.gd#L410)). The census strips
comments first, matching **string literals before `#`** so a colour literal or a context string
containing `#` is not mistaken for a comment — the same discipline `lint_orphan_assets.py` already
uses.

| File | HEAD | Routed now | Raw left | What the residue is |
|---|---|---|---|---|
| [BugHuntBattleSetup.gd](../../src/core/battle/BugHuntBattleSetup.gd) | 12 | 2 | 11 | **10 positional** — location pick `:140`, sector row/col `:151` `:168`, board edge `:182`, edge positions `:185-188` — plus 1 fallback `:233` |
| [BugHuntCharacterGeneration.gd](../../src/core/character/BugHuntCharacterGeneration.gd) | 8 | 9 | 7 | 2 character ids `:125` `:184`, 3 name picks `:283-285`, 2 fallbacks `:293` `:423` |
| [BugHuntMissionPanel.gd](../../src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd) | 8 | 8 | 1 | 1 fallback `:568` |
| [SpecialAssignmentsPanel.gd](../../src/ui/screens/bug_hunt/panels/SpecialAssignmentsPanel.gd) | 2 | 2 | 1 | 1 fallback `:425` |
| [BugHuntPostBattlePanel.gd](../../src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd) | 9 | 0 | 9 | **deliberately untouched** — written routed inside the resolver in Phase 5, so they are not routed twice |
| [CharacterTransferService.gd](../../src/core/character/CharacterTransferService.gd) (enlistment only) | 2 | 2 | 0 | — |
| **Five Bug Hunt files** | **39** | **21** | **29** | **9** Phase 5 · **5** fallback returns · **15** positional/cosmetic |
| **+ enlistment** | 41 | **23** | 29 | |

⭐ **CharacterGeneration routes 9 sites out of 8 HEAD occurrences, and that row is the interesting
one.** Three raw rolls became nine routed call sites, and two new fallback `randi_range` calls
appeared inside the helpers (8 − 3 + 2 = 7 raw left). The expansion is real, not bookkeeping: the
commendation roll was one `randi()` inside a `for i in 2` loop and is now
[`"Bug Hunt Commendation: die %d" % (i + 1)`](../../src/core/character/BugHuntCharacterGeneration.gd#L319)
— **one line, two distinct forceable keys**, so a tester can pin each die. A count of raw calls
understates how many *decisions* a mode makes.

⚠ **The 15 positional calls are left raw ON PURPOSE**, and the reason is written at both sites:
5PFH's own `BattlefieldGenerator.gd` has zero `DiceManager` references and seeds a local RNG for
placement. Routing *"which of 16 squares does this marker land on"* would flood the forced-roll
dropdown with entries no tester asked to control, and the seam's whole value is that **every
offered key is one a rule depends on**.

### Step 4 measured OUT: `roll_custom` already honours forcing

The plan's step 4 asked for a new case in `test_dice_forced_results.gd` pinning that
`DiceManager.roll_custom` consumes forced results. Read at the source,
[`roll_custom()`](../../src/core/managers/DiceManager.gd#L217) **already calls `_take_forced`** —
there was nothing to wire. The step is **Done by inspection, not cut**: the routed Bug Hunt helpers
call `roll_d6`/`roll_d100`, whose forcing is what case 1 of the new suite instruments end to end.

ⓘ One latent row noted while reading, **not a defect today**:
[`legacy_randi_range()`](../../src/core/managers/DiceManager.gd#L312)'s `_:` arm forwards to
`roll_custom`, so a future caller of that helper inherits forcing for free.

### New finding **J** — Bug Hunt generated stats were JSON floats, for main characters and grunts

**FIXED this phase.** Case 1 measured it before a type case existed:

```
line 119: Expecting: '1'  but was '1.000000'   (combat_skill)
line 120: Expecting: '4'  but was '4.000000'   (toughness)
```

Godot's JSON parser returns **every** number as a float, so `base_stats` handed back `3.0` for
Toughness and [`_apply_stat_bonuses`](../../src/core/character/BugHuntCharacterGeneration.gd#L305)'s
`+=` kept it one — **a typed local coerces on `+=`, a Dictionary value does not**. Three sites now
coerce: [generate_main_character](../../src/core/character/BugHuntCharacterGeneration.gd#L73)
(5 reads), [_apply_stat_bonuses](../../src/core/character/BugHuntCharacterGeneration.gd#L311)
(**both** operands), and
[generate_grunt](../../src/core/character/BugHuntCharacterGeneration.gd#L197) (5 reads).

⚠ **This is T11-33/T11-34 in a mode nobody had swept.** That defect was found on a real device walk
against the 5PFH ship readout and is recorded verbatim at
[DisplayText.gd:12-17](../../src/ui/components/common/DisplayText.gd#L12): *a value written as 35
comes back as 35.0 and `str()` prints "35.0"*. Fixing it at the **source** rather than at each
renderer is deliberate — the float also reaches `to_dictionary()` and the save, so a renderer-side
fix leaves `"toughness": 3.0` on disk for every Bug Hunt character ever generated. The coercion is
faithful: Bug Hunt stats are whole numbers in the book (Compendium p.171) and int literals in the
shipped JSON.

⭐ **Why a *type* case lives in the *dice* suite.** It needs the forced-roll harness to make a
generated character deterministic, and the seam is what measured it. That is this phase's thesis
demonstrated on itself: **the tooling found the bug on its first run.**

⭐ **The type case asserts its own premise first.** Before testing types it asserts the Ground
Forces row actually granted its `combat_skill +1` — otherwise `_apply_stat_bonuses` is never on the
path and the type assertions would pass while that half of the fix was reverted.

### The QA seam, and the rule that keeps it honest

[`QAScenarioDialog.FORCEABLE_ROLLS`](../../src/ui/screens/dev/QAScenarioDialog.gd#L76) gains **16
Bug Hunt rows**. The plan listed ten tables; six of them — Casualty, Muster Out, Reputation,
Operational Progress, Military Life, Court Martial — are **deliberately absent**, and the reason is
written at the site: their producers do not exist until `BugHuntPostBattleResolver` lands in
Phase 5, and **a row whose key matches no roll is worse than a missing row** — the tester queues a
value, nothing consumes it, and they conclude the rule is broken when it never ran. Case 9
(`test_every_bug_hunt_forceable_key_has_a_live_roll_context`) is what makes that statement
checkable rather than aspirational, and it is arm **G**.

⭐ **Prefix-freedom is a real constraint, discovered while naming a key.**
[`_take_forced`](../../src/core/managers/DiceManager.gd#L102) matches a queued key as a
case-insensitive **substring** of the roll context and returns on the **first** match in
`Dictionary` insertion order. So a key that is a prefix of *another key* silently eats that other
key's queued value. The regiment reroll is therefore named
[`"Bug Hunt Regiment: title reroll"`](../../src/core/character/BugHuntCharacterGeneration.gd#L247)
rather than the natural `"... title part 1 reroll"`, with the ⚠ recorded at the line. Two census
cases pin it: case 10 inside the Bug Hunt block, case 11 across the 5PFH/Bug Hunt boundary in
**both** directions.

⚠ **A key being a prefix of a *context* is fine and intended** — that is exactly how one dropdown
row reaches `"Bug Hunt Support die 1: Air Support"`. Only key-vs-**key** is the hazard, and the two
cases test the right one.

⚠ **The census is a same-line static scan and it says so.** It cannot see a context built with `%`
formatting or assigned to a variable first, so every routed site keeps its literal prefix on the
roll line. A future site that builds its context elsewhere will read as uncovered rather than
silently pass.

**Owner guard.** `QAScenarioDialog.open()` builds the full scenario list only for a campaign that
has `crew_data`; a Bug Hunt core gets the forced-roll section alone, because `QAScenarioLoader`
mutates through 5PFH setters. The predicate is
[`campaign_supports_scenarios()`](../../src/ui/screens/dev/QAScenarioDialog.gd#L136) and it guards
on the **OWNER**, not on a mode flag — the shape this project has now adopted five times, and the
reason T11-49's five consumers went wrong when they asked the question any other way. Cases 12 and
13 drive it against a real `BugHuntCampaignCore`, and case 13 asserts the refusal *text names the
problem* rather than merely being non-empty.

**Dashboard card.** [BugHuntDashboard](../../src/ui/screens/bug_hunt/BugHuntDashboard.gd#L122) gains
a QA card behind `OS.is_debug_build()` — the same gate `CampaignDashboard.gd:262` uses, quoted at
the site — built inside `_build_dashboard()` so the touch sweep Phase 1 added covers it.

### Four findings recorded, not fixed — none is in this phase's file list

| # | Finding | Evidence |
|---|---|---|
| **F** | **Planetfall Class Training is half-routed.** [CharacterTransferService:914](../../src/core/character/CharacterTransferService.gd#L914) calls `dice.roll_d6()` with **no context argument**, so it cannot be forced by key; the random-class follow-up at [:922](../../src/core/character/CharacterTransferService.gd#L922) is a bare `randi_range(1, 6)` with no `DiceManager` at all. A tester can force the aptitude test's *existence* but neither its outcome nor the class it assigns | read at the site |
| **G** | **`QAScenarioLoader._apply_counters` writes to the WRONG campaign.** It applies every counter with `gsm.call(method, ...)` ([:128-142](../../src/core/qa/QAScenarioLoader.gd#L128)), and the `GameStateManager` setters write through to `GameState.current_campaign` — **not** the campaign handed to `apply()`. Harmless today because every caller passes the current campaign; it becomes a silent mis-write the moment one does not | read at the site |
| **H** | **A page cite is off.** [`bug_hunt_special_assignments.json:2`](../../data/bug_hunt/bug_hunt_special_assignments.json#L2) cites *"Compendium pp.181-182"*; the book puts Special Assignments on **p.183**. The *values* are not in question — this is the cite. Fixed in Phase 6 with the rest of the provenance pass, where the extraction is re-run | grep |
| **I** | **`BugHuntCharacterGeneration.gd` carries no page cites at all**, though its Origin / Basic Training / Service History tables are confirmed against **Compendium pp.171-172**. A rules file with no cite is the shape that let `EnemyAI.json` ship the wrong book | grep |

### Detection proofs — 11 arms, every one detected, every file restored byte-identically

Run one arm at a time by a scratchpad harness (not committed — the method is what
transfers, and it is stated in full here). Each arm renames the other twelve cases `off_*` (gdUnit4
discovers on the `test_` prefix), reverts **one** fix from an in-memory byte snapshot, runs, and
restores. Cases 1 and 3 are the harness instrument and the unforced control and are deliberately
not armed.

| Arm | Case | What was reverted | Result | The message that names it |
|---|---|---|---|---|
| **A** | creation rolls forceable end to end | `_roll_d100` body → `randi_range(1, 100)` | `0 err · 7 fail` | `a queued value was never consumed, so at least one context does not match its key: { "bug hunt origin": [1], "bug hunt basic training": [1], "bug hunt service history": [26] }` |
| **B** | generated stats are ints | all three `int()` sites, `+=` restored | `0 · 5` | `main character stat 'reactions' is 1.0, a float and not an int…` — and speed 4.0, combat_skill 1.0, toughness 4.0, savvy 0.0 |
| **C** | signals count → tactical locations | `BugHuntBattleSetup._roll_d6` → unconditional `randi_range(1, 6)` | `0 · 4` | `'6' but was '2'` · `'0' but was '4'` · `'2' but was '1'` |
| **D** | tactical location type forceable | same helper | `0 · 2` | `Expecting: '6'` · `Expecting: 'Delay'` |
| **E** | enlistment pass boundary is exact | `_roll_enlistment_d6` → unconditional `randi_range(1, 6)` | `0 · 3` | `'[6, 1]' but was '[1, 5]'` · `Expecting to be greater than or equal: '7' but was '6'` |
| **F** | a forced refusal reports both dice | same helper | `0 · 1` | `Expecting: '[1, 1]'` |
| **G** | every forceable key reaches a live roll | `_roll_d100("Bug Hunt Origin")` → `"Bug Hunt Beginning"` | `0 · 1` | `FORCEABLE_ROLLS offers keys that reach no roll in src/: ["Bug Hunt Origin"]` |
| **H** | no key is a prefix of another | inserted a `"Bug Hunt Enlistment"` row | `0 · 1` | `forceable keys are not prefix-free: ["Bug Hunt Enlistment -> eaten by -> Bug Hunt Enlistment: die 1", "… die 2"]` |
| **I** | no 5PFH key matches a Bug Hunt roll | inserted an `"Origin"` row | `0 · 1` | `["5PFH 'Origin' would be eaten by Bug Hunt 'Bug Hunt Origin'"]` |
| **J** | the owner guard discriminates four cores | `campaign_supports_scenarios` → `return campaign != null` | `0 · 3` | `a real BugHuntCampaignCore must NOT be supported` |
| **K** | the refusal text names the problem | `unsupported_campaign_text` → `"Not available."` | `0 · 3` | the text must contain `crew_data`, `5pfh-only` and `forcing a roll`; none present |

⭐ **Arm A is the one worth reading twice.** Reverting the routing did not merely change a number:
origin, basic training and service history all landed on *different* random rows together, so the
composite the case asserts decohered. And the assertion that NAMED the cause was none of the six
value comparisons — it was the check that the forced queue was **drained**. A forced value left
unconsumed is the signature of *a context that does not match its key*, and it is the only
assertion in the suite that distinguishes **"routed to the wrong key"** from **"rolled badly"**.
Every routing suite should carry one.

⚠ **Arms C and D share one revert but are separate proofs**, because that helper feeds two rules —
the p.191 signal count and the p.208 tactical-location type. One arm would have left the other
rule's forcing unproven.

⚠ **The harness scores `cases != 1` as "not isolated", never as a pass.** A GDScript parse error
makes gdUnit4 print *"No test cases found"* and **exit 0**, which reads exactly like a clean run;
the population check is what stops an arm being scored against a suite that never ran.

⚠ **Two harness traps cost real time and are worth carrying forward.**

- **Line endings are per FILE, not per repo.** The suite, `BugHuntCharacterGeneration.gd`,
  `BugHuntBattleSetup.gd` and `CharacterTransferService.gd` are LF; `QAScenarioDialog.gd` is
  **CRLF**. A multi-line LF anchor matches **0 times** in a CRLF file, so arms J and K failed
  pre-validation with zero hits. The harness now re-expresses every patch in the target file's own
  endings, idempotently.
- **Escaping runs in two directions inside one string.** In the same patch, `\n` must arrive as the
  two characters *backslash-n* (it is a GDScript escape inside a GDScript literal) while `—`
  must arrive as a real em-dash **byte**. Writing both the same way is a silent no-match — caught
  by pre-validation before any Godot run. The documented `bash -c` heredoc trap ate doubled
  backslashes again on the way; the patches were made with the editor tool instead.

⚠ **And one met while writing this section: the citation lint caught a broken link I had
pattern-matched into place.** Two scratchpad harness scripts were named as citations — the
census script as a markdown link, the detection harness as a code span. The lint existence-checks
any path inside a code span or a link, a scratchpad file is not in the repo, and both FAILED. The
second one I had convinced myself was fine *because it matched an existing line* — but that
line says “reverted from a scratchpad backup” in plain **prose**, which is not a citation
at all. ⭐ **A convention read off one nearby line is a lead, not a rule**; the lint disagreed
in one run. Phases 0-2 cite no harness, and this section now matches them: the method is stated in
full, and no reader is sent after a file that was never committed.

⚠ **A second, sharper one from the same lint: naming its absence-marker in PROSE arms it.** The
marker is line-scoped — the docstring says putting it “anywhere on that line” inverts
the check — and there is no escape for a document that needs to DISCUSS the marker. Writing the
token in the gates row inverted that whole row, so the two citations on it that *do* resolve failed
as “stale marker” while the two that genuinely do not resolve silently passed. ⭐ **A
lint whose control syntax is a bare literal cannot be written about in the documents it lints.**
⚠ Note the failure DIRECTION: the inversion turns *correct* citations red and hides *broken*
ones, so a document that trips it reports the opposite of what it measured. The row now says
“the lint's absence-marker” instead; the two legitimate uses at lines 28 and 570 are
untouched, because there the token is doing its job. ⚠ **The line-scoping has a structural
consequence worth stating: a markdown TABLE ROW cannot be split across lines, so a row can never
mix citations that resolve with citations that do not** — with the marker it fails on the former,
without it on the latter. The only way out is to stop citing the absent ones: name them in prose
and point at the document that carries them as real citations, which is what this row now does.

⚠ **One more trap, met while collecting these gates.** Batch 9 was read as the documented signal-11
crash because its log had no `Overall Summary` line. It had none because **the log was still being
written** — the batch finished a minute later, `286 cases · 0 · 0`. A log tail is a snapshot of a
live file, not a result. Same family as *"settled is not hung"*.

### Phase 3 gates

| Gate | Result |
|---|---|
| Compile guard | **exit 0** — only output is the pre-existing macOS-only `GodotApplePlugins` GDExtension parse line on Windows |
| 8 lints | **all exit 0** — orphan lint `files=560 roots=36 reachable_from_product=560 test_only=0 orphans=0 unwired_rules=0`; multiline lint 910 scripts / 0 findings; dead-`has_method` lint clean |
| Citation lint (a **9th**, not in the gating eight) | **exit 0** on this doc — `ok=256 failed=0 unresolved=0`, up from the `ok=137` Phase 0 recorded. ⚠ A **full** `scripts/lint_audit_citations.py` run exits **1** on `failed=3` in two OTHER audit docs (`CAMPAIGN_DATA_FLOW_SWEEP_2026-08-01.md:7-8` cite the two phase files deleted in `c249e19e3` — precisely the case the lint's absence-marker exists for, and the names are deliberately left un-code-spanned here so this row does not inherit their absence; `BATTLE_PHASE_DELIVERY_AUDIT_2026-08-06.md:35` cites a plan file, and plans live outside the repo). Both are tracked and unmodified, so they are **pre-existing and out of this sprint's file list** — recorded rather than silently scoped away |
| `tests/unit`, 10 headless batches of ≤35 | **3416 cases · 0 errors · 0 failures · 0 flaky** (430 · 302 · 373 · 464 · 479 · 387 · 350 · 338 · 286 · 7). **No signal-11 cliff this run** — batch 9 completed, so the 18+17 split Phase 2 needed was not required |
| **Count arithmetic** | **`3403` (Phase 2) `+13` (`test_bug_hunt_dice_routing.gd`) `= 3416`. Measured: 3416.** ✓ |
| Suite arithmetic | **318** `test_*.gd` files under `tests/unit`, **315 executed**. The three non-executors are all pre-existing and named: `test_sheet_source_paths_resolve.gd` (NEEDS_DISPLAY — it builds a real `SheetRenderer` and segfaults headless, so it is excluded from the list by design) and **two zero-case stubs**, `ui/panels/test_config_panel.gd` (27 lines, 0 `func test_`) and `ui/screens/campaign/test_upkeep_phase_ui.gd` (**0 bytes**). ⚠ An empty file under `tests/unit` reads as coverage that does not exist — the *"a test that asserts nothing is a false green"* family. Recorded, not this sprint's to fix |
| Post-edit isolated re-run | **13/13 · 0 · 0.** The suite's failure-message text was corrected AFTER its batch had already completed, so it was re-run alone to confirm: no case-count or pass/fail effect |
| Detection proofs | **11/11 detected**, each run alone, reverted from an in-memory snapshot (**never** `git restore`), all five touched files verified byte-identical afterwards by md5 |
| Data diff | **Phase 3 touches no data file.** `git diff -- data/` still shows only the other instance's `data/black_zone_jobs.json`, present in the session-start porcelain |
| Concurrency | porcelain checked at phase start; this phase's contribution is **13** cases in one new suite, and no file in its list overlaps the other instance's uncommitted paths |

⚠ **One gate is weaker than it looks and is stated rather than hidden:** the 13 new cases pin the
STATE the routing leaves behind — which context string a roll carries, which key consumes it, what
the guard returns. **Godot delivers no `InputEvent`s headless**, and no case here presses the QA
card. That the dashboard card opens the dialog, and that a queued value survives to the table a
tester is actually watching, is owed to the **device walk in Phase 7**.

---

## ✅ CONFIRMED-OK — correct code, recorded so nobody "fixes" it

This section is as load-bearing as the defects. §C4 failed by recording "verified" without checking
delivery; these rows were checked **both** ways.

- **All 30 creation-table rows** (Origin 13 / Basic Training 9 / Service History 8) exact **and
  applied** — `BugHuntCharacterGeneration.gd:103` applies stat bonuses, advantages and the 2D6
  Combat-Operations commendation.
- **All 12 Special Assignments** exact, **applied, and persisted** — compound requirements
  ("Reactions *or* Combat Skill 2+"), every "if currently lower than N" cap, and the once-per-career
  rule. This was a *suspected* defect and is **REFUTED**.
- **All 12 Support options** exact and **live** — 2D6 against the right target, the point correctly
  burned on failure, once-per-mission enforced.
- **Weapons 60/60 fields**; enemy table 16/16 rows; variants 6/6; pack leaders 6/6; Movie Magic 10/10.
- Priority `mini(d1,d2)` with +1 Vital / +2 Critical and clamp 1-6; Spawn Rating
  `clampi(priority-1, 0, 3)`; initial contacts `objectives + 1` with the difficulty modifier — all correct.
- D100 last-row ranges encode **100**, not 0 — no off-by-one anywhere in the tables.
- **Stars of the Story and Story Points are correctly EXCLUDED** per Compendium p.214 — documented
  at `src/core/character/CharacterTransferService.gd:29`. Do not "fix" this.
- Enlistment target is **7** (`CharacterTransferService.gd:36`), matching p.212. The skill doc
  saying 8 is wrong — see below.
- Campaign-journal integration works; `"bug_hunt"` is a registered journal tag.
- **Panel-owned completion already works, and Advance is already navigation-only** (MEASURED
  2026-09-19, cases 0-3). Special Assignments completes through the panel's own control, and
  `BugHuntTurnController._on_navigation_updated` (`:365`) drives the Advance button from
  `can_forward`. All four completion paths are detection-proven by isolated revert:
  `SpecialAssignmentsPanel.gd:348` (the bare in-panel call), `:115` (the Skip lambda),
  `BugHuntTurnController.gd:404` (`go_to_phase(POST_BATTLE)`), and
  `BugHuntPostBattlePanel.gd:158` (the Complete lambda).
  - ⚠ **This corrects a "soft-lock" claim made earlier in the Sprint 1 plan, and the reason it was
    wrong is the transferable part.** The grep that produced it searched for `complete()` **call
    sites on a panel reference** and so found only `BugHuntTurnController.gd:321` — it was
    structurally blind to a panel calling its own bare `complete()` and to calls inside lambdas.
    A zero-result grep for "who else calls this?" is an **ambiguity**, not a finding; here it read
    as "only Advance can complete a phase" when it meant "my pattern does not match the three other
    shapes this codebase uses".
  - ⭐ The cases written to prove the soft-lock instead found the turn-completion defect recorded
    above, which is a worse bug than the one they were aimed at.

---

## Stale documentation corrected alongside this audit

| Doc | Was | Reality |
|---|---|---|
| `docs/QA_RULES_ACCURACY_AUDIT.md:1238` | §C4 rows C4-001…C4-019 all "VERIFIED" | Superseded by this file. C4-001 cites a nonexistent file |
| `docs/gameplay/COMPENDIUM_IMPLEMENTATION.md:1318` | *"Bug Hunt Campaign Variant ❌ NOT IMPLEMENTED"* | Shipped; contradicts `docs/COMPENDIUM_CHAPTER_TRACE_2026-08.md:216` |
| `.claude/skills/bug-hunt-gamemode/SKILL.md` | enlistment "2D6 + Combat >= **8**"; a `_bug_hunt_returning` flag | Target is **7**; that flag has **zero matches repo-wide** |
| `docs/technical/SCREEN_MAP.md:558` | wizard step 4 is `FinalReviewPanel` | The class is `BugHuntReviewPanel` |

---

## How to read this ledger

**Do not read the OK section as "Bug Hunt is mostly fine."** The data layer is in excellent shape
and the delivery layer is not. A player can create a squad correctly, take a Special Assignment
correctly, roll Support correctly — and then fight a battle under 5PFH's rules, score no objectives,
be told they were court-martialled, pay Reputation to avoid a punishment that was never coming, and
play a campaign that cannot be won.

**The going-forward guard is not this count.** It is:

1. A **chokepoint** for Bug Hunt battle results, the way `BattleResultNormalizer` is for 5PFH —
   twelve key mismatches is one missing chokepoint, not twelve mistakes.
2. `_source` keys on `data/bug_hunt/*.json` so a lint can check a cite.
3. A consumer census test in the shape of
   `tests/unit/test_final_partial_rows.gd:83` — a `{accessor: consumer_file}` map asserting the
   **comment-stripped** consumer source actually calls it.

## Audit method and its own verification

- Walked by printed page, not by subsystem — *a subsystem census cannot see a chapter that is
  nobody's subsystem*, which is how the Aug 2026 audit missed pp.12-62 of the Core Rules.
- Book text via PyPDF2 only. Compendium offset −1, verified on three pages.
  `docs/rules/bug_hunt_compendium_extract.txt` is complete for the chapter but uses **1-based PDF
  pages** — printed = marker − 2.
- Every `path:line` in this file is machine-checked by `scripts/lint_audit_citations.py`, which
  asserts the file exists and has at least that many lines. **This is the specific check that would
  have invalidated §C4 in March.**
- "No consumer" claims were verified with comment-stripped greps — `lint_orphan_assets.py` once
  counted a file's own obituary comment as a live reference.

## 🔬 HEADLESS VERIFICATION (2026-09-10, after the desk pass)

The desk audit was re-run against the **running engine** before any device work, on the
principle this project already records: *implementation is not delivery, and a harness can
measure the right size and the wrong screen.* `tests/tools/probe_bug_hunt_desk_walk.gd`
drives the real classes rather than reading them, so every number below is **observed**.

It is an instrument, not a test — it asserts nothing. A row it contradicted was corrected
rather than defended; two were.

**Gate state at the time of the run:** headless boot parse-clean (the only error is the iOS
GDExtension having no Windows binary, expected on this platform), and the six Bug Hunt-adjacent
and concurrently-modified suites pass **113 cases / 0 failures**.

### Rows upgraded from desk-derived to MEASURED

| Row | Measured |
|---|---|
| Phantom spawn points | `spawn_rating` **0 → 2** points, 1 → 3, 3 → 5. `base_count` confirmed absent from `bug_hunt_spawn_rules.json`, whose real keys are `description`/`spawn_rating_description`/`phases`/`closing_down`. A rating of 0 can never disable spawning |
| Signals never resolve | **3 of 3** generated Signals have an empty `result`, while **6** `signal_table` rows sit unused in the data file |
| Aggression / Chance dice | the generated battle context carries `aggression_dice Dict(0)` and `chance_dice Dict(0)` — **empty**, confirming the `contact_markers.aggression` key mismatch at runtime |
| 5-main-character option | asked for 3 → 3, 4 → 4, **5 → 4**. The book's fifth slot is unreachable |
| Sick Bay one turn short | `add_to_sick_bay("x", 3)` → `{"x": 3}`; one `tick_sick_bay()` → `{"x": 2}`. `BugHuntPhaseManager._apply_post_battle_results()` does both in one call |
| Muster-out past 15 | 8 → target 9, 12 → target 7, 15 → `null` (Automatic), **16 → NO ROW MATCHED**, 20 → NO ROW MATCHED. Veterans become immortal at 16 |
| `missions_in_current_operation` | still **0** after a complete turn — the book's R&R trigger never moves |

### Corrections to the desk ledger

- **The battle context has 16 keys, not 15.** Sorted: `aggression_dice`, `armor_table`,
  `battle_mode`, `chance_dice`, `contact_markers`, `contact_table_rules`, `gear_table`,
  `no_morale`, `objective`, `priority`, `signals`, `spawn_points`, `spawn_rating`,
  `tactical_locations`, `terrain_theme`, `weapons_table`. The "only `battle_mode` is read"
  finding is unchanged; the count was wrong.
- **The float render is three fields, not one.** Measured: `experience.awards[].xp` → `"1.0"`,
  `advancement_costs[].xp_cost` → `"8.0"`, `advancement_costs[].max_value` → `"4.0"`. This is
  therefore **desk-measurable and no longer owed to the device walk.**

### Three findings the headless run ADDED

| Bucket | Finding | Site |
|---|---|---|
| ⚫ NEVER-FIRES | **`set_combat_teams()` has zero callers repo-wide**, so `combat_teams` is never populated — it is serialized by `to_dictionary()` and restored by `from_dictionary()` and is always empty. This *strengthens* the reaction-dice row: even a correct p.198 implementation ("one die per main character **plus one per combat team**") could never award a team die, because there are no teams | `BugHuntCampaignCore.gd:160` |
| ⚫ NEVER-FIRES | **`BugHuntCampaignCore.validate()` and `get_validation_errors()` have zero callers.** The p.170 five-main-character cap message is written, page-cited, and unreachable. `BugHuntReviewPanel` does not call it — it carries a **private duplicate**, `_get_validation_errors(config, characters)`, with a different signature that never touches the core. Contrast Tactics, which wires its coordinator's version into two panels. This is the project's signature shape: correct code, no call site | `BugHuntCampaignCore.gd:281`, `BugHuntReviewPanel.gd:127` |
| 🟠 WRONG-VALUE | **The default difficulty matches no enemy modifier.** A fresh `BugHuntCampaignCore` is `difficulty = "mess_me_up"`; `bug_hunt_enemies.json` offers `im_too_pretty_to_die`, `standard`, `mega_violence`, `living_nightmare`. `bug_hunt_missions.json` uses the other vocabulary — `hey_not_too_crazy`, `mess_me_up`. So the **default** difficulty can never match an enemy difficulty modifier. Sharper than the desk row, which recorded only that the id sets differ | `BugHuntCampaignCore.gd:27`, `bug_hunt_enemies.json` |

### PANEL HARNESS (`tests/tools/probe_bug_hunt_panels.gd`, gdUnit4)

The `--script` probe above cannot touch the panels — they resolve autoloads, and such a probe
measures a tree its own setup never touched. gdUnit4 **does** register autoloads, so this
harness builds the real screens. **9 cases, 0 failures — but read the printed block, not the
pass count:** its assertions are deliberately confined to "the panel builds", because a test
that asserted today's behaviour would pin these defects in place and turn the fix sprint red.

**All 8 panels instantiate and build.** `CharacterTransferPanel` produces **0 text nodes**
(2 children) — worth a look on the device walk.

#### ⭐ ROOT CAUSE FOUND: the battle → post-battle boundary speaks the wrong vocabulary

This supersedes three separate desk rows with one cause. The harness feeds the panel the
payload `TacticalBattleUI` **actually** emits (`TacticalBattleUI.gd:6866`, routed through
`_on_delegated_battle_completed` → `temp_data["bug_hunt_battle_result"]` →
`BugHuntTurnController.gd:401`). It carries **18 keys, all in 5PFH vocabulary**:

```
auto_resolved, crew_alive, crew_casualties, crew_casualties_data, crew_injuries,
crew_injuries_data, crew_participants, defeated_enemies, enemies_defeated_count,
enemies_remaining, held_field, objective_id, objective_met, objective_progress,
rounds_fought, success, victory, won
```

`BugHuntPostBattlePanel` reads **`casualties`**, **`objectives_completed`** and
**`lost_marines`**. *None of the three is in that list.* All three take a silent default.

⭐ **Bug Hunt reuses `TacticalBattleUI` but never adapted to its result vocabulary — and it is
the one mode that does not pass through `BattleResultNormalizer`, the chokepoint whose entire
job is to stop exactly this.** That is the axis-B finding stated as precisely as it can be.

⚠ **A grep for the producer is actively misleading here.** `BugHuntMissionPanel.gd:452` and
`:497` *do* write `"objectives_completed": 1` — but both sit in **unreachable fallback
branches** (one if `BugHuntBattleSetup` fails to load, one if `SceneRouter` is missing). The
live path navigates to the battle and deliberately does not complete. So a reader who greps
`objectives_completed`, finds two writers, and concludes it is wired would be wrong twice over.

#### Measured panel behaviour

| # | Measurement | Result |
|---|---|---|
| P3 | Post-battle panel driven with a **victorious** battle result that named **1 casualty** | prints **"No casualties this mission. Outstanding!"** — the panel reads `casualties`, the battle wrote `crew_casualties_data` |
| P4 | Court Martial across 20 runs | fired **20 of 20**. On all **7** GUILTY verdicts, `_results.mustered_out` stayed `[]` — the removal at `:642` is a comment. The 3-Reputation buyout is the only thing that really happens |
| P5 | `completed_missions_count` after **one** mission | **+2** (panel step 2, then `BugHuntPhaseManager._apply_post_battle_results`). Measured twice from different baselines: 0→2 and 2→4. Book p.203 says +1 |
| P6 | Muster-out for a veteran | tally 14 → step 2 stores 15 → step 3 checks **16**; tally 15 → checks 17; tally 16 → checks 18. **No muster line rendered at all in any case — the check is skipped** |
| P7 | XP advancement, character with **9 XP** | **15** advance buttons offered; pressing four took the character to **−19 XP**. No re-check between purchases |
| P8 | Campaign Escalation priority, turns 1-8 | **`[3, 3, 3, 3, 3, 3, 3, 3]`** against the book's `[1, 1, 2, 2, 3, 4, 5, 6]`. The harness prints both key names: `campaign_escalation` (asked for) **absent**, `campaign_escalation_option` (in the data) **present** |
| P9 | Hand Cannon swap, "One MC only" (p.187) | 4 checkboxes offered, **4 stayed pressed**. `hand_cannon_assigned` is a **local** (`BugHuntMissionPanel.gd:284`) captured **by value** into each lambda, so no checkbox can see another's assignment |

#### ⭐ Sharper than the desk row: muster-out is unreachable from 14 upward

Three defects compound, and the harness shows the arithmetic. `_update_completed_missions()`
(step 2) increments the stored tally; `_process_mustering_out()` (step 3) then computes
`completed_missions_count + 1` — *"including this mission"* — on a tally that already includes
it. So a character stored at **14** is checked at **16**, sailing straight past the
`completed_missions: 15` **Automatic** row, and 16+ matches no row at all, leaving
`threshold = 0` and hitting `elif threshold <= 0: continue`.

**The automatic muster-out at 15 is therefore unreachable, and no character can muster out at
any tally above it.** The desk ledger recorded only the 16+ half.

#### Two harness bugs caught and fixed, recorded so the numbers can be trusted

- The first run reported **GUILTY 20 of 20** for a 1-in-6 roll. The detector matched
  `"guilty"`, which is a **substring of "Not guilty"** — it could not distinguish the two
  outcomes. Corrected to the guilty branch's exact wording; the honest figure is **7 of 20**.
  An impossible number is the tell; *a diagnostic that cannot disagree proves nothing.*
- P9 first reported **0 Hand Cannon checkboxes**, which reads exactly like "the control does
  not exist". `refresh()` only *clears*; `_generate_mission()` builds the loadout. The probe
  had never delivered its own stimulus. With it delivered: 4 offered, 4 accepted.

### Two things the probe did NOT find, recorded so they are not re-reported

- **The journal errors in the probe log are a probe artifact, not a defect.**
  `Can't use get_node() with absolute paths from outside the active scene tree` fires from
  `BugHuntPhaseManager._journal()`. The tell is in the probe's own output: the autoload banners
  (`[T11-07]`, Steam, Talo) print **after** the probe's `END` marker, so the autoloads had not
  initialised while it ran. This is the documented `--script` trap, not a product condition.
- **The Hand Cannon by-value capture is now MEASURED**, not code-read — see P9 above.
- **"0 grunts" was the probe's own fault.** `generate_squad()` genuinely returns no `grunts` key,
  but `BugHuntCreationCoordinator.gd:113-114` calls `generate_fire_team(4)` and assigns
  `campaign.grunts` directly. The probe did not replicate that, so its zero is meaningless.
  (Worth one small DRIFT note: `initialize_squad(mc, [])` passes a hardcoded empty array and the
  grunts are then written straight onto the property, bypassing the owner setter.)

## Still owed

**A device walk.** `src/ui/screens/mainmenu/MainMenu.gd:20` has `const A1_BUILD := true`, which
rebinds the Bug Hunt button to a "coming soon" note — Bug Hunt is currently unreachable from the
main menu, and the only live route is the store screen. Every finding above is desk-verified.
The delivery-layer defects that static analysis structurally cannot see — touch scroll on the
bare-`Control` panels and tablet layout — need hardware. (The "4.0" render was owed to the
device and is now measured at the desk; see the headless section above.)
