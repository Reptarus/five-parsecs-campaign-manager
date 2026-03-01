# Manager File Deletion Analysis

## Total Manager Files: 71

### ✅ CRITICAL - DO NOT DELETE (13 files)

These are legitimate system classes that manage state/workflow:

1. **src/core/managers/GameStateManager.gd** - Core game state (autoload)
2. **src/core/managers/DiceManager.gd** - Dice rolling system (autoload)
3. **src/core/managers/CampaignManager.gd** - Main campaign orchestration
4. **src/core/state/SaveManager.gd** - Save/load functionality
5. **src/core/data/DataManager.gd** - Data loading system
6. **src/core/campaign/CampaignPhaseManager.gd** - Phase state machine
7. **src/core/campaign/creation/CampaignCreationStateManager.gd** - Creation workflow
8. **src/core/managers/AlphaGameManager.gd** - Alpha features toggle
9. **src/core/managers/SectorManager.gd** - Sector generation
10. **src/core/managers/GalacticWarManager.gd** - War tracking
11. **src/core/managers/EventManager.gd** - Event system
12. **src/ui/screens/UIManager.gd** - UI screen routing
13. **src/core/managers/UpkeepPhaseManager.gd** - Upkeep phase logic

### ❌ DELETE - DUPLICATES (28 files)

**Data Manager Duplicates** (3):
- src/core/data/SimplifiedDataManager.gd → merge into DataManager.gd
- src/core/data/LazyDataManager.gd → merge into DataManager.gd
- src/core/character/Management/CharacterDataManager.gd → merge into Character.gd

**Save Manager Duplicates** (2):
- src/core/validation/SecureSaveManager.gd → merge into SaveManager.gd
- src/core/workflow/ProductionSaveManager.gd → merge into SaveManager.gd

**Campaign Manager Duplicates** (4):
- src/base/campaign/BaseCampaignManager.gd → delete base duplicate
- src/core/campaign/CampaignCreationManager.gd → redundant with CampaignCreationStateManager
- src/core/campaign/GameCampaignManager.gd → merge into CampaignManager.gd
- src/ui/screens/campaign/CampaignManager.gd → UI duplicate

**Dice Manager Duplicates** (1):
- src/core/systems/FallbackDiceManager.gd → merge into DiceManager.gd

**Fallback/Helper Managers** (4):
- src/core/systems/FallbackCampaignManager.gd → delete fallback
- src/core/systems/AutoloadManager.gd → delete helper
- src/core/systems/CampaignCreationRollbackManager.gd → merge into state manager
- src/core/workflow/WorkflowContextManager.gd → merge into state manager

**Character Managers** (2):
- src/core/character/Management/CharacterManager.gd → merge into Character.gd
- src/ui/screens/character/AdvancementManager.gd → merge into CharacterProgression.gd

**Enemy Managers** (3):
- src/core/managers/EnemyManager.gd → merge into Enemy.gd
- src/core/managers/EnemyDeploymentManager.gd → merge into Enemy.gd
- src/core/managers/EnemyAIManager.gd → merge into Enemy.gd

**Battle Managers** (6):
- src/core/battle/BattlefieldManager.gd → merge into Battle.gd
- src/core/battle/BattlefieldDisplayManager.gd → merge into BattleUI.gd
- src/core/battle/BattleResultsManager.gd → merge into Battle.gd
- src/core/battle/FPCM_BattleManager.gd → merge into Battle.gd
- src/base/combat/BaseCombatManager.gd → delete base duplicate
- src/base/combat/battlefield/BaseBattlefieldManager.gd → delete base duplicate

**Equipment/Ship Managers** (2):
- src/ui/screens/equipment/EquipmentManager.gd → merge into Equipment UI
- src/ui/screens/ships/ShipManager.gd → merge into Ship UI

**World/Planet Managers** (2):
- src/core/world/ContactManager.gd → merge into Campaign.gd
- src/core/world/PlanetDataManager.gd → merge into data system
- src/game/world/WorldEconomyManager.gd → merge into EconomySystem.gd

**UI Helper Managers** (4):
- src/core/ui/ResponsiveDesignManager.gd → delete (unnecessary abstraction)
- src/ui/components/tooltip/TooltipManager.gd → merge into UI components
- src/ui/components/gesture/GestureManager.gd → merge into UI components
- src/ui/themes/ThemeManager.gd → merge into UI autoload


### ⚠️ DELETE - MAYBE SAFE (30 files)

These might have unique functionality - need to check before deletion:

**Optional Feature Managers** (7):
- src/core/managers/AdvTrainingManager.gd
- src/core/managers/EliteLevelEnemiesManager.gd
- src/core/managers/EscalatingBattlesManager.gd
- src/core/managers/PsionicManager.gd
- src/core/battle/OptionalAutomationManager.gd
- src/autoload/BattlefieldCompanionManager.gd
- src/game/tutorial/BattleTutorialManager.gd

**Phase/Task Managers** (2):
- src/core/managers/CrewTaskManager.gd
- src/core/managers/DeploymentManager.gd

**Signal/Scene Managers** (4):
- src/core/systems/UniversalSignalManager.gd
- src/core/systems/UniversalSceneManager.gd
- src/core/systems/SignalConnectionManager.gd
- src/core/systems/PanelTransitionManager.gd (duplicate with src/core/ui/PanelTransitionManager.gd)

**Economy/Loan Managers** (2):
- src/core/managers/LoanManager.gd
- src/ui/screens/world/PatronRivalManager.gd

**Crew/Relationship Managers** (2):
- src/core/campaign/crew/CrewRelationshipManager.gd
- src/base/campaign/crew/BaseCrewRelationshipManager.gd

**Campaign Feature Managers** (4):
- src/core/campaign/DifficultyManager.gd
- src/ui/screens/events/CampaignEventsManager.gd
- src/core/security/CampaignSecurityManager.gd
- src/ui/accessibility/AccessibilityManager.gd

**System Managers** (2):
- src/core/systems/GameSystemManager.gd
- src/core/equipment/EquipmentManager.gd

---

## DELETION STRATEGY

### Phase 1: Safe Deletions (28 files)
Delete obvious duplicates and merge functionality into canonical files.

