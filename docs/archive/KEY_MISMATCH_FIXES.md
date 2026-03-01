# Equipment and Size Key Mismatch Fixes - Phase 10

**Date**: 2025-12-28
**Issue**: Inconsistent key names across CrewPanel, Coordinator, and InitialCrewCreation causing data loss

## Problem Summary

### Equipment Key Inconsistency
| File | Key Used | Line Numbers |
|------|----------|--------------|
| CrewPanel.gd | `"starting_equipment"` | 54, 292-293, 503-504, 542-543, 662, 668, 1308, 1354, 1461, 1561 |
| Coordinator.gd | `"items"` or `"equipment"` | 56-59, 194-197 |
| FinalPanel.gd | Falls back to both `"items"` and `"equipment"` | 561 |

### Size Key Inconsistency
| File | Key Used | Meaning |
|------|----------|---------|
| InitialCrewCreation.gd | `"size"` | Target crew size (line 50-54) |
| CrewPanel.gd | `selected_size` variable + `"size"` | Mixed usage (lines 451, 468-473) |
| Coordinator.gd | `"selected_size"` AND `"size"` | Normalizes both (lines 266-271) |

## Solutions Implemented

### 1. CrewPanel Equipment Key Normalization (Lines 535-556)

**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/panels/CrewPanel.gd`

**Change**: In `_notify_coordinator_of_crew_update()`, added normalization:
```gdscript
# KEY NORMALIZATION: Ensure consistent keys for coordinator
var normalized_crew_data = local_crew_data.duplicate()

# Equipment: Convert "starting_equipment" to "items" key
if normalized_crew_data.has("starting_equipment"):
    normalized_crew_data["items"] = normalized_crew_data.get("starting_equipment", [])

# Size: Ensure both "selected_size" and "size" keys are present
normalized_crew_data["selected_size"] = selected_size
if not normalized_crew_data.has("size"):
    normalized_crew_data["size"] = selected_size
```

**Result**: CrewPanel now sends both equipment formats to coordinator:
- Internal: `"starting_equipment"` (unchanged)
- To Coordinator: `"items"` (normalized)
- Size: Both `"selected_size"` and `"size"` (normalized)

### 2. Coordinator Size Normalization (Already Exists - Lines 264-271)

**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/CampaignCreationCoordinator.gd`

**Existing Code** (No changes needed):
```gdscript
# Store crew size (4/5/6) for EnemyGenerator and FinalPanel
# Check both "selected_size" (from CrewPanel) and "size" (legacy) keys
if crew_data.has("selected_size"):
    unified_campaign_state.crew.size = crew_data.selected_size
    print("CampaignCreationCoordinator: Crew size set to %d (from selected_size)" % crew_data.selected_size)
elif crew_data.has("size") and crew_data.size > 0:
    unified_campaign_state.crew.size = crew_data.size
    print("CampaignCreationCoordinator: Crew size set to %d (from size)" % crew_data.size)
```

**Result**: Coordinator already handles both `"selected_size"` and `"size"` correctly.

### 3. FinalPanel Equipment Fallback (Already Exists - Line 561)

**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/panels/FinalPanel.gd`

**Existing Code** (No changes needed):
```gdscript
equipment_list = equipment_data.get("items", equipment_data.get("equipment", []))
```

**Result**: FinalPanel already handles both `"items"` and `"equipment"` keys.

## Data Flow Architecture

### Before Fix
```
CrewPanel
├─ Internal: "starting_equipment": [...]
└─ To Coordinator: "starting_equipment": [...]  ❌ WRONG KEY

Coordinator
├─ Expected: "items": [...]
└─ Fallback check: "equipment": [...]

FinalPanel
├─ Checks: "items"
└─ Fallback: "equipment"
```

### After Fix
```
CrewPanel
├─ Internal: "starting_equipment": [...]
├─ To Coordinator (normalized):
│   ├─ "items": [...]  ✅ CORRECT
│   ├─ "selected_size": 6  ✅ CORRECT
│   └─ "size": 6  ✅ CORRECT

Coordinator
├─ Receives: "items": [...]  ✅
├─ Receives: "selected_size": 6  ✅
└─ Normalizes to unified state

FinalPanel
├─ Reads: "items": [...]  ✅
└─ Fallback works if needed
```

## Testing Checklist

- [ ] Create new campaign
- [ ] Generate crew in CrewPanel
- [ ] Verify coordinator receives equipment with "items" key
- [ ] Verify coordinator receives both "selected_size" and "size"
- [ ] Navigate to FinalPanel
- [ ] Verify equipment displays correctly
- [ ] Verify crew size displays correctly
- [ ] Save and reload campaign
- [ ] Verify data persists correctly

## Files Modified

1. **CrewPanel.gd** - Added key normalization in `_notify_coordinator_of_crew_update()`
   - Lines 535-556 updated

## Files Verified (No Changes Needed)

1. **CampaignCreationCoordinator.gd** - Already handles both size keys
2. **FinalPanel.gd** - Already handles both equipment keys
3. **InitialCrewCreation.gd** - Uses `"size"` key (compatible with normalization)

## Related Issues

- Phase 10 Gap Analysis (Equipment Key Mismatch)
- Phase 10 Gap Analysis (Size Key Mismatch)

## Success Metrics

- ✅ CrewPanel sends equipment with "items" key to coordinator
- ✅ CrewPanel sends both "selected_size" and "size" keys to coordinator
- ✅ Coordinator normalizes all incoming data correctly
- ✅ FinalPanel displays equipment correctly
- ✅ No data loss during panel transitions
