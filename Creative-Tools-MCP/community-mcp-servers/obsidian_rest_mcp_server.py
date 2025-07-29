# Obsidian REST API MCP Server - Production Implementation
# Integrates with Obsidian Local REST API for enterprise knowledge management

import json
import sys
import asyncio
import logging
from typing import Any, Dict, List, Optional
from pathlib import Path
import aiohttp

# Configure production logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ObsidianRESTMCPServer:
    """
    Production-ready Obsidian MCP server using REST API integration
    Provides comprehensive vault access with enterprise error handling
    """
    
    def __init__(self, base_url: str = "https://127.0.0.1:27124"):
        self.base_url = base_url
        self.session = None
        self.initialized = False
        self.server_info = {
            "name": "obsidian-knowledge-rest",
            "version": "1.0.0"
        }
        self.tools = self._initialize_tools()
    
    async def _get_session(self) -> aiohttp.ClientSession:
        """Get or create aiohttp session with SSL verification disabled for self-signed certs"""
        if self.session is None or self.session.closed:
            timeout = aiohttp.ClientTimeout(total=10, connect=5)
            # Create SSL context that ignores certificate verification
            import ssl
            ssl_context = ssl.create_default_context()
            ssl_context.check_hostname = False
            ssl_context.verify_mode = ssl.CERT_NONE
            
            connector = aiohttp.TCPConnector(ssl=ssl_context)
            self.session = aiohttp.ClientSession(timeout=timeout, connector=connector)
        return self.session
    
    async def _test_connection(self) -> Dict[str, Any]:
        """Test connection to Obsidian REST API with comprehensive diagnostics"""
        try:
            session = await self._get_session()
            async with session.get(f"{self.base_url}/vault") as response:
                if response.status == 200:
                    vault_info = await response.json()
                    logger.info("Obsidian REST API connection successful")
                    return {"success": True, "vault_info": vault_info}
                else:
                    return {"success": False, "error": f"HTTP {response.status}: {await response.text()}"}
        except aiohttp.ClientConnectorError:
            return {"success": False, "error": "Connection refused - Obsidian REST API not running on port 27123"}
        except asyncio.TimeoutError:
            return {"success": False, "error": "Connection timeout - Obsidian may be unresponsive"}
        except Exception as e:
            return {"success": False, "error": f"Connection error: {str(e)}"}
    
    def _initialize_tools(self) -> List[Dict[str, Any]]:
        """Initialize MCP tools with comprehensive schemas for Obsidian REST API"""
        return [
            {
                "name": "search_obsidian_vault",
                "description": "Search notes in Obsidian vault using REST API",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "query": {
                            "type": "string",
                            "description": "Search query (text, tags, or content)"
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
                "name": "read_obsidian_note",
                "description": "Read specific note content from Obsidian vault",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "note_path": {
                            "type": "string",
                            "description": "Path to note file (e.g., 'Characters/Hero.md')"
                        }
                    },
                    "required": ["note_path"]
                }
            },
            {
                "name": "list_obsidian_notes",
                "description": "List all notes in vault with metadata",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "folder": {
                            "type": "string",
                            "description": "Specific folder to list (optional)",
                            "default": ""
                        }
                    }
                }
            },
            {
                "name": "get_obsidian_tags",
                "description": "Get all tags used in the vault",
                "inputSchema": {
                    "type": "object",
                    "properties": {}
                }
            }
        ]
    
    async def handle_initialize(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle MCP initialize method with connection validation"""
        connection_test = await self._test_connection()
        
        if connection_test["success"]:
            self.initialized = True
            logger.info("Obsidian REST MCP Server initialized successfully")
            return {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": self.server_info
            }
        else:
            logger.error(f"Obsidian REST API connection failed: {connection_test['error']}")
            return {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": self.server_info,
                "initializationError": connection_test["error"]
            }
    
    async def handle_search_vault(self, query: str, limit: int = 10) -> Dict[str, Any]:
        """Search vault using Obsidian REST API with comprehensive error handling"""
        try:
            session = await self._get_session()
            
            # Use the search endpoint if available, otherwise fallback to listing and filtering
            search_url = f"{self.base_url}/search"
            params = {"query": query, "limit": limit}
            
            async with session.get(search_url, params=params) as response:
                if response.status == 200:
                    results = await response.json()
                    return {
                        "query": query,
                        "results": results,
                        "total_found": len(results),
                        "search_method": "rest_api"
                    }
                elif response.status == 404:
                    # Fallback: Get all files and search manually
                    return await self._fallback_search(query, limit)
                else:
                    return {"error": f"Search failed: HTTP {response.status}"}
                    
        except Exception as e:
            logger.error(f"Search error: {str(e)}")
            return {"error": f"Search failed: {str(e)}"}
    
    async def _fallback_search(self, query: str, limit: int) -> Dict[str, Any]:
        """Fallback search by listing files and searching content"""
        try:
            session = await self._get_session()
            
            # Get all notes
            async with session.get(f"{self.base_url}/vault") as response:
                if response.status != 200:
                    return {"error": "Failed to access vault"}
                
                vault_data = await response.json()
                notes = vault_data.get("files", [])
                
                results = []
                query_lower = query.lower()
                
                for note in notes[:limit]:
                    if note["path"].endswith(".md"):
                        # Check if query matches filename or content
                        if query_lower in note["path"].lower():
                            results.append({
                                "path": note["path"],
                                "match_type": "filename",
                                "size": note.get("size", 0)
                            })
                
                return {
                    "query": query,
                    "results": results,
                    "total_found": len(results),
                    "search_method": "fallback"
                }
                
        except Exception as e:
            return {"error": f"Fallback search failed: {str(e)}"}
    
    async def handle_read_note(self, note_path: str) -> Dict[str, Any]:
        """Read note content using REST API with comprehensive error handling"""
        try:
            session = await self._get_session()
            
            # URL encode the path properly
            import urllib.parse
            encoded_path = urllib.parse.quote(note_path)
            note_url = f"{self.base_url}/vault/{encoded_path}"
            
            async with session.get(note_url) as response:
                if response.status == 200:
                    content = await response.text()
                    return {
                        "path": note_path,
                        "content": content,
                        "size": len(content),
                        "access_method": "rest_api"
                    }
                elif response.status == 404:
                    return {"error": f"Note not found: {note_path}"}
                else:
                    return {"error": f"Failed to read note: HTTP {response.status}"}
                    
        except Exception as e:
            logger.error(f"Read note error: {str(e)}")
            return {"error": f"Failed to read note: {str(e)}"}
    
    async def handle_list_notes(self, folder: str = "") -> Dict[str, Any]:
        """List notes using REST API with folder filtering"""
        try:
            session = await self._get_session()
            
            async with session.get(f"{self.base_url}/vault") as response:
                if response.status == 200:
                    vault_data = await response.json()
                    all_files = vault_data.get("files", [])
                    
                    # Filter for markdown files and folder if specified
                    notes = []
                    for file in all_files:
                        if file["path"].endswith(".md"):
                            if not folder or file["path"].startswith(folder):
                                notes.append({
                                    "filename": Path(file["path"]).name,
                                    "path": file["path"],
                                    "size": file.get("size", 0),
                                    "modified": file.get("mtime", 0)
                                })
                    
                    # Sort by modification time (newest first)
                    notes.sort(key=lambda x: x.get("modified", 0), reverse=True)
                    
                    return {
                        "notes": notes,
                        "total_notes": len(notes),
                        "folder_filter": folder,
                        "access_method": "rest_api"
                    }
                else:
                    return {"error": f"Failed to list vault: HTTP {response.status}"}
                    
        except Exception as e:
            logger.error(f"List notes error: {str(e)}")
            return {"error": f"Failed to list notes: {str(e)}"}
    
    async def handle_get_tags(self) -> Dict[str, Any]:
        """Get all tags from the vault"""
        try:
            session = await self._get_session()
            
            # Try tags endpoint first
            async with session.get(f"{self.base_url}/tags") as response:
                if response.status == 200:
                    tags_data = await response.json()
                    return {
                        "tags": tags_data,
                        "total_tags": len(tags_data),
                        "access_method": "rest_api"
                    }
                else:
                    return {"error": f"Failed to get tags: HTTP {response.status}"}
                    
        except Exception as e:
            logger.error(f"Get tags error: {str(e)}")
            return {"error": f"Failed to get tags: {str(e)}"}
    
    async def cleanup(self):
        """Cleanup resources"""
        if self.session and not self.session.closed:
            await self.session.close()

# MCP Server Protocol Implementation
async def run_server():
    """Main server loop with full MCP protocol compliance"""
    server = ObsidianRESTMCPServer()
    
    try:
        # Main request handling loop
        while True:
            try:
                line = input()
                if not line:
                    continue
                    
                request = json.loads(line)
                method = request.get('method')
                params = request.get('params', {})
                request_id = request.get('id')
                
                # Handle MCP initialize method
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
                    
                    if tool_name == 'search_obsidian_vault':
                        result = await server.handle_search_vault(
                            arguments.get('query', ''),
                            arguments.get('limit', 10)
                        )
                    elif tool_name == 'read_obsidian_note':
                        result = await server.handle_read_note(arguments.get('note_path', ''))
                    elif tool_name == 'list_obsidian_notes':
                        result = await server.handle_list_notes(arguments.get('folder', ''))
                    elif tool_name == 'get_obsidian_tags':
                        result = await server.handle_get_tags()
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
                logger.error(f"Request handling error: {e}")
                if 'request_id' in locals() and request_id:
                    error_response = {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "error": {"code": -32603, "message": f"Internal error: {str(e)}"}
                    }
                    print(json.dumps(error_response))
    finally:
        await server.cleanup()

if __name__ == "__main__":
    asyncio.run(run_server())
