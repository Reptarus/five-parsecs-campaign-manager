# Compendium chapter trace — Aug 3 2026

Every chapter of the Compendium, walked producer → key → consumer by hand against
the TOC on pp.4-5 of `docs/rules/Five Parsecs From Home-Compendium.pdf`. No agents,
no fan-out; each row below was confirmed by opening the file.

**The question each row answers is not "does a file exist" but "does a live path
reach the player".** A gated getter that loads book-exact data and is called by
nobody is indistinguishable, from the player's seat, from a feature that was never
written — and it is worse for us, because it looks finished in every inventory.

## Verdict

| | Chapters |
|---|---|
| **LIVE** — a live path reaches the player | 26 |
| **PARTIAL** — some of the chapter lands, a named part does not | 0 |
| **DEAD** — data + gated API exist, nothing reaches the player | 4 |

Casualty Tables, Detailed Injuries, Dramatic Combat and Loans all moved to LIVE
on Aug 3. Each fix is described in its section below — and every one of them was
a defect that **call-site tracing cannot see**, which is what the original pass
did. Trace to the value.

All 4 remaining dead chapters are **Freelancer's Handbook** — PvP (pp.35-38),
Expanded Co-op (pp.39-41), AI Variations (p.42) and Grid-based Movement
(pp.90-93). Three of those four need a second player or a movement layer this
app does not have; only Grid-based Movement is a pure wiring gap.

> ### ⛔ Two rows in the first version of this table were WRONG, in the same way
>
> Fringe World Strife and the 12 Difficulty Toggles were both published here as
> LIVE. Both are dead, and the existing audit ledger already said so; the trace
> and the ledger disagreed and the ledger was right.
>
> The error is one step short of the finish line: **I found a caller and stopped.**
>
> - Strife: `WorldPhaseController.gd:648` really does call `should_check_strife`
>   — with `world_phase_data.get("is_fringe_world", false)`, and
>   **`is_fringe_world` is written nowhere in the repository.** The argument is
>   permanently false, so the call returns at its own guard, every turn, forever.
>   A caller is not a consumer if its argument is a key nobody writes.
> - Toggles: four resolvers preload `compendium_difficulty_toggles.gd`, which
>   looked conclusive. They call `get_adjusted_shooting_thresholds()`,
>   `roll_casualty()` and `roll_detailed_injury()` — Dramatic Combat and the
>   Casualty tables, which live in the same file. **Not one of the twelve toggle
>   ids** (`strength_adjusted`, `slaves_to_stargrind_money`, `veteran`,
>   `actually_specialized`, `armored_leaders`, `better_leadership`,
>   `paying_by_hour`, `movement_all_over`, `fickle_scans`, `starting_gutter`,
>   `reduced_lethality`) **appears anywhere in `src/`.** A shared data file makes
>   one chapter's consumers look like another's.
>
> Trace to the value, not to the call site.

---

## Character Options (pp.11-28) — Trailblazer's Toolkit

| Chapter | Verdict | Consumer evidence |
|---|---|---|
| Krag p.12 | LIVE | `compendium_species.gd:78`, `Character.gd:506`, `CharacterGeneration.gd:1134`, `UpkeepPhaseComponent.gd:2000`, `FiveParsecsCharacterData.gd:339` |
| Skulkers p.14 | LIVE | same five sites, Skulker branch |
| New Primary Alien Table p.16 | LIVE | `CompendiumDataProvider.gd:148` `"primary_aliens"`; `SpeciesDataService.gd:22`; `SimpleCharacterCreator.gd:295` |
| Psionics pp.17-24 | LIVE | `PsionicSystem.gd` + 7 consumers (`PostBattlePhase`, `TacticalBattleUI:3324`, `UpkeepPhaseComponent:2577`, `WorldPhase:381`, `PreBattleChecklist:415`, `PsionicLegalityBadge`, `CharacterTransferService`) |
| New Training p.25 | LIVE | `compendium_equipment.get_advanced_training()` → `get_advancement_phase_items()` → `AdvancementPhasePanel.gd:6` |
| New Bot Upgrades p.26 | LIVE | → `get_advancement_phase_items()` → same panel |
| New Ship Parts p.27 | LIVE | → `get_trade_phase_items()` → `TradePhasePanel.gd:6` |
| Psionic Equipment p.27 | LIVE | → `get_trade_phase_items()` → same panel |

