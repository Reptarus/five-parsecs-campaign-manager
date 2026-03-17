# Codebase Optimization & Consolidation Audit — Five Parsecs Campaign Manager

**Date**: 2026-03-16
**Scope**: ~900 GDScript files, Godot 4.6-stable
**Purpose**: Documentation-only audit. No code changes — cataloguing issues, causes, and solutions for future sprints.
**Two initiatives**: Part A = Performance/Quality Optimization | Part B = Structural Consolidation

---

## Context

The project has reached 100% game mechanics compliance (170/170) and demo-ready status. This audit shifts focus from feature development to **technical debt reduction and runtime optimization**. Three parallel scans covered: structural/architecture, performance/runtime, and data integrity/code quality. Key optimization recommendations were validated against Godot 4.6 official documentation via Context7.

---

## Table of Contents

### Part A: Performance/Quality Optimization
1. [CRITICAL: Signal Memory Leaks](#1-critical-signal-memory-leaks)
2. [CRITICAL: Synchronous Startup I/O](#2-critical-synchronous-startup-io)
3. [HIGH: Inefficient Data Lookups](#3-high-inefficient-data-lookups)
4. [HIGH: Excessive Unconditional Preloading](#4-high-excessive-unconditional-preloading)
5. [HIGH: Serialization Bug in FiveParsecsCampaignCore](#5-high-serialization-bug-in-fiveparsecscampaigncore)
6. [HIGH: Magic Numbers / Hardcoded Costs](#6-high-magic-numbers--hardcoded-costs)
7. [HIGH: Save/Load Robustness Gaps](#7-high-saveload-robustness-gaps)
8. [MEDIUM: Dictionary Memory Waste](#8-medium-dictionary-memory-waste)
9. [MEDIUM: String Concatenation GC Pressure](#9-medium-string-concatenation-gc-pressure)
10. [MEDIUM: Dead Code / Unused Classes](#10-medium-dead-code--unused-classes)
11. [MEDIUM: Type Safety Gaps](#11-medium-type-safety-gaps)
12. [LOW: _process() Usage Review](#12-low-_process-usage-review)
13. [Implementation Roadmap](#implementation-roadmap)

### Part B: Structural Consolidation
14. [GOD OBJECTS: Oversized Files](#14-god-objects-oversized-files)
15. [CRITICAL: Utility/Safety Class Proliferation](#15-critical-utilitysafety-class-proliferation)
16. [HIGH: Duplicate File Groups](#16-high-duplicate-file-groups)
17. [HIGH: World Phase Component Consolidation](#17-high-world-phase-component-consolidation)
18. [HIGH: Character.gd Decomposition](#18-high-charactergd-decomposition)
19. [HIGH: GameEnums.gd Decomposition](#19-high-gameenumsgd-decomposition)
20. [MEDIUM: Autoload Consolidation](#20-medium-autoload-consolidation)
21. [MEDIUM: Cross-Cutting Pattern Deduplication](#21-medium-cross-cutting-pattern-deduplication)
22. [LOW: Parallel Directory Trees](#22-low-parallel-directory-trees)
23. [Consolidation Roadmap](#23-consolidation-roadmap)

---

# PART A: PERFORMANCE / QUALITY OPTIMIZATION

---

## 1. CRITICAL: Signal Memory Leaks

### Verified Metrics
| Metric | Count |
|--------|-------|
| `.connect()` calls in `src/` | **1,280** across 284 files |
| `.disconnect()` calls in `src/` | **113** across 37 files |
| `_exit_tree()` implementations | **26** across 26 files |
| **Leak ratio** | **11.3:1** (connects to disconnects) |

### Root Cause
UI panels and components connect to long-lived autoload signals (GameState, CampaignPhaseManager, etc.) in `_ready()` but never disconnect in `_exit_tree()`. When scenes are freed, the autoload retains references to dead callables.

### Worst Offenders (by connect count)
| File | Connects | Disconnects |
|------|----------|-------------|
| `src/ui/screens/battle/TacticalBattleUI.gd` | 58 | 6 |
| `src/ui/screens/postbattle/PostBattleSequence.gd` | 32 | 0 |
| `src/ui/screens/campaign/CampaignTurnController.gd` | 32 | 25 |
| `src/ui/screens/SaveLoadUI.gd` | 28 | 1 |
| `src/ui/screens/campaign/CampaignDashboard.gd` | 23 | 0 |
| `src/core/character/Generation/SimpleCharacterCreator.gd` | 21 | 0 |
| `src/ui/screens/campaign/CampaignCreationUI.gd` | 19 | 0 |

### Context7 Validation
Godot docs (running_code_in_editor.md, openxr_spatial_entities.md) explicitly demonstrate the pattern:
```gdscript
# CORRECT: Disconnect in _exit_tree() to prevent memory leaks
func _exit_tree():
    if signal_source.is_connected("signal_name", _handler):
        signal_source.signal_name.disconnect(_handler)
```

### Estimated Impact
- ~200 bytes per leaked connection
- ~1,167 uncleaned connections = **~233KB per campaign lifecycle**
- Long campaigns (50+ turns with scene transitions): **1-3MB cumulative**

### Recommended Fix
For each file with `.connect()` calls to autoloads, add matching `_exit_tree()` cleanup:
```gdscript
func _exit_tree() -> void:
    # Disconnect all autoload signal connections
    if GameState.campaign_loaded.is_connected(_on_campaign_loaded):
        GameState.campaign_loaded.disconnect(_on_campaign_loaded)
    if CampaignPhaseManager.phase_entered.is_connected(_on_phase_entered):
        CampaignPhaseManager.phase_entered.disconnect(_on_phase_entered)
```

**Note**: The project already has `src/core/systems/SignalConnectionManager.gd` and `src/core/memory/MemoryLeakPrevention.gd` — evaluate whether these existing utilities can be leveraged before writing new cleanup code.

---

## 2. CRITICAL: Synchronous Startup I/O

### Root Cause
`GameDataManager._ready()` loads 13+ JSON files sequentially at startup, blocking the main thread. Each file goes through `FileAccess.open()` → `get_as_text()` → `JSON.new()` → `parse()`.

### Estimated Timing
- ~190ms per file × 13 files = **~2,470ms blocked startup**
- Plus TacticalBattleUI's 33 unconditional preloads
- **Total perceived delay: 3+ seconds black screen**

### Key Files
- `src/core/managers/GameDataManager.gd` — 13 sequential JSON loads in `_ready()`
- Data files in `data/` directory (injury_tables, enemy_types, gear_database, etc.)

### Context7 Validation
Godot docs confirm `preload()` loads at scene-load time (blocks), while `load()` loads at runtime (deferred). The docs also show `@onready var json_resource = load("res://demo.json")` as the pattern for deferred JSON loading.

### Recommended Fix — Two Phases

**Phase 1: Singleton JSON Parser** (eliminate repeated `JSON.new()`)
```gdscript
var _json_parser: JSON = JSON.new()  # Reuse single instance

func _load_json_file(path: String) -> Variant:
    var file = FileAccess.open(path, FileAccess.READ)
    if not file: return {}
    var error = _json_parser.parse(file.get_as_text())
    return _json_parser.data if error == OK else {}
```

**Phase 2: Lazy Loading** (load data on first access, not at startup)
```gdscript
var _injury_tables: Dictionary = {}
var _injury_tables_loaded: bool = false

func get_injury_tables() -> Dictionary:
    if not _injury_tables_loaded:
        _injury_tables = _load_json_file(INJURY_TABLE_PATH)
        _injury_tables_loaded = true
    return _injury_tables
```

### Estimated Impact
- Startup reduction: **1.5-2s**
- Memory savings: **~3MB** (unused data not loaded until needed)

---

## 3. HIGH: Inefficient Data Lookups

### Root Cause
`GameDataManager` getter methods use O(n) nested loops for keyed lookups that should be O(1) Dictionary access.

### Affected Methods
| Method | Pattern | Worst-Case Iterations |
|--------|---------|----------------------|
| `get_enemy_type(id)` | Nested loop over categories x enemies | ~500 |
| `get_mission_template(id)` | Linear scan of ~100 templates | ~100 |
| `get_weapon_by_id(id)` | Linear scan | ~200 |
| `get_armor_by_id(id)` | Linear scan | ~150 |
| `get_status_effect_by_id(id)` | Linear scan | ~50 |
| `get_character_creation_option(id)` | Linear scan | ~80 |

### Call Volume
- Battle initialization: ~5 `get_enemy_type()` calls per enemy spawn
- Per battle: **200-300 O(n) lookups**
- 10-turn campaign: **1-2 seconds cumulative**

### Context7 Validation
Godot docs (data_preferences.md) confirm: Array is `Vector<Variant>` (contiguous memory, good for iteration) but Dictionary provides O(1) keyed access. For ID-based lookups, Dictionary is the correct choice.

### Recommended Fix
Build index maps at load time:
```gdscript
var _enemy_types_index: Dictionary[String, Dictionary] = {}

func _build_enemy_types_index() -> void:
    for category in _raw_enemy_data.get("enemy_categories", []):
        for enemy in category.get("enemies", []):
            _enemy_types_index[enemy.get("id", "")] = enemy

func get_enemy_type(enemy_id: String) -> Dictionary:
    return _enemy_types_index.get(enemy_id, {})  # O(1)
```

---

## 4. HIGH: Excessive Unconditional Preloading

### Root Cause
`src/ui/screens/battle/TacticalBattleUI.gd` has **33 unconditional `preload()` statements** (lines 17-49). Every battle loads all 33 scenes regardless of battle mode (standard, bug_hunt, stealth, escalating).

### Estimated Waste
- 33 scenes x ~350KB avg = **~11.6MB loaded**
- Per battle: only 8-14 scenes actually used -> **45-75% wasted**

### Context7 Validation
Godot docs confirm: `preload()` loads at scene-load time. `load()` loads at runtime. For mode-dependent resources, lazy `load()` with caching is the documented best practice.

### Recommended Fix
Replace unconditional preloads with a lazy-load cache:
```gdscript
var _scene_cache: Dictionary = {}
const _SCENE_REGISTRY: Dictionary = {
    "tier_selection": "res://src/ui/components/battle/TierSelectionPanel.gd",
    "battle_journal": "res://src/ui/components/battle/BattleJournal.tscn",
    # ... remaining 31 entries
}

func _get_scene(key: String) -> Resource:
    if key not in _scene_cache:
        _scene_cache[key] = load(_SCENE_REGISTRY[key])
    return _scene_cache[key]
```

### Estimated Impact
- Memory savings: **6-8MB per battle**
- Battle init speedup: **200-400ms**

---

## 5. HIGH: Serialization Bug in FiveParsecsCampaignCore

### Root Cause
`src/game/campaign/FiveParsecsCampaignCore.gd`, line 303 -- `from_dictionary()` assigns the **entire campaign data dict** to `_pending_qol_data` instead of extracting just the QoL sub-dict:

```gdscript
# BUG: Assigns entire dict
if data.has("qol_data"):
    _pending_qol_data = data.duplicate(true)  # WRONG

# FIX: Extract the correct sub-key
if data.has("qol_data"):
    _pending_qol_data = data.get("qol_data", {}).duplicate(true)
```

### Impact
QoL data deferred loading via `apply_pending_qol_data()` receives the full campaign state instead of QoL-specific data, causing potential silent corruption of CampaignJournal, NPCTracker, and TurnPhaseChecklist state.

### Severity
**HIGH** -- data corruption risk during campaign load. Needs verification: does `apply_pending_qol_data()` filter keys internally (mitigating the bug) or does it blindly consume the dict?

---

## 6. HIGH: Magic Numbers / Hardcoded Costs

### Root Cause
Economy values (upkeep, travel, equipment costs) are hardcoded as literal numbers across multiple files with no centralized constants.

### Affected Files
| File | Hardcoded Values |
|------|-----------------|
| `CampaignPhaseManager.gd` (lines 806-816) | `crew_cost = members.size() * 10`, `ship_cost = 50`, `equipment_cost * 5` |
| `WorldPhase.gd` (lines 47-51) | `base_crew_4_to_6: 1`, `additional_crew: 1`, `sick_bay_per_patient: 1` |
| `TravelPhase.gd` | `starship_travel: 5`, `commercial_passage_per_crew: 1` |
| `GameStateManager.gd` (lines 116-145) | Hardcoded string keys `"credits"`, `"supplies"`, `"reputation"` |

### Recommended Fix
Create a centralized `CampaignEconomyConstants.gd`:
```gdscript
class_name CampaignEconomyConstants

# Core Rules p.25 -- Upkeep
const UPKEEP_PER_CREW_MEMBER := 1
const UPKEEP_SICK_BAY_PER_PATIENT := 1
# Core Rules p.64 -- Travel
const TRAVEL_STARSHIP := 5
const TRAVEL_COMMERCIAL_PER_CREW := 1
# etc.
```

---

## 7. HIGH: Save/Load Robustness Gaps

### Issues Found in SaveManager.gd

**7a. Incomplete Error Recovery** (lines 67-68)
- Backup load failure and "no backup exists" emit identical `(false, {})` signal
- Player cannot distinguish between recoverable and unrecoverable corruption
- Fix: Emit distinct error codes

**7b. Version Mismatch Allows Incompatible Loads** (line 75)
- `push_warning()` on version mismatch but proceeds to load anyway
- Incompatible save files may load silently with data loss
- Fix: Implement version compatibility checking or migration logic

**7c. No Schema Validation on Campaign Init** (FiveParsecsCampaignCore lines 96-106)
- `initialize_resources()` accepts unvalidated Dictionary -- no type checks, no range validation
- Negative credits, invalid arrays, wrong types all accepted silently
- Fix: Add validation at the Resource boundary

---

## 8. MEDIUM: Dictionary Memory Waste

### Root Cause
`PlanetDataManager.serialize()` creates a new Dictionary on every call (including 17+ fields with Array duplicates). Called 50-300 times per campaign lifecycle.

### Estimated Impact
- ~800 bytes per call x 300 calls = **~240KB garbage per campaign**
- GC pressure from frequent intermediate allocations

### Recommended Fix
Cache serialization results, invalidate on mutation:
```gdscript
var _serialize_cache: Dictionary = {}
var _cache_dirty: bool = true

func serialize() -> Dictionary:
    if _cache_dirty:
        _serialize_cache = { ... }
        _cache_dirty = false
    return _serialize_cache
```

---

## 9. MEDIUM: String Concatenation GC Pressure

### Root Cause
56 occurrences of `+=` string concatenation in UI code, creating intermediate String objects that become garbage.

### Recommended Fix (Context7 validated)
Use format strings or `"\n".join()`:
```gdscript
# Before (3 intermediate allocations):
var desc = ""
desc += "Name: " + character.name
desc += ", Level: " + str(character.level)

# After (1 allocation):
var desc = "Name: %s, Level: %d" % [character.name, character.level]
```

---

## 10. MEDIUM: Dead Code / Unused Classes

### Metrics
- **108 classes** identified with zero references across the codebase
- **36 mapped** to exact file paths; **72 remain unmapped**
- **2 intentionally disabled autoloads**: `zzzCharacterManager`, `zzzBattleStateMachine`

### Notable Categories
- **FPCM_-prefixed classes**: 64 total; several may be orphaned from refactoring
- **Multiple class_name declarations** that are never instantiated, preloaded, or referenced
- **PostBattlePhase.gd**: 11 methods containing only `pass` (lines 230-270) -- stub implementations

### Recommended Approach
1. Complete the file-path mapping for remaining 72 classes
2. Verify each with `grep` for runtime string-based references (e.g., `get_node()`, `load()`)
3. Remove confirmed dead code in batches with compile verification between batches

---

## 11. MEDIUM: Type Safety Gaps

### Root Cause
Mix of untyped `var x =` declarations in critical code paths. Godot 4.6 supports typed Dictionaries (`Dictionary[String, int]`) and typed Arrays (`Array[Character]`), but many collections use untyped variants.

### Context7 Validation
Godot 4.6 docs confirm `Dictionary[KeyType, ValueType]` syntax is available and enforces type safety at assignment time.

### Key Areas for Improvement
- `GameStateManager` temp_data: `Dictionary` -> `Dictionary[String, Variant]`
- Campaign data accessors: `.get()` returns untyped -> add explicit type annotations
- Phase action tracking: `phase_actions_completed` uses stringly-typed keys

---

## 12. LOW: _process() Usage Review

### Current Usage
Only **1 GDScript file** in `src/` uses `_process()`: `src/ui/components/tooltip/TooltipManager.gd`

### Context7 Validation
For occasional checks, Godot docs recommend `Engine.get_process_frames() % N == 0` to throttle expensive logic within `_process()`. For most UI updates, signal-driven updates or Timer nodes are preferred.

### Assessment
This is already well-managed. The project correctly avoids `_process()` in favor of signals and timers. No action needed unless TooltipManager's usage is problematic.

---

## 13. Implementation Roadmap (Part A)

### Priority Order (estimated effort)

| # | Issue | Severity | Est. Effort | Files Affected |
|---|-------|----------|-------------|----------------|
| 1 | Signal memory leaks | CRITICAL | 4-6 hours | ~250 files (systematic) |
| 2 | Synchronous startup I/O | CRITICAL | 2-3 hours | GameDataManager + callers |
| 3 | Data lookup indexing | HIGH | 1-2 hours | GameDataManager |
| 4 | Unconditional preloading | HIGH | 1-2 hours | TacticalBattleUI |
| 5 | Serialization bug CRI-001 | HIGH | 30 min | FiveParsecsCampaignCore |
| 6 | Magic numbers extraction | HIGH | 2-3 hours | 4-5 phase files |
| 7 | Save/load robustness | HIGH | 2-3 hours | SaveManager + GameState |
| 8 | Dictionary caching | MEDIUM | 1 hour | PlanetDataManager |
| 9 | String concatenation | MEDIUM | 1 hour | ~56 UI occurrences |
| 10 | Dead code removal | MEDIUM | 3-4 hours | ~108 files |
| 11 | Type safety annotations | MEDIUM | 2-3 hours | Core managers/state |
| 12 | _process() review | LOW | 15 min | 1 file |

**Total estimated effort**: ~20-30 hours across 10-15 sessions

### Verification Plan
After each sprint:
1. **Compile check**: `Godot --headless --quit --path <project>` (zero errors)
2. **Editor reboot**: LSP validates all scripts (headless misses some)
3. **MCP runtime test**: Campaign creation -> Turn 1 -> Battle entry flow
4. **gdUnit4 regression**: Run affected test suites

### Dependencies
- Signal cleanup (Item 1) should happen first -- it affects the most files and reduces memory baseline
- Startup I/O (Item 2) and lookup indexing (Item 3) can be combined in one sprint
- Serialization bug (Item 5) is a quick standalone fix
- Dead code removal (Item 10) should happen last to avoid conflicts with other changes

### Existing Utilities to Leverage
- `src/core/systems/SignalConnectionManager.gd` -- evaluate for signal cleanup orchestration
- `src/core/memory/MemoryLeakPrevention.gd` -- may already address some leak patterns
- `src/core/memory/UniversalCleanupFramework.gd` -- cleanup helpers
- `src/core/memory/CleanupHelpers.gd` -- additional cleanup utilities
- `src/core/performance/PerformanceOptimizer.gd` -- may have relevant patterns

---
---

# PART B: STRUCTURAL CONSOLIDATION AUDIT

---

## 14. GOD OBJECTS: Oversized Files

### Top 20 Files by Line Count
137 files exceed 400 lines. Top candidates for decomposition:

| Rank | File | Lines | Domain |
|------|------|-------|--------|
| 1 | `src/core/campaign/phases/PostBattlePhase.gd` | **4,204** | Post-battle sequence |
| 2 | `src/ui/screens/world/WorldPhaseAutomationController.gd` | **2,469** | World phase automation |
| 3 | `src/ui/screens/battle/TacticalBattleUI.gd` | **2,238** | Battle UI orchestration |
| 4 | `src/ui/screens/campaign/panels/EquipmentPanel.gd` | **2,026** | Equipment management UI |
| 5 | `src/core/battle/BattleCalculations.gd` | **1,828** | Battle math |
| 6 | `src/ui/screens/postbattle/PostBattleSequence.gd` | **1,706** | Battle outcome UI |
| 7 | `src/ui/screens/campaign/panels/WorldInfoPanel.gd` | **1,683** | World info display |
| 8 | `src/core/campaign/phases/WorldPhase.gd` | **1,624** | World exploration |
| 9 | `src/core/character/Generation/CharacterGeneration.gd` | **1,605** | Character creation |
| 10 | `src/ui/screens/campaign/CampaignCreationCoordinator.gd` | **1,584** | Campaign creation |
| 11 | `src/ui/screens/campaign/panels/ShipPanel.gd` | **1,539** | Ship management UI |
| 12 | `src/ui/screens/world/WorldPhaseController.gd` | **1,528** | World phase UI |
| 13 | `src/core/equipment/EquipmentManager.gd` | **1,429** | Equipment ops |
| 14 | `src/ui/screens/campaign/CampaignDashboard.gd` | **1,415** | Dashboard |
| 15 | `src/ui/screens/world/components/CrewTaskComponent.gd` | **1,394** | Crew tasks UI |
| 16 | `src/core/enums/GameEnums.gd` | **1,373** | Enum definitions |
| 17 | `src/core/campaign/CampaignCreationStateManager.gd` | **1,357** | Creation state |
| 18 | `src/ui/screens/campaign/panels/ExpandedConfigPanel.gd` | **1,309** | Config UI |
| 19 | `src/ui/screens/campaign/panels/FinalPanel.gd` | **1,273** | Final review UI |
| 20 | `src/core/systems/GlobalEnums.gd` | **1,225** | Global enums |

### PostBattlePhase.gd -- Extreme God Object (4,204 lines)

**64 functions** across **25+ responsibility domains**:

| Domain | Functions | LOC Est. | Extractable? |
|--------|-----------|----------|-------------|
| Rival Management | 4 | ~200 | YES -> RivalResolver.gd |
| Patron Management | 4 | ~200 | YES -> PatronResolver.gd |
| Quest Tracking | 3 | ~100 | YES -> QuestTracker.gd |
| Payment Processing | 2 | ~150 | YES -> PaymentProcessor.gd |
| Battlefield Finds | 2 | ~150 | YES -> BattlefieldFindResolver.gd |
| Loot Management | 4 | ~200 | YES -> LootGatherer.gd |
| Injury Resolution | 6 | ~400 | YES -> InjuryResolver.gd |
| Experience Calculation | 8 | ~350 | YES -> ExperienceCalculator.gd |
| Training Enrollment | 3 | ~200 | YES -> TrainingEnroller.gd |
| Campaign Events | 6 | ~250 | YES -> CampaignEventHandler.gd |
| Character Events | 3 | ~150 | YES -> CharacterEventHandler.gd |
| Galactic War | 8 | ~300 | YES -> GalacticWarResolver.gd |
| Character Statistics | 4 | ~200 | YES -> BattleStatisticsRecorder.gd |
| Config/Init/Completion | 6 | ~150 | Keep in PostBattlePhase |
| Dice Operations | 2 | ~20 | Keep (utility) |

**Decomposition strategy**: Extract 12-13 domain subsystems as RefCounted classes. PostBattlePhase becomes an orchestrator (~400 lines) that delegates to subsystems. Backward-compatible -- no public API change.

---

## 15. CRITICAL: Utility/Safety Class Proliferation

### The Problem
The codebase has **11+ utility/safety/monitoring classes** that form a 4-tier enterprise architecture. Several overlap or are pure wrappers.

### Four-Tier Architecture Map

**Tier 1 -- Memory Management (4 files, ~2,045 lines total)**
| File | Lines | Role | Needed? |
|------|-------|------|---------|
| `src/core/memory/UniversalCleanupFramework.gd` | 457 | Core orchestration (8 cleanup patterns, 5 priority levels) | YES -- core |
| `src/core/memory/CleanupHelpers.gd` | 268 | Pure wrapper/facade -- NO unique functionality | **DELETE -- merge into UCF** |
| `src/core/memory/MemoryLeakPrevention.gd` | 709 | Leak detection (85MB warn, 110MB critical) | YES -- detection |
| `src/core/memory/MemoryPerformanceOptimizer.gd` | 611 | Object pooling (9 types) + profiling | YES -- optimization |

**Tier 2 -- Error Handling (3 files, ~1,861 lines total)**
| File | Lines | Role | Needed? |
|------|-------|------|---------|
| `src/core/error/ProductionErrorHandler.gd` | 731 | Error capture (5 severity, 7 recovery strategies) | YES -- core |
| `src/core/error/UniversalErrorBoundary.gd` | 482 | safe_call/safe_get/safe_set wrapper | EVALUATE -- may overlap |
| `src/core/error/SystemErrorIntegrator.gd` | 648 | Auto-injects error boundaries into systems | EVALUATE -- may be overkill |

**Tier 3 -- Health Monitoring (4 files, ~1,829 lines total)**
| File | Lines | Role | Needed? |
|------|-------|------|---------|
| `src/core/monitoring/IntegrationHealthMonitor.gd` | 330 | Backend system health (6 systems) | EVALUATE |
| `src/core/production/ProductionPerformanceMonitor.gd` | 580 | FPS, memory, load times | EVALUATE |
| `src/core/state/StateConsistencyMonitor.gd` | 527 | UI-state consistency | EVALUATE |
| `src/core/campaign/creation/CampaignCreationErrorMonitor.gd` | 392 | Campaign-specific errors | EVALUATE |

### Consolidation Targets

**Definite merge (HIGH confidence):**
- **CleanupHelpers.gd -> merge into UniversalCleanupFramework.gd** (268 lines eliminated, pure delegation wrapper)

**Evaluate for merging (MEDIUM confidence):**
- IntegrationHealthMonitor + StateConsistencyMonitor -> both monitor system health, could share alert aggregation
- ProductionPerformanceMonitor + ProductionErrorHandler -> both track health scores and generate recommendations
- All 4 monitoring files -> could become a single `ProductionMonitor.gd` (~800 lines) with subsystem modules

**Question for implementation**: Is the monitoring tier actually used in production, or was it scaffolded speculatively? If monitoring methods are never called from game code, the entire tier may be dead code.

---

## 16. HIGH: Duplicate File Groups

### Verified Duplicate Groups (17+ groups, 40+ files)

Same-named files in different directories -- some are intentional (thin redirects, battle variants), others are legacy copies.

| File Name | Copies | Locations | Assessment |
|-----------|--------|-----------|------------|
| **Character.gd** | 5 | core/character/, core/character/Base/, game/character/, battle/character/, core/battle/character/ | 1 canonical + 1 base + 3 redirect/variant |
| **Enemy.gd** | 4 | core/enemy/, battle/enemy/, core/enemy/base/, core/battle/enemy/ | Need content comparison |
| **EquipmentManager.gd** | 2 | core/equipment/ (autoload), ui/screens/equipment/ | Name collision -- different purposes |
| **GalacticWarManager.gd** | 2 | core/managers/, ui location? | Need content comparison |
| **CharacterCreator.gd** | 2 | core/character/Generation/, unknown | Need content comparison |
| **GameDataManager.gd** | 2 | core/managers/ (autoload), unknown | Need content comparison |
| **BattlefieldGenerator.gd** | 3 | core/battle/, unknown locations | Need content comparison |
| **EnemyData.gd** | 3 | Multiple locations | Need content comparison |
| **CharacterBox.gd** | 3 | Multiple locations | Need content comparison |
| **CampaignManager.gd** | 2 | Multiple locations | Need content comparison |
| + 7 more groups | 2 each | Various | Need content comparison |

### BattleEnemyResource.gd -- Confirmed 99% Duplicate
- `BattleEnemyResource.gd` is 99% identical to `EnemyResource.gd`
- Only differences: `weapon_range` default (1.0 vs 2.0), `movement_range` default (4.0 vs 5.0)
- **Fix**: Merge into EnemyResource with configurable defaults

### Recommended Approach
1. Content-compare each group with `diff`
2. Classify: intentional variant / thin redirect / legacy copy / true duplicate
3. Merge true duplicates, delete legacy copies, document intentional variants

---

## 17. HIGH: World Phase Component Consolidation

### The Problem
10 world phase components all extend `Control` directly, ignoring the `WorldPhaseComponent` base class (111 lines) that defines their intended lifecycle interface.

### Components (10 files)
| Component | Lines | Inherits WorldPhaseComponent? |
|-----------|-------|------------------------------|
| UpkeepPhaseComponent.gd | 361 | NO |
| JobOfferComponent.gd | 948 | NO |
| CrewTaskComponent.gd | ~1,394 | NO |
| AssignEquipmentComponent.gd | 545 | NO |
| CampaignEventComponent.gd | 240 | NO |
| CharacterEventComponent.gd | 293 | NO |
| PurchaseItemsComponent.gd | 412 | NO |
| ResolveRumorsComponent.gd | 343 | NO |
| MissionPrepComponent.gd | 509 | NO |
| (10th component TBD) | -- | NO |

### Six Consolidation Opportunities

**17a. Inheritance refactoring** -- Refactor all 10 to extend WorldPhaseComponent
- Gains: shared init template, standardized event bus, common signals
- Risk: LOW | LOC saved: ~100-150

**17b. Event bus pattern standardization** -- 3 different patterns found:
- Pattern 1: Assert-based (UpkeepPhaseComponent) -- RECOMMENDED
- Pattern 2: Silent null-guard (6 components) -- hides bugs
- Pattern 3: Fallback creation (MissionPrepComponent) -- creates orphan autoloads
- Risk: LOW | LOC saved: ~30-50

**17c. Design constants deduplication** -- `TOUCH_TARGET_MIN=48`, spacing/color values hardcoded inline in 4+ components instead of referencing UIColors
- Risk: LOW | LOC saved: ~20-30

**17d. Character polymorphism helper** -- Identical Dictionary-vs-Object member access pattern duplicated across 5+ components
```gdscript
# This pattern appears in 5+ files:
if member is Dictionary:
    member_id = member.get("id", member.get("character_id", ""))
elif member is Object and "character_id" in member:
    member_id = member.character_id
```
- Fix: Extract to `CharacterPolymorph.gd` with static helpers
- Risk: LOW-MEDIUM | LOC saved: ~50-80

**17e. Safe property access helper** -- Nested null-guard chains for campaign->mission->location duplicated across 5+ components
- Risk: MEDIUM | LOC saved: ~40-60

**17f. Rules tables externalization** -- 7 Core Rules reference tables embedded as code (D100 event tables, weapon tables, etc.)
- Fix: Move to `data/world_phase/*.json`
- Risk: MEDIUM | LOC saved: ~100-150

**Total estimated savings**: 340-520 lines across ~40 files

---

## 18. HIGH: Character.gd Decomposition

### Current State
`src/core/character/Character.gd` -- **1,159 lines**, 942 references, 12 responsibility clusters

### Decomposition Candidates (7 subsystems)

| Extracted Class | Source Domain | Est. Lines | Risk |
|----------------|--------------|-----------|------|
| `ImplantSystem.gd` | Implant management (max 3) | ~200 | LOW |
| `BotUpgradeSystem.gd` | Bot-specific mechanics | ~150 | LOW |
| `ReactionEconomySystem.gd` | Battle action economy | ~100 | LOW |
| `CombatModifierSystem.gd` | Battle calculation modifiers | ~250 | LOW |
| `CharacterGeneration.gd` (exists) | Creation workflow | ~400 | ALREADY EXTRACTED |
| `InjuryManagementSystem.gd` | Injury tracking/recovery | ~300 | MEDIUM |
| `CharacterAdvancementSystem.gd` | XP spending/advancement | ~200 | MEDIUM |

### Strategy
- Composition pattern: Character.gd keeps public API, delegates to subsystem `.new()` instances
- Facade methods remain on Character for backward compatibility (942 references unchanged)
- Character.gd shrinks from ~1,159 to ~400 lines (orchestrator + properties + serialization)

---

## 19. HIGH: GameEnums.gd Decomposition

### Current State
`src/core/enums/GameEnums.gd` -- **1,373 lines**, 1,048 references (highest coupling in entire codebase), 85+ enum declarations

### Proposed Domain Split

| New File | Enum Groups | Est. Lines |
|----------|------------|-----------|
| `BattleEnums.gd` | TerrainType, DeploymentType, BattlePhase, VictoryCondition, etc. | ~300 |
| `CampaignEnums.gd` | CampaignPhase, TurnPhase, MissionType, etc. | ~250 |
| `CharacterEnums.gd` | CharacterClass, CharacterStatus, Origin, Background, etc. | ~200 |
| `EquipmentEnums.gd` | WeaponType, ArmorType, GearType, ItemRarity, etc. | ~200 |
| `TerrainEnums.gd` | TerrainCategory, TerrainFeature, CoverType, etc. | ~150 |

### Backward Compatibility Strategy
GameEnums.gd becomes a **re-export facade** (no import changes needed for 1,048 references):
```gdscript
# GameEnums.gd -- thin re-export facade (~50 lines)
const BattleEnums = preload("res://src/core/enums/BattleEnums.gd")
const CampaignEnums = preload("res://src/core/enums/CampaignEnums.gd")
# Existing access patterns still work:
# GameEnums.BattlePhase.SETUP -> BattleEnums.BattlePhase.SETUP (via const)
```

### Risk
MEDIUM -- enum ordinal values must be preserved exactly. Any reordering breaks save/load.

---

## 20. MEDIUM: Autoload Consolidation

### Current State: 22+ Autoloads
Every autoload adds to startup time and global namespace. Some may be candidates for merging.

### Consolidation Candidates

**World data cluster** (3 autoloads -> 1):
- `PlanetDataManager` + `PlanetCache` + `WorldEconomyManager` -> `WorldSystem.gd`
- These three are tightly coupled and always used together

**Campaign QoL cluster** (3 autoloads -> 1):
- `CampaignJournal` + `TurnPhaseChecklist` + `NPCTracker` -> `CampaignQoL.gd`
- Always loaded/saved together via `apply_pending_qol_data()`

**Disabled autoloads** (2 -> remove):
- `zzzCharacterManager` -- intentionally disabled, legacy
- `zzzBattleStateMachine` -- intentionally disabled, legacy
- Verify zero runtime references, then remove from project.godot

### Impact
- Reduces autoload count from 22+ to ~17
- Simplifies initialization order
- Reduces global namespace pollution

---

## 21. MEDIUM: Cross-Cutting Pattern Deduplication

### 21a. Autoload Null-Guard Boilerplate
Pattern `get_node_or_null("/root/X")` appears **hundreds of times** across the codebase. Each file that accesses an autoload writes its own guard.

**Fix**: Since autoloads are guaranteed to exist (registered in project.godot), most null-guards are unnecessary. For truly optional access, a single `AutoloadHelper.get_optional(name)` reduces boilerplate.

### 21b. DiceManager Delegation Pattern
Identical 5-line pattern duplicated across 10+ files:
```gdscript
var dice_manager = get_node_or_null("/root/DiceManager")
if dice_manager and dice_manager.has_method("roll_d6"):
    return dice_manager.roll_d6()
return randi_range(1, 6)
```

**Fix**: DiceManager is an autoload -- call it directly: `DiceManager.roll_d6()`. The null-guard is unnecessary.

### 21c. Campaign Phase Panel Boilerplate
Phase panels (StoryPhasePanel, TradePhasePanel, AdvancementPhasePanel, etc.) share significant boilerplate that could be extracted to BasePhasePanel.

---

## 22. LOW: Parallel Directory Trees

### `src/battle/` vs `src/core/battle/`
Both directories contain battle-related files. `src/battle/` appears to be a legacy tree.

| Directory | Files | Purpose |
|-----------|-------|---------|
| `src/core/battle/` | ~43 files | Current battle system |
| `src/battle/` | ~5 files | Legacy? Character.gd, Enemy.gd variants |

**Recommended**: Content-compare, merge any unique functionality into `src/core/battle/`, delete `src/battle/`

### `src/ui/screens/campaign/panels/` vs `src/ui/components/campaign/`
Both contain campaign UI. Panels are full-screen, components are reusable widgets -- this split is intentional.

---

## 23. Consolidation Roadmap (Part B)

### Priority Order

| # | Consolidation | Severity | Est. Effort | LOC Saved |
|---|--------------|----------|-------------|-----------|
| C1 | CleanupHelpers.gd -> merge into UCF | CRITICAL | 30 min | 268 |
| C2 | BattleEnemyResource -> merge into EnemyResource | HIGH | 30 min | ~150 |
| C3 | World phase inheritance refactor | HIGH | 3-4 hours | 100-150 |
| C4 | PostBattlePhase.gd decomposition | HIGH | 6-8 hours | ~3,800 (redistributed) |
| C5 | Character.gd decomposition | HIGH | 4-6 hours | ~750 (redistributed) |
| C6 | Duplicate file group cleanup | HIGH | 3-4 hours | ~500-1,000 |
| C7 | World phase pattern deduplication | HIGH | 2-3 hours | 340-520 |
| C8 | GameEnums.gd domain split | MEDIUM | 3-4 hours | 0 (reorganized) |
| C9 | Autoload consolidation (3->1 clusters) | MEDIUM | 2-3 hours | ~200 |
| C10 | Cross-cutting pattern cleanup | MEDIUM | 2-3 hours | ~300 |
| C11 | Remove disabled zzz autoloads | LOW | 15 min | ~0 |
| C12 | Merge src/battle/ into src/core/battle/ | LOW | 1-2 hours | ~100 |
| C13 | Monitoring tier evaluation | LOW | 1-2 hours | 0-1,829 |

**Total estimated consolidation effort**: ~30-40 hours across 15-20 sessions

### Dependency Order
1. **C1** (CleanupHelpers merge) and **C2** (BattleEnemyResource merge) -- standalone, no dependencies
2. **C6** (duplicate cleanup) -- do before decompositions to establish single source of truth
3. **C4** (PostBattlePhase decomposition) -- largest file, most impact
4. **C5** (Character.gd decomposition) -- second-highest coupling
5. **C3 + C7** (world phase consolidation) -- can be combined
6. **C8** (GameEnums split) -- requires careful ordinal preservation
7. **C9 + C10 + C11 + C12** -- lower-risk structural cleanup
8. **C13** (monitoring evaluation) -- may reveal additional dead code

### Risk Mitigation
- Every consolidation must be followed by headless compile check
- Decompositions use facade/composition pattern -- no public API breaks
- Enum splits preserve exact ordinal values (save/load safety)
- Duplicate merges verified with content diff before deletion

---

## Combined Effort Summary

| Initiative | Items | Est. Effort | Sessions |
|-----------|-------|-------------|----------|
| Part A: Optimization | 12 | ~20-30 hours | 10-15 |
| Part B: Consolidation | 13 | ~30-40 hours | 15-20 |
| **Total** | **25** | **~50-70 hours** | **25-35** |
