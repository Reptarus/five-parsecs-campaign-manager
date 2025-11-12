#!/bin/bash
# Phase 1 Batch 5: Delete Unused Base* Classes
# Target: Delete 12 zero-reference Base classes
# Risk Level: ZERO (no references found)

echo "==================================================================="
echo "PHASE 1 BATCH 5: UNUSED BASE* CLASSES DELETION"
echo "Target: Delete 12 Base classes with zero references"
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

BASE_CLASSES=(
    # Campaign base classes (unused)
    "src/base/campaign/BasePostBattlePhase.gd"
    "src/base/campaign/BasePreBattleLoop.gd"

    # Crew base classes (unused)
    "src/base/campaign/crew/BaseCrewExporter.gd"
    "src/base/campaign/crew/BaseCrewSystem.gd"

    # Combat base classes (legacy)
    "src/base/combat/base_combat_system.gd"

    # Mission base classes (replaced)
    "src/base/mission/mission_base.gd"

    # Ship base classes (unused)
    "src/base/ships/base_ship.gd"
    "src/base/ships/base_ship_component.gd"

    # World base classes (unused)
    "src/base/world/world_base.gd"
    "src/base/world/base_world_system.gd"
    "src/base/world/economy_manager_base.gd"

    # Character base class (replaced)
    "src/base/character/character_base.gd"
)

deleted_count=0
for file in "${BASE_CLASSES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done

echo ""
echo "==================================================================="
echo "Batch 5 complete: $deleted_count files deleted"
echo "==================================================================="
echo ""
echo "Next: Run project verification"
