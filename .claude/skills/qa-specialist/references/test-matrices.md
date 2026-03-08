# Test Matrices — Five Parsecs Campaign Manager

Combinatorial test matrices for systematic coverage. Each matrix uses priority-based sampling to manage the explosion of combinations.

**Sampling Strategy:**
- **P0 (Independent)**: Test each dimension independently while others use defaults (~100 tests)
- **P1 (Pairwise)**: Test all pairs of two key dimensions (~200 tests)
- **P2 (Random sampling)**: Random triples from 3+ dimensions (~50 tests)

---

## 1. Campaign Creation Matrix

### Dimensions

| Dimension | Values | Count |
|-----------|--------|-------|
| Difficulty | EASY, NORMAL, HARD, CHALLENGING, NIGHTMARE, HARDCORE, ELITE, INSANITY | 8 |
| Campaign Type | STANDARD, CUSTOM, TUTORIAL, STORY, SANDBOX | 5 |
| Victory Condition | STANDARD, TURNS_20, TURNS_50, TURNS_100, CREDITS_50K, CREDITS_100K, REPUTATION_10, REPUTATION_20, QUESTS_3, QUESTS_5, QUESTS_10, BATTLES_20, BATTLES_50, BATTLES_100, STORY_COMPLETE, STORY_POINTS_10, STORY_POINTS_20, WEALTH_GOAL, REPUTATION_GOAL, FACTION_DOMINANCE, MISSION_COUNT | 21 |
| Story Track | enabled, disabled | 2 |
| Ironman Mode | enabled, disabled | 2 |
| Crew Size | 2, 3, 4, 5, 6 | 5 |

**Total theoretical**: 8 × 5 × 21 × 2 × 2 × 5 = **16,800**

### P0: Independent Tests (44 tests)
- Each difficulty level with STANDARD/NORMAL defaults (8 tests)
- Each campaign type with NORMAL difficulty (5 tests)
- Each victory condition with NORMAL/STANDARD defaults (21 tests)
- Story track on/off (2 tests)
- Ironman on/off (2 tests)
- Each crew size with defaults (5 tests)
- Default everything (1 test — the happy path)

### P1: Pairwise — Difficulty × Victory Condition (168 tests)
- Every difficulty paired with every victory condition
- Other dimensions at defaults
- This catches most interaction bugs (difficulty modifiers affecting victory thresholds)

### P2: Random Sampling (30 tests)
- 30 random combinations across all 6 dimensions
- Use seeded RNG for reproducibility

---

## 2. Character Creation Matrix

### Dimensions

| Dimension | Values | Count |
|-----------|--------|-------|
| Character Class | SOLDIER, MEDIC, ENGINEER, PILOT, MERCHANT, SECURITY, BROKER, BOT_TECH, WORKING_CLASS, TECHNICIAN, SCIENTIST, HACKER, MERCENARY, AGITATOR, PRIMITIVE, ARTIST, NEGOTIATOR, TRADER, STARSHIP_CREW, PETTY_CRIMINAL, GANGER, SCOUNDREL, ENFORCER, SPECIAL_AGENT, TROUBLESHOOTER, BOUNTY_HUNTER, NOMAD, EXPLORER, PUNK, SCAVENGER | 30 |
| Background | MILITARY, MERCENARY, CRIMINAL, COLONIST, ACADEMIC, EXPLORER, TRADER, NOBLE, OUTCAST, SOLDIER, MERCHANT, (+20 more) | 30+ |
| Origin | HUMAN, ENGINEER, FERAL, KERIN, PRECURSOR, SOULLESS, SWIFT, BOT, CORE_WORLDS, FRONTIER, DEEP_SPACE, COLONY, HIVE_WORLD, FORGE_WORLD | 14 |
| Motivation | WEALTH, REVENGE, GLORY, KNOWLEDGE, POWER, JUSTICE, SURVIVAL, LOYALTY, FREEDOM, DISCOVERY, REDEMPTION, DUTY, FAME, ESCAPE, ADVENTURE, TRUTH, TECHNOLOGY, ROMANCE, FAITH, POLITICAL, ORDER | 21 |
| Training | NONE, PILOT, MECHANIC, MEDICAL, MERCHANT, SECURITY, BROKER, BOT_TECH, SPECIALIST | 9 |

**Total theoretical**: 30 × 30 × 14 × 21 × 9 = **2,381,400**

### P0: Independent Tests (104 tests)
- Each character class with Human/defaults (30 tests)
- Each origin with Soldier/defaults (14 tests)
- Each motivation with defaults (21 tests)
- Each training with defaults (9 tests)
- Key backgrounds (~30, sampled to 15 representative) (15 tests)
- All species with stat boundary checks (14 tests — verify luck, toughness limits per species)
- Captain flag = true (1 test)

