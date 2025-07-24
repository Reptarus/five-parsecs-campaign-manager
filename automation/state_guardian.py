#!/usr/bin/env python3
"""
Five Parsecs Campaign Manager - State Management Guardian
Enterprise-grade protection system for campaign state integrity and signal architecture validation
"""

import os
import sys
import json
import re
import ast
import argparse
import time
from pathlib import Path
from typing import Dict, List, Optional, Set, NamedTuple, Tuple, Any
from dataclasses import dataclass
from enum import Enum

class StateIntegrityLevel(Enum):
    CRITICAL = "critical"
    ERROR = "error"
    WARNING = "warning"
    INFO = "info"

class StateGuardCategory(Enum):
    SIGNAL_ARCHITECTURE = "signal_architecture"
    STATE_VALIDATION = "state_validation"
    UI_STATE_BINDING = "ui_state_binding"
    DATA_FLOW = "data_flow"
    CONCURRENCY_SAFETY = "concurrency_safety"
    MEMORY_MANAGEMENT = "memory_management"

@dataclass
class StateIntegrityIssue:
    """Comprehensive state management integrity issue"""
    level: StateIntegrityLevel
    category: StateGuardCategory
    file_path: str
    line_number: Optional[int]
    function_name: Optional[str]
    issue_type: str
    description: str
    current_implementation: str
    expected_pattern: str
    remediation: str
    business_impact: str
    code_example: Optional[str] = None

@dataclass
class StateGuardResult:
    """Comprehensive state management validation results"""
    is_secure: bool
    total_issues: int
    critical_issues: int
    error_issues: int
    warning_issues: int
    info_issues: int
    issues: List[StateIntegrityIssue]
    signal_integrity_score: float
    state_validation_coverage: float
    execution_time: float
    recommendations: List[str]

