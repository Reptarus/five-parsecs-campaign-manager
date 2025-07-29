#!/usr/bin/env python3
"""
Quick MCP Ecosystem Validation
Simple validation script to check if the ecosystem is properly configured
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
    print("\n⚙️ Validating configuration...")
    try:
        with open("mcp_config.json") as f:
            config = json.load(f)
        
        # Check server configurations
        servers = config.get("servers", {})
        print(f"  ✅ Configuration valid - {len(servers)} servers configured")
        for server_name in servers.keys():
            print(f"     • {server_name}")
            
    except FileNotFoundError:
        print(f"  ❌ mcp_config.json not found")
        issues.append("Configuration file missing")
    except json.JSONDecodeError as e:
        print(f"  ❌ Invalid JSON in mcp_config.json: {e}")
        issues.append("Invalid configuration format")
    
    # Check 3: Environment variables
    print("\n🌍 Checking environment variables...")
    required_env = ["GOOGLE_API_KEY"]
    for var in required_env:
        if os.getenv(var):
            print(f"  ✅ {var} is set")
        else:
            print(f"  ❌ {var} - NOT SET")
            issues.append(f"Missing environment variable: {var}")
    
    # Check 4: Directory structure
    print("\n📂 Checking directory structure...")
    required_dirs = [
        "mcp_bridge/requests",
        "mcp_bridge/responses",
        "logs",
        "metrics"
    ]
    
    for dir_path in required_dirs:
        dir_obj = Path(dir_path)
        if dir_obj.exists():
            print(f"  ✅ {dir_path}")
        else:
            print(f"  📁 {dir_path} - Creating...")
            dir_obj.mkdir(parents=True, exist_ok=True)
            print(f"  ✅ {dir_path} - Created")
    
    # Check 5: Python dependencies
    print("\n🐍 Checking Python dependencies...")
    required_packages = ["psutil", "aiofiles", "watchdog", "requests"]
    for package in required_packages:
        try:
            __import__(package)
            print(f"  ✅ {package}")
        except ImportError:
            print(f"  ❌ {package} - NOT INSTALLED")
            issues.append(f"Missing Python package: {package}")
    
    # Check 6: Process status
    print("\n🔄 Checking current processes...")
    try:
        import psutil
        python_processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                if proc.info['name'] == 'python.exe' and proc.info['cmdline']:
                    cmdline = ' '.join(proc.info['cmdline'])
                    if any(keyword in cmdline for keyword in ['mcp', 'gemini', 'bridge']):
                        python_processes.append({
                            'pid': proc.info['pid'],
                            'cmdline': cmdline[:80] + '...' if len(cmdline) > 80 else cmdline
                        })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        
        if python_processes:
            print(f"  🟡 Found {len(python_processes)} MCP-related processes:")
            for proc in python_processes[:5]:  # Show first 5
                print(f"     • PID {proc['pid']}: {proc['cmdline']}")
            if len(python_processes) > 5:
                print(f"     ... and {len(python_processes) - 5} more")
        else:
            print(f"  ℹ️ No MCP processes currently running")
            
    except ImportError:
        print(f"  ⚠️ Cannot check processes (psutil not available)")
    
    # Summary
    print("\n" + "=" * 50)
    if not issues:
        print("🎉 VALIDATION SUCCESSFUL")
        print("   Your MCP ecosystem is properly configured!")
        print("\n📋 Next steps:")
        print("   1. Start ecosystem: python mcp_ecosystem_manager.py start")
        print("   2. Check health: python mcp_ecosystem_manager.py status") 
        print("   3. Configure Claude Desktop with claude_desktop_config.json")
        return True
    else:
        print("⚠️ VALIDATION ISSUES FOUND")
        print(f"   {len(issues)} issue(s) need to be resolved:")
        for i, issue in enumerate(issues, 1):
            print(f"   {i}. {issue}")
        print("\n🔧 Resolve these issues and run validation again.")
        return False

if __name__ == "__main__":
    success = validate_ecosystem()
    sys.exit(0 if success else 1)
