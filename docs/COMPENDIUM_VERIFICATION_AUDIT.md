# Five Parsecs Compendium — Verification Audit

**Created**: 2026-04-08
**Source**: Five Parsecs From Home Compendium PDF (236 pages), top-to-bottom verification against codebase
**Purpose**: Verify every Compendium mechanic is properly wired (not just data-present) in the app
**Method**: Extract mechanics from PDF, grep/read codebase, classify each as WIRED / DATA ONLY / MISSING

---

## Status Legend

| Status | Meaning |
|--------|---------|
| **WIRED** | Data exists AND gameplay/UI consumes it |
| **DATA ONLY** | Static data or rules engine exists, but nothing reads/enforces it at runtime |
| **MISSING** | Not implemented at all |
| **N/A** | Not applicable to a digital companion app (e.g. miniatures advice) |

---

## Audit Progress

| # | Section | Pages | Status | Verdict |
|---|---------|-------|--------|---------|
| 1 | Campaign Sequences | pp.11-12 | DONE | 6 setup toggles missing from creation wizard |
| 2 | Character Options (Krag/Skulker) | pp.14-18 | DONE | 3 creation modifiers DATA ONLY, armor rules not enforced |
| 3 | Psionics | pp.19-26 | DONE | Rules engine solid; NO UI integration (creation/battle/advancement) |
| 4 | New Kit | pp.27-29 | DONE | All data WIRED; enforcement gaps (duplicate limits, psionic-only) |
| 5 | Progressive Difficulty + Toggles | pp.32-36 | DONE | Fully WIRED |
| 6 | PvP + Co-op Battles | pp.37-43 | DONE | DATA ONLY — no battle mode UI (acceptable: multiplayer content) |
| 7 | AI Variations + Deployment Variables | pp.44-47 | DONE | Fully WIRED |
| 8 | Escalating Battles + Elite Enemies | pp.48-67 | DONE | Fully WIRED |
| 9 | No-Minis Combat | pp.68-75 | DONE | Fully WIRED (data + UI panel) |
| 10 | Expanded Missions/Quests/Connections | pp.76-88 | DONE | Fully WIRED |
| 11 | Dramatic Combat + Grid Movement | pp.89-95 | DONE | DATA ONLY — text reference, no gameplay reads flag |
| 12 | Terrain Generation + Casualties | pp.96-104 | DONE | Fully WIRED (one of strongest sections) |
| 13 | Intro Campaign + Factions + Mission Selection | pp.106-118 | DONE | Fully WIRED |
| 14 | Stealth + Street Fights + Salvage | pp.119-149 | DONE | Fully WIRED (generators + UI panels) |
| 15 | Fringe World Strife + Loans + Names | pp.150-162 | DONE | Mostly WIRED; creation toggle gap |

---

## Section 1: Campaign Sequences (pp.11-12)

The Compendium provides an **Updated Campaign Setup Sequence** (13 steps) and **Updated Campaign Turn Sequence** that integrates all optional rules from the book.

### Updated Campaign Setup Sequence

| # | Setup Option | Status | Evidence | Notes |
|---|---|---|---|---|
| 1 | Select crew size (4/5/6) | **WIRED** | `ExpandedConfigPanel` crew_size_option | Core Rules p.63 |
| 2 | Introductory Campaign | **WIRED** | `ExpandedConfigPanel` intro_campaign_checkbox | DLC-gated |
| 3 | Loans: Who Do You Owe? | **WIRED** | `ExpandedConfigPanel._build_compendium_setup_section()` + `TradePhasePanel` loan UI | Per-campaign opt-in at setup |
| 4 | Story Track | **WIRED** | `ExpandedConfigPanel` story_track_checkbox | |
| 5 | Expanded Factions | **WIRED** | `ExpandedConfigPanel._build_compendium_setup_section()` + `FactionSystem` | Per-campaign opt-in at setup |
| 6 | Victory condition | **WIRED** | `ExpandedConfigPanel` victory conditions section | |
| 7 | Difficulty mode + Toggles | **WIRED** | `ExpandedConfigPanel` difficulty selector | 5 Core Rules modes |
| 8 | Progressive Difficulty | **WIRED** | `ExpandedConfigPanel` checkboxes (basic/advanced) | DLC-gated |
| 9 | Fringe World Strife | **WIRED** | `ExpandedConfigPanel._build_compendium_setup_section()` + instability code in `WorldPhase.gd` | Per-campaign opt-in at setup |
| 10 | Dramatic Combat | **WIRED** | `ExpandedConfigPanel._build_compendium_setup_section()` + `compendium_difficulty_toggles.gd` | Per-campaign opt-in at setup |
| 11 | Casualty Tables | **WIRED** | `ExpandedConfigPanel._build_compendium_setup_section()` + `TacticalBattleUI` line 3131 | Per-campaign opt-in at setup |
| 12 | Detailed Post-battle Injuries | **WIRED** | `ExpandedConfigPanel._build_compendium_setup_section()` + `TacticalBattleUI` line 3135 | Per-campaign opt-in at setup |
| 13 | House rules | **N/A** | Player decision, not app-managed | |

