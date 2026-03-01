# MASSIVE DUPLICATION CRISIS - Deduplication Report

## 🚨 CRITICAL FRAMEWORK BIBLE VIOLATIONS

### File Count Analysis
- **Total duplicates found**: 260+ files
- **Manager pattern violations**: 161 files
- **Character duplicates**: 31 files
- **Enemy duplicates**: 14 files
- **Mission duplicates**: 23 files
- **Other duplicates**: 31+ files

### Framework Bible Violation Summary
❌ **Maximum 20 files rule**: VIOLATED (260+ files)
❌ **NO Manager classes**: VIOLATED (161 Manager files)
❌ **Consolidation over separation**: VIOLATED (massive duplication)

---

## 📊 DETAILED DUPLICATION ANALYSIS

### 1. MANAGER PATTERN VIOLATIONS (161 files - DELETE ALL)

#### Core Managers (Consolidate into static classes)
- CampaignManager.gd → CampaignSystem.gd (static methods)
- GameStateManager.gd → GameState.gd (autoload singleton)
- DiceManager.gd → DiceSystem.gd (static methods)
- DataManager.gd / SimplifiedDataManager.gd / LazyDataManager.gd / GameDataManager.gd → Data.gd
- SaveManager.gd / SecureSaveManager.gd / ProductionSaveManager.gd → SaveSystem.gd

#### Character Managers (DELETE - merge into Character.gd)
- CharacterManager.gd
- CharacterDataManager.gd
- AdvancementManager.gd

#### Enemy Managers (DELETE - merge into Enemy.gd)
- EnemyManager.gd
- EnemyDeploymentManager.gd
- EnemyAIManager.gd

#### UI Managers (DELETE - merge into UI scenes)
- UIManager.gd
- SceneTransitionManager.gd (duplicate x3)
- PanelTransitionManager.gd (duplicate x3)
- PanelLifecycleManager.gd
- PanelSafetyManager.gd
- ResponsiveDesignManager.gd
- TooltipManager.gd
- ThemeManager.gd
- GestureManager.gd
- AccessibilityManager.gd

#### World/Campaign Managers (DELETE - merge into Campaign.gd)
- WorldEconomyManager.gd
- PlanetDataManager.gd
- ContactManager.gd
- PatronRivalManager.gd
- CampaignEventsManager.gd
- BattleTutorialManager.gd

#### Equipment/Ship Managers (DELETE - merge into Equipment.gd / Ship.gd)
- EquipmentManager.gd
- ShipManager.gd

#### Signal/Scene Managers (DELETE - merge into autoload or scenes)
- UniversalSignalManager.gd (duplicate x2)
- UniversalSceneManager.gd (duplicate x2)
- SignalConnectionManager.gd
- WorkflowContextManager.gd
- PortraitManager.gd

#### Security/Validation Managers (DELETE - merge into validation classes)
- CampaignSecurityManager.gd
- AutoloadManager.gd
- CampaignCreationRollbackManager.gd
- FallbackCampaignManager.gd

---

### 2. CHARACTER FILE DUPLICATES (31 files)

#### Core Character Classes (KEEP 1, DELETE 30)
**CANONICAL**: `src/core/character/Character.gd` (832 lines - most complete)

**DELETE THESE DUPLICATES**:
- src/core/character/FiveParsecsCharacter.gd (340 lines - factory wrapper)
- src/base/character/character_base.gd (166 lines - redundant base)
- src/core/character/FiveParsecsCharacterMigration.gd (migration adapter)
- src/core/character/Base/CharacterStats.gd (stats in Character.gd)
- src/core/character/Base/CharacterBox.gd (UI - move to ui/)

#### Character Creation (KEEP 1, DELETE 6)
**CANONICAL**: `src/core/character/CharacterGeneration.gd`

**DELETE**:
- src/core/character/Generation/BaseCharacterCreator.gd
- src/core/character/Generation/SimpleCharacterCreator.gd
- src/base/character/BaseCharacterCreationSystem.gd
- src/ui/screens/character/CharacterCreator.gd (UI only - not generation)

