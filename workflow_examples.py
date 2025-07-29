#!/usr/bin/env python3
"""
MCP Bridge Client - Cross-Platform Interface
Simple client for interacting with the MCP bridge system from any platform
"""

import json
import uuid
import time
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, Optional

class MCPBridgeClient:
    """Client for communicating with MCP bridge system"""
    
    def __init__(self, bridge_dir: str = "mcp_bridge"):
        self.bridge_dir = Path(bridge_dir)
        self.requests_dir = self.bridge_dir / "requests"
        self.responses_dir = self.bridge_dir / "responses"
        
        # Ensure directories exist
        self.requests_dir.mkdir(parents=True, exist_ok=True)
        self.responses_dir.mkdir(parents=True, exist_ok=True)
    
    def send_request(self, tool_name: str, arguments: Dict[str, Any], 
                    client_id: str = "bridge_client", timeout: int = 30) -> Dict[str, Any]:
        """Send request to MCP bridge and wait for response"""
        
        request_id = str(uuid.uuid4())
        
        # Create request
        request = {
            "request_id": request_id,
            "tool_name": tool_name,
            "arguments": arguments,
            "client_id": client_id,
            "timestamp": datetime.now().isoformat(),
            "timeout_seconds": timeout
        }
        
        # Write request file
        request_file = self.requests_dir / f"{request_id}.json"
        with open(request_file, 'w') as f:
            json.dump(request, f, indent=2)
        
        print(f"📤 Request sent: {request_id} ({tool_name})")
        
        # Wait for response
        response_file = self.responses_dir / f"{request_id}.json"
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            if response_file.exists():
                with open(response_file, 'r') as f:
                    response = json.load(f)
                
                print(f"📥 Response received: {request_id}")
                return response
            
            time.sleep(0.5)  # Check every 500ms
        
        raise TimeoutError(f"No response received within {timeout} seconds")
    
    def gemini_quick_query(self, query: str, client_id: str = "bridge_client") -> str:
        """Send quick query to Gemini via bridge"""
        response = self.send_request(
            tool_name="gemini_quick_query",
            arguments={"query": query},
            client_id=client_id
        )
        
        if response.get("status") == "completed":
            return response["data"]["answer"]
        else:
            raise RuntimeError(f"Query failed: {response.get('error', 'Unknown error')}")
    
    def gemini_analyze_code(self, code_content: str, analysis_type: str = "comprehensive",
                          client_id: str = "bridge_client") -> Dict[str, Any]:
        """Analyze code via Gemini bridge"""
        response = self.send_request(
            tool_name="gemini_analyze_code", 
            arguments={
                "code_content": code_content,
                "analysis_type": analysis_type
            },
            client_id=client_id
        )
        
        if response.get("status") == "completed":
            return response["data"]
        else:
            raise RuntimeError(f"Analysis failed: {response.get('error', 'Unknown error')}")

# Example usage functions
def example_godot_workflow():
    """Example: Godot game development workflow using MCP bridge"""
    client = MCPBridgeClient()
    
    print("🎮 Godot Development Workflow Example")
    print("=" * 50)
    
    # 1. Analyze GDScript code for optimization
    gdscript_code = '''
extends Node2D

var health = 100
var damage = 25

func _ready():
    print("Player ready")

func take_damage(amount):
    health -= amount
    if health <= 0:
        die()

func die():
    print("Player died")
    queue_free()
'''
    
    print("📝 Analyzing GDScript code...")
    try:
        analysis = client.gemini_analyze_code(
            code_content=gdscript_code,
            analysis_type="performance",
            client_id="godot_engine"
        )
        
        print("✅ Analysis completed:")
        print(f"   Issues found: {analysis.get('issues_found', 0)}")
        if 'suggestions' in analysis:
            for suggestion in analysis['suggestions'][:3]:
                print(f"   • {suggestion}")
    
    except Exception as e:
        print(f"❌ Analysis failed: {e}")
    
    # 2. Get game design advice
    print("\n🎨 Getting game design advice...")
    try:
        advice = client.gemini_quick_query(
            "How can I make a 2D platformer more engaging for players?",
            client_id="godot_design"
        )
        print(f"💡 Design advice: {advice[:200]}...")
    
    except Exception as e:
        print(f"❌ Query failed: {e}")

def example_cross_platform_handoff():
    """Example: Handoff workflow between different platforms"""
    client = MCPBridgeClient()
    
    print("🔄 Cross-Platform Handoff Example")
    print("=" * 50)
    
    # Simulate Gemini CLI creating analysis request
    print("📱 Step 1: Gemini CLI analysis request...")
    
    analysis_request = {
        "request_id": f"handoff_{int(time.time())}",
        "tool_name": "gemini_analyze_code",
        "arguments": {
            "code_content": "def fibonacci(n):\n    if n <= 1: return n\n    return fibonacci(n-1) + fibonacci(n-2)",
            "analysis_type": "performance"
        },
        "client_id": "gemini_cli",
        "metadata": {
            "source": "cli_session",
            "next_client": "claude_desktop",
            "context": "Performance optimization needed"
        }
    }
    
    # Write request directly (simulating Gemini CLI)
    request_file = client.requests_dir / f"{analysis_request['request_id']}.json"
    with open(request_file, 'w') as f:
        json.dump(analysis_request, f, indent=2)
    
    print(f"   Request created: {analysis_request['request_id']}")
    
    # Wait for response
    print("⏳ Step 2: Waiting for processing...")
    response_file = client.responses_dir / f"{analysis_request['request_id']}.json"
    
    timeout = 30
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        if response_file.exists():
            with open(response_file, 'r') as f:
                response = json.load(f)
            break
        time.sleep(1)
    else:
        print("❌ Timeout waiting for response")
        return
    
    print("📥 Step 3: Response received, ready for Claude Desktop")
    print(f"   Status: {response.get('status', 'unknown')}")
    
    if response.get('status') == 'completed':
        print("✅ Handoff complete - Claude Desktop can now access:")
        print(f"   • Analysis results in memory MCP")
        print(f"   • Original code context") 
        print(f"   • Performance recommendations")