**Setup Sequence Gap Summary**: All 12 applicable setup options are now **WIRED**. The 6 Compendium options (Loans, Expanded Factions, Fringe World Strife, Dramatic Combat, Casualty Tables, Detailed Injuries) are promoted to a dedicated "COMPENDIUM SETUP OPTIONS" card in the creation wizard with per-campaign toggles.

### Per-Mission Options

These are correctly handled as DLC flags that can be toggled on/off:

| Option | Status | Notes |
|---|---|---|
| AI Variations | **DLC-GATED** | `compendium_deployment_variables.gd` |
| Enemy Deployment Variables | **DLC-GATED** | `compendium_deployment_variables.gd` |
| Escalating Battles | **DLC-GATED** | `compendium_escalating_battles.gd` |
| Elite-level Enemies | **DLC-GATED** | ContentFlag in DLCManager |
| No-minis Combat | **DLC-GATED** | `NoMinisCombatPanel.gd` |
| Expanded Missions | **DLC-GATED** | `compendium_missions_expanded.gd` |
| Expanded Quest Progression | **DLC-GATED** | ContentFlag |
| Grid-based Movement | **DATA ONLY** | Flag stored, **no grid system reads it** (known gap) |
| Terrain Generation | **WIRED** | `BattlefieldGenerator` + terrain JSON |

### Updated Turn Sequence Additions

| Step | Status | Evidence |
|---|---|---|
| Travel: Flee invasion | **WIRED** | `TravelPhase._process_flee_invasion()` |
| Travel: Check Factions fleeing (invasion) | **WIRED** | `FactionSystem.process_invasion()` — flee/fight/destroy with Power-based D6 |
| World: Loan enforcement | **WIRED** | `TradePhasePanel._check_loan_enforcement()` with tiered thresholds |
| Battle: Salvage as battle type | **WIRED** | `WorldPhase.gd` generates salvage job offers via `SalvageJobGenerator` |
| Battle: Expanded Connections | **DLC-GATED** | ContentFlag exists |
| Post-battle: Psionic usage check | **WIRED** | `PostBattlePhase._check_psionic_detection()` |
| Post-battle: Trade Salvage | **DLC-GATED** | `compendium_salvage_jobs.gd` exists |
| Post-battle: Check Instability | **WIRED** | `WorldPhase.gd` instability code with clampi(0,10) |
| New World: Psionic legality | **WIRED** | `WorldPhase._check_dlc_psionic_legality()` + `PsionicLegalityBadge` UI |
| New World: Check Instability | **WIRED** | Same instability path as above |

---

## Section 2: Character Options — Krag, Skulkers, New Primary Alien Table (pp.14-18)

### Krag (Compendium pp.14-15)

| Mechanic | Status | Evidence | Compendium Page |
|---|---|---|---|
| Base stats: R1, Sp4", CS+0, T4, Sv+0 | **WIRED** | `character_species.json` line 361 | p.14 |
| Stat modifier: Toughness +1 at creation | **WIRED** | `CharacterGeneration.gd:1091` | p.14 |
| Cannot take Dash moves | **WIRED** | `BattleCalculations.gd:1542` `no_dash` ability | p.15 |
| Reroll natural 1 vs Rivals (fire or Brawl) | **WIRED** | `BattleCalculations.gd:1543` ability flag | p.15 |
| If creation gives 1+ Patrons → must add 1 Rival | **DATA ONLY** | Text in `character_species.json:366` but **NOT executed** in `_roll_and_store_creation_bonuses()` | p.15 |
| Random fight/argument: always Krag if present (no SP bypass) | **WIRED** | `BattleCalculations.gd:1544` `always_selected_for_fights` | p.15 |
| Trade armor: player picks Krag-armor or not | **DATA ONLY** | Text in JSON, `FiveParsecsCharacterData.gd:346` has `requires_krag_modification`, **no UI enforces** | p.15 |
| Non-Trade armor needs 2cr modification | **DATA ONLY** | Text in JSON, **no EquipmentManager logic** | p.15 |
| Skulkers + Engineers can wear both Krag and non-Krag armor | **DATA ONLY** | Not enforced anywhere | p.15 |
| Krag Colony Worlds (Busy Markets + Vendetta, 1 SP to add) | **MISSING** | No colony world system | p.15 |

### Skulker (Compendium pp.16-17)

| Mechanic | Status | Evidence | Compendium Page |
|---|---|---|---|
| Base stats: R1, Sp6", CS+0, T3, Sv+1 | **WIRED** | `character_species.json` line 376 | p.16 |
| Stat modifiers: Speed+2, Savvy+1 at creation | **WIRED** | `CharacterGeneration.gd:1095-1096` | p.16 |
| Creation: 1D6 Credits results → 1D3 Credits instead | **DATA ONLY** | Text in `character_species.json:379` but **NOT executed** in creation code | p.17 |
| Creation: Ignore first Rival rolled | **DATA ONLY** | Text in `character_species.json:380` but **NOT executed** in creation code | p.17 |
| Ignore difficult ground movement reduction | **WIRED** | `BattleCalculations.gd:1549` | p.17 |
| Ignore obstacles up to 1", first 1" of climb free | **WIRED** | `BattleCalculations.gd:1550-1551` | p.17 |
| Biological resistance: D6 3+ vs poison/toxin/gas/bio hazards | **WIRED** | `BattleCalculations.gd:1552` | p.17 |
| Drug resistance (Booster Pills, Combat Serum, Rage Out, Still — Stim-packs OK) | **DATA ONLY** | Text in `character_species.json:384`, **no gameplay check** | p.17 |
| Can use all armor/equipment without adaptation | **WIRED** | `BattleCalculations.gd:1553` `universal_armor_fit` | p.17 |
| Skulker Colony Worlds (Adventurous + random, Alien restricted = no result) | **MISSING** | No colony world system | p.17 |

