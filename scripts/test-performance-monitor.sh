#!/bin/bash

# Five Parsecs Campaign Manager - Test Performance Monitoring Script
# Tracks test execution performance and generates trend reports

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORTS_DIR="$PROJECT_ROOT/reports/performance"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_ONLY=$(date +%Y%m%d)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}📊 Five Parsecs Test Performance Monitor${NC}"
echo "=========================================="
echo "Timestamp: $(date)"
echo "Reports Directory: $REPORTS_DIR"
echo ""

# Ensure reports directory exists
mkdir -p "$REPORTS_DIR"
cd "$PROJECT_ROOT"

# Initialize performance data file
PERF_DATA="$REPORTS_DIR/performance_${TIMESTAMP}.json"
DAILY_SUMMARY="$REPORTS_DIR/daily_summary_${DATE_ONLY}.json"
TREND_DATA="$REPORTS_DIR/trend_history.jsonl"

# Function to record metric
record_metric() {
    local category="$1"
    local metric_name="$2"
    local value="$3"
    local unit="$4"
    
    echo "{\"timestamp\":\"$(date -Iseconds)\",\"category\":\"$category\",\"metric\":\"$metric_name\",\"value\":$value,\"unit\":\"$unit\"}" >> "$PERF_DATA"
}

# Function to run timed test category
run_timed_test() {
    local category="$1"
    local test_command="$2"
    local description="$3"
    local timeout_seconds="$4"
    
    echo -e "${BLUE}🧪 Running $category: $description${NC}"
    
    local start_time=$(date +%s.%N)
    local start_time_ms=$(date +%s%3N)
    
    # Run test with timeout
    if timeout $timeout_seconds bash -c "$test_command" >/dev/null 2>&1; then
        local end_time=$(date +%s.%N)
        local end_time_ms=$(date +%s%3N)
        local duration=$(echo "$end_time - $start_time" | bc)
        local duration_ms=$((end_time_ms - start_time_ms))
        
        echo -e "${GREEN}  ✅ Completed in ${duration}s (${duration_ms}ms)${NC}"
        
        # Record metrics
        record_metric "$category" "execution_time_seconds" "$duration" "seconds"
        record_metric "$category" "execution_time_ms" "$duration_ms" "milliseconds"
        
        return 0
    else
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        
        echo -e "${RED}  ❌ Failed or timed out after ${duration}s${NC}"
        
        # Record failure
        record_metric "$category" "execution_time_seconds" "$timeout_seconds" "seconds"
        record_metric "$category" "failed" "1" "boolean"
        
        return 1
    fi
}

# Test performance measurement
echo -e "${BLUE}📋 PERFORMANCE MEASUREMENT PHASE${NC}"
echo "=================================="

# Track overall memory usage
initial_memory=$(free -m | awk 'NR==2{printf "%.0f", $3}' 2>/dev/null || echo "0")
record_metric "system" "initial_memory_mb" "$initial_memory" "megabytes"

# Test Categories with Performance Measurement

echo -e "${PURPLE}Category 1: Unit Tests${NC}"
run_timed_test "unit_tests" \
    '"/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/test_global_enums_unit.gd --ignoreHeadlessMode -c' \
    "GlobalEnums wrapper unit tests" \
    30

echo -e "${PURPLE}Category 2: Integration Tests${NC}"
if [ -f "tests/integration/test_campaign_initialization.gd" ]; then
    run_timed_test "integration_tests" \
        '"/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/integration/test_campaign_initialization.gd --ignoreHeadlessMode -c' \
        "Campaign initialization integration" \
        90
else
    echo -e "${YELLOW}  ⚠️ Skipped - file not found${NC}"
    record_metric "integration_tests" "skipped" "1" "boolean"
fi

echo -e "${PURPLE}Category 3: End-to-End Tests${NC}"
if [ -f "tests/e2e/test_enum_migration_e2e.gd" ]; then
    run_timed_test "e2e_tests" \
        '"/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/e2e/test_enum_migration_e2e.gd --ignoreHeadlessMode -c' \
        "End-to-end enum migration" \
        180