#### Character UI Components (CONSOLIDATE)
**KEEP SEPARATE** (legitimate UI):
- src/ui/components/character/CharacterSheet.gd (display component)
- src/ui/screens/character/CharacterBox.gd (UI container)
- src/ui/screens/character/CharacterProgression.gd (UI screen)

**DELETE** (duplicate UI):
- src/scenes/character/CharacterUI.gd (old UI)
- src/ui/screens/campaign/CharacterCustomizationScreen.gd (merge into creation flow)
- src/core/battle/CharacterUnit.gd (battle-specific - not character core)
- src/ui/screens/campaign/panels/CharacterCreationDialog.gd (panel duplicate)

#### Character Data/Resources (CONSOLIDATE)
**DELETE** (merge into Character.gd or data/):
- src/data/resources/CharacterBackgroundResource.gd
- src/data/resources/CharacterClassResource.gd
- src/data/resources/CharacterMotivationResource.gd
- src/data/resources/FiveParsecsCharacterData.gd
- src/core/character/connections/CharacterConnections.gd
- src/core/character/Equipment/CharacterInventory.gd

#### Character Helpers (DELETE - 2 exact duplicates!)
- src/utils/helpers/MainContainer_CharacterCreationScreen.gd
- src/core/utils/MainContainer_CharacterCreationScreen.gd

---

### 3. ENEMY FILE DUPLICATES (14 files)

#### Core Enemy Classes (KEEP 1, DELETE 3)
**CANONICAL**: `src/core/enemy/base/Enemy.gd`

**DELETE DUPLICATES**:
- src/core/battle/enemy/Enemy.gd (battle duplicate)
- src/core/rivals/EnemyData.gd (data duplicate)
- src/data/resources/EnemyData.gd (resource duplicate)

#### Enemy Systems (DELETE - merge into Enemy.gd)
- src/core/systems/EnemyGenerator.gd → Enemy.generate_enemy()
- src/base/combat/enemy/BaseEnemyScalingSystem.gd → Enemy.scale_to_level()
- src/game/combat/EnemyTacticalAI.gd → Enemy.calculate_ai_action()
- src/game/economy/loot/EnemyLootGenerator.gd → Enemy.generate_loot()

#### Enemy UI (KEEP - legitimate UI)
- src/ui/components/mission/EnemyInfoPanel.gd (display only)

#### Enemy Data (CONSOLIDATE)
- src/data/resources/EnemyDatabase.gd (consolidate into data system)
- src/core/battle/EnemyTracker.gd (battle state - keep separate)

---

### 4. MISSION FILE DUPLICATES (23 files)

#### Core Mission Classes (KEEP 1, DELETE 2)
**CANONICAL**: `src/core/systems/Mission.gd`

**DELETE**:
- src/core/templates/MissionTemplate.gd (template - merge into Mission.gd)
- src/base/mission/mission_base.gd (base duplicate)

#### Mission Generation (DELETE - merge into Mission.gd)
- src/core/systems/MissionGenerator.gd → Mission.generate()
- src/base/campaign/BaseMissionGenerator.gd → Mission.generate()
- src/base/mission/BaseMissionGenerationSystem.gd → Mission.generate()

#### Mission Components (CONSOLIDATE)
- src/core/mission/MissionObjective.gd (keep as separate resource)
- src/core/mission/MissionIntegrator.gd (DELETE - merge into Mission.gd)

#### Mission Types (KEEP - legitimate variants)
Specific mission implementations:
- src/game/missions/StreetFightMission.gd
- src/game/missions/StealthMission.gd
- src/game/missions/SalvageMission.gd
- src/game/missions/opportunity/RaidMission.gd
- src/game/missions/patron/InvestigationMission.gd
- src/game/missions/patron/EscortMission.gd
- src/game/missions/patron/DeliveryMission.gd
- src/game/missions/patron/BountyHuntingMission.gd

#### Mission Enhanced (DELETE - bloat)
- src/game/missions/enhanced/MissionTypeRegistry.gd (DELETE)
- src/game/missions/enhanced/MissionRewardCalculator.gd (DELETE)
- src/game/missions/enhanced/MissionDifficultyScaler.gd (DELETE)

