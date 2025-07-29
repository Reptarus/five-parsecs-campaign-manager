#!/usr/bin/env python3
"""
Memory MCP Integration for Cross-Platform Context Consistency
Production-ready implementation for sharing persistent knowledge across
Claude Desktop, Claude Code, Gemini CLI, and other development tools
"""

import json
import uuid
import time
import asyncio
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Union
from dataclasses import dataclass, asdict
from enum import Enum

class ContextType(Enum):
    """Types of context that can be stored and shared"""
    PROJECT_STATE = "project_state"
    CODE_ANALYSIS = "code_analysis"
    CONVERSATION = "conversation"
    WORKFLOW = "workflow"
    DEBUGGING_SESSION = "debugging_session"
    ARCHITECTURE_DECISION = "architecture_decision"

@dataclass
class ContextEntry:
    """Structured context entry for memory persistence"""
    id: str
    context_type: ContextType
    title: str
    content: Dict[str, Any]
    source_client: str
    target_clients: List[str]
    timestamp: datetime
    priority: int = 5  # 1-10, higher = more important
    expires_at: Optional[datetime] = None
    tags: List[str] = None
    metadata: Dict[str, Any] = None

    def __post_init__(self):
        if self.tags is None:
            self.tags = []
        if self.metadata is None:
            self.metadata = {}

