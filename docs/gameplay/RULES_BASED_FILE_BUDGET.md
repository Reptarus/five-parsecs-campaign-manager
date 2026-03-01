# Five Parsecs Campaign Manager - Rules-Based File Budget

## 📖 Analysis of core_rules.md (14,648 lines)

### Major Game Systems Identified

**From the official rulebook, Five Parsecs requires:**

#### 1. CHARACTER SYSTEM (Complex)
- Character creation (backgrounds, motivations, classes)
- 6 ability scores (Reactions, Speed, Combat, Toughness, Savvy, Luck)
- Humans, Bots, Primary Aliens (4 types), Strange Characters (7 types)
- Character progression/XP
- Injuries and status
- Equipment/inventory management

#### 2. CAMPAIGN TURN SYSTEM (Very Complex)
**Travel Steps:**
- Decide whether to travel
- Starship travel (FTL)
- New world arrival
- Upkeep and ship repairs

**World Steps (10 steps per turn!):**
1. Flight
2. Patron jobs
3. Notable sights
4. Job offers
5. Assignment missions
6. **Choose your battle**
7. Pre-battle events
8. Battle!
9. Post-battle sequence
10. Character advancement

#### 3. BATTLE SYSTEM (Extremely Complex)
**Readying for Battle (14 substeps!):**
1. Select mission type
2. Deployment conditions
3. Determine enemy (tables!)
4. Set up battlefield
5. Determine objective
6. Notable sights
7. Place enemies
8. Seize initiative
9. Deployment
10. Round 1 events
11. Battlefield events (optional)
12-14. Special rules

**Battle Round:**
- Quick actions phase
- Enemy actions phase
- Slow actions phase
- End phase
- Battle events (optional)

**Combat Mechanics:**
- Movement (dash, combat, quick, slow)
- Line of sight/cover
- Shooting
- Brawling
- Grenades/explosives
- Stun/suppression
- Morale/panic
- Reactions
- Luck points

#### 4. POST-BATTLE SYSTEM (Complex)
- Casualties/injuries
- Loot generation
- Story points
- Quest rumors
- Character advancement
- Campaign events
- Patron status resolution

#### 5. EQUIPMENT/ECONOMY SYSTEM (Complex)
**Weapons (30+):**
- Pistols, rifles, shotguns, heavy weapons
- Melee weapons
- Grenades/explosives
- Alien weapons

**Gear (20+):**
- Armor
- Utility gear
- Consumables
- Ship equipment

**Economy:**
- Credits
- Story points
- Trade goods
- Ship upgrades
- Crew hiring/firing

#### 6. ENEMY SYSTEM (Very Complex)
**Enemy Types (dozens!):**
- Criminal elements
- Hired muscle
- Punks/gangs
- Cultists
- Pirates
- Raiders
- Orks
- Skulker colonies
- Assassins
- Bounty hunters
- Converted/fanatics
- Feral mercenaries
- Starport scum
- Black ops teams
- **Plus:** Roving threats, unique individuals, boss enemies

**Enemy AI:**
- Movement patterns
- Targeting priority
- Special behaviors
- Morale checks

#### 7. MISSION/OBJECTIVE SYSTEM (Complex)
**Mission Types:**
- Patrol
- Move through
- Fight off
- Defend
- Opportunity missions
- Quest missions
- Rival/patron missions
- Story missions

**Objectives:**
- Eliminate all enemies
- Reach location
- Defend position
- Rescue/extraction
- Destroy objective
- Seize objective

#### 8. PATRON/RIVAL/STORY SYSTEM (Complex)
- Patron generation/tracking
- Rival generation/tracking
- Story track progression
- Quest rumors
- Campaign events
- Invasion tracks
- Galactic war

#### 9. WORLD GENERATION (Moderate)
- Planet types
- World traits
- Local factions
- Trade opportunities
- Notable sights

#### 10. SHIP SYSTEM (Moderate)
- Ship types/classes
- Debt tracking
- Hull damage
- Upgrades
- Fuel/maintenance

---

## 🎯 MINIMUM VIABLE FILE COUNT: **45-50 Files**

### Absolute Minimum (45 files)

**Core Game Logic (20 files):**
1. Character.gd (creation + stats + progression)
2. CharacterGeneration.gd (tables + rolling)
3. Crew.gd (crew composition + management)
4. Campaign.gd (campaign state + turn sequence)
5. CampaignTurn.gd (10-step world phase logic)
6. Travel.gd (travel steps + starship)
7. Battle.gd (battle core + round sequence)
8. BattleSetup.gd (14-step battle preparation)
9. Combat.gd (shooting + brawling + reactions)
10. Enemy.gd (enemy data + AI + generation)
11. EnemyGenerator.gd (tables + spawning logic)
12. Mission.gd (mission types + objectives)
13. Loot.gd (post-battle loot generation)
14. Equipment.gd (weapons + gear + management)
15. Patron.gd (patron/rival system)
16. StoryTrack.gd (story progression + quests)
17. World.gd (world generation + traits)
18. Ship.gd (ship management + debt)
19. Economy.gd (credits + trade + shops)
20. DiceSystem.gd (dice rolling + tables - autoload)

