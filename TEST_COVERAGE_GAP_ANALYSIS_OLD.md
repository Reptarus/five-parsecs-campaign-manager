# Test Coverage Gap Analysis - Five Parsecs Campaign Manager
**Generated**: 2025-12-13
**Analysis Scope**: Backend integrations, critical paths, campaign workflow
**Current Test Count**: 67 test files / 234 core system files (28.6% file coverage)

---

## Executive Summary

**Overall Test Coverage**: ~35-40% (estimated)
**Critical Gaps**: 19 untested core systems identified
**Risk Level**: HIGH - Major game systems lack test coverage

### Key Findings
- **Phase Handlers**: 0% unit test coverage (4 handlers exist, 0 tests)
- **Procedural Systems**: 15% coverage (enemy/character generation untested)
- **Campaign Workflow**: 60% coverage (creation tested, turn loop partially tested)
- **Battle Systems**: 20% coverage (AI, automation, terrain untested)

---

## 1. CRITICAL SYSTEMS WITH 0% TEST COVERAGE

### 1.1 Core Procedural Systems (HIGH PRIORITY)

#### EnemyGenerator.gd - 0% Coverage
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/systems/EnemyGenerator.gd`
**Lines**: 678
**Risk**: HIGH - Generates enemies for every battle
**Missing Tests**:
- Enemy category selection (JSON-driven)
- Stat generation (d6 rolls with modifiers)
- Equipment assignment based on enemy type
- Loot table integration
- Spawn rule validation

**Impact**: Broken enemy generation = no playable battles
**Estimated Test Effort**: 6-8 hours (13-15 tests)

---

#### CharacterGeneration.gd - 0% Coverage
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/character/CharacterGeneration.gd`
**Lines**: 1576
**Risk**: CRITICAL - Foundation of campaign creation
**Missing Tests**:
- Background table (d100 rolls with stat bonuses)
- Motivation table (d100 with special abilities)
- Class selection and bonuses
- Stat generation (2D6 / 3.0 rounded up formula)
- Starting equipment assignment
- JSON data integration

**Impact**: Broken character generation = campaign creation fails
**Estimated Test Effort**: 10-12 hours (18-22 tests)

---

#### WeaponSystem.gd - 0% Coverage
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/systems/WeaponSystem.gd`
**Lines**: 112
**Risk**: HIGH - All combat depends on weapon stats
**Missing Tests**:
- Weapon category lookup
- Weapon trait parsing
- Range/damage/shots validation
- JSON data loading fallback
- Enemy weapon assignment

**Impact**: Invalid weapon data = combat calculations fail
**Estimated Test Effort**: 3-4 hours (8-10 tests)

---

### 1.2 Phase Handler Systems (CRITICAL PRIORITY)

#### TravelPhase.gd - 0% Unit Tests (E2E exists)
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/campaign/phases/TravelPhase.gd`
**Lines**: 431
**Risk**: HIGH - First phase of every campaign turn
**Existing Coverage**: E2E tests only (test_campaign_turn_loop_e2e.gd)
**Missing Unit Tests**:
- Invasion check (d6 roll with patron modifier)
- Travel decision (starship vs commercial passage)
- Travel cost calculation (5 credits vs 1 per crew)
- Travel event table (d100 rolls)
- World arrival and trait assignment

**Impact**: Broken travel = campaign turn loop fails at step 1
**Estimated Test Effort**: 5-6 hours (12-15 tests)

---

#### WorldPhase.gd - 0% Unit Tests (E2E exists)
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/campaign/phases/WorldPhase.gd`
**Lines**: 1176
**Risk**: CRITICAL - Most complex phase with 7 substeps
**Existing Coverage**: E2E tests only (test_world_phase_effects.gd - partial)
**Missing Unit Tests**:
- Upkeep calculation (base + per crew + sick bay)
- Crew task assignment and resolution (8 different tasks)
- Job offer generation (patron jobs, opportunity jobs)
- Equipment assignment validation
- Character event resolution (d100 table)
- Campaign event resolution (d100 table)
- Rumors and quest progression

**Impact**: Broken world phase = no crew tasks, no jobs, no progression
**Estimated Test Effort**: 12-15 hours (25-30 tests)

---

#### BattlePhase.gd - 0% Unit Tests (E2E exists)
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/campaign/phases/BattlePhase.gd`
**Lines**: 335
**Risk**: HIGH - Core gameplay loop
**Existing Coverage**: E2E tests only (test_battle_phase_integration.gd)
**Missing Unit Tests**:
- Battle setup data validation
- Deployment condition processing
- Initiative roll determination
- Combat round progression (max 8 rounds)
- Battle results compilation
- Enemy AI activation

