#!/usr/bin/env python3
"""
Production MCP Bridge System
Handles reliable request/response processing between stateless clients and MCP servers
with comprehensive error handling, monitoring, and automatic recovery
"""

import os
import json
import time
import uuid
import asyncio
import aiofiles
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
from enum import Enum
import logging
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import concurrent.futures
from contextlib import asynccontextmanager

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s',
    handlers=[
        logging.FileHandler('mcp_bridge.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('MCPBridge')

class RequestStatus(Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    TIMEOUT = "timeout"

@dataclass
class BridgeRequest:
    request_id: str
    tool_name: str
    arguments: Dict[str, Any]
    timestamp: datetime
    client_id: Optional[str] = None
    priority: int = 0
    timeout_seconds: int = 30
    retry_count: int = 0
    max_retries: int = 3

@dataclass
class BridgeResponse:
    request_id: str
    status: RequestStatus
    timestamp: datetime
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    processing_time_ms: Optional[int] = None
    metadata: Optional[Dict[str, Any]] = None

@dataclass
class BridgeMetrics:
    total_requests: int = 0
    successful_responses: int = 0
    failed_responses: int = 0
    timeout_responses: int = 0
    average_processing_time_ms: float = 0.0
    active_requests: int = 0
    queue_size: int = 0
    error_rate_percent: float = 0.0

class BridgeRequestHandler(FileSystemEventHandler):
    """Handle incoming bridge requests via file system events"""
    
    def __init__(self, bridge_processor):
        self.bridge_processor = bridge_processor
        
    def on_created(self, event):
        if not event.is_directory and event.src_path.endswith('.json'):
            logger.info(f"New request detected: {event.src_path}")
            asyncio.create_task(self.bridge_processor.process_file_request(event.src_path))

class MCPBridgeProcessor:
    """Production-grade MCP bridge system with monitoring and error recovery"""
    
    def __init__(self, config_file: str = "mcp_config.json"):
        self.config = self._load_config(config_file)
        
        # Core directories
        self.request_dir = Path(self.config['bridge']['request_dir'])
        self.response_dir = Path(self.config['bridge']['response_dir'])
        self.request_dir.mkdir(parents=True, exist_ok=True)
        self.response_dir.mkdir(parents=True, exist_ok=True)
        
        # Request tracking
        self.active_requests: Dict[str, BridgeRequest] = {}
        self.request_queue: asyncio.Queue = asyncio.Queue()
        self.metrics = BridgeMetrics()
        
        # Configuration
        self.max_concurrent = self.config['bridge'].get('max_concurrent_requests', 10)
        self.processing_timeout = self.config['bridge'].get('processing_timeout_seconds', 30)
        self.cleanup_interval = self.config['bridge'].get('cleanup_interval_hours', 24)
        
        # Worker management
        self.workers: List[asyncio.Task] = []
        self.running = False
        self.file_observer: Optional[Observer] = None
        
        # Thread pool for CPU-intensive operations
        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=4)
        
    def _load_config(self, config_file: str) -> Dict[str, Any]:
        """Load configuration with validation"""
        try:
            with open(config_file) as f:
                config = json.load(f)
            
            # Validate required configuration
            required_keys = ['bridge.request_dir', 'bridge.response_dir']
            for key in required_keys:
                if not self._get_nested_value(config, key):
                    raise ValueError(f"Missing required config: {key}")
            
            return config
        except FileNotFoundError:
            logger.warning(f"Config file {config_file} not found, using defaults")
            return self._default_config()
    
    def _get_nested_value(self, data: Dict, key: str) -> Any:
        """Get nested dictionary value using dot notation"""
        keys = key.split('.')
        value = data
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return None
        return value
    
    def _default_config(self) -> Dict[str, Any]:
        """Default configuration for bridge system"""
        return {
            'bridge': {
                'request_dir': 'mcp_bridge/requests',
                'response_dir': 'mcp_bridge/responses',
                'processing_timeout_seconds': 30,
                'cleanup_interval_hours': 24,
                'max_concurrent_requests': 10
            }
        }
    
    async def start(self):
        """Start the bridge processing system"""
        logger.info("Starting MCP Bridge Processor")
        self.running = True
        
        # Start file system monitoring
        self._start_file_monitoring()
        
        # Start worker tasks
        for i in range(self.max_concurrent):
            worker = asyncio.create_task(self._worker(f"worker-{i}"))
            self.workers.append(worker)
        
        # Start maintenance tasks
        asyncio.create_task(self._cleanup_task())
        asyncio.create_task(self._metrics_reporter())
        
        # Process any existing requests
        await self._process_existing_requests()
        
        logger.info(f"Bridge processor started with {len(self.workers)} workers")
    
    async def stop(self):
        """Gracefully stop the bridge processor"""
        logger.info("Stopping MCP Bridge Processor")
        self.running = False
        
        # Stop file monitoring
        if self.file_observer:
            self.file_observer.stop()
            self.file_observer.join()
        
        # Cancel worker tasks
        for worker in self.workers:
            worker.cancel()
        
        # Wait for workers to finish current tasks
        await asyncio.gather(*self.workers, return_exceptions=True)
        
        # Close thread pool
        self.executor.shutdown(wait=True)
        
        logger.info("Bridge processor stopped")
    
    def _start_file_monitoring(self):
        """Start monitoring the request directory for new files"""
        event_handler = BridgeRequestHandler(self)
        self.file_observer = Observer()
        self.file_observer.schedule(event_handler, str(self.request_dir), recursive=False)
        self.file_observer.start()
        logger.info(f"File monitoring started for: {self.request_dir}")
    
    async def _process_existing_requests(self):
        """Process any requests that were pending when the system restarted"""
        for request_file in self.request_dir.glob("*.json"):
            try:
                # Check if response already exists
                response_file = self.response_dir / request_file.name
                if not response_file.exists():
                    logger.info(f"Processing existing request: {request_file}")
                    await self.process_file_request(str(request_file))
            except Exception as e:
                logger.error(f"Error processing existing request {request_file}: {e}")
    
    async def process_file_request(self, file_path: str):
        """Process a request from a file"""
        try:
            async with aiofiles.open(file_path, 'r') as f:
                content = await f.read()
            
            request_data = json.loads(content)
            request = BridgeRequest(
                request_id=request_data['request_id'],
                tool_name=request_data['tool_name'],
                arguments=request_data['arguments'],
                timestamp=datetime.now(),
                client_id=request_data.get('client_id'),
                priority=request_data.get('priority', 0),
                timeout_seconds=request_data.get('timeout_seconds', self.processing_timeout)
            )
            
            await self.queue_request(request)
            
        except Exception as e:
            logger.error(f"Error processing request file {file_path}: {e}")
            # Create error response
            await self._create_error_response(
                request_id=Path(file_path).stem,
                error=f"Failed to parse request: {e}"
            )
    
    async def queue_request(self, request: BridgeRequest):
        """Queue a request for processing"""
        self.active_requests[request.request_id] = request
        await self.request_queue.put(request)
        self.metrics.queue_size = self.request_queue.qsize()
        logger.debug(f"Queued request {request.request_id} for tool {request.tool_name}")
    
    async def _worker(self, worker_name: str):
        """Worker task that processes requests from the queue"""
        logger.info(f"Worker {worker_name} started")
        
        while self.running:
            try:
                # Get request from queue with timeout
                request = await asyncio.wait_for(
                    self.request_queue.get(),
                    timeout=1.0
                )
                
                self.metrics.active_requests += 1
                await self._process_request(request, worker_name)
                self.metrics.active_requests -= 1
                self.metrics.queue_size = self.request_queue.qsize()
                
            except asyncio.TimeoutError:
                continue  # No requests in queue, continue waiting
            except Exception as e:
                logger.error(f"Worker {worker_name} error: {e}")
                self.metrics.active_requests = max(0, self.metrics.active_requests - 1)
    
    async def _process_request(self, request: BridgeRequest, worker_name: str):
        """Process a single request with comprehensive error handling"""
        start_time = time.time()
        logger.info(f"Worker {worker_name} processing request {request.request_id}")
        
        try:
            # Update metrics
            self.metrics.total_requests += 1
            
            # Simulate MCP tool execution (replace with actual MCP integration)
            response_data = await self._execute_mcp_tool(request)
            
            processing_time_ms = int((time.time() - start_time) * 1000)
            
            # Create successful response
            response = BridgeResponse(
                request_id=request.request_id,
                status=RequestStatus.COMPLETED,
                timestamp=datetime.now(),
                data=response_data,
                processing_time_ms=processing_time_ms,
                metadata={
                    'worker': worker_name,
                    'tool_name': request.tool_name,
                    'retry_count': request.retry_count
                }
            )
            
            await self._write_response(response)
            self.metrics.successful_responses += 1
            
            # Update average processing time
            self._update_average_processing_time(processing_time_ms)
            
            logger.info(f"Successfully processed {request.request_id} in {processing_time_ms}ms")
            
        except asyncio.TimeoutError:
            logger.warning(f"Request {request.request_id} timed out")
            await self._handle_timeout(request)
            
        except Exception as e:
            logger.error(f"Error processing request {request.request_id}: {e}")
            await self._handle_error(request, str(e))
            
        finally:
            # Clean up active request tracking
            self.active_requests.pop(request.request_id, None)
    
    async def _execute_mcp_tool(self, request: BridgeRequest) -> Dict[str, Any]:
        """Execute the actual MCP tool (placeholder for integration)"""
        # This is where you would integrate with your actual MCP servers
        # For now, we'll simulate different tool responses
        
        tool_name = request.tool_name
        arguments = request.arguments
        
        # Simulate processing time based on tool complexity
        if tool_name == "gemini_quick_query":
            await asyncio.sleep(0.5)  # Quick query
            return {
                "query": arguments.get("query", ""),
                "answer": f"Simulated response for: {arguments.get('query', 'unknown query')}",
                "model_used": "gemini-2.0-flash-exp",
                "tokens": 150
            }
        elif tool_name == "gemini_analyze_code":
            await asyncio.sleep(2.0)  # Code analysis takes longer
            return {
                "analysis": f"Code analysis completed for {len(arguments.get('code_content', ''))} characters",
                "issues_found": 3,
                "suggestions": ["Use type hints", "Add error handling", "Optimize performance"]
            }
        else:
            # Unknown tool
            raise ValueError(f"Unknown tool: {tool_name}")
    
    async def _write_response(self, response: BridgeResponse):
        """Write response to file system"""
        response_file = self.response_dir / f"{response.request_id}.json"
        
        response_data = asdict(response)
        # Convert datetime to ISO string for JSON serialization
        response_data['timestamp'] = response.timestamp.isoformat()
        response_data['status'] = response.status.value
        
        async with aiofiles.open(response_file, 'w') as f:
            await f.write(json.dumps(response_data, indent=2))
        
        logger.debug(f"Response written to: {response_file}")
    
    async def _handle_timeout(self, request: BridgeRequest):
        """Handle request timeout"""
        response = BridgeResponse(
            request_id=request.request_id,
            status=RequestStatus.TIMEOUT,
            timestamp=datetime.now(),
            error=f"Request timed out after {request.timeout_seconds} seconds",
            metadata={'retry_count': request.retry_count}
        )
        
        await self._write_response(response)
        self.metrics.timeout_responses += 1
    
    async def _handle_error(self, request: BridgeRequest, error_message: str):
        """Handle request processing error with retry logic"""
        if request.retry_count < request.max_retries:
            # Retry the request
            request.retry_count += 1
            logger.info(f"Retrying request {request.request_id} (attempt {request.retry_count})")
            await asyncio.sleep(2 ** request.retry_count)  # Exponential backoff
            await self.queue_request(request)
        else:
            # Max retries exceeded, create error response
            response = BridgeResponse(
                request_id=request.request_id,
                status=RequestStatus.FAILED,
                timestamp=datetime.now(),
                error=error_message,
                metadata={'retry_count': request.retry_count}
            )
            
            await self._write_response(response)
            self.metrics.failed_responses += 1
    
    async def _create_error_response(self, request_id: str, error: str):
        """Create an error response for malformed requests"""
        response = BridgeResponse(
            request_id=request_id,
            status=RequestStatus.FAILED,
            timestamp=datetime.now(),
            error=error
        )
        
        await self._write_response(response)
        self.metrics.failed_responses += 1
    
    def _update_average_processing_time(self, processing_time_ms: int):
        """Update running average of processing time"""
        total_successful = self.metrics.successful_responses
        if total_successful == 1:
            self.metrics.average_processing_time_ms = processing_time_ms
        else:
            # Running average
            current_avg = self.metrics.average_processing_time_ms
            self.metrics.average_processing_time_ms = (
                (current_avg * (total_successful - 1) + processing_time_ms) / total_successful
            )
    
    async def _cleanup_task(self):
        """Periodic cleanup of old request/response files"""
        while self.running:
            try:
                await asyncio.sleep(3600)  # Run every hour
                await self._cleanup_old_files()
            except Exception as e:
                logger.error(f"Cleanup task error: {e}")
    
    async def _cleanup_old_files(self):
        """Remove old request/response files"""
        cutoff_time = datetime.now() - timedelta(hours=self.cleanup_interval)
        
        cleaned_requests = 0
        cleaned_responses = 0
        
        # Clean up old request files
        for request_file in self.request_dir.glob("*.json"):
            if datetime.fromtimestamp(request_file.stat().st_mtime) < cutoff_time:
                request_file.unlink()
                cleaned_requests += 1
        
        # Clean up old response files
        for response_file in self.response_dir.glob("*.json"):
            if datetime.fromtimestamp(response_file.stat().st_mtime) < cutoff_time:
                response_file.unlink()
                cleaned_responses += 1
        
        if cleaned_requests > 0 or cleaned_responses > 0:
            logger.info(f"Cleanup completed: {cleaned_requests} requests, {cleaned_responses} responses")
    
    async def _metrics_reporter(self):
        """Periodic metrics reporting"""
        while self.running:
            try:
                await asyncio.sleep(300)  # Report every 5 minutes
                self._calculate_error_rate()
                self._log_metrics()
            except Exception as e:
                logger.error(f"Metrics reporter error: {e}")
    
    def _calculate_error_rate(self):
        """Calculate current error rate"""
        total_responses = (
            self.metrics.successful_responses + 
            self.metrics.failed_responses + 
            self.metrics.timeout_responses
        )
        
        if total_responses > 0:
            error_count = self.metrics.failed_responses + self.metrics.timeout_responses
            self.metrics.error_rate_percent = (error_count / total_responses) * 100
    
    def _log_metrics(self):
        """Log current metrics"""
        logger.info(
            f"Bridge Metrics - "
            f"Total: {self.metrics.total_requests}, "
            f"Success: {self.metrics.successful_responses}, "
            f"Failed: {self.metrics.failed_responses}, "
            f"Timeout: {self.metrics.timeout_responses}, "
            f"Active: {self.metrics.active_requests}, "
            f"Queue: {self.metrics.queue_size}, "
            f"Avg Time: {self.metrics.average_processing_time_ms:.1f}ms, "
            f"Error Rate: {self.metrics.error_rate_percent:.1f}%"
        )
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get current metrics as dictionary"""
        self._calculate_error_rate()
        return asdict(self.metrics)

# Health check endpoint for monitoring
async def health_check_handler(bridge_processor: MCPBridgeProcessor) -> Dict[str, Any]:
    """Health check endpoint for external monitoring"""
    metrics = bridge_processor.get_metrics()
    
    # Determine health status based on metrics
    health_status = "healthy"
    if metrics['error_rate_percent'] > 10:
        health_status = "degraded"
    if metrics['active_requests'] >= bridge_processor.max_concurrent:
        health_status = "overloaded"
    
    return {
        "status": health_status,
        "timestamp": datetime.now().isoformat(),
        "metrics": metrics,
        "version": "1.0.0"
    }

# Main execution
async def main():
    bridge_processor = MCPBridgeProcessor()
    
    try:
        await bridge_processor.start()
        
        logger.info("MCP Bridge Processor is running. Press Ctrl+C to stop.")
        
        # Keep running until interrupted
        while True:
            await asyncio.sleep(1)
            
    except KeyboardInterrupt:
        logger.info("Shutdown signal received")
    finally:
        await bridge_processor.stop()

if __name__ == "__main__":
    asyncio.run(main())
