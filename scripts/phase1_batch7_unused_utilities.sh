#!/bin/bash
# Phase 1 Batch 7 (REVISED): Delete ONLY Truly Unused Utility Files
# Target: Delete 2 unused utility files (NOT SafeDataAccess - different API)
# Risk Level: ZERO (no references found for these 2 files)

echo "==================================================================="
echo "PHASE 1 BATCH 7: UNUSED UTILITY FILES DELETION (REVISED)"
echo "Target: Delete 2 confirmed unused utilities"
echo "NOTE: SafeDataAccess kept - has different API than DataValidator"
echo "==================================================================="
echo ""

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
echo "Batch 7 complete: $deleted_count unused utility files deleted"
echo "SafeDataAccess kept (different API - needs manual refactor)"
echo "==================================================================="
echo ""
echo "Next: Run project verification to ensure no parse errors"