**Impact**: Broken battle phase = no combat resolution
**Estimated Test Effort**: 8-10 hours (15-18 tests)

---

#### PostBattlePhase.gd - 0% Unit Tests (E2E exists)
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/campaign/phases/PostBattlePhase.gd`
**Lines**: 1136
**Risk**: CRITICAL - Handles casualties, loot, XP
**Existing Coverage**: E2E tests only (test_battle_4phase_resolution.gd)
**Missing Unit Tests**:
- Rival/patron status resolution
- Quest progress tracking
- Payment calculation
- Battlefield finds (separate from loot - already tested)
- Invasion check
- Training application
- Purchase processing
- Campaign/character event triggers
- Galactic war progression

**Impact**: Broken post-battle = no campaign progression after battles
**Estimated Test Effort**: 10-12 hours (20-25 tests)

---

### 1.3 Battle Subsystems (MEDIUM-HIGH PRIORITY)

#### AIController.gd - 0% Coverage
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/battle/AIController.gd`
**Lines**: ~200 (estimated)
**Risk**: HIGH - Controls enemy behavior
**Missing Tests**:
- AI decision-making (move, shoot, take cover)
- Target selection logic
- Aggression level modifiers
- Line-of-sight calculations
- AI behavior validation

**Impact**: Broken AI = enemies don't act, battles unplayable
**Estimated Test Effort**: 6-8 hours (12-15 tests)

---

#### TerrainSystem.gd + UnifiedTerrainSystem.gd - 0% Coverage
**Files**:
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/terrain/TerrainSystem.gd`
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/terrain/UnifiedTerrainSystem.gd`
- 7 additional terrain files (TerrainFactory, TerrainRules, TerrainEffects, etc.)
**Lines**: ~800 total (estimated)
**Risk**: MEDIUM - Affects combat mechanics
**Missing Tests**:
- Terrain generation procedural rules
- Terrain effect application (cover, movement)
- Line-of-sight blocking
- Terrain type validation
- Factory pattern for terrain piece creation

**Impact**: Broken terrain = no cover mechanics, unrealistic battles
**Estimated Test Effort**: 8-10 hours (15-18 tests across terrain subsystem)

---

#### OptionalAutomationManager.gd - 0% Coverage
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/battle/OptionalAutomationManager.gd`
**Lines**: ~150 (estimated)
**Risk**: MEDIUM - Quality-of-life feature
**Missing Tests**:
- Auto-resolve options
- Automation toggling
- Result consistency with manual battles

**Impact**: Broken automation = players forced into manual battles
**Estimated Test Effort**: 3-4 hours (6-8 tests)

---

### 1.4 Campaign Systems (MEDIUM PRIORITY)

#### RivalSystem.gd - 0% Coverage
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/rivals/RivalSystem.gd`
**Lines**: ~250 (estimated)
**Risk**: MEDIUM - Long-term campaign tracking
**Missing Tests**:
- Rival creation and tracking
- Rival encounter generation
- Rival progression over time
- Rival battle special rules

**Impact**: Broken rival system = no recurring enemies, less narrative depth
**Estimated Test Effort**: 5-6 hours (10-12 tests)

---

#### PatronJobGenerator.gd - 0% Coverage
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/patrons/PatronJobGenerator.gd`
**Lines**: ~200 (estimated)
**Risk**: MEDIUM - Income source for players
**Missing Tests**:
- Patron job generation
- Difficulty scaling
- Reward calculation
- Job type variety validation

**Impact**: Broken patron jobs = reduced income options
**Estimated Test Effort**: 4-5 hours (8-10 tests)

---

#### StoryTrackSystem.gd - 0% Coverage
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/story/StoryTrackSystem.gd`
**Lines**: ~300 (estimated)
**Risk**: MEDIUM - Narrative progression
**Existing**: test_story_point_system.gd (story points only, not story track)
**Missing Tests**:
- Story track event triggering
- Progress tracking
- Event resolution
- Tutorial integration (new feature)