The four New Kit flags reach the player only through the three **aggregators**
(`get_trade_phase_items`, `get_trade_phase_items_with_lock_status`,
`get_advancement_phase_items`). Searching for callers of `get_bot_upgrades()`
directly finds none and reads as dead — it isn't. Trace the aggregator, not the
getter.

## Game Options (pp.29-102) — Freelancer's Handbook

| Chapter | Verdict | Evidence |
|---|---|---|
| Progressive Difficulty p.30 | LIVE | `ProgressiveDifficultyTracker` → `EnemyGenerator`, `TacticalBattleUI:6652` |
| Difficulty Toggles pp.32-34 | **LIVE (fixed Aug 3)** | all 12 ids were read NOWHERE, and the creation selection never even left the panel — `CampaignCreationCoordinator.update_campaign_config_state` is a whitelist that did not name the key. Now: whitelist → `campaign.progress_data["difficulty_toggles"]` → `CompendiumDifficultyToggles.is_toggle_active()`, the one call every rule site reads. **Known partial:** Starting in the Gutter applies 3 of its 4 clauses — see below |
| **Player vs Player pp.35-38** | **DEAD** | `get_pvp_setup` / `get_pvp_rules` / `roll_pvp_battle_reason` / `roll_pvp_third_party` (`compendium_missions_expanded.gd:319/326/333/346`) — **zero callers repo-wide, tests included.** No PvP surface exists |
| **Expanded Co-op pp.39-41** | **DEAD** | `get_coop_setup` / `get_coop_rules` (`:359/:366`) — zero callers |
| **AI Variations p.42** | **DEAD** | `roll_ai_behavior` / `get_ai_behavior` (`compendium_difficulty_toggles.gd:150/161`) and the `AI_VARIATION_TABLES` getter (`:91`) — zero callers |
| Enemy Deployment Variables pp.44-45 | **LIVE (fixed Aug 3)** | the missing loader is `src/data/compendium_deployment_variables.gd`; the roll fires from `TacticalBattleUI._on_initiative_calculated`, the exact moment p.44 keys it to |
| Escalating Battles p.46 | LIVE | `EscalatingBattlesManager` → `TacticalBattleUI:6091`, `BattleRoundHUD` |
| Elite-level Enemies pp.48-65 | **LIVE (fixed Aug 3)** | was never loaded AND only 40% present. Data completed from the PDF (82 profiles, five tables, each spanning 1-100); `src/data/compendium_elite_enemies.gd` loads it and `EnemyGenerator._roll_enemy_in_category` performs the p.48 substitution. See "the incomplete table is worse than the dead one" below |
| No-minis Combat pp.66-73 | LIVE | `NoMinisResolver`, `BattleResolverRouter:38`, `NoMinisCombatPanel`, `TacticalBattleUI:6741` |
| Expanded Missions p.74 | LIVE | five roll functions consumed by `JobOfferComponent.gd:1649-1669` |
| Expanded Quest Progression pp.78-80 | **LIVE (fixed Aug 3)** | data complete, readers correct, zero callers — the missing piece was STATE. A Quest step is a standing obligation ("until this has been done, you cannot progress the Quest"), which a stateless roller cannot express. New `src/core/campaign/ExpandedQuestProgression.gd` holds the p.78 gate (replacing the core p.120 mapping AND its p.119 travel roll at `RivalPatronResolver`), the pending step at `progress_data["expanded_quest"]`, a producer for each of the seven blocking rows, and the two permanent modifiers into `EnemyGenerator` / `BattleSetupRules`. See below |
| Expanded Connections pp.80-86 | **LIVE (fixed Aug 3)** | same shape: 30 complete subtable scenarios, three correct readers, zero callers. New `src/core/campaign/ExpandedConnections.gd` runs the p.80 1D6 check in the Mission Prep step (the book's own "while establishing the objectives and parameters"), the D6 main table into one of five subtables, the automatic first-game Connection, the `*` decline, the one-turn expiry, and the no-roll / variety-swap variations as real settings. **`src/core/character/connections/CharacterConnections.gd` is a DIFFERENT system** — creation-time starting contacts — and is still referenced by nothing |
| **Dramatic Combat pp.87-89** | **PARTIAL** | Adjusted Shooting is applied by all four resolvers and the rule text renders (`TacticalBattleUI:6113`). The **Dramatic Weapons stat table pp.88-89** does not: `get_dramatic_weapon_stats()` and `get_dramatic_effect()` have zero callers |
| **Grid-based Movement pp.90-93** | **DEAD** | `TacticalBattleUI.gd:6123` reads `mission_dict["grid_movement_instructions"]` — **zero producers.** `BattlefieldGrid.gd` is table geometry (p.108 sizes), not this chapter |
| Terrain Generation pp.94-98 | LIVE | `FPCM_BattlefieldGenerator` + `data/battlefield/themes/compendium_terrain.json` |
| Casualty Tables pp.99-100 | **LIVE (fixed Aug 3)** | `roll_casualty(category, is_boss)` now reads the real `casualty_tables` data. Auto-resolve applies it at `TacticalBattleUI:5488`; the played path gets the rules text from `CheatSheetPanel`, which is the correct delivery for a table the player rolls themselves |
| Detailed Post-Battle Injuries pp.101-102 | **LIVE (fixed Aug 3)** | `roll_detailed_injury()` now rolls D100 against `roll_min`/`roll_max`, and `InjuryProcessor.process_single_injury` uses it **in place of** the Core Rules table for organic characters (bots stay on the p.122 Bot table, per p.101) |

## Scenarios & Settings (pp.103-160) — Fixer's Guidebook

| Chapter | Verdict | Evidence |
|---|---|---|
| Introductory Campaign pp.104-109 | LIVE | `IntroductoryCampaignManager.gd:58/:77`, `JobOfferComponent.gd:1603` |
| Expanded Factions pp.110-115 | LIVE | `FactionSystem` (autoload), 9 gate sites |
| Mission Selection p.116 | LIVE | superseded by `JobOfferComponent`; the old `MissionSelectionUI` and its route were deleted with evidence (`WorldPhaseController.gd:2013-2018`) |
| Stealth Missions pp.117-122 | LIVE | `StealthMissionGenerator` + `StealthResolver` + `StealthMissionPanel` |
| Street Fights pp.123-136 | LIVE | `StreetFightGenerator` + `StreetFightResolver` + `StreetFightPanel` |
| Salvage Jobs pp.137-147 | LIVE | `SalvageJobGenerator` + `SalvageResolver` + `SalvageMissionPanel` |
| Fringe World Strife pp.148-151 | **LIVE (fixed Aug 3)** | four independent faults at the one call site, and fixing all four would still not have produced the chapter — its engine, a per-world Instability score, did not exist. New `src/core/world/FringeWorldStrife.gd` holds the arrival 1D6, the accumulator, the ≥10 D100 and the "NA" stop-tracking rows. See below |
| **Loans pp.152-156** | **PARTIAL** | Steps 1/3/4 live via `TradePhasePanel.gd:828-832`. **Step 2 is a hardcoded constant** — see below |
| Name Generation pp.157-160 | LIVE | `compendium_world_options` name tables + `CharacterGeneration.gd:456`, `ContactManager.gd:311` |
| Bug Hunt pp.161-223 | LIVE | full gamemode, separate architecture |

---

## The three PARTIAL rows, in detail

### FIXED Aug 3 — the reader that disagreed with its own data

Both of these were listed here as PARTIAL, on the evidence that their call sites
sat in the auto-resolve branch. That was true and it was not the real problem.
**Neither table had ever produced a single result in any battle**, because each
reader was looking at something its own data file does not contain:

- `roll_casualty()` read `casualty_table` — whose value in
  `difficulty_toggles.json` is the empty array `[]`. The real pp.99-100 data has
  always been in **`casualty_tables`**: three tables (humanoid / cybernetic /
  beast) with `regular` and `boss` COLUMNS, not a flat `roll` field. Iterating
  the empty array returned `{}` every time, so `casualty_check.is_empty()` at the
  call site was permanently true and the code always fell through to the Core
  Rules D6.
- `roll_detailed_injury()` rolled **2D6 — a 2..12 range — against a D100 table**,
  then matched `entry.roll`, a key those rows do not have (they carry `roll_min`
  / `roll_max`). Either fault alone guaranteed `{}`.

Neither is findable by tracing call sites, which is exactly how both survived the
chapter-level pass that checked call sites. **Trace to the value.**

Both are now wired: `roll_casualty(category, is_boss)` reads the real tables and
honours the boss column; `roll_detailed_injury()` rolls D100 against the spans;
and `InjuryProcessor.process_single_injury` uses the p.102 table *in place of*
the Core Rules one for organic characters, with bots still routed to the p.122
Bot table per p.101. Pinned by `tests/unit/test_compendium_casualty_and_injury.gd`
(18 cases, revert-proven: restoring the 2D6 reader fails it 1802 times).

Three parts of p.102 are recorded but NOT auto-applied, and the code says so at
the site rather than pretending: **Injured arm** (CS -1 only "when firing a
non-Pistol weapon or when Brawling"), **Injured torso** ("knocked out after two
Stun markers, instead of the customary three") and the **Lingering injury**
pre-mission 1D6. All three are conditional rules the unconditional modifier
channel cannot express, and applying them as flat numbers would be HARSHER than
the book. They surface as character-sheet text with the rule quoted — the correct
delivery for a tabletop companion — and need a per-attack / stun-threshold /
pre-deployment hook before they can fire automatically. **Injured leg** (Speed -1)
IS applied, because that one maps exactly onto the existing live gate.

### Superseded note — what the PARTIAL verdict said

Both fire from exactly one place, `TacticalBattleUI:5488` / `:5496`, and that block
sits inside the **auto-resolve** branch — it reads `resolver_result` and walks
`crew_units_final`. `InjuryProcessor`, which owns the post-battle injury step on the
**played** path, contains no reference to the Compendium tables at all.

For a tabletop companion this is the wrong way round: playing the battle on the
table and recording the result is the primary path, and it is the one that silently
falls back to the Core Rules D6 death check. The player who bought the pack sees the
new tables only when they let the app resolve the fight for them.



### Loans Step 2 — the amount is invented (p.152)

The book:

> "The base value of the loan will be **the cost of the ship in question, as
> indicated on p.31 of the core rules**. […] • Unity Program loans must add **+5
> Credits** due to fees and paperwork. • Free Trader or Suspicious Character loans
> must add **+1D6 Credits** due to personal whims."

`TradePhasePanel.gd:835` is `var loan_amount: int = 20`. Steps 1, 3 and 4 all roll
correctly and feed a loan whose principal is a constant, so the two
origin-conditional modifiers — the only place the chapter's five origins differ in
*cost* rather than flavor — have no implementation. A Unity loan and a Suspicious
Character loan are financially identical.

### Fringe World Strife — the wrong mechanism, not a missing key (p.148)

Adding an `is_fringe_world` producer would NOT fix this chapter. The book never
asks whether a world "is a fringe world":

> "If using this system, when arriving on a new world, **roll 1D6. A roll of 4+
> indicates the world is Unstable.** You may opt to use a 5+ roll if you prefer a
> less chaotic environment."
>
> "An Unstable world always maintains an **Instability score** […] When you arrive
> on the world, it begins at **+1**. During the **Invasion step of every campaign
> turn, add 1D6** to the total. Adjust by an additional **+1 for every active Rival
> on this world**. Subtract **-1 if you completed a Patron job** this campaign
> turn. Subtract **-1 if you Held the Field against a Roving Threat** this campaign
> turn. If this causes Instability to reach or **exceed 10**, make a D100 roll on
> the table below, **reduce the Instability score by the amount listed**, and apply
> the listed effect."

What exists is a boolean gate plus an immediate D100 on arrival. What the chapter
actually is: an arrival 1D6 (4+, player-selectable 5+), a **per-world persisted
Instability score**, a per-turn accumulator with four modifiers running in the
Invasion step, and a ≥10 threshold that fires the D100 *and decrements the score by
the row's listed amount*. The accumulator is the engine of the whole chapter and has
no implementation at all — which is why `Instability tracking — Compendium p.148`
is a separate OPEN row in the audit ledger.

This is the reason the chapter is on the hide list rather than the quick-fix list.

### FIXED Aug 3 — Dramatic Combat's weapons table, and why it had no consumer

`get_dramatic_weapon_stats(weapon_id)` had zero callers. Chasing that turned up a
much larger defect underneath it: **no combatant had a weapon at all.**

`BattleResolver` reads `attacker["weapon"]` at exactly two sites and nothing
anywhere wrote it. `initialize_battle` pulled armor and screens out of
`equipment` and never a weapon; `Character.to_dictionary()` emits `equipment` (an
Array of item *names*) with no `weapon` key; enemies carry `weapons` — plural, an
Array of names — while the attack loop reads `weapon`, singular. So
`attacker.get("weapon", {})` was `{}` in every auto-resolved battle ever played,
and every attack used the defaults:

```text
range 12"    shots 1    damage 1    traits []    logged "Unknown Weapon"
```

A Hand Cannon (damage 2, 8") and a Hand Gun (damage 0, 12") were mechanically
identical, a Machine Pistol fired one shot instead of two, and every weapon trait
in the game — Focused, Piercing, Critical, Snap Shot, Heavy, Burn, Hot — was
inert, because the trait list was always empty. The Overheat and Focused handling
in `BattleResolver` is written correctly and simply had no data to act on.
`"Unknown Weapon"` in the battle log was the visible symptom.

`initialize_battle` now resolves each figure's profile from
`equipment_database.json` and the pp.88-89 table overlays at that same point, so
the chapter has its consumer. Pinned by `tests/unit/test_battle_weapon_profiles.gd`
(10 cases).

---

## Two chapters where the gate was not the problem (Aug 3)

**Fringe World Strife (pp.148-151).** The 10-row D100 table has been complete
and byte-correct in `world_options.json` since it was written, and the chapter
never ran once, for four independent reasons at the one live call site — each
fatal on its own:

1. it gated on `world_phase_data["is_fringe_world"]`, a key no producer anywhere
   writes, so the guard was permanently false;
2. `should_check_strife()` re-rolled the p.148 ARRIVAL die every campaign turn;
   the book rolls it once, on arrival;
3. it then fired the D100 immediately; the book fires it only at 10 or above;
4. it read `instability_mod`, and every row carries `instability_reduction` —
   into a local that was never used anyway.

Then it logged through `journal.add_entry()`, which has zero definitions on
CampaignJournal: a fifth permanently-false guard.

**Repairing all five would still have produced nothing**, because the engine of
the chapter — a per-world Instability score that accumulates across turns — did
not exist in any form. The function that looked like it (`roll_instability_delta`)
had one caller, in the zero-instantiation `phases/WorldPhase.gd`, and that copy
did `clampi(instability, 0, 10)`: pinning the score AT the threshold it was
supposed to cross. **Counting broken guards is not the same as asking whether
the mechanism is present.**

**Difficulty Toggles (pp.32-34).** Two separate UIs collected toggle selections
and nothing read a toggle id. The creation panel's selection did not even leave
the panel: the coordinator's config whitelist did not name the key, so the array
was dropped at the panel boundary — the *identical* defect, in the *identical*
function, that had already made Progressive Difficulty decorative. A whitelist
is good design and this is its failure mode: a key it does not name vanishes in
silence.

Worth recording separately: the advancement numbers exist in **three** parallel
copies (`AdvancementSystem.stat_advancement_costs`,
`CharacterAdvancementConstants` over `character_advancement.json`, and
`AdvancementPhasePanel.advancement_costs`). Slower Progression is applied at all
three, because an option wired into two of them reads as implemented and simply
does not apply on whichever screen the player happens to open.

And one rules trap: the Compendium prints a bare **"3"** for Luck's maximum
where the Core Rules print **"1 (3 Human)"**. Read as a flat 3, Slower
Progression would have *raised* every non-Human species' Luck cap from 1 to 3 —
in a chapter whose entire purpose is to make the game harder. The maximum is
therefore applied as a clamp that can only ever lower the existing cap.

## Two chapters where nothing was broken at all (Aug 3)

**Expanded Quests (pp.78-80) and Expanded Connections (pp.80-86).** Neither had a
broken guard, a truncated table, a wrong key or a dead file. The data was
complete — nine quest rows spanning 01-100 contiguously, 30 Connection scenarios
across five subtables with every `*` decline marker recorded. The readers on
`compendium_missions_expanded.gd` were correct and correctly DLC-gated. The
chapters were dead purely because **nothing called them**.

That is a third failure mode, and it needs naming separately, because the
question "what is wrong with this code" has no answer here. The right question is
"what would a caller have needed, and did it exist?"

For Quests, it did not. A Quest step is not an event, it is a **standing
obligation** — seven of the nine rows end "until this has been paid / done /
completed, you cannot progress the Quest" — and a roll with nowhere to persist
its result cannot express that. `roll_quest_progression()` could only ever have
returned a row and thrown it away. The missing piece was STATE, and no amount of
staring at the reader would have revealed it.

Same for Connections at a smaller scale: the p.81 variety swap is scoped to "this
campaign", the no-roll option is a question about the PRIOR Opportunity mission,
and the offer expires one campaign turn after it is made. Three separate reasons
the chapter needs memory, none of them visible from `check_for_connection()`.

Two decisions worth recording:

- **"In place of" means in place of.** p.78 says the expanded system is used "in
  place of the core rulebook system" at Post-Battle Step 3, so the core 1-3/4-6/7+
  mapping goes, and so does the p.119 travel roll that follows it — the travel
  roll is part of the step being replaced, not a separate rule. The Compendium
  p.28 Expanded Database +1 is KEPT: a ship component that modifies a Quest
  progress roll does not care which table the roll consults.
- **The branch is taken before the die.** A standing obligation suppresses the
  roll entirely, so `process_quest_progress` must decide which system it is
  running BEFORE `ctx.roll_d6()`. A die rolled and discarded still reaches the
  dice feed and the journal, and for a player following along on paper that is
  worse than no die at all.

## The incomplete table is worse than the dead one (Elite Enemies, Aug 3)

`elite_enemy_types.json` was never loaded — but it was also only ~40% of the
chapter, and that second fact is the one that mattered. It held **three** of the
book's five tables, and two of those stopped halfway: Elite Hired Muscle ended at
roll 50, Elite Unique Individuals at 41, with Elite Interested Parties and Elite
Roving Threats absent entirely.

Wiring it in that state would have produced a generator that returned nothing for
most rolls — a silent default that reads as "implemented" in every inventory.
That is the same defect family the rest of this document is about, manufactured
fresh. **So the data was completed from the PDF before anything was wired.**

Two checks back the extraction, and both are asserted in the test suite rather
than only at extraction time, because a later hand-edit reopens a hole just as
easily:

1. **Coverage** — every table must span D100 1-100 with no gap and no overlap. A
   dropped row shows up immediately as a gap. This is what caught the four rows
   the first parse missed.
2. **Row-count parity** — p.48 says the elite tables "contain the same types of
   enemies" as the core ones, so each elite table must have exactly as many rows
   as its counterpart in `enemy_types.json`. All four match (15/16/16/13). This
   is independent of the extraction itself, so it catches an *invented* row as
   well as a dropped one.

Extraction traps worth remembering: rows were being dropped because names carry a
curly apostrophe (K'Erin) and the NUM/PANIC columns print an en-dash for "none"
(War Bots `+1 –`); the Roving Threats and Unique Individuals tables share a page,
so page ranges alone cannot split them (their row shapes can — Unique
Individuals prints LUCK where the others print NUM/PANIC); and 11 weapon cells
wrap onto the next line, leaving `"Hand Cannon,"` with `"Shatter Axe"` at the head
of the description. The wrap is repaired by consuming description words only
while they spell a weapon the game already knows, so the cell is completed *from
data* rather than guessed at.

## Latent traps found during the trace (not player-visible yet)

- `compendium_world_options.gd:28` loads
  `"res://data/RulesReference/FringeWorldStrife"` — **no file extension, and no
  such file exists** under either name. `FileAccess.open` returns null, the loop
  skips it silently, and `_ref_data` stays half-populated. Harmless *today* only
  because nothing in that class reads `_ref_data`; the strife table it looks like
  it is loading actually comes from `world_options.json` via a second, separate
  loader at `:73`.
- `TacticalBattleUI.gd:6074-6077` colour-codes instruction prefixes `"AI:"` and
  `"TOGGLE:"`. `_build_compendium_option_instructions()` (`:6639`) only ever emits
  `"MILESTONE:"`, so both branches are unreachable.
- `CharacterConnections.gd:28` uses `Engine.get_singleton("DiceManager")`, which
  per the standing gotcha does not resolve autoloads. Even if the file were wired,
  the random-connection roll could not fire.

## Method note

The flag audit and the chapter trace are **different measurements** and the first
does not imply the second. All 33 `ContentFlag`s except `DEPLOYMENT_VARIABLES` and
`ELITE_ENEMIES` are read somewhere — but six more chapters are dead, because the
flag is read *inside the gated getter that nobody calls*. Gating is not wiring.

Two spellings must both be searched or the count comes out wrong:

```
dlc.is_feature_enabled(dlc.ContentFlag.PSIONICS)   # enum form, ~40 sites
_is_flag_enabled("NEW_TRAINING")                    # string form, ~47 sites
    -> dlc_mgr.ContentFlag.get(flag_name, -1)       # variable, not a literal
```

An earlier pass searched only the enum form and concluded 19 of 33 flags were dead.
A later pass searched `ContentFlag.get("` as a literal and found 2 sites, missing
the string form entirely, because the lookup is by variable. Both numbers were
wrong in opposite directions.
