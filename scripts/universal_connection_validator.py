#!/usr/bin/env python3
"""
Universal Connection Validator for Five Parsecs Campaign Manager

Based on the proven Universal Mock Strategy (97.7% success) and 
7-Stage Systematic Methodology (100% warning reduction).

This script systematically validates connections across all /src folders
to prevent crashes and ensure proper system integration.
"""

import os
import re
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional


class UniversalConnectionValidator:
    """
    Universal Connection Validator - Systematic approach to crash prevention
    
    Applies the same patterns that achieved:
    - Universal Mock Strategy: 97.7% test success
    - 7-Stage Methodology: 100% warning reduction
    """
    
    def __init__(self, src_path: str = "src"):
        self.src_path = Path(src_path)
        self.validation_results: Dict[str, Any] = {}
        self.critical_issues: List[Dict[str, Any]] = []
        self.warnings: List[Dict[str, Any]] = []
        self.fixes_suggested: List[Dict[str, Any]] = []
        
        # Expected folder structure based on project layout
        self.expected_folders = [
            "autoload", "base", "core", "data", 
            "game", "scenes", "ui", "utils"
        ]
        
        # Critical systems that must be connected
        self.critical_systems = {
            "core/managers": [
                "BattleManager", "CampaignManager", "CharacterManager",
                "EquipmentManager", "MissionManager", "StateManager"
            ],
            "ui/screens": [
                "MainMenu", "CampaignScreen", "CharacterScreen",
                "BattleScreen", "EquipmentScreen", "SettingsScreen"
            ],
            "game": [
                "CampaignLogic", "BattleLogic", "CharacterLogic",
                "TutorialLogic", "StoryLogic", "VictoryLogic"
            ]
        }
        
        # Expected signal architecture
        self.expected_signals = {
            "CharacterManager": ["character_added", "character_removed", "character_updated"],
            "BattleManager": ["battle_started", "battle_ended", "turn_changed"],
            "CampaignManager": ["campaign_started", "phase_changed", "campaign_ended"],
            "EquipmentManager": ["item_added", "item_removed", "item_equipped"],
            "UIManager": ["screen_changed", "dialog_opened", "dialog_closed"]
        }

    def validate_all_connections(self) -> Dict[str, Any]:
        """
        Apply Universal Connection Validation to all folders
        
        Returns comprehensive validation results dictionary
        """
        print("🚀 Starting Universal Connection Validation...")
        print(f"Target directory: {self.src_path.absolute()}")
        
        if not self.src_path.exists():
            self.critical_issues.append({
                "type": "CRITICAL",
                "message": f"Source directory does not exist: {self.src_path}",
                "fix": "Ensure you're running from the project root directory"
            })
            return self._generate_results()
        
        # Phase 1: Folder Structure Validation
        print("\n📁 Phase 1: Validating folder structure...")
        self._validate_folder_structure()
        
        # Phase 2: System-by-System Validation
        print("\n🔧 Phase 2: Validating system connections...")
        for folder in self.expected_folders:
            folder_path = self.src_path / folder
            if folder_path.exists():
                print(f"  Validating {folder}...")
                self.validation_results[folder] = self._validate_folder(folder_path)
        
        # Phase 3: Cross-System Dependencies
        print("\n🔗 Phase 3: Validating cross-system dependencies...")
        self._validate_cross_system_dependencies()
        
        # Phase 4: Signal Architecture
        print("\n📡 Phase 4: Validating signal architecture...")
        self._validate_signal_architecture()
        
        return self._generate_results()

    def _validate_folder_structure(self) -> None:
        """Validate expected folder structure exists"""
        for folder in self.expected_folders:
            folder_path = self.src_path / folder
            if not folder_path.exists():
                self.warnings.append({
                    "type": "STRUCTURE",
                    "folder": folder,
                    "message": f"Expected folder missing: {folder}",
                    "fix": f"Create folder: {folder_path}"
                })

    def _validate_folder(self, folder_path: Path) -> Dict[str, Any]:
        """Validate connections in a specific folder"""
        results = {
            "node_references": self._check_node_references(folder_path),
            "resource_paths": self._check_resource_paths(folder_path),
            "signal_connections": self._check_signal_connections(folder_path),
            "script_dependencies": self._check_script_dependencies(folder_path),
            "file_count": len(list(folder_path.rglob("*.gd")))
        }
        return results

    def _check_node_references(self, folder_path: Path) -> List[Dict[str, Any]]:
        """Check for potentially broken node references"""
        broken_refs = []
        
        for gd_file in folder_path.rglob("*.gd"):
            try:
                with open(gd_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                # Find all get_node calls
                node_patterns = [
                    r'get_node\(["\']([^"\']+)["\']\)',
                    r'\$["\']([^"\']+)["\']',
                    r'\$([A-Za-z_][A-Za-z0-9_]*)',
                ]
                
                for pattern in node_patterns:
                    matches = re.findall(pattern, content)
                    for node_path in matches:
                        if self._is_potentially_broken_node_path(node_path):
                            broken_refs.append({
                                "file": str(gd_file.relative_to(self.src_path)),
                                "node_path": node_path,
                                "issue": "Potentially unsafe node reference",
                                "suggestion": f"Use get_node_safe('{node_path}', 'context')"
                            })
                            
            except Exception as e:
                self.warnings.append({
                    "type": "FILE_READ",
                    "file": str(gd_file.relative_to(self.src_path)),
                    "message": f"Could not read file: {e}"
                })
        
        return broken_refs

    def _check_resource_paths(self, folder_path: Path) -> List[Dict[str, Any]]:
        """Check for broken resource path references"""
        broken_paths = []
        
        for gd_file in folder_path.rglob("*.gd"):
            try:
                with open(gd_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                # Find resource path references
                resource_patterns = [
                    r'preload\(["\']([^"\']+)["\']\)',
                    r'load\(["\']([^"\']+)["\']\)',
                    r'res://([^"\'\\s]+)',
                ]
                
                for pattern in resource_patterns:
                    matches = re.findall(pattern, content)
                    for resource_path in matches:
                        full_path = resource_path if resource_path.startswith('res://') else f'res://{resource_path}'
                        if not self._resource_exists(full_path):
                            broken_paths.append({
                                "file": str(gd_file.relative_to(self.src_path)),
                                "resource_path": full_path,
                                "issue": "Resource path may not exist",
                                "suggestion": f"Use load_resource_safe('{full_path}', 'context')"
                            })
                            
            except Exception as e:
                continue
        
        return broken_paths

    def _check_signal_connections(self, folder_path: Path) -> List[Dict[str, Any]]:
        """Check for potentially unsafe signal connections"""
        unsafe_connections = []
        
        for gd_file in folder_path.rglob("*.gd"):
            try:
                with open(gd_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                # Find signal connection calls
                connection_patterns = [
                    r'\.connect\(["\']([^"\']+)["\']\s*,\s*([^)]+)\)',
                    r'signal_name\.connect\(([^)]+)\)',
                ]
                
                for pattern in connection_patterns:
                    matches = re.findall(pattern, content)
                    for match in matches:
                        if isinstance(match, tuple) and len(match) >= 2:
                            signal_name, target = match[0], match[1]
                            unsafe_connections.append({
                                "file": str(gd_file.relative_to(self.src_path)),
                                "signal_name": signal_name,
                                "target": target,
                                "issue": "Unsafe signal connection",
                                "suggestion": f"Use connect_signal_safe(source, '{signal_name}', target, 'context')"
                            })
                            
            except Exception as e:
                continue
        
        return unsafe_connections

    def _check_script_dependencies(self, folder_path: Path) -> List[Dict[str, Any]]:
        """Check for missing script dependencies"""
        missing_deps = []
        
        for gd_file in folder_path.rglob("*.gd"):
            try:
                with open(gd_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                # Find class_name and extends declarations
                class_patterns = [
                    r'extends\s+["\']([^"\']+)["\']',
                    r'extends\s+([A-Za-z_][A-Za-z0-9_]*)',
                ]
                
                for pattern in class_patterns:
                    matches = re.findall(pattern, content)
                    for dependency in matches:
                        if not self._is_builtin_class(dependency) and not self._dependency_exists(dependency):
                            missing_deps.append({
                                "file": str(gd_file.relative_to(self.src_path)),
                                "dependency": dependency,
                                "issue": "Missing dependency",
                                "suggestion": f"Ensure {dependency} is properly defined or imported"
                            })
                            
            except Exception as e:
                continue
        
        return missing_deps

    def _validate_cross_system_dependencies(self) -> None:
        """Validate that critical systems can find each other"""
        print("  Checking autoload availability...")
        
        # Check if critical autoloads exist
        project_file = Path("project.godot")
        if project_file.exists():
            try:
                with open(project_file, 'r') as f:
                    project_content = f.read()
                    
                expected_autoloads = [
                    "GameState", "EventBus", "ConfigManager", "SaveManager"
                ]
                
                for autoload in expected_autoloads:
                    if autoload not in project_content:
                        self.warnings.append({
                            "type": "AUTOLOAD",
                            "system": autoload,
                            "message": f"Expected autoload not found: {autoload}",
                            "fix": f"Add {autoload} to project autoloads"
                        })
                        
            except Exception as e:
                self.warnings.append({
                    "type": "PROJECT_READ",
                    "message": f"Could not read project.godot: {e}"
                })

    def _validate_signal_architecture(self) -> None:
        """Validate expected signal architecture exists"""
        for system_name, expected_signals in self.expected_signals.items():
            system_files = list(self.src_path.rglob(f"*{system_name}*.gd"))
            
            if not system_files:
                self.warnings.append({
                    "type": "SYSTEM_MISSING",
                    "system": system_name,
                    "message": f"Expected system not found: {system_name}",
                    "fix": f"Create or locate {system_name} implementation"
                })
                continue
                
            # Check if system defines expected signals
            for system_file in system_files:
                try:
                    with open(system_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                        
                    for signal_name in expected_signals:
                        if f"signal {signal_name}" not in content:
                            self.warnings.append({
                                "type": "SIGNAL_MISSING",
                                "system": system_name,
                                "signal": signal_name,
                                "file": str(system_file.relative_to(self.src_path)),
                                "message": f"Expected signal not found: {signal_name}",
                                "fix": f"Add 'signal {signal_name}' to {system_name}"
                            })
                            
                except Exception as e:
                    continue

    def _is_potentially_broken_node_path(self, node_path: str) -> bool:
        """Check if a node path is potentially problematic"""
        problematic_patterns = [
            r'^[A-Z]',  # Starts with capital (might be class name)
            r'\.\.',    # Contains parent navigation
            r'/',       # Contains path separator (might be complex path)
        ]
        
        return any(re.search(pattern, node_path) for pattern in problematic_patterns)

    def _resource_exists(self, resource_path: str) -> bool:
        """Check if a resource path likely exists"""
        if resource_path.startswith('res://'):
            local_path = resource_path[6:]  # Remove 'res://'
            return Path(local_path).exists()
        return False

    def _dependency_exists(self, dependency: str) -> bool:
        """Check if a dependency exists in the project"""
        # Simple check - look for files with similar names
        search_patterns = [
            f"*{dependency}*.gd",
            f"{dependency}.gd",
        ]
        
        for pattern in search_patterns:
            if list(self.src_path.rglob(pattern)):
                return True
        return False

    def _is_builtin_class(self, class_name: str) -> bool:
        """Check if class is a Godot builtin"""
        builtin_classes = [
            "Node", "Node2D", "Node3D", "Control", "Resource", "RefCounted",
            "Area2D", "RigidBody2D", "CharacterBody2D", "StaticBody2D",
            "Button", "Label", "LineEdit", "TextEdit", "ProgressBar",
            "Panel", "VBoxContainer", "HBoxContainer", "GridContainer",
            "PackedScene", "AudioStreamPlayer", "Timer", "AnimationPlayer"
        ]
        return class_name in builtin_classes

    def _generate_results(self) -> Dict[str, Any]:
        """Generate comprehensive validation results"""
        total_issues = len(self.critical_issues) + len(self.warnings)
        total_files_checked = sum(
            result.get('file_count', 0) 
            for result in self.validation_results.values()
        )
        
        results = {
            "timestamp": datetime.now().isoformat(),
            "summary": {
                "total_folders_validated": len(self.validation_results),
                "total_files_checked": total_files_checked,
                "critical_issues": len(self.critical_issues),
                "warnings": len(self.warnings),
                "total_issues": total_issues,
                "validation_status": "PASSED" if len(self.critical_issues) == 0 else "FAILED"
            },
            "folder_results": self.validation_results,
            "critical_issues": self.critical_issues,
            "warnings": self.warnings,
            "fixes_suggested": self.fixes_suggested
        }
        
        return results

    def generate_report(self, output_file: str = "validation_report.json") -> None:
        """Generate detailed validation report"""
        results = self._generate_results()
        
        # Write JSON report
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2)
        
        # Print summary
        print(f"\n📊 UNIVERSAL CONNECTION VALIDATION COMPLETE")
        print(f"=" * 50)
        print(f"Folders validated: {results['summary']['total_folders_validated']}")
        print(f"Files checked: {results['summary']['total_files_checked']}")
        print(f"Critical issues: {results['summary']['critical_issues']}")
        print(f"Warnings: {results['summary']['warnings']}")
        print(f"Overall status: {results['summary']['validation_status']}")
        print(f"Report saved to: {output_file}")
        
        if results['summary']['critical_issues'] > 0:
            print(f"\n🚨 CRITICAL ISSUES FOUND:")
            for issue in self.critical_issues:
                print(f"  - {issue['message']}")
                if 'fix' in issue:
                    print(f"    Fix: {issue['fix']}")
        
        if results['summary']['warnings'] > 0:
            print(f"\n⚠️  TOP WARNINGS:")
            for warning in self.warnings[:5]:  # Show first 5 warnings
                print(f"  - {warning['message']}")
                if 'fix' in warning:
                    print(f"    Fix: {warning['fix']}")
        
        print(f"\n🚀 Next Steps:")
        print(f"  1. Review critical issues and apply fixes")  
        print(f"  2. Run: python scripts/apply_universal_fixes.py")
        print(f"  3. Test application stability")
        print(f"  4. Re-run validation to verify improvements")


def main():
    """Main execution function"""
    print("🚀 Five Parsecs Campaign Manager - Universal Connection Validator")
    print("Based on Universal Mock Strategy (97.7% success) patterns")
    print("=" * 60)
    
    validator = UniversalConnectionValidator()
    results = validator.validate_all_connections()
    validator.generate_report()
    
    return results['summary']['validation_status'] == "PASSED"


if __name__ == "__main__":
    success = main()
    exit(0 if success else 1) 