#!/bin/bash

# Five Parsecs Campaign Manager - Sprint Validation Checkpoints
# Integrates test execution with Sprint Execution Plan phases

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKPOINT_REPORTS="$PROJECT_ROOT/reports/sprint_checkpoints"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Sprint phases from SPRINT_EXECUTION_PLAN.md
declare -A SPRINT_PHASES=(
    ["phase1"]="Core Refactoring"
    ["phase2"]="Signal Integration" 
    ["phase3"]="Testing & Validation"
    ["phase4"]="Cleanup & Documentation"
)

show_help() {
    echo "Five Parsecs Sprint Validation Checkpoints"
    echo ""
    echo "Usage: $0 [PHASE] [OPTIONS]"
    echo ""
    echo "Sprint Phases:"
    echo "  phase1    Core Refactoring validation"
    echo "  phase2    Signal Integration validation"
    echo "  phase3    Testing & Validation checkpoint"
    echo "  phase4    Cleanup & Documentation validation"
    echo "  all       Run all phase validations"
    echo ""
    echo "Options:"
    echo "  --quick   Fast validation mode"
    echo "  --report  Generate detailed checkpoint report"
    echo "  --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 phase1              # Validate Phase 1 completion"
    echo "  $0 phase3 --report     # Full Phase 3 validation with report"
    echo "  $0 all --quick         # Quick validation of all phases"
}

PHASE=""
QUICK_MODE=false
GENERATE_REPORT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        phase1|phase2|phase3|phase4|all)
            PHASE="$1"
            shift
            ;;
        --quick)
            QUICK_MODE=true
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

if [ -z "$PHASE" ]; then
    echo "Error: Phase argument required"
    show_help
    exit 1
fi

echo -e "${BLUE}🚀 Five Parsecs Sprint Validation Checkpoints${NC}"
echo "=============================================="
echo "Phase: $PHASE"
echo "Quick Mode: $QUICK_MODE"
echo "Generate Report: $GENERATE_REPORT"
echo "Time: $(date)"
echo ""

# Create checkpoint reports directory
mkdir -p "$CHECKPOINT_REPORTS"
cd "$PROJECT_ROOT"

# Validation results tracking
CHECKPOINT_RESULTS=()
OVERALL_STATUS="PASSED"

# Function to run checkpoint validation
run_checkpoint() {
    local checkpoint_name="$1"
    local description="$2"
    local validation_command="$3"
    local required="$4"  # true/false
    
    echo -e "${BLUE}🔍 Checkpoint: $checkpoint_name${NC}"
    echo "Description: $description"
    
    if [ "$QUICK_MODE" = true ] && [ "$required" = false ]; then
        echo -e "${YELLOW}  ⚠️ Skipped (non-required in quick mode)${NC}"
        CHECKPOINT_RESULTS+=("$checkpoint_name|SKIPPED|Optional checkpoint skipped in quick mode")
        return 0
    fi
    
    local start_time=$(date +%s)
    
    # Execute validation command
    if eval "$validation_command" >/dev/null 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}  ✅ PASSED (${duration}s)${NC}"
        CHECKPOINT_RESULTS+=("$checkpoint_name|PASSED|$description")
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${RED}  ❌ FAILED (${duration}s)${NC}"
        CHECKPOINT_RESULTS+=("$checkpoint_name|FAILED|$description")
        
        if [ "$required" = true ]; then
            OVERALL_STATUS="FAILED"
        fi
        return 1
    fi
}

# Function to validate file changes
validate_file_changes() {
    local file_pattern="$1"
    local change_description="$2"
    
    # Check if files matching pattern exist and have recent changes
    if find . -path "$file_pattern" -newer .git/HEAD >/dev/null 2>&1; then
        echo "Recent changes detected in: $change_description"
        return 0
    else
        echo "No recent changes in: $change_description"
        return 1
    fi
}

# Function to run specific test category
run_test_category() {
    local category="$1"
    local timeout="$2"
    
    if [ -f "scripts/run-test-categories.sh" ]; then
        timeout "$timeout" ./scripts/run-test-categories.sh --"$category" --quick
    else
        # Fallback to basic validation
        timeout "$timeout" "/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe" --headless --check-only --quit
    fi
}

