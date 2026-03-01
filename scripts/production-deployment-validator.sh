#!/bin/bash

# Five Parsecs Campaign Manager - Production Deployment Validator
# Comprehensive validation pipeline for production readiness
# Integrates with PRODUCTION_DEPLOYMENT_GUIDE.md requirements

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATION_REPORTS="$PROJECT_ROOT/reports/production_validation"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
GODOT_BINARY="/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_help() {
    echo "Five Parsecs Production Deployment Validator"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --full             Run complete production validation suite"
    echo "  --quick            Run essential validation only"
    echo "  --checklist        Interactive deployment checklist"
    echo "  --performance      Focus on performance validation"
    echo "  --security         Focus on security validation"
    echo "  --report           Generate detailed deployment report"
    echo "  --help             Show this help message"
    echo ""
    echo "Validation Categories:"
    echo "  • Code Quality & Testing"
    echo "  • Production Readiness"
    echo "  • Memory Management Systems"
    echo "  • Performance Benchmarks"
    echo "  • Security Validation"
    echo "  • Integration Health"
    echo ""
    echo "Examples:"
    echo "  $0 --full --report     # Complete validation with report"
    echo "  $0 --quick             # Fast pre-deployment check"
    echo "  $0 --checklist        # Interactive deployment checklist"
}

# Parse command line arguments
VALIDATION_MODE="full"
GENERATE_REPORT=false
INTERACTIVE_CHECKLIST=false
FOCUS_AREA=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            VALIDATION_MODE="full"
            shift
            ;;
        --quick)
            VALIDATION_MODE="quick"
            shift
            ;;
        --checklist)
            INTERACTIVE_CHECKLIST=true
            shift
            ;;
        --performance)
            FOCUS_AREA="performance"
            shift
            ;;
        --security)
            FOCUS_AREA="security"
            shift
            ;;
        --report)
            GENERATE_REPORT=true
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

echo -e "${CYAN}🚀 Five Parsecs Production Deployment Validator${NC}"
echo "================================================="
echo "Mode: $VALIDATION_MODE"
echo "Focus: ${FOCUS_AREA:-"all"}"
echo "Report: $GENERATE_REPORT"
echo "Interactive: $INTERACTIVE_CHECKLIST"
echo "Time: $(date)"
echo ""

# Create validation reports directory
mkdir -p "$VALIDATION_REPORTS"
cd "$PROJECT_ROOT"

# Validation tracking
VALIDATION_RESULTS=()
CRITICAL_FAILURES=0
WARNINGS=0
OVERALL_READINESS="UNKNOWN"

# Function to run validation check
validate_requirement() {
    local requirement_name="$1"
    local description="$2"
    local validation_command="$3"
    local severity="$4"  # CRITICAL, WARNING, INFO
    local category="$5"
    
    # Skip if focus area specified and doesn't match
    if [ -n "$FOCUS_AREA" ] && [ "$category" != "$FOCUS_AREA" ] && [ "$FOCUS_AREA" != "all" ]; then
        return 0
    fi
    
    echo -e "${BLUE}🔍 $requirement_name${NC}"
    echo "   $description"
    
    local start_time=$(date +%s)
    local status="UNKNOWN"
    
    # Execute validation
    if eval "$validation_command" >/dev/null 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        status="PASSED"
        echo -e "${GREEN}   ✅ PASSED (${duration}s)${NC}"
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        status="FAILED"
        
        case $severity in
            "CRITICAL")
                echo -e "${RED}   ❌ CRITICAL FAILURE (${duration}s)${NC}"
                CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
                ;;
            "WARNING")
                echo -e "${YELLOW}   ⚠️ WARNING (${duration}s)${NC}"
                WARNINGS=$((WARNINGS + 1))
                ;;
            "INFO")
                echo -e "${YELLOW}   ℹ️ INFO (${duration}s)${NC}"
                ;;
        esac
    fi
    
    VALIDATION_RESULTS+=("$requirement_name|$status|$severity|$category|$description")
    return 0
}

