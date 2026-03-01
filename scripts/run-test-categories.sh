#!/bin/bash

# Five Parsecs Campaign Manager - Categorized Test Runner
# Optimized test execution with smart categorization and parallel options

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BINARY="/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe"
REPORT_DIR="$PROJECT_ROOT/test_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Parse command line arguments
CATEGORY=""
PARALLEL=false
QUICK=false
VERBOSE=false
DRY_RUN=false

show_help() {
    echo "Five Parsecs Test Category Runner"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Categories:"
    echo "  --unit              Run unit tests only (fastest, <10s)"
    echo "  --integration       Run integration tests only (~60s)"
    echo "  --e2e              Run end-to-end tests only (~300s)"
    echo "  --performance      Run performance benchmarks only (~60s)"
    echo "  --critical         Run critical path tests (unit + key integration)"
    echo "  --all              Run all test categories (default)"
    echo ""
    echo "Options:"
    echo "  --parallel         Run test categories in parallel (experimental)"
    echo "  --quick            Skip slower tests, run minimal validation"
    echo "  --verbose          Show detailed test output"
    echo "  --dry-run          Show what would be executed without running"
    echo "  --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --unit                    # Quick unit test validation"
    echo "  $0 --critical --parallel     # Fast critical path with parallel execution"
    echo "  $0 --integration --verbose   # Detailed integration test output"
    echo "  $0 --quick                   # Minimal validation for pre-commit"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --unit)
            CATEGORY="unit"
            shift
            ;;
        --integration)
            CATEGORY="integration"
            shift
            ;;
        --e2e)
            CATEGORY="e2e"
            shift
            ;;
        --performance)
            CATEGORY="performance"
            shift
            ;;
        --critical)
            CATEGORY="critical"
            shift
            ;;
        --all)
            CATEGORY="all"
            shift
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        --quick)
            QUICK=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Default to all if no category specified
if [ -z "$CATEGORY" ]; then
    CATEGORY="all"
fi

echo -e "${BLUE}🧪 Five Parsecs Categorized Test Runner${NC}"
echo "========================================"
echo "Category: $CATEGORY"
echo "Parallel: $PARALLEL"
echo "Quick: $QUICK"
echo "Verbose: $VERBOSE"
echo "Dry Run: $DRY_RUN"
echo "Time: $(date)"
echo ""

# Validate environment
if [ ! -f "$GODOT_BINARY" ]; then
    echo -e "${RED}❌ ERROR: Godot binary not found at: $GODOT_BINARY${NC}"
    exit 1
fi

if [ ! -d "$PROJECT_ROOT/addons/gdUnit4" ]; then
    echo -e "${RED}❌ ERROR: GdUnit4 addon not found${NC}"
    exit 1
fi

# Create report directory
mkdir -p "$REPORT_DIR"
cd "$PROJECT_ROOT"

# Test execution tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
START_TIME=$(date +%s)

# Function to run a single test with smart timeout
run_test() {
    local test_file="$1"
    local test_name="$2"
    local test_type="$3"
    local timeout_seconds="$4"
    local is_gdunit="${5:-true}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY RUN] Would run $test_type: $test_name${NC}"
        echo "  File: $test_file"
        echo "  Timeout: ${timeout_seconds}s"
        echo "  GdUnit4: $is_gdunit"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    fi
    
    echo -e "${BLUE}🧪 Running $test_type: $test_name${NC}"
    if [ "$VERBOSE" = true ]; then
        echo "  File: $test_file"
        echo "  Timeout: ${timeout_seconds}s"
    fi
    
    local log_file="$REPORT_DIR/${test_name}_${CATEGORY}_${TIMESTAMP}.log"
    local test_start=$(date +%s)
    
    local test_command
    if [ "$is_gdunit" = true ]; then
        test_command="\"$GODOT_BINARY\" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a \"$test_file\" --ignoreHeadlessMode -c"
    else
        test_command="\"$GODOT_BINARY\" --headless --path . --script \"$test_file\" --quit"
    fi
    
    # Execute test with timeout
    if [ "$VERBOSE" = true ]; then
        echo "  Command: $test_command"
        if timeout "$timeout_seconds" bash -c "$test_command" 2>&1 | tee "$log_file"; then
            local exit_code=${PIPESTATUS[0]}
        else
            local exit_code=$?
        fi
    else
        if timeout "$timeout_seconds" bash -c "$test_command" > "$log_file" 2>&1; then
            local exit_code=0
        else
            local exit_code=$?
        fi
    fi
    
    local test_end=$(date +%s)
    local test_duration=$((test_end - test_start))
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}   ✅ PASSED (${test_duration}s)${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}   ❌ FAILED (${test_duration}s, exit code: $exit_code)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        
        if [ "$VERBOSE" = false ]; then
            echo "     Log: $log_file"
            echo "     Last 3 lines:"
            tail -n 3 "$log_file" | sed 's/^/       /'
        fi
        return 1
    fi
}

# Function to run tests in parallel
run_parallel_tests() {
    local test_list=("$@")
    local pids=()
    local results=()
    
    echo -e "${PURPLE}🔄 Running ${#test_list[@]} tests in parallel...${NC}"
    
    for test_def in "${test_list[@]}"; do
        IFS='|' read -r test_file test_name test_type timeout_seconds is_gdunit <<< "$test_def"
        
        # Run test in background
        (run_test "$test_file" "$test_name" "$test_type" "$timeout_seconds" "$is_gdunit") &
        pids+=($!)
    done
    
    # Wait for all tests to complete
    local all_passed=true
    for pid in "${pids[@]}"; do
        wait $pid
        if [ $? -ne 0 ]; then
            all_passed=false
        fi
    done
    
    return $([ "$all_passed" = true ] && echo 0 || echo 1)
}

