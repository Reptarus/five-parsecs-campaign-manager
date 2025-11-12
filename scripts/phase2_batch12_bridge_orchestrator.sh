#!/bin/bash
# Phase 2 Batch 12: Delete Bridge/Orchestrator Files
# Target: Delete 3 bridge/orchestrator files
# Risk Level: LOW (zero references or consolidated into BaseController)

echo "==================================================================="
echo "PHASE 2 BATCH 12: BRIDGE/ORCHESTRATOR FILES DELETION"
echo "Target: Delete 3 unused bridge/orchestrator files"
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

BRIDGE_FILES=(
    # Zero references - orphaned orchestrator
    "src/ui/screens/campaign/PanelOrchestrator.gd"

    # Consolidated into BaseController
    "src/ui/screens/campaign/controllers/UniversalControllerUtilities.gd"

    # Zero references - unused bridge pattern
    "src/core/campaign/creation/CampaignFinalizationBridge.gd"
)

deleted_count=0
for file in "${BRIDGE_FILES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done

echo ""
echo "==================================================================="
echo "Batch 12 complete: $deleted_count bridge/orchestrator files deleted"
echo "==================================================================="
echo ""
echo "Next: Run project verification to ensure no parse errors"
