#!/usr/bin/env python3
"""
Five Parsecs Campaign Manager - Enhanced Test Runner for Claude Hooks
Production-grade automated testing with targeted execution and intelligent reporting
"""

import os
import sys
import json
import subprocess
import argparse
import time
import re
from pathlib import Path
from typing import Dict, List, Optional, NamedTuple, Set
from dataclasses import dataclass
from enum import Enum

class TestResult(Enum):
    SUCCESS = "success"
    FAILURE = "failure"
    TIMEOUT = "timeout"
    SKIP = "skip"

@dataclass
class TestExecution:
    """Results from test suite execution"""
    result: TestResult
    duration: float
    tests_run: int
    tests_passed: int
    tests_failed: int
    coverage_percentage: float
    output: str
    error_details: List[str]

@dataclass
class SyntaxContextError:
    """Represents a syntax or context error found in code"""
    file_path: str
    line_number: int
    error_type: str
    error_message: str
    suggested_fix: str
    severity: str  # "critical", "warning", "suggestion"

@dataclass
class BackendValidationResult:
    """Results from comprehensive backend validation"""
    syntax_errors: List[SyntaxContextError]
    context_errors: List[SyntaxContextError]
    missing_resources: List[str]
    type_mismatches: List[SyntaxContextError]
    signal_connection_issues: List[SyntaxContextError]
    data_flow_errors: List[SyntaxContextError]
    overall_health: str  # "healthy", "warning", "critical"
    total_issues: int
    critical_issues: int