class CrossPlatformMemoryManager:
    """Production-ready memory management for cross-platform context sharing"""
    
    def __init__(self, bridge_dir: str = "mcp_bridge", memory_dir: str = "memory_persistence"):
        self.bridge_dir = Path(bridge_dir)
        self.memory_dir = Path(memory_dir)
        self.memory_dir.mkdir(exist_ok=True)
        
        # Context storage
        self.context_store = self.memory_dir / "context_store.json"
        self.session_log = self.memory_dir / "session_log.json"
        
        # Load existing context
        self.contexts: Dict[str, ContextEntry] = self._load_contexts()
        
    def _load_contexts(self) -> Dict[str, ContextEntry]:
        """Load existing contexts from persistent storage"""
        try:
            if self.context_store.exists():
                with open(self.context_store, 'r') as f:
                    data = json.load(f)
                
                contexts = {}
                for ctx_id, ctx_data in data.items():
                    # Convert datetime strings back to datetime objects
                    ctx_data['timestamp'] = datetime.fromisoformat(ctx_data['timestamp'])
                    if ctx_data.get('expires_at'):
                        ctx_data['expires_at'] = datetime.fromisoformat(ctx_data['expires_at'])
                    
                    ctx_data['context_type'] = ContextType(ctx_data['context_type'])
                    contexts[ctx_id] = ContextEntry(**ctx_data)
                
                return contexts
        except Exception as e:
            print(f"Error loading contexts: {e}")
        
        return {}
    
    def _save_contexts(self):
        """Save contexts to persistent storage"""
        try:
            data = {}
            for ctx_id, context in self.contexts.items():
                ctx_dict = asdict(context)
                # Convert datetime objects to strings for JSON serialization
                ctx_dict['timestamp'] = context.timestamp.isoformat()
                if context.expires_at:
                    ctx_dict['expires_at'] = context.expires_at.isoformat()
                ctx_dict['context_type'] = context.context_type.value
                data[ctx_id] = ctx_dict
            
            with open(self.context_store, 'w') as f:
                json.dump(data, f, indent=2)
                
        except Exception as e:
            print(f"Error saving contexts: {e}")
    
    def store_context(self, context: ContextEntry) -> str:
        """Store context for cross-platform access"""
        self.contexts[context.id] = context
        self._save_contexts()
        
        # Log the storage action
        self._log_action("store", context.id, context.source_client, {
            "type": context.context_type.value,
            "title": context.title,
            "target_clients": context.target_clients
        })
        
        print(f"Stored context: {context.title} (ID: {context.id})")
        return context.id
    
    def retrieve_context(self, context_id: str, client_name: str) -> Optional[ContextEntry]:
        """Retrieve context for a specific client"""
        context = self.contexts.get(context_id)
        
        if context:
            # Check if context has expired
            if context.expires_at and datetime.now() > context.expires_at:
                self._remove_context(context_id)
                return None
            
            # Log the retrieval action
            self._log_action("retrieve", context_id, client_name, {
                "type": context.context_type.value,
                "title": context.title
            })
            
            return context
        
        return None
    
    def search_contexts(self, client_name: str, 
                       context_type: Optional[ContextType] = None,
                       tags: Optional[List[str]] = None,
                       since: Optional[datetime] = None) -> List[ContextEntry]:
        """Search contexts with filters"""
        results = []
        
        for context in self.contexts.values():
            # Check if context has expired
            if context.expires_at and datetime.now() > context.expires_at:
                continue
            
            # Apply filters
            if context_type and context.context_type != context_type:
                continue
            
            if tags and not any(tag in context.tags for tag in tags):
                continue
            
            if since and context.timestamp < since:
                continue
            
            # Check if client has access
            if (client_name in context.target_clients or 
                context.source_client == client_name or
                "all" in context.target_clients):
                results.append(context)
        
        # Sort by priority and timestamp
        results.sort(key=lambda x: (x.priority, x.timestamp), reverse=True)
        return results
    
    def create_project_context(self, project_name: str, client_name: str, 
                             current_state: Dict[str, Any]) -> str:
        """Create project state context for cross-platform sharing"""
        context = ContextEntry(
            id=f"project_{project_name}_{int(time.time())}",
            context_type=ContextType.PROJECT_STATE,
            title=f"Project State: {project_name}",
            content={
                "project_name": project_name,
                "current_files": current_state.get("files", []),
                "active_features": current_state.get("features", []),
                "recent_changes": current_state.get("changes", []),
                "architecture_notes": current_state.get("architecture", ""),
                "next_steps": current_state.get("next_steps", [])
            },
            source_client=client_name,
            target_clients=["all"],  # Available to all clients
            timestamp=datetime.now(),
            priority=8,
            tags=["project", "state", project_name.lower()]
        )
        
        return self.store_context(context)
    
    def create_code_analysis_context(self, analysis_result: Dict[str, Any], 
                                   client_name: str, file_path: str = "") -> str:
        """Create code analysis context for sharing insights"""
        context = ContextEntry(
            id=f"analysis_{uuid.uuid4()}",
            context_type=ContextType.CODE_ANALYSIS,
            title=f"Code Analysis: {file_path or 'Multiple Files'}",
            content={
                "file_path": file_path,
                "analysis_type": analysis_result.get("analysis_type", "comprehensive"),
                "issues_found": analysis_result.get("issues_found", 0),
                "suggestions": analysis_result.get("suggestions", []),
                "performance_score": analysis_result.get("performance_score"),
                "security_score": analysis_result.get("security_score"),
                "recommendations": analysis_result.get("recommendations", ""),
                "code_snippet": analysis_result.get("code_content", "")[:500]  # First 500 chars
            },
            source_client=client_name,
            target_clients=["claude-desktop", "claude-code", "gemini-cli"],
            timestamp=datetime.now(),
            priority=7,
            expires_at=datetime.now() + timedelta(days=7),  # Analysis expires in 1 week
            tags=["code", "analysis", "review"],
            metadata={
                "language": analysis_result.get("language", "unknown"),
                "complexity": analysis_result.get("complexity", "medium")
            }
        )
        
        return self.store_context(context)
    
    def create_conversation_context(self, conversation_summary: str, 
                                  client_name: str, topic: str) -> str:
        """Create conversation context for continuity across platforms"""
        context = ContextEntry(
            id=f"conversation_{uuid.uuid4()}",
            context_type=ContextType.CONVERSATION,
            title=f"Conversation: {topic}",
            content={
                "topic": topic,
                "summary": conversation_summary,
                "key_decisions": [],  # To be filled by client
                "action_items": [],   # To be filled by client
                "context_links": []   # Links to related contexts
            },
            source_client=client_name,
            target_clients=["all"],
            timestamp=datetime.now(),
            priority=6,
            expires_at=datetime.now() + timedelta(days=30),  # Conversations expire in 1 month
            tags=["conversation", topic.lower().replace(" ", "_")]
        )
        
        return self.store_context(context)
    
    def create_workflow_context(self, workflow_name: str, steps: List[str], 
                              client_name: str, current_step: int = 0) -> str:
        """Create workflow context for process continuity"""
        context = ContextEntry(
            id=f"workflow_{workflow_name}_{int(time.time())}",
            context_type=ContextType.WORKFLOW,
            title=f"Workflow: {workflow_name}",
            content={
                "workflow_name": workflow_name,
                "steps": steps,
                "current_step": current_step,
                "completed_steps": [],
                "notes": {},
                "estimated_completion": None
            },
            source_client=client_name,
            target_clients=["all"],
            timestamp=datetime.now(),
            priority=9,  # High priority for active workflows
            tags=["workflow", workflow_name.lower().replace(" ", "_")]
        )
        
        return self.store_context(context)
    
    def update_workflow_progress(self, workflow_id: str, completed_step: int, 
                               notes: str = "", client_name: str = "") -> bool:
        """Update workflow progress from any client"""
        context = self.contexts.get(workflow_id)
        if context and context.context_type == ContextType.WORKFLOW:
            context.content["current_step"] = completed_step
            context.content["completed_steps"].append({
                "step": completed_step,
                "completed_at": datetime.now().isoformat(),
                "notes": notes,
                "completed_by": client_name
            })
            
            self._save_contexts()
            self._log_action("update_workflow", workflow_id, client_name, {
                "step": completed_step,
                "notes": notes
            })
            return True
        
        return False
    
    def get_cross_platform_summary(self, client_name: str) -> Dict[str, Any]:
        """Get summary of all available context for a client"""
        recent_contexts = self.search_contexts(
            client_name, 
            since=datetime.now() - timedelta(days=7)
        )
        
        summary = {
            "client": client_name,
            "timestamp": datetime.now().isoformat(),
            "total_contexts": len(recent_contexts),
            "by_type": {},
            "recent_activities": [],
            "active_workflows": [],
            "pending_actions": []
        }
        
        # Group by type
        for context in recent_contexts:
            ctx_type = context.context_type.value
            if ctx_type not in summary["by_type"]:
                summary["by_type"][ctx_type] = 0
            summary["by_type"][ctx_type] += 1
            
            # Add to recent activities
            summary["recent_activities"].append({
                "id": context.id,
                "title": context.title,
                "type": ctx_type,
                "timestamp": context.timestamp.isoformat(),
                "priority": context.priority
            })
            
            # Track active workflows
            if context.context_type == ContextType.WORKFLOW:
                total_steps = len(context.content.get("steps", []))
                current_step = context.content.get("current_step", 0)
                summary["active_workflows"].append({
                    "id": context.id,
                    "name": context.content.get("workflow_name", "Unknown"),
                    "progress": f"{current_step}/{total_steps}",
                    "completion_percent": (current_step / total_steps * 100) if total_steps > 0 else 0
                })
        
        # Limit recent activities to 10 most recent
        summary["recent_activities"] = summary["recent_activities"][:10]
        
        return summary
    
    def _remove_context(self, context_id: str):
        """Remove expired or invalid context"""
        if context_id in self.contexts:
            del self.contexts[context_id]
            self._save_contexts()
    
    def _log_action(self, action: str, context_id: str, client: str, details: Dict[str, Any]):
        """Log actions for monitoring and debugging"""
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "action": action,
            "context_id": context_id,
            "client": client,
            "details": details
        }
        
        # Append to session log
        try:
            log_entries = []
            if self.session_log.exists():
                with open(self.session_log, 'r') as f:
                    log_entries = json.load(f)
            
            log_entries.append(log_entry)
            
            # Keep only last 1000 entries
            if len(log_entries) > 1000:
                log_entries = log_entries[-1000:]
            
            with open(self.session_log, 'w') as f:
                json.dump(log_entries, f, indent=2)
                
        except Exception as e:
            print(f"Error logging action: {e}")
    
    def cleanup_expired_contexts(self):
        """Remove expired contexts"""
        now = datetime.now()
        expired_ids = []
        
        for ctx_id, context in self.contexts.items():
            if context.expires_at and now > context.expires_at:
                expired_ids.append(ctx_id)
        
        for ctx_id in expired_ids:
            self._remove_context(ctx_id)
        
        if expired_ids:
            print(f"Cleaned up {len(expired_ids)} expired contexts")