# Define test categories
declare -A test_categories

# Unit Tests (fastest)
test_categories[unit]="
tests/unit/test_global_enums_unit.gd|GlobalEnums_Unit|Unit|30|true
"

# Integration Tests
test_categories[integration]="
tests/integration/test_campaign_initialization.gd|Campaign_Initialization|Integration|90|true
tests/integration/test_dice_manager_randomization.gd|Dice_Manager_Randomization|Integration|60|true
tests/integration/test_multilayer_randomization.gd|Multilayer_Randomization|Integration|60|true
"

# End-to-End Tests
test_categories[e2e]="
tests/e2e/test_enum_migration_e2e.gd|Enum_Migration_E2E|E2E|300|true
tests/integration/test_campaign_e2e_complete.gd|Campaign_E2E_Complete|E2E|300|true
"

# Performance Tests
test_categories[performance]="
simple_enum_test.gd|Enum_Performance|Performance|60|false
phase7d_performance_benchmarking.gd|Performance_Benchmarking|Performance|120|false
"

# Critical Path Tests (subset for quick validation)
test_categories[critical]="
tests/unit/test_global_enums_unit.gd|GlobalEnums_Unit|Critical|30|true
tests/integration/test_campaign_initialization.gd|Campaign_Initialization|Critical|90|true
"

# Execute tests based on category
execute_category() {
    local category="$1"
    
    if [ -z "${test_categories[$category]}" ]; then
        echo -e "${RED}❌ ERROR: Unknown test category: $category${NC}"
        exit 1
    fi
    
    echo -e "${PURPLE}📋 EXECUTING CATEGORY: $category${NC}"
    echo "$(echo "${test_categories[$category]}" | grep -v '^$' | wc -l) tests scheduled"
    echo ""
    
    # Filter out empty lines and parse test definitions
    local test_list=()
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            IFS='|' read -r test_file test_name test_type timeout_seconds is_gdunit <<< "$line"
            
            # Skip if file doesn't exist
            if [ ! -f "$test_file" ]; then
                echo -e "${YELLOW}  ⚠️ Skipping $test_name - file not found: $test_file${NC}"
                continue
            fi
            
            # Adjust timeout for quick mode
            if [ "$QUICK" = true ]; then
                timeout_seconds=$((timeout_seconds / 2))
                if [ $timeout_seconds -lt 30 ]; then
                    timeout_seconds=30
                fi
            fi
            
            test_list+=("$test_file|$test_name|$test_type|$timeout_seconds|$is_gdunit")
        fi
    done <<< "${test_categories[$category]}"
    
    # Execute tests
    if [ "$PARALLEL" = true ] && [ ${#test_list[@]} -gt 1 ]; then
        run_parallel_tests "${test_list[@]}"
    else
        for test_def in "${test_list[@]}"; do
            IFS='|' read -r test_file test_name test_type timeout_seconds is_gdunit <<< "$test_def"
            run_test "$test_file" "$test_name" "$test_type" "$timeout_seconds" "$is_gdunit"
        done
    fi
}

# Main execution logic
case $CATEGORY in
    "unit"|"integration"|"e2e"|"performance"|"critical")
        execute_category "$CATEGORY"
        ;;
    "all")
        if [ "$QUICK" = true ]; then
            echo -e "${YELLOW}Quick mode: Running critical tests only${NC}"
            execute_category "critical"
        else
            echo -e "${BLUE}Running all test categories...${NC}"
            for cat in unit integration performance e2e; do
                echo ""
                execute_category "$cat"
            done
        fi
        ;;
    *)
        echo -e "${RED}❌ ERROR: Invalid category: $CATEGORY${NC}"
        show_help
        exit 1
        ;;
esac

# Calculate final results
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))
SUCCESS_RATE=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))

echo ""
echo -e "${BLUE}📊 TEST EXECUTION SUMMARY${NC}"
echo "=========================="
echo "Category: $CATEGORY"
echo "Total Duration: ${TOTAL_DURATION}s"
echo "Total Tests: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"
echo "Success Rate: ${SUCCESS_RATE}%"

if [ "$PARALLEL" = true ]; then
    echo "Execution Mode: Parallel"
fi

if [ "$QUICK" = true ]; then
    echo "Mode: Quick (reduced timeouts)"
fi

echo ""
echo "📄 Test logs location: $REPORT_DIR/"

# Set exit code based on results
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
    
    # Performance feedback
    if [ $TOTAL_DURATION -lt 60 ]; then
        echo -e "${GREEN}⚡ Excellent execution time: ${TOTAL_DURATION}s${NC}"
    elif [ $TOTAL_DURATION -lt 300 ]; then
        echo -e "${YELLOW}⏱️  Good execution time: ${TOTAL_DURATION}s${NC}"
    else
        echo -e "${YELLOW}🐌 Consider optimization: ${TOTAL_DURATION}s${NC}"
    fi
    
    exit 0
else
    echo -e "${RED}❌ $FAILED_TESTS TEST(S) FAILED${NC}"
    
    echo ""
    echo "🔍 Failed test logs:"
    find "$REPORT_DIR" -name "*_${CATEGORY}_${TIMESTAMP}.log" -exec grep -l "FAILED\|ERROR" {} \; 2>/dev/null | while read log_file; do
        echo "  • $(basename "$log_file")"
    done
    
    echo ""
    echo "💡 Troubleshooting tips:"
    echo "  • Run with --verbose for detailed output"
    echo "  • Check individual test logs in $REPORT_DIR/"
    echo "  • Run single failing tests manually for debugging"
    
    exit 1
fi