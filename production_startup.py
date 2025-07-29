#!/usr/bin/env python3
"""
MCP Ecosystem Production Startup & Validation
Complete validation and startup sequence for Windows environments
"""

import os
import sys
import json
import subprocess
import time
from pathlib import Path

def configure_environment():
    """Configure environment variables for MCP ecosystem"""
    print("Configuring environment...")
    
    # Set API key for this session
    api_key = "AIzaSyCAOFmT0DJGe7DD8eWoZmP-_j7RewRiWHo"
    os.environ["GOOGLE_API_KEY"] = api_key
    
    # Set additional environment variables
    os.environ["GEMINI_FLASH_MODEL"] = "gemini-2.0-flash-exp"
    os.environ["GEMINI_PRO_MODEL"] = "gemini-2.0-flash-thinking-exp"
    
    print("Environment configured successfully")
    print(f"   API Key: {api_key[:6]}...{api_key[-4:]} ({len(api_key)} chars)")
    print(f"   Flash Model: {os.environ['GEMINI_FLASH_MODEL']}")
    print(f"   Pro Model: {os.environ['GEMINI_PRO_MODEL']}")

def validate_ecosystem():
    """Run ecosystem validation with configured environment"""
    print("\nRunning ecosystem validation...")
    
    # Import validation function
    sys.path.append(str(Path(__file__).parent))
    
    try:
        from simple_validate import validate_ecosystem
        success = validate_ecosystem()
        return success
    except ImportError as e:
        print(f"ERROR: Could not import validation module: {e}")
        return False
    except Exception as e:
        print(f"ERROR: Validation failed: {e}")
        return False

def test_api_connection():
    """Test Google Gemini API connection"""
    print("\nTesting API connection...")
    
    try:
        import requests
        
        api_key = os.environ.get("GOOGLE_API_KEY")
        
        # Test endpoint using Gemini API
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key={api_key}"
        
        payload = {
            "contents": [{
                "parts": [{"text": "Hello, this is a test. Please respond with 'API connection successful'"}]
            }],
            "generationConfig": {
                "maxOutputTokens": 50,
                "temperature": 0.1
            }
        }
        
        print("   Making API request...")
        response = requests.post(url, json=payload, timeout=15)
        
        if response.status_code == 200:
            data = response.json()
            if "candidates" in data and len(data["candidates"]) > 0:
                content = data["candidates"][0]["content"]["parts"][0]["text"]
                print("SUCCESS: API connection working")
                print(f"   Response: {content.strip()}")
                return True
            else:
                print("WARNING: API responded but no content generated")
                print(f"   Response: {data}")
                return False
        else:
            print(f"ERROR: API connection failed: HTTP {response.status_code}")
            print(f"   Error: {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"ERROR: Network error: {e}")
        return False
    except Exception as e:
        print(f"ERROR: API test failed: {e}")
        return False

def create_bridge_test():
    """Create a test bridge request"""
    print("\nTesting bridge system...")
    
    bridge_dir = Path("mcp_bridge")
    requests_dir = bridge_dir / "requests"
    responses_dir = bridge_dir / "responses"
    
    # Ensure directories exist
    requests_dir.mkdir(parents=True, exist_ok=True)
    responses_dir.mkdir(parents=True, exist_ok=True)
    
    # Create test request
    test_request = {
        "request_id": "production_test_001",
        "tool_name": "gemini_quick_query",
        "arguments": {
            "query": "Explain the purpose of the MCP ecosystem in 2 sentences."
        },
        "client_id": "production_validator",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ")
    }
    
    request_file = requests_dir / f"{test_request['request_id']}.json"
    with open(request_file, 'w') as f:
        json.dump(test_request, f, indent=2)
    
    print(f"SUCCESS: Test request created: {test_request['request_id']}")
    print(f"   File: {request_file}")
    return test_request['request_id']

def check_process_status():
    """Check current MCP process status"""
    print("\nChecking MCP process status...")
    
    try:
        import psutil
        
        mcp_processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'memory_info']):
            try:
                if proc.info['name'] == 'python.exe' and proc.info['cmdline']:
                    cmdline = ' '.join(proc.info['cmdline'])
                    if any(keyword in cmdline.lower() for keyword in ['mcp', 'gemini', 'bridge']):
                        memory_mb = proc.info['memory_info'].rss / (1024 * 1024)
                        mcp_processes.append({
                            'pid': proc.info['pid'],
                            'memory_mb': memory_mb,
                            'cmdline': cmdline[:80] + '...' if len(cmdline) > 80 else cmdline
                        })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        
        if mcp_processes:
            print(f"   Found {len(mcp_processes)} MCP-related processes:")
            total_memory = 0
            for proc in mcp_processes[:5]:  # Show first 5
                print(f"   PID {proc['pid']:5} | {proc['memory_mb']:6.1f}MB | {proc['cmdline']}")
                total_memory += proc['memory_mb']
            
            if len(mcp_processes) > 5:
                print(f"   ... and {len(mcp_processes) - 5} more processes")
            
            print(f"   Total memory usage: {total_memory:.1f}MB")
            
            if len(mcp_processes) > 20:
                print("   WARNING: High number of MCP processes detected")
                print("   Consider running production cleanup if needed")
        else:
            print("   No MCP processes currently running")
        
        return len(mcp_processes)
        
    except ImportError:
        print("   Cannot check processes (psutil not available)")
        return 0
    except Exception as e:
        print(f"   Error checking processes: {e}")
        return 0

