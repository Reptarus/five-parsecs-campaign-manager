# Five Parsecs Campaign Manager - REALISTIC Framework Bible

## 🎯 The Reality Check

**Current State:**
- **518 GDScript files** in src/
- **175,558 lines of code**
- **Massive complexity**: Full campaign manager, battle system, character creation, world generation

**Original Goal:**
- ❌ Maximum 20 files (UNREALISTIC for this scope)
- ✅ NO Manager pattern (GOOD principle, keep this)
- ✅ Consolidation over separation (GOOD, but needs realistic targets)

---

## 📊 REALISTIC FILE BUDGET

### Tier 1: Core Game (30 files max)
**Essential game logic - cannot be consolidated further**

1. **Character System** (5 files)
   - Character.gd (main resource)
   - CharacterGeneration.gd (creation logic)
   - CharacterSheet.gd (UI display)
   - CharacterBox.gd (UI container)
   - CharacterProgression.gd (advancement)

2. **Campaign System** (6 files)
   - Campaign.gd (main state)
   - CampaignPhase.gd (phase state machine)
   - CampaignCreation.gd (setup workflow)
   - CampaignDashboard.gd (main UI)
   - WorldPhase.gd (world phase logic)
   - UpkeepPhase.gd (upkeep logic)

3. **Battle System** (5 files)
   - Battle.gd (combat core)
   - Battlefield.gd (map/grid)
   - BattleAI.gd (enemy AI)
   - BattleUI.gd (combat interface)
   - BattleResults.gd (post-combat)

4. **Enemy System** (3 files)
   - Enemy.gd (enemy resource + generation)
   - EnemyDatabase.gd (data storage)
   - EnemyInfoPanel.gd (UI display)

5. **Mission System** (3 files)
   - Mission.gd (core + generation)
   - MissionObjective.gd (objectives)
   - MissionSelectionUI.gd (UI)

6. **Core Systems** (8 files)
   - GameState.gd (global state autoload)
   - DiceSystem.gd (dice rolling autoload)
   - DataSystem.gd (data loading)
   - SaveSystem.gd (save/load)
   - EventSystem.gd (campaign events)
   - EconomySystem.gd (credits/trade)
   - PatronSystem.gd (patron jobs)
   - FactionSystem.gd (factions/rivals)

### Tier 2: UI & Screens (20 files max)
**UI screens and components - can be consolidated into scenes**

7. **Main Screens** (8 files)
   - MainMenu.gd
   - CampaignCreationUI.gd
   - MainCampaignScene.gd
   - BattleResolutionUI.gd
   - WorldPhaseUI.gd
   - UpkeepPhaseUI.gd
   - PostBattleResultsUI.gd
   - SaveLoadUI.gd

8. **UI Components** (12 files)
   - StoryTrackPanel.gd
   - VictoryProgressPanel.gd
   - CrewPanel.gd
   - ShipPanel.gd
   - EquipmentPanel.gd
   - ResourceDisplay.gd
   - DiceDisplay.gd
   - TooltipSystem.gd
   - DialogSystem.gd
   - NotificationSystem.gd
   - ThemeSystem.gd
   - AccessibilitySystem.gd

### Tier 3: Data & Resources (15 files max)
**Data structures and game content**

9. **Resources** (8 files)
   - WeaponDatabase.gd
   - ArmorDatabase.gd
   - GearDatabase.gd
   - ShipData.gd
   - PlanetData.gd
   - BackgroundData.gd
   - MissionTypeData.gd
   - EventData.gd

10. **Data Management** (7 files)
   - GlobalEnums.gd
   - TypeRegistry.gd
   - ValidationSystem.gd
   - MigrationAdapter.gd
   - SerializationSystem.gd
   - SecurityValidator.gd
   - PerformanceMonitor.gd

### Tier 4: Utilities & Helpers (10 files max)
**Generic utilities - keep minimal**

11. **Utilities** (10 files)
   - SafeDataAccess.gd
   - ErrorHandler.gd
   - Logger.gd
   - MathUtils.gd
   - StringUtils.gd
   - ArrayUtils.gd
   - SceneRouter.gd
   - SignalBus.gd (autoload)
   - ConfigLoader.gd
   - DebugTools.gd

---

## 🎯 REALISTIC TARGETS

### Current vs Realistic Budget
| Category | Current | Target | Reduction |
|----------|---------|--------|-----------|
| Core Game | ~150 | 30 | -80% |
| UI & Screens | ~120 | 20 | -83% |
| Data & Resources | ~100 | 15 | -85% |
| Utilities | ~80 | 10 | -88% |
| **TOTAL** | **518** | **75** | **-85%** |

