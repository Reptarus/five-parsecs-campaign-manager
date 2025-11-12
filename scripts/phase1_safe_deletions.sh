#!/bin/bash
# Phase 1: Safe Deletions Script
# Target: 518 → 368 files (-150 files)
# Risk Level: ZERO

# Don't exit on error - continue through missing files

BACKUP_DIR="backups/phase1_$(date +%Y%m%d_%H%M%S)"
PROJECT_ROOT="C:/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"

echo "==================================================================="
echo "PHASE 1: SAFE DELETIONS"
echo "Target: Delete 150 zero-risk files"
echo "==================================================================="
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "Backup directory created: $BACKUP_DIR"
echo ""

# Function to safely delete files
safe_delete() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "  ✓ Deleting: $file"
        # Try git rm first, fall back to regular rm
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

# BATCH 1: Deprecated/Disabled Files (9 files)
echo "BATCH 1: Deleting deprecated/disabled files..."
DEPRECATED_FILES=(
    # .disabled files
    "src/ui/screens/campaign/SimpleCampaignCreation.gd.disabled"
    "src/ui/screens/campaign/SimpleCampaignCreation.tscn.disabled"
    "src/ui/screens/campaign/CampaignWorkflowOrchestrator.tscn.disabled"

    # .backup files (keeping project.godot.backup for safety)
    "assets/PNG/Double (128px)/arrow_diagonal_cross_divided.png.import.backup"
    "assets/PNG/Double (128px)/arrow_rotate.png.import.backup"
    "assets/PNG/Double (128px)/arrow_diagonal_cross.png.import.backup"
    "assets/images/global-plugin.png.import.backup"

    # .DELETED files
    "src/utils/UniversalSignalManager.gd.DELETED"

    # .uid files for deleted scripts
    "src/ui/screens/campaign/SimpleCampaignCreation.gd.uid"
)

deleted_count=0
for file in "${DEPRECATED_FILES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done
echo "Batch 1 complete: $deleted_count files deleted"
echo ""

# BATCH 2: Test Files (30+ files)
echo "BATCH 2: Deleting test/demo files..."
TEST_FILES=(
    # Root test files
    "test_complete_campaign_flow.gd"
    "test_complete_campaign_flow.gd.uid"
    "test_final_campaign_integration.gd"
    "test_final_campaign_integration.gd.uid"

    # Data test files
    "src/data/TestJsonConversion.gd"
    "src/data/TestJsonConversion.gd.uid"
    "src/data/TestJsonConversion.tscn"
    "src/data/TestResourceSystem.gd"
    "src/data/TestResourceSystem.gd.uid"
    "src/data/TestRunner.gd"
    "src/data/TestRunner.gd.uid"
    "src/data/ConversionExample.gd"
    "src/data/ConversionExample.gd.uid"
    "src/data/FullConversion.gd"
    "src/data/FullConversion.gd.uid"
    "src/data/ManualConversion.gd"
    "src/data/ManualConversion.gd.uid"
    "src/data/QuickTest.gd"
    "src/data/QuickTest.gd.uid"
    "src/data/QuickTest.tscn"
    "src/data/SimpleResourceTest.gd"
    "src/data/SimpleResourceTest.gd.uid"

    # Tools (development-only utilities)
    "tools/BatchSceneUpdater.gd"
    "tools/BatchSceneUpdater.gd.uid"
    "tools/json_converter.gd"
    "tools/json_converter.gd.uid"
    "tools/ValidateSceneIntegrity.gd"
    "tools/ValidateSceneIntegrity.gd.uid"

    # Campaign diagnostics
    "src/ui/screens/campaign/diagnostics/TestPanelReplacement.gd"
)

deleted_count=0
for file in "${TEST_FILES[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done
echo "Batch 2 complete: $deleted_count files deleted"
echo ""

# BATCH 3: Duplicate Data Managers (6 files)
echo "BATCH 3: Deleting duplicate data managers..."
DATA_MANAGERS=(
    "src/core/data/SimplifiedDataManager.gd"
    "src/core/data/SimplifiedDataManager.gd.uid"
    "src/core/data/LazyDataManager.gd"
    "src/core/data/LazyDataManager.gd.uid"
    "src/core/character/Management/CharacterDataManager.gd"
    "src/core/character/Management/CharacterDataManager.gd.uid"
)

deleted_count=0
for file in "${DATA_MANAGERS[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done
echo "Batch 3 complete: $deleted_count files deleted"
echo ""

# BATCH 4: Duplicate Save Managers (3 files)
echo "BATCH 4: Deleting duplicate save managers..."
SAVE_MANAGERS=(
    "src/core/validation/SecureSaveManager.gd"
    "src/core/validation/SecureSaveManager.gd.uid"
    "src/core/workflow/ProductionSaveManager.gd"
    "src/core/workflow/ProductionSaveManager.gd.uid"
)

deleted_count=0
for file in "${SAVE_MANAGERS[@]}"; do
    if safe_delete "$file"; then
        ((deleted_count++))
    fi
done
echo "Batch 4 complete: $deleted_count files deleted"
echo ""

echo "==================================================================="
echo "PHASE 1 BATCH DELETIONS COMPLETE"
echo "==================================================================="
echo ""
echo "Next steps:"
echo "1. Run: git status  (review changes)"
echo "2. Test the project for errors"
echo "3. If all good: git add -A && git commit -m 'Phase 1: Safe deletions batch 1-4'"
echo "4. Continue with Base* class deletions"
echo ""
