#!/bin/bash
# Phase 2C Sprint 5: Remove Empty Directories
# Target: Remove 2 empty directories
# Risk Level: ZERO (completely empty directories)

echo "==================================================================="
echo "PHASE 2C SPRINT 5: EMPTY DIRECTORIES REMOVAL"
echo "Target: Remove 2 empty directories"
echo "==================================================================="
echo ""

# Function to safely remove empty directories
safe_rmdir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        # Check if directory is truly empty (only . and .. entries)
        if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
            echo "  ✓ Removing empty directory: $dir"
            rmdir "$dir" 2>/dev/null && return 0 || {
                echo "  ⚠ Failed to remove: $dir"
                return 1
            }
        else
            echo "  ⚠ Directory not empty: $dir"
            return 1
        fi
    else
        echo "  ⚠ Not found: $dir"
        return 1
    fi
}

EMPTY_DIRS=(
    "src/scenes/campaign/world_phase"
    "src/ui/screens/campaign/panels/fixes"
)

removed_count=0
for dir in "${EMPTY_DIRS[@]}"; do
    if safe_rmdir "$dir"; then
        ((removed_count++))
    fi
done

echo ""
echo "==================================================================="
echo "Sprint 5 complete: $removed_count empty directories removed"
echo "==================================================================="
echo ""
echo "Empty directories eliminated - project structure cleaned"
