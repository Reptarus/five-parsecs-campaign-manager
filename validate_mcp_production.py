#!/usr/bin/env python3
"""
Production MCP Configuration Validation Suite
Validates all MCP server configurations, paths, and dependencies
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from datetime import datetime

class MCPValidator:
    def __init__(self):
        self.config_path = "/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/.mcp.json"
        self.results = []
        self.errors = []
        
    def log_result(self, test_name, status, message=""):
        """Log test result"""
        result = {
            "test": test_name,
            "status": status,
            "message": message,
            "timestamp": datetime.now().isoformat()
        }
        self.results.append(result)
        status_symbol = "✅" if status == "PASS" else "❌" if status == "FAIL" else "⚠️"
        print(f"{status_symbol} {test_name}: {message}")
    
    def validate_json_syntax(self):
        """Validate JSON syntax of .mcp.json"""
        try:
            with open(self.config_path, 'r') as f:
                json.load(f)
            self.log_result("JSON Syntax", "PASS", "Configuration file is valid JSON")
            return True
        except Exception as e:
            self.log_result("JSON Syntax", "FAIL", f"Invalid JSON: {str(e)}")
            return False
    
    def validate_executables(self):
        """Test all executable paths"""
        executables = [
            ("python3", "/usr/bin/python3"),
            ("node", "/home/elijah/.nvm/versions/node/v18.20.8/bin/node"),
            ("npx", "/home/elijah/.nvm/versions/node/v18.20.8/bin/npx")
        ]
        
        all_passed = True
        for name, path in executables:
            if os.path.exists(path) and os.access(path, os.X_OK):
                self.log_result(f"Executable: {name}", "PASS", f"Found at {path}")
            else:
                self.log_result(f"Executable: {name}", "FAIL", f"Missing or not executable: {path}")
                all_passed = False
        
        return all_passed
    
    def validate_python_scripts(self):
        """Validate Python MCP server scripts exist and are accessible"""
        scripts = [
            "/mnt/c/Users/elija/Creative-Tools-MCP/community-mcp-servers/claude-gemini-mcp-slim-main/gemini_mcp_server.py",
            "/mnt/c/Users/elija/AppData/Roaming/Claude/Claude Extensions/ant.dir.cursortouch.windows-mcp/main.py"
        ]
        
        all_passed = True
        for script in scripts:
            if os.path.exists(script):
                self.log_result(f"Python Script", "PASS", f"Found: {os.path.basename(script)}")
            else:
                self.log_result(f"Python Script", "FAIL", f"Missing: {script}")
                all_passed = False
        
        return all_passed
    
    def validate_bridge_infrastructure(self):
        """Test bridge directory functionality"""
        bridge_dir = "/mnt/c/Users/elija/Claude-Bridge-State/mcp_bridge"
        test_file = f"{bridge_dir}/validation_test_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        try:
            # Test write capability
            test_data = {"validation": "success", "timestamp": datetime.now().isoformat()}
            with open(test_file, 'w') as f:
                json.dump(test_data, f)
            
            # Test read capability
            with open(test_file, 'r') as f:
                read_data = json.load(f)
            
            # Cleanup
            os.remove(test_file)
            
            self.log_result("Bridge Infrastructure", "PASS", "Read/write operations successful")
            return True
        except Exception as e:
            self.log_result("Bridge Infrastructure", "FAIL", f"Bridge test failed: {str(e)}")
            return False
    
    def validate_environment_variables(self):
        """Check critical environment variables"""
        required_paths = [
            "/mnt/c/Users/elija/Creative-Tools-MCP",
            "/mnt/c/Users/elija/Claude-Bridge-State"
        ]
        
        all_passed = True
        for path in required_paths:
            if os.path.exists(path):
                self.log_result("Environment Path", "PASS", f"Accessible: {path}")
            else:
                self.log_result("Environment Path", "FAIL", f"Missing: {path}")
                all_passed = False
        
        return all_passed
    
    def test_node_packages(self):
        """Test if required Node packages can be accessed"""
        packages = [
            "@modelcontextprotocol/server-memory@latest",
            "@modelcontextprotocol/server-filesystem@latest", 
            "@wonderwhy-er/desktop-commander@latest"
        ]
        
        all_passed = True
        for package in packages:
            try:
                result = subprocess.run(['npx', '-y', package, '--help'], 
                                      capture_output=True, text=True, timeout=10)
                if result.returncode == 0 or "help" in result.stdout.lower() or "usage" in result.stdout.lower():
                    self.log_result("Node Package", "PASS", f"Accessible: {package}")
                else:
                    self.log_result("Node Package", "WARN", f"May have issues: {package}")
            except Exception as e:
                self.log_result("Node Package", "FAIL", f"Failed to test: {package} - {str(e)}")
                all_passed = False
        
        return all_passed
    
    def run_full_validation(self):
        """Run complete validation suite"""
        print("🚀 Starting MCP Production Validation Suite")
        print("=" * 60)
        
        tests = [
            self.validate_json_syntax,
            self.validate_executables,
            self.validate_python_scripts,
            self.validate_bridge_infrastructure,
            self.validate_environment_variables,
            self.test_node_packages
        ]
        
        passed = 0
        total = len(tests)
        
        for test in tests:
            if test():
                passed += 1
        
        print("\n" + "=" * 60)
        print(f"📊 Validation Results: {passed}/{total} tests passed")
        
        if passed == total:
            print("✅ All systems operational - MCP configuration is production-ready!")
            return True
        else:
            print(f"⚠️  {total - passed} issues found - review failed tests above")
            return False
    
    def generate_report(self):
        """Generate detailed validation report"""
        report = {
            "validation_timestamp": datetime.now().isoformat(),
            "total_tests": len(self.results),
            "passed_tests": len([r for r in self.results if r["status"] == "PASS"]),
            "failed_tests": len([r for r in self.results if r["status"] == "FAIL"]),
            "warning_tests": len([r for r in self.results if r["status"] == "WARN"]),
            "results": self.results
        }
        
        report_path = "/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/mcp_validation_report.json"
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"📋 Detailed report saved to: {report_path}")

if __name__ == "__main__":
    validator = MCPValidator()
    success = validator.run_full_validation()
    validator.generate_report()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)