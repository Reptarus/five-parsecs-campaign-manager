# Codebase Cleanup List

## Overview

This document provides a comprehensive list of files that can be safely deleted to clean up the Five Parsecs Campaign Manager codebase. The analysis identified **22+ files** and **17 empty directories** that can be removed, eliminating **~2,800+ lines** of redundant code.

## 🔴 **HIGH PRIORITY - SAFE FOR IMMEDIATE DELETION**

### **1. Backup Files (8 files)**
**Impact**: Remove development artifacts, save significant space
**Safety**: ✅ **SAFE** - Git versioning makes these redundant

```bash
# All .backup files can be deleted immediately
src/core/managers/EventManager.gd.backup
src/core/state/GameState.gd.backup
src/game/campaign/crew/FiveParsecsCrewRelationshipManager.gd.backup
src/game/campaign/crew/FiveParsecsCrewSystem.gd.backup
src/game/combat/CombatResolver.gd.backup
src/game/combat/EnemyTacticalAI.gd.backup
src/ui/components/automation/AutomationSettingsPanel.gd.backup
src/ui/components/combat/log/combat_log_controller.gd.backup
```

### **2. Test Files Misplaced in src/ (7 files)**
**Impact**: Improve organization, tests belong in tests/ directory
**Safety**: ✅ **SAFE** - Comprehensive test infrastructure exists in tests/

```bash
# Test files that should be in tests/ directory instead
src/ui/screens/battle/BattleCompanionTest.gd
src/ui/screens/battle/BattleCompanionTest.tscn
src/ui/screens/battle/TestPreBattle.gd
src/ui/screens/battle/TestPreBattle.gd.uid
src/ui/screens/battle/TestPreBattle.tscn
src/ui/screens/dice/DiceTestScene.gd
src/ui/screens/dice/DiceTestScene.gd.uid
```

### **3. Test Scene Files (2 files)**
**Impact**: Remove UI test scenes from production code
**Safety**: ✅ **SAFE** - Development artifacts only

```bash
src/ui/components/base/CampaignResponsiveLayoutTest.tscn
src/ui/components/base/ResponsiveContainerTest.tscn
```

### **4. Explicitly Deprecated Files (1 file)**
**Impact**: Remove file marked for deletion by developers
**Safety**: ✅ **SAFE** - Explicitly marked as deprecated

```bash
# File header states: "This file should be considered deprecated and will be removed in future updates"
src/utils/helpers/stat_distribution.gd
```

**Total High Priority**: **18 files** - **Safe for immediate deletion**

---

## 🟡 **MEDIUM PRIORITY - REVIEW BEFORE DELETION**

### **5. Compatibility Stub Files (3 files)**
**Impact**: Clean up backward compatibility layer
**Safety**: ⚠️ **CAUTION** - Check for active references first

```bash
# These are minimal compatibility wrappers
src/core/battle/enemy/Enemy.gd               # 4 lines - extends base Enemy
src/core/character/Character.gd              # 11 lines - alias for backward compatibility
src/core/character/Equipment/base/gear.gd    # 8 lines - minimal base class
```

**Verification needed**: Search codebase for imports/references to these files before deletion.

### **6. Duplicate Helper Files (1 file)**
**Impact**: Remove redundant implementation
**Safety**: ⚠️ **CAUTION** - Verify which version is authoritative

```bash
# Check if this duplicates src/core/utils/MainContainer_CharacterCreationScreen.gd
src/utils/helpers/MainContainer_CharacterCreationScreen.gd
```

**Total Medium Priority**: **4 files** - **Review dependencies first**

---

## 🟢 **LOW PRIORITY - EMPTY DIRECTORIES**

### **7. Empty Directories (17 directories)**
**Impact**: Clean up project structure
**Safety**: ✅ **SAFE** - No functional impact

```bash
# Empty directories that can be removed
src/base/combat/state/
src/base/state/
src/core/character/-p/                                    # Likely creation error
src/core/character/src/core/character/management/         # Nested structure error
src/core/items/weapons/
src/core/main/screens/campaign/
src/core/mission/base/
src/core/mission/generation/
src/core/mission/state/
src/data/config/
src/data/models/
src/data/storage/
src/game/economy/
src/game/enemy/
src/game/ships/components/
src/game/state/
src/game/terrain/
src/scenes/campaign/dialogs/
src/utils/debug/
src/utils/math/
```