### New Primary Alien Table (p.18)

| Mechanic | Status | Notes |
|---|---|---|
| D100 table with Krag (41-50) and Skulker (66-80) ranges | **N/A** | App uses manual species selection in character creator, not random D100 roll. Krag/Skulker are DLC-gated options in the dropdown. Acceptable for companion app. |

### Section 2 Gap Summary

**Creation-time species effects not wired** (3 items):
- Krag: +1 Rival if creation gives Patrons — needs adding to `CharacterCreator._roll_and_store_creation_bonuses()` species match block
- Skulker: 1D6 → 1D3 Credits — needs credit dice reduction in same function
- Skulker: Ignore first Rival — needs rival count adjustment in same function

**Equipment restrictions not enforced** (2 items):
- Krag armor modification (2cr cost) — would need EquipmentManager + UI
- Krag/Skulker/Engineer cross-species armor compatibility — would need armor assignment logic

**Colony worlds** (2 items): Not implemented — low priority for tabletop companion

---

## Section 3: Psionics (pp.19-26)

The Psionics system is one of the most complex Compendium additions. `PsionicSystem.gd` (~490 lines) is a remarkably complete **rules engine** covering powers, projection, strain, legality, detection, enemy psionics, and advancement. The gaps are entirely in **UI integration**.

### Psionics in Your Crew (pp.19-20)

| Mechanic | Status | Evidence | Page |
|---|---|---|---|
| Pick one crew member as Psionic at creation | **MISSING** | No "designate as psionic" UI in CharacterCreator | p.19 |
| Species restrictions (Soulless/Bot/De-converted/Hulker/Uplift/Bio-upgrade barred) | **DATA ONLY** | Rules text exists, **not enforced in code** | p.19 |
| Recruit psionic mid-campaign (1 SP or 10cr, max 1) | **MISSING** | No recruitment path | p.19 |
| Maximum one Psionic per crew | **MISSING** | No crew-level psionic count check | p.19 |

### Limitations (p.20)

| Mechanic | Status | Evidence | Page |
|---|---|---|---|
| Cannot increase Combat Skill via XP | **NOT ENFORCED** | AdvancementSystem doesn't check psionic status | p.20 |
| Weapons limited to Pistol or Melee trait only | **NOT ENFORCED** | EquipmentManager doesn't filter by psionic | p.20 |
| Implants permanently destroy psionic ability | **NOT ENFORCED** | No check in implant system | p.20 |

### Psionic Power Determination (pp.20-21)

| Mechanic | Status | Evidence | Page |
|---|---|---|---|
| 10 crew psionic powers with full descriptions | **WIRED** | `PsionicSystem` lines 16-91, all 10 powers | pp.20-21 |
| D10 x2 for starting powers | **WIRED** | `determine_starting_powers()` | p.20 |
| Duplicate: choose adjacent power (+/-1) | **WIRED** | `acquire_psionic_power()` line 253 | p.20 |
| Precursor may trade die for Predict (D10=6) | **PARTIAL** | `CharacterCreator._grant_random_psionic_power()` gives Precursor 1 power, but doesn't offer the Predict swap choice | p.20 |
| Power metadata (affects robotic? target self? persists?) | **DATA ONLY** | Not stored per-power in `PsionicSystem` — descriptions mention these in text but not as structured flags | p.20 |

### Using Powers (p.22)

| Mechanic | Status | Evidence | Page |
|---|---|---|---|
| Psionic Action as bonus before normal action | **MISSING** | TacticalBattleUI has **zero psionic references** | p.22 |
| 2D6 Projection roll (range in inches) | **WIRED** (engine) | `attempt_psionic_action()` | p.22 |
| Strain: extra D6, 4-5=stunned+success, 6=stunned+fail | **WIRED** (engine) | Lines 200-220 | p.22 |
| Swift strain advantage (stunned on 5-6 only, no fail on 6) | **MISSING** | No Swift species check in strain code | p.22 |
| Target visibility rules (see through friendly/hostile figures) | **MISSING** | No battle integration | p.22 |

### Psionic Advancement (p.22)

| Mechanic | Status | Evidence | Page |
|---|---|---|---|
| Acquire Psionic Power (12 XP) | **WIRED** (engine) | `acquire_psionic_power()` method exists, **no UI to trigger** | p.22 |
| Power Enhancement (6 XP, +1D6 to casting) | **WIRED** (engine) | `enhance_psionic_power()` exists, **no UI** | p.22 |
| Cannot raise Combat Skill via XP (reminder) | **NOT ENFORCED** | No check in AdvancementSystem | p.22 |

