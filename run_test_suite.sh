#!/bin/bash
# Post-Consolidation Test Suite Runner
# Usage: ./run_test_suite.sh [test_category]
# Categories: unit, integration, all (default)

PROJECT_PATH="c:/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"
GODOT_CONSOLE="/mnt/c/Users/elija/Desktop/GoDot/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe"

CATEGORY=${1:-all}

echo "=========================================="
echo "RUNNING TEST SUITE: $CATEGORY"
echo "=========================================="
echo ""

run_tests() {
    local test_path=$1
    local test_name=$2
    local timeout=$3

    echo "Running $test_name tests..."
    "$GODOT_CONSOLE" \
        --path "$PROJECT_PATH" \
        --script addons/gdUnit4/bin/GdUnitCmdTool.gd \
        -a "$test_path" \
        --quit-after "$timeout" 2>&1 | tee "test_results_${test_name}.log"

    # Check for failures
    if grep -q "FAILED" "test_results_${test_name}.log"; then
        echo "❌ $test_name tests FAILED - See test_results_${test_name}.log"
        return 1
    elif grep -q "ERROR" "test_results_${test_name}.log"; then
        echo "❌ $test_name tests encountered ERRORS - See test_results_${test_name}.log"
        return 1
    else
        echo "✓ $test_name tests passed"
        return 0
    fi
}

FAILED_SUITES=0

case $CATEGORY in
    unit)
        run_tests "tests/unit" "unit" 120 || ((FAILED_SUITES++))
        ;;
    integration)
        run_tests "tests/integration" "integration" 180 || ((FAILED_SUITES++))
        ;;
    all)
        run_tests "tests/unit" "unit" 120 || ((FAILED_SUITES++))
        echo ""
        run_tests "tests/integration" "integration" 180 || ((FAILED_SUITES++))
        ;;
    *)
        echo "Unknown category: $CATEGORY"
        echo "Usage: ./run_test_suite.sh [unit|integration|all]"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "TEST SUITE SUMMARY"
echo "=========================================="

if [ "$FAILED_SUITES" -eq 0 ]; then
    echo "✓✓✓ ALL TESTS PASSED"
    echo ""
    echo "Test suite validation: SUCCESS"
    echo "No regressions detected from consolidation"
    exit 0
else
    echo "❌ $FAILED_SUITES test suite(s) FAILED"
    echo ""
    echo "CRITICAL: Consolidation introduced regressions"
    echo "Action Required: Review test logs and fix issues"
    exit 1
fi
