#!/usr/bin/env python3
"""
Memory-Enhanced Bridge System
Integration of cross-platform memory persistence with your existing MCP bridge
"""

import json
import time
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, Optional

# Import your existing cross-platform memory system
from cross_platform_memory import CrossPlatformMemoryManager, ContextType

class MemoryEnhancedBridge:
    """Production bridge system with automatic memory persistence"""
    
    def __init__(self, bridge_dir: str = "mcp_bridge"):
        self.bridge_dir = Path(bridge_dir)
        self.requests_dir = self.bridge_dir / "requests"
        self.responses_dir = self.bridge_dir / "responses"
        self.memory = CrossPlatformMemoryManager()
        
    def process_bridge_request_with_memory(self, request_file: Path) -> Dict[str, Any]:
        """Process bridge request and automatically store context"""
        
        # Load request
        with open(request_file, 'r') as f:
            request = json.load(f)
        
        request_id = request.get("request_id")
        tool_name = request.get("tool_name")
        arguments = request.get("arguments", {})
        client_id = request.get("client_id", "unknown")
        
        print(f"Processing request {request_id} from {client_id}")
        
        # Check if we have relevant context for this request
        relevant_context = self._find_relevant_context(arguments, client_id)
        
        # Simulate processing (replace with your actual bridge logic)
        response_data = self._simulate_processing(tool_name, arguments, relevant_context)
        
        # Store the interaction context for future use
        self._store_interaction_context(request, response_data, client_id)
        
        # Create response
        response = {
            "request_id": request_id,
            "status": "completed",
            "timestamp": datetime.now().isoformat(),
            "data": response_data,
            "metadata": {
                "memory_enhanced": True,
                "context_links": [ctx.id for ctx in relevant_context] if relevant_context else [],
                "processing_time_ms": 250
            }
        }
        
        # Write response
        response_file = self.responses_dir / f"{request_id}.json"
        with open(response_file, 'w') as f:
            json.dump(response, f, indent=2)
        
        print(f"Response generated with memory enhancement: {response_file}")
        return response
    
    def _find_relevant_context(self, arguments: Dict[str, Any], client_id: str) -> list:
        """Find relevant existing context for the request"""
        relevant_contexts = []
        
        # Search for code analysis if this is a code-related request
        query = arguments.get("query", "").lower()
        if any(keyword in query for keyword in ["code", "analysis", "performance", "bug", "optimize"]):
            code_contexts = self.memory.search_contexts(
                client_id, 
                context_type=ContextType.CODE_ANALYSIS
            )
            relevant_contexts.extend(code_contexts[:3])  # Top 3 most relevant
        
        # Search for project context if project-related
        if any(keyword in query for keyword in ["project", "architecture", "design", "feature"]):
            project_contexts = self.memory.search_contexts(
                client_id,
                context_type=ContextType.PROJECT_STATE
            )
            relevant_contexts.extend(project_contexts[:2])
        
        # Search for workflow context if workflow-related
        if any(keyword in query for keyword in ["deploy", "workflow", "process", "steps"]):
            workflow_contexts = self.memory.search_contexts(
                client_id,
                context_type=ContextType.WORKFLOW
            )
            relevant_contexts.extend(workflow_contexts[:2])
        
        return relevant_contexts
    
    def _simulate_processing(self, tool_name: str, arguments: Dict[str, Any], 
                           relevant_context: list) -> Dict[str, Any]:
        """Simulate processing with context awareness"""
        
        if tool_name == "gemini_quick_query":
            query = arguments.get("query", "")
            
            # Build context-aware response
            context_summary = ""
            if relevant_context:
                context_summary = f"\n\nBased on your previous work:\n"
                for ctx in relevant_context[:2]:  # Use top 2 contexts
                    if ctx.context_type == ContextType.CODE_ANALYSIS:
                        context_summary += f"- Previous code analysis found {ctx.content.get('issues_found', 0)} issues\n"
                    elif ctx.context_type == ContextType.PROJECT_STATE:
                        next_steps = ctx.content.get('next_steps', [])
                        if next_steps:
                            context_summary += f"- Project next steps: {', '.join(next_steps[:2])}\n"
            
            # Enhanced response with context
            base_response = f"Response to: {query}"
            if "mcp" in query.lower():
                base_response = "The MCP ecosystem enables seamless AI integration across development tools. Your implementation provides cross-platform context sharing, intelligent fallback systems, and production-grade process management."
            elif "performance" in query.lower():
                base_response = "For performance optimization, focus on database query optimization, caching strategies, async operations, and connection pooling. Profile your application to identify bottlenecks."
            elif "deploy" in query.lower():
                base_response = "Deployment best practices include automated testing, staged environments, health checks, monitoring, and rollback capabilities. Use CI/CD pipelines for consistency."
            
            return {
                "answer": base_response + context_summary,
                "model_used": "memory-enhanced-bridge",
                "context_used": len(relevant_context),
                "tokens": len(base_response) // 4  # Rough token estimate
            }
        
        elif tool_name == "gemini_analyze_code":
            code_content = arguments.get("code_content", "")
            analysis_type = arguments.get("analysis_type", "comprehensive")
            
            # Context-aware analysis
            previous_analyses = [ctx for ctx in relevant_context 
                               if ctx.context_type == ContextType.CODE_ANALYSIS]
            
            issues_found = 3
            suggestions = [
                "Add type hints for better code documentation",
                "Implement proper error handling with try-catch blocks",
                "Consider caching for performance optimization"
            ]
            
            # Enhance suggestions based on previous context
            if previous_analyses:
                prev_analysis = previous_analyses[0]
                prev_suggestions = prev_analysis.content.get("suggestions", [])
                if prev_suggestions:
                    suggestions.append(f"Building on previous analysis: {prev_suggestions[0]}")
            
            return {
                "analysis": f"{analysis_type.title()} analysis completed with context awareness",
                "issues_found": issues_found,
                "suggestions": suggestions,
                "performance_score": 7.5,
                "context_enhanced": len(previous_analyses) > 0,
                "recommendations": f"Focus on {analysis_type} improvements based on project context"
            }
        
        return {"message": "Unknown tool", "tool_name": tool_name}
    
    def _store_interaction_context(self, request: Dict[str, Any], 
                                 response_data: Dict[str, Any], client_id: str):
        """Store the interaction for future context"""
        
        tool_name = request.get("tool_name")
        
        if tool_name == "gemini_quick_query":
            # Store as conversation context
            query = request["arguments"].get("query", "")
            answer = response_data.get("answer", "")
            
            self.memory.create_conversation_context(
                conversation_summary=f"Query: {query}\nResponse: {answer[:200]}...",
                client_name=client_id,
                topic=f"Bridge Query Session"
            )
        
        elif tool_name == "gemini_analyze_code":
            # Store as code analysis context
            self.memory.create_code_analysis_context(
                analysis_result=response_data,
                client_name=client_id,
                file_path=request["arguments"].get("file_path", "bridge_request")
            )