else
    echo -e "${YELLOW}  ⚠️ Skipped - file not found${NC}"
    record_metric "e2e_tests" "skipped" "1" "boolean"
fi

echo -e "${PURPLE}Category 4: Performance Benchmark${NC}"
if [ -f "simple_enum_test.gd" ]; then
    run_timed_test "performance_benchmark" \
        '"/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe" --headless --path . --script simple_enum_test.gd --quit' \
        "Enum performance benchmark" \
        60
else
    echo -e "${YELLOW}  ⚠️ Skipped - file not found${NC}"
    record_metric "performance_benchmark" "skipped" "1" "boolean"
fi

echo -e "${PURPLE}Category 5: Full Test Suite${NC}"
if [ -f "scripts/run_comprehensive_test_suite.sh" ]; then
    # Run comprehensive test suite and capture detailed timing
    full_suite_start=$(date +%s.%N)
    
    if timeout 600 ./scripts/run_comprehensive_test_suite.sh >/dev/null 2>&1; then
        full_suite_end=$(date +%s.%N)
        full_suite_duration=$(echo "$full_suite_end - $full_suite_start" | bc)
        
        echo -e "${GREEN}  ✅ Full suite completed in ${full_suite_duration}s${NC}"
        record_metric "full_test_suite" "execution_time_seconds" "$full_suite_duration" "seconds"
    else
        full_suite_end=$(date +%s.%N)
        full_suite_duration=$(echo "$full_suite_end - $full_suite_start" | bc)
        
        echo -e "${RED}  ❌ Full suite failed or timed out after ${full_suite_duration}s${NC}"
        record_metric "full_test_suite" "execution_time_seconds" "600" "seconds"
        record_metric "full_test_suite" "failed" "1" "boolean"
    fi
else
    echo -e "${YELLOW}  ⚠️ Skipped - script not found${NC}"
    record_metric "full_test_suite" "skipped" "1" "boolean"
fi

# Final memory measurement
final_memory=$(free -m | awk 'NR==2{printf "%.0f", $3}' 2>/dev/null || echo "0")
memory_delta=$((final_memory - initial_memory))
record_metric "system" "final_memory_mb" "$final_memory" "megabytes"
record_metric "system" "memory_delta_mb" "$memory_delta" "megabytes"

echo ""
echo -e "${BLUE}📊 PERFORMANCE ANALYSIS${NC}"
echo "======================="

# Analyze performance data
echo "Performance Data File: $PERF_DATA"

# Calculate summary statistics
total_tests=$(grep -c "execution_time_seconds" "$PERF_DATA" 2>/dev/null || echo "0")
failed_tests=$(grep -c "\"failed\"" "$PERF_DATA" 2>/dev/null || echo "0")
success_rate=$(echo "scale=2; ($total_tests - $failed_tests) * 100 / $total_tests" | bc 2>/dev/null || echo "100")

echo "📈 Summary Statistics:"
echo "  • Total test categories: $total_tests"
echo "  • Failed categories: $failed_tests"
echo "  • Success rate: ${success_rate}%"
echo "  • Memory usage change: ${memory_delta}MB"

# Performance targets and alerts
echo ""
echo "🎯 Performance Targets vs Actual:"

# Define performance targets (in seconds)
declare -A targets=(
    ["unit_tests"]=10
    ["integration_tests"]=60
    ["e2e_tests"]=300
    ["performance_benchmark"]=60
    ["full_test_suite"]=600
)