### P1: Pairwise — Origin × Character Class (420 tests)
- Every origin × class combination
- Validates species-specific class restrictions (e.g., Bots can't be certain classes)

### P2: Random Sampling (50 tests)
- 50 random full-dimension combinations

---

## 3. Battle System Matrix

### Dimensions

| Dimension | Values | Count |
|-----------|--------|-------|
| Deployment Type | STANDARD, LINE, AMBUSH, SCATTERED, DEFENSIVE, INFILTRATION, REINFORCEMENT, BOLSTERED_LINE, CONCEALED, OFFENSIVE | 10 |
| Battle Victory Condition | ELIMINATION, OBJECTIVE, SURVIVAL, EXTRACTION, CONTROL_POINTS | 5 |
| Enemy Type | GANGERS, PUNKS, RAIDERS, PIRATES, CULTISTS, PSYCHOS, WAR_BOTS, SECURITY_BOTS, BLACK_OPS_TEAM, SECRET_AGENTS, ELITE, BOSS, MINION, ENFORCERS, ASSASSINS, UNITY_GRUNTS, BLACK_DRAGON_MERCS | 17 |
| Enemy Trait | SCAVENGER, TOUGH_FIGHT, ALERT, FEROCIOUS, LEG_IT, FRIDAY_NIGHT_WARRIORS, AGGRO, UP_CLOSE, FEARLESS, GRUESOME, SAVING_THROW, TRICK_SHOT, CARELESS, BAD_SHOTS | 14 |
| Oracle Tier | LOG_ONLY, ASSISTED, FULL_ORACLE | 3 |
| Crew Size | 2, 3, 4, 5, 6 | 5 |

**Total theoretical**: 10 × 5 × 17 × 14 × 3 × 5 = **178,500**

### P0: Independent Tests (54 tests)
- Each deployment type with defaults (10 tests)
- Each battle victory condition with STANDARD deployment (5 tests)
- Each enemy type with STANDARD deployment (17 tests)
- Each enemy trait with GANGERS (14 tests)
- Each oracle tier (3 tests)
- Each crew size (5 tests)

### P1: Pairwise — Deployment × Enemy Type (170 tests)
- Every deployment × enemy type combination
- Validates deployment logic is independent of enemy composition

### P2: Targeted Combos (20 tests)
- AMBUSH + FEARLESS enemies (surprise attack on fearless)
- INFILTRATION + ALERT enemies (stealth vs detection)
- 1-crew SURVIVAL (minimum crew, must survive)
- FULL_ORACLE + BOSS enemy (max complexity)
- Each enemy behavior (AGGRESSIVE, DEFENSIVE, etc.) with matching deployment

---

## 4. Turn Phase Data Handoff Matrix

Each phase must correctly pass data to the next. Test the handoff between each pair.

| From Phase | To Phase | Data Handed Off | Edge Cases |
|------------|----------|-----------------|------------|
| STORY | TRAVEL | story_event_results, risk_modifier | No events generated |
| TRAVEL | UPKEEP (World) | destination, travel_costs | Stayed (no travel), 0 credits |
| UPKEEP | CREW_TASKS | remaining_credits, injured_list | All crew injured |
| CREW_TASKS | JOB_OFFERS | task_results, trained_skills | No tasks assigned |
| JOB_OFFERS | EQUIPMENT_ASSIGN | selected_mission, mission_type | No jobs available |
| EQUIPMENT_ASSIGN | MISSION_PREP | crew_loadouts | Empty equipment pool |
| MISSION_PREP | BATTLE | deployed_crew, mission_data | Minimum crew (1-2) |
| BATTLE | POST_BATTLE | battle_result, casualties, loot | All crew dead, auto-resolve |
| POST_BATTLE | ADVANCEMENT | xp_awarded, injury_updates | No XP, all crew recovering |
| ADVANCEMENT | TRADING | advanced_stats | No eligible characters |
| TRADING | CHARACTER | purchased_items, sold_items | No trading done |
| CHARACTER | END | character_events | No events triggered |
| END | STORY (next turn) | turn_summary, save_confirmed | Save failed |

### P0: Sequential Happy Path (1 test)
- Complete full turn with valid data at every handoff

### P1: Null/Empty Data Handoff (13 tests)
- Each handoff with null/empty data from predecessor

### P2: Error Recovery (13 tests)
- Each handoff with invalid/corrupted data

---

## 5. World Generation Matrix

### Dimensions

| Dimension | Values | Count |
|-----------|--------|-------|
| Planet Type | DESERT, ICE, JUNGLE, OCEAN, ROCKY, TEMPERATE, VOLCANIC | 7 |
| Environment | URBAN, FOREST, DESERT, ICE, RAIN, STORM, HAZARDOUS, VOLCANIC, OCEANIC, TEMPERATE, JUNGLE | 11 |
| World Trait | INDUSTRIAL_HUB, FRONTIER_WORLD, TRADE_CENTER, PIRATE_HAVEN, FREE_PORT, CORPORATE_CONTROLLED, TECH_CENTER, MINING_COLONY, AGRICULTURAL_WORLD, FRONTIER, TRADE_HUB, INDUSTRIAL, RESEARCH, CRIMINAL, AFFLUENT, DANGEROUS, CORPORATE, MILITARY | 18 |
| Strife Level | PEACEFUL, UNREST, CIVIL_WAR, INVASION, LOW, MEDIUM, HIGH, CRITICAL | 8 |
| Market State | NORMAL, CRISIS, BOOM, RESTRICTED | 4 |

**Total theoretical**: 7 × 11 × 18 × 8 × 4 = **44,352**

### P0: Independent Tests (48 tests)
- Each planet type (7)
- Each environment (11)
- Each world trait (18)
- Each strife level (8)
- Each market state (4)

### P1: World Trait × Market State (72 tests)
- Validates economic effects (e.g., TRADE_CENTER + BOOM = cheap goods)

### P2: Planet × Strife × Trait (20 random combos)
- Validates no invalid combinations crash

---

## 6. DLC Gating Matrix

### 37 ContentFlags to Test

Each flag needs 3 tests:
1. **Enabled**: Feature accessible, UI shows content
2. **Disabled**: Feature hidden/locked, graceful degradation
3. **Toggle mid-campaign**: Feature appears/disappears without crash

**Total: 111 tests (37 × 3)**

### Priority Grouping

**P0 (Core gameplay flags — 10 flags × 3 = 30 tests):**
- BUG_HUNT_CORE, BUG_HUNT_MISSIONS
- PROGRESSIVE_DIFFICULTY, EXPANDED_MISSIONS
- STEALTH_MISSIONS, STREET_FIGHTS, SALVAGE_JOBS
- CASUALTY_TABLES, DETAILED_INJURIES
- INTRODUCTORY_CAMPAIGN

**P1 (Character/equipment flags — 12 flags × 3 = 36 tests):**
- SPECIES_KRAG, SPECIES_SKULKER
- PSIONICS, PSIONIC_EQUIPMENT
- NEW_TRAINING, BOT_UPGRADES, NEW_SHIP_PARTS
- AI_VARIATIONS, ELITE_ENEMIES
- EXPANDED_FACTIONS, EXPANDED_LOANS, NAME_GENERATION

**P2 (Battle/mode flags — 15 flags × 3 = 45 tests):**
- PVP_BATTLES, COOP_BATTLES
- DEPLOYMENT_VARIABLES, ESCALATING_BATTLES
- DRAMATIC_COMBAT, NO_MINIS_COMBAT
- GRID_BASED_MOVEMENT, TERRAIN_GENERATION
- EXPANDED_QUESTS, EXPANDED_CONNECTIONS
- DIFFICULTY_TOGGLES
- FRINGE_WORLD_STRIFE
- PRISON_PLANET_CHARACTER

---

## 7. Character Advancement Matrix

### XP Cost Verification

| Stat | Cost | Max | Species Exceptions |
|------|------|-----|-------------------|
| reactions | 7 | 6 | — |
| combat | 7 | 5 | — |
| speed | 5 | 8 | — |
| savvy | 5 | 5 | — |
| toughness | 6 | 6 | Engineer can exceed |
| luck | 10 | 3 | Humans only, some aliens -1 |

### Test Cases (36 total — existing)
- Each stat cost (6 tests)
- Each stat at max (6 tests)
- Species-specific max checks (4 tests)
- Eligibility checks (8 tests)
- Application of advancement (6 tests)
- Automated processing (5 tests)
- Invalid stat name → returns 999 (1 test)

### Training Cost Verification

| Training | Cost |
|----------|------|
| PILOT | 20 |
| MECHANIC | 15 |
| MEDICAL | 20 |
| MERCHANT | 10 |
| SECURITY | 10 |
| BROKER | 15 |
| BOT_TECH | 10 |

---

## 8. Equipment Assignment Matrix

### Dimensions

| Dimension | Values | Count |
|-----------|--------|-------|
| Equipment Category | WEAPON, ARMOR, GEAR, CONSUMABLE, SPECIAL | 5 |
| Rarity | COMMON, UNCOMMON, RARE, EPIC, LEGENDARY | 5 |
| Condition | PRISTINE, GOOD, DAMAGED, CRITICAL | 4 |
| Character carrying | Captain, Regular, Bot, Injured, Recovering | 5 |

### P0 Tests (20 tests)
- Each category equips correctly (5)
- Each condition affects sell price (4)
- Each rarity tier generates (5)
- Assign to each character type (5)
- Armor slot limit (1 per character) (1)

---

## Summary: Total Test Cases by Priority

| Priority | Count | Coverage |
|----------|-------|----------|
| P0 (Independent) | ~270 | Each dimension independently |
| P1 (Pairwise) | ~870 | Key dimension pairs |
| P2 (Random/Edge) | ~215 | Triple combos + edge cases |
| **Total** | **~1,355** | Comprehensive coverage |

Recommended execution order: P0 first (catches most bugs), then P1 (interaction bugs), then P2 (polish).