**Total Low Priority**: **17 directories** - **Safe to remove**

---

## 📊 **CLEANUP IMPACT SUMMARY**

### **Files for Deletion**
- **High Priority (Safe)**: 18 files
- **Medium Priority (Review)**: 4 files
- **Total Files**: 22 files
- **Empty Directories**: 17 directories

### **Space Savings**
- **Backup Files**: ~2,500+ lines of redundant code
- **Test Files**: ~300+ lines of misplaced tests
- **Deprecated Files**: ~100+ lines of deprecated code
- **Total Lines Eliminated**: ~2,800+ lines

### **Benefits**
- ✅ Cleaner project structure
- ✅ Faster file searches and navigation
- ✅ Reduced cognitive load for developers
- ✅ Eliminated confusion from duplicate/deprecated files
- ✅ Better organization with tests in proper location

---

## 🔧 **DELETION COMMANDS**

### **High Priority (Execute Immediately)**
```bash
# Navigate to project root
cd /mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager

# Delete backup files
find src -name "*.backup" -type f -delete

# Delete test files in src/
rm -f src/ui/screens/battle/BattleCompanionTest.gd
rm -f src/ui/screens/battle/BattleCompanionTest.tscn
rm -f src/ui/screens/battle/TestPreBattle.gd
rm -f src/ui/screens/battle/TestPreBattle.gd.uid
rm -f src/ui/screens/battle/TestPreBattle.tscn
rm -f src/ui/screens/dice/DiceTestScene.gd
rm -f src/ui/screens/dice/DiceTestScene.gd.uid

# Delete test scene files
rm -f src/ui/components/base/CampaignResponsiveLayoutTest.tscn
rm -f src/ui/components/base/ResponsiveContainerTest.tscn

# Delete deprecated file
rm -f src/utils/helpers/stat_distribution.gd

# Remove empty directories
find src -type d -empty -delete
```

### **Medium Priority (Review First)**
```bash
# BEFORE deleting these, search for references:
grep -r "src/core/battle/enemy/Enemy.gd" src/
grep -r "src/core/character/Character.gd" src/
grep -r "src/core/character/Equipment/base/gear.gd" src/
grep -r "src/utils/helpers/MainContainer_CharacterCreationScreen.gd" src/

# If no active references found, delete:
# rm -f src/core/battle/enemy/Enemy.gd
# rm -f src/core/character/Character.gd
# rm -f src/core/character/Equipment/base/gear.gd
# rm -f src/utils/helpers/MainContainer_CharacterCreationScreen.gd
```

---

## ⚠️ **VERIFICATION CHECKLIST**

Before executing deletion commands:

### **Pre-Deletion Checks**
- [ ] Backup current codebase (git commit/push)
- [ ] Verify no active development branches depend on these files
- [ ] Check project.godot for references to deleted files
- [ ] Verify autoload settings don't reference deleted files

### **Post-Deletion Verification**
- [ ] Project loads without errors in Godot
- [ ] No broken import paths in console
- [ ] Test suite still passes
- [ ] All scenes load properly
- [ ] No missing script warnings

### **Rollback Plan**
- Git commit before deletion: `git add -A && git commit -m "Pre-cleanup snapshot"`
- If issues occur: `git reset --hard HEAD~1`

---

## 🎯 **RECOMMENDED EXECUTION ORDER**

1. **Backup**: Commit current state to git
2. **High Priority**: Delete backup files and misplaced tests
3. **Test**: Verify project loads and tests pass
4. **Medium Priority**: Review compatibility stubs, delete if unused
5. **Final**: Remove empty directories
6. **Verify**: Full project validation

This cleanup will significantly improve codebase organization while maintaining all functional code and preserving the sophisticated architecture of the Five Parsecs Campaign Manager.

---

*Generated by Claude Code for Five Parsecs Campaign Manager*
*Date: 2025-01-05*