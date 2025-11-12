#!/bin/bash
# Phase 1 Batch 6: Delete Character Migration Files
# Target: Delete 3 migration files (migration complete)
# Risk Level: ZERO (migration verified complete via git log)

echo "==================================================================="
echo "PHASE 1 BATCH 6: CHARACTER MIGRATION FILES DELETION"
echo "Target: Delete 3 completed migration files"
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

MIGRATION_FILES=(
    # Character migration (migration complete per git log)
    "src/core/character/FiveParsecsCharacterMigration.gd"

    # Combat migration (no active usage)
    "src/core/combat/FiveParsecsCombatMigration.gd"

    # Resource migration (one-time operation complete)
    "src/data/migration/ResourceMigrationAdapter.gd"
)

deleted_count=0
for file in "${MIGRATION_FILES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done

# Remove empty migration directory if it exists
if [ -d "src/data/migration" ] && [ -z "$(ls -A src/data/migration)" ]; then
    echo "  ✓ Removing empty directory: src/data/migration"
    rmdir src/data/migration
fi

echo ""
echo "==================================================================="
echo "Batch 6 complete: $deleted_count files deleted"
echo "==================================================================="
echo ""
echo "Next: Run project verification"
