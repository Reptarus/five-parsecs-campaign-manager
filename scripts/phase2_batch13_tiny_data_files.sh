#!/bin/bash
# Phase 2 Batch 13: Delete Tiny Data Resource Files
# Target: Delete 7 tiny data resource files (149 lines total)
# Risk Level: ZERO (imports already removed from DataManager)

echo "==================================================================="
echo "PHASE 2 BATCH 13: TINY DATA RESOURCE FILES DELETION"
echo "Target: Delete 7 tiny data resource files (149 lines)"
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

DATA_FILES=(
    # Never-used resource schemas (no .tres files exist)
    "src/data/resources/ArmorData.gd"           # 17 lines
    "src/data/resources/WeaponData.gd"          # 18 lines
    "src/data/resources/EnemyData.gd"           # 20 lines
    "src/data/resources/CrewTaskModifiersData.gd"  # 22 lines

    # Never-used database wrappers
    "src/data/resources/ArmorDatabase.gd"       # 24 lines
    "src/data/resources/WeaponDatabase.gd"      # 24 lines
    "src/data/resources/EnemyDatabase.gd"       # 24 lines
)

deleted_count=0
for file in "${DATA_FILES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done

echo ""
echo "==================================================================="
echo "Batch 13 complete: $deleted_count tiny data resource files deleted"
echo "==================================================================="
echo ""
echo "Next: Run project verification to ensure no parse errors"
