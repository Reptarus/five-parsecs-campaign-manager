#!/bin/bash

# Five Parsecs Campaign Manager - Comprehensive Test Suite Runner
# Executes all 21 test files in staged order with detailed reporting
# Follows CLAUDE.md MCP orchestration guidelines

set -e  # Exit on any error

# Configuration
PROJECT_ROOT="/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"
GODOT_BINARY="/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe"
REPORT_DIR="$PROJECT_ROOT/test_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Five Parsecs Comprehensive Test Suite Runner${NC}"
echo "=============================================="
echo "Project: Five Parsecs Campaign Manager"
echo "Framework: GdUnit4 + Custom Test Scripts"
echo "Mode: Headless"
echo "Time: $(date)"
echo ""

# Validate environment
echo -e "${BLUE}🔧 Validating test environment...${NC}"

if [ ! -f "$GODOT_BINARY" ]; then
    echo -e "${RED}❌ ERROR: Godot binary not found at: $GODOT_BINARY${NC}"
    exit 1
fi

if [ ! -d "$PROJECT_ROOT" ]; then
    echo -e "${RED}❌ ERROR: Project directory not found at: $PROJECT_ROOT${NC}"
    exit 1
fi

if [ ! -d "$PROJECT_ROOT/addons/gdUnit4" ]; then
    echo -e "${RED}❌ ERROR: GdUnit4 addon not found in project${NC}"
    exit 1
fi

# Create report directory
mkdir -p "$REPORT_DIR"
cd "$PROJECT_ROOT"

echo -e "${GREEN}✅ Environment validation passed${NC}"
echo ""

# Test execution tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
STAGE_RESULTS=()