class CampaignStateGuardian:
    """
    Production-grade state management protection system
    
    Protects the enterprise-grade CampaignCreationStateManager and ensures:
    - Signal architecture integrity and proper connection patterns
    - State validation and business rule enforcement
    - UI-state binding consistency and data flow validation
    - Concurrency safety and race condition prevention
    - Memory management and resource cleanup
    """
    
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.issues: List[StateIntegrityIssue] = []
        
        # Critical state management patterns for Five Parsecs
        self.critical_state_managers = [
            "CampaignCreationStateManager",
            "WorldPhaseStateManager", 
            "BattleStateManager",
            "CharacterStateManager"
        ]
        
        # Required signal patterns for campaign creation workflow
        self.required_signals = [
            "character_data_changed",
            "crew_configuration_updated",
            "ship_selection_changed",
            "background_selected",
            "validation_state_changed",
            "navigation_state_updated"
        ]
        
        # State validation patterns
        self.validation_patterns = self._build_validation_patterns()
        
        # Signal connection patterns
        self.signal_patterns = self._build_signal_patterns()
        
    def _build_validation_patterns(self) -> Dict[str, Dict]:
        """
        Build comprehensive state validation pattern definitions
        Based on Five Parsecs enterprise state management requirements
        """
        return {
            "state_manager_patterns": {
                "validation_methods": [
                    "validate_character_data",
                    "validate_crew_configuration", 
                    "validate_ship_selection",
                    "validate_campaign_settings"
                ],
                "required_properties": [
                    "is_valid",
                    "validation_errors",
                    "current_state",
                    "state_history"
                ],
                "lifecycle_methods": [
                    "_initialize_state",
                    "_validate_transition",
                    "_cleanup_state"
                ]
            },
            "ui_state_binding": {
                "required_connections": [
                    "_connect_panel_signals",
                    "_update_navigation_state",
                    "_validate_current_panel"
                ],
                "state_synchronization": [
                    "_sync_ui_with_state",
                    "_handle_state_change",
                    "_update_validation_display"
                ]
            },
            "signal_architecture": {
                "emission_patterns": [
                    "signal.emit(data)",
                    "signal_name.emit(value)",
                    "emit_signal(\"signal_name\", data)"
                ],
                "connection_patterns": [
                    "signal.connect(method)",
                    "connect(\"signal_name\", method)",
                    "signal_name.connect(callable)"
                ]
            }
        }
    
    def _build_signal_patterns(self) -> Dict[str, re.Pattern]:
        """
        Build regex patterns for signal architecture validation
        """
        return {
            "signal_definition": re.compile(r'@signal\s+(\w+)\s*\([^)]*\)|signal\s+(\w+)\s*\([^)]*\)', re.MULTILINE),
            "signal_emission": re.compile(r'(\w+)\.emit\([^)]*\)|emit_signal\s*\(\s*["\'](\w+)["\']', re.MULTILINE),
            "signal_connection": re.compile(r'(\w+)\.connect\([^)]*\)|connect\s*\(\s*["\'](\w+)["\']', re.MULTILINE),
            "signal_disconnection": re.compile(r'(\w+)\.disconnect\([^)]*\)|disconnect\s*\(\s*["\'](\w+)["\']', re.MULTILINE),
            "state_validation": re.compile(r'func\s+validate_\w+\s*\([^)]*\)\s*->\s*(bool|ValidationResult)', re.MULTILINE),
            "state_transition": re.compile(r'func\s+_transition_to_\w+|func\s+set_\w+_state', re.MULTILINE)
        }
    
    def validate_state_manager_integrity(self, file_path: str) -> List[StateIntegrityIssue]:
        """
        Validate state manager implementation against enterprise patterns
        """
        issues = []
        
        if not os.path.exists(file_path):
            return issues
            
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            lines = content.split('\n')
            file_name = Path(file_path).name
            
            # Check if this is a critical state manager
            is_critical_manager = any(manager in file_name for manager in self.critical_state_managers)
            
            if is_critical_manager:
                issues.extend(self._validate_critical_state_manager(file_path, content, lines))
            
            # Validate signal architecture
            issues.extend(self._validate_signal_architecture(file_path, content, lines))
            
            # Validate state validation implementation
            issues.extend(self._validate_state_validation_logic(file_path, content, lines))
            
            # Validate UI-state binding
            if "UI" in file_name:
                issues.extend(self._validate_ui_state_binding(file_path, content, lines))
                
            # Check concurrency safety
            issues.extend(self._validate_concurrency_safety(file_path, content, lines))
            
            # Validate memory management
            issues.extend(self._validate_memory_management(file_path, content, lines))
            
        except Exception as e:
            issues.append(StateIntegrityIssue(
                level=StateIntegrityLevel.ERROR,
                category=StateGuardCategory.STATE_VALIDATION,
                file_path=file_path,
                line_number=None,
                function_name=None,
                issue_type="file_parsing_error",
                description=f"Failed to parse file for state validation: {str(e)}",
                current_implementation="File could not be analyzed",
                expected_pattern="All state management files must be parseable",
                remediation="Fix file encoding, syntax errors, or access permissions",
                business_impact="Critical state management validation cannot be performed",
                code_example=None
            ))
        
        return issues
    
    def _validate_critical_state_manager(self, file_path: str, content: str, 
                                       lines: List[str]) -> List[StateIntegrityIssue]:
        """
        Validate critical state manager implementations (CampaignCreationStateManager, etc.)
        """
        issues = []
        file_name = Path(file_path).name
        
        # Check for required validation methods
        required_validations = self.validation_patterns["state_manager_patterns"]["validation_methods"]
        
        for validation_method in required_validations:
            if validation_method not in content:
                issues.append(StateIntegrityIssue(
                    level=StateIntegrityLevel.CRITICAL,
                    category=StateGuardCategory.STATE_VALIDATION,
                    file_path=file_path,
                    line_number=None,
                    function_name=validation_method,
                    issue_type="missing_critical_validation",
                    description=f"Critical state manager missing {validation_method}",
                    current_implementation="Validation method not implemented",
                    expected_pattern=f"func {validation_method}() -> ValidationResult",
                    remediation=f"Implement {validation_method} with comprehensive business rule validation",
                    business_impact="Campaign creation workflow may allow invalid states, corrupting user data",
                    code_example=f"""func {validation_method}() -> ValidationResult:
    var result = ValidationResult.new()
    
    # Implement specific validation logic
    if not _validate_business_rules():
        result.add_error("Business rule validation failed")
        return result
    
    result.mark_valid()
    return result"""
                ))
        
        # Check for required properties
        required_props = self.validation_patterns["state_manager_patterns"]["required_properties"]
        
        for prop in required_props:
            if f"var {prop}" not in content and f"@export var {prop}" not in content:
                issues.append(StateIntegrityIssue(
                    level=StateIntegrityLevel.ERROR,
                    category=StateGuardCategory.STATE_VALIDATION,
                    file_path=file_path,
                    line_number=None,
                    function_name=None,
                    issue_type="missing_required_property",
                    description=f"State manager missing required property: {prop}",
                    current_implementation="Property not declared",
                    expected_pattern=f"var {prop}: Type = default_value",
                    remediation=f"Add {prop} property with proper type annotation and initialization",
                    business_impact="State management may be incomplete, leading to runtime errors",
                    code_example=f"@export var {prop}: bool = false  # or appropriate type"
                ))
        
        # Validate state transition safety
        if "func set_" in content or "func _transition_" in content:
            transition_matches = self.signal_patterns["state_transition"].findall(content)
            
            for match in transition_matches:
                func_line = self._find_function_line(lines, match)
                # Check if transition has validation
                if func_line and func_line < len(lines) - 5:
                    func_content = "\n".join(lines[func_line:func_line + 10])
                    
                    if "validate" not in func_content.lower():
                        issues.append(StateIntegrityIssue(
                            level=StateIntegrityLevel.WARNING,
                            category=StateGuardCategory.STATE_VALIDATION,
                            file_path=file_path,
                            line_number=func_line + 1,
                            function_name=match,
                            issue_type="unvalidated_state_transition",
                            description="State transition without validation check",
                            current_implementation="Direct state change without validation",
                            expected_pattern="Validate before state transition",
                            remediation="Add validation check before changing state",
                            business_impact="Invalid state transitions could corrupt campaign data",
                            code_example="""func set_new_state(new_state: CampaignState) -> bool:
    var validation = validate_state_transition(current_state, new_state)
    if not validation.is_valid:
        push_error("Invalid state transition: " + validation.error_message)
        return false
    
    current_state = new_state
    state_changed.emit(new_state)
    return true"""
                        ))
        
        return issues
    
    def _validate_signal_architecture(self, file_path: str, content: str, 
                                    lines: List[str]) -> List[StateIntegrityIssue]:
        """
        Validate signal architecture integrity and connection patterns
        """
        issues = []
        
        # Find all signal definitions
        signal_definitions = self.signal_patterns["signal_definition"].findall(content)
        defined_signals = set()
        
        for match in signal_definitions:
            signal_name = match[0] if match[0] else match[1]
            defined_signals.add(signal_name)
        
        # Find all signal emissions
        signal_emissions = self.signal_patterns["signal_emission"].findall(content)
        emitted_signals = set()
        
        for match in signal_emissions:
            signal_name = match[0] if match[0] else match[1] 
            emitted_signals.add(signal_name)
        
        # Check for emitted signals that aren't defined
        undefined_emissions = emitted_signals - defined_signals
        
        for undefined_signal in undefined_emissions:
            line_num = self._find_signal_usage_line(lines, undefined_signal, "emit")
            issues.append(StateIntegrityIssue(
                level=StateIntegrityLevel.ERROR,
                category=StateGuardCategory.SIGNAL_ARCHITECTURE,
                file_path=file_path,
                line_number=line_num,
                function_name=None,
                issue_type="undefined_signal_emission",
                description=f"Emitting undefined signal: {undefined_signal}",
                current_implementation=f"Emitting {undefined_signal} without definition",
                expected_pattern="@signal signal_name(parameters: Type)",
                remediation=f"Define signal: @signal {undefined_signal}(data: Type)",
                business_impact="Runtime errors and broken UI state synchronization",
                code_example=f"@signal {undefined_signal}(data: Dictionary)  # Add at class level"
            ))
        
        # Find signal connections
        signal_connections = self.signal_patterns["signal_connection"].findall(content)
        connected_signals = set()
        
        for match in signal_connections:
            signal_name = match[0] if match[0] else match[1]
            connected_signals.add(signal_name)
        
        # Check for orphaned signals (defined but never connected or emitted)
        orphaned_signals = defined_signals - (emitted_signals | connected_signals)
        
        for orphaned_signal in orphaned_signals:
            line_num = self._find_signal_definition_line(lines, orphaned_signal)
            issues.append(StateIntegrityIssue(
                level=StateIntegrityLevel.WARNING,
                category=StateGuardCategory.SIGNAL_ARCHITECTURE,
                file_path=file_path,
                line_number=line_num,
                function_name=None,
                issue_type="orphaned_signal",
                description=f"Signal defined but never used: {orphaned_signal}",
                current_implementation=f"Signal {orphaned_signal} exists but is unused",
                expected_pattern="Signals should be connected and emitted",
                remediation=f"Either remove unused signal or implement connection/emission",
                business_impact="Code bloat and potential confusion about signal purpose",
                code_example=f"# Either remove: @signal {orphaned_signal}\n# Or connect: {orphaned_signal}.connect(_on_{orphaned_signal})"
            ))
        
        # Check for critical Five Parsecs signals in UI files
        if "UI" in Path(file_path).name:
            for required_signal in self.required_signals:
                if required_signal not in content:
                    issues.append(StateIntegrityIssue(
                        level=StateIntegrityLevel.WARNING,
                        category=StateGuardCategory.SIGNAL_ARCHITECTURE,
                        file_path=file_path,
                        line_number=None,
                        function_name=None,
                        issue_type="missing_critical_signal",
                        description=f"UI missing critical Five Parsecs signal: {required_signal}",
                        current_implementation="Signal not implemented in UI",
                        expected_pattern=f"@signal {required_signal}(data: Type)",
                        remediation=f"Implement {required_signal} for campaign workflow integration",
                        business_impact="Campaign creation workflow may be incomplete or non-functional",
                        code_example=f"@signal {required_signal}(data: Dictionary)"
                    ))
        
        return issues
    
    def _validate_state_validation_logic(self, file_path: str, content: str, 
                                       lines: List[str]) -> List[StateIntegrityIssue]:
        """
        Validate state validation logic implementation
        """
        issues = []
        
        # Check for validation method patterns
        validation_methods = self.signal_patterns["state_validation"].findall(content)
        
        if not validation_methods and ("StateManager" in Path(file_path).name or "state" in content.lower()):
            issues.append(StateIntegrityIssue(
                level=StateIntegrityLevel.ERROR,
                category=StateGuardCategory.STATE_VALIDATION,
                file_path=file_path,
                line_number=None,
                function_name=None,
                issue_type="missing_validation_methods",
                description="State management class lacks validation methods",
                current_implementation="No validation methods found",
                expected_pattern="func validate_*() -> bool/ValidationResult",
                remediation="Implement comprehensive state validation methods",
                business_impact="Invalid states may persist, causing data corruption and user experience issues",
                code_example="""func validate_current_state() -> ValidationResult:
    var result = ValidationResult.new()
    
    if not _validate_required_fields():
        result.add_error("Required fields missing")
    
    if not _validate_business_rules():
        result.add_error("Business rules violated")
    
    return result"""
            ))
        
        # Check for error handling in state changes
        if "state" in content.lower() and "error" not in content.lower():
            issues.append(StateIntegrityIssue(
                level=StateIntegrityLevel.WARNING,
                category=StateGuardCategory.STATE_VALIDATION,
                file_path=file_path,
                line_number=None,
                function_name=None,
                issue_type="missing_error_handling",
                description="State management lacks comprehensive error handling",
                current_implementation="State changes without error handling",
                expected_pattern="Try-catch blocks and error validation for state changes",
                remediation="Add error handling for all state modifications",
                business_impact="Unhandled errors may crash the application or corrupt state",
                code_example="""func change_state(new_state: State) -> Result:
    try:
        var validation = validate_state_transition(new_state)
        if not validation.is_valid:
            return Result.error(validation.error_message)
        
        _apply_state_change(new_state)
        return Result.success()
    except Exception as e:
        push_error("State change failed: " + str(e))
        return Result.error("State transition failed")"""
            ))
        
        return issues
    
    def _validate_ui_state_binding(self, file_path: str, content: str, 
                                 lines: List[str]) -> List[StateIntegrityIssue]:
        """
        Validate UI-state binding consistency and patterns
        """
        issues = []
        
        # Check for state synchronization methods
        required_ui_methods = self.validation_patterns["ui_state_binding"]["state_synchronization"]
        
        for method in required_ui_methods:
            if method not in content:
                issues.append(StateIntegrityIssue(
                    level=StateIntegrityLevel.WARNING,
                    category=StateGuardCategory.UI_STATE_BINDING,
                    file_path=file_path,
                    line_number=None,
                    function_name=method,
                    issue_type="missing_ui_state_sync",
                    description=f"UI missing state synchronization method: {method}",
                    current_implementation="UI-state synchronization not implemented",
                    expected_pattern=f"func {method}() -> void",
                    remediation=f"Implement {method} for proper UI-state coordination",
                    business_impact="UI may display stale data or be out of sync with business state",
                    code_example=f"""func {method}() -> void:
    # Synchronize UI components with current state
    if state_manager:
        _update_ui_components(state_manager.get_current_state())
        _refresh_validation_indicators()"""
                ))
        
        # Check for proper signal connection in UI
        if "_connect" not in content and "connect" in content:
            issues.append(StateIntegrityIssue(
                level=StateIntegrityLevel.WARNING,
                category=StateGuardCategory.UI_STATE_BINDING,
                file_path=file_path,
                line_number=None,
                function_name=None,
                issue_type="manual_signal_connections",
                description="UI uses manual signal connections instead of centralized method",
                current_implementation="Signal connections scattered throughout code",
                expected_pattern="Centralized _connect_signals() method",
                remediation="Consolidate signal connections into _connect_signals() method",
                business_impact="Signal connections may be incomplete or disconnected improperly",
                code_example="""func _connect_signals() -> void:
    if state_manager:
        state_manager.state_changed.connect(_on_state_changed)
        state_manager.validation_changed.connect(_on_validation_changed)
    
    # Connect UI component signals
    for panel in panels:
        panel.data_changed.connect(_on_panel_data_changed)"""
            ))
        
        return issues
    
    def _validate_concurrency_safety(self, file_path: str, content: str, 
                                   lines: List[str]) -> List[StateIntegrityIssue]:
        """
        Validate concurrency safety and race condition prevention
        """
        issues = []
        
        # Check for potential race conditions in state access
        if ("await" in content or "async" in content) and "mutex" not in content and "lock" not in content:
            issues.append(StateIntegrityIssue(
                level=StateIntegrityLevel.WARNING,
                category=StateGuardCategory.CONCURRENCY_SAFETY,
                file_path=file_path,
                line_number=None,
                function_name=None,
                issue_type="potential_race_condition",
                description="Async operations without concurrency protection",
                current_implementation="Async code without mutex or locking",
                expected_pattern="Mutex or semaphore protection for shared state",
                remediation="Add mutex protection for concurrent state access",
                business_impact="Race conditions may corrupt state or cause data loss",
                code_example="""# Add class-level mutex
var state_mutex = Mutex.new()

func modify_state_safely(new_data: Dictionary) -> void:
    state_mutex.lock()
    try:
        # Modify state safely
        _update_internal_state(new_data)
    finally:
        state_mutex.unlock()"""
            ))
        
        return issues
    
    def _validate_memory_management(self, file_path: str, content: str, 
                                  lines: List[str]) -> List[StateIntegrityIssue]:
        """
        Validate memory management and resource cleanup
        """
        issues = []
        
        # Check for signal disconnection in cleanup
        if "connect" in content and ("disconnect" not in content and "_exit_tree" not in content):
            issues.append(StateIntegrityIssue(
                level=StateIntegrityLevel.WARNING,
                category=StateGuardCategory.MEMORY_MANAGEMENT,
                file_path=file_path,
                line_number=None,
                function_name=None,
                issue_type="missing_signal_cleanup",
                description="Signal connections without cleanup in _exit_tree",
                current_implementation="Signals connected but not disconnected",
                expected_pattern="Disconnect signals in _exit_tree() method",
                remediation="Add _exit_tree() method to disconnect signals",
                business_impact="Memory leaks and dangling references may degrade performance",
                code_example="""func _exit_tree() -> void:
    # Disconnect all signals to prevent memory leaks
    if state_manager:
        if state_manager.state_changed.is_connected(_on_state_changed):
            state_manager.state_changed.disconnect(_on_state_changed)
    
    # Clean up other resources
    _cleanup_internal_references()"""
            ))
        
        # Check for proper resource cleanup
        if ("new()" in content or "load(" in content) and "queue_free" not in content:
            issues.append(StateIntegrityIssue(
                level=StateIntegrityLevel.INFO,
                category=StateGuardCategory.MEMORY_MANAGEMENT,
                file_path=file_path,
                line_number=None,
                function_name=None,
                issue_type="potential_resource_leak",
                description="Creating resources without explicit cleanup",
                current_implementation="Resources created without cleanup verification",
                expected_pattern="Explicit resource cleanup in _exit_tree",
                remediation="Ensure all created resources are properly cleaned up",
                business_impact="Memory usage may increase over time",
                code_example="""func _exit_tree() -> void:
    # Clean up any dynamically created resources
    for resource in created_resources:
        if is_instance_valid(resource):
            resource.queue_free()
    
    created_resources.clear()"""
            ))
        
        return issues
    
    def _find_function_line(self, lines: List[str], function_name: str) -> Optional[int]:
        """Find line number where function is defined"""
        for i, line in enumerate(lines):
            if f"func {function_name}" in line:
                return i
        return None
    
    def _find_signal_definition_line(self, lines: List[str], signal_name: str) -> Optional[int]:
        """Find line number where signal is defined"""
        for i, line in enumerate(lines):
            if f"@signal {signal_name}" in line or f"signal {signal_name}" in line:
                return i + 1
        return None
    
    def _find_signal_usage_line(self, lines: List[str], signal_name: str, usage_type: str) -> Optional[int]:
        """Find line number where signal is used (emit/connect)"""
        pattern = f"{signal_name}.{usage_type}" if usage_type in ["emit", "connect"] else signal_name
        for i, line in enumerate(lines):
            if pattern in line:
                return i + 1
        return None
    
    def run_comprehensive_validation(self, target_files: List[str]) -> StateGuardResult:
        """
        Run comprehensive state management validation across multiple files
        """
        start_time = time.time()
        
        all_issues = []
        validated_files = 0
        
        print("🛡️ Starting comprehensive state management validation...")
        
        for file_path in target_files:
            if not file_path.endswith('.gd'):
                continue
                
            print(f"🔍 Validating: {Path(file_path).name}")
            
            file_issues = self.validate_state_manager_integrity(file_path)
            all_issues.extend(file_issues)
            validated_files += 1
        
        execution_time = time.time() - start_time
        
        # Categorize issues by severity
        critical_count = len([i for i in all_issues if i.level == StateIntegrityLevel.CRITICAL])
        error_count = len([i for i in all_issues if i.level == StateIntegrityLevel.ERROR])
        warning_count = len([i for i in all_issues if i.level == StateIntegrityLevel.WARNING])
        info_count = len([i for i in all_issues if i.level == StateIntegrityLevel.INFO])
        
        # Calculate integrity scores
        signal_issues = len([i for i in all_issues if i.category == StateGuardCategory.SIGNAL_ARCHITECTURE])
        signal_integrity_score = max(0.0, 100.0 - (signal_issues * 10.0))
        
        validation_issues = len([i for i in all_issues if i.category == StateGuardCategory.STATE_VALIDATION])
        state_validation_coverage = max(0.0, 100.0 - (validation_issues * 15.0))
        
        # Generate recommendations
        recommendations = self._generate_recommendations(all_issues)
        
        result = StateGuardResult(
            is_secure=critical_count == 0 and error_count == 0,
            total_issues=len(all_issues),
            critical_issues=critical_count,
            error_issues=error_count,
            warning_issues=warning_count,
            info_issues=info_count,
            issues=all_issues,
            signal_integrity_score=signal_integrity_score,
            state_validation_coverage=state_validation_coverage,
            execution_time=execution_time,
            recommendations=recommendations
        )
        
        return result
    
    def _generate_recommendations(self, issues: List[StateIntegrityIssue]) -> List[str]:
        """
        Generate actionable recommendations based on identified issues
        """
        recommendations = []
        
        # Category-based recommendations
        categories = {}
        for issue in issues:
            if issue.category not in categories:
                categories[issue.category] = 0
            categories[issue.category] += 1
        
        if categories.get(StateGuardCategory.SIGNAL_ARCHITECTURE, 0) > 3:
            recommendations.append(
                "Implement centralized signal management system with SignalManager class for better architecture"
            )
        
        if categories.get(StateGuardCategory.STATE_VALIDATION, 0) > 2:
            recommendations.append(
                "Create comprehensive ValidationResult system with detailed error reporting and business rule validation"
            )
        
        if categories.get(StateGuardCategory.UI_STATE_BINDING, 0) > 2:
            recommendations.append(
                "Implement reactive UI pattern with automatic state synchronization using Observer or MVVM pattern"
            )
        
        if categories.get(StateGuardCategory.MEMORY_MANAGEMENT, 0) > 1:
            recommendations.append(
                "Add automated resource cleanup system with reference counting and proper lifecycle management"
            )
        
        # Critical issue specific recommendations
        critical_issues = [i for i in issues if i.level == StateIntegrityLevel.CRITICAL]
        if critical_issues:
            recommendations.append(
                "Address critical state management issues immediately to prevent data corruption and system instability"
            )
        
        return recommendations

