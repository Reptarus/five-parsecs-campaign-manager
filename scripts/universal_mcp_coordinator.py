#!/usr/bin/env python3
"""
Universal MCP Coordinator for Five Parsecs Campaign Manager
Fixes information handoff between Claude Desktop, Claude Code, Godot MCP, and Gemini
"""

import json
import subprocess
import sys
import os
import tempfile
import time
import threading
from typing import Dict, Any, Optional, List, Union
from pathlib import Path
from dataclasses import dataclass, asdict
from contextlib import contextmanager

@dataclass
class MCPContext:
    """Shared context for all MCP operations"""
    project_path_windows: str
    project_path_wsl: str
    godot_path_windows: str
    godot_path_wsl: str
    session_id: str
    current_operation: str = ""
    last_result: Dict[str, Any] = None
    error_history: List[str] = None
    
    def __post_init__(self):
        if self.error_history is None:
            self.error_history = []

class UniversalMCPCoordinator:
    """Central coordinator for all MCP systems"""
    
    def __init__(self):
        self.project_root = Path(__file__).parent.parent
        self.context = self._initialize_context()
        self.state_file = self.project_root / "mcp_shared_state.json"
        self._load_shared_state()
        
    def _initialize_context(self) -> MCPContext:
        """Initialize unified context with consistent paths"""
        project_windows = str(self.project_root.resolve())
        project_wsl = self._windows_to_wsl_path(project_windows)
        
        # Get consistent Godot paths
        godot_windows = r"C:\Users\elija\Desktop\GoDot\Godot_v4.4-stable_mono_win64\Godot_v4.4-stable_mono_win64_console.exe"
        godot_wsl = self._windows_to_wsl_path(godot_windows)
        
        return MCPContext(
            project_path_windows=project_windows,
            project_path_wsl=project_wsl,
            godot_path_windows=godot_windows,
            godot_path_wsl=godot_wsl,
            session_id=f"mcp_session_{int(time.time())}"
        )
    
    def _windows_to_wsl_path(self, windows_path: str) -> str:
        """Convert Windows path to WSL format"""
        if ":" in windows_path:
            drive = windows_path[0].lower()
            path = windows_path[2:].replace("\\", "/")
            return f"/mnt/{drive}{path}"
        return windows_path
    
    def _wsl_to_windows_path(self, wsl_path: str) -> str:
        """Convert WSL path to Windows format"""
        if wsl_path.startswith("/mnt/"):
            drive = wsl_path[5].upper()
            path = wsl_path[6:].replace("/", "\\")
            return f"{drive}:{path}"
        return wsl_path
    
    def _save_shared_state(self):
        """Save current context to shared state file"""
        try:
            with open(self.state_file, 'w') as f:
                json.dump(asdict(self.context), f, indent=2)
        except Exception as e:
            print(f"Warning: Could not save shared state: {e}")
    
    def _load_shared_state(self):
        """Load context from shared state file if it exists"""
        try:
            if self.state_file.exists():
                with open(self.state_file, 'r') as f:
                    data = json.load(f)
                    # Update context with saved data
                    for key, value in data.items():
                        if hasattr(self.context, key):
                            setattr(self.context, key, value)
        except Exception as e:
            print(f"Warning: Could not load shared state: {e}")
    
    @contextmanager
    def operation_context(self, operation_name: str):
        """Context manager for MCP operations with state tracking"""
        self.context.current_operation = operation_name
        self._save_shared_state()
        
        try:
            yield self.context
        except Exception as e:
            self.context.error_history.append(f"{operation_name}: {str(e)}")
            raise
        finally:
            self.context.current_operation = ""
            self._save_shared_state()
    
    def execute_claude_desktop_operation(self, operation: str, **kwargs) -> Dict[str, Any]:
        """Execute operation through Claude Desktop (via permissions)"""
        with self.operation_context(f"claude_desktop_{operation}"):
            try:
                if operation == "check_godot_syntax":
                    # Use Windows path for Claude Desktop
                    cmd = [
                        self.context.godot_path_windows,
                        "--headless", "--check-only",
                        "--path", self.context.project_path_windows
                    ]
                    
                    result = subprocess.run(
                        cmd, capture_output=True, text=True, timeout=30
                    )
                    
                    return {
                        "success": result.returncode == 0,
                        "output": result.stdout,
                        "errors": result.stderr,
                        "operation": operation,
                        "system": "claude_desktop"
                    }
                
                elif operation == "run_tests":
                    cmd = [
                        self.context.godot_path_windows,
                        "--headless",
                        "--script", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
                        "--path", self.context.project_path_windows
                    ]
                    
                    result = subprocess.run(
                        cmd, capture_output=True, text=True, timeout=60
                    )
                    
                    return {
                        "success": result.returncode == 0,
                        "output": result.stdout,
                        "errors": result.stderr,
                        "operation": operation,
                        "system": "claude_desktop"
                    }
                
                else:
                    return {"error": f"Unknown operation: {operation}", "success": False}
                    
            except Exception as e:
                return {"error": str(e), "success": False, "system": "claude_desktop"}
    
    def execute_godot_mcp_operation(self, operation: str, **kwargs) -> Dict[str, Any]:
        """Execute operation through Godot MCP Server"""
        with self.operation_context(f"godot_mcp_{operation}"):
            try:
                # Update Godot MCP config with consistent paths
                config_path = self.project_root / "godot-mcp-server" / "config.json"
                config = {
                    "godotPath": self.context.godot_path_wsl,
                    "projectPath": self.context.project_path_wsl,
                    "strictPathValidation": True
                }
                
                with open(config_path, 'w') as f:
                    json.dump(config, f, indent=2)
                
                # Execute MCP server operation
                server_path = self.project_root / "godot-mcp-server" / "build" / "index.js"
                cmd = ["node", str(server_path), operation]
                
                if kwargs:
                    cmd.extend([json.dumps(kwargs)])
                
                env = os.environ.copy()
                env["GODOT_PATH"] = self.context.godot_path_wsl
                env["PROJECT_PATH"] = self.context.project_path_wsl
                
                result = subprocess.run(
                    cmd, capture_output=True, text=True, 
                    env=env, timeout=60, cwd=self.project_root
                )
                
                return {
                    "success": result.returncode == 0,
                    "output": result.stdout,
                    "errors": result.stderr,
                    "operation": operation,
                    "system": "godot_mcp"
                }
                
            except Exception as e:
                return {"error": str(e), "success": False, "system": "godot_mcp"}
    
    def execute_gemini_operation(self, operation: str, **kwargs) -> Dict[str, Any]:
        """Execute operation through Gemini MCP"""
        with self.operation_context(f"gemini_{operation}"):
            try:
                # Gemini operations use the configured MCP servers
                if operation == "analyze_code":
                    # Use filesystem MCP server for code analysis
                    mcp_request = {
                        "jsonrpc": "2.0",
                        "id": 1,
                        "method": "tools/call",
                        "params": {
                            "name": "read_file",
                            "arguments": {
                                "path": kwargs.get("file_path", "")
                            }
                        }
                    }
                    
                    # This would normally be handled by Gemini's MCP integration
                    # For now, we'll simulate it
                    return {
                        "success": True,
                        "output": f"Code analysis request for {kwargs.get('file_path')}",
                        "operation": operation,
                        "system": "gemini"
                    }
                
                else:
                    return {"error": f"Unknown operation: {operation}", "success": False}
                    
            except Exception as e:
                return {"error": str(e), "success": False, "system": "gemini"}
    
    def execute_coordinated_workflow(self, workflow_name: str, **kwargs) -> Dict[str, Any]:
        """Execute multi-system coordinated workflow"""
        with self.operation_context(f"workflow_{workflow_name}"):
            results = []
            
            try:
                if workflow_name == "full_project_validation":
                    # Step 1: Claude Desktop syntax check
                    syntax_result = self.execute_claude_desktop_operation("check_godot_syntax")
                    results.append(syntax_result)
                    
                    if not syntax_result["success"]:
                        return {
                            "success": False,
                            "workflow": workflow_name,
                            "failed_at": "syntax_check",
                            "results": results
                        }
                    
                    # Step 2: Godot MCP project info
                    project_result = self.execute_godot_mcp_operation("get_project_info")
                    results.append(project_result)
                    
                    # Step 3: Claude Desktop test run
                    test_result = self.execute_claude_desktop_operation("run_tests")
                    results.append(test_result)
                    
                    # Step 4: Update shared context
                    self.context.last_result = {
                        "workflow": workflow_name,
                        "success": all(r.get("success", False) for r in results),
                        "steps_completed": len(results),
                        "results": results
                    }
                    
                    return self.context.last_result
                
                elif workflow_name == "development_handoff":
                    # Prepare context for AI handoff
                    context_summary = {
                        "project_state": self.get_project_status(),
                        "recent_operations": self.context.error_history[-5:],
                        "paths": {
                            "windows": self.context.project_path_windows,
                            "wsl": self.context.project_path_wsl
                        },
                        "session_id": self.context.session_id
                    }
                    
                    # Save handoff context
                    handoff_file = self.project_root / "mcp_handoff_context.json"
                    with open(handoff_file, 'w') as f:
                        json.dump(context_summary, f, indent=2)
                    
                    return {
                        "success": True,
                        "handoff_context": context_summary,
                        "handoff_file": str(handoff_file)
                    }
                
                else:
                    return {"error": f"Unknown workflow: {workflow_name}", "success": False}
                    
            except Exception as e:
                return {
                    "error": str(e), 
                    "success": False, 
                    "workflow": workflow_name,
                    "results": results
                }
    
    def get_project_status(self) -> Dict[str, Any]:
        """Get unified project status across all systems"""
        status = {
            "context": asdict(self.context),
            "paths_accessible": {
                "windows": os.path.exists(self.context.project_path_windows),
                "wsl": True  # Assume WSL paths are accessible
            },
            "godot_accessible": {
                "windows": os.path.exists(self.context.godot_path_windows),
                "wsl": True  # Assume WSL Godot is accessible
            },
            "mcp_servers": {
                "godot_mcp": os.path.exists(self.project_root / "godot-mcp-server" / "build" / "index.js"),
                "filesystem": True,  # Configured in .gemini/settings.json
                "memory": True       # Configured in .gemini/settings.json
            }
        }
        
        return status
    
    def fix_configuration_inconsistencies(self) -> Dict[str, Any]:
        """Fix path and configuration inconsistencies across all systems"""
        fixes_applied = []
        
        try:
            # Fix 1: Update Godot MCP Server config
            godot_config_path = self.project_root / "godot-mcp-server" / "config.json"
            config = {
                "godotPath": self.context.godot_path_wsl,
                "projectPath": self.context.project_path_wsl,
                "strictPathValidation": True
            }
            
            with open(godot_config_path, 'w') as f:
                json.dump(config, f, indent=2)
            fixes_applied.append("Updated Godot MCP Server config")
            
            # Fix 2: Update Gemini MCP config paths  
            gemini_config_path = self.project_root / ".gemini" / "settings.json"
            if gemini_config_path.exists():
                with open(gemini_config_path, 'r') as f:
                    gemini_config = json.load(f)
                
                # Update filesystem server path
                if "filesystem" in gemini_config.get("mcpServers", {}):
                    gemini_config["mcpServers"]["filesystem"]["command"] = f"npx -y @modelcontextprotocol/server-filesystem@latest {self.context.project_path_wsl}"
                    
                    with open(gemini_config_path, 'w') as f:
                        json.dump(gemini_config, f, indent=2)
                    fixes_applied.append("Updated Gemini filesystem server path")
            
            # Fix 3: Create unified config file
            unified_config = {
                "universal_mcp": {
                    "version": "1.0",
                    "session_id": self.context.session_id,
                    "paths": {
                        "project_windows": self.context.project_path_windows,
                        "project_wsl": self.context.project_path_wsl,
                        "godot_windows": self.context.godot_path_windows,
                        "godot_wsl": self.context.godot_path_wsl
                    },
                    "systems": {
                        "claude_desktop": {
                            "config_file": ".claude/settings.local.json",
                            "path_format": "windows"
                        },
                        "gemini": {
                            "config_file": ".gemini/settings.json", 
                            "path_format": "wsl"
                        },
                        "godot_mcp": {
                            "config_file": "godot-mcp-server/config.json",
                            "path_format": "wsl"
                        }
                    }
                }
            }
            
            unified_config_path = self.project_root / "mcp_unified_config.json"
            with open(unified_config_path, 'w') as f:
                json.dump(unified_config, f, indent=2)
            fixes_applied.append("Created unified MCP configuration")
            
            return {
                "success": True,
                "fixes_applied": fixes_applied,
                "config_file": str(unified_config_path)
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "fixes_applied": fixes_applied
            }