#### Mission UI (KEEP - legitimate UI)
- src/ui/screens/world/MissionSelectionUI.gd
- src/ui/screens/world/components/MissionPrepPanel.gd
- src/ui/components/mission/MissionSummaryPanel.gd
- src/ui/components/mission/MissionInfoPanel.gd

---

## 🎯 IMMEDIATE ACTION PLAN

### Phase 1: Delete All Manager Files (161 files)
```bash
# Find and list all Manager files for deletion
find src -name "*Manager*.gd" -type f > manager_files_to_delete.txt

# Count: Should be ~161 files
wc -l manager_files_to_delete.txt

# Backup before deletion
mkdir -p backup/manager_files
while read file; do
  cp "$file" "backup/manager_files/$(basename $file)"
done < manager_files_to_delete.txt

# DELETE ALL MANAGER FILES
while read file; do
  git rm "$file"
done < manager_files_to_delete.txt
```

### Phase 2: Consolidate Character Files (31 → 5)
**KEEP**:
1. `src/core/character/Character.gd` (main class)
2. `src/core/character/CharacterGeneration.gd` (creation logic)
3. `src/ui/components/character/CharacterSheet.gd` (UI display)
4. `src/ui/screens/character/CharacterBox.gd` (UI container)
5. `src/ui/screens/character/CharacterProgression.gd` (UI screen)

**DELETE**: 26 duplicate files

### Phase 3: Consolidate Enemy Files (14 → 3)
**KEEP**:
1. `src/core/enemy/base/Enemy.gd` (main class with all logic)
2. `src/ui/components/mission/EnemyInfoPanel.gd` (UI only)
3. `src/data/resources/EnemyDatabase.gd` (data storage)

**DELETE**: 11 duplicate files

### Phase 4: Consolidate Mission Files (23 → 13)
**KEEP**:
1. `src/core/systems/Mission.gd` (main class)
2. `src/core/mission/MissionObjective.gd` (objective resource)
3-10. Mission type implementations (8 files)
11-13. Mission UI components (3 files)

**DELETE**: 10 duplicate files

---

## 📈 EXPECTED RESULTS

### Before Deduplication
- **Total files**: 260+ files
- **Manager violations**: 161 files
- **Framework Bible compliance**: 0%

### After Deduplication
- **Total files**: ~80 files (still need further reduction to 20)
- **Manager violations**: 0 files
- **Framework Bible compliance**: 50% (major improvement, but need to reach 20 files)
- **Code reduction**: ~70% fewer files

### Next Steps (Reach 20 File Goal)
After initial deduplication (260 → 80), further consolidation needed:
- Merge UI screens into unified screens (currently 30+ UI files)
- Consolidate game systems into core systems (20+ game files)
- Merge data resources into unified data layer (15+ resource files)

---

## 🛠️ AUTOMATED DEDUPLICATION SCRIPT

See: `scripts/automated_deduplication.sh`

This script will:
1. Backup all files to be deleted
2. Delete all Manager files
3. Consolidate duplicates into canonical files
4. Update all references
5. Run tests to verify integrity
6. Generate before/after report

---

## ⚠️ RISKS & MITIGATION

### Risks
1. **Breaking references**: Many files reference Manager classes
2. **Lost functionality**: Some Managers may have unique code
3. **Test failures**: Existing tests may reference deleted files

### Mitigation
1. **Comprehensive backup**: All deleted files backed up to `backup/`
2. **Reference scanning**: Automated find-and-replace for all imports
3. **Incremental testing**: Test after each phase
4. **Git safety**: All changes committed incrementally with clear messages

---

## 📝 NOTES

This deduplication is **CRITICAL** for Framework Bible compliance. The current codebase violates every core principle:
- ❌ Way over 20 file limit (260+ files)
- ❌ Massive Manager pattern violations (161 files)
- ❌ Extreme duplication instead of consolidation

**This must be fixed NOW before any further development.**
