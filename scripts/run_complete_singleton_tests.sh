#!/bin/bash

# Complete GlobalEnums Singleton Simulation Test Runner
# Demonstrates all 4 approaches to singleton simulation for testing
# Provides comprehensive validation of the enum migration system

set -e  # Exit on any error

# Configuration
PROJECT_ROOT="/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"
GODOT_BINARY="/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe"
REPORT_DIR="$PROJECT_ROOT/tests/reports/singleton_simulation"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 GLOBALENUMS SINGLETON SIMULATION TEST SUITE${NC}"
echo "=" * 80
echo "Project: Five Parsecs Campaign Manager"
echo "Solution: Complete GlobalEnums Singleton Simulation"
echo "Approaches: 4 different singleton simulation methods"
echo "Framework: GdUnit4 with custom utilities"
echo "Time: $(date)"
echo ""

# Validate environment
echo -e "${BLUE}🔧 Validating test environment...${NC}"

if [ ! -f "$GODOT_BINARY" ]; then
    echo -e "${RED}❌ ERROR: Godot binary not found${NC}"
    exit 1
fi

if [ ! -d "$PROJECT_ROOT" ]; then
    echo -e "${RED}❌ ERROR: Project directory not found${NC}"
    exit 1
fi

if [ ! -d "$PROJECT_ROOT/addons/gdUnit4" ]; then
    echo -e "${RED}❌ ERROR: GdUnit4 addon not found${NC}"
    exit 1
fi

# Create report directory
mkdir -p "$REPORT_DIR"

echo -e "${GREEN}✅ Environment validation passed${NC}"
echo ""

# Change to project directory
cd "$PROJECT_ROOT"

# Store overall results
declare -A approach_results
overall_success=true

echo -e "${PURPLE}🎯 APPROACH 1: GDUNIT4 MOCK SYSTEM${NC}"
echo "-" * 50
echo "Description: Fast, isolated unit testing with mocks"
echo "Use Case: Unit tests, TDD, isolated component testing"
echo "Speed: Very Fast (< 1 second)"
echo ""

"$GODOT_BINARY" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    -a tests/unit/test_global_enums_unit.gd \
    --ignoreHeadlessMode -c 2>&1 | tee "$REPORT_DIR/approach1_mocks.log"

APPROACH1_EXIT=${PIPESTATUS[0]}
approach_results["mocks"]=$APPROACH1_EXIT

if [ $APPROACH1_EXIT -eq 0 ]; then
    echo -e "${GREEN}✅ Approach 1 (GdUnit4 Mocks): PASSED${NC}"
else
    echo -e "${RED}❌ Approach 1 (GdUnit4 Mocks): FAILED${NC}"
    overall_success=false
fi
echo ""

echo -e "${PURPLE}🎯 APPROACH 2: MANUAL SINGLETON INJECTION${NC}"
echo "-" * 50
echo "Description: Direct singleton replacement with TestSingletonHelper"
echo "Use Case: Integration tests, singleton dependency testing"
echo "Speed: Medium (1-5 seconds)"
echo ""

"$GODOT_BINARY" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    -a tests/integration/test_global_enums_gdunit4.gd \
    --ignoreHeadlessMode -c 2>&1 | tee "$REPORT_DIR/approach2_injection.log"

APPROACH2_EXIT=${PIPESTATUS[0]}
approach_results["injection"]=$APPROACH2_EXIT

if [ $APPROACH2_EXIT -eq 0 ]; then
    echo -e "${GREEN}✅ Approach 2 (Manual Injection): PASSED${NC}"
else
    echo -e "${RED}❌ Approach 2 (Manual Injection): FAILED${NC}"
    overall_success=false
fi
echo ""

echo -e "${PURPLE}🎯 APPROACH 3: AUTOLOADMANAGER FALLBACKS${NC}"
echo "-" * 50
echo "Description: Leverage existing AutoloadManager for fallbacks"
echo "Use Case: Resilient testing, production-like environments"
echo "Speed: Medium (2-10 seconds)"
echo ""

"$GODOT_BINARY" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    -a tests/integration/test_enum_migration_gdunit4.gd \
    --ignoreHeadlessMode -c 2>&1 | tee "$REPORT_DIR/approach3_fallbacks.log"

APPROACH3_EXIT=${PIPESTATUS[0]}
approach_results["fallbacks"]=$APPROACH3_EXIT

if [ $APPROACH3_EXIT -eq 0 ]; then
    echo -e "${GREEN}✅ Approach 3 (AutoloadManager Fallbacks): PASSED${NC}"
else
    echo -e "${RED}❌ Approach 3 (AutoloadManager Fallbacks): FAILED${NC}"
    overall_success=false
fi
echo ""

echo -e "${PURPLE}🎯 APPROACH 4: HEADLESS TEST RUNNER${NC}"
echo "-" * 50
echo "Description: Complete system testing with proper autoload initialization"
echo "Use Case: End-to-end testing, CI/CD pipelines, production validation"
echo "Speed: Slower (5-30 seconds)"
echo ""

"$GODOT_BINARY" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    -a tests/e2e/test_enum_migration_e2e.gd \
    --ignoreHeadlessMode -c 2>&1 | tee "$REPORT_DIR/approach4_headless.log"

APPROACH4_EXIT=${PIPESTATUS[0]}
approach_results["headless"]=$APPROACH4_EXIT

