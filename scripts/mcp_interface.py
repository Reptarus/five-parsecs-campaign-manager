#!/usr/bin/env python3
"""
MCP Interface Wrapper for Five Parsecs Campaign Manager
Provides programmatic access to Obsidian MCP and Desktop Commander
"""

import json
import subprocess
import sys
import os
import tempfile
import threading
import time
from typing import Dict, Any, Optional, List
from pathlib import Path

class MCPInterface:
    def __init__(self):
        self.project_root = Path(__file__).parent.parent
        self.obsidian_vault = Path("/mnt/c/Users/elija/SynologyDrive/Godot/Obsidian/Scripts and Home")
        self.obsidian_mcp_path = self.obsidian_vault / ".obsidian/plugins/mcp-tools/bin/mcp-server.exe"
        self.obsidian_api_key = "18908571648600e2729c18047bdfd9b736b7dee4af616c2d6bb884db3b79fdc2"
        
    def execute_desktop_command(self, command: str, args: List[str] = None) -> Dict[str, Any]:
        """Execute a command through desktop-commander MCP"""
        if args is None:
            args = []
            
        try:
            # Create MCP request
            mcp_request = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/call",
                "params": {
                    "name": "execute_command",
                    "arguments": {
                        "command": command,
                        "args": args
                    }
                }
            }
            
            # Run desktop-commander
            proc = subprocess.Popen(
                ["npx", "@wonderwhy-er/desktop-commander@latest"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=self.project_root
            )
            
            # Send request
            stdout, stderr = proc.communicate(input=json.dumps(mcp_request))
            
            if proc.returncode != 0:
                return {"error": f"Desktop commander failed: {stderr}", "success": False}
                
            try:
                response = json.loads(stdout)
                return {"result": response, "success": True}
            except json.JSONDecodeError:
                return {"result": stdout, "success": True}
                
        except Exception as e:
            return {"error": str(e), "success": False}
    
    def obsidian_search(self, query: str, vault_path: str = None) -> Dict[str, Any]:
        """Search Obsidian vault using MCP"""
        if vault_path is None:
            vault_path = str(self.obsidian_vault)
            
        try:
            mcp_request = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/call",
                "params": {
                    "name": "search_notes",
                    "arguments": {
                        "query": query,
                        "vault_path": vault_path
                    }
                }
            }
            
            env = os.environ.copy()
            env["OBSIDIAN_API_KEY"] = self.obsidian_api_key
            env["OBSIDIAN_HOST"] = "https://127.0.0.1:27124"
            
            proc = subprocess.Popen(
                [str(self.obsidian_mcp_path)],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env
            )
            
            stdout, stderr = proc.communicate(input=json.dumps(mcp_request))
            
            if proc.returncode != 0:
                return {"error": f"Obsidian MCP failed: {stderr}", "success": False}
                
            try:
                response = json.loads(stdout)
                return {"result": response, "success": True}
            except json.JSONDecodeError:
                return {"result": stdout, "success": True}
                
        except Exception as e:
            return {"error": str(e), "success": False}
    
    def obsidian_create_note(self, title: str, content: str, folder: str = None) -> Dict[str, Any]:
        """Create a new note in Obsidian vault"""
        try:
            mcp_request = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/call",
                "params": {
                    "name": "create_note",
                    "arguments": {
                        "title": title,
                        "content": content,
                        "folder": folder or ""
                    }
                }
            }
            
            env = os.environ.copy()
            env["OBSIDIAN_API_KEY"] = self.obsidian_api_key
            env["OBSIDIAN_HOST"] = "https://127.0.0.1:27124"
            
            proc = subprocess.Popen(
                [str(self.obsidian_mcp_path)],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env
            )
            
            stdout, stderr = proc.communicate(input=json.dumps(mcp_request))
            
            if proc.returncode != 0:
                return {"error": f"Obsidian MCP failed: {stderr}", "success": False}
                
            try:
                response = json.loads(stdout)
                return {"result": response, "success": True}
            except json.JSONDecodeError:
                return {"result": stdout, "success": True}
                
        except Exception as e:
            return {"error": str(e), "success": False}