# Check each category against targets
for category in "${!targets[@]}"; do
    target=${targets[$category]}
    actual=$(grep "\"category\":\"$category\".*\"execution_time_seconds\"" "$PERF_DATA" | head -1 | sed 's/.*"value":\([0-9.]*\).*/\1/' 2>/dev/null || echo "0")
    
    if (( $(echo "$actual > 0" | bc -l) )); then
        percentage=$(echo "scale=0; $actual * 100 / $target" | bc)
        
        if (( $(echo "$actual <= $target" | bc -l) )); then
            echo -e "  • $category: ${GREEN}${actual}s ≤ ${target}s (${percentage}%)${NC}"
        elif (( $(echo "$actual <= $target * 1.5" | bc -l) )); then
            echo -e "  • $category: ${YELLOW}${actual}s > ${target}s (${percentage}%) ⚠️${NC}"
        else
            echo -e "  • $category: ${RED}${actual}s >> ${target}s (${percentage}%) ❌${NC}"
        fi
    else
        echo -e "  • $category: ${YELLOW}Skipped or failed${NC}"
    fi
done

# Generate daily summary
echo ""
echo -e "${BLUE}📋 DAILY SUMMARY GENERATION${NC}"

# Create daily summary JSON
cat > "$DAILY_SUMMARY" << EOF
{
  "date": "$DATE_ONLY",
  "timestamp": "$(date -Iseconds)",
  "summary": {
    "total_categories": $total_tests,
    "failed_categories": $failed_tests,
    "success_rate": $success_rate,
    "memory_delta_mb": $memory_delta
  },
  "performance": {
EOF

# Add performance data for each category
first=true
for category in "${!targets[@]}"; do
    target=${targets[$category]}
    actual=$(grep "\"category\":\"$category\".*\"execution_time_seconds\"" "$PERF_DATA" | head -1 | sed 's/.*"value":\([0-9.]*\).*/\1/' 2>/dev/null || echo "0")
    
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$DAILY_SUMMARY"
    fi
    
    echo -n "    \"$category\": {\"target\": $target, \"actual\": $actual}" >> "$DAILY_SUMMARY"
done

cat >> "$DAILY_SUMMARY" << EOF

  },
  "raw_data_file": "performance_${TIMESTAMP}.json"
}
EOF

# Append to trend history
echo "{\"date\":\"$DATE_ONLY\",\"timestamp\":\"$(date -Iseconds)\",\"success_rate\":$success_rate,\"total_categories\":$total_tests,\"memory_delta\":$memory_delta}" >> "$TREND_DATA"

echo "Daily summary: $DAILY_SUMMARY"
echo "Trend data: $TREND_DATA"

# Performance alerts
echo ""
echo -e "${BLUE}🚨 PERFORMANCE ALERTS${NC}"

alerts_triggered=false

# Check for critical performance issues
for category in "${!targets[@]}"; do
    target=${targets[$category]}
    actual=$(grep "\"category\":\"$category\".*\"execution_time_seconds\"" "$PERF_DATA" | head -1 | sed 's/.*"value":\([0-9.]*\).*/\1/' 2>/dev/null || echo "0")
    
    if (( $(echo "$actual > $target * 2" | bc -l) )); then
        echo -e "${RED}❌ CRITICAL: $category exceeds target by 100% ($actual s vs $target s)${NC}"
        alerts_triggered=true
    elif (( $(echo "$actual > $target * 1.5" | bc -l) )); then
        echo -e "${YELLOW}⚠️  WARNING: $category exceeds target by 50% ($actual s vs $target s)${NC}"
        alerts_triggered=true
    fi
done

# Check success rate
if (( $(echo "$success_rate < 80" | bc -l) )); then
    echo -e "${RED}❌ CRITICAL: Success rate below 80% ($success_rate%)${NC}"
    alerts_triggered=true
elif (( $(echo "$success_rate < 90" | bc -l) )); then
    echo -e "${YELLOW}⚠️  WARNING: Success rate below 90% ($success_rate%)${NC}"
    alerts_triggered=true
fi

# Check memory usage
if [ "$memory_delta" -gt 100 ]; then
    echo -e "${RED}❌ CRITICAL: Memory usage increased by ${memory_delta}MB (>100MB threshold)${NC}"
    alerts_triggered=true
