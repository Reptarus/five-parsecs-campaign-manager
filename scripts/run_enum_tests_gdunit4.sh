#!/bin/bash

# GdUnit4 Enum Migration Test Runner Script
# Executes enum migration tests using GdUnit4 framework with headless mode
# Supports both Windows (WSL) and native Linux environments

set -e  # Exit on any error

# Configuration
PROJECT_ROOT="/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"
GODOT_BINARY="/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe"
REPORT_DIR="$PROJECT_ROOT/tests/reports/gdunit4"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 GdUnit4 Enum Migration Test Runner${NC}"
echo "=" * 60
echo "Project: Five Parsecs Campaign Manager"
echo "Framework: GdUnit4"
echo "Mode: Headless"
echo "Time: $(date)"
echo ""

# Validate environment
echo -e "${BLUE}🔧 Validating test environment...${NC}"

# Check if Godot binary exists
if [ ! -f "$GODOT_BINARY" ]; then
    echo -e "${RED}❌ ERROR: Godot binary not found at: $GODOT_BINARY${NC}"
    exit 1
fi

# Check if project directory exists
if [ ! -d "$PROJECT_ROOT" ]; then
    echo -e "${RED}❌ ERROR: Project directory not found at: $PROJECT_ROOT${NC}"
    exit 1
fi

# Check if GdUnit4 is installed
if [ ! -d "$PROJECT_ROOT/addons/gdUnit4" ]; then
    echo -e "${RED}❌ ERROR: GdUnit4 addon not found in project${NC}"
    exit 1
fi

# Create report directory
mkdir -p "$REPORT_DIR"

echo -e "${GREEN}✅ Environment validation passed${NC}"
echo ""

# Change to project directory
cd "$PROJECT_ROOT"

echo -e "${BLUE}🧪 Running GdUnit4 Tests...${NC}"
echo ""

# Method 1: Direct GdUnit4 CLI execution
echo "Method 1: Direct GdUnit4 CLI execution"
echo "Command: $GODOT_BINARY --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/integration/test_global_enums_gdunit4.gd --ignoreHeadlessMode"
echo ""

"$GODOT_BINARY" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    -a tests/integration/test_global_enums_gdunit4.gd \
    --ignoreHeadlessMode \
    -rd "$REPORT_DIR" \
    -c 2>&1 | tee "$REPORT_DIR/test_output_method1.log"

METHOD1_EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "Method 1 Exit Code: $METHOD1_EXIT_CODE"
echo ""

# Method 2: Custom test runner execution
echo "Method 2: Custom test runner execution"
echo "Command: $GODOT_BINARY --headless --path . -s run_gdunit4_enum_tests.gd"
echo ""

"$GODOT_BINARY" --headless --path . -s run_gdunit4_enum_tests.gd 2>&1 | tee "$REPORT_DIR/test_output_method2.log"

METHOD2_EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "Method 2 Exit Code: $METHOD2_EXIT_CODE"
echo ""

# Method 3: Enum migration test suite
echo "Method 3: Enum migration test suite execution"
echo "Command: $GODOT_BINARY --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/integration/test_enum_migration_gdunit4.gd --ignoreHeadlessMode"
echo ""

"$GODOT_BINARY" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    -a tests/integration/test_enum_migration_gdunit4.gd \
    --ignoreHeadlessMode \
    -rd "$REPORT_DIR" \
    -c 2>&1 | tee "$REPORT_DIR/test_output_method3.log"

METHOD3_EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "Method 3 Exit Code: $METHOD3_EXIT_CODE"
echo ""

# Generate summary report
echo -e "${BLUE}📊 Test Execution Summary${NC}"
echo "=" * 60
echo "Method 1 (GlobalEnums GdUnit4): Exit Code $METHOD1_EXIT_CODE"
echo "Method 2 (Custom Runner): Exit Code $METHOD2_EXIT_CODE"
echo "Method 3 (Migration Suite): Exit Code $METHOD3_EXIT_CODE"
echo ""

# Determine overall result
OVERALL_SUCCESS=true
TOTAL_FAILURES=0

if [ $METHOD1_EXIT_CODE -ne 0 ]; then
    OVERALL_SUCCESS=false
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
    echo -e "${RED}❌ Method 1 failed${NC}"
else
    echo -e "${GREEN}✅ Method 1 passed${NC}"
fi

if [ $METHOD2_EXIT_CODE -ne 0 ]; then
    OVERALL_SUCCESS=false
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
    echo -e "${RED}❌ Method 2 failed${NC}"
else
    echo -e "${GREEN}✅ Method 2 passed${NC}"
fi

if [ $METHOD3_EXIT_CODE -ne 0 ]; then
    OVERALL_SUCCESS=false
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
    echo -e "${RED}❌ Method 3 failed${NC}"
else
    echo -e "${GREEN}✅ Method 3 passed${NC}"
fi

echo ""

# Final status and recommendations
if [ "$OVERALL_SUCCESS" = true ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED SUCCESSFULLY!${NC}"
    echo ""
    echo "Recommendations:"
    echo "  🚀 Enum migration system is ready for production"
    echo "  📈 Consider running performance benchmarks"
    echo "  🔄 System can handle singleton simulation properly"
    exit 0
else
    echo -e "${RED}❌ $TOTAL_FAILURES TEST METHOD(S) FAILED${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  🔍 Review test output logs in $REPORT_DIR/"
    echo "  🛠️ Check singleton simulation setup"
    echo "  📋 Verify GdUnit4 configuration"
    echo "  🔧 Ensure all test dependencies are available"
    
    # Show recent log content for debugging
    echo ""
    echo -e "${YELLOW}📄 Recent log content (last 20 lines):${NC}"
    echo "Method 1 output:"
    tail -n 20 "$REPORT_DIR/test_output_method1.log" | head -n 10
    echo ""
    echo "Method 2 output:"
    tail -n 20 "$REPORT_DIR/test_output_method2.log" | head -n 10
    echo ""
    echo "Method 3 output:"
    tail -n 20 "$REPORT_DIR/test_output_method3.log" | head -n 10
    
    exit 1
fi