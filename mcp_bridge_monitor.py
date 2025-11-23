#!/usr/bin/env python3
"""
MCP Bridge Monitor - Production Grade
Handles file-based communication between Claude Code and Gemini CLI
Implements the architecture documented in MCP_MAINTAINER_PROJECT_KNOWLEDGE.md
"""

import json
import time
import asyncio
import logging
from pathlib import Path
from datetime import datetime, timedelta
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Configure production logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/mcp-bridge.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('MCPBridge')

class MCPBridgeHandler(FileSystemEventHandler):
    def __init__(self, requests_dir: Path, responses_dir: Path):
        self.requests_dir = requests_dir
        self.responses_dir = responses_dir
        logger.info(f"Bridge handler initialized: {requests_dir} -> {responses_dir}")
        
    def on_created(self, event):
        if event.is_directory or not event.src_path.endswith('.json'):
            return
            
        request_file = Path(event.src_path)
        logger.info(f"Processing new request: {request_file.name}")
        
        # Process in background to avoid blocking
        asyncio.create_task(self.process_request(request_file))
    
    async def process_request(self, request_file: Path):
        """Process MCP bridge request with comprehensive error handling"""
        try:
            # Read and validate request
            with open(request_file, 'r') as f:
                request = json.load(f)
            
            logger.info(f"Request content: {request}")
            
            # Generate timestamped response
            response = {
                "request_id": request.get("id", f"req_{int(time.time())}"),
                "timestamp": datetime.now().isoformat(),
                "status": "processed",
                "source": "mcp-bridge",
                "data": {
                    "query": request.get('query', 'No query provided'),
                    "processed_at": datetime.now().isoformat(),
                    "bridge_version": "1.0.0"
                }
            }
            
            # Write response with atomic operation
            response_file = self.responses_dir / f"response_{int(time.time())}_{request.get('id', 'unknown')}.json"
            temp_file = response_file.with_suffix('.tmp')
            
            with open(temp_file, 'w') as f:
                json.dump(response, f, indent=2)
            
            temp_file.rename(response_file)
            logger.info(f"Response written: {response_file.name}")
            
        except Exception as e:
            logger.error(f"Error processing {request_file}: {e}")
            # Write error response
            error_response = {
                "request_id": "error",
                "timestamp": datetime.now().isoformat(),
                "status": "error",
                "error": str(e)
            }
            error_file = self.responses_dir / f"error_{int(time.time())}.json"
            with open(error_file, 'w') as f:
                json.dump(error_response, f, indent=2)

def start_bridge_monitor():
    """Start the production MCP bridge monitoring system"""
    requests_dir = Path("mcp_bridge/requests")
    responses_dir = Path("mcp_bridge/responses")
    
    requests_dir.mkdir(parents=True, exist_ok=True)
    responses_dir.mkdir(parents=True, exist_ok=True)
    
    handler = MCPBridgeHandler(requests_dir, responses_dir)
    observer = Observer()
    observer.schedule(handler, str(requests_dir), recursive=False)
    observer.start()
    
    logger.info("🌉 MCP Bridge Monitor started (Production Mode)")
    logger.info(f"📥 Monitoring: {requests_dir}")
    logger.info(f"📤 Responses: {responses_dir}")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        logger.info("🛑 Bridge monitor stopped")
    observer.join()

if __name__ == "__main__":
    start_bridge_monitor()
