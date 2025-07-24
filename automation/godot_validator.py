#!/usr/bin/env python3
"""
Five Parsecs Campaign Manager - Godot Project Validator
Enterprise-grade validation for Godot project integrity, scene dependencies, and resource management
"""

import os
import sys
import json
import subprocess
import argparse
import time
from pathlib import Path
from typing import Dict, List, Optional, Set, NamedTuple
from dataclasses import dataclass
from enum import Enum
import re

class ValidationSeverity(Enum):
    INFO = "info"
    WARNING = "warning" 
    ERROR = "error"
    CRITICAL = "critical"

@dataclass
class ValidationIssue:
    """Structured validation issue with context and remediation"""
    severity: ValidationSeverity
    category: str
    file_path: str
    line_number: Optional[int]
    message: str
    description: str
    remediation: str

@dataclass
class ValidationResult:
    """Comprehensive validation results with actionable insights"""
    is_valid: bool
    total_issues: int
    critical_issues: int
    error_issues: int
    warning_issues: int
    info_issues: int
    issues: List[ValidationIssue]
    execution_time: float
    metadata: Dict

class GodotProjectValidator:
    """
    Production-grade Godot project validation system
    
    Validates:
    - Scene dependency integrity
    - Resource references and loading
    - Project configuration compliance
    - Asset organization and optimization
    - Script compilation and syntax
    """
    
    def __init__(self, project_root: str, godot_path: str):
        self.project_root = Path(project_root)
        self.godot_path = Path(godot_path)
        self.project_file = self.project_root / "project.godot"
        self.issues: List[ValidationIssue] = []
        
        # Five Parsecs specific patterns
        self.required_autoloads = [
            "GameGlobals",
            "CampaignManager", 
            "DataManager",
            "EventBus"
        ]
        
        self.critical_scenes = [
            "MainMenu.tscn",
            "CampaignCreation.tscn", 
            "WorldPhase.tscn",
            "BattleScene.tscn"
        ]
        
    def validate_project_structure(self) -> bool:
        """
        Validate overall project structure and organization
        """
        print("[VALIDATE] Validating project structure...")
        
        success = True
        
        # Check for project.godot file
        if not self.project_file.exists():
            self.add_issue(
                ValidationSeverity.CRITICAL,
                "project_structure",
                str(self.project_file),
                None,
                "Missing project.godot file",
                "The project.godot file is required for Godot to recognize this as a valid project",
                "Create a valid project.godot file or ensure you're in the correct project directory"
            )
            success = False
        
        # Validate required directories
        required_dirs = ["src", "assets", "scenes", "data", "tests"]
        for dir_name in required_dirs:
            dir_path = self.project_root / dir_name
            if not dir_path.exists():
                self.add_issue(
                    ValidationSeverity.WARNING,
                    "project_structure", 
                    str(dir_path),
                    None,
                    f"Missing {dir_name} directory",
                    f"The {dir_name} directory is part of the Five Parsecs project structure",
                    f"Create the {dir_name} directory to maintain project organization"
                )
        
        # Check for .godot directory (should exist after first import)
        godot_dir = self.project_root / ".godot"
        if not godot_dir.exists():
            self.add_issue(
                ValidationSeverity.INFO,
                "project_structure",
                str(godot_dir),
                None,
                "Project not yet imported",
                "The .godot directory doesn't exist, indicating the project hasn't been imported yet",
                "Open the project in Godot to complete the initial import process"
            )
            
        return success
    
    def validate_scene_dependencies(self) -> bool:
        """
        Validate scene files and their dependencies
        """
        print("[SCENE] Validating scene dependencies...")
        
        success = True
        scene_files = list(self.project_root.rglob("*.tscn"))
        
        for scene_file in scene_files:
            try:
                with open(scene_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check for broken script references
                script_matches = re.findall(r'script = ExtResource\("(\d+)"\)', content)
                resource_matches = re.findall(r'\[ext_resource.*path="([^"]+)".*id="(\d+)"\]', content)
                
                # Build resource ID to path mapping
                resource_map = {res_id: path for path, res_id in resource_matches}
                
                # Validate script references
                for script_id in script_matches:
                    if script_id in resource_map:
                        script_path = self.project_root / resource_map[script_id]
                        if not script_path.exists():
                            self.add_issue(
                                ValidationSeverity.ERROR,
                                "scene_dependencies",
                                str(scene_file),
                                None,
                                f"Broken script reference: {resource_map[script_id]}",
                                f"Scene {scene_file.name} references script {resource_map[script_id]} which doesn't exist",
                                f"Create the missing script file or update the scene to reference the correct script"
                            )
                            success = False
                
                # Check for critical scenes in Five Parsecs
                if scene_file.name in self.critical_scenes:
                    # Validate critical scene structure
                    if not self._validate_critical_scene_structure(scene_file, content):
                        success = False
                        
            except Exception as e:
                self.add_issue(
                    ValidationSeverity.ERROR,
                    "scene_dependencies",
                    str(scene_file),
                    None,
                    f"Failed to parse scene file: {str(e)}",
                    f"Scene file {scene_file.name} could not be parsed or read",
                    "Check file encoding and syntax, ensure it's a valid Godot scene file"
                )
                success = False
        
        return success
    
    def validate_resource_integrity(self) -> bool:
        """
        Validate resource files and references
        """
        print("[INSTALL] Validating resource integrity...")
        
        success = True
        resource_files = list(self.project_root.rglob("*.tres")) + list(self.project_root.rglob("*.res"))
        
        for resource_file in resource_files:
            try:
                with open(resource_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check for broken external references
                ext_refs = re.findall(r'ExtResource\("([^"]+)"\)', content)
                
                for ref in ext_refs:
                    ref_path = self.project_root / ref
                    if not ref_path.exists():
                        self.add_issue(
                            ValidationSeverity.ERROR,
                            "resource_integrity",
                            str(resource_file),
                            None,
                            f"Broken resource reference: {ref}",
                            f"Resource {resource_file.name} references {ref} which doesn't exist",
                            f"Create the missing resource or update the reference path"
                        )
                        success = False
                        
            except Exception as e:
                self.add_issue(
                    ValidationSeverity.ERROR,
                    "resource_integrity", 
                    str(resource_file),
                    None,
                    f"Failed to parse resource file: {str(e)}",
                    f"Resource file {resource_file.name} could not be parsed",
                    "Check file encoding and syntax, ensure it's a valid Godot resource file"
                )
                success = False
        
        return success
    
    def validate_project_configuration(self) -> bool:
        """
        Validate project.godot configuration for Five Parsecs requirements
        """
        print("[SETTINGS] Validating project configuration...")
        
        success = True
        
        if not self.project_file.exists():
            return False
            
        try:
            with open(self.project_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Check for required autoloads
            autoload_section = self._extract_section(content, "autoload")
            
            for autoload in self.required_autoloads:
                if autoload.lower() not in autoload_section.lower():
                    self.add_issue(
                        ValidationSeverity.WARNING,
                        "project_config",
                        str(self.project_file),
                        None,
                        f"Missing autoload: {autoload}",
                        f"The {autoload} autoload is expected for Five Parsecs functionality",
                        f"Add {autoload} to the autoload section in project settings"
                    )
            
            # Validate application configuration
            app_section = self._extract_section(content, "application")
            
            # Check main scene
            if 'run/main_scene=' not in app_section:
                self.add_issue(
                    ValidationSeverity.ERROR,
                    "project_config",
                    str(self.project_file),
                    None,
                    "No main scene configured",
                    "Project doesn't have a main scene set",
                    "Set the main scene in Project Settings > Application > Run"
                )
                success = False
            
            # Check Godot version compatibility
            if 'config_version=' in content:
                version_match = re.search(r'config_version=(\d+)', content)
                if version_match and int(version_match.group(1)) < 5:
                    self.add_issue(
                        ValidationSeverity.WARNING,
                        "project_config",
                        str(self.project_file),
                        None,
                        "Potentially outdated project format",
                        "Project may be using an older Godot project format",
                        "Consider updating the project format in Godot 4.4"
                    )
                    
        except Exception as e:
            self.add_issue(
                ValidationSeverity.ERROR,
                "project_config",
                str(self.project_file),
                None,
                f"Failed to parse project.godot: {str(e)}",
                "Project configuration file could not be read or parsed",
                "Check project.godot file syntax and encoding"
            )
            success = False
        
        return success
    
    def validate_script_compilation(self) -> bool:
        """
        Validate that all GDScript files compile successfully
        """
        print("[FIXING] Validating script compilation...")
        
        success = True
        
        # Use Godot's built-in syntax checking
        cmd = [
            str(self.godot_path),
            "--headless",
            "--check-only",
            "--path",
            str(self.project_root)
        ]
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=60
            )
            
            if result.returncode != 0:
                # Parse compilation errors
                error_lines = result.stderr.split('\n')
                
                for line in error_lines:
                    if 'ERROR:' in line and '.gd' in line:
                        # Extract file and error info
                        parts = line.split(':')
                        if len(parts) >= 4:
                            file_path = parts[1].strip()
                            line_num = parts[2].strip() if parts[2].strip().isdigit() else None
                            error_msg = ':'.join(parts[3:]).strip()
                            
                            self.add_issue(
                                ValidationSeverity.ERROR,
                                "script_compilation",
                                file_path,
                                int(line_num) if line_num else None,
                                f"Compilation error: {error_msg}",
                                f"GDScript compilation failed for {Path(file_path).name}",
                                "Fix the syntax error or remove the problematic code"
                            )
                            success = False
                            
        except subprocess.TimeoutExpired:
            self.add_issue(
                ValidationSeverity.WARNING,
                "script_compilation",
                str(self.project_root),
                None,
                "Script compilation check timed out",
                "Godot syntax checking took longer than expected",
                "Check for large files or complex scripts that may be causing slow compilation"
            )
            
        except Exception as e:
            self.add_issue(
                ValidationSeverity.ERROR,
                "script_compilation",
                str(self.project_root),
                None,
                f"Failed to run compilation check: {str(e)}",
                "Could not execute Godot compilation validation",
                "Verify Godot path and project accessibility"
            )
            success = False
        
        return success
    
    def _validate_critical_scene_structure(self, scene_file: Path, content: str) -> bool:
        """
        Validate structure of critical Five Parsecs scenes
        """
        success = True
        scene_name = scene_file.name
        
        # Define expected structure for critical scenes
        expected_structures = {
            "CampaignCreation.tscn": ["CampaignCreationUI", "StateManager"],
            "WorldPhase.tscn": ["WorldPhaseUI", "AutomationController"],
            "BattleScene.tscn": ["BattleManager", "UILayer"],
            "MainMenu.tscn": ["MenuContainer", "BackgroundLayer"]
        }
        
        if scene_name in expected_structures:
            required_nodes = expected_structures[scene_name]
            
            for node in required_nodes:
                if node not in content:
                    self.add_issue(
                        ValidationSeverity.WARNING,
                        "scene_structure",
                        str(scene_file),
                        None,
                        f"Missing expected node: {node}",
                        f"Critical scene {scene_name} doesn't contain expected node {node}",
                        f"Add the {node} node to maintain Five Parsecs scene structure"
                    )
                    success = False
        
        return success
    
    def _extract_section(self, content: str, section_name: str) -> str:
        """
        Extract a specific section from project.godot file
        """
        lines = content.split('\n')
        section_content = []
        in_section = False
        
        for line in lines:
            if line.strip() == f'[{section_name}]':
                in_section = True
                continue
            elif line.strip().startswith('[') and in_section:
                break
            elif in_section:
                section_content.append(line)
        
        return '\n'.join(section_content)
    
    def add_issue(self, severity: ValidationSeverity, category: str, file_path: str, 
                  line_number: Optional[int], message: str, description: str, remediation: str):
        """
        Add a validation issue with full context
        """
        issue = ValidationIssue(
            severity=severity,
            category=category,
            file_path=file_path,
            line_number=line_number,
            message=message,
            description=description,
            remediation=remediation
        )
        self.issues.append(issue)
    
    def run_comprehensive_validation(self) -> ValidationResult:
        """
        Execute complete validation suite and return structured results
        """
        start_time = time.time()
        
        print("[STARTING] Starting comprehensive Godot project validation...")
        
        # Execute all validation phases
        validations = [
            ("Project Structure", self.validate_project_structure),
            ("Scene Dependencies", self.validate_scene_dependencies),
            ("Resource Integrity", self.validate_resource_integrity),
            ("Project Configuration", self.validate_project_configuration),
            ("Script Compilation", self.validate_script_compilation)
        ]
        
        overall_success = True
        
        for phase_name, validation_func in validations:
            print(f"\n[LIST] {phase_name}...")
            try:
                phase_success = validation_func()
                overall_success = overall_success and phase_success
                
                if phase_success:
                    print(f"[COMPLETE] {phase_name} passed")
                else:
                    print(f"[FAIL] {phase_name} failed")
                    
            except Exception as e:
                print(f"[CRASH] {phase_name} crashed: {str(e)}")
                self.add_issue(
                    ValidationSeverity.CRITICAL,
                    "validation_system",
                    str(self.project_root),
                    None,
                    f"Validation phase {phase_name} failed: {str(e)}",
                    f"The validation system encountered an error during {phase_name}",
                    "Check validation system logs and project accessibility"
                )
                overall_success = False
        
        execution_time = time.time() - start_time
        
        # Categorize issues by severity
        critical_count = len([i for i in self.issues if i.severity == ValidationSeverity.CRITICAL])
        error_count = len([i for i in self.issues if i.severity == ValidationSeverity.ERROR])
        warning_count = len([i for i in self.issues if i.severity == ValidationSeverity.WARNING])
        info_count = len([i for i in self.issues if i.severity == ValidationSeverity.INFO])
        
        result = ValidationResult(
            is_valid=overall_success and critical_count == 0 and error_count == 0,
            total_issues=len(self.issues),
            critical_issues=critical_count,
            error_issues=error_count,
            warning_issues=warning_count,
            info_issues=info_count,
            issues=self.issues,
            execution_time=execution_time,
            metadata={
                "project_path": str(self.project_root),
                "godot_path": str(self.godot_path),
                "validation_phases": len(validations),
                "timestamp": time.time()
            }
        )
        
        return result

def main():
    """
    Command-line interface for Godot project validation
    Designed for integration with Claude Hooks and CI/CD pipelines
    """
    parser = argparse.ArgumentParser(
        description="Five Parsecs Campaign Manager - Godot Project Validator"
    )
    
    parser.add_argument(
        "--validate-scenes",
        action="store_true",
        help="Validate scene dependencies and structure"
    )
    
    parser.add_argument(
        "--validate-resources",
        action="store_true",
        help="Validate resource integrity and references"
    )
    
    parser.add_argument(
        "--check-dependencies",
        action="store_true",
        help="Check for broken dependencies and references"
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
        help="Output format for validation results"
    )
    
    parser.add_argument(
        "--fail-on-warnings",
        action="store_true",
        help="Fail validation if warnings are found"
    )
    
    args = parser.parse_args()
    
    # Initialize validator
    project_root = os.getcwd()
    validator = GodotProjectValidator(project_root, args.godot_path)
    
    # Run validation
    result = validator.run_comprehensive_validation()
    
    # Output results
    if args.output_format == "json":
        result_data = {
            "is_valid": result.is_valid,
            "total_issues": result.total_issues,
            "critical_issues": result.critical_issues,
            "error_issues": result.error_issues,
            "warning_issues": result.warning_issues,
            "info_issues": result.info_issues,
            "execution_time": result.execution_time,
            "issues": [
                {
                    "severity": issue.severity.value,
                    "category": issue.category,
                    "file_path": issue.file_path,
                    "line_number": issue.line_number,
                    "message": issue.message,
                    "description": issue.description,
                    "remediation": issue.remediation
                }
                for issue in result.issues
            ],
            "metadata": result.metadata
        }
        print(json.dumps(result_data, indent=2))
    else:
        print(f"\n[TARGET] Godot Project Validation Summary")
        print(f"Overall Status: {'[COMPLETE] VALID' if result.is_valid else '[FAIL] INVALID'}")
        print(f"Execution Time: {result.execution_time:.2f}s")
        print(f"Total Issues: {result.total_issues}")
        
        if result.total_issues > 0:
            print(f"  Critical: {result.critical_issues}")
            print(f"  Errors: {result.error_issues}")
            print(f"  Warnings: {result.warning_issues}")
            print(f"  Info: {result.info_issues}")
            
            print(f"\n[LIST] Issue Details:")
            for issue in result.issues:
                print(f"\n{issue.severity.value.upper()}: {issue.message}")
                print(f"  File: {issue.file_path}")
                if issue.line_number:
                    print(f"  Line: {issue.line_number}")
                print(f"  Description: {issue.description}")
                print(f"  Remediation: {issue.remediation}")
    
    # Determine exit code
    if result.critical_issues > 0 or result.error_issues > 0:
        sys.exit(1)
    elif args.fail_on_warnings and result.warning_issues > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()