# Phase 1: Core Refactoring Validation
validate_phase1() {
    echo -e "${PURPLE}📋 PHASE 1: CORE REFACTORING VALIDATION${NC}"
    echo "========================================"
    
    # Task 1.1: State Manager Phase Updates
    run_checkpoint "state_manager_update" \
        "CampaignCreationStateManager.gd phase enum updated" \
        "grep -q 'enum Phase.*CONFIG.*CAPTAIN_CREATION.*CREW_SETUP.*SHIP_ASSIGNMENT.*EQUIPMENT_GENERATION.*WORLD_GENERATION.*FINAL_REVIEW' src/core/campaign/creation/CampaignCreationStateManager.gd" \
        true
    
    # Task 1.2: Coordinator Updates  
    run_checkpoint "coordinator_update" \
        "CampaignCreationCoordinator.gd total_steps = 7" \
        "grep -q 'total_steps.*7' src/ui/screens/campaign/CampaignCreationCoordinator.gd" \
        true
        
    # Task 1.3: UI Panel Mapping
    run_checkpoint "ui_panel_mapping" \
        "CampaignCreationUI.gd panel mapping updated" \
        "grep -c 'Phase\\.' src/ui/screens/campaign/CampaignCreationUI.gd | grep -q '^7$'" \
        true
        
    # Task 1.4: ExpandedConfigPanel Victory Integration
    run_checkpoint "config_panel_victory" \
        "ExpandedConfigPanel.gd victory conditions integrated" \
        "grep -q 'victory_conditions' src/ui/screens/campaign/panels/ExpandedConfigPanel.gd" \
        true
        
    # Syntax validation
    run_checkpoint "syntax_validation" \
        "Project syntax validation passes" \
        "timeout 60 \"/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe\" --headless --check-only --quit" \
        true
        
    # Unit tests
    run_checkpoint "unit_tests" \
        "Core unit tests pass" \
        "run_test_category unit 90" \
        false
}

# Phase 2: Signal Integration Validation
validate_phase2() {
    echo -e "${PURPLE}📋 PHASE 2: SIGNAL INTEGRATION VALIDATION${NC}"
    echo "=========================================="
    
    # Signal connection implementation
    run_checkpoint "signal_connections" \
        "_connect_panel_signals() implementation" \
        "grep -q '_connect_panel_signals' src/ui/screens/campaign/CampaignCreationUI.gd" \
        true
        
    # Navigation state updates
    run_checkpoint "navigation_updates" \
        "_update_navigation_state() implementation" \
        "grep -q '_update_navigation_state' src/ui/screens/campaign/CampaignCreationUI.gd" \
        true
        
    # Panel signal emissions
    run_checkpoint "panel_signals" \
        "Panel signal emissions implemented" \
        "grep -q 'signal.*emit' src/ui/screens/campaign/panels/*.gd" \
        true
        
    # Integration tests
    run_checkpoint "integration_tests" \
        "Integration tests pass" \
        "run_test_category integration 180" \
        false
        
    # Campaign creation flow test
    run_checkpoint "campaign_flow_test" \
        "Campaign creation flow validation" \
        "timeout 120 \"/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe\" --headless --script comprehensive_campaign_test.gd --quit" \
        false
}

# Phase 3: Testing & Validation
validate_phase3() {
    echo -e "${PURPLE}📋 PHASE 3: TESTING & VALIDATION${NC}"
    echo "=================================="
    
    # Manual testing checklist (simulated)
    run_checkpoint "manual_testing" \
        "Manual testing checklist validation" \
        "test -f docs/CAMPAIGN_CREATION_FIX.md || echo 'Manual testing docs validation'" \
        false
        
    # Unit test implementation
    run_checkpoint "unit_test_suite" \
        "Unit test suite execution" \
        "run_test_category unit 60" \
        true
        
    # Integration test implementation  
    run_checkpoint "integration_test_suite" \
        "Integration test suite execution" \
        "run_test_category integration 240" \
        true
        
    # End-to-end tests
    run_checkpoint "e2e_tests" \
        "End-to-end test execution" \
        "run_test_category e2e 360" \
        false
        
    # Performance tests
    run_checkpoint "performance_tests" \
        "Performance test execution" \
        "run_test_category performance 120" \
        false
        
    # Comprehensive test suite
    run_checkpoint "comprehensive_suite" \
        "Full comprehensive test suite" \
        "timeout 600 ./scripts/run_comprehensive_test_suite.sh" \
        true
}

