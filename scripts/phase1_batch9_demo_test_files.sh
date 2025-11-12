#!/bin/bash
# Phase 1 Batch 9: Delete Demo & Test Files
# Target: Delete 3 demo/test files
# Risk Level: ZERO (demo code, not used in production)

echo "==================================================================="
echo "PHASE 1 BATCH 9: DEMO & TEST FILES DELETION"
echo "Target: Delete 3 demo/test files"
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

DEMO_FILES=(
    # Demo files (not used in production)
    "src/utils/HybridApproachDemo.gd"
    "src/demo/WorldPhaseRefactoringDemo.gd"

    # Test wrapper (only for testing, not production)
    "src/core/systems/GlobalEnumsTestWrapper.gd"
)

deleted_count=0
for file in "${DEMO_FILES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done

echo ""
echo "==================================================================="
echo "Batch 9 complete: $deleted_count demo/test files deleted"
echo "==================================================================="
echo ""
echo "Next: Run project verification to ensure no parse errors"