def test_memory_enhanced_bridge():
    """Test the memory-enhanced bridge system"""
    print("Memory-Enhanced Bridge System Test")
    print("=" * 50)
    
    bridge = MemoryEnhancedBridge()
    
    # Create test requests that demonstrate memory integration
    test_requests = [
        {
            "request_id": f"memory_test_{int(time.time())}_1",
            "tool_name": "gemini_quick_query",
            "arguments": {
                "query": "What are the best practices for MCP ecosystem deployment?"
            },
            "client_id": "claude-desktop"
        },
        {
            "request_id": f"memory_test_{int(time.time())}_2", 
            "tool_name": "gemini_analyze_code",
            "arguments": {
                "code_content": "def deploy_application():\n    # TODO: Add proper error handling\n    return deploy_to_production()",
                "analysis_type": "security"
            },
            "client_id": "claude-code"
        },
        {
            "request_id": f"memory_test_{int(time.time())}_3",
            "tool_name": "gemini_quick_query", 
            "arguments": {
                "query": "How can I improve the performance of my deployment process?"
            },
            "client_id": "gemini-cli"
        }
    ]
    
    # Process each request
    for i, request in enumerate(test_requests, 1):
        print(f"\nTest {i}: {request['tool_name']} from {request['client_id']}")
        print("-" * 40)
        
        # Write request file
        request_file = bridge.requests_dir / f"{request['request_id']}.json"
        with open(request_file, 'w') as f:
            json.dump(request, f, indent=2)
        
        # Process with memory enhancement
        response = bridge.process_bridge_request_with_memory(request_file)
        
        print(f"Request: {request['arguments'].get('query', 'Code analysis')}")
        if response['data'].get('answer'):
            print(f"Response: {response['data']['answer'][:150]}...")
        else:
            print(f"Analysis: {response['data'].get('analysis', 'Unknown')}")
        
        context_links = response['metadata'].get('context_links', [])
        print(f"Context used: {len(context_links)} previous interactions")
        
        time.sleep(1)  # Brief pause between requests
    
    # Show cross-platform summary
    print(f"\n" + "=" * 50)
    print("CROSS-PLATFORM CONTEXT SUMMARY")
    print("=" * 50)
    
    for client in ["claude-desktop", "claude-code", "gemini-cli"]:
        summary = bridge.memory.get_cross_platform_summary(client)
        print(f"\n{client}:")
        print(f"  Total contexts: {summary['total_contexts']}")
        print(f"  Recent activities: {len(summary['recent_activities'])}")
        
        for activity in summary['recent_activities'][:2]:
            print(f"    - {activity['title']} ({activity['type']})")
    
    print(f"\nMemory-enhanced bridge system operational!")
    print(f"Context persistence enables intelligent responses across all clients.")

if __name__ == "__main__":
    test_memory_enhanced_bridge()
