# 🏗️ Five Parsecs Campaign Manager - Master Refactoring Plan

## 🎯 Executive Summary

This refactoring plan consolidates **9 monolithic scripts (5,500+ total lines)** into **6 focused, cross-cutting systems** by identifying shared concerns and creating unified solutions that serve multiple domains.

**Current Monoliths Identified:**
- `GameStateManager.gd` (1,200+ lines) - State management god object
- `CampaignCreationUI.gd` (1,150+ lines) - UI orchestration monolith  
- `CharacterGeneration.gd` (900+ lines) - Complex character creation
- `CampaignManager.gd` (800+ lines) - Campaign flow and missions
- `AlphaGameManager.gd` (600+ lines) - System coordination
- `BattlefieldManager.gd` (500+ lines) - Battlefield generation
- `PostBattlePhase.gd` (500+ lines) - Post-battle processing
- `SceneRouter.gd` (400+ lines) - Scene management (✅ Keep as-is)
- `DiceSystem.gd` (300+ lines) - Dice rolling (✅ Keep as-is)

**Target Architecture:** 6 consolidated systems + 2 existing focused systems = **8 total scripts**

---

## 🔍 Cross-Cutting Concern Analysis

### 1. **State Management Layer** 
*Combines: GameStateManager + CampaignManager + CampaignCreationUI state logic*

**Current Problems:**
- GameStateManager handles everything from resources to testing scenarios
- CampaignManager duplicates state management for campaigns
- CampaignCreationUI maintains its own state synchronization

**Unified Solution:**
- `CoreStateController.gd` - Centralized state management
- `StateEventBus.gd` - Cross-system state change notifications  
- `StatePersistence.gd` - Save/load operations with validation

### 2. **System Orchestration Layer**
*Combines: AlphaGameManager + GameStateManager system coordination*

**Current Problems:**
- AlphaGameManager and GameStateManager both handle system coordination
- Duplicate manager registration and lifecycle management
- Overlapping initialization and error handling

**Unified Solution:**
- `SystemOrchestrator.gd` - Single system coordinator
- `ManagerRegistry.gd` - Centralized manager discovery
- `SystemHealthMonitor.gd` - Performance and health tracking

### 3. **Game Flow Management Layer**
*Combines: CampaignManager + PostBattlePhase + BattlefieldManager game logic*

**Current Problems:**
- Campaign flow scattered across multiple managers
- Phase management duplicated between systems
- Battle-related logic spread across files

**Unified Solution:**
- `GameFlowController.gd` - Turn sequence and phase management
- `MissionLifecycleManager.gd` - Mission creation to completion
- `BattleEventCoordinator.gd` - Battle setup, execution, and resolution

### 4. **UI Orchestration Layer**
*Combines: CampaignCreationUI + SceneRouter UI logic*

**Current Problems:**
- CampaignCreationUI trying to manage complex multi-step workflows
- No centralized form validation or data collection
- UI state scattered across components

**Unified Solution:**
- `UIFlowController.gd` - Multi-step workflow management
- `FormOrchestrator.gd` - Cross-form validation and data collection
- `UIStateManager.gd` - Centralized UI state synchronization

### 5. **Data Generation Layer**
*Combines: CharacterGeneration + GameStateManager test scenarios*

**Current Problems:**
- Character generation isolated from broader data needs
- Test scenario creation spread across GameStateManager
- No unified approach to procedural content generation

**Unified Solution:**
- `ContentGenerator.gd` - Characters, missions, events, scenarios
- `DataTemplateEngine.gd` - Configurable data generation
- `MockDataProvider.gd` - Testing and development utilities

### 6. **Resource Management Layer**
*Combines: GameStateManager resources + CampaignManager economics*

**Current Problems:**
- Resource management scattered across systems
- Economic calculations duplicated
- No centralized validation or constraints

**Unified Solution:**
- `ResourceManager.gd` - Credits, supplies, reputation, etc.
- `EconomicEngine.gd` - Market prices, transactions, constraints
- `ResourceValidator.gd` - Constraint checking and validation

---

## 📁 New Architecture Overview

