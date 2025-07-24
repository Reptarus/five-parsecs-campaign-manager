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
from pathlib import Path
from typing import Dict, List, Optional, NamedTuple
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
        choices=["targeted", "full"],
        default="targeted",
        help="Test execution mode"
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
    else:
        execution = runner.run_full_suite()
    
    # Output results
    if args.output_format == "json":
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
    
    # Exit with appropriate code
    sys.exit(0 if execution.result == TestResult.SUCCESS else 1)

if __name__ == "__main__":
    main()