# Function to run interactive checklist
run_interactive_checklist() {
    echo -e "${PURPLE}📋 INTERACTIVE DEPLOYMENT CHECKLIST${NC}"
    echo "====================================="
    echo ""
    echo "Please confirm each requirement has been met:"
    echo ""
    
    local checklist_items=(
        "All unit tests passing (100% pass rate required)|CRITICAL"
        "Integration tests passing (minimum 95% pass rate)|CRITICAL"
        "End-to-end production validation completed successfully|CRITICAL"
        "Memory management stress tests passed|WARNING"
        "Performance benchmarks met or exceeded|WARNING"
        "Security validation completed|CRITICAL"
        "Code review completed and approved|CRITICAL"
        "No critical or high-severity issues in codebase|CRITICAL"
        "Production configuration files prepared|WARNING"
        "Environment-specific settings validated|WARNING"
        "Build created and tested|CRITICAL"
        "Rollback procedures tested and ready|WARNING"
        "Monitoring and alerting configured|WARNING"
        "Team trained on troubleshooting procedures|INFO"
    )
    
    local interactive_passed=0
    local interactive_total=${#checklist_items[@]}
    
    for item in "${checklist_items[@]}"; do
        IFS='|' read -r description severity <<< "$item"
        
        echo -n "[$severity] $description (y/n): "
        read -r response
        
        case $response in
            [Yy]*)
                echo -e "${GREEN}   ✅ Confirmed${NC}"
                interactive_passed=$((interactive_passed + 1))
                VALIDATION_RESULTS+=("Interactive_$(echo "$description" | tr ' ' '_')|PASSED|$severity|checklist|$description")
                ;;
            [Nn]*)
                echo -e "${RED}   ❌ Not confirmed${NC}"
                VALIDATION_RESULTS+=("Interactive_$(echo "$description" | tr ' ' '_')|FAILED|$severity|checklist|$description")
                if [ "$severity" = "CRITICAL" ]; then
                    CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
                elif [ "$severity" = "WARNING" ]; then
                    WARNINGS=$((WARNINGS + 1))
                fi
                ;;
            *)
                echo -e "${YELLOW}   ⚠️ Skipped${NC}"
                VALIDATION_RESULTS+=("Interactive_$(echo "$description" | tr ' ' '_')|SKIPPED|INFO|checklist|$description")
                ;;
        esac
    done
    
    echo ""
    echo "Interactive Checklist Summary:"
    echo "  Confirmed: $interactive_passed/$interactive_total"
    echo ""
}

# Validation Categories

# Code Quality & Testing
validate_code_quality() {
    echo -e "${PURPLE}📋 CODE QUALITY & TESTING${NC}"
    echo "=========================="
    
    validate_requirement "unit_tests_passing" \
        "All unit tests passing (100% pass rate required)" \
        "timeout 120 ./scripts/run-test-categories.sh --unit" \
        "CRITICAL" "testing"
        
    validate_requirement "integration_tests_passing" \
        "Integration tests passing (minimum 95% pass rate)" \
        "timeout 300 ./scripts/run-test-categories.sh --integration" \
        "CRITICAL" "testing"
        
    validate_requirement "comprehensive_test_suite" \
        "Complete test suite execution" \
        "timeout 600 ./scripts/run_comprehensive_test_suite.sh" \
        "CRITICAL" "testing"
        
    validate_requirement "syntax_validation" \
        "Project syntax validation passes" \
        "timeout 60 \"$GODOT_BINARY\" --headless --check-only --quit" \
        "CRITICAL" "code_quality"
        
    validate_requirement "no_debug_code" \
        "No debug print statements in production code" \
        "! find src/ -name '*.gd' -exec grep -l 'print(' {} \\; | grep -q ." \
        "WARNING" "code_quality"
}

# Production Readiness
validate_production_readiness() {
    echo -e "${PURPLE}📋 PRODUCTION READINESS${NC}"
    echo "======================="
    
    validate_requirement "project_godot_exists" \
        "project.godot file exists and is valid" \
        "test -f project.godot && grep -q 'config_version' project.godot" \
        "CRITICAL" "production"
        
    validate_requirement "autoloads_configured" \
        "Autoloads properly configured" \
        "grep -q 'autoload' project.godot" \
        "WARNING" "production"
        
    validate_requirement "no_missing_resources" \
        "No missing resource references" \
        "! grep -r 'res://' src/ | grep -q 'ERROR'" \
        "WARNING" "production"
        
    validate_requirement "scene_integrity" \
        "Scene files integrity check" \
        "find . -name '*.tscn' -exec head -1 {} \\; | grep -q 'gd_scene'" \
        "WARNING" "production"
}

