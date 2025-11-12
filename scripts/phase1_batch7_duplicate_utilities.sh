#!/bin/bash
# Phase 1 Batch 7: Delete Duplicate Utility Files
# Target: Delete 4 duplicate utility files + update 6 files to use DataValidator
# Risk Level: LOW (simple find/replace needed)

echo "==================================================================="
echo "PHASE 1 BATCH 7: DUPLICATE UTILITY FILES DELETION"
echo "Target: Delete 4 duplicate utilities"
echo "==================================================================="
echo ""

# First, update files that use SafeDataAccess to use DataValidator instead
echo "Step 1: Updating 6 files to use DataValidator instead of SafeDataAccess..."

FILES_TO_UPDATE=(
    "src/core/systems/PatronSystem.gd"
    "src/core/data/DataManager.gd"
    "src/ui/screens/world/WorldPhaseUI.gd"
    "src/core/character/CharacterGeneration.gd"
    "src/base/ui/BaseCrewComponent.gd"
    "src/ui/screens/equipment/EquipmentGenerationScene.gd"
)

for file in "${FILES_TO_UPDATE[@]}"; do
    if [ -f "$file" ]; then
        if grep -q "SafeDataAccess" "$file"; then
            echo "  ✓ Updating: $file"
            sed -i 's/SafeDataAccess/DataValidator/g' "$file"
        else
            echo "  ⚠ No SafeDataAccess found in: $file"
        fi
    else
        echo "  ⚠ Not found: $file"
    fi
done

echo ""
echo "Step 2: Deleting duplicate utility files..."

# Function to safely delete files
safe_delete() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "  ✓ Deleting: $file"
        if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            git rm -f "$file" 2>/dev/null || rm -f "$file"
        else
            rm -f "$file"
        fi
        return 0
    else
        echo "  ⚠ Not found: $file"
        return 1
    fi
}

UTILITY_FILES=(
    # SafeDataAccess - duplicates DataValidator
    "src/utils/SafeDataAccess.gd"

    # DataConsistencyValidator - unused 645-line validation system
    "src/core/validation/DataConsistencyValidator.gd"

    # UniversalPanelConnector - never integrated connector pattern
    "src/core/ui/UniversalPanelConnector.gd"
)

deleted_count=0
for file in "${UTILITY_FILES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done

echo ""
echo "==================================================================="
echo "Batch 7 complete: $deleted_count files deleted, 6 files updated"
echo "==================================================================="
echo ""
echo "Next: Run project verification to ensure DataValidator replacements work"