```
src/unified_systems/
├── core/
│   ├── CoreStateController.gd           # 🔄 State management
│   ├── StateEventBus.gd                 # 📡 State notifications  
│   └── StatePersistence.gd              # 💾 Save/load operations
│
├── orchestration/
│   ├── SystemOrchestrator.gd            # 🎭 System coordination
│   ├── ManagerRegistry.gd               # 📋 Manager discovery
│   └── SystemHealthMonitor.gd           # 📊 Performance tracking
│
├── game_flow/
│   ├── GameFlowController.gd            # 🎮 Turn/phase management
│   ├── MissionLifecycleManager.gd       # 🎯 Mission lifecycle
│   └── BattleEventCoordinator.gd        # ⚔️ Battle coordination
│
├── ui_orchestration/
│   ├── UIFlowController.gd              # 🖱️ UI workflow management
│   ├── FormOrchestrator.gd              # 📝 Form validation
│   └── UIStateManager.gd                # 🔄 UI state sync
│
├── content_generation/
│   ├── ContentGenerator.gd              # 🎲 Procedural content
│   ├── DataTemplateEngine.gd            # 🏗️ Template system
│   └── MockDataProvider.gd              # 🧪 Test data
│
└── resources/
    ├── ResourceManager.gd               # 💰 Resource management
    ├── EconomicEngine.gd                # 📈 Economic calculations
    └── ResourceValidator.gd             # ✅ Constraint validation

# Existing focused systems (keep as-is)
src/core/ui/screens/SceneRouter.gd       # 🗺️ Scene management
src/core/systems/DiceSystem.gd          # 🎲 Dice rolling
```

---

## 🎯 Implementation Strategy

### Phase 1: Foundation Systems (Week 1-2)
**Priority: Critical Path Dependencies**

1. **CoreStateController.gd** - Extract pure state management
   - Consolidate resource properties from GameStateManager
   - Add state change notifications via signals
   - Implement state validation and constraints

2. **SystemOrchestrator.gd** - Unify system coordination  
   - Merge initialization logic from AlphaGameManager + GameStateManager
   - Implement centralized error handling and recovery
   - Add performance monitoring and health checks

3. **StateEventBus.gd** - State change notifications
   - Create typed event system for state changes
   - Replace direct coupling with event-driven architecture
   - Add event logging and debugging capabilities

### Phase 2: Game Logic Systems (Week 3-4)
**Priority: Core Game Functionality**

4. **GameFlowController.gd** - Campaign turn management
   - Extract turn sequence logic from CampaignManager
   - Implement phase transitions with validation
   - Add campaign progression tracking

5. **MissionLifecycleManager.gd** - Mission management
   - Consolidate mission logic from CampaignManager
   - Add mission state machine with clear transitions
   - Implement mission validation and requirements

6. **ResourceManager.gd** - Resource and economy
   - Extract resource management from GameStateManager
   - Add economic calculations and market systems
   - Implement resource constraints and validation

### Phase 3: UI and Content Systems (Week 5-6)
**Priority: User Experience and Content**

7. **UIFlowController.gd** - Multi-step UI workflows
   - Extract workflow logic from CampaignCreationUI
   - Implement generic form progression system
   - Add validation and error handling

8. **ContentGenerator.gd** - Procedural content
   - Consolidate CharacterGeneration + test scenarios
   - Add configurable generation templates
   - Implement validation and quality checks

### Phase 4: Integration and Polish (Week 7-8)
**Priority: System Integration**

9. **Complete system integration testing**
10. **Update all scenes and UI components**
11. **Performance testing and optimization**
12. **Documentation and deployment**

---

## 🎨 UI/Scene Support Matrix

### Scenes Requiring Updates

| System | Required Scenes | Status | Priority |
|--------|----------------|--------|----------|
| **UIFlowController** | `CampaignCreationFlow.tscn`<br>`MultiStepWizard.tscn` | ⚠️ Create | High |
| **GameFlowController** | `CampaignDashboard.tscn`<br>`PhaseTransition.tscn` | ⚠️ Update | High |
| **ResourceManager** | `ResourcePanel.tscn`<br>`EconomicOverview.tscn` | ⚠️ Update | Medium |
| **ContentGenerator** | `CharacterCreator.tscn`<br>`ScenarioBuilder.tscn` | ⚠️ Update | Medium |
| **SystemOrchestrator** | `SystemStatus.tscn`<br>`DebugConsole.tscn` | ⚠️ Create | Low |