def main():
    """
    Command-line interface for state management protection
    Designed for integration with Claude Hooks and enterprise development workflows
    """
    parser = argparse.ArgumentParser(
        description="Five Parsecs Campaign Manager - State Management Guardian"
    )
    
    parser.add_argument(
        "--validate-state-integrity",
        action="store_true",
        help="Validate state management integrity and patterns"
    )
    
    parser.add_argument(
        "--check-signal-connections",
        action="store_true",
        help="Validate signal architecture and connection patterns"
    )
    
    parser.add_argument(
        "--verify-validation-logic",
        action="store_true",
        help="Check state validation logic implementation"
    )
    
    parser.add_argument(
        "--target-file",
        help="Validate specific state management file"
    )
    
    parser.add_argument(
        "--target-directory",
        help="Validate all state management files in directory"
    )
    
    parser.add_argument(
        "--output-format",
        choices=["json", "text"],
        default="text",
        help="Output format for validation results"
    )
    
    parser.add_argument(
        "--fail-on-critical",
        action="store_true",
        help="Exit with error code if critical issues found"
    )
    
    args = parser.parse_args()
    
    # Initialize guardian
    project_root = os.getcwd()
    guardian = CampaignStateGuardian(project_root)
    
    # Determine target files
    target_files = []
    
    if args.target_file:
        target_files = [args.target_file]
    elif args.target_directory:
        target_dir = Path(args.target_directory)
        target_files = [str(f) for f in target_dir.rglob("*.gd")]
    else:
        # Default to state management files
        state_dirs = [
            Path(project_root) / "src" / "ui" / "screens",
            Path(project_root) / "src" / "core" / "campaign",
            Path(project_root) / "src" / "game" / "state"
        ]
        
        for state_dir in state_dirs:
            if state_dir.exists():
                target_files.extend([str(f) for f in state_dir.rglob("*.gd")])
    
    # Run validation
    result = guardian.run_comprehensive_validation(target_files)
    
    # Output results
    if args.output_format == "json":
        result_data = {
            "is_secure": result.is_secure,
            "total_issues": result.total_issues,
            "critical_issues": result.critical_issues,
            "error_issues": result.error_issues,
            "warning_issues": result.warning_issues,
            "info_issues": result.info_issues,
            "signal_integrity_score": result.signal_integrity_score,
            "state_validation_coverage": result.state_validation_coverage,
            "execution_time": result.execution_time,
            "recommendations": result.recommendations,
            "issues": [
                {
                    "level": issue.level.value,
                    "category": issue.category.value,
                    "file_path": issue.file_path,
                    "line_number": issue.line_number,
                    "function_name": issue.function_name,
                    "issue_type": issue.issue_type,
                    "description": issue.description,
                    "current_implementation": issue.current_implementation,
                    "expected_pattern": issue.expected_pattern,
                    "remediation": issue.remediation,
                    "business_impact": issue.business_impact,
                    "code_example": issue.code_example
                }
                for issue in result.issues
            ]
        }
        print(json.dumps(result_data, indent=2))
    else:
        print(f"\n🛡️ State Management Guardian Summary")
        print(f"Security Status: {'✅ SECURE' if result.is_secure else '❌ ISSUES FOUND'}")
        print(f"Total Issues: {result.total_issues}")
        print(f"Signal Integrity: {result.signal_integrity_score:.1f}%")
        print(f"Validation Coverage: {result.state_validation_coverage:.1f}%")
        print(f"Execution Time: {result.execution_time:.2f}s")
        
        if result.total_issues > 0:
            print(f"  Critical: {result.critical_issues}")
            print(f"  Errors: {result.error_issues}")
            print(f"  Warnings: {result.warning_issues}")
            print(f"  Info: {result.info_issues}")
        
        if result.recommendations:
            print(f"\n💡 Recommendations:")
            for rec in result.recommendations:
                print(f"  • {rec}")
        
        if result.issues:
            print(f"\n📋 Detailed Issues:")
            for issue in result.issues[:10]:  # Show first 10 issues in text mode
                print(f"\n{issue.level.value.upper()}: {issue.issue_type}")
                print(f"  File: {Path(issue.file_path).name}")
                if issue.line_number:
                    print(f"  Line: {issue.line_number}")
                print(f"  Issue: {issue.description}")
                print(f"  Impact: {issue.business_impact}")
                print(f"  Fix: {issue.remediation}")
            
            if len(result.issues) > 10:
                print(f"\n... and {len(result.issues) - 10} more issues. Use --output-format=json for complete list.")
    
    # Exit with appropriate code
    if args.fail_on_critical and result.critical_issues > 0:
        sys.exit(1)
    elif result.critical_issues > 0 or result.error_issues > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()