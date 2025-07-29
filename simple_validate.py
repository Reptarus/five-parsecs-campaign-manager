#!/usr/bin/env python3
"""
Simple MCP Ecosystem Validation
"""

import os
import json
import sys
from pathlib import Path

def validate_ecosystem():
    """Perform basic validation of MCP ecosystem"""
    print("MCP Ecosystem Validation")
    print("=" * 50)
    
    issues = []
    
    # Check 1: Required files
    required_files = [
        "mcp_config.json",
        "mcp_process_manager.py", 
        "mcp_bridge_processor.py",
        "mcp_ecosystem_manager.py",
        "claude_desktop_config.json"
    ]
    
    print("Checking required files...")
    for file_path in required_files:
        if Path(file_path).exists():
            print(f"  [OK] {file_path}")
        else:
            print(f"  [MISSING] {file_path}")
            issues.append(f"Missing file: {file_path}")
    
    # Check 2: Configuration validation
    print("\nValidating configuration...")
    try:
        with open("mcp_config.json") as f:
            config = json.load(f)
        
        servers = config.get("servers", {})
        print(f"  [OK] Configuration valid - {len(servers)} servers configured")
        for server_name in servers.keys():
            print(f"     - {server_name}")
            
    except FileNotFoundError:
        print(f"  [ERROR] mcp_config.json not found")
        issues.append("Configuration file missing")
    except json.JSONDecodeError as e:
        print(f"  [ERROR] Invalid JSON in mcp_config.json: {e}")
        issues.append("Invalid configuration format")
    
    # Check 3: Environment variables
    print("\nChecking environment variables...")
    required_env = ["GOOGLE_API_KEY"]
    for var in required_env:
        if os.getenv(var):
            print(f"  [OK] {var} is set")
        else:
            print(f"  [MISSING] {var}")
            issues.append(f"Missing environment variable: {var}")
    
    # Check 4: Directory structure
    print("\nChecking directory structure...")
    required_dirs = [
        "mcp_bridge/requests",
        "mcp_bridge/responses",
        "logs",
        "metrics"
    ]
    
    for dir_path in required_dirs:
        dir_obj = Path(dir_path)
        if dir_obj.exists():
            print(f"  [OK] {dir_path}")
        else:
            print(f"  [CREATE] {dir_path}")
            dir_obj.mkdir(parents=True, exist_ok=True)
            print(f"  [OK] {dir_path} - Created")
    
    # Check 5: Python dependencies
    print("\nChecking Python dependencies...")
    required_packages = ["psutil", "aiofiles", "watchdog", "requests"]
    for package in required_packages:
        try:
            __import__(package)
            print(f"  [OK] {package}")
        except ImportError:
            print(f"  [MISSING] {package}")
            issues.append(f"Missing Python package: {package}")
    
    # Summary
    print("\n" + "=" * 50)
    if not issues:
        print("VALIDATION SUCCESSFUL")
        print("Your MCP ecosystem is properly configured!")
        print("\nNext steps:")
        print("1. Start ecosystem: python mcp_ecosystem_manager.py start")
        print("2. Check health: python mcp_ecosystem_manager.py status") 
        print("3. Configure Claude Desktop with claude_desktop_config.json")
        return True
    else:
        print("VALIDATION ISSUES FOUND")
        print(f"{len(issues)} issue(s) need to be resolved:")
        for i, issue in enumerate(issues, 1):
            print(f"{i}. {issue}")
        print("\nResolve these issues and run validation again.")
        return False

if __name__ == "__main__":
    success = validate_ecosystem()
    sys.exit(0 if success else 1)
