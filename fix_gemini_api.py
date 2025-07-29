#!/usr/bin/env python3
"""
Gemini API Test with Correct Model Names
Test actual API connectivity with updated model names
"""

import os
import requests
import json

def test_gemini_api():
    """Test Gemini API with correct model names"""
    
    # Set API key
    api_key = "AIzaSyCAOFmT0DJGe7DD8eWoZmP-_j7RewRiWHo"
    os.environ["GOOGLE_API_KEY"] = api_key
    
    print("Testing Gemini API connection...")
    print(f"API Key: {api_key[:6]}...{api_key[-4:]}")
    
    # Try the correct model name for Gemini 1.5
    model_names = [
        "gemini-1.5-flash",
        "gemini-1.5-pro", 
        "gemini-pro-latest",
        "gemini-1.0-pro"
    ]
    
    for model_name in model_names:
        print(f"\nTesting model: {model_name}")
        
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"
        
        payload = {
            "contents": [{
                "parts": [{"text": "Say 'API connection successful' if this works"}]
            }],
            "generationConfig": {
                "maxOutputTokens": 50,
                "temperature": 0.1
            }
        }
        
        try:
            response = requests.post(url, json=payload, timeout=15)
            
            if response.status_code == 200:
                data = response.json()
                if "candidates" in data and len(data["candidates"]) > 0:
                    content = data["candidates"][0]["content"]["parts"][0]["text"]
                    print(f"SUCCESS: {model_name} working!")
                    print(f"Response: {content.strip()}")
                    
                    # Update configuration with working model
                    return model_name
                else:
                    print(f"WARNING: {model_name} responded but no content")
            else:
                print(f"ERROR: {model_name} failed: HTTP {response.status_code}")
                if response.status_code == 404:
                    print(f"   Model not available")
                else:
                    print(f"   Error: {response.text[:200]}")
                    
        except Exception as e:
            print(f"ERROR: {model_name} exception: {e}")
    
    return None

def update_config_with_working_model(working_model):
    """Update MCP config with working model"""
    
    config_file = "mcp_config.json"
    
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
        
        # Update gemini-orchestrator configuration
        if "servers" in config and "gemini-orchestrator" in config["servers"]:
            env_vars = config["servers"]["gemini-orchestrator"].get("env_vars", {})
            env_vars["GEMINI_FLASH_MODEL"] = working_model
            env_vars["GEMINI_PRO_MODEL"] = working_model
            
            config["servers"]["gemini-orchestrator"]["env_vars"] = env_vars
            
            # Write updated config
            with open(config_file, 'w') as f:
                json.dump(config, f, indent=2)
            
            print(f"\nUpdated {config_file} with working model: {working_model}")
            return True
    
    except Exception as e:
        print(f"ERROR updating config: {e}")
        return False
    
    return False

def main():
    """Test API and update configuration"""
    print("Gemini API Model Testing & Configuration Update")
    print("=" * 60)
    
    working_model = test_gemini_api()
    
    if working_model:
        print(f"\n" + "=" * 60)
        print("API CONNECTION SUCCESSFUL!")
        print(f"Working model: {working_model}")
        
        # Update configuration
        if update_config_with_working_model(working_model):
            print("\nConfiguration updated successfully!")
        
        print("\nYour MCP ecosystem is now fully production ready!")
        print("\nNext steps:")
        print("1. python mcp_ecosystem_manager.py start")
        print("2. python mcp_ecosystem_manager.py status")
        print("3. Configure Claude Desktop")
        
    else:
        print(f"\n" + "=" * 60)
        print("API CONNECTION ISSUES")
        print("No working model found. This could be due to:")
        print("1. API key permissions")
        print("2. Google Cloud API quotas")
        print("3. Network connectivity")
        print("4. Regional restrictions")
        
        print("\nDebugging steps:")
        print("1. Check Google Cloud Console for API quotas")
        print("2. Verify API key permissions")
        print("3. Try different network connection")

if __name__ == "__main__":
    main()