elif [ "$memory_delta" -gt 50 ]; then
    echo -e "${YELLOW}⚠️  WARNING: Memory usage increased by ${memory_delta}MB (>50MB threshold)${NC}"
    alerts_triggered=true
fi

if [ "$alerts_triggered" = false ]; then
    echo -e "${GREEN}✅ No performance alerts triggered${NC}"
fi

# Trend analysis (if history exists)
echo ""
echo -e "${BLUE}📈 TREND ANALYSIS${NC}"

if [ -f "$TREND_DATA" ] && [ -s "$TREND_DATA" ]; then
    trend_lines=$(wc -l < "$TREND_DATA")
    
    if [ "$trend_lines" -gt 1 ]; then
        echo "Analyzing trends over $trend_lines data points..."
        
        # Get last 7 days of data for trend analysis
        last_week_data=$(tail -n 7 "$TREND_DATA" 2>/dev/null)
        
        if [ -n "$last_week_data" ]; then
            avg_success_rate=$(echo "$last_week_data" | jq -r '.success_rate' | awk '{sum+=$1} END {printf "%.1f", sum/NR}' 2>/dev/null || echo "N/A")
            avg_memory_delta=$(echo "$last_week_data" | jq -r '.memory_delta' | awk '{sum+=$1} END {printf "%.0f", sum/NR}' 2>/dev/null || echo "N/A")
            
            echo "📊 7-day averages:"
            echo "  • Success rate: ${avg_success_rate}%"
            echo "  • Memory delta: ${avg_memory_delta}MB"
            
            # Compare current to average
            if [ "$avg_success_rate" != "N/A" ] && (( $(echo "$success_rate < $avg_success_rate - 5" | bc -l) )); then
                echo -e "${YELLOW}  ⚠️ Current success rate is 5% below 7-day average${NC}"
            fi
        fi
    else
        echo "Insufficient historical data for trend analysis (need >1 data point)"
    fi
else
    echo "No historical trend data available"
fi

echo ""
echo -e "${BLUE}📋 RECOMMENDATIONS${NC}"
echo "=================="

# Generate actionable recommendations
if (( $(echo "$success_rate < 90" | bc -l) )); then
    echo "🔧 Low success rate detected:"
    echo "  • Review failing test categories"
    echo "  • Check for environmental issues"
    echo "  • Consider test isolation improvements"
fi

# Performance recommendations
slow_categories=()
for category in "${!targets[@]}"; do
    target=${targets[$category]}
    actual=$(grep "\"category\":\"$category\".*\"execution_time_seconds\"" "$PERF_DATA" | head -1 | sed 's/.*"value":\([0-9.]*\).*/\1/' 2>/dev/null || echo "0")
    
    if (( $(echo "$actual > $target * 1.2" | bc -l) )); then
        slow_categories+=("$category")
    fi
done

if [ ${#slow_categories[@]} -gt 0 ]; then
    echo "⚡ Performance optimization needed:"
    for category in "${slow_categories[@]}"; do
        echo "  • Optimize $category test execution"
    done
    echo "  • Consider parallel execution"
    echo "  • Review test data and setup costs"
fi

if [ "$memory_delta" -gt 25 ]; then
    echo "🧠 Memory optimization needed:"
    echo "  • Review test cleanup procedures"
    echo "  • Check for memory leaks in test code"
    echo "  • Consider smaller test data sets"
fi

echo ""
echo -e "${GREEN}🎉 Performance monitoring completed!${NC}"
echo "📄 Reports generated:"
echo "  • Performance data: $PERF_DATA"
echo "  • Daily summary: $DAILY_SUMMARY" 
echo "  • Trend history: $TREND_DATA"
echo ""
echo "💡 Next steps:"
echo "  • Review performance alerts and recommendations"
echo "  • Set up automated monitoring schedule"
echo "  • Integrate with CI/CD pipeline for regression detection"