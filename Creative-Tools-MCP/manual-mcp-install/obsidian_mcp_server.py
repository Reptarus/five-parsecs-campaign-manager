# Obsidian MCP Server - Production MCP Protocol Compliant Implementation
# Fixes the "Method not found: initialize" error by implementing proper MCP handshake

import json
import sys
import asyncio
from typing import Any, Dict, List, Optional
from pathlib import Path

class ObsidianMCPServer:
    """
    Production-ready Obsidian MCP server with full MCP protocol compliance
    Implements proper initialize handshake and tool management
    """
    
    def __init__(self, vault_path: str):
        self.vault_path = Path(vault_path)
        self.initialized = False
        self.server_info = {
            "name": "obsidian-knowledge",
            "version": "1.0.0"
        }
        self.tools = self._initialize_tools()
    
    def _initialize_tools(self) -> List[Dict[str, Any]]:
        """Initialize MCP tools with comprehensive schemas"""
        return [
            {
                "name": "read_obsidian_note",
                "description": "Read content from an Obsidian note by filename",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "filename": {
                            "type": "string",
                            "description": "Name of the note file (with or without .md extension)"
                        }
                    },
                    "required": ["filename"]
                }
            },
            {
                "name": "search_obsidian_vault",
                "description": "Search for notes containing specific text or tags",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "query": {
                            "type": "string", 
                            "description": "Search query (text or #tag)"
                        },
                        "limit": {
                            "type": "number",
                            "description": "Maximum number of results",
                            "default": 10
                        }
                    },
                    "required": ["query"]
                }
            },
            {
                "name": "list_obsidian_notes",
                "description": "List all notes in the vault with metadata",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "folder": {
                            "type": "string",
                            "description": "Specific folder to search (optional)",
                            "default": ""
                        }
                    }
                }
            }
        ]
    
    async def handle_initialize(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle MCP initialize method - Critical for protocol compliance"""
        self.initialized = True
        
        return {
            "protocolVersion": "2024-11-05",
            "capabilities": {
                "tools": {}
            },
            "serverInfo": self.server_info
        }
    
    async def handle_read_note(self, filename: str) -> Dict[str, Any]:
        """Read note content with comprehensive error handling"""
        try:
            # Normalize filename
            if not filename.endswith('.md'):
                filename += '.md'
            
            file_path = self.vault_path / filename
            
            if not file_path.exists():
                # Search in subdirectories
                for md_file in self.vault_path.rglob(filename):
                    file_path = md_file
                    break
                else:
                    return {
                        "error": f"Note '{filename}' not found in vault",
                        "suggestions": self._get_similar_notes(filename)
                    }
            
            content = file_path.read_text(encoding='utf-8')
            
            return {
                "filename": filename,
                "path": str(file_path.relative_to(self.vault_path)),
                "content": content,
                "size": len(content),
                "modified": file_path.stat().st_mtime
            }
            
        except Exception as e:
            return {"error": f"Failed to read note: {str(e)}"}
    
    async def handle_search_vault(self, query: str, limit: int = 10) -> Dict[str, Any]:
        """Search vault with performance optimization"""
        try:
            results = []
            search_count = 0
            
            # Handle tag search
            is_tag_search = query.startswith('#')
            search_term = query.lower()
            
            for md_file in self.vault_path.rglob('*.md'):
                if search_count >= limit:
                    break
                    
                try:
                    content = md_file.read_text(encoding='utf-8')
                    content_lower = content.lower()
                    
                    # Check if query matches
                    if search_term in content_lower:
                        # Extract context around match
                        context = self._extract_context(content, query)
                        
                        results.append({
                            "filename": md_file.name,
                            "path": str(md_file.relative_to(self.vault_path)),
                            "context": context,
                            "size": len(content)
                        })
                        search_count += 1
                        
                except Exception:
                    continue  # Skip problematic files
            
            return {
                "query": query,
                "results": results,
                "total_found": len(results),
                "search_completed": search_count < limit
            }
            
        except Exception as e:
            return {"error": f"Search failed: {str(e)}"}
    
    async def handle_list_notes(self, folder: str = "") -> Dict[str, Any]:
        """List notes with metadata and organization"""
        try:
            search_path = self.vault_path / folder if folder else self.vault_path
            
            if not search_path.exists():
                return {"error": f"Folder '{folder}' not found"}
            
            notes = []
            folders = set()
            
            for item in search_path.rglob('*'):
                if item.is_file() and item.suffix == '.md':
                    rel_path = item.relative_to(self.vault_path)
                    folder_path = str(rel_path.parent) if rel_path.parent != Path('.') else ""
                    
                    if folder_path:
                        folders.add(folder_path)
                    
                    notes.append({
                        "filename": item.name,
                        "path": str(rel_path),
                        "folder": folder_path,
                        "size": item.stat().st_size,
                        "modified": item.stat().st_mtime
                    })
            
            # Sort by modification time (newest first)
            notes.sort(key=lambda x: x['modified'], reverse=True)
            
            return {
                "notes": notes,
                "folders": sorted(list(folders)),
                "total_notes": len(notes),
                "vault_path": str(self.vault_path)
            }
            
        except Exception as e:
            return {"error": f"Failed to list notes: {str(e)}"}
    
    def _extract_context(self, content: str, query: str, context_length: int = 200) -> str:
        """Extract context around search matches"""
        query_lower = query.lower()
        content_lower = content.lower()
        
        pos = content_lower.find(query_lower)
        if pos == -1:
            return content[:context_length] + "..." if len(content) > context_length else content
        
        start = max(0, pos - context_length // 2)
        end = min(len(content), pos + len(query) + context_length // 2)
        
        context = content[start:end]
        if start > 0:
            context = "..." + context
        if end < len(content):
            context = context + "..."
            
        return context
    
    def _get_similar_notes(self, filename: str) -> List[str]:
        """Get similar note suggestions"""
        try:
            all_notes = [f.name for f in self.vault_path.rglob('*.md')]
            # Simple similarity based on character overlap
            filename_lower = filename.lower()
            similar = [note for note in all_notes 
                      if any(char in note.lower() for char in filename_lower[:3])]
            return similar[:5]  # Top 5 suggestions
        except:
            return []

# MCP Server Protocol Implementation with Proper Initialize Handling
async def run_server():
    """Main server loop with full MCP protocol compliance"""
    vault_path = sys.argv[1] if len(sys.argv) > 1 else "C:\\Users\\elija\\SynologyDrive\\Godot"
    
    server = ObsidianMCPServer(vault_path)
    
    # Main request handling loop with proper MCP protocol
    while True:
        try:
            line = input()
            if not line:
                continue
                
            request = json.loads(line)
            method = request.get('method')
            params = request.get('params', {})
            request_id = request.get('id')
            
            # Handle MCP initialize method - CRITICAL for protocol compliance
            if method == 'initialize':
                result = await server.handle_initialize(params)
                response = {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "result": result
                }
            
            elif method == 'tools/list':
                response = {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "result": {"tools": server.tools}
                }
            
            elif method == 'tools/call':
                tool_name = params.get('name')
                arguments = params.get('arguments', {})
                
                if tool_name == 'read_obsidian_note':
                    result = await server.handle_read_note(arguments.get('filename', ''))
                elif tool_name == 'search_obsidian_vault':
                    result = await server.handle_search_vault(
                        arguments.get('query', ''),
                        arguments.get('limit', 10)
                    )
                elif tool_name == 'list_obsidian_notes':
                    result = await server.handle_list_notes(arguments.get('folder', ''))
                else:
                    result = {"error": f"Unknown tool: {tool_name}"}
                
                response = {
                    "jsonrpc": "2.0", 
                    "id": request_id,
                    "result": {"content": [{"type": "text", "text": json.dumps(result, indent=2)}]}
                }
            
            else:
                response = {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {"code": -32601, "message": f"Method not found: {method}"}
                }
            
            print(json.dumps(response))
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            if 'request_id' in locals() and request_id:
                error_response = {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {"code": -32603, "message": f"Internal error: {str(e)}"}
                }
                print(json.dumps(error_response))

if __name__ == "__main__":
    asyncio.run(run_server())