**New realistic target: 75 files** (vs original 20)

---

## ✅ REVISED CORE PRINCIPLES

### 1. NO Manager Pattern ✅ KEEP THIS
**Why it's good:**
- Managers are passive containers that just delegate
- Leads to "Manager of Managers" anti-pattern
- Violates Single Responsibility Principle

**Instead use:**
- **Static classes** for stateless utilities (DiceSystem.roll_d6())
- **Autoload singletons** for global state (GameState, SignalBus)
- **Resource classes** for data (Character, Enemy, Mission)
- **Direct methods** on resources (character.level_up(), enemy.generate())

### 2. Consolidation Targets ✅ REALISTIC
**Instead of 20 files, aim for:**
- **75 core files** (85% reduction from 518)
- Group by feature, not by pattern
- One file per major system
- Combine related UI into single screens

### 3. File Size Guidelines ✅ NEW
**Acceptable file sizes:**
- **Core systems**: 500-1500 lines (complex logic)
- **UI screens**: 300-800 lines (scene scripts)
- **Resources**: 200-500 lines (data + methods)
- **Utilities**: 100-300 lines (helpers)

**When to split:**
- File exceeds 2000 lines
- Multiple unrelated responsibilities
- Different team members editing simultaneously

### 4. Forbidden Patterns ✅ KEEP THESE
**NEVER create:**
- ❌ XxxManager classes (use static methods or autoloads)
- ❌ XxxHelper classes (put helpers in relevant files)
- ❌ XxxUtil classes (consolidate into category utils)
- ❌ XxxCoordinator classes (use direct method calls)
- ❌ XxxHandler classes (handle in the class that owns the data)
- ❌ BaseXxx classes with no shared code
- ❌ Multiple inheritance hierarchies

**ALWAYS prefer:**
- ✅ Direct responsibility (Character.level_up(), not CharacterManager.level_up_character())
- ✅ Composition over inheritance
- ✅ Static methods for utilities (DiceSystem.roll(), not DiceManager.instance.roll())
- ✅ Autoload for global state (GameState singleton, not GameStateManager)

---

## 📏 CONSOLIDATION STRATEGY

### Phase 1: Delete Obvious Duplicates (518 → 300)
**Target: -218 files (42% reduction)**

Delete confirmed duplicates:
- 28 Manager duplicates ✅
- 26 Character duplicates ✅
- 11 Enemy duplicates ✅
- 10 Mission duplicates ✅
- ~150 other confirmed duplicates (Base classes, old versions, etc.)

### Phase 2: Merge Similar Files (300 → 150)
**Target: -150 files (50% reduction)**

Merge files by feature:
- Combine all character UI into CharacterSheet.gd
- Merge all battle phases into Battle.gd
- Consolidate all mission generation into Mission.gd
- Combine all economy logic into EconomySystem.gd

### Phase 3: Aggressive Consolidation (150 → 75)
**Target: -75 files (50% reduction)**

Major architectural consolidation:
- Single file per major system
- Combine UI screens that share 80%+ code
- Merge resource types into databases
- Eliminate all "Enhanced" variants

---

## 🚀 IMMEDIATE ACTION ITEMS

### Can Delete NOW (75 files) - Zero Risk
1. ✅ 28 Manager duplicates (script ready)
2. ✅ 26 Character duplicates (need script)
3. ✅ 11 Enemy duplicates (need script)
4. ✅ 10 Mission duplicates (need script)

**Result**: 518 → 443 files (-14%)

### Can Consolidate NEXT (143 files) - Low Risk
5. Merge all Base classes into their implementations
6. Delete all "Enhanced" variants
7. Consolidate UI panels into screens
8. Merge generation systems into core classes

**Result**: 443 → 300 files (-46% total)

### Architectural Refactor (225 files) - Medium Risk
9. Major system consolidation
10. UI screen merging
11. Data layer simplification

**Result**: 300 → 75 files (-85% total)

---

## 💡 BOTTOM LINE

**The 20 file limit was unrealistic** for a project with:
- 175K lines of code
- Full RPG campaign manager
- Complex battle system
- Character progression
- World generation
- Mission system
- Equipment/economy
- Save/load

**New realistic target: 75 files** (vs 518 current)
- **85% reduction** instead of 96%
- **Still achieves** "NO Manager" principle
- **Maintains** consolidation philosophy
- **Preserves** all functionality

**Your instinct was right** - being ultra-strict helped identify problems, but we need realistic targets for a project this large!

Want me to proceed with the **realistic 75-file plan** instead of the impossible 20-file limit?