### Legality of Psionics (pp.22-24)

| Mechanic | Status | Evidence | Page |
|---|---|---|---|
| D100 legality table per world (Outlawed 01-25 / Unusual 26-55 / Who Cares 56-100) | **WIRED** | `roll_psionic_legality()` line 303 | p.22 |
| World arrival legality roll | **WIRED** | `WorldPhase._check_dlc_psionic_legality()` | p.22 |
| Legality badge UI | **WIRED** | `PsionicLegalityBadge.gd` in WorldPhaseController | p.22 |
| Outlawed: post-battle D6 detection (1 use=1, 2+=1-2) | **WIRED** | `check_outlawed_detection()` | p.23 |
| Outlawed: Psi-hunter enforcement D6 table (4 types) | **WIRED** | `_roll_enforcement_type()` | p.23 |
| Psi-hunter modifiers (-2 seize, +1 specialist, +1 vs psionics) | **WIRED** | Returned in enforcement dictionary | p.23 |
| Highly Unusual: 2+ sixes on projection triggers reinforcements | **WIRED** | `check_highly_unusual_reinforcements()` | p.24 |
| Highly Unusual: 3D6 reinforcement table (1=none, 2-5=basic, 6=specialist) | **WIRED** | `_roll_highly_unusual_reinforcements()` | p.24 |

### Enemy Psionics (pp.24-26)

| Mechanic | Status | Evidence | Page |
|---|---|---|---|
| 10 enemy psionic powers (Assail through Psionic Rage) | **WIRED** | `ENEMY_PSIONIC_DATA` dictionary, all 10 | p.26 |
| 4-step determination (Rogue Psionic / Swift-Precursor / Robotic / Other D6 4+) | **WIRED** | `determine_enemy_psionics()` | pp.24-25 |
| Enemy psionic profile: Hand Gun + Blade, Toughness 4 minimum | **WIRED** | Line 471 profile text | p.25 |
| Enemy psionics don't suffer Strain | **DATA ONLY** | Noted in text descriptions, not a separate code path | p.26 |

### Section 3 Gap Summary

**Rules engine is solid** — `PsionicSystem.gd` covers legality, detection, reinforcements, enemy psionics, crew powers, projection, strain, and advancement methods.

**UI integration is the gap** (this is the single largest Compendium gap):
1. **Character creation**: No way to designate a character as Psionic
2. **Battle UI**: TacticalBattleUI has zero psionic references — no Psionic Action button, no projection roll UI
3. **Advancement UI**: No XP spend options for Acquire Power (12 XP) or Enhance Power (6 XP)
4. **Recruitment**: No mid-campaign "make recruit Psionic" option (1 SP / 10 cr)
5. **Restrictions not enforced**: Combat Skill XP cap, Pistol/Melee weapon limit, implant destruction

**Minor code gaps**:
- Swift strain advantage (stunned 5-6 only) not implemented
- Power metadata (affects_robotic, target_self, persists) not structured — just in description text
- Precursor Predict swap choice not offered (just gets 1 random power)

---

## Section 4: New Kit — Training, Bot Upgrades, Ship Parts, Psionic Equipment (pp.27-29)

All data is in `data/compendium/compendium_equipment.json`, accessed via `CompendiumEquipment` class. DLC-gated by 4 ContentFlags.

### Advanced Training (p.27)

| Training | Cost | Status | Evidence |
|---|---|---|---|
| Freelancer Certification (permanent Patron license) | 15 cr | **WIRED** | JSON + `AdvancementPhasePanel` consumes `get_advancement_phase_items()` |
| Instructor (no fee/availability for crew training) | 10 cr | **WIRED** | JSON data, `one_per_crew: true` |
| Survival Course (D6 4+ evade traps/hazards) | 10 cr | **WIRED** | JSON data |
| Fixer (+1 Find Patron/Recruit/Track) | 15 cr | **WIRED** | JSON data, `one_per_crew: true` |
| Tactical Course (act before move) | 15 cr | **WIRED** | JSON data |
| `one_per_crew` enforcement (Freelancer Cert, Instructor, Fixer) | — | **GAP** | Flag exists in JSON but **not enforced** — duplicate purchases allowed (noted in implementation map) |

### Bot Upgrades (p.28)

| Upgrade | Cost | Status | Evidence |
|---|---|---|---|
| Built-in Weapon (negate Heavy/Clumsy) | 3cr x Shots + 1cr x Damage | **WIRED** | JSON with `cost_formula`, `revert_cost: 1` |
| Improved Armor Casing (5+ save) | 5 cr | **WIRED** | JSON data |
| Deflection Module (Screen + Armor save) | 8 cr | **WIRED** | JSON data |
| Jump Module (replace move with jump) | 6 cr | **WIRED** | JSON data |
| Multi-wave Scanner (+1 Seize Initiative) | 10 cr | **WIRED** | JSON data |
| Broad Spectrum Vision (see through all) | 6 cr | **WIRED** | JSON data |
| "One of each" limit / "Soulless cannot use" | — | **GAP** | Not enforced in purchase flow |
| "Max 1 upgrade per campaign turn" | — | **GAP** | Not enforced |

