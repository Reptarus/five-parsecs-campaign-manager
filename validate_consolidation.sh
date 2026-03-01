#!/bin/bash
# Post-Consolidation Validation Script
# Usage: ./validate_consolidation.sh

set -e  # Exit on error

PROJECT_PATH="c:/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"
GODOT_CONSOLE="/mnt/c/Users/elija/Desktop/GoDot/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe"

echo "=========================================="
echo "POST-CONSOLIDATION VALIDATION"
echo "=========================================="
echo ""

# Step 1: Parse Check
echo "[1/5] Running parse check..."
"$GODOT_CONSOLE" --headless --check-only --path "$PROJECT_PATH" --quit-after 8 2>&1 | tee parse_check.log
if grep -q "ERROR" parse_check.log; then
    echo "❌ PARSE CHECK FAILED - See parse_check.log for details"
    exit 1
else
    echo "✓ Parse check passed"
fi
echo ""

# Step 2: File Count Verification
echo "[2/5] Verifying file count reduction..."
CURRENT_COUNT=$(find src -name "*.gd" | wc -l)
echo "Current file count: $CURRENT_COUNT"
if [ "$CURRENT_COUNT" -gt 350 ]; then
    echo "⚠️  File count still above target (350+)"
elif [ "$CURRENT_COUNT" -gt 250 ]; then
    echo "✓ Minimum viable consolidation achieved (< 350 files)"
elif [ "$CURRENT_COUNT" -gt 150 ]; then
    echo "✓✓ Target consolidation achieved (< 250 files)"
else
    echo "✓✓✓ Stretch goal achieved (< 150 files)"
fi
echo ""

# Step 3: Autoload Path Validation
echo "[3/5] Validating autoload paths..."
MISSING_AUTOLOADS=0
while IFS= read -r line; do
    if [[ "$line" =~ \"*res:// ]]; then
        # Extract path between quotes
        PATH_PART=$(echo "$line" | sed -n 's/.*"\*res:\/\/\([^"]*\)".*/\1/p')
        FULL_PATH="$PROJECT_PATH/$PATH_PART"

        # Convert Windows path for WSL
        WSL_PATH=$(echo "$FULL_PATH" | sed 's|c:/|/mnt/c/|')

        if [ -f "$WSL_PATH" ]; then
            echo "  ✓ $PATH_PART"
        else
            echo "  ❌ MISSING: $PATH_PART"
            ((MISSING_AUTOLOADS++))
        fi
    fi
done < project.godot

if [ "$MISSING_AUTOLOADS" -eq 0 ]; then
    echo "✓ All autoload paths valid"
else
    echo "❌ $MISSING_AUTOLOADS autoload paths broken - CRITICAL ISSUE"
    exit 1
fi
echo ""

# Step 4: Duplicate class_name Check
echo "[4/5] Checking for duplicate class_name declarations..."
DUPLICATE_CLASSES=$(grep -r "^class_name " src --include="*.gd" | awk '{print $2}' | sort | uniq -d)
if [ -z "$DUPLICATE_CLASSES" ]; then
    echo "✓ No duplicate class_name declarations found"
else
    echo "❌ Duplicate class_name declarations found:"
    echo "$DUPLICATE_CLASSES"
    exit 1
fi
echo ""

# Step 5: Signal Definition Count
echo "[5/5] Verifying signal preservation..."
SIGNAL_COUNT=$(grep -r "^signal " src --include="*.gd" | wc -l)
echo "Total signals defined: $SIGNAL_COUNT"
if [ "$SIGNAL_COUNT" -lt 200 ]; then
    echo "⚠️  Warning: Signal count seems low (expected 300+). Verify manually."
else
    echo "✓ Signal count preserved"
fi
echo ""

echo "=========================================="
echo "VALIDATION COMPLETE"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Review parse_check.log for any warnings"
echo "2. Run test suite: ./run_test_suite.sh"
echo "3. Perform manual smoke testing"
echo "4. Check performance metrics"
echo ""
