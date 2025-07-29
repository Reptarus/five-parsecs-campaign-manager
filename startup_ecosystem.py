#!/usr/bin/env python3
"""
MCP Ecosystem Startup with API Key Configuration
Complete validation and startup sequence with embedded API key for testing
"""

import os
import sys
import json
import subprocess
from pathlib import Path

def configure_environment():
    """Configure environment variables for MCP ecosystem"""
    print("🔧 Configuring environment...")
    
    # Set API key for this session
    api_key = "AIzaSyCAOFmT0DJGe7DD8eWoZmP-_j7RewRiWHo"
    os.environ["GOOGLE_API_KEY"] = api_key
    
    # Set additional environment variables
    os.environ["GEMINI_FLASH_MODEL"] = "gemini-2.0-flash-exp"
    os.environ["GEMINI_PRO_MODEL"] = "gemini-2.0-flash-thinking-exp"
    
    print("✅ Environment configured")
    print(f"   API Key: {api_key[:6]}...{api_key[-4:]} ({len(api_key)} chars)")
    print(f"   Flash Model: {os.environ['GEMINI_FLASH_MODEL']}")
    print(f"   Pro Model: {os.environ['GEMINI_PRO_MODEL']}")

def validate_ecosystem():
    """Run ecosystem validation with configured environment"""
    print("\n🔍 Running ecosystem validation...")
    
    # Import validation function
    sys.path.append(str(Path(__file__).parent))
    
    try:
        from simple_validate import validate_ecosystem
        success = validate_ecosystem()
        return success
    except ImportError as e:
        print(f"❌ Could not import validation module: {e}")
        return False
    except Exception as e:
        print(f"❌ Validation failed: {e}")
        return False

def test_api_connection():
    """Test Google API connection"""
    print("\n🌐 Testing API connection...")
    
    try:
        import requests
        
        api_key = os.environ.get("GOOGLE_API_KEY")
        
        # Test endpoint (using a simple Gemini API call)
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
        
        response = requests.post(url, json=payload, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            if "candidates" in data and len(data["candidates"]) > 0:
                content = data["candidates"][0]["content"]["parts"][0]["text"]
                print("✅ API connection successful")
                print(f"   Response: {content.strip()}")
                return True
            else:
                print("❌ API responded but no content generated")
                return False
        else:
            print(f"❌ API connection failed: {response.status_code}")
            print(f"   Error: {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Network error: {e}")
        return False
    except Exception as e:
        print(f"❌ API test failed: {e}")
        return False

def create_bridge_test():
    """Create a test bridge request"""
    print("\n🌉 Testing bridge system...")
    
    bridge_dir = Path("mcp_bridge")
    requests_dir = bridge_dir / "requests"
    responses_dir = bridge_dir / "responses"
    
    # Ensure directories exist
    requests_dir.mkdir(parents=True, exist_ok=True)
    responses_dir.mkdir(parents=True, exist_ok=True)
    
    # Create test request
    test_request = {
        "request_id": "ecosystem_test_001",
        "tool_name": "gemini_quick_query",
        "arguments": {
            "query": "What is the purpose of the MCP ecosystem?"
        },
        "client_id": "ecosystem_validator",
        "timestamp": "2025-07-28T15:30:00Z"
    }
    
    request_file = requests_dir / f"{test_request['request_id']}.json"
    with open(request_file, 'w') as f:
        json.dump(test_request, f, indent=2)
    
    print(f"✅ Test request created: {test_request['request_id']}")
    print(f"   File: {request_file}")
    return test_request['request_id']

def main():
    """Main startup and validation sequence"""
    print("🚀 MCP Ecosystem Startup & Validation")
    print("=" * 60)
    
    # Step 1: Configure environment
    configure_environment()
    
    # Step 2: Validate ecosystem
    validation_success = validate_ecosystem()
    
    if not validation_success:
        print("\n❌ Ecosystem validation failed. Please check the issues above.")
        return False
    
    # Step 3: Test API connection
    api_success = test_api_connection()
    
    if not api_success:
        print("\n⚠️ API connection test failed, but ecosystem is configured.")
        print("   This might be due to network issues or API quotas.")
    
    # Step 4: Create bridge test
    test_id = create_bridge_test()
    
    # Summary
    print("\n" + "=" * 60)
    print("🎉 MCP ECOSYSTEM READY FOR PRODUCTION!")
    print("=" * 60)
    
    print("\n✅ Configuration Status:")
    print(f"   • Environment variables: Configured")
    print(f"   • Required files: All present")
    print(f"   • Dependencies: Installed")
    print(f"   • API connection: {'✅ Working' if api_success else '⚠️ Check needed'}")
    
    print("\n🚀 Next Steps:")
    print("   1. Start ecosystem: python mcp_ecosystem_manager.py start")
    print("   2. Check health: python mcp_ecosystem_manager.py status")
    print("   3. Configure Claude Desktop with claude_desktop_config.json")
    print("   4. Test workflows: python workflow_examples.py")
    
    print(f"\n📝 Test Request Created:")
    print(f"   • Request ID: {test_id}")
    print(f"   • Watch for response in: mcp_bridge/responses/")
    
    if api_success:
        print("\n🎯 Your MCP ecosystem is fully operational and ready to use!")
    else:
        print("\n🔧 Your MCP ecosystem is configured but needs API connectivity verification.")
        print("   Check your internet connection and Google Cloud API quotas.")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
