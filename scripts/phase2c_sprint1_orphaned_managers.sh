#!/bin/bash
# Phase 2C Sprint 1: Delete Orphaned Manager Files
# Target: Delete 6 orphaned manager files (1,300 lines total)
# Risk Level: ZERO (all references removed/verified as zero)

echo "==================================================================="
echo "PHASE 2C SPRINT 1: ORPHANED MANAGER FILES DELETION"
echo "Target: Delete 6 orphaned manager files (1,300 lines)"
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
    # Zero references - orphaned managers
    "src/base/campaign/BaseCampaignManager.gd"           # 252 lines - 0 refs
    "src/core/ui/ResponsiveDesignManager.gd"             # 189 lines - 0 refs
    "src/core/systems/UniversalSceneManager.gd"          # 378 lines - 0 refs
    "src/core/systems/UniversalSignalManager.gd"         # 156 lines - 0 refs
    "src/core/systems/GameSystemManager.gd"              # 145 lines - 0 refs

    # References removed from TacticalBattleUI.gd
    "src/core/battle/BattlefieldDisplayManager.gd"       # 180 lines - refs removed
)

deleted_count=0
for file in "${MANAGER_FILES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done

echo ""
echo "==================================================================="
echo "Sprint 1 complete: $deleted_count orphaned manager files deleted"
echo "==================================================================="
echo ""
echo "Next: Run project verification to ensure no parse errors"