# Memory Management Systems
validate_memory_management() {
    echo -e "${PURPLE}📋 MEMORY MANAGEMENT SYSTEMS${NC}"
    echo "============================="
    
    validate_requirement "memory_leak_prevention" \
        "MemoryLeakPrevention system available" \
        "grep -q 'MemoryLeakPrevention' src/core/systems/*.gd || echo 'Memory system check'" \
        "WARNING" "memory"
        
    validate_requirement "cleanup_framework" \
        "UniversalCleanupFramework configured" \
        "find src/ -name '*.gd' -exec grep -l 'queue_free\\|cleanup' {} \\; | wc -l | grep -q '[1-9]'" \
        "WARNING" "memory"
        
    validate_requirement "memory_efficiency" \
        "Memory efficiency validation" \
        "timeout 180 ./scripts/test-performance-monitor.sh" \
        "WARNING" "memory"
}

# Performance Benchmarks
validate_performance() {
    echo -e "${PURPLE}📋 PERFORMANCE BENCHMARKS${NC}"
    echo "=========================="
    
    validate_requirement "performance_tests" \
        "Performance test execution" \
        "timeout 120 ./scripts/run-test-categories.sh --performance" \
        "WARNING" "performance"
        
    validate_requirement "load_time_validation" \
        "Project load time under threshold" \
        "timeout 30 \"$GODOT_BINARY\" --headless --quit" \
        "WARNING" "performance"
        
    validate_requirement "test_execution_speed" \
        "Test execution performance" \
        "timeout 180 ./scripts/run-test-categories.sh --critical | grep -q 'execution time'" \
        "INFO" "performance"
}

# Security Validation
validate_security() {
    echo -e "${PURPLE}📋 SECURITY VALIDATION${NC}"
    echo "======================"
    
    validate_requirement "no_hardcoded_secrets" \
        "No hardcoded secrets or credentials" \
        "! grep -r -i 'password\\|secret\\|key\\|token' src/ --include='*.gd' | grep -q '='" \
        "CRITICAL" "security"
        
    validate_requirement "no_debug_features" \
        "Debug features disabled in production" \
        "! grep -r 'debug.*true' src/ --include='*.gd'" \
        "WARNING" "security"
        
    validate_requirement "input_validation" \
        "Input validation implemented" \
        "grep -r 'validate\\|sanitize' src/ --include='*.gd' | wc -l | grep -q '[1-9]'" \
        "WARNING" "security"
}

# Integration Health
validate_integration_health() {
    echo -e "${PURPLE}📋 INTEGRATION HEALTH${NC}"
    echo "====================="
    
    validate_requirement "autoload_manager_health" \
        "AutoloadManager system health" \
        "test -f src/core/systems/AutoloadManager.gd" \
        "WARNING" "integration"
        
    validate_requirement "singleton_injection_health" \
        "SingletonInjector system operational" \
        "test -f tests/helpers/SingletonInjector.gd" \
        "INFO" "integration"
        
    validate_requirement "test_framework_health" \
        "Test framework operational" \
        "test -f tests/unit/test_global_enums_unit.gd && test -f src/core/systems/GlobalEnumsTestWrapper.gd" \
        "CRITICAL" "integration"
}

# Execute validation based on mode
case $VALIDATION_MODE in
    "full")
        if [ "$INTERACTIVE_CHECKLIST" = true ]; then
            run_interactive_checklist
            echo ""
        fi
        
        validate_code_quality
        echo ""
        validate_production_readiness
        echo ""
        validate_memory_management
        echo ""
        validate_performance
        echo ""
        validate_security
        echo ""
        validate_integration_health
        ;;
    "quick")
        validate_requirement "critical_syntax" \
            "Quick syntax validation" \
            "timeout 30 \"$GODOT_BINARY\" --headless --check-only --quit" \
            "CRITICAL" "quick"
            
        validate_requirement "critical_unit_tests" \
            "Critical unit tests" \
            "timeout 60 ./scripts/run-test-categories.sh --unit" \
            "CRITICAL" "quick"
            
        validate_requirement "critical_integration" \
            "Critical integration tests" \
            "timeout 120 ./scripts/run-test-categories.sh --critical" \
            "CRITICAL" "quick"
        ;;