def demonstrate_cross_platform_context():
    """Demonstrate cross-platform context sharing functionality"""
    print("Cross-Platform Memory Context Demonstration")
    print("=" * 60)
    
    # Initialize memory manager
    memory = CrossPlatformMemoryManager()
    
    # Simulate different client interactions
    scenarios = [
        {
            "name": "Project State Sharing",
            "description": "Gemini CLI shares project state with Claude Desktop"
        },
        {
            "name": "Code Analysis Continuity", 
            "description": "Claude Desktop analysis available in Claude Code"
        },
        {
            "name": "Workflow Coordination",
            "description": "Multi-client workflow with progress tracking"
        },
        {
            "name": "Conversation Context",
            "description": "Discussion continuity across platforms"
        }
    ]
    
    print("\nRunning cross-platform context scenarios...\n")
    
    # Scenario 1: Project State Sharing
    print("1. PROJECT STATE SHARING")
    print("-" * 30)
    
    project_state = {
        "files": ["main.py", "config.json", "requirements.txt"],
        "features": ["user_auth", "data_processing", "api_endpoints"],
        "changes": ["Added authentication middleware", "Optimized database queries"],
        "architecture": "Microservices with FastAPI and PostgreSQL",
        "next_steps": ["Implement caching", "Add monitoring", "Performance testing"]
    }
    
    project_id = memory.create_project_context("five-parsecs-campaign", "gemini-cli", project_state)
    print(f"   Gemini CLI stored project state: {project_id}")
    
    # Claude Desktop retrieves the context
    retrieved_context = memory.retrieve_context(project_id, "claude-desktop")
    if retrieved_context:
        print(f"   Claude Desktop accessed project state successfully")
        print(f"   Next steps available: {len(retrieved_context.content['next_steps'])}")
    
    # Scenario 2: Code Analysis Continuity
    print(f"\n2. CODE ANALYSIS CONTINUITY")
    print("-" * 30)
    
    analysis_result = {
        "analysis_type": "performance",
        "issues_found": 3,
        "suggestions": [
            "Implement database connection pooling",
            "Add caching for frequently accessed data",
            "Use async/await for I/O operations"
        ],
        "performance_score": 7.5,
        "recommendations": "Focus on database optimization and caching",
        "code_content": "def process_data(data):\n    # Database query here\n    return result"
    }
    
    analysis_id = memory.create_code_analysis_context(analysis_result, "claude-desktop", "src/data_processor.py")
    print(f"   Claude Desktop stored code analysis: {analysis_id}")
    
    # Claude Code retrieves the analysis
    retrieved_analysis = memory.retrieve_context(analysis_id, "claude-code")
    if retrieved_analysis:
        print(f"   Claude Code accessed analysis successfully")
        print(f"   Performance score: {retrieved_analysis.content['performance_score']}")
    
    # Scenario 3: Workflow Coordination
    print(f"\n3. WORKFLOW COORDINATION")
    print("-" * 30)
    
    deployment_steps = [
        "Run comprehensive tests",
        "Update documentation", 
        "Create deployment package",
        "Deploy to staging",
        "Validate staging environment",
        "Deploy to production",
        "Monitor production metrics"
    ]
    
    workflow_id = memory.create_workflow_context("production-deployment", deployment_steps, "claude-desktop")
    print(f"   Claude Desktop created workflow: {workflow_id}")
    
    # Simulate progress updates from different clients
    memory.update_workflow_progress(workflow_id, 1, "All tests passing", "claude-code")
    memory.update_workflow_progress(workflow_id, 2, "Docs updated with new features", "gemini-cli")
    print(f"   Progress updated by multiple clients")
    
    # Scenario 4: Conversation Context
    print(f"\n4. CONVERSATION CONTEXT")
    print("-" * 30)
    
    conversation_summary = """
    Discussed MCP ecosystem architecture and cross-platform integration strategies.
    Key points: Memory persistence enables seamless context sharing, fallback systems
    ensure reliability during API quotas, and workflow coordination improves team productivity.
    """
    
    conversation_id = memory.create_conversation_context(
        conversation_summary, 
        "claude-desktop", 
        "MCP Architecture Discussion"
    )
    print(f"   Conversation context stored: {conversation_id}")
    
    # Generate cross-platform summary
    print(f"\n5. CROSS-PLATFORM SUMMARY")
    print("-" * 30)
    
    for client in ["claude-desktop", "claude-code", "gemini-cli"]:
        summary = memory.get_cross_platform_summary(client)
        print(f"   {client}: {summary['total_contexts']} contexts available")
        if summary['active_workflows']:
            for workflow in summary['active_workflows']:
                print(f"     Active workflow: {workflow['name']} ({workflow['progress']})")
    
    print(f"\n" + "=" * 60)
    print("CROSS-PLATFORM CONTEXT DEMONSTRATION COMPLETE")
    print("Memory MCP enables seamless knowledge sharing across all clients!")
    
    return memory

if __name__ == "__main__":
    # Demonstrate the cross-platform memory system
    memory_manager = demonstrate_cross_platform_context()
    
    print(f"\nProduction Benefits:")
    print(f"- Context preserved across client switches")
    print(f"- Code analysis shared between tools") 
    print(f"- Workflow progress tracked across sessions")
    print(f"- Conversation continuity maintained")
    
    print(f"\nIntegration with your MCP ecosystem:")
    print(f"- Bridge system can store/retrieve context")
    print(f"- Claude Desktop has persistent memory")
    print(f"- Gemini CLI maintains session context")
    print(f"- All tools share the same knowledge base")
