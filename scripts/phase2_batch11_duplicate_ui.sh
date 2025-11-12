#!/bin/bash
# Phase 2 Batch 11: Delete Duplicate UI Components
# Target: Delete 4 duplicate/minimal-usage UI components
# Risk Level: ZERO (duplicates or minimal usage found)

echo "==================================================================="
echo "PHASE 2 BATCH 11: DUPLICATE UI COMPONENTS DELETION"
echo "Target: Delete 4 duplicate/unused UI components"
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

UI_FILES=(
    # Duplicate base/stripped versions
    "src/ui/components/base/ResponsiveContainer.gd"
    "src/base/ui/BaseController.gd"

    # Minimal usage components (only 2 references each)
    "src/ui/components/tooltip/TooltipManager.gd"
    "src/ui/components/gesture/GestureManager.gd"
)

deleted_count=0
for file in "${UI_FILES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done

echo ""
echo "==================================================================="
echo "Batch 11 complete: $deleted_count duplicate/unused UI components deleted"
echo "==================================================================="
echo ""
echo "Next: Run project verification to ensure no parse errors"