def main():
    """CLI interface for Universal MCP Coordinator"""
    if len(sys.argv) < 2:
        print("Usage: python universal_mcp_coordinator.py <command> [args...]")
        print("Commands:")
        print("  status                           - Get project status")
        print("  fix-config                       - Fix configuration inconsistencies")
        print("  claude-desktop <operation>       - Execute Claude Desktop operation")
        print("  godot-mcp <operation>            - Execute Godot MCP operation")
        print("  gemini <operation>               - Execute Gemini operation")
        print("  workflow <workflow_name>         - Execute coordinated workflow")
        print("  handoff                          - Prepare context for AI handoff")
        return
    
    coordinator = UniversalMCPCoordinator()
    command = sys.argv[1]
    
    try:
        if command == "status":
            result = coordinator.get_project_status()
        elif command == "fix-config":
            result = coordinator.fix_configuration_inconsistencies()
        elif command == "claude-desktop":
            operation = sys.argv[2] if len(sys.argv) > 2 else "check_godot_syntax"
            result = coordinator.execute_claude_desktop_operation(operation)
        elif command == "godot-mcp":
            operation = sys.argv[2] if len(sys.argv) > 2 else "get_project_info"
            result = coordinator.execute_godot_mcp_operation(operation)
        elif command == "gemini":
            operation = sys.argv[2] if len(sys.argv) > 2 else "analyze_code"
            result = coordinator.execute_gemini_operation(operation)
        elif command == "workflow":
            workflow = sys.argv[2] if len(sys.argv) > 2 else "full_project_validation"
            result = coordinator.execute_coordinated_workflow(workflow)
        elif command == "handoff":
            result = coordinator.execute_coordinated_workflow("development_handoff")
        else:
            result = {"error": f"Unknown command: {command}", "success": False}
        
        print(json.dumps(result, indent=2))
        
    except Exception as e:
        print(json.dumps({"error": str(e), "success": False}, indent=2))
        sys.exit(1)

if __name__ == "__main__":
    main()