def main():
    """Main startup and validation sequence"""
    print("MCP Ecosystem Production Startup & Validation")
    print("=" * 60)
    
    # Step 1: Configure environment
    configure_environment()
    
    # Step 2: Check current process status
    process_count = check_process_status()
    
    # Step 3: Validate ecosystem
    validation_success = validate_ecosystem()
    
    if not validation_success:
        print("\nERROR: Ecosystem validation failed. Please check the issues above.")
        return False
    
    # Step 4: Test API connection
    api_success = test_api_connection()
    
    # Step 5: Create bridge test
    test_id = create_bridge_test()
    
    # Summary
    print("\n" + "=" * 60)
    print("MCP ECOSYSTEM STATUS REPORT")
    print("=" * 60)
    
    print("\nConfiguration Status:")
    print(f"   Environment variables: CONFIGURED")
    print(f"   Required files: ALL PRESENT")
    print(f"   Dependencies: INSTALLED")
    print(f"   Current MCP processes: {process_count}")
    print(f"   API connection: {'WORKING' if api_success else 'NEEDS CHECK'}")
    
    if validation_success and api_success:
        status = "PRODUCTION READY"
        print(f"\nOverall Status: {status}")
        print("\nREADY TO USE! Next Steps:")
        print("   1. Start ecosystem: python mcp_ecosystem_manager.py start")
        print("   2. Check health: python mcp_ecosystem_manager.py status")
        print("   3. Configure Claude Desktop with claude_desktop_config.json")
        print("   4. Test workflows: python workflow_examples.py")
    elif validation_success:
        status = "CONFIGURED (API CHECK NEEDED)"
        print(f"\nOverall Status: {status}")
        print("\nConfiguration complete, but API connectivity needs verification.")
        print("Check your internet connection and Google Cloud API quotas.")
    else:
        status = "CONFIGURATION ISSUES"
        print(f"\nOverall Status: {status}")
        print("\nPlease resolve the validation issues above before proceeding.")
    
    print(f"\nTest Request Created:")
    print(f"   Request ID: {test_id}")
    print(f"   Watch for response in: mcp_bridge/responses/")
    
    print(f"\nAPI Key Configuration:")
    print(f"   Session: Configured for this terminal session")
    print(f"   Persistent: Use the commands below for permanent setup")
    
    print(f"\nFor Permanent API Key Setup:")
    print(f"   PowerShell: [Environment]::SetEnvironmentVariable('GOOGLE_API_KEY', 'your_key', 'User')")
    print(f"   Or add to your system environment variables")
    
    return validation_success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
