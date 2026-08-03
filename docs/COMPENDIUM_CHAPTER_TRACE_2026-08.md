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
| **LIVE** — a live path reaches the player | 18 |
| **PARTIAL** — some of the chapter lands, a named part does not | 2 |
| **DEAD** — data + gated API exist, nothing reaches the player | 10 |

7 of the 10 dead are **Freelancer's Handbook** — 7 of that pack's 17 advertised
features.

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
| **Difficulty Toggles pp.32-34** | **DEAD** | Listed in `DifficultyTogglesPanel`, listed in `ExpandedConfigPanel`, rendered as cheat-sheet text — and **none of the 12 toggle ids is read anywhere in `src/`.** Ticking one changes nothing in play |
| **Player vs Player pp.35-38** | **DEAD** | `get_pvp_setup` / `get_pvp_rules` / `roll_pvp_battle_reason` / `roll_pvp_third_party` (`compendium_missions_expanded.gd:319/326/333/346`) — **zero callers repo-wide, tests included.** No PvP surface exists |
| **Expanded Co-op pp.39-41** | **DEAD** | `get_coop_setup` / `get_coop_rules` (`:359/:366`) — zero callers |
| **AI Variations p.42** | **DEAD** | `roll_ai_behavior` / `get_ai_behavior` (`compendium_difficulty_toggles.gd:150/161`) and the `AI_VARIATION_TABLES` getter (`:91`) — zero callers |
| **Enemy Deployment Variables p.44** | **DEAD** | `data/compendium/deployment_variables.json` — zero loaders anywhere |
| Escalating Battles p.46 | LIVE | `EscalatingBattlesManager` → `TacticalBattleUI:6091`, `BattleRoundHUD` |
| **Elite-level Enemies pp.48-65** | **DEAD** | `data/elite_enemy_types.json` is never even **loaded**: `DataManager.gd:37` declares the path, `:60/:111/:255` declare and clear the dict, and the only getter is commented out at `:745-747` |
| No-minis Combat pp.66-73 | LIVE | `NoMinisResolver`, `BattleResolverRouter:38`, `NoMinisCombatPanel`, `TacticalBattleUI:6741` |
| Expanded Missions p.74 | LIVE | five roll functions consumed by `JobOfferComponent.gd:1649-1669` |
| **Expanded Quest Progression p.78** | **DEAD** | `roll_quest_progression` / `get_quest_conclusion` (`:258/:271`) — zero callers |
| **Expanded Connections p.80** | **DEAD** | `check_for_connection` / `roll_connection_type` / `roll_connection_subtable` (`:278/:285/:298`) zero callers, **and** `src/core/character/connections/CharacterConnections.gd` is referenced by nothing in `src/` |
| **Dramatic Combat pp.87-89** | **PARTIAL** | Adjusted Shooting is applied by all four resolvers and the rule text renders (`TacticalBattleUI:6113`). The **Dramatic Weapons stat table pp.88-89** does not: `get_dramatic_weapon_stats()` and `get_dramatic_effect()` have zero callers |
| **Grid-based Movement pp.90-93** | **DEAD** | `TacticalBattleUI.gd:6123` reads `mission_dict["grid_movement_instructions"]` — **zero producers.** `BattlefieldGrid.gd` is table geometry (p.108 sizes), not this chapter |
| Terrain Generation pp.94-98 | LIVE | `FPCM_BattlefieldGenerator` + `data/battlefield/themes/compendium_terrain.json` |
| Casualty Tables p.99 | LIVE | `roll_casualty()` → `TacticalBattleUI:6722` → called at `:5488` |
| Detailed Post-Battle Injuries p.101 | LIVE | `roll_detailed_injury()` → `:6726` → called at `:5496` |

## Scenarios & Settings (pp.103-160) — Fixer's Guidebook

| Chapter | Verdict | Evidence |
|---|---|---|
| Introductory Campaign pp.104-109 | LIVE | `IntroductoryCampaignManager.gd:58/:77`, `JobOfferComponent.gd:1603` |
| Expanded Factions pp.110-115 | LIVE | `FactionSystem` (autoload), 9 gate sites |
| Mission Selection p.116 | LIVE | superseded by `JobOfferComponent`; the old `MissionSelectionUI` and its route were deleted with evidence (`WorldPhaseController.gd:2013-2018`) |
| Stealth Missions pp.117-122 | LIVE | `StealthMissionGenerator` + `StealthResolver` + `StealthMissionPanel` |
| Street Fights pp.123-136 | LIVE | `StreetFightGenerator` + `StreetFightResolver` + `StreetFightPanel` |
| Salvage Jobs pp.137-147 | LIVE | `SalvageJobGenerator` + `SalvageResolver` + `SalvageMissionPanel` |
| **Fringe World Strife pp.148-151** | **DEAD** | `WorldPhaseController.gd:648` calls `should_check_strife(world_phase_data.get("is_fringe_world", false))` and **`is_fringe_world` is written nowhere in the repo** — permanently false. But the missing producer is not the real problem: **the implemented mechanism is not the book's.** See below |
| **Loans pp.152-156** | **PARTIAL** | Steps 1/3/4 live via `TradePhasePanel.gd:828-832`. **Step 2 is a hardcoded constant** — see below |
| Name Generation pp.157-160 | LIVE | `compendium_world_options` name tables + `CharacterGeneration.gd:456`, `ContactManager.gd:311` |
| Bug Hunt pp.161-223 | LIVE | full gamemode, separate architecture |

---

## The two PARTIAL rows, in detail

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

### Dramatic Combat — the weapons table (pp.88-89)

`get_dramatic_weapon_stats(weapon_id)` reads `dramatic_weapons_stats` and returns
the per-weapon override the chapter exists to provide. Zero callers, so a
Dramatic-Combat battle uses baseline `equipment_database` profiles throughout.

---

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