**Impact**: Broken story track = no narrative progression
**Estimated Test Effort**: 5-6 hours (10-12 tests)

---

#### Ship.gd + ShipComponent.gd - 0% Coverage
**Files**:
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/ships/Ship.gd`
- 8 ship component files (CargoComponent, EngineComponent, HullComponent, etc.)
**Lines**: ~600 total (estimated)
**Risk**: MEDIUM - Ship upgrades and travel
**Existing**: test_ship_stash_persistence.gd (stash only, not ship systems)
**Missing Tests**:
- Ship component installation
- Hull damage tracking
- Cargo capacity validation
- Engine speed calculations
- Medical bay functionality
- Weapons component integration

**Impact**: Broken ship systems = no upgrades, travel issues
**Estimated Test Effort**: 6-8 hours (12-15 tests)

---

#### UpkeepSystem.gd - 0% Coverage
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/systems/UpkeepSystem.gd`
**Lines**: ~100 (estimated)
**Risk**: MEDIUM - Economy balance
**Missing Tests**:
- Upkeep cost calculation
- Crew size scaling
- Sick bay costs
- Debt accumulation

**Impact**: Broken upkeep = economy imbalance
**Estimated Test Effort**: 3-4 hours (6-8 tests)

---

#### PsionicSystem.gd - 0% Coverage
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/systems/PsionicSystem.gd`
**Lines**: ~150 (estimated)
**Risk**: LOW - Optional rules
**Missing Tests**:
- Psionic power activation
- Power cost tracking
- Power effect resolution
- Character psionic stat validation

**Impact**: Broken psionics = optional rules unusable
**Estimated Test Effort**: 4-5 hours (8-10 tests)

---

#### ResourceSystem.gd - 0% Coverage
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/systems/ResourceSystem.gd`
**Lines**: ~100 (estimated)
**Risk**: LOW - Generic resource tracking
**Missing Tests**:
- Resource registration
- Resource modification
- Resource bounds checking

**Impact**: May be covered by EconomySystem tests
**Estimated Test Effort**: 2-3 hours (4-6 tests)

---

#### MissionObjective.gd + ReactTables.gd - 0% Coverage
**Files**:
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/mission/MissionObjective.gd`
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/mission/ReactTables.gd`
**Lines**: ~200 total (estimated)
**Risk**: MEDIUM - Mission variety
**Missing Tests**:
- Mission objective generation
- React table (encounter variation during missions)
- Objective completion validation
- Special mission rules

**Impact**: Broken missions = repetitive gameplay
**Estimated Test Effort**: 5-6 hours (10-12 tests)

---

