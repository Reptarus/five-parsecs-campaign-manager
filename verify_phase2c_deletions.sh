#!/bin/bash
# Phase 2C Deletion Verification Script
# Run this before executing deletions to confirm zero references

echo "=================================================="
echo "PHASE 2C DELETION VERIFICATION"
echo "=================================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Batch 14: Orphaned Manager and Stub Files
echo "BATCH 14: Orphaned Manager and Stub Mission Files"
echo "--------------------------------------------------"

declare -a batch14_files=(
    "src/core/managers/LoanManager.gd"
    "src/base/campaign/BaseCampaignManager.gd"
    "src/game/missions/StreetFightMission.gd"
    "src/game/missions/SalvageMission.gd"
    "src/game/missions/StealthMission.gd"
    "src/core/battle/enemy/Enemy.gd"
)

batch14_total=0
batch14_safe=0

for file in "${batch14_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠ SKIP${NC}: $file (file not found)"
        continue
    fi

    filename=$(basename "$file" .gd)
    refs=$(grep -r "$filename" src --include="*.gd" 2>/dev/null | grep -v "^$file:" | wc -l)

    batch14_total=$((batch14_total + 1))

    if [ "$refs" -eq 0 ]; then
        echo -e "${GREEN}✓ SAFE${NC}: $file (0 references)"
        batch14_safe=$((batch14_safe + 1))
    else
        echo -e "${RED}✗ RISK${NC}: $file ($refs references found)"
        echo "  Sample references:"
        grep -r "$filename" src --include="*.gd" 2>/dev/null | grep -v "^$file:" | head -3
    fi
done

echo ""
echo "Batch 14 Summary: $batch14_safe/$batch14_total files safe to delete"
echo ""

# Batch 15: Unused Base* Template Classes
echo "BATCH 15: Unused Base* Template Classes"
echo "--------------------------------------------------"

declare -a batch15_files=(
    "src/base/campaign/BaseCampaign.gd"
    "src/base/combat/BaseBattleCharacter.gd"
    "src/base/combat/BaseBattleData.gd"
    "src/base/campaign/BaseMissionGenerator.gd"
    "src/base/combat/BaseMainBattleController.gd"
    "src/base/combat/BaseCombatManager.gd"
    "src/base/combat/BaseBattleRules.gd"
    "src/base/combat/battlefield/BaseBattlefieldManager.gd"
)

batch15_total=0
batch15_safe=0

for file in "${batch15_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠ SKIP${NC}: $file (file not found)"
        continue
    fi

    classname=$(basename "$file" .gd)

    # Check for inheritance (extends ClassName)
    extends_refs=$(grep -r "extends $classname" src --include="*.gd" 2>/dev/null | wc -l)

    # Check for direct references (preload, new, etc)
    direct_refs=$(grep -r "$classname" src --include="*.gd" 2>/dev/null | grep -v "^$file:" | wc -l)

    batch15_total=$((batch15_total + 1))

    if [ "$extends_refs" -eq 0 ] && [ "$direct_refs" -eq 0 ]; then
        echo -e "${GREEN}✓ SAFE${NC}: $file (0 extends, 0 references)"
        batch15_safe=$((batch15_safe + 1))
    elif [ "$extends_refs" -eq 0 ] && [ "$direct_refs" -lt 3 ]; then
        echo -e "${YELLOW}⚠ CHECK${NC}: $file (0 extends, $direct_refs references)"
        echo "  References found:"
        grep -r "$classname" src --include="*.gd" 2>/dev/null | grep -v "^$file:" | head -3
    else
        echo -e "${RED}✗ RISK${NC}: $file ($extends_refs extends, $direct_refs references)"
        echo "  Inheritance found:"
        grep -r "extends $classname" src --include="*.gd" 2>/dev/null | head -3
    fi
done

echo ""
echo "Batch 15 Summary: $batch15_safe/$batch15_total files safe to delete"
echo ""

# Overall Summary
echo "=================================================="
echo "OVERALL SUMMARY"
echo "=================================================="
total_files=$((batch14_total + batch15_total))
total_safe=$((batch14_safe + batch15_safe))

echo "Total files checked: $total_files"
echo "Safe to delete: $total_safe"
echo "Needs review: $((total_files - total_safe))"
echo ""

if [ "$total_safe" -eq "$total_files" ]; then
    echo -e "${GREEN}✓ ALL FILES SAFE TO DELETE${NC}"
    echo ""
    echo "Proceed with Phase 2C execution:"
    echo "  1. Run deletions for Batch 14"
    echo "  2. Verify with: godot --headless --quit --check-only"
    echo "  3. Commit Batch 14"
    echo "  4. Run deletions for Batch 15"
    echo "  5. Verify with: godot --headless --quit --check-only"
    echo "  6. Commit Batch 15"
else
    echo -e "${YELLOW}⚠ REVIEW FLAGGED FILES BEFORE DELETION${NC}"
    echo ""
    echo "Some files have references. Review the output above."
fi

echo ""
echo "=================================================="
