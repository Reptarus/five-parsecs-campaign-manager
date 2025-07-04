#!/usr/bin/env python3

"""
Simple Cursor IDE Integration Bridge (No External Dependencies)
Provides basic IDE integration for error monitoring and problem detection
"""

import json
import os
import sys
import time
import argparse
import subprocess
from pathlib import Path

class SimpleCursorBridge:
    def __init__(self, project_path):
        self.project_path = Path(project_path)
        
    def get_current_status(self):
        """Get current project status and potential errors"""
        status = {
            "timestamp": time.time(),
            "project_path": str(self.project_path),
            "file_counts": self._count_files(),
            "potential_issues": self._scan_for_issues(),
            "godot_status": self._check_godot_status()
        }
        return status
        
    def _count_files(self):
        """Count different types of files in the project"""
        counts = {
            "gdscript_files": len(list(self.project_path.glob("**/*.gd"))),
            "test_files": len(list(self.project_path.glob("**/test_*.gd"))),
            "json_files": len(list(self.project_path.glob("**/*.json"))),
            "scene_files": len(list(self.project_path.glob("**/*.tscn")))
        }
        return counts
        
    def _scan_for_issues(self):
        """Scan for potential issues in recent files"""
        issues = []
        
        # Check for common problem patterns in GDScript files
        gdscript_files = list(self.project_path.glob("**/*.gd"))
        for gd_file in gdscript_files:
            try:
                with open(gd_file, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    line_num = 0
                    for line in content.split('\n'):
                        line_num += 1
                        line_lower = line.lower().strip()
                        
                        # Check for common issues
                        if any(issue in line_lower for issue in ['todo', 'fixme', 'hack', 'broken']):
                            issues.append({
                                "file": str(gd_file.relative_to(self.project_path)),
                                "line": line_num,
                                "type": "todo_or_fixme",
                                "content": line.strip()[:100]
                            })
                        elif 'error' in line_lower and ('print' in line_lower or 'push_error' in line_lower):
                            issues.append({
                                "file": str(gd_file.relative_to(self.project_path)),
                                "line": line_num,
                                "type": "error_logging",
                                "content": line.strip()[:100]
                            })
                            
            except Exception as e:
                issues.append({
                    "file": str(gd_file.relative_to(self.project_path)),
                    "type": "file_read_error",
                    "error": str(e)
                })
                
        return issues
        
    def _check_godot_status(self):
        """Check if Godot is available and get version info"""
        godot_status = {
            "available": False,
            "version": None,
            "path": None
        }
        
        # Try common Godot locations
        godot_paths = [
            "/mnt/c/Users/elija/Desktop/GoDot/Godot_v4.4-stable_mono_win64/Godot_v4.4-stable_mono_win64.exe",
            "godot",
            "godot4"
        ]
        
        for godot_path in godot_paths:
            try:
                if os.path.exists(godot_path):
                    result = subprocess.run([godot_path, "--version"], 
                                          capture_output=True, text=True, timeout=10)
                    if result.returncode == 0:
                        godot_status["available"] = True
                        godot_status["version"] = result.stdout.strip()
                        godot_status["path"] = godot_path
                        break
            except Exception:
                continue
                
        return godot_status
        
    def validate_enhanced_character_creation(self):
        """Validate our enhanced character creation implementation"""
        validation = {
            "files_exist": True,
            "required_files": [],
            "missing_files": [],
            "syntax_issues": [],
            "overall_status": "unknown"
        }
        
        # Check required files
        required_files = [
            "src/core/character/tables/CharacterCreationTables.gd",
            "src/core/character/equipment/StartingEquipmentGenerator.gd", 
            "src/core/character/connections/CharacterConnections.gd",
            "src/core/character/CharacterGeneration.gd",
            "tests/unit/character/test_enhanced_character_creation.gd",
            "data/character_creation_tables/background_events.json",
            "data/character_creation_tables/motivation_table.json",
            "data/character_creation_tables/quirks_table.json",
            "data/character_creation_tables/equipment_tables.json",
            "data/character_creation_tables/connections_table.json"
        ]
        
        for file_path in required_files:
            full_path = self.project_path / file_path
            if full_path.exists():
                validation["required_files"].append(file_path)
                
                # Basic syntax check for GDScript files
                if file_path.endswith('.gd'):
                    try:
                        with open(full_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            # Basic syntax checks
                            if not content.strip().startswith('@tool'):
                                validation["syntax_issues"].append(f"{file_path}: Missing @tool directive")
                            if 'extends' not in content:
                                validation["syntax_issues"].append(f"{file_path}: Missing extends declaration")
                    except Exception as e:
                        validation["syntax_issues"].append(f"{file_path}: Read error - {e}")
                        
                # Basic JSON validation
                elif file_path.endswith('.json'):
                    try:
                        with open(full_path, 'r', encoding='utf-8') as f:
                            json.load(f)
                    except Exception as e:
                        validation["syntax_issues"].append(f"{file_path}: JSON error - {e}")
                        
            else:
                validation["missing_files"].append(file_path)
                validation["files_exist"] = False
        
        # Determine overall status
        if not validation["missing_files"] and not validation["syntax_issues"]:
            validation["overall_status"] = "excellent"
        elif not validation["missing_files"] and len(validation["syntax_issues"]) < 3:
            validation["overall_status"] = "good"
        elif len(validation["missing_files"]) < 3:
            validation["overall_status"] = "fair"
        else:
            validation["overall_status"] = "poor"
            
        return validation
        
    def run_quick_test(self):
        """Run a quick test of the project"""
        test_result = {
            "attempted": True,
            "success": False,
            "output": "",
            "error": ""
        }
        
        godot_status = self._check_godot_status()
        if not godot_status["available"]:
            test_result["error"] = "Godot not available for testing"
            return test_result
            
        try:
            # Try to run a quick syntax check
            result = subprocess.run([
                godot_status["path"], 
                "--path", str(self.project_path),
                "--check-only"
            ], capture_output=True, text=True, timeout=30)
            
            test_result["success"] = result.returncode == 0
            test_result["output"] = result.stdout
            test_result["error"] = result.stderr
            
        except subprocess.TimeoutExpired:
            test_result["error"] = "Test timed out"
        except Exception as e:
            test_result["error"] = str(e)
            
        return test_result

def main():
    parser = argparse.ArgumentParser(description="Simple Cursor IDE Bridge")
    parser.add_argument("command", choices=["status", "validate", "test"], help="Command to execute")
    parser.add_argument("--project", default=".", help="Project path")
    
    args = parser.parse_args()
    project_path = Path(args.project).resolve()
    
    bridge = SimpleCursorBridge(project_path)
    
    if args.command == "status":
        status = bridge.get_current_status()
        print(json.dumps(status, indent=2, default=str))
        
    elif args.command == "validate":
        validation = bridge.validate_enhanced_character_creation()
        print(json.dumps(validation, indent=2))
        
        # Also print a summary
        print("\\n" + "="*50)
        print("ENHANCED CHARACTER CREATION VALIDATION SUMMARY")
        print("="*50)
        print(f"Required files: {len(validation['required_files'])}/{len(validation['required_files']) + len(validation['missing_files'])}")
        print(f"Syntax issues: {len(validation['syntax_issues'])}")
        print(f"Overall status: {validation['overall_status'].upper()}")
        
        if validation['missing_files']:
            print("\\nMissing files:")
            for file in validation['missing_files']:
                print(f"  ❌ {file}")
                
        if validation['syntax_issues']:
            print("\\nSyntax issues:")
            for issue in validation['syntax_issues']:
                print(f"  ⚠️ {issue}")
                
        if validation['overall_status'] == 'excellent':
            print("\\n🎉 Enhanced Character Creation System is in excellent condition!")
        elif validation['overall_status'] == 'good':
            print("\\n✅ Enhanced Character Creation System is in good condition")
        else:
            print("\\n⚠️ Enhanced Character Creation System needs attention")
            
    elif args.command == "test":
        test_result = bridge.run_quick_test()
        print(json.dumps(test_result, indent=2))

if __name__ == "__main__":
    main()