### Ship Parts (p.29)

| Part | Cost | Status | Evidence |
|---|---|---|---|
| Expanded Database (+1 Quest progress) | 10 cr | **WIRED** | JSON data, `TradePhasePanel` consumes `get_trade_phase_items_with_lock_status()` |
| Scientific Research System (travel roll) | 10 cr | **WIRED** | JSON data |
| Miniaturized Components (no fuel cost) | +5 cr (8 cr retrofit) | **WIRED** | JSON data with `retrofit_cost: 8, permanent: true` |
| Ship parts to dedicated ship slots | — | **GAP** | Parts go to generic pool, not ship component slots (noted in implementation map) |

### Psionic Equipment (p.29)

| Item | Cost | Status | Evidence |
|---|---|---|---|
| Warding Shrel (avoid Strain, 1/battle) | 10 cr | **WIRED** | JSON data with `carry_two_cancels: true` |
| Psionic Focus (+1" power range) | 10 cr | **WIRED** | JSON data |
| Nullification Surgery (permanently lose psionics) | 3 cr | **WIRED** | JSON data with `permanent: true, irreversible: true` |
| `psionic_only` restriction enforcement | — | **GAP** | Not enforced — any character can buy psionic equipment (noted in implementation map) |

### Section 4 Summary
All items exist in JSON with correct values from the Compendium. The `CompendiumEquipment` class provides proper DLC-gated queries. UI consumers exist in both `AdvancementPhasePanel` (training + bot upgrades) and `TradePhasePanel` (ship parts + psionic gear). `PreBattleChecklist` also shows instruction text.

**Gaps are all enforcement-related**: duplicate purchase limits, Soulless exclusion, per-turn upgrade limits, psionic-only restrictions, and ship component slot assignment.

---

## Section 5: Progressive Difficulty + Difficulty Toggles (pp.32-36)

### Progressive Difficulty (pp.32-33)

| Mechanic | Status | Evidence |
|---|---|---|
| Option 1: Turn-based scaling table | **WIRED** | `ProgressiveDifficultyTracker.gd`, consumed by `BattlePhase.gd` |
| Option 2: Feature unlock by turn number | **WIRED** | Same tracker, data in `DifficultyOptions.json` |
| Campaign creation toggle (basic/advanced) | **WIRED** | `ExpandedConfigPanel` checkboxes, stored in `progress_data["progressive_difficulty_options"]` |
| DLC gating | **WIRED** | `ContentFlag.PROGRESSIVE_DIFFICULTY` |

### Difficulty Toggles (pp.34-36)

| Toggle | Status | Evidence |
|---|---|---|
| Strength-adjusted Enemies | **WIRED** | `compendium_difficulty_toggles.gd` category `encounter_scaling` |
| Slaves to the Star-grind (reduced credits) | **WIRED** | Category `economy` |
| Hit Me Harder (Veteran/Actually Specialized/Armored Leaders/Better Leadership) | **WIRED** | Category `combat_difficulty`, 4 sub-toggles |
| Time is Running Out (Paying by Hour / Movement All Over) | **WIRED** | Category `time_pressure` |
| Starting in the Gutter (reduced starting resources) | **WIRED** | Category `economy` |
| Reduced Lethality (injury table softening) | **WIRED** | Category `combat_difficulty` |
| DLC gating | **WIRED** | `ContentFlag.DIFFICULTY_TOGGLES` |

**Section 5 is fully WIRED.** JSON data, DLC gating, campaign creation toggle, and battle consumption all in place.

---

## Section 6: PvP + Co-op Battles (pp.37-43)

| Mechanic | Status | Evidence |
|---|---|---|
| PvP battle reason table (D100) | **DATA ONLY** | `compendium_missions_expanded.gd` has `PVP_BATTLE_REASON` |
| PvP initiative, power ratings | **DATA ONLY** | `PVP_INITIATIVE_USES`, `PVP_POWER_RATING` |
| PvP 3-way battle deployment | **DATA ONLY** | `PVP_THIRD_PARTY_DEPLOYMENT` |
| PvP rules text | **DATA ONLY** | `PVP_RULES` dict, `get_pvp_setup()` method |
| Co-op battle rules | **DATA ONLY** | In same data file |
| Battle mode selection UI (PvP/Co-op/Standard) | **MISSING** | TacticalBattleUI has **zero PvP/Co-op references** |
| DLC flags | **WIRED** | `ContentFlag.PVP_BATTLES`, `ContentFlag.COOP_BATTLES` |

**Section 6: Complete rule text data exists, but NO battle UI integration.** This is text-instruction content that could be shown as reference, but there's no way to select PvP or Co-op as a battle mode. Noted as acceptable for a single-player companion app — PvP/Co-op is inherently multiplayer.

---

## Section 7: AI Variations + Enemy Deployment Variables (pp.44-47)

| Mechanic | Status | Evidence |
|---|---|---|
| AI Variation D6 table (6 types) | **WIRED** | `compendium_difficulty_toggles.gd` `AI_VARIATION_TABLES` |
| AI type affects deployment | **WIRED** | `compendium_deployment_variables.gd` `roll_deployment(ai_type)` |
| Deployment condition modifiers | **WIRED** | JSON-driven, DLC-gated |
| DLC flags | **WIRED** | `ContentFlag.AI_VARIATIONS`, `ContentFlag.DEPLOYMENT_VARIABLES` |

**Section 7 is fully WIRED.**

---

## Section 8: Escalating Battles + Elite-Level Enemies (pp.48-67)

| Mechanic | Status | Evidence |
|---|---|---|
| Escalation mechanics (reinforcement waves) | **WIRED** | `compendium_escalating_battles.gd` with `roll_escalation()` |
| `EscalatingBattlesManager` | **WIRED** | Instantiated in `BattleSetupPhasePanel.setup_phase()` |
| Elite-level enemy tables (pp.52-67) | **WIRED** | `EliteLevelEnemiesManager.gd`, data in `DataManager.gd` |
| Elite-level rivals, composition, weapon notes, rewards | **WIRED** | JSON data + DLC gating |
| DLC flags | **WIRED** | `ContentFlag.ESCALATING_BATTLES`, `ContentFlag.ELITE_ENEMIES` |

**Section 8 is fully WIRED.**

---

## Section 9: No-Minis Combat Resolution (pp.68-75)

| Mechanic | Status | Evidence |
|---|---|---|
| Abstract zone-based combat system | **WIRED** | `compendium_no_minis.gd` data + `NoMinisCombatPanel.gd` UI |
| Initiative actions | **WIRED** | In data |
| Locations, Firefight, Hectic Combat | **WIRED** | Full rules text |
| Battle Flow Events | **WIRED** | Data present |
| Mission-specific notes | **WIRED** | Data present |
| DLC flag | **WIRED** | `ContentFlag.NO_MINIS_COMBAT` |

**Section 9 is fully WIRED** — both data and a dedicated UI panel exist.

---

## Section 10: Expanded Ways to Play — Missions, Quests, Connections (pp.76-88)

| Mechanic | Status | Evidence |
|---|---|---|
| 13 expanded mission objectives | **WIRED** | `compendium_missions_expanded.gd` |
| 6 expanded deployment types | **WIRED** | Same data file |
| Expanded Quest Progression | **WIRED** | DLC-gated, `RivalPatronResolver` in PostBattle |
| Expanded Connections (Opportunity missions) | **WIRED** | `PatronSystem.gd` checks flag |
| DLC flags | **WIRED** | `ContentFlag.EXPANDED_MISSIONS`, `EXPANDED_QUESTS`, `EXPANDED_CONNECTIONS` |

**Section 10 is fully WIRED.**

---

## Section 11: Dramatic Combat + Grid-based Movement (pp.89-95)

| Mechanic | Status | Evidence |
|---|---|---|
| Dramatic Combat rules | **DATA ONLY** | `DRAMATIC_COMBAT_RULES` in `compendium_difficulty_toggles.gd` |
| Dramatic Weapons table | **DATA ONLY** | Data exists but no battle UI reads it |
| Grid-based Movement (1 square = 2") | **DATA ONLY** | `ContentFlag.GRID_BASED_MOVEMENT` stored, `CheatSheetPanel` has reference text, but **no grid system reads the flag** |
| DLC flags | **WIRED** | Flags exist |

**Section 11: Data exists but limited gameplay integration.** Dramatic Combat is text-reference only. Grid Movement flag is stored but unused. Both are low-impact since this is a tabletop companion (the player implements these on their physical table).

---

## Section 12: Terrain Generation + Casualties & Injuries (pp.96-104)

| Mechanic | Status | Evidence |
|---|---|---|
| Compendium terrain generation (5-step) | **WIRED** | `BattlefieldGenerator.gd` with 7 themes, 10 world trait mods |
| Terrain tables | **WIRED** | `data/battlefield/themes/compendium_terrain.json` |
| `BattlefieldMapView` + `BattlefieldGridPanel` | **WIRED** | Full map visualization |
| Casualty Tables (alternative injury roll) | **WIRED** | `compendium_difficulty_toggles.gd`, `TacticalBattleUI` line 3131 |
| Critical Hit table | **WIRED** | Data present |
| Detailed Post-Battle Injuries | **WIRED** | `TacticalBattleUI` line 3135 |
| DLC flags | **WIRED** | `ContentFlag.TERRAIN_GENERATION`, `CASUALTY_TABLES`, `DETAILED_INJURIES` |

**Section 12 is fully WIRED** — one of the most thoroughly implemented sections.

---

## Section 13: Introductory Campaign + Expanded Factions + Mission Selection (pp.106-118)

### Introductory Campaign (pp.106-111)

| Mechanic | Status | Evidence |
|---|---|---|
| 5-mission guided tutorial campaign | **WIRED** | `IntroductoryCampaignManager.gd` |
| Campaign creation toggle | **WIRED** | `ExpandedConfigPanel` checkbox |
| World Phase gating (sequential mission unlock) | **WIRED** | `CampaignPhaseManager` + `JobOfferComponent` |
| DLC flag | **WIRED** | `ContentFlag.INTRODUCTORY_CAMPAIGN` |

### Expanded Factions (pp.112-117)

| Mechanic | Status | Evidence |
|---|---|---|
| Faction generation (power, influence, type) | **WIRED** | `FactionSystem.gd` (~1,400 lines) |
| Faction jobs | **WIRED** | `check_faction_job_available()` |
| Affiliated Patron Jobs, Loyalty, Playing All Sides | **WIRED** | Full faction lifecycle |
| Faction Activities (per-turn) | **WIRED** | `process_faction_event()` |
| Off-World Factions | **WIRED** | Faction system handles world transitions |
| Invasion response (flee/fight/destroy) | **WIRED** | `process_invasion()` with Power-based D6 |
| Faction Events table | **WIRED** | `_apply_faction_event()` |
| Faction Destruction | **WIRED** | `_check_faction_destruction()` |
| DLC flag | **WIRED** | `ContentFlag.EXPANDED_FACTIONS` |

### Mission Selection (p.118)

| Mechanic | Status | Evidence |
|---|---|---|
| Battle type selection (Patron/Rival/Quest/Opportunity/Salvage) | **WIRED** | `JobOfferComponent` derives battle type, `WorldPhaseController` has `MissionSelectionUI` |

**Section 13 is fully WIRED.**

---

## Section 14: Stealth Missions + Street Fights + Salvage Jobs (pp.119-149)

### Stealth Missions (pp.119-124)

| Mechanic | Status | Evidence |
|---|---|---|
| Stealth generator (6 objectives, spotting) | **WIRED** | `StealthMissionGenerator.gd` |
| Stealth Mission Panel UI | **WIRED** | `StealthMissionPanel.gd` |
| Sentries (uses `campaign_crew_size` for count) | **WIRED** | Verified in crew size scaling work |
| Psionics and Stealth interaction | **DATA ONLY** | Text reference only |
| DLC flag | **WIRED** | `ContentFlag.STEALTH_MISSIONS` |

### Street Fights (pp.125-138)

| Mechanic | Status | Evidence |
|---|---|---|
| Street fight generator (suspect markers, police) | **WIRED** | `StreetFightGenerator.gd` |
| Street Fight Panel UI | **WIRED** | `StreetFightPanel.gd` |
| DLC flag | **WIRED** | `ContentFlag.STREET_FIGHTS` |

### Salvage Jobs (pp.139-149)

| Mechanic | Status | Evidence |
|---|---|---|
| Salvage job generator (tension track, contacts) | **WIRED** | `SalvageJobGenerator.gd` |
| Salvage Mission Panel UI | **WIRED** | `SalvageMissionPanel.gd` |
| Tension track (uses `campaign_crew_size`) | **WIRED** | Verified in crew size scaling work |
| Salvage as World Phase battle type | **WIRED** | `WorldPhase.gd` generates salvage offers |
| DLC flag | **WIRED** | `ContentFlag.SALVAGE_JOBS` |

**Section 14 is fully WIRED** — all 3 mission types have generators, UI panels, and DLC gating.

---

## Section 15: Fringe World Strife + Loans + Name Generation (pp.150-162)

### Fringe World Strife (pp.150-153)

| Mechanic | Status | Evidence |
|---|---|---|
| 10 Fringe World Strife events | **WIRED** | `compendium_world_options.gd` |
| Instability 0-10 scale | **WIRED** | `WorldPhase.gd` instability tracking with `clampi(0, 10)` |
| Post-battle instability check | **WIRED** | `WorldPhase.gd` delta calculation |
| DLC flag | **WIRED** | `ContentFlag.FRINGE_WORLD_STRIFE` |
| **Not toggleable at campaign creation** | **GAP** | Only in DLCManagementDialog (see Section 1) |

### Loans: Who Do You Owe? (pp.154-158)

| Mechanic | Status | Evidence |
|---|---|---|
| 6 loan origins | **WIRED** | `compendium_world_options.gd` |
| Interest rate calculation | **WIRED** | `TradePhasePanel._apply_loan_interest()` |
| Enforcement thresholds (2 tiers) | **WIRED** | `TradePhasePanel._check_loan_enforcement()` |
| Enforcement method roll | **WIRED** | `CompendiumWorldOptions.roll_enforcement_method()` |
| Take/pay loan UI in Trade Phase | **WIRED** | Full loan display + buttons |
| Ship purchase loan option | **WIRED** | `ShipPurchaseDialog` loan checkbox |
| LoanManager | **WIRED** | `LoanManager.gd` |
| DLC flag | **WIRED** | `ContentFlag.EXPANDED_LOANS` |
| **Not toggleable at campaign creation** | **GAP** | Only in DLCManagementDialog (see Section 1) |

### Name Generation Tables (pp.159-162)

| Mechanic | Status | Evidence |
|---|---|---|
| World names, Colony names, Ship names, Corporate Patron names | **WIRED** | `compendium_world_options.gd` |
| 7 species name tables | **WIRED** | Data present |
| DLC flag | **WIRED** | `ContentFlag.NAME_GENERATION` |

### Prison Planet Character (referenced in mission data)

| Mechanic | Status | Evidence |
|---|---|---|
| Prison Planet as character origin | **PARTIAL** | `CharacterCreator.gd` shows it as DLC-gated origin in dropdown, but **no creation-time effects applied** |
| DLC flag | **WIRED** | `ContentFlag.PRISON_PLANET_CHARACTER` |

**Section 15 is mostly WIRED**, with the same campaign creation toggle gap noted in Section 1.

---

## Gap Summary (All 15 Sections Complete)

### Overall Score

- **15 sections audited** covering 236 Compendium pages
- **10 sections fully WIRED** (5, 7, 8, 9, 10, 12, 13, 14 + most of 4, 15)
- **2 sections DATA ONLY** (6: PvP/Co-op, 11: Dramatic/Grid — acceptable for companion app)
- **1 section major gap** (3: Psionics — rules engine complete, UI missing)
- **2 sections with minor gaps** (1: creation toggles, 2: creation modifiers)

### HIGH — Missing UI/Gameplay Wiring

| Gap | Section | Impact | Fix Location |
|-----|---------|--------|-------------|
| Psionics: No creation UI to designate a character as Psionic | 3 | Cannot use psionics at all | CharacterCreator |
| Psionics: No battle UI for Psionic Actions | 3 | Core psionic gameplay unusable | TacticalBattleUI |
| Psionics: No advancement UI for psionic XP options | 3 | Cannot grow psionic abilities | AdvancementPhasePanel |
| Psionics: No mid-campaign psionic recruitment | 3 | Can't add psionics after creation | Recruitment flow |

### MEDIUM — Data Present But Not Enforced

| Gap | Section | Impact | Fix Location |
|-----|---------|--------|-------------|
| ~~6 setup options not in creation wizard~~ | 1 | **RESOLVED** — dedicated Compendium Setup Options card added | `ExpandedConfigPanel._build_compendium_setup_section()` |
| Krag creation: +1 Rival if has Patrons | 2 | Creation doesn't apply species rule | `CharacterCreator._roll_and_store_creation_bonuses()` |
| Skulker creation: 1D6 → 1D3 Credits | 2 | Creation doesn't reduce credits | Same function |
| Skulker creation: Ignore first Rival | 2 | Creation doesn't skip first rival | Same function |
| Psionics: Combat Skill XP cap not enforced | 3 | Psionics can level Combat Skill | AdvancementSystem |
| Psionics: Weapon restriction not enforced | 3 | Psionics can use any weapon | EquipmentManager |
| Psionics: Implant destroys ability not enforced | 3 | Implants don't affect psionics | Character implant code |
| Psionics: Species restrictions not enforced | 3 | Bots/Soulless could be psionic | CharacterCreator |
| Training `one_per_crew` not enforced | 4 | Duplicate Freelancer Cert/Instructor purchases allowed | AdvancementPhasePanel |
| Bot upgrade limits not enforced | 4 | No per-turn/Soulless/per-bot checks | Purchase flow |
| Psionic equipment `psionic_only` not enforced | 4 | Any character can buy psionic gear | EquipmentManager |
| Ship parts to generic pool, not ship slots | 4 | Parts don't go to dedicated ship component system | ShipPanel |
| Skulker drug resistance not enforced | 2 | Consumables work on Skulkers | TacticalBattleUI consumable code |
| Krag armor modification (2cr) | 2 | No armor compatibility check | EquipmentManager |
| Prison Planet: no creation-time effects | 15 | Origin selectable but no special rules applied | CharacterCreator |
| Grid-based Movement flag unused | 1, 11 | Flag stored but nothing reads it | TacticalBattleUI |

### LOW — Missing Features (Low Priority for Companion App)

| Gap | Section | Impact | Fix Location |
|-----|---------|--------|-------------|
| PvP/Co-op battle mode selection | 6 | Multiplayer content, data exists as text reference | TacticalBattleUI |
| Dramatic Combat rules integration | 11 | Text reference only, player applies on tabletop | Battle UI |
| Krag Colony Worlds | 2 | Flavor content | World generation |
| Skulker Colony Worlds | 2 | Flavor content | World generation |
| Swift strain advantage (5-6 only) | 3 | Minor balance difference | PsionicSystem strain code |
| Psionic power structured metadata | 3 | Powers work but lack affects_robotic/target_self/persists flags | PsionicSystem |
| Precursor Predict swap choice | 3 | Minor creation option | CharacterCreator |
| Psionics and Stealth interaction | 14 | Text reference only | StealthMissionGenerator |

### Summary by Priority

| Priority | Count | Description |
|----------|-------|-------------|
| **HIGH** | 4 | All psionics UI (creation + battle + advancement + recruitment) |
| **MEDIUM** | 16 | Enforcement gaps, creation toggles, species creation modifiers |
| **LOW** | 8 | PvP/Co-op, Dramatic, colonies, minor psionic details |
| **Total gaps** | **28** | Out of ~150+ individual mechanics checked |
| **Fully WIRED** | ~85% | Of all Compendium mechanics |
