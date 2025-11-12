#!/bin/bash
# Phase 2 Batch 10: Delete Fallback & Orphaned Managers
# Target: Delete 6 fallback/orphaned manager files
# Risk Level: ZERO (never used in production or completely orphaned)

echo "==================================================================="
echo "PHASE 2 BATCH 10: FALLBACK & ORPHANED MANAGERS DELETION"
echo "Target: Delete 6 unused manager files"
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

MANAGER_FILES=(
    # Fallback managers (never actually used - real autoloads always load)
    "src/core/systems/FallbackCampaignManager.gd"
    "src/core/systems/FallbackDiceManager.gd"

    # Orphaned managers (zero references found)
    "src/core/campaign/DifficultyManager.gd"
    "src/core/managers/UpkeepPhaseManager.gd"

    # Duplicate/superseded managers
    "src/game/world/WorldEconomyManager.gd"
    "src/core/workflow/WorkflowContextManager.gd"
)

deleted_count=0
for file in "${MANAGER_FILES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done

echo ""
echo "==================================================================="
echo "Batch 10 complete: $deleted_count fallback/orphaned managers deleted"
echo "==================================================================="
echo ""
echo "Next: Run project verification to ensure no parse errors"
