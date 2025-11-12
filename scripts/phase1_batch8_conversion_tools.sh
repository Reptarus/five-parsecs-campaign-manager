#!/bin/bash
# Phase 1 Batch 8: Delete Conversion Tools & Utilities
# Target: Delete 10 files (conversion tools, unused controllers, backups)
# Risk Level: ZERO (conversion complete, controllers unused, backups safe to delete)

echo "==================================================================="
echo "PHASE 1 BATCH 8: CONVERSION TOOLS & UTILITIES DELETION"
echo "Target: Delete 10 obsolete conversion/utility files"
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

CONVERSION_FILES=(
    # JSON to TRES conversion tools (completed)
    "src/data/JsonToTresConverter.gd"
    "src/tools/JSONToResourceConverter.gd"
    "src/tools/run_conversion.gd"

    # Unused UI controllers (never integrated)
    "src/ui/screens/campaign/controllers/CampaignPanelSignalBridge.gd"
    "src/ui/screens/campaign/controllers/FiveParsecsUIController.gd"

    # Unused managers
    "src/core/managers/PsionicManager.gd"

    # Verification/test tools (completed)
    "src/tools/verify_campaign_system.gd"

    # Backup files
    "project.godot.backup"
    "src/ui/screens/campaign/panels/CrewPanel.gd.backup_20250817192329"

    # Duplicate panel transition manager
    "src/core/ui/PanelTransitionManager.gd"
)

deleted_count=0
for file in "${CONVERSION_FILES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done

echo ""
echo "==================================================================="
echo "Batch 8 complete: $deleted_count conversion/utility files deleted"
echo "==================================================================="
echo ""
echo "Next: Run project verification to ensure no parse errors"
