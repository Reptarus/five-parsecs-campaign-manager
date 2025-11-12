#!/bin/bash
# Phase 2C Sprint 2: Delete Orphaned Base Class Files
# Target: Delete 8 Base* class files with zero external references
# Risk Level: LOW (all have zero references verified)

echo "==================================================================="
echo "PHASE 2C SPRINT 2: ORPHANED BASE CLASS FILES DELETION"
echo "Target: Delete 8 Base* class files with zero external references"
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

BASE_CLASS_FILES=(
    # All verified with ZERO external references
    "src/base/combat/events/BaseBattleEventSystem.gd"              # 0 refs
    "src/base/combat/rewards/BaseBattleRewardSystem.gd"            # 0 refs
    "src/base/campaign/crew/BaseCrewMember.gd"                     # 0 refs
    "src/base/campaign/crew/BaseCrewRelationshipManager.gd"        # 0 refs
    "src/base/combat/enemy/BaseEnemyScalingSystem.gd"              # 0 refs
    "src/base/campaign/BaseMissionGenerator.gd"                    # 0 refs
    "src/base/combat/objectives/BaseObjectiveSystem.gd"            # 0 refs
    "src/base/campaign/crew/BaseStrangeCharacters.gd"              # 0 refs
)

deleted_count=0
for file in "${BASE_CLASS_FILES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done

echo ""
echo "==================================================================="
echo "Sprint 2 complete: $deleted_count Base* class files deleted"
echo "==================================================================="
echo ""
echo "Next: Run project verification to ensure no parse errors"
