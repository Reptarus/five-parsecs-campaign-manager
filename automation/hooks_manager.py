#!/usr/bin/env python3
"""
Five Parsecs Campaign Manager - Claude Hooks Management System
Production-grade hook activation, testing, and management for development workflows
"""

import os
import sys
import json
import subprocess
import argparse
import time
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from enum import Enum

class HookStatus(Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    ERROR = "error"
    TESTING = "testing"

@dataclass
class HookTestResult:
    """Results from hook testing"""
    hook_name: str
    status: HookStatus
    execution_time: float
    success: bool
    output: str
    error_message: Optional[str] = None

class ClaudeHooksManager:
    """
    Production-grade Claude Hooks management system
    
    Features:
    - Hook activation and deactivation
    - Hook testing and validation
    - Performance monitoring
    - Configuration management
    - Troubleshooting and diagnostics
    """
    
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.hooks_config_path = self.project_root / ".claude" / "hooks.json"
        self.hooks_log_path = self.project_root / ".claude" / "hooks.log"
        
        # Ensure .claude directory exists
        self.hooks_config_path.parent.mkdir(exist_ok=True)
        
        # Load hook configuration
        self.hooks_config = self._load_hooks_config()
        
    def _load_hooks_config(self) -> Dict:
        """Load hooks configuration from file"""
        if not self.hooks_config_path.exists():
            return {}
            
        try:
            with open(self.hooks_config_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"Warning: Failed to load hooks config: {e}")
            return {}
    
    def _save_hooks_config(self) -> bool:
        """Save hooks configuration to file"""
        try:
            with open(self.hooks_config_path, 'w') as f:
                json.dump(self.hooks_config, f, indent=2)
            return True
        except Exception as e:
            print(f"Error: Failed to save hooks config: {e}")
            return False
    
    def list_hooks(self) -> List[Dict[str, Any]]:
        """List all available hooks with their status"""
        hooks = []
        
        if "hooks" not in self.hooks_config:
            return hooks
            
        for hook in self.hooks_config["hooks"]:
            hook_info = {
                "name": hook.get("name", "Unknown"),
                "type": hook.get("type", "Unknown"),
                "enabled": hook.get("enabled", False),
                "description": hook.get("description", "No description"),
                "patterns": len(hook.get("patterns", [])),
                "timeout": hook.get("timeout", 60)
            }
            hooks.append(hook_info)
            
        return hooks
    
    def activate_hook(self, hook_name: str) -> bool:
        """Activate a specific hook"""
        if "hooks" not in self.hooks_config:
            print(f"Error: No hooks configuration found")
            return False
            
        for hook in self.hooks_config["hooks"]:
            if hook.get("name") == hook_name:
                hook["enabled"] = True
                if self._save_hooks_config():
                    print(f"✅ Activated hook: {hook_name}")
                    return True
                else:
                    print(f"❌ Failed to save hook activation: {hook_name}")
                    return False
        
        print(f"❌ Hook not found: {hook_name}")
        return False
    
    def deactivate_hook(self, hook_name: str) -> bool:
        """Deactivate a specific hook"""
        if "hooks" not in self.hooks_config:
            print(f"Error: No hooks configuration found")
            return False
            
        for hook in self.hooks_config["hooks"]:
            if hook.get("name") == hook_name:
                hook["enabled"] = False
                if self._save_hooks_config():
                    print(f"🔌 Deactivated hook: {hook_name}")
                    return True
                else:
                    print(f"❌ Failed to save hook deactivation: {hook_name}")
                    return False
        
        print(f"❌ Hook not found: {hook_name}")
        return False
    
    def test_hook(self, hook_name: str, test_file: Optional[str] = None) -> HookTestResult:
        """Test a specific hook with a sample file"""
        print(f"🧪 Testing hook: {hook_name}")
        
        if "hooks" not in self.hooks_config:
            return HookTestResult(
                hook_name=hook_name,
                status=HookStatus.ERROR,
                execution_time=0.0,
                success=False,
                output="",
                error_message="No hooks configuration found"
            )
        
        # Find the hook
        target_hook = None
        for hook in self.hooks_config["hooks"]:
            if hook.get("name") == hook_name:
                target_hook = hook
                break
        
        if not target_hook:
            return HookTestResult(
                hook_name=hook_name,
                status=HookStatus.ERROR,
                execution_time=0.0,
                success=False,
                output="",
                error_message=f"Hook {hook_name} not found"
            )
        
        # Create test file if not provided
        if not test_file:
            test_file = self._create_test_file_for_hook(target_hook)
        
        # Execute hook command
        start_time = time.time()
        
        try:
            # Build command
            command = [target_hook.get("command", "python")]
            args = target_hook.get("args", [])
            
            # Replace placeholders
            processed_args = []
            for arg in args:
                if "${filePath}" in arg:
                    processed_args.append(arg.replace("${filePath}", test_file))
                elif "${workingDirectory}" in arg:
                    processed_args.append(arg.replace("${workingDirectory}", str(self.project_root)))
                else:
                    processed_args.append(arg)
            
            command.extend(processed_args)
            
            # Execute command
            result = subprocess.run(
                command,
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=target_hook.get("timeout", 60)
            )
            
            execution_time = time.time() - start_time
            
            success = result.returncode == 0
            status = HookStatus.ACTIVE if success else HookStatus.ERROR
            
            return HookTestResult(
                hook_name=hook_name,
                status=status,
                execution_time=execution_time,
                success=success,
                output=result.stdout,
                error_message=result.stderr if result.stderr else None
            )
            
        except subprocess.TimeoutExpired:
            return HookTestResult(
                hook_name=hook_name,
                status=HookStatus.ERROR,
                execution_time=target_hook.get("timeout", 60),
                success=False,
                output="",
                error_message="Hook execution timed out"
            )
            
        except Exception as e:
            return HookTestResult(
                hook_name=hook_name,
                status=HookStatus.ERROR,
                execution_time=time.time() - start_time,
                success=False,
                output="",
                error_message=str(e)
            )
    
    def _create_test_file_for_hook(self, hook: Dict) -> str:
        """Create a test file appropriate for the hook's patterns"""
        # Determine file type from patterns
        patterns = hook.get("patterns", [])
        file_extension = ".gd"  # Default to GDScript
        
        for pattern in patterns:
            if "*.tscn" in pattern.get("filePattern", ""):
                file_extension = ".tscn"
                break
            elif "*.tres" in pattern.get("filePattern", ""):
                file_extension = ".tres"
                break
        
        # Create test file
        test_file_path = self.project_root / f"temp_test_file{file_extension}"
        
        if file_extension == ".gd":
            test_content = '''# Test GDScript file for hook validation
class_name TestClass
extends Node

@signal test_signal(data: Dictionary)

var test_variable: int = 0
var untyped_var = "test"

func _ready() -> void:
    print("Test file loaded")

func test_function() -> bool:
    var result = true
    if test_variable > 0:
        result = false
    return result

func _process(delta: float) -> void:
    # This should trigger performance warnings
    var temp_array = Array()  # Bad practice in _process
    for i in range(100):
        temp_array.append(i)
'''
        elif file_extension == ".tscn":
            test_content = '''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://TestScript.gd" id="1"]

[node name="TestNode" type="Node"]
script = ExtResource("1")
'''
        else:
            test_content = '''[gd_resource type="Resource" format=3]

[resource]
'''
        
        try:
            with open(test_file_path, 'w') as f:
                f.write(test_content)
            return str(test_file_path)
        except Exception as e:
            print(f"Warning: Failed to create test file: {e}")
            return str(self.project_root / "run_tests.gd")  # Fallback to existing file
    
    def test_all_hooks(self) -> List[HookTestResult]:
        """Test all enabled hooks"""
        print("🧪 Testing all enabled hooks...")
        
        results = []
        
        if "hooks" not in self.hooks_config:
            print("❌ No hooks configuration found")
            return results
        
        for hook in self.hooks_config["hooks"]:
            if hook.get("enabled", False):
                result = self.test_hook(hook.get("name", "Unknown"))
                results.append(result)
                
                if result.success:
                    print(f"✅ {result.hook_name}: PASSED ({result.execution_time:.2f}s)")
                else:
                    print(f"❌ {result.hook_name}: FAILED - {result.error_message}")
            else:
                print(f"⏭️ {hook.get('name', 'Unknown')}: SKIPPED (disabled)")
        
        return results
    
    def validate_hook_dependencies(self) -> Dict[str, bool]:
        """Validate that all hook dependencies are available"""
        print("Validating hook dependencies...")
        
        dependencies = {}
        
        # Check Python availability
        try:
            result = subprocess.run(["python", "--version"], capture_output=True, text=True)
            dependencies["python"] = result.returncode == 0
            if dependencies["python"]:
                print(f"[OK] Python: {result.stdout.strip()}")
            else:
                print("[FAIL] Python: Not available")
        except Exception:
            dependencies["python"] = False
            print("[FAIL] Python: Not found")
        
        # Check Godot availability
        godot_path = self.hooks_config.get("globalSettings", {}).get("environment", {}).get("GODOT_PATH")
        if godot_path:
            try:
                result = subprocess.run([godot_path, "--version"], capture_output=True, text=True)
                dependencies["godot"] = result.returncode == 0
                if dependencies["godot"]:
                    print(f"[OK] Godot: Available at {godot_path}")
                else:
                    print(f"[FAIL] Godot: Failed to execute at {godot_path}")
            except Exception:
                dependencies["godot"] = False
                print(f"[FAIL] Godot: Not found at {godot_path}")
        else:
            dependencies["godot"] = False
            print("[FAIL] Godot: Path not configured")
        
        # Check automation scripts
        automation_dir = self.project_root / "automation"
        required_scripts = [
            "gdscript_linter_fixer.py",
            "test_runner.py", 
            "godot_validator.py",
            "rule_validator.py",
            "state_guardian.py",
            "performance_monitor.py"
        ]
        
        for script in required_scripts:
            script_path = automation_dir / script
            if script == "gdscript_linter_fixer.py":
                script_path = self.project_root / "fixes" / script
                
            dependencies[script] = script_path.exists()
            if dependencies[script]:
                print(f"[OK] {script}: Available")
            else:
                print(f"[FAIL] {script}: Missing")
        
        return dependencies
    
    def install_hooks(self) -> bool:
        """Install hooks configuration if not present"""
        print("📦 Installing Claude Hooks configuration...")
        
        if self.hooks_config_path.exists():
            print("ℹ️ Hooks configuration already exists")
            return True
        
        # The configuration was already created when we wrote the hooks.json file
        if self.hooks_config_path.exists():
            print("✅ Hooks configuration installed successfully")
            return True
        else:
            print("❌ Failed to install hooks configuration")
            return False
    
    def generate_status_report(self) -> Dict[str, Any]:
        """Generate comprehensive status report for hooks system"""
        report = {
            "timestamp": time.time(),
            "project_root": str(self.project_root),
            "configuration": {
                "config_exists": self.hooks_config_path.exists(),
                "config_valid": len(self.hooks_config) > 0,
                "total_hooks": len(self.hooks_config.get("hooks", [])),
                "enabled_hooks": len([h for h in self.hooks_config.get("hooks", []) if h.get("enabled", False)])
            },
            "dependencies": self.validate_hook_dependencies(),
            "hooks": []
        }
        
        # Test all hooks
        hook_results = self.test_all_hooks()
        
        for result in hook_results:
            report["hooks"].append({
                "name": result.hook_name,
                "status": result.status.value,
                "success": result.success,
                "execution_time": result.execution_time,
                "error_message": result.error_message
            })
        
        return report
    
    def cleanup_test_files(self) -> None:
        """Clean up temporary test files"""
        test_files = [
            "temp_test_file.gd",
            "temp_test_file.tscn", 
            "temp_test_file.tres"
        ]
        
        for test_file in test_files:
            test_path = self.project_root / test_file
            if test_path.exists():
                try:
                    test_path.unlink()
                    print(f"🧹 Cleaned up: {test_file}")
                except Exception as e:
                    print(f"Warning: Failed to clean up {test_file}: {e}")

def main():
    """
    Command-line interface for Claude Hooks management
    """
    parser = argparse.ArgumentParser(
        description="Five Parsecs Campaign Manager - Claude Hooks Manager"
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # List hooks command
    list_parser = subparsers.add_parser("list", help="List all available hooks")
    list_parser.add_argument("--format", choices=["table", "json"], default="table", help="Output format")
    
    # Activate hook command
    activate_parser = subparsers.add_parser("activate", help="Activate a hook")
    activate_parser.add_argument("hook_name", help="Name of hook to activate")
    
    # Deactivate hook command
    deactivate_parser = subparsers.add_parser("deactivate", help="Deactivate a hook")
    deactivate_parser.add_argument("hook_name", help="Name of hook to deactivate")
    
    # Test hook command
    test_parser = subparsers.add_parser("test", help="Test a hook")
    test_parser.add_argument("hook_name", help="Name of hook to test")
    test_parser.add_argument("--file", help="Test file to use (optional)")
    
    # Test all hooks command
    test_all_parser = subparsers.add_parser("test-all", help="Test all enabled hooks")
    test_all_parser.add_argument("--format", choices=["summary", "detailed", "json"], default="summary", help="Output format")
    
    # Validate dependencies command
    validate_parser = subparsers.add_parser("validate", help="Validate hook dependencies")
    
    # Status report command
    status_parser = subparsers.add_parser("status", help="Generate status report")
    status_parser.add_argument("--format", choices=["text", "json"], default="text", help="Output format")
    
    # Install hooks command
    install_parser = subparsers.add_parser("install", help="Install hooks configuration")
    
    # Cleanup command
    cleanup_parser = subparsers.add_parser("cleanup", help="Clean up temporary files")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # Initialize manager
    project_root = os.getcwd()
    manager = ClaudeHooksManager(project_root)
    
    try:
        if args.command == "list":
            hooks = manager.list_hooks()
            
            if args.format == "json":
                print(json.dumps(hooks, indent=2))
            else:
                print(f"\n📋 Claude Hooks Status")
                print(f"{'Hook Name':<30} {'Type':<15} {'Enabled':<8} {'Patterns':<8} {'Timeout':<8}")
                print("-" * 80)
                
                for hook in hooks:
                    enabled_icon = "✅" if hook["enabled"] else "❌"
                    print(f"{hook['name']:<30} {hook['type']:<15} {enabled_icon:<8} {hook['patterns']:<8} {hook['timeout']:<8}")
                
                print(f"\nTotal Hooks: {len(hooks)}")
                print(f"Enabled: {len([h for h in hooks if h['enabled']])}")
        
        elif args.command == "activate":
            success = manager.activate_hook(args.hook_name)
            sys.exit(0 if success else 1)
        
        elif args.command == "deactivate":
            success = manager.deactivate_hook(args.hook_name)
            sys.exit(0 if success else 1)
        
        elif args.command == "test":
            result = manager.test_hook(args.hook_name, args.file)
            
            print(f"\n🧪 Hook Test Results: {result.hook_name}")
            print(f"Status: {result.status.value.upper()}")
            print(f"Success: {'✅ PASSED' if result.success else '❌ FAILED'}")
            print(f"Execution Time: {result.execution_time:.2f}s")
            
            if result.output:
                print(f"\nOutput:\n{result.output}")
            
            if result.error_message:
                print(f"\nError:\n{result.error_message}")
            
            sys.exit(0 if result.success else 1)
        
        elif args.command == "test-all":
            results = manager.test_all_hooks()
            
            if args.format == "json":
                result_data = [
                    {
                        "hook_name": r.hook_name,
                        "status": r.status.value,
                        "success": r.success,
                        "execution_time": r.execution_time,
                        "error_message": r.error_message
                    }
                    for r in results
                ]
                print(json.dumps(result_data, indent=2))
            
            elif args.format == "detailed":
                for result in results:
                    print(f"\n{'='*50}")
                    print(f"Hook: {result.hook_name}")
                    print(f"Status: {result.status.value}")
                    print(f"Success: {result.success}")
                    print(f"Time: {result.execution_time:.2f}s")
                    if result.error_message:
                        print(f"Error: {result.error_message}")
                    if result.output:
                        print(f"Output: {result.output[:200]}...")
            
            else:  # summary
                passed = len([r for r in results if r.success])
                failed = len([r for r in results if not r.success])
                total_time = sum(r.execution_time for r in results)
                
                print(f"\n📊 Hook Test Summary")
                print(f"Total Tests: {len(results)}")
                print(f"Passed: ✅ {passed}")
                print(f"Failed: ❌ {failed}")
                print(f"Total Time: {total_time:.2f}s")
                
                if failed > 0:
                    print(f"\n❌ Failed Hooks:")
                    for result in results:
                        if not result.success:
                            print(f"  • {result.hook_name}: {result.error_message}")
            
            sys.exit(0 if all(r.success for r in results) else 1)
        
        elif args.command == "validate":
            dependencies = manager.validate_hook_dependencies()
            
            all_valid = all(dependencies.values())
            
            print(f"\n🔍 Dependency Validation: {'✅ PASSED' if all_valid else '❌ FAILED'}")
            
            if not all_valid:
                print(f"\n❌ Missing Dependencies:")
                for dep, status in dependencies.items():
                    if not status:
                        print(f"  • {dep}")
            
            sys.exit(0 if all_valid else 1)
        
        elif args.command == "status":
            report = manager.generate_status_report()
            
            if args.format == "json":
                print(json.dumps(report, indent=2))
            else:
                print(f"\n📊 Claude Hooks Status Report")
                print(f"Project: {report['project_root']}")
                print(f"Configuration Valid: {'✅' if report['configuration']['config_valid'] else '❌'}")
                print(f"Total Hooks: {report['configuration']['total_hooks']}")
                print(f"Enabled Hooks: {report['configuration']['enabled_hooks']}")
                
                print(f"\n🔧 Dependencies:")
                for dep, status in report['dependencies'].items():
                    print(f"  {dep}: {'✅' if status else '❌'}")
                
                print(f"\n🧪 Hook Test Results:")
                for hook in report['hooks']:
                    status_icon = "✅" if hook['success'] else "❌"
                    print(f"  {hook['name']}: {status_icon} ({hook['execution_time']:.2f}s)")
        
        elif args.command == "install":
            success = manager.install_hooks()
            sys.exit(0 if success else 1)
        
        elif args.command == "cleanup":
            manager.cleanup_test_files()
            print("🧹 Cleanup completed")
        
        else:
            parser.print_help()
    
    finally:
        # Always cleanup test files
        manager.cleanup_test_files()

if __name__ == "__main__":
    main()