class FiveParsecsTools:
    """Five Parsecs specific MCP tool integrations"""
    
    def __init__(self):
        self.mcp = MCPInterface()
        
    def document_rules_implementation(self, rule_name: str, implementation_details: str) -> Dict[str, Any]:
        """Document how a Five Parsecs rule was implemented"""
        note_title = f"Implementation: {rule_name}"
        content = f"""# {rule_name} Implementation

## Rule Source
Five Parsecs From Home - {rule_name}

## Implementation Details
{implementation_details}

## Code Location
- Project: Five Parsecs Campaign Manager
- Repository: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/`

## Status
- [ ] Implemented
- [ ] Tested
- [ ] Documented
- [ ] Rules Compliant

## Related Files
*Add relevant file paths here*

## Notes
*Implementation notes and decisions*

---
Tags: #five-parsecs #implementation #rules
Created: {time.strftime("%Y-%m-%d %H:%M:%S")}
"""
        
        return self.mcp.obsidian_create_note(note_title, content, "Five Parsecs/Implementation")
    
    def search_rules_documentation(self, rule_term: str) -> Dict[str, Any]:
        """Search existing Five Parsecs documentation"""
        return self.mcp.obsidian_search(f"Five Parsecs {rule_term}")
    
    def build_project(self) -> Dict[str, Any]:
        """Build the Five Parsecs project using desktop commander"""
        return self.mcp.execute_desktop_command("godot", ["-s", "build.gd"])
    
    def run_tests(self) -> Dict[str, Any]:
        """Run project tests"""
        return self.mcp.execute_desktop_command("godot", ["-s", "build.gd", "--run-tests"])
    
    def export_project(self, platform: str = "Windows Desktop") -> Dict[str, Any]:
        """Export project for specified platform"""
        return self.mcp.execute_desktop_command("godot", ["--export-release", platform])

def main():
    """CLI interface for MCP tools"""
    if len(sys.argv) < 2:
        print("Usage: python mcp_interface.py <command> [args...]")
        print("Commands:")
        print("  obsidian-search <query>")
        print("  obsidian-note <title> <content> [folder]")
        print("  desktop-cmd <command> [args...]")
        print("  document-rule <rule_name> <implementation>")
        print("  search-rules <term>")
        print("  build")
        print("  test")
        print("  export [platform]")
        return
    
    command = sys.argv[1]
    tools = FiveParsecsTools()
    
    try:
        if command == "obsidian-search":
            if len(sys.argv) < 3:
                print("Usage: obsidian-search <query>")
                return
            result = tools.mcp.obsidian_search(sys.argv[2])
            
        elif command == "obsidian-note":
            if len(sys.argv) < 4:
                print("Usage: obsidian-note <title> <content> [folder]")
                return
            folder = sys.argv[4] if len(sys.argv) > 4 else None
            result = tools.mcp.obsidian_create_note(sys.argv[2], sys.argv[3], folder)
            
        elif command == "desktop-cmd":
            if len(sys.argv) < 3:
                print("Usage: desktop-cmd <command> [args...]")
                return
            result = tools.mcp.execute_desktop_command(sys.argv[2], sys.argv[3:])
            
        elif command == "document-rule":
            if len(sys.argv) < 4:
                print("Usage: document-rule <rule_name> <implementation>")
                return
            result = tools.document_rules_implementation(sys.argv[2], sys.argv[3])
            
        elif command == "search-rules":
            if len(sys.argv) < 3:
                print("Usage: search-rules <term>")
                return
            result = tools.search_rules_documentation(sys.argv[2])
            
        elif command == "build":
            result = tools.build_project()
            
        elif command == "test":
            result = tools.run_tests()
            
        elif command == "export":
            platform = sys.argv[2] if len(sys.argv) > 2 else "Windows Desktop"
            result = tools.export_project(platform)
            
        else:
            print(f"Unknown command: {command}")
            return
        
        print(json.dumps(result, indent=2))
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()