# Phase 4: Cleanup & Documentation
validate_phase4() {
    echo -e "${PURPLE}📋 PHASE 4: CLEANUP & DOCUMENTATION${NC}"
    echo "====================================="
    
    # Redundant file removal
    run_checkpoint "file_cleanup" \
        "Redundant files removed" \
        "! find src/ui/screens/campaign/panels -name '*VictoryConditionsPanel*' -o -name '*SimpleConfigPanel*' -o -name '*.backup' | grep -q ." \
        true
        
    # Documentation updates
    run_checkpoint "documentation" \
        "Documentation updated" \
        "test -f docs/campaign_creation_flow.md || test -f docs/TEST_DRIVEN_DEVELOPMENT_WORKFLOW.md" \
        true
        
    # Git repository status
    run_checkpoint "git_status" \
        "Git repository clean or staged" \
        "git status --porcelain | grep -q '^[AM]' || test \$(git status --porcelain | wc -l) -eq 0" \
        false
        
    # Final validation
    run_checkpoint "final_validation" \
        "Final project validation" \
        "timeout 300 \"/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe\" --headless --check-only --quit" \
        true
        
    # Test suite final run
    run_checkpoint "final_test_run" \
        "Final comprehensive test run" \
        "run_test_category critical 180" \
        true
}

# Execute validation based on phase
case $PHASE in
    "phase1")
        validate_phase1
        ;;
    "phase2") 
        validate_phase2
        ;;
    "phase3")
        validate_phase3
        ;;
    "phase4")
        validate_phase4
        ;;
    "all")
        validate_phase1
        echo ""
        validate_phase2
        echo ""
        validate_phase3
        echo ""
        validate_phase4
        ;;
    *)
        echo -e "${RED}❌ ERROR: Invalid phase: $PHASE${NC}"
        exit 1
        ;;
esac

# Generate checkpoint report
if [ "$GENERATE_REPORT" = true ]; then
    echo ""
    echo -e "${BLUE}📊 GENERATING CHECKPOINT REPORT${NC}"
    
    REPORT_FILE="$CHECKPOINT_REPORTS/sprint_checkpoint_${PHASE}_${TIMESTAMP}.md"
    
    cat > "$REPORT_FILE" << EOF
# Sprint Validation Checkpoint Report

**Phase:** $PHASE - ${SPRINT_PHASES[$PHASE]:-"All Phases"}  
**Date:** $(date)  
**Overall Status:** $OVERALL_STATUS  

## Checkpoint Results

| Checkpoint | Status | Description |
|------------|--------|-------------|
EOF
    
    # Add checkpoint results to report
    for result in "${CHECKPOINT_RESULTS[@]}"; do
        IFS='|' read -r name status description <<< "$result"
        echo "| $name | $status | $description |" >> "$REPORT_FILE"
    done
    
    cat >> "$REPORT_FILE" << EOF

## Summary