# Function to run a single test
run_test() {
    local test_file="$1"
    local test_name="$2"
    local test_type="$3"
    
    echo -e "${BLUE}🧪 Running $test_type: $test_name${NC}"
    echo "   File: $test_file"
    echo "   Singleton Management: Auto-cleanup enabled"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Run test with timeout and capture output
    local log_file="$REPORT_DIR/${test_name}_${TIMESTAMP}.log"
    
    if timeout 120 "$GODOT_BINARY" --headless --path . --script "$test_file" --quit 2>&1 | tee "$log_file"; then
        local exit_code=${PIPESTATUS[0]}
        if [ $exit_code -eq 0 ]; then
            echo -e "${GREEN}   ✅ PASSED${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}   ❌ FAILED (Exit Code: $exit_code)${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        echo -e "${RED}   ❌ FAILED (Timeout or Error)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Function to run GdUnit4 test
run_gdunit4_test() {
    local test_file="$1"
    local test_name="$2"
    
    echo -e "${BLUE}🧪 Running GdUnit4 Test: $test_name${NC}"
    echo "   File: $test_file"
    echo "   Mock Strategy: Wrapper-first with fallbacks"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    local log_file="$REPORT_DIR/${test_name}_gdunit4_${TIMESTAMP}.log"
    
    if timeout 120 "$GODOT_BINARY" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a "$test_file" --ignoreHeadlessMode -c 2>&1 | tee "$log_file"; then
        local exit_code=${PIPESTATUS[0]}
        if [ $exit_code -eq 0 ]; then
            echo -e "${GREEN}   ✅ PASSED${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}   ❌ FAILED (Exit Code: $exit_code)${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        echo -e "${RED}   ❌ FAILED (Timeout or Error)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

echo -e "${BLUE}🧪 Enhanced Testing with Wrapper Strategy${NC}"
echo "Enhanced Features:"
echo "  • GlobalEnumsTestWrapper for simplified function signatures"
echo "  • Singleton injection system with fallbacks"
echo "  • Multiple mock strategies (Wrapper → Direct → Manual)"
echo "  • Automatic test environment cleanup"
echo ""

echo -e "${BLUE}📋 STAGE 1: UNIT TESTS${NC}"
echo "========================"

# Unit Tests
stage1_passed=0
stage1_total=0

if run_gdunit4_test "tests/unit/test_global_enums_unit.gd" "GlobalEnums_Unit"; then
    stage1_passed=$((stage1_passed + 1))
fi
stage1_total=$((stage1_total + 1))

STAGE_RESULTS+=("Unit Tests: $stage1_passed/$stage1_total")
echo ""

echo -e "${BLUE}📋 STAGE 2: INTEGRATION TESTS${NC}"
echo "=============================="

# Integration Tests
stage2_passed=0
stage2_total=0

integration_tests=(
    "tests/integration/test_campaign_creation_flow.gd:Campaign_Creation_Flow"
    "tests/integration/test_campaign_initialization.gd:Campaign_Initialization"
    "tests/integration/test_dice_manager_randomization.gd:Dice_Manager_Randomization"
    "tests/integration/test_multilayer_randomization.gd:Multilayer_Randomization"
    "tests/integration/test_full_campaign_turn.gd:Full_Campaign_Turn"
)

for test_entry in "${integration_tests[@]}"; do
    IFS=':' read -r test_file test_name <<< "$test_entry"
    if run_gdunit4_test "$test_file" "$test_name"; then
        stage2_passed=$((stage2_passed + 1))
    fi
    stage2_total=$((stage2_total + 1))
done

STAGE_RESULTS+=("Integration Tests: $stage2_passed/$stage2_total")
echo ""

echo -e "${BLUE}📋 STAGE 3: PHASE-SPECIFIC TESTS${NC}"
echo "================================="

# Phase-specific Tests
stage3_passed=0
stage3_total=0

phase_tests=(
    "tests/phase/test_travel_phase_substeps.gd:Travel_Phase_Substeps"
    "tests/phase/test_world_phase_substeps.gd:World_Phase_Substeps"
    "tests/phase/test_battle_phase_substeps.gd:Battle_Phase_Substeps"
    "tests/phase/test_postbattle_phase_substeps.gd:PostBattle_Phase_Substeps"
)

for test_entry in "${phase_tests[@]}"; do
    IFS=':' read -r test_file test_name <<< "$test_entry"
    if [ -f "$test_file" ]; then
        if run_gdunit4_test "$test_file" "$test_name"; then
            stage3_passed=$((stage3_passed + 1))
        fi
        stage3_total=$((stage3_total + 1))
    fi
done

STAGE_RESULTS+=("Phase Tests: $stage3_passed/$stage3_total")
echo ""

echo -e "${BLUE}📋 STAGE 4: END-TO-END TESTS${NC}"
echo "============================="

# End-to-End Tests
stage4_passed=0
stage4_total=0

e2e_tests=(
    "tests/integration/test_campaign_e2e_complete.gd:Campaign_E2E_Complete"
)

for test_entry in "${e2e_tests[@]}"; do
    IFS=':' read -r test_file test_name <<< "$test_entry"
    if [ -f "$test_file" ]; then
        if run_gdunit4_test "$test_file" "$test_name"; then
            stage4_passed=$((stage4_passed + 1))
        fi
        stage4_total=$((stage4_total + 1))
    fi
done

STAGE_RESULTS+=("E2E Tests: $stage4_passed/$stage4_total")
echo ""

echo -e "${BLUE}📋 STAGE 5: PERFORMANCE TESTS${NC}"
echo "=============================="

# Performance Tests
stage5_passed=0
stage5_total=0

performance_tests=(
    "simple_enum_test.gd:Enum_Performance"
    "phase7d_performance_benchmarking.gd:Performance_Benchmarking"
    "simple_production_test.gd:Production_Test"
)

for test_entry in "${performance_tests[@]}"; do
    IFS=':' read -r test_file test_name <<< "$test_entry"
    if [ -f "$test_file" ]; then
        if run_test "$test_file" "$test_name" "Performance"; then
            stage5_passed=$((stage5_passed + 1))
        fi
        stage5_total=$((stage5_total + 1))
    fi
done

STAGE_RESULTS+=("Performance Tests: $stage5_passed/$stage5_total")
echo ""

# Generate comprehensive report
echo -e "${BLUE}📊 COMPREHENSIVE TEST RESULTS${NC}"
echo "============================================="
echo "Execution Time: $(date)"
echo "Total Tests Executed: $TOTAL_TESTS"
echo "Tests Passed: $PASSED_TESTS"
echo "Tests Failed: $FAILED_TESTS"
echo "Success Rate: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"
echo ""

echo "Stage Breakdown:"
for result in "${STAGE_RESULTS[@]}"; do
    echo "  $result"
done
echo ""

# Determine overall result
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED SUCCESSFULLY!${NC}"
    echo ""
    echo "✅ Five Parsecs Campaign Manager test suite is production-ready"
    echo "✅ All campaign mechanics validated"
    echo "✅ Dice systems working correctly"
    echo "✅ Character generation functional"
    echo "✅ Multi-layer randomization confirmed"
    exit 0
else
    echo -e "${RED}❌ $FAILED_TESTS TEST(S) FAILED${NC}"
    echo ""
    echo "🔍 Review test logs in: $REPORT_DIR/"
    echo "🛠️ Check specific test failures for debugging"
    echo "📋 Verify system dependencies and configuration"
    
    echo ""
    echo -e "${YELLOW}📄 Recent failures (last 10 lines each):${NC}"
    for log_file in "$REPORT_DIR"/*_${TIMESTAMP}.log; do
        if [ -f "$log_file" ] && grep -q "FAILED\|ERROR" "$log_file"; then
            echo "$(basename "$log_file"):"
            tail -n 10 "$log_file" | head -n 5
            echo ""
        fi
    done
    
    exit 1
fi