### Existing Scenes to Refactor

```
src/ui/screens/campaign/
├── CampaignCreationUI.tscn          # Split into workflow components
├── CampaignDashboard.tscn           # Connect to new state system
└── panels/
    ├── ConfigPanel.tscn             # Update for UIFlowController
    ├── CrewPanel.tscn               # Update for ContentGenerator
    ├── EquipmentPanel.tscn          # Update for ResourceManager
    └── FinalPanel.tscn              # Update for UIFlowController
```

---

## 📋 Script Consolidation Breakdown

### Before → After Mapping

| Original Monolith | Lines | New System | Lines | Reduction |
|-------------------|-------|------------|-------|-----------|
| GameStateManager.gd | 1,200+ | CoreStateController.gd | 300 | -75% |
| CampaignCreationUI.gd | 1,150+ | UIFlowController.gd | 250 | -78% |
| CharacterGeneration.gd | 900+ | ContentGenerator.gd | 350 | -61% |
| CampaignManager.gd | 800+ | GameFlowController.gd | 300 | -63% |
| AlphaGameManager.gd | 600+ | SystemOrchestrator.gd | 200 | -67% |
| BattlefieldManager.gd | 500+ | BattleEventCoordinator.gd | 200 | -60% |
| PostBattlePhase.gd | 500+ | *Integrated into GameFlowController* | - | -100% |
| **TOTAL** | **5,650+** | **6 New Systems** | **1,600** | **-72%** |

---

## 🔄 Migration Strategy

### 1. **Gradual Migration Approach**
- Keep original files during transition
- Use adapter pattern for compatibility
- Migrate one system at a time
- Extensive testing at each step

### 2. **Backwards Compatibility**
- Create compatibility wrappers for existing APIs
- Gradual deprecation of old methods
- Clear migration guides for each system
- Automated migration tools where possible

### 3. **Testing Strategy**
- Unit tests for each new system
- Integration tests for system interactions
- Performance benchmarks for optimization
- User acceptance testing for UI changes

---

## 🚀 Expected Benefits

### **Code Quality Improvements**
- **72% reduction in total lines of code**
- **Single Responsibility Principle** - Each system has one clear purpose
- **Better testability** - Smaller, focused components
- **Reduced coupling** - Event-driven architecture

### **Developer Experience** 
- **Faster development** - Less code to understand and modify
- **Easier debugging** - Clear separation of concerns
- **Better maintainability** - Focused systems with clear boundaries
- **Improved collaboration** - Multiple developers can work on different systems

### **System Performance**
- **Reduced memory usage** - Elimination of duplicate functionality
- **Faster initialization** - More efficient system startup
- **Better responsiveness** - Event-driven state updates
- **Improved scalability** - Modular architecture supports growth

---

## ⚠️ Risk Mitigation

### **High-Risk Areas**
1. **State synchronization** between new systems
2. **UI binding updates** for new state management
3. **Save/load compatibility** with existing saves
4. **Performance regression** during transition

### **Mitigation Strategies**
1. **Comprehensive integration testing**
2. **Gradual rollout with feature flags**
3. **Automated migration tools**
4. **Performance monitoring and benchmarking**
5. **Rollback procedures** for each migration step

---

## 📊 Success Metrics

### **Technical Metrics**
- [ ] 70%+ reduction in total codebase size
- [ ] 90%+ test coverage for new systems  
- [ ] <100ms response time for state operations
- [ ] Zero memory leaks in new architecture

### **Developer Metrics**
- [ ] 50%+ reduction in average bug fix time
- [ ] 30%+ improvement in feature development velocity
- [ ] 90%+ developer satisfaction with new architecture
- [ ] <2 hours onboarding time for new developers

### **Quality Metrics**
- [ ] Zero critical bugs in production
- [ ] 99.9% uptime for core systems
- [ ] <1s load time for all UI screens
- [ ] 100% backwards compatibility during transition

---

This refactoring plan transforms a monolithic, hard-to-maintain codebase into a modern, modular architecture that will scale with your project's growth while dramatically improving developer productivity and system reliability.