if [ $APPROACH4_EXIT -eq 0 ]; then
    echo -e "${GREEN}✅ Approach 4 (Headless Runner): PASSED${NC}"
else
    echo -e "${RED}❌ Approach 4 (Headless Runner): FAILED${NC}"
    overall_success=false
fi
echo ""

echo -e "${CYAN}🎯 BONUS: COMPLETE INTEGRATED SUITE${NC}"
echo "-" * 50
echo "Description: All approaches combined in sequence"
echo "Use Case: Comprehensive validation, full system verification"
echo "Speed: Complete (10-60 seconds)"
echo ""

"$GODOT_BINARY" --headless --path . -s run_complete_enum_test_suite.gd 2>&1 | tee "$REPORT_DIR/complete_suite.log"

COMPLETE_EXIT=${PIPESTATUS[0]}
approach_results["complete"]=$COMPLETE_EXIT

if [ $COMPLETE_EXIT -eq 0 ]; then
    echo -e "${GREEN}✅ Complete Integrated Suite: PASSED${NC}"
else
    echo -e "${RED}❌ Complete Integrated Suite: FAILED${NC}"
    overall_success=false
fi
echo ""

# Generate comprehensive summary
echo -e "${BLUE}📊 COMPREHENSIVE SINGLETON SIMULATION RESULTS${NC}"
echo "=" * 80

echo "APPROACH RESULTS:"
echo "  1. GdUnit4 Mocks:           $([ ${approach_results[mocks]} -eq 0 ] && echo -e "${GREEN}PASSED${NC}" || echo -e "${RED}FAILED${NC}")"
echo "  2. Manual Injection:        $([ ${approach_results[injection]} -eq 0 ] && echo -e "${GREEN}PASSED${NC}" || echo -e "${RED}FAILED${NC}")"
echo "  3. AutoloadManager Fallbacks: $([ ${approach_results[fallbacks]} -eq 0 ] && echo -e "${GREEN}PASSED${NC}" || echo -e "${RED}FAILED${NC}")"
echo "  4. Headless Runner:         $([ ${approach_results[headless]} -eq 0 ] && echo -e "${GREEN}PASSED${NC}" || echo -e "${RED}FAILED${NC}")"
echo "  5. Complete Suite:          $([ ${approach_results[complete]} -eq 0 ] && echo -e "${GREEN}PASSED${NC}" || echo -e "${RED}FAILED${NC}")"

# Count successes
successful_approaches=0
total_approaches=5

for approach in mocks injection fallbacks headless complete; do
    if [ ${approach_results[$approach]} -eq 0 ]; then
        successful_approaches=$((successful_approaches + 1))
    fi
done

echo ""
echo "SUCCESS RATE: $successful_approaches/$total_approaches approaches passed"

# Final assessment
echo ""
if [ "$overall_success" = true ]; then
    echo -e "${GREEN}🎉 ALL SINGLETON SIMULATION APPROACHES SUCCESSFUL!${NC}"
    echo ""
    echo "SOLUTION VALIDATION:"
    echo -e "  ${GREEN}✅ Problem solved: GlobalEnums singleton testing now possible${NC}"
    echo -e "  ${GREEN}✅ Multiple approaches available for different use cases${NC}"
    echo -e "  ${GREEN}✅ GdUnit4 integration working properly${NC}"
    echo -e "  ${GREEN}✅ Headless mode execution validated${NC}"
    echo -e "  ${GREEN}✅ CI/CD pipeline ready${NC}"
    echo ""
    echo "RECOMMENDED USAGE:"
    echo "  🎭 Use Approach 1 (Mocks) for fast unit tests"
    echo "  🔧 Use Approach 2 (Injection) for integration tests"
    echo "  🔄 Use Approach 3 (Fallbacks) for resilient testing"
    echo "  🖥️ Use Approach 4 (Headless) for CI/CD and production validation"
    echo ""
    echo "NEXT STEPS:"
    echo "  🚀 Deploy enum migration system to production"
    echo "  📈 Set up continuous monitoring"
    echo "  🔄 Integrate into CI/CD pipeline"
    echo "  📋 Document singleton testing patterns for team"
    
else
    echo -e "${RED}❌ SOME SINGLETON SIMULATION APPROACHES FAILED${NC}"
    echo ""
    echo "TROUBLESHOOTING:"
    echo "  🔍 Review logs in $REPORT_DIR/"
    echo "  🛠️ Check GdUnit4 installation and configuration"
    echo "  🔧 Verify singleton simulation setup"
    echo "  📋 Ensure all test dependencies are available"
    echo ""
    echo "FAILED APPROACHES:"
    
    for approach in mocks injection fallbacks headless complete; do
        if [ ${approach_results[$approach]} -ne 0 ]; then
            case $approach in
                mocks) echo "  ❌ GdUnit4 Mocks - Check mock factory configuration" ;;
                injection) echo "  ❌ Manual Injection - Check TestSingletonHelper" ;;
                fallbacks) echo "  ❌ AutoloadManager - Check fallback system" ;;
                headless) echo "  ❌ Headless Runner - Check autoload initialization" ;;
                complete) echo "  ❌ Complete Suite - Check all components" ;;
            esac
        fi
    done
fi

echo ""
echo "📄 Detailed logs saved to: $REPORT_DIR/"
echo "🕐 Test execution completed at: $(date)"
echo "=" * 80

# Exit with appropriate code
if [ "$overall_success" = true ]; then
    exit 0
else
    exit 1
fi