def example_collaborative_development():
    """Example: Multi-tool collaborative development"""
    client = MCPBridgeClient()
    
    print("👥 Collaborative Development Example")
    print("=" * 50)
    
    # Step 1: Architecture planning
    print("🏗️ Step 1: Architecture planning...")
    try:
        architecture_query = """
        I'm building a turn-based strategy game in Godot. What's the best architecture pattern 
        for managing game state, turns, and player actions? Consider performance and maintainability.
        """
        
        architecture_advice = client.gemini_quick_query(
            architecture_query,
            client_id="architect"
        )
        
        print("✅ Architecture advice received")
        print(f"   Key recommendations: {architecture_advice[:150]}...")
        
    except Exception as e:
        print(f"❌ Architecture planning failed: {e}")
        return
    
    # Step 2: Code review simulation
    print("\n🔍 Step 2: Code review...")
    sample_code = '''
class GameManager:
    def __init__(self):
        self.players = []
        self.current_turn = 0
        self.game_state = "waiting"
    
    def start_game(self):
        self.game_state = "playing"
        self.next_turn()
    
    def next_turn(self):
        self.current_turn += 1
        current_player = self.players[self.current_turn % len(self.players)]
        current_player.take_turn()
'''
    
    try:
        review = client.gemini_analyze_code(
            code_content=sample_code,
            analysis_type="comprehensive",
            client_id="code_reviewer"
        )
        
        print("✅ Code review completed")
        print(f"   Issues found: {review.get('issues_found', 0)}")
        
    except Exception as e:
        print(f"❌ Code review failed: {e}")
    
    # Step 3: Documentation generation
    print("\n📚 Step 3: Documentation generation...")
    try:
        doc_query = f"""
        Generate documentation for this GameManager class:
        {sample_code}
        
        Include: class purpose, method descriptions, usage examples, and potential improvements.
        """
        
        documentation = client.gemini_quick_query(
            doc_query,
            client_id="documenter"
        )
        
        print("✅ Documentation generated")
        print(f"   Length: {len(documentation)} characters")
        
    except Exception as e:
        print(f"❌ Documentation generation failed: {e}")

def example_debugging_workflow():
    """Example: Debugging workflow using MCP ecosystem"""
    client = MCPBridgeClient()
    
    print("🐛 Debugging Workflow Example")
    print("=" * 50)
    
    # Simulate a problematic code snippet
    buggy_code = '''
def calculate_damage(base_damage, armor, critical_hit):
    damage_reduction = armor / (armor + 100)
    final_damage = base_damage * (1 - damage_reduction)
    
    if critical_hit:
        final_damage *= 2.5
    
    return int(final_damage)

# This sometimes returns negative damage!
result = calculate_damage(50, -10, True)
print(f"Damage: {result}")
'''
    
    print("🔍 Analyzing problematic code...")
    try:
        bug_analysis = client.gemini_analyze_code(
            code_content=buggy_code,
            analysis_type="security",  # Security analysis often catches edge cases
            client_id="debugger"
        )
        
        print("✅ Bug analysis completed")
        print(f"   Issues detected: {bug_analysis.get('issues_found', 0)}")
        
        if 'suggestions' in bug_analysis:
            print("   Key issues:")
            for suggestion in bug_analysis['suggestions'][:3]:
                print(f"   • {suggestion}")
    
    except Exception as e:
        print(f"❌ Bug analysis failed: {e}")
    
    # Get debugging strategies
    print("\n💡 Getting debugging strategies...")
    try:
        debug_query = """
        What are the best practices for debugging game logic issues in Godot? 
        Include specific tools and techniques for tracking down calculation errors.
        """
        
        debug_advice = client.gemini_quick_query(
            debug_query,
            client_id="debug_mentor"
        )
        
        print("✅ Debugging strategies received")
        print(f"   Advice: {debug_advice[:200]}...")
        
    except Exception as e:
        print(f"❌ Debug advice failed: {e}")

def main():
    """Run all workflow examples"""
    print("🚀 MCP Ecosystem Workflow Examples")
    print("=" * 60)
    
    # Check if bridge system is available
    bridge_dir = Path("mcp_bridge")
    if not bridge_dir.exists():
        print("❌ Bridge system not found. Please run:")
        print("   python mcp_ecosystem_manager.py start")
        return
    
    examples = [
        ("Godot Development", example_godot_workflow),
        ("Cross-Platform Handoff", example_cross_platform_handoff), 
        ("Collaborative Development", example_collaborative_development),
        ("Debugging Workflow", example_debugging_workflow)
    ]
    
    for name, example_func in examples:
        print(f"\n{'='*20} {name} {'='*20}")
        try:
            example_func()
        except Exception as e:
            print(f"❌ Example failed: {e}")
        
        print(f"\n{'='*60}")
        
        # Pause between examples
        input("Press Enter to continue to next example...")

if __name__ == "__main__":
    main()