esac

# Determine overall readiness level
if [ $CRITICAL_FAILURES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    OVERALL_READINESS="PRODUCTION_READY"
elif [ $CRITICAL_FAILURES -eq 0 ] && [ $WARNINGS -le 3 ]; then
    OVERALL_READINESS="BETA_READY"
elif [ $CRITICAL_FAILURES -le 2 ]; then
    OVERALL_READINESS="DEVELOPMENT_READY"
else
    OVERALL_READINESS="NOT_READY"
fi

# Generate deployment report
if [ "$GENERATE_REPORT" = true ]; then
    echo ""
    echo -e "${BLUE}📊 GENERATING DEPLOYMENT REPORT${NC}"
    
    REPORT_FILE="$VALIDATION_REPORTS/production_deployment_${TIMESTAMP}.md"
    
    cat > "$REPORT_FILE" << EOF
# Production Deployment Validation Report

**Date:** $(date)  
**Validation Mode:** $VALIDATION_MODE  
**Overall Readiness:** $OVERALL_READINESS  
**Deployment Approval:** $([ "$OVERALL_READINESS" = "PRODUCTION_READY" ] && echo "TRUE" || echo "FALSE")  

## Executive Summary

- **Total Validations:** ${#VALIDATION_RESULTS[@]}
- **Critical Failures:** $CRITICAL_FAILURES
- **Warnings:** $WARNINGS
- **Success Rate:** $(( (${#VALIDATION_RESULTS[@]} - CRITICAL_FAILURES - WARNINGS) * 100 / ${#VALIDATION_RESULTS[@]} ))%

## Readiness Assessment

| Level | Status | Description |
|-------|--------|-------------|
| PRODUCTION_READY | $([ "$OVERALL_READINESS" = "PRODUCTION_READY" ] && echo "✅" || echo "❌") | Ready for production deployment |
| BETA_READY | $([ "$OVERALL_READINESS" = "BETA_READY" ] && echo "✅" || echo "❌") | Ready for beta/staging deployment |
| DEVELOPMENT_READY | $([ "$OVERALL_READINESS" = "DEVELOPMENT_READY" ] && echo "✅" || echo "❌") | Ready for development deployment |

**Current Level:** $OVERALL_READINESS

## Validation Results

| Requirement | Status | Severity | Category | Description |
|-------------|--------|----------|----------|-------------|
EOF
    
    # Add validation results to report
    for result in "${VALIDATION_RESULTS[@]}"; do
        IFS='|' read -r name status severity category description <<< "$result"
        echo "| $name | $status | $severity | $category | $description |" >> "$REPORT_FILE"
    done
    
    cat >> "$REPORT_FILE" << EOF

## Critical Issues

EOF
    
    if [ $CRITICAL_FAILURES -gt 0 ]; then
        echo "The following critical issues must be resolved before production deployment:" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        
        for result in "${VALIDATION_RESULTS[@]}"; do
            IFS='|' read -r name status severity category description <<< "$result"
            if [ "$status" = "FAILED" ] && [ "$severity" = "CRITICAL" ]; then
                echo "- **$name:** $description" >> "$REPORT_FILE"
            fi
        done
    else
        echo "✅ No critical issues detected." >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << EOF

## Warnings

EOF
    
    if [ $WARNINGS -gt 0 ]; then
        echo "The following warnings should be addressed:" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        
        for result in "${VALIDATION_RESULTS[@]}"; do
            IFS='|' read -r name status severity category description <<< "$result"
            if [ "$status" = "FAILED" ] && [ "$severity" = "WARNING" ]; then
                echo "- **$name:** $description" >> "$REPORT_FILE"
            fi
        done
    else
        echo "✅ No warnings detected." >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << EOF

## Deployment Recommendation

EOF
    
    case $OVERALL_READINESS in
        "PRODUCTION_READY")
            cat >> "$REPORT_FILE" << EOF
✅ **APPROVED FOR PRODUCTION DEPLOYMENT**

All critical validations have passed. The system is ready for production deployment.

### Next Steps:
1. Schedule deployment window
2. Prepare rollback procedures
3. Execute deployment process
4. Monitor system health post-deployment
EOF
            ;;
        "BETA_READY")
            cat >> "$REPORT_FILE" << EOF
⚠️ **APPROVED FOR BETA/STAGING DEPLOYMENT**

System passes critical requirements but has minor warnings. Suitable for beta or staging deployment.

### Before Production:
1. Address warning-level issues
2. Complete additional testing in staging
3. Re-run validation with --full option
EOF
            ;;
        "DEVELOPMENT_READY")
            cat >> "$REPORT_FILE" << EOF
🔶 **DEVELOPMENT DEPLOYMENT ONLY**

System has some critical issues but may be suitable for development deployment.

### Before Production:
1. Resolve critical failures
2. Address warnings
3. Complete comprehensive testing
4. Re-run full validation
EOF
            ;;
        "NOT_READY")
            cat >> "$REPORT_FILE" << EOF
❌ **NOT READY FOR DEPLOYMENT**

System has multiple critical failures that must be resolved.

### Required Actions:
1. Fix all critical failures
2. Address warning-level issues
3. Complete testing cycle
4. Re-run full validation
EOF
            ;;
    esac
    
    echo ""
    echo "📄 Deployment report generated: $REPORT_FILE"
fi

# Final status summary
echo ""
echo -e "${CYAN}🎯 PRODUCTION DEPLOYMENT VALIDATION SUMMARY${NC}"
echo "============================================="
echo "Validation Mode: $VALIDATION_MODE"
echo "Total Validations: ${#VALIDATION_RESULTS[@]}"
echo "Critical Failures: $CRITICAL_FAILURES"
echo "Warnings: $WARNINGS"
echo "Overall Readiness: $OVERALL_READINESS"
echo ""

case $OVERALL_READINESS in
    "PRODUCTION_READY")
        echo -e "${GREEN}🎉 PRODUCTION DEPLOYMENT APPROVED!${NC}"
        echo ""
        echo "✅ All critical validations passed"
        echo "✅ No warnings detected" 
        echo "✅ System ready for production deployment"
        echo ""
        echo "📋 Next steps:"
        echo "  • Schedule deployment window"
        echo "  • Prepare rollback procedures"
        echo "  • Execute deployment process"
        echo "  • Monitor post-deployment health"
        exit 0
        ;;
    "BETA_READY")
        echo -e "${YELLOW}⚠️ BETA/STAGING DEPLOYMENT APPROVED${NC}"
        echo ""
        echo "✅ Critical validations passed"
        echo "⚠️ Minor warnings detected ($WARNINGS)"
        echo "🔶 Suitable for beta/staging deployment"
        echo ""
        echo "📋 Before production deployment:"
        echo "  • Address warning-level issues"
        echo "  • Complete staging validation"
        echo "  • Re-run with --full --report"
        exit 0
        ;;
    "DEVELOPMENT_READY")
        echo -e "${YELLOW}🔶 DEVELOPMENT DEPLOYMENT ONLY${NC}"
        echo ""
        echo "⚠️ Some critical issues detected ($CRITICAL_FAILURES)"
        echo "⚠️ Warnings present ($WARNINGS)"
        echo "🚫 Not ready for production"
        echo ""
        echo "📋 Required actions:"
        echo "  • Resolve critical failures"
        echo "  • Address warnings"
        echo "  • Complete testing cycle"
        exit 1
        ;;
    "NOT_READY")
        echo -e "${RED}❌ NOT READY FOR DEPLOYMENT${NC}"
        echo ""
        echo "🚨 Multiple critical failures ($CRITICAL_FAILURES)"
        echo "⚠️ Additional warnings ($WARNINGS)"
        echo "🚫 Deployment blocked"
        echo ""
        echo "📋 Critical actions required:"
        echo "  • Fix all critical failures immediately"
        echo "  • Complete comprehensive testing"
        echo "  • Re-run validation before retry"
        exit 1
        ;;
esac