**Data/Resources (10 files):**
21. WeaponDatabase.gd (30+ weapons)
22. GearDatabase.gd (armor + utility)
23. EnemyDatabase.gd (enemy types + stats)
24. MissionDatabase.gd (mission definitions)
25. BackgroundDatabase.gd (character backgrounds)
26. WorldDatabase.gd (world types + traits)
27. EventDatabase.gd (campaign events)
28. TableDatabase.gd (all random tables)
29. GlobalEnums.gd (enums + constants)
30. GameConfig.gd (game settings)

**UI Screens (10 files):**
31. MainMenu.gd
32. CampaignCreationUI.gd
33. CampaignDashboard.gd (main campaign screen)
34. BattleUI.gd (tactical combat screen)
35. CharacterSheet.gd (character display/edit)
36. CrewManagement.gd (crew overview)
37. ShipManagement.gd (ship screen)
38. WorldPhaseUI.gd (10-step workflow)
39. PostBattleUI.gd (casualties + loot)
40. SaveLoadUI.gd

**Systems (5 files):**
41. GameState.gd (global state - autoload)
42. SaveSystem.gd (save/load)
43. EventSystem.gd (campaign events)
44. SignalBus.gd (global signals - autoload)
45. ValidationSystem.gd (data validation)

---

## 🎯 REALISTIC OPTIMAL: **60-75 Files**

### With Reasonable Separation (60 files minimum)

Add these for better maintainability:

**Split Battle System (5 files):**
46. BattleEvents.gd (battle events system - optional rule)
47. BattleAI.gd (enemy AI + targeting)
48. BattleObjectives.gd (objective tracking)
49. Terrain.gd (terrain generation + cover)
50. Battlefield.gd (battlefield setup + grid)

**Split UI Components (5 files):**
51. StoryTrackPanel.gd (story track display)
52. VictoryPanel.gd (victory conditions)
53. PatronPanel.gd (patron/rival display)
54. EquipmentPanel.gd (equipment management)
55. DiceRoller.gd (visual dice roller)

**Split Character System (3 files):**
56. CharacterTypes.gd (human/bot/alien variants)
57. CharacterProgression.gd (XP + advancement)
58. Injuries.gd (injury + recovery system)

**Additional Systems (2 files):**
59. Tutorial.gd (tutorial/help system)
60. Achievements.gd (achievements/tracking)

### Maximum Reasonable (75 files)

Add these for polish:

**UI Polish (8 files):**
61-65. Individual UI components (tooltips, dialogs, notifications, theme, accessibility)
66-68. Additional screens (statistics, codex, settings)

**Gameplay Extensions (7 files):**
69-75. Optional rules, expansions, variants, debug tools, performance monitoring, analytics, modding support

---

## 📊 FILE BUDGET COMPARISON

| Scenario | Files | Description |
|----------|-------|-------------|
| **Current** | 518 | Massive duplication |
| **After Dedup** | 443 | Remove 75 confirmed duplicates |
| **Aggressive** | 300 | Major consolidation |
| **Maximum** | 75 | With all polish/features |
| **Optimal** | 60 | Reasonable separation |
| **Minimum Viable** | 45 | Absolute bare minimum |

---

## ✅ RECOMMENDATION: **60 Files**

**Why 60 is the sweet spot:**

1. **Matches game complexity** - Five Parsecs has 10+ major systems
2. **Maintainable file sizes** - 500-1000 lines per file (reasonable)
3. **Clear separation** - One file per major game system
4. **Room for polish** - UI components, optional rules
5. **Not dogmatic** - Practical over theoretical

**File size targets:**
- Average: ~2,900 lines per file (175K / 60)
- Core systems: 800-1500 lines (complex logic)
- UI screens: 400-800 lines (scene scripts)
- Databases: 300-600 lines (data + helpers)
- Utilities: 200-400 lines (focused helpers)

---

## 🎯 IMMEDIATE GOAL: Get to 60 Files

**Current: 518 files**
**Target: 60 files**
**Reduction needed: 458 files (88.4%)**

**Phase 1**: Delete 75 duplicates → 443 files (-14%)
**Phase 2**: Consolidate systems → 300 files (-42%)
**Phase 3**: Major refactor → 60 files (-88%) ✅

This is **achievable** and **maintains all functionality** from the 14,648-line rulebook!