class TargetedTestRunner:
    """
    Intelligent test runner that executes relevant tests based on changed files
    Integrates with GDUnit4 and provides comprehensive reporting for Claude Hooks
    """
    
    def __init__(self, project_root: str, godot_path: str):
        self.project_root = Path(project_root)
        self.godot_path = Path(godot_path)
        self.test_mappings = self._build_test_mappings()
        
    def _build_test_mappings(self) -> Dict[str, List[str]]:
        """
        Build intelligent mappings between source files and their relevant tests
        Based on the established Five Parsecs project structure
        """
        mappings = {
            # Core systems to their comprehensive test suites
            "src/core/campaign/": ["tests/unit/campaign/", "tests/integration/campaign/"],
            "src/core/battle/": ["tests/unit/battle/", "tests/integration/battle/"],
            "src/core/character/": ["tests/unit/character/", "tests/integration/character/"],
            "src/core/story/": ["tests/unit/story/", "tests/integration/story/"],
            "src/core/systems/": ["tests/unit/core/", "tests/unit/systems/"],
            
            # Game implementations to their specific tests
            "src/game/campaign/": ["tests/unit/campaign/", "tests/unit/game/"],
            "src/game/combat/": ["tests/unit/combat/", "tests/unit/battle/"],
            "src/game/character/": ["tests/unit/character/"],
            "src/game/ships/": ["tests/unit/ships/"],
            "src/game/mission/": ["tests/unit/mission/"],
            
            # UI components to UI tests
            "src/ui/screens/": ["tests/unit/ui/"],
            "src/ui/components/": ["tests/unit/ui/"],
            
            # Base classes trigger comprehensive testing
            "src/base/": ["tests/unit/", "tests/integration/"],
            
            # Critical state management files
            "CampaignCreationStateManager.gd": ["tests/unit/campaign/", "tests/integration/campaign/"],
            "StateManager.gd": ["tests/unit/state/", "tests/integration/state/"]
        }
        
        return mappings
    
    def get_relevant_tests(self, changed_file: str) -> List[str]:
        """
        Determine which tests should run based on the changed file
        Uses intelligent mapping and dependency analysis
        """
        changed_path = Path(changed_file)
        relevant_tests = set()
        
        # Direct mapping checks
        for pattern, test_paths in self.test_mappings.items():
            if pattern in str(changed_path):
                relevant_tests.update(test_paths)
        
        # Specific file name checks for critical components
        filename = changed_path.name
        if filename in self.test_mappings:
            relevant_tests.update(self.test_mappings[filename])
            
        # If it's a state manager or UI file, run comprehensive tests
        if "StateManager" in filename or "UI.gd" in filename:
            relevant_tests.add("tests/unit/ui/")
            relevant_tests.add("tests/integration/campaign/")
            
        # Convert to actual test file paths that exist
        existing_tests = []
        for test_path in relevant_tests:
            full_path = self.project_root / test_path
            if full_path.exists():
                existing_tests.append(str(full_path))
                
        return existing_tests if existing_tests else ["tests/unit/"]
    
    def run_targeted_tests(self, changed_file: str) -> TestExecution:
        """
        Execute relevant tests for the changed file with comprehensive reporting
        """
        start_time = time.time()
        
        # Get relevant test paths
        test_paths = self.get_relevant_tests(changed_file)
        
        print(f"[TARGET] Running targeted tests for: {Path(changed_file).name}")
        print(f"[FOLDER] Test paths: {', '.join([Path(p).name for p in test_paths])}")
        
        # Build Godot test command
        cmd = [
            str(self.godot_path),
            "--headless",
            "--script",
            "addons/gdUnit4/bin/GdUnitCmdTool.gd",
            "-a"  # Run all tests in specified directories
        ]
        
        # Add test paths
        for test_path in test_paths:
            cmd.extend(["-s", str(test_path)])
            
        # Add output formatting for parsing
        cmd.extend(["--output", "json"])
        
        try:
            # Execute tests with timeout
            result = subprocess.run(
                cmd,
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            duration = time.time() - start_time
            
            # Parse GDUnit4 output
            test_results = self._parse_test_output(result.stdout, result.stderr)
            
            # Determine overall result
            if result.returncode == 0 and test_results["tests_failed"] == 0:
                overall_result = TestResult.SUCCESS
            else:
                overall_result = TestResult.FAILURE
                
            return TestExecution(
                result=overall_result,
                duration=duration,
                tests_run=test_results["tests_run"],
                tests_passed=test_results["tests_passed"], 
                tests_failed=test_results["tests_failed"],
                coverage_percentage=test_results.get("coverage", 0.0),
                output=result.stdout,
                error_details=test_results.get("errors", [])
            )
            
        except subprocess.TimeoutExpired:
            return TestExecution(
                result=TestResult.TIMEOUT,
                duration=300.0,
                tests_run=0,
                tests_passed=0,
                tests_failed=0,
                coverage_percentage=0.0,
                output="Test execution timed out",
                error_details=["Test suite exceeded 5 minute timeout"]
            )
            
        except Exception as e:
            return TestExecution(
                result=TestResult.FAILURE,
                duration=time.time() - start_time,
                tests_run=0,
                tests_passed=0,
                tests_failed=1,
                coverage_percentage=0.0,
                output=str(e),
                error_details=[f"Test execution failed: {str(e)}"]
            )
    
    def run_full_backend_validation(self, changed_file: str = None) -> BackendValidationResult:
        """
        COMPREHENSIVE END-TO-END BACKEND VALIDATION
        Catches syntax errors, context issues, and data flow problems before user testing
        """
        print("[E2E BACKEND] Starting comprehensive backend validation...")
        
        result = BackendValidationResult(
            syntax_errors=[],
            context_errors=[],
            missing_resources=[],
            type_mismatches=[],
            signal_connection_issues=[],
            data_flow_errors=[],
            overall_health="healthy",
            total_issues=0,
            critical_issues=0
        )
        
        # 1. Syntax and type validation
        syntax_errors = self._validate_syntax_and_types(changed_file)
        result.syntax_errors.extend(syntax_errors)
        
        # 2. Resource validation  
        missing_resources = self._validate_resources(changed_file)
        result.missing_resources.extend(missing_resources)
        
        # 3. Type mismatch detection
        type_errors = self._detect_type_mismatches(changed_file)
        result.type_mismatches.extend(type_errors)
        
        # 4. Signal connection validation
        signal_errors = self._validate_signal_connections(changed_file)
        result.signal_connection_issues.extend(signal_errors)
        
        # 5. Data flow validation
        data_flow_errors = self._validate_data_flows(changed_file)
        result.data_flow_errors.extend(data_flow_errors)
        
        # 6. Context and integration validation
        context_errors = self._validate_context_integrity(changed_file)
        result.context_errors.extend(context_errors)
        
        # Calculate overall health
        self._calculate_backend_health(result)
        
        return result
    
    def _validate_syntax_and_types(self, changed_file: str = None) -> List[SyntaxContextError]:
        """Validate GDScript syntax and detect common type errors"""
        errors = []
        
        # Get files to check
        files_to_check = self._get_files_to_validate(changed_file)
        
        for file_path in files_to_check:
            if not file_path.suffix == '.gd':
                continue
                
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    lines = content.split('\n')
                
                # Check for common syntax issues
                for line_num, line in enumerate(lines, 1):
                    line_stripped = line.strip()
                    
                    # Type mismatch patterns
                    type_patterns = [
                        (r'var\s+(\w+):\s*String\s*=\s*(\d+)', "String variable assigned numeric value"),
                        (r'var\s+(\w+):\s*int\s*=\s*"([^"]*)"', "Integer variable assigned string value"),
                        (r'var\s+(\w+):\s*Array\[(\w+)\]\s*=\s*\{\}', "Array variable assigned Dictionary"),
                        (r'var\s+(\w+):\s*Dictionary\s*=\s*\[\]', "Dictionary variable assigned Array"),
                    ]
                    
                    for pattern, error_msg in type_patterns:
                        if re.search(pattern, line_stripped):
                            errors.append(SyntaxContextError(
                                file_path=str(file_path),
                                line_number=line_num,
                                error_type="TYPE_MISMATCH",
                                error_message=error_msg,
                                suggested_fix=f"Check variable type and assignment on line {line_num}",
                                severity="critical"
                            ))
                    
                    # Missing null checks
                    if re.search(r'(\w+)\.(\w+)\(' , line_stripped) and 'if' not in line_stripped and 'null' not in line_stripped:
                        # Check if this is a potential null reference
                        var_name = re.search(r'(\w+)\.', line_stripped)
                        if var_name and var_name.group(1) not in ['print', 'push_error', 'push_warning']:
                            errors.append(SyntaxContextError(
                                file_path=str(file_path),
                                line_number=line_num,
                                error_type="POTENTIAL_NULL_REFERENCE",
                                error_message=f"Potential null reference: {var_name.group(1)}",
                                suggested_fix=f"Add null check: if {var_name.group(1)}: before method call",
                                severity="warning"
                            ))
                    
                    # Incorrect signal connections
                    if '.connect(' in line_stripped and 'signal' not in line_stripped:
                        if not re.search(r'\.connect\s*\(\s*["\']?\w+["\']?\s*,\s*\w+\.\w+\s*\)', line_stripped):
                            errors.append(SyntaxContextError(
                                file_path=str(file_path),
                                line_number=line_num,
                                error_type="SIGNAL_CONNECTION_SYNTAX",
                                error_message="Potential signal connection syntax error",
                                suggested_fix="Verify signal connection syntax: signal_name.connect(callable)",
                                severity="warning"
                            ))
                    
                    # Missing return types
                    if line_stripped.startswith('func ') and '->' not in line_stripped and ':' in line_stripped:
                        if 'void' not in line_stripped:
                            errors.append(SyntaxContextError(
                                file_path=str(file_path),
                                line_number=line_num,
                                error_type="MISSING_RETURN_TYPE",
                                error_message="Function missing return type annotation",
                                suggested_fix="Add return type: func name() -> ReturnType:",
                                severity="suggestion"
                            ))
                            
            except Exception as e:
                errors.append(SyntaxContextError(
                    file_path=str(file_path),
                    line_number=0,
                    error_type="FILE_READ_ERROR",
                    error_message=f"Could not read file: {str(e)}",
                    suggested_fix="Check file encoding and permissions",
                    severity="critical"
                ))
        
        return errors
    
    def _validate_resources(self, changed_file: str = None) -> List[str]:
        """Validate that all resource references exist"""
        missing_resources = []
        
        files_to_check = self._get_files_to_validate(changed_file)
        
        for file_path in files_to_check:
            if not file_path.suffix == '.gd':
                continue
                
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Find preload and load statements
                preload_pattern = r'preload\s*\(\s*["\']([^"\']+)["\']\s*\)'
                load_pattern = r'load\s*\(\s*["\']([^"\']+)["\']\s*\)'
                
                for pattern in [preload_pattern, load_pattern]:
                    matches = re.findall(pattern, content)
                    for resource_path in matches:
                        # Convert relative path to absolute
                        if resource_path.startswith('res://'):
                            abs_path = self.project_root / resource_path[6:]  # Remove 'res://'
                        else:
                            abs_path = file_path.parent / resource_path
                        
                        if not abs_path.exists():
                            missing_resources.append(f"{file_path}: {resource_path}")
                            
            except Exception as e:
                missing_resources.append(f"{file_path}: Error reading file - {str(e)}")
        
        return missing_resources
    
    def _detect_type_mismatches(self, changed_file: str = None) -> List[SyntaxContextError]:
        """Detect type mismatches that could cause runtime errors"""
        errors = []
        
        files_to_check = self._get_files_to_validate(changed_file)
        
        for file_path in files_to_check:
            if not file_path.suffix == '.gd':
                continue
                
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    lines = content.split('\n')
                
                # Track variable types
                var_types = {}
                
                for line_num, line in enumerate(lines, 1):
                    line_stripped = line.strip()
                    
                    # Track variable declarations
                    var_match = re.search(r'var\s+(\w+):\s*(\w+)', line_stripped)
                    if var_match:
                        var_name, var_type = var_match.groups()
                        var_types[var_name] = var_type
                    
                    # Check assignments to typed variables
                    assign_match = re.search(r'(\w+)\s*=\s*(.+)', line_stripped)
                    if assign_match:
                        var_name, assignment = assign_match.groups()
                        if var_name in var_types:
                            expected_type = var_types[var_name]
                            
                            # Simple type checking
                            if expected_type == "String" and assignment.isdigit():
                                errors.append(SyntaxContextError(
                                    file_path=str(file_path),
                                    line_number=line_num,
                                    error_type="TYPE_MISMATCH",
                                    error_message=f"String variable '{var_name}' assigned numeric value",
                                    suggested_fix=f"Convert to string: {var_name} = str({assignment})",
                                    severity="critical"
                                ))
                            elif expected_type == "int" and assignment.startswith('"'):
                                errors.append(SyntaxContextError(
                                    file_path=str(file_path),
                                    line_number=line_num,
                                    error_type="TYPE_MISMATCH",
                                    error_message=f"Integer variable '{var_name}' assigned string value",
                                    suggested_fix=f"Convert to int: {var_name} = int({assignment})",
                                    severity="critical"
                                ))
                            
            except Exception as e:
                errors.append(SyntaxContextError(
                    file_path=str(file_path),
                    line_number=0,
                    error_type="FILE_READ_ERROR",
                    error_message=f"Could not analyze types: {str(e)}",
                    suggested_fix="Check file syntax",
                    severity="critical"
                ))
        
        return errors
    
    def _validate_signal_connections(self, changed_file: str = None) -> List[SyntaxContextError]:
        """Validate signal connections and detect missing signals"""
        errors = []
        
        files_to_check = self._get_files_to_validate(changed_file)
        
        for file_path in files_to_check:
            if not file_path.suffix == '.gd':
                continue
                
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    lines = content.split('\n')
                
                # Track signal definitions
                signals_defined = set()
                signal_connections = []
                
                for line_num, line in enumerate(lines, 1):
                    line_stripped = line.strip()
                    
                    # Find signal definitions
                    signal_match = re.search(r'signal\s+(\w+)', line_stripped)
                    if signal_match:
                        signals_defined.add(signal_match.group(1))
                    
                    # Find signal connections
                    connect_match = re.search(r'(\w+)\.connect\s*\(\s*([^,)]+)', line_stripped)
                    if connect_match:
                        signal_connections.append((line_num, connect_match.group(1), connect_match.group(2)))
                
                # Validate connections
                for line_num, object_name, signal_ref in signal_connections:
                    # Simple validation - more complex analysis would require AST
                    if '.' in signal_ref:
                        # Format: object.signal_name
                        signal_name = signal_ref.split('.')[-1]
                        if signal_name not in signals_defined:
                            errors.append(SyntaxContextError(
                                file_path=str(file_path),
                                line_number=line_num,
                                error_type="UNDEFINED_SIGNAL",
                                error_message=f"Signal '{signal_name}' may not be defined",
                                suggested_fix=f"Check if signal '{signal_name}' is properly defined",
                                severity="warning"
                            ))
                            
            except Exception as e:
                errors.append(SyntaxContextError(
                    file_path=str(file_path),
                    line_number=0,
                    error_type="FILE_READ_ERROR",
                    error_message=f"Could not analyze signals: {str(e)}",
                    suggested_fix="Check file syntax",
                    severity="warning"
                ))
        
        return errors
    
    def _validate_data_flows(self, changed_file: str = None) -> List[SyntaxContextError]:
        """Validate data flow patterns that could break at runtime"""
        errors = []
        
        files_to_check = self._get_files_to_validate(changed_file)
        
        for file_path in files_to_check:
            if not file_path.suffix == '.gd':
                continue
                
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    lines = content.split('\n')
                
                for line_num, line in enumerate(lines, 1):
                    line_stripped = line.strip()
                    
                    # Array access without bounds checking
                    array_access = re.search(r'(\w+)\[(\d+|\w+)\]', line_stripped)
                    if array_access and 'size()' not in line_stripped and 'length' not in line_stripped:
                        var_name, index = array_access.groups()
                        if index.isdigit():
                            errors.append(SyntaxContextError(
                                file_path=str(file_path),
                                line_number=line_num,
                                error_type="UNSAFE_ARRAY_ACCESS",
                                error_message=f"Array access without bounds check: {var_name}[{index}]",
                                suggested_fix=f"Add bounds check: if {var_name}.size() > {index}:",
                                severity="warning"
                            ))
                    
                    # Dictionary access without key checking
                    dict_access = re.search(r'(\w+)\[[\'""]([^\'""]+)[\'"\"]\]', line_stripped)
                    if dict_access and 'has(' not in line_stripped and 'get(' not in line_stripped:
                        var_name, key = dict_access.groups()
                        errors.append(SyntaxContextError(
                            file_path=str(file_path),
                            line_number=line_num,
                            error_type="UNSAFE_DICT_ACCESS",
                            error_message=f"Dictionary access without key check: {var_name}['{key}']",
                            suggested_fix=f"Use safe access: {var_name}.get('{key}', default_value)",
                            severity="warning"
                        ))
                    
                    # Method calls on potentially null objects
                    method_call = re.search(r'(\w+)\.(\w+)\s*\(', line_stripped)
                    if method_call and 'if' not in line_stripped:
                        obj_name, method_name = method_call.groups()
                        # Skip known safe patterns
                        if obj_name not in ['print', 'push_error', 'push_warning', 'str', 'int', 'float']:
                            errors.append(SyntaxContextError(
                                file_path=str(file_path),
                                line_number=line_num,
                                error_type="POTENTIAL_NULL_METHOD_CALL",
                                error_message=f"Method call on potentially null object: {obj_name}.{method_name}()",
                                suggested_fix=f"Add null check: if {obj_name} and {obj_name}.has_method('{method_name}'):",
                                severity="suggestion"
                            ))
                            
            except Exception as e:
                errors.append(SyntaxContextError(
                    file_path=str(file_path),
                    line_number=0,
                    error_type="FILE_READ_ERROR",
                    error_message=f"Could not analyze data flows: {str(e)}",
                    suggested_fix="Check file syntax",
                    severity="warning"
                ))
        
        return errors
    
    def _validate_context_integrity(self, changed_file: str = None) -> List[SyntaxContextError]:
        """Validate context and integration integrity"""
        errors = []
        
        # Check for missing autoload references
        autoload_references = ["GameStateManager", "DataManagerAutoload", "SystemsAutoload"]
        
        files_to_check = self._get_files_to_validate(changed_file)
        
        for file_path in files_to_check:
            if not file_path.suffix == '.gd':
                continue
                
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    lines = content.split('\n')
                
                for line_num, line in enumerate(lines, 1):
                    line_stripped = line.strip()
                    
                    # Check for undefined autoload usage
                    for autoload in autoload_references:
                        if autoload in line_stripped and 'preload' not in line_stripped:
                            # Simple check - this would need project.godot parsing for accuracy
                            if not re.search(r'@?onready\s+var.*' + autoload, line_stripped):
                                errors.append(SyntaxContextError(
                                    file_path=str(file_path),
                                    line_number=line_num,
                                    error_type="AUTOLOAD_REFERENCE",
                                    error_message=f"Reference to autoload '{autoload}' - verify it's configured",
                                    suggested_fix=f"Ensure '{autoload}' is configured in project autoloads",
                                    severity="suggestion"
                                ))
                    
                    # Check for scene tree access patterns
                    if 'get_tree()' in line_stripped and 'await' not in line_stripped:
                        if 'current_scene' in line_stripped or 'change_scene' in line_stripped:
                            errors.append(SyntaxContextError(
                                file_path=str(file_path),
                                line_number=line_num,
                                error_type="SCENE_TREE_ACCESS",
                                error_message="Scene tree access pattern detected",
                                suggested_fix="Ensure scene tree access is properly handled",
                                severity="suggestion"
                            ))
                            
            except Exception as e:
                errors.append(SyntaxContextError(
                    file_path=str(file_path),
                    line_number=0,
                    error_type="FILE_READ_ERROR",
                    error_message=f"Could not analyze context: {str(e)}",
                    suggested_fix="Check file syntax",
                    severity="warning"
                ))
        
        return errors
    
    def _get_files_to_validate(self, changed_file: str = None) -> List[Path]:
        """Get list of files to validate"""
        if changed_file:
            # If specific file provided, also check related files
            changed_path = Path(changed_file)
            files = [changed_path]
            
            # Add related files based on your existing mapping logic
            test_paths = self.get_relevant_tests(changed_file)
            for test_path in test_paths:
                files.extend(Path(test_path).glob('**/*.gd'))
        else:
            # Check all source files
            files = list(self.project_root.glob('src/**/*.gd'))
            files.extend(self.project_root.glob('scripts/**/*.gd'))
        
        return [f for f in files if f.exists() and f.is_file()]
    
    def _calculate_backend_health(self, result: BackendValidationResult) -> None:
        """Calculate overall backend health"""
        total_issues = (
            len(result.syntax_errors) +
            len(result.context_errors) +
            len(result.missing_resources) +
            len(result.type_mismatches) +
            len(result.signal_connection_issues) +
            len(result.data_flow_errors)
        )
        
        critical_issues = sum(1 for error_list in [
            result.syntax_errors,
            result.context_errors,
            result.type_mismatches,
            result.signal_connection_issues,
            result.data_flow_errors
        ] for error in error_list if error.severity == "critical")
        
        critical_issues += len(result.missing_resources)  # Missing resources are always critical
        
        result.total_issues = total_issues
        result.critical_issues = critical_issues
        
        if critical_issues > 0:
            result.overall_health = "critical"
        elif total_issues > 10:
            result.overall_health = "warning"
        else:
            result.overall_health = "healthy"
    
    def _parse_test_output(self, stdout: str, stderr: str) -> Dict:
        """
        Parse GDUnit4 test output to extract structured results
        """
        results = {
            "tests_run": 0,
            "tests_passed": 0,
            "tests_failed": 0,
            "errors": []
        }
        
        # Try to parse JSON output if available
        try:
            if stdout.strip():
                json_data = json.loads(stdout)
                if isinstance(json_data, dict):
                    results.update(json_data)
                    return results
        except json.JSONDecodeError:
            pass
            
        # Fall back to text parsing
        output_lines = (stdout + stderr).split('\n')
        
        for line in output_lines:
            line = line.strip()
            
            # Parse test counts
            if "tests passed" in line.lower():
                try:
                    results["tests_passed"] = int(line.split()[0])
                except (ValueError, IndexError):
                    pass
                    
            if "tests failed" in line.lower():
                try:
                    results["tests_failed"] = int(line.split()[0])
                except (ValueError, IndexError):
                    pass
                    
            if "error:" in line.lower():
                results["errors"].append(line)
                
        results["tests_run"] = results["tests_passed"] + results["tests_failed"]
        return results
    
    def run_full_suite(self) -> TestExecution:
        """
        Run the complete test suite for comprehensive validation
        """
        print("[TEST] Running complete GDUnit4 test suite...")
        
        start_time = time.time()
        
        cmd = [
            str(self.godot_path),
            "--headless", 
            "--script",
            "run_tests.gd"
        ]
        
        try:
            result = subprocess.run(
                cmd,
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=600  # 10 minute timeout for full suite
            )
            
            duration = time.time() - start_time
            test_results = self._parse_test_output(result.stdout, result.stderr)
            
            overall_result = TestResult.SUCCESS if result.returncode == 0 else TestResult.FAILURE
            
            return TestExecution(
                result=overall_result,
                duration=duration,
                tests_run=test_results["tests_run"],
                tests_passed=test_results["tests_passed"],
                tests_failed=test_results["tests_failed"],
                coverage_percentage=0.0,  # Full coverage analysis would need additional tooling
                output=result.stdout,
                error_details=test_results.get("errors", [])
            )
            
        except subprocess.TimeoutExpired:
            return TestExecution(
                result=TestResult.TIMEOUT,
                duration=600.0,
                tests_run=0,
                tests_passed=0,
                tests_failed=0,
                coverage_percentage=0.0,
                output="Full test suite timed out",
                error_details=["Test suite exceeded 10 minute timeout"]
            )

def main():
    """
    Command-line interface for the test runner
    Designed for integration with Claude Hooks
    """
    parser = argparse.ArgumentParser(
        description="Five Parsecs Campaign Manager - Intelligent Test Runner"
    )
    
    parser.add_argument(
        "--mode",
        choices=["targeted", "full", "backend", "complete"],
        default="targeted",
        help="Test execution mode: targeted (file-based), full (all tests), backend (syntax/context validation), complete (all validations)"
    )
    
    parser.add_argument(
        "--changed-file",
        help="Path to the file that was changed (for targeted mode)"
    )
    
    parser.add_argument(
        "--godot-path",
        required=True,
        help="Path to Godot console executable"
    )
    
    parser.add_argument(
        "--output-format",
        choices=["json", "text"],
        default="text",
        help="Output format for results"
    )
    
    args = parser.parse_args()
    
    # Initialize test runner
    project_root = os.getcwd()
    runner = TargetedTestRunner(project_root, args.godot_path)
    
    # Execute tests based on mode
    if args.mode == "targeted" and args.changed_file:
        execution = runner.run_targeted_tests(args.changed_file)
    elif args.mode == "backend":
        # Run comprehensive backend validation
        backend_result = runner.run_full_backend_validation(args.changed_file)
        _output_backend_results(backend_result, args.output_format)
        sys.exit(0 if backend_result.overall_health != "critical" else 1)
    elif args.mode == "complete":
        # Run both backend validation and tests
        backend_result = runner.run_full_backend_validation(args.changed_file)
        if backend_result.critical_issues > 0:
            print("[COMPLETE] Critical backend issues found, skipping tests")
            _output_backend_results(backend_result, args.output_format)
            sys.exit(1)
        else:
            execution = runner.run_full_suite()
            _output_test_results(execution, args.output_format)
            _output_backend_results(backend_result, "text")  # Always show backend summary
            sys.exit(0 if execution.result == TestResult.SUCCESS else 1)
    else:
        execution = runner.run_full_suite()
        _output_test_results(execution, args.output_format)
        sys.exit(0 if execution.result == TestResult.SUCCESS else 1)
    
def _output_test_results(execution: TestExecution, output_format: str) -> None:
    """Output test execution results"""
    if output_format == "json":
        result_data = {
            "result": execution.result.value,
            "duration": execution.duration,
            "tests_run": execution.tests_run,
            "tests_passed": execution.tests_passed,
            "tests_failed": execution.tests_failed,
            "coverage": execution.coverage_percentage,
            "errors": execution.error_details
        }
        print(json.dumps(result_data, indent=2))
    else:
        print(f"\n[STATUS] Test Execution Summary")
        print(f"Result: {execution.result.value.upper()}")
        print(f"Duration: {execution.duration:.2f}s")
        print(f"Tests Run: {execution.tests_run}")
        print(f"Passed: {execution.tests_passed}")
        print(f"Failed: {execution.tests_failed}")
        
        if execution.error_details:
            print(f"\n[FAIL] Errors:")
            for error in execution.error_details:
                print(f"  • {error}")

def _output_backend_results(backend_result: BackendValidationResult, output_format: str) -> None:
    """Output comprehensive backend validation results"""
    if output_format == "json":
        result_data = {
            "overall_health": backend_result.overall_health,
            "total_issues": backend_result.total_issues,
            "critical_issues": backend_result.critical_issues,
            "syntax_errors": len(backend_result.syntax_errors),
            "context_errors": len(backend_result.context_errors),
            "type_mismatches": len(backend_result.type_mismatches),
            "signal_issues": len(backend_result.signal_connection_issues),
            "data_flow_errors": len(backend_result.data_flow_errors),
            "missing_resources": len(backend_result.missing_resources),
            "details": {
                "syntax_errors": [
                    {
                        "file": e.file_path,
                        "line": e.line_number,
                        "type": e.error_type,
                        "message": e.error_message,
                        "fix": e.suggested_fix,
                        "severity": e.severity
                    } for e in backend_result.syntax_errors
                ],
                "missing_resources": backend_result.missing_resources
            }
        }
        print(json.dumps(result_data, indent=2))
    else:
        print(f"\n[E2E BACKEND] Backend Validation Summary")
        print(f"Overall Health: {backend_result.overall_health.upper()}")
        print(f"Total Issues: {backend_result.total_issues}")
        print(f"Critical Issues: {backend_result.critical_issues}")
        print()
        
        # Category breakdown
        categories = [
            ("Syntax Errors", backend_result.syntax_errors),
            ("Type Mismatches", backend_result.type_mismatches),
            ("Context Errors", backend_result.context_errors),
            ("Signal Issues", backend_result.signal_connection_issues),
            ("Data Flow Errors", backend_result.data_flow_errors),
        ]
        
        for category_name, errors in categories:
            if errors:
                print(f"[{category_name.upper()}] {len(errors)} issues found:")
                for error in errors[:5]:  # Show first 5 errors per category
                    print(f"  🔍 {error.file_path}:{error.line_number}")
                    print(f"     {error.error_message}")
                    print(f"     💡 {error.suggested_fix}")
                    print()
                if len(errors) > 5:
                    print(f"  ... and {len(errors) - 5} more {category_name.lower()}")
                print()
        
        if backend_result.missing_resources:
            print(f"[MISSING RESOURCES] {len(backend_result.missing_resources)} missing:")
            for resource in backend_result.missing_resources[:5]:
                print(f"  ❌ {resource}")
            if len(backend_result.missing_resources) > 5:
                print(f"  ... and {len(backend_result.missing_resources) - 5} more missing resources")
            print()
        
        # Health-based recommendations
        if backend_result.overall_health == "critical":
            print("🚨 CRITICAL: Fix these issues before user testing!")
        elif backend_result.overall_health == "warning":
            print("⚠️  WARNING: Consider fixing these issues before release")
        else:
            print("✅ HEALTHY: Backend validation passed!")

if __name__ == "__main__":
    main()