#### World Systems (ContactManager, Location, PlanetDataManager) - 0% Coverage
**Files**:
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/world/ContactManager.gd`
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/world/Location.gd`
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/world/PlanetDataManager.gd`
**Lines**: ~300 total (estimated)
**Risk**: MEDIUM - World exploration
**Missing Tests**:
- Contact creation and tracking
- Location data persistence
- Planet trait generation
- World data validation

**Impact**: Broken world systems = no exploration variety
**Estimated Test Effort**: 5-6 hours (10-12 tests)

---

## 2. MISSING INTEGRATION TEST SCENARIOS

### 2.1 Phase-to-Phase Handoffs (CRITICAL)

**Existing**: test_phase_transitions.gd (state machine only)
**Missing**: Data persistence between phases

#### Travel → World Handoff (0% Coverage)
- Travel event data passed to WorldPhase
- World traits available in WorldPhase
- Invasion pending flag carried forward
- Credits deducted for travel

**Estimated Effort**: 2-3 hours (5-6 tests)

---

#### World → Battle Handoff (0% Coverage)
- Equipment assignments transferred to BattlePhase
- Crew task results affect battle readiness
- Job offer data creates battle scenarios
- Mission objectives loaded into battle

**Estimated Effort**: 3-4 hours (6-8 tests)

---

#### Battle → PostBattle Handoff (0% Coverage)
- Battle results passed correctly (casualties, enemies defeated)
- Deployment data used for injury determination
- Combat round count affects XP awards
- Mission success/failure status carried forward

**Estimated Effort**: 3-4 hours (6-8 tests)

---

#### PostBattle → Travel Handoff (0% Coverage)
- Injuries persist into next turn
- Loot added to ship stash
- XP applied to characters
- Campaign events trigger travel events
- Turn number increments correctly

**Estimated Effort**: 3-4 hours (6-8 tests)

---

### 2.2 Campaign Creation → Dashboard Transition (PARTIAL COVERAGE)

**Existing**: test_campaign_creation_data_flow.gd, test_campaign_wizard_flow.gd
**Missing**:
- Victory condition validation in dashboard
- Starting crew displayed correctly
- Starting equipment loaded
- Ship data initialized

**Estimated Effort**: 2-3 hours (4-6 tests)

---

### 2.3 Save/Load Integration with Phases (0% Coverage)

**Existing**: test_state_save_load.gd (basic save/load)
**Missing**:
- Save mid-phase, load resumes at correct substep
- Phase handler state restoration
- Signal reconnection after load
- Temp data cleanup on save

**Estimated Effort**: 4-5 hours (8-10 tests)

---

### 2.4 UI → State → Backend Validation (PARTIAL COVERAGE)

**Existing**: test_ui_backend_bridge.gd (basic signal flow)
**Missing**:
- Equipment panel → EquipmentManager → BattlePhase
- Crew panel → CharacterManager → ActiveCrew
- Trading screen → EconomySystem → ResourceSystem
- Dashboard stats → GameStateManager → UI updates

**Estimated Effort**: 5-6 hours (10-12 tests)

---

## 3. CRITICAL PATHS WITHOUT E2E TESTS

### 3.1 Complete Campaign Turn Cycle (PARTIAL COVERAGE)

**Existing**: test_campaign_turn_loop_e2e.gd (phase transitions only)
**Missing**: Full substep validation

#### Travel Phase E2E (0% Coverage)
1. Check invasion (d6 roll)
2. If invasion: escape attempt
3. Decide travel method (starship vs commercial)
4. Deduct credits
5. Roll travel event
6. Arrive at world, assign traits

**Estimated Effort**: 3-4 hours (1 comprehensive E2E test)

---

#### World Phase E2E (0% Coverage)
1. Calculate upkeep costs
2. Assign crew tasks (8 types)
3. Resolve crew task results
4. Generate job offers (patron + opportunity)
5. Assign equipment to crew
6. Resolve character events
7. Resolve campaign events
8. Check rumors, trigger quests
9. Choose battle or skip

**Estimated Effort**: 5-6 hours (1 comprehensive E2E test)

---

#### Battle Phase E2E (0% Coverage)
1. Load battle setup data
2. Deploy crew and enemies
3. Determine initiative
4. Execute 1-8 combat rounds
5. Apply terrain effects
6. Activate AI for enemies
7. Resolve battle results
8. Pass results to PostBattle

**Estimated Effort**: 4-5 hours (1 comprehensive E2E test)

---

#### PostBattle Phase E2E (0% Coverage)
1. Resolve rival/patron status
2. Update quest progress
3. Receive payment
4. Determine battlefield finds
5. Check invasion
6. Gather loot (already tested separately)
7. Determine injuries (already tested separately)
8. Award XP (already tested separately)
9. Apply training
10. Make purchases
11. Trigger campaign/character events
12. Update galactic war progress

**Estimated Effort**: 5-6 hours (1 comprehensive E2E test)

---

### 3.2 Character Lifecycle (0% Coverage)

**Path**: Creation → Recruitment → Task Assignment → Battle → Injury → Recovery → Advancement → Removal

**Missing Tests**:
- Create character via CharacterGeneration
- Add to crew via CharacterManager
- Assign task in WorldPhase
- Deploy in BattlePhase
- Sustain injury in PostBattle
- Recover via InjuryRecoverySystem (partially tested)
- Advance via AdvancementSystem (tested)
- Remove and cascade equipment cleanup

**Estimated Effort**: 6-8 hours (1 comprehensive E2E test)

---

### 3.3 Economy Lifecycle (0% Coverage)

**Path**: Starting Credits → Travel Costs → Upkeep → Job Payment → Trading → Loot Sales → Debt

**Missing Tests**:
- Start with background credits
- Deduct travel costs
- Deduct upkeep
- Receive job payment
- Buy equipment via trading
- Sell loot
- Accumulate debt if negative

**Estimated Effort**: 4-5 hours (1 comprehensive E2E test)

---

### 3.4 Mission Lifecycle (0% Coverage)

**Path**: Job Offer → Accept → Prepare → Battle → Resolve → Payment

**Missing Tests**:
- Generate job offer (PatronJobGenerator)
- Accept job in WorldPhase
- Load mission in BattlePhase
- Complete mission objective
- Resolve in PostBattle
- Receive payment

**Estimated Effort**: 5-6 hours (1 comprehensive E2E test)

---

## 4. DATA VALIDATION GAPS

### 4.1 Character Creation Validation (0% Coverage)

**Missing**:
- Stat bounds (0-6 for most stats)
- Background roll validity (1-100)
- Motivation roll validity (1-100)
- Class selection constraints
- Starting equipment validity

**Estimated Effort**: 3-4 hours (8-10 tests)

---

### 4.2 Equipment Assignment Validation (PARTIAL COVERAGE)

**Existing**: test_equipment_management.gd (stash bounds, cascades)
**Missing**:
- Can't assign equipment to dead/absent crew
- Can't assign 2-handed weapon + shield
- Can't exceed carrying capacity
- Weapon type restrictions (e.g., Engineer-only weapons)

**Estimated Effort**: 2-3 hours (5-6 tests)

---

### 4.3 Resource Management Validation (PARTIAL COVERAGE)

**Existing**: test_economy_consistency.gd (negative prevention, overflow)
**Missing**:
- Resource type registration validation
- Invalid resource ID handling
- Resource dependency validation

**Estimated Effort**: 2-3 hours (4-6 tests)

---

### 4.4 Battle Setup Validation (PARTIAL COVERAGE)

**Existing**: test_battle_initialization.gd (crew required, deployment)
**Missing**:
- Enemy count limits (max 20)
- Terrain piece count limits
- Deployment zone overlap detection
- Invalid mission objective handling

**Estimated Effort**: 3-4 hours (6-8 tests)

---

## 5. TEST PRIORITY RECOMMENDATIONS

### Tier 1 - CRITICAL (Must Test Before PRODUCTION_CANDIDATE)

1. **CharacterGeneration.gd** - 10-12 hours
2. **EnemyGenerator.gd** - 6-8 hours
3. **WorldPhase.gd unit tests** - 12-15 hours
4. **PostBattlePhase.gd unit tests** - 10-12 hours
5. **Phase handoff integration tests** - 11-15 hours

**Subtotal**: 49-62 hours

---

### Tier 2 - HIGH (Test Before PRODUCTION_READY)

6. **TravelPhase.gd unit tests** - 5-6 hours
7. **BattlePhase.gd unit tests** - 8-10 hours
8. **AIController.gd** - 6-8 hours
9. **WeaponSystem.gd** - 3-4 hours
10. **Complete turn cycle E2E** - 17-21 hours (4 E2E tests)

**Subtotal**: 39-49 hours

---

### Tier 3 - MEDIUM (Test for Polish)

11. **TerrainSystem** - 8-10 hours
12. **RivalSystem** - 5-6 hours
13. **PatronJobGenerator** - 4-5 hours
14. **Ship systems** - 6-8 hours
15. **StoryTrackSystem** - 5-6 hours
16. **Character lifecycle E2E** - 6-8 hours

**Subtotal**: 34-43 hours

---

### Tier 4 - LOW (Nice to Have)

17. **MissionObjective/ReactTables** - 5-6 hours
18. **UpkeepSystem** - 3-4 hours
19. **PsionicSystem** - 4-5 hours
20. **World systems (Contact/Location/Planet)** - 5-6 hours
21. **OptionalAutomationManager** - 3-4 hours

**Subtotal**: 20-25 hours

---

## 6. TOTAL EFFORT ESTIMATE

### By Priority Tier
- **Tier 1 (Critical)**: 49-62 hours
- **Tier 2 (High)**: 39-49 hours
- **Tier 3 (Medium)**: 34-43 hours
- **Tier 4 (Low)**: 20-25 hours

**Total Comprehensive Coverage**: 142-179 hours (18-22 work days)

### Minimum Viable Test Suite (Tier 1 + Tier 2)
**Estimate**: 88-111 hours (11-14 work days)

### For PRODUCTION_CANDIDATE (98/100) - Tier 1 Only
**Estimate**: 49-62 hours (6-8 work days)

---

## 7. RISK ASSESSMENT BY UNTESTED SYSTEM

| System | Risk Level | Player Impact | Test Effort |
|--------|-----------|---------------|-------------|
| CharacterGeneration | CRITICAL | Campaign creation fails | 10-12h |
| WorldPhase | CRITICAL | No progression between battles | 12-15h |
| PostBattlePhase | CRITICAL | No rewards/progression | 10-12h |
| EnemyGenerator | HIGH | No enemies = no battles | 6-8h |
| TravelPhase | HIGH | Turn loop fails at start | 5-6h |
| BattlePhase | HIGH | Combat doesn't resolve | 8-10h |
| AIController | HIGH | Enemies don't act | 6-8h |
| WeaponSystem | HIGH | Combat calculations wrong | 3-4h |
| TerrainSystem | MEDIUM | No cover mechanics | 8-10h |
| RivalSystem | MEDIUM | Less narrative depth | 5-6h |
| Ship Systems | MEDIUM | No ship upgrades | 6-8h |
| PatronJobGenerator | MEDIUM | Reduced income | 4-5h |
| StoryTrackSystem | MEDIUM | No story progression | 5-6h |
| MissionObjective | MEDIUM | Repetitive missions | 5-6h |
| UpkeepSystem | MEDIUM | Economy imbalance | 3-4h |
| World Systems | LOW | Reduced variety | 5-6h |
| PsionicSystem | LOW | Optional rules broken | 4-5h |
| OptionalAutomation | LOW | QoL feature broken | 3-4h |

---

## 8. RECOMMENDED IMMEDIATE ACTIONS

### Week 1: Critical Systems Foundation
1. Create `test_character_generation.gd` - 18-22 tests covering background/motivation/class
2. Create `test_enemy_generator.gd` - 13-15 tests covering enemy creation
3. Create `test_weapon_system.gd` - 8-10 tests covering weapon data

**Deliverable**: Character and enemy creation fully tested

---

### Week 2: Phase Handler Unit Tests
4. Create `test_world_phase_unit.gd` - 25-30 tests covering all 7 substeps
5. Create `test_post_battle_phase_unit.gd` - 20-25 tests covering all substeps
6. Create `test_travel_phase_unit.gd` - 12-15 tests covering travel mechanics
7. Create `test_battle_phase_unit.gd` - 15-18 tests covering battle setup/resolution

**Deliverable**: All phase handlers have unit test coverage

---

### Week 3: Integration & E2E
8. Create `test_phase_handoffs.gd` - 25-30 tests covering data persistence between phases
9. Enhance `test_campaign_turn_loop_e2e.gd` - Add full substep validation (4 E2E tests)
10. Create `test_character_lifecycle_e2e.gd` - Full character journey test

**Deliverable**: Complete integration coverage for campaign turn loop

---

### Week 4: Battle Systems & AI
11. Create `test_ai_controller.gd` - 12-15 tests covering enemy AI
12. Create `test_terrain_system.gd` - 15-18 tests covering terrain generation and effects
13. Enhance existing battle tests with AI/terrain validation

**Deliverable**: Battle systems fully tested

---

## 9. METRICS TO TRACK

### Test Coverage Goals
- **Current**: ~35-40% (estimated)
- **PRODUCTION_CANDIDATE (98/100)**: 70-75%
- **PRODUCTION_READY (100/100)**: 85-90%

### Test Count Goals
- **Current**: 164 tests (162 passing)
- **PRODUCTION_CANDIDATE**: 280-320 tests
- **PRODUCTION_READY**: 400-450 tests

### Bug Discovery Rate
- **Week 3 Proven**: 8 critical bugs via 138 tests
- **Expected**: 15-25 critical bugs from Tier 1 tests
- **Target**: 100% critical bugs caught before user testing

---

## 10. CONCLUSION

The Five Parsecs Campaign Manager has **excellent test coverage for implemented systems** (96.2% pass rate, 164 tests), but **significant gaps in core procedural and phase systems**.

**Highest Risk**: Character and enemy generation systems have 0% test coverage despite being critical for campaign creation and battles.

**Recommended Path**: Focus on Tier 1 tests (49-62 hours) to reach PRODUCTION_CANDIDATE status, then Tier 2 (39-49 hours) for PRODUCTION_READY.

**Estimated Timeline**:
- PRODUCTION_CANDIDATE: 6-8 work days (Tier 1 only)
- PRODUCTION_READY: 17-20 work days (Tier 1 + Tier 2)

**Key Success Metric**: Achieve 70%+ test coverage before user testing to maintain current 0% regression rate.