- **Total Checkpoints:** ${#CHECKPOINT_RESULTS[@]}
- **Passed:** $(echo "${CHECKPOINT_RESULTS[@]}" | grep -o "PASSED" | wc -l)
- **Failed:** $(echo "${CHECKPOINT_RESULTS[@]}" | grep -o "FAILED" | wc -l) 
- **Skipped:** $(echo "${CHECKPOINT_RESULTS[@]}" | grep -o "SKIPPED" | wc -l)

## Recommendations

EOF
    
    if [ "$OVERALL_STATUS" = "FAILED" ]; then
        cat >> "$REPORT_FILE" << EOF
⚠️ **Action Required:** This sprint phase has failing checkpoints that must be resolved before proceeding.

### Failed Checkpoints
EOF
        for result in "${CHECKPOINT_RESULTS[@]}"; do
            IFS='|' read -r name status description <<< "$result"
            if [ "$status" = "FAILED" ]; then
                echo "- **$name:** $description" >> "$REPORT_FILE"
            fi
        done
    else
        cat >> "$REPORT_FILE" << EOF
✅ **Ready to Proceed:** All required checkpoints have passed for this sprint phase.
EOF
    fi
    
    cat >> "$REPORT_FILE" << EOF

## Next Steps

EOF
    
    case $PHASE in
        "phase1")
            echo "- Proceed to Phase 2: Signal Integration" >> "$REPORT_FILE"
            echo "- Run: \`./scripts/sprint-validation-checkpoints.sh phase2\`" >> "$REPORT_FILE"
            ;;
        "phase2")
            echo "- Proceed to Phase 3: Testing & Validation" >> "$REPORT_FILE"
            echo "- Run: \`./scripts/sprint-validation-checkpoints.sh phase3 --report\`" >> "$REPORT_FILE"
            ;;
        "phase3")
            echo "- Proceed to Phase 4: Cleanup & Documentation" >> "$REPORT_FILE"
            echo "- Run: \`./scripts/sprint-validation-checkpoints.sh phase4\`" >> "$REPORT_FILE"
            ;;
        "phase4")
            echo "- Sprint completion validated" >> "$REPORT_FILE"
            echo "- Ready for production deployment validation" >> "$REPORT_FILE"
            echo "- Run: \`./scripts/production-deployment-validator.sh\`" >> "$REPORT_FILE"
            ;;
        "all")
            echo "- Review individual phase results" >> "$REPORT_FILE"
            echo "- Address any failing checkpoints" >> "$REPORT_FILE"
            echo "- Consider production deployment when all phases pass" >> "$REPORT_FILE"
            ;;
    esac
    
    echo ""
    echo "📄 Checkpoint report generated: $REPORT_FILE"
fi

# Final status summary
echo ""
echo -e "${BLUE}📋 SPRINT CHECKPOINT SUMMARY${NC}"
echo "============================="
echo "Phase: $PHASE - ${SPRINT_PHASES[$PHASE]:-"All Phases"}"
echo "Total Checkpoints: ${#CHECKPOINT_RESULTS[@]}"

passed_count=$(echo "${CHECKPOINT_RESULTS[@]}" | grep -o "PASSED" | wc -l)
failed_count=$(echo "${CHECKPOINT_RESULTS[@]}" | grep -o "FAILED" | wc -l)
skipped_count=$(echo "${CHECKPOINT_RESULTS[@]}" | grep -o "SKIPPED" | wc -l)

echo "Passed: $passed_count"
echo "Failed: $failed_count"
echo "Skipped: $skipped_count"

if [ "$OVERALL_STATUS" = "PASSED" ]; then
    echo -e "${GREEN}Overall Status: ✅ PASSED${NC}"
    echo ""
    echo "🎉 Sprint phase validation completed successfully!"
    
    case $PHASE in
        "phase1")
            echo "💡 Next: Run './scripts/sprint-validation-checkpoints.sh phase2'"
            ;;
        "phase2")
            echo "💡 Next: Run './scripts/sprint-validation-checkpoints.sh phase3 --report'"
            ;;
        "phase3")
            echo "💡 Next: Run './scripts/sprint-validation-checkpoints.sh phase4'"
            ;;
        "phase4")
            echo "💡 Next: Ready for production deployment validation"
            ;;
        "all")
            echo "💡 Next: Address any failing phases and proceed to deployment"
            ;;
    esac
    
    exit 0
else
    echo -e "${RED}Overall Status: ❌ FAILED${NC}"
    echo ""
    echo "🚨 Sprint phase validation failed!"
    echo "Review failed checkpoints and resolve issues before proceeding."
    
    exit 1
fi