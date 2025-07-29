#!/usr/bin/env python3
"""
MCP Ecosystem Deployment and Operations Manager
Production-grade automation for deploying, monitoring, and maintaining the MCP infrastructure
"""

import os
import sys
import json
import time
import signal
import subprocess
import asyncio
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import logging
import psutil
import requests
from dataclasses import dataclass
import concurrent.futures

# Import our custom components
sys.path.append(str(Path(__file__).parent))
from mcp_process_manager import MCPProcessManager
from mcp_bridge_processor import MCPBridgeProcessor

# Configure production logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - [%(process)d] - %(message)s',
    handlers=[
        logging.FileHandler('mcp_ecosystem.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('MCPEcosystem')

@dataclass
class DeploymentConfig:
    """Configuration for MCP ecosystem deployment"""
    config_file: str = "mcp_config.json"
    log_level: str = "INFO"
    health_check_port: int = 8080
    metrics_interval: int = 300  # 5 minutes
    auto_restart: bool = True
    max_restart_attempts: int = 5
    environment: str = "production"  # development, staging, production

@dataclass
class EcosystemHealth:
    """Health status of the entire MCP ecosystem"""
    timestamp: datetime
    overall_status: str  # healthy, degraded, critical, down
    process_manager_status: str
    bridge_processor_status: str
    active_servers: int
    total_servers: int
    bridge_queue_size: int
    error_rate_percent: float
    memory_usage_mb: float
    issues: List[str]

class MCPEcosystemManager:
    """Production manager for the entire MCP ecosystem"""
    
    def __init__(self, config: DeploymentConfig):
        self.config = config
        self.process_manager: Optional[MCPProcessManager] = None
        self.bridge_processor: Optional[MCPBridgeProcessor] = None
        self.running = False
        self.health_server: Optional[asyncio.Server] = None
        self.metrics_task: Optional[asyncio.Task] = None
        
        # Ensure required directories exist
        self._setup_directories()
        
        # Validate environment
        self._validate_environment()
        
    def _setup_directories(self):
        """Create required directories for the MCP ecosystem"""
        required_dirs = [
            "mcp_bridge/requests",
            "mcp_bridge/responses", 
            "logs",
            "metrics",
            "backups"
        ]
        
        for dir_path in required_dirs:
            Path(dir_path).mkdir(parents=True, exist_ok=True)
            logger.debug(f"Ensured directory exists: {dir_path}")
    
    def _validate_environment(self):
        """Validate that all required environment variables and dependencies are available"""
        required_env_vars = [
            "GOOGLE_API_KEY"
        ]
        
        missing_vars = []
        for var in required_env_vars:
            if not os.getenv(var):
                missing_vars.append(var)
        
        if missing_vars:
            logger.error(f"Missing required environment variables: {missing_vars}")
            raise ValueError(f"Missing environment variables: {missing_vars}")
        
        # Check Python dependencies
        required_packages = ["psutil", "aiofiles", "watchdog"]
        missing_packages = []
        
        for package in required_packages:
            try:
                __import__(package)
            except ImportError:
                missing_packages.append(package)
        
        if missing_packages:
            logger.error(f"Missing required packages: {missing_packages}")
            raise ImportError(f"Missing packages: {missing_packages}. Install with: pip install {' '.join(missing_packages)}")
        
        logger.info("Environment validation completed successfully")
    
    async def start(self):
        """Start the complete MCP ecosystem"""
        logger.info("Starting MCP Ecosystem Manager")
        self.running = True
        
        try:
            # Start process manager
            logger.info("Starting MCP Process Manager...")
            self.process_manager = MCPProcessManager(self.config.config_file)
            self.process_manager.start_all()
            
            # Wait for processes to stabilize
            await asyncio.sleep(5)
            
            # Start bridge processor
            logger.info("Starting MCP Bridge Processor...")
            self.bridge_processor = MCPBridgeProcessor(self.config.config_file)
            await self.bridge_processor.start()
            
            # Start health monitoring server
            await self._start_health_server()
            
            # Start metrics collection
            self.metrics_task = asyncio.create_task(self._metrics_collector())
            
            # Perform initial health check
            health = await self._comprehensive_health_check()
            logger.info(f"Ecosystem startup completed - Status: {health.overall_status}")
            
            if health.overall_status == "critical":
                logger.error("Critical issues detected during startup")
                for issue in health.issues:
                    logger.error(f"  - {issue}")
                    
                if not self.config.auto_restart:
                    raise RuntimeError("Critical startup issues detected and auto-restart is disabled")
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to start MCP ecosystem: {e}")
            await self.stop()
            raise
    
    async def stop(self):
        """Gracefully stop the MCP ecosystem"""
        logger.info("Stopping MCP Ecosystem Manager")
        self.running = False
        
        # Stop metrics collection
        if self.metrics_task:
            self.metrics_task.cancel()
            try:
                await self.metrics_task
            except asyncio.CancelledError:
                pass
        
        # Stop health server
        if self.health_server:
            self.health_server.close()
            await self.health_server.wait_closed()
        
        # Stop bridge processor
        if self.bridge_processor:
            await self.bridge_processor.stop()
        
        # Stop process manager
        if self.process_manager:
            self.process_manager.stop_all()
        
        logger.info("MCP ecosystem stopped")
    
    async def restart(self):
        """Restart the entire ecosystem"""
        logger.info("Restarting MCP ecosystem")
        await self.stop()
        await asyncio.sleep(3)  # Brief pause for cleanup
        await self.start()
        logger.info("MCP ecosystem restart completed")
    
    async def _start_health_server(self):
        """Start HTTP health check server"""
        async def health_handler(request):
            """HTTP handler for health checks"""
            health = await self._comprehensive_health_check()
            
            # Determine HTTP status code based on health
            status_codes = {
                "healthy": 200,
                "degraded": 200,  # Still operational
                "critical": 503,  # Service unavailable
                "down": 503
            }
            
            response_data = {
                "status": health.overall_status,
                "timestamp": health.timestamp.isoformat(),
                "details": {
                    "process_manager": health.process_manager_status,
                    "bridge_processor": health.bridge_processor_status,
                    "active_servers": health.active_servers,
                    "total_servers": health.total_servers,
                    "bridge_queue_size": health.bridge_queue_size,
                    "error_rate_percent": health.error_rate_percent,
                    "memory_usage_mb": health.memory_usage_mb
                },
                "issues": health.issues,
                "version": "1.0.0"
            }
            
            return web.json_response(
                response_data,
                status=status_codes.get(health.overall_status, 503)
            )
        
        # Simple HTTP server for health checks
        try:
            from aiohttp import web
            
            app = web.Application()
            app.router.add_get('/health', health_handler)
            app.router.add_get('/healthz', health_handler)  # Kubernetes-style
            
            self.health_server = await asyncio.start_server(
                lambda r, w: None,  # Placeholder - aiohttp handles this
                '0.0.0.0',
                self.config.health_check_port
            )
            
            logger.info(f"Health check server started on port {self.config.health_check_port}")
            
        except ImportError:
            logger.warning("aiohttp not available, health server disabled")
        except Exception as e:
            logger.error(f"Failed to start health server: {e}")
    
    async def _comprehensive_health_check(self) -> EcosystemHealth:
        """Perform comprehensive health check of the entire ecosystem"""
        timestamp = datetime.now()
        issues = []
        
        # Check process manager
        process_manager_status = "unknown"
        active_servers = 0
        total_servers = 0
        memory_usage_mb = 0.0
        
        if self.process_manager:
            try:
                report = self.process_manager.status_report()
                active_servers = report['summary']['running_servers']
                total_servers = report['summary']['total_servers']
                memory_usage_mb = report['summary']['total_memory_mb']
                
                if active_servers == total_servers:
                    process_manager_status = "healthy"
                elif active_servers > 0:
                    process_manager_status = "degraded"
                    issues.append(f"Only {active_servers}/{total_servers} MCP servers running")
                else:
                    process_manager_status = "critical"
                    issues.append("No MCP servers are running")
                    
            except Exception as e:
                process_manager_status = "error"
                issues.append(f"Process manager error: {e}")
        else:
            process_manager_status = "not_started"
            issues.append("Process manager not started")
        
        # Check bridge processor
        bridge_processor_status = "unknown"
        bridge_queue_size = 0
        error_rate_percent = 0.0
        
        if self.bridge_processor:
            try:
                metrics = self.bridge_processor.get_metrics()
                bridge_queue_size = metrics['queue_size']
                error_rate_percent = metrics['error_rate_percent']
                
                if error_rate_percent < 5:
                    bridge_processor_status = "healthy"
                elif error_rate_percent < 15:
                    bridge_processor_status = "degraded"
                    issues.append(f"High error rate: {error_rate_percent:.1f}%")
                else:
                    bridge_processor_status = "critical"
                    issues.append(f"Critical error rate: {error_rate_percent:.1f}%")
                
                if bridge_queue_size > 50:
                    issues.append(f"High queue size: {bridge_queue_size}")
                    
            except Exception as e:
                bridge_processor_status = "error"
                issues.append(f"Bridge processor error: {e}")
        else:
            bridge_processor_status = "not_started"
            issues.append("Bridge processor not started")
        
        # Check system resources
        try:
            system_memory = psutil.virtual_memory()
            if system_memory.percent > 90:
                issues.append(f"High system memory usage: {system_memory.percent:.1f}%")
            
            disk_usage = psutil.disk_usage('.')
            if disk_usage.percent > 85:
                issues.append(f"High disk usage: {disk_usage.percent:.1f}%")
                
        except Exception as e:
            issues.append(f"System resource check failed: {e}")
        
        # Determine overall status
        if not issues:
            overall_status = "healthy"
        elif any("critical" in status for status in [process_manager_status, bridge_processor_status]):
            overall_status = "critical"
        elif any("error" in status for status in [process_manager_status, bridge_processor_status]):
            overall_status = "critical"
        elif len(issues) > 0:
            overall_status = "degraded"
        else:
            overall_status = "healthy"
        
        return EcosystemHealth(
            timestamp=timestamp,
            overall_status=overall_status,
            process_manager_status=process_manager_status,
            bridge_processor_status=bridge_processor_status,
            active_servers=active_servers,
            total_servers=total_servers,
            bridge_queue_size=bridge_queue_size,
            error_rate_percent=error_rate_percent,
            memory_usage_mb=memory_usage_mb,
            issues=issues
        )
    
    async def _metrics_collector(self):
        """Collect and store metrics periodically"""
        while self.running:
            try:
                health = await self._comprehensive_health_check()
                
                # Store metrics in JSON format
                metrics_file = Path("metrics") / f"metrics_{datetime.now().strftime('%Y%m%d_%H%M')}.json"
                
                metrics_data = {
                    "timestamp": health.timestamp.isoformat(),
                    "overall_status": health.overall_status,
                    "active_servers": health.active_servers,
                    "total_servers": health.total_servers,
                    "bridge_queue_size": health.bridge_queue_size,
                    "error_rate_percent": health.error_rate_percent,
                    "memory_usage_mb": health.memory_usage_mb,
                    "issue_count": len(health.issues)
                }
                
                with open(metrics_file, 'w') as f:
                    json.dump(metrics_data, f, indent=2)
                
                # Log key metrics
                logger.info(
                    f"Metrics - Status: {health.overall_status}, "
                    f"Servers: {health.active_servers}/{health.total_servers}, "
                    f"Queue: {health.bridge_queue_size}, "
                    f"Error Rate: {health.error_rate_percent:.1f}%, "
                    f"Memory: {health.memory_usage_mb:.1f}MB"
                )
                
                # Auto-restart on critical issues
                if (health.overall_status == "critical" and 
                    self.config.auto_restart and 
                    self.config.environment == "production"):
                    
                    logger.warning("Critical status detected, attempting auto-restart")
                    asyncio.create_task(self._auto_restart())
                
                await asyncio.sleep(self.config.metrics_interval)
                
            except Exception as e:
                logger.error(f"Metrics collection error: {e}")
                await asyncio.sleep(60)  # Wait longer on error
    
    async def _auto_restart(self):
        """Automatic restart with exponential backoff"""
        max_attempts = self.config.max_restart_attempts
        
        for attempt in range(1, max_attempts + 1):
            try:
                logger.info(f"Auto-restart attempt {attempt}/{max_attempts}")
                await self.restart()
                
                # Verify restart was successful
                await asyncio.sleep(10)
                health = await self._comprehensive_health_check()
                
                if health.overall_status in ["healthy", "degraded"]:
                    logger.info("Auto-restart successful")
                    return
                else:
                    logger.warning(f"Auto-restart attempt {attempt} failed, status: {health.overall_status}")
                    
            except Exception as e:
                logger.error(f"Auto-restart attempt {attempt} failed: {e}")
            
            if attempt < max_attempts:
                wait_time = min(60 * (2 ** attempt), 600)  # Max 10 minutes
                logger.info(f"Waiting {wait_time} seconds before next restart attempt")
                await asyncio.sleep(wait_time)
        
        logger.error("All auto-restart attempts failed")
        
        # Send alert (implement your alerting mechanism here)
        await self._send_critical_alert("All auto-restart attempts failed")
    
    async def _send_critical_alert(self, message: str):
        """Send critical alert (implement based on your alerting system)"""
        logger.critical(f"CRITICAL ALERT: {message}")
        
        # Example implementations:
        # - Send email via SMTP
        # - Post to Slack webhook
        # - Send to monitoring system (PagerDuty, etc.)
        # - Write to alert file for external monitoring
        
        alert_file = Path("alerts") / f"critical_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        alert_file.parent.mkdir(exist_ok=True)
        
        alert_data = {
            "timestamp": datetime.now().isoformat(),
            "level": "critical",
            "message": message,
            "ecosystem_health": "critical"
        }
        
        with open(alert_file, 'w') as f:
            json.dump(alert_data, f, indent=2)

# CLI Interface
async def main():
    """Main CLI interface for MCP ecosystem management"""
    import argparse
    
    parser = argparse.ArgumentParser(description="MCP Ecosystem Manager")
    parser.add_argument("--config", default="mcp_config.json", help="Configuration file path")
    parser.add_argument("--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"])
    parser.add_argument("--health-port", type=int, default=8080, help="Health check port")
    parser.add_argument("--environment", default="production", choices=["development", "staging", "production"])
    parser.add_argument("--no-auto-restart", action="store_true", help="Disable automatic restart")
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Start command
    start_parser = subparsers.add_parser("start", help="Start the MCP ecosystem")
    
    # Stop command  
    stop_parser = subparsers.add_parser("stop", help="Stop the MCP ecosystem")
    
    # Restart command
    restart_parser = subparsers.add_parser("restart", help="Restart the MCP ecosystem")
    
    # Status command
    status_parser = subparsers.add_parser("status", help="Show ecosystem status")
    
    args = parser.parse_args()
    
    # Configure logging level
    logging.getLogger().setLevel(getattr(logging, args.log_level))
    
    # Create deployment config
    config = DeploymentConfig(
        config_file=args.config,
        log_level=args.log_level,
        health_check_port=args.health_port,
        auto_restart=not args.no_auto_restart,
        environment=args.environment
    )
    
    manager = MCPEcosystemManager(config)
    
    # Handle commands
    if args.command == "start" or not args.command:
        try:
            await manager.start()
            
            # Setup signal handlers
            loop = asyncio.get_running_loop()
            
            def signal_handler():
                logger.info("Shutdown signal received")
                asyncio.create_task(manager.stop())
            
            for sig in [signal.SIGINT, signal.SIGTERM]:
                loop.add_signal_handler(sig, signal_handler)
            
            logger.info("MCP Ecosystem is running. Press Ctrl+C to stop.")
            
            # Keep running until stopped
            while manager.running:
                await asyncio.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Keyboard interrupt received")
        except Exception as e:
            logger.error(f"Ecosystem manager error: {e}")
            sys.exit(1)
        finally:
            await manager.stop()
    
    elif args.command == "stop":
        # Implementation for stopping a running ecosystem
        logger.info("Stop command - implement process termination")
    
    elif args.command == "restart":
        # Implementation for restarting ecosystem
        logger.info("Restart command - implement restart logic")
    
    elif args.command == "status":
        # Implementation for status check
        try:
            # Try to connect to health endpoint
            import requests
            response = requests.get(f"http://localhost:{args.health_port}/health", timeout=5)
            health_data = response.json()
            
            print(f"Ecosystem Status: {health_data['status']}")
            print(f"Timestamp: {health_data['timestamp']}")
            print(f"Active Servers: {health_data['details']['active_servers']}/{health_data['details']['total_servers']}")
            print(f"Bridge Queue: {health_data['details']['bridge_queue_size']}")
            print(f"Error Rate: {health_data['details']['error_rate_percent']:.1f}%")
            print(f"Memory Usage: {health_data['details']['memory_usage_mb']:.1f}MB")
            
            if health_data['issues']:
                print("\nIssues:")
                for issue in health_data['issues']:
                    print(f"  - {issue}")
                    
        except requests.exceptions.RequestException:
            print("Ecosystem is not running or health endpoint is not accessible")
        except Exception as e:
            print(f"Error checking status: {e}")

if __name__ == "__main__":
    asyncio.run(main())
