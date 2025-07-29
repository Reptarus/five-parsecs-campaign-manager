#!/usr/bin/env python3
"""
Production MCP Process Manager
Handles lifecycle management for all MCP servers with monitoring, health checks, and automatic recovery
"""

import psutil
import json
import time
import subprocess
import logging
from pathlib import Path
from typing import Dict, List, Optional, NamedTuple
from datetime import datetime, timedelta
import threading
from dataclasses import dataclass

# Configure production logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('mcp_manager.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('MCPManager')

@dataclass
class MCPServerConfig:
    name: str
    command: List[str]
    working_dir: str
    env_vars: Dict[str, str]
    max_memory_mb: int = 100
    max_restart_attempts: int = 3
    health_check_interval: int = 30
    port: Optional[int] = None

class ProcessHealth(NamedTuple):
    pid: int
    memory_mb: float
    cpu_percent: float
    uptime_seconds: int
    status: str

class MCPProcessManager:
    def __init__(self, config_file: str = "mcp_config.json"):
        self.config_file = Path(config_file)
        self.processes: Dict[str, psutil.Process] = {}
        self.restart_counts: Dict[str, int] = {}
        self.last_health_check: Dict[str, datetime] = {}
        self.running = False
        self.health_thread: Optional[threading.Thread] = None
        
        # Load server configurations
        self.server_configs = self._load_configurations()
        
    def _load_configurations(self) -> Dict[str, MCPServerConfig]:
        """Load MCP server configurations from JSON file"""
        try:
            with open(self.config_file) as f:
                configs = json.load(f)
            
            servers = {}
            for name, config in configs.get('servers', {}).items():
                servers[name] = MCPServerConfig(
                    name=name,
                    command=config['command'],
                    working_dir=config.get('working_dir', '.'),
                    env_vars=config.get('env_vars', {}),
                    max_memory_mb=config.get('max_memory_mb', 100),
                    max_restart_attempts=config.get('max_restart_attempts', 3),
                    health_check_interval=config.get('health_check_interval', 30),
                    port=config.get('port')
                )
            
            return servers
        except FileNotFoundError:
            logger.warning(f"Config file {self.config_file} not found, using defaults")
            return self._default_configurations()
    
    def _default_configurations(self) -> Dict[str, MCPServerConfig]:
        """Default MCP server configurations"""
        return {
            'gemini-orchestrator': MCPServerConfig(
                name='gemini-orchestrator',
                command=['python', 'gemini_mcp_server.py'],
                working_dir='C:/Users/elija/Creative-Tools-MCP/community-mcp-servers/claude-gemini-mcp-slim-main',
                env_vars={'GOOGLE_API_KEY': '${GOOGLE_API_KEY}'},
                max_memory_mb=200,
                port=3000
            ),
            'memory-server': MCPServerConfig(
                name='memory-server',
                command=['npx', '-y', '@modelcontextprotocol/server-memory@latest'],
                working_dir='.',
                env_vars={},
                max_memory_mb=50,
                port=3001
            )
        }
    
    def start_server(self, server_name: str) -> bool:
        """Start an MCP server with comprehensive error handling"""
        if server_name not in self.server_configs:
            logger.error(f"Unknown server: {server_name}")
            return False
        
        config = self.server_configs[server_name]
        
        # Check if already running
        if server_name in self.processes and self.processes[server_name].is_running():
            logger.info(f"{server_name} is already running (PID: {self.processes[server_name].pid})")
            return True
        
        try:
            # Prepare environment
            env = os.environ.copy()
            env.update(config.env_vars)
            
            # Expand environment variables in env_vars
            for key, value in env.items():
                if value.startswith('${') and value.endswith('}'):
                    env_var = value[2:-1]
                    if env_var in os.environ:
                        env[key] = os.environ[env_var]
            
            # Start the process
            logger.info(f"Starting {server_name}: {' '.join(config.command)}")
            
            process = subprocess.Popen(
                config.command,
                cwd=config.working_dir,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Wait briefly to ensure it starts successfully
            time.sleep(2)
            
            if process.poll() is None:  # Process is still running
                self.processes[server_name] = psutil.Process(process.pid)
                self.restart_counts[server_name] = 0
                self.last_health_check[server_name] = datetime.now()
                logger.info(f"Successfully started {server_name} (PID: {process.pid})")
                return True
            else:
                stdout, stderr = process.communicate()
                logger.error(f"Failed to start {server_name}: {stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Error starting {server_name}: {e}")
            return False
    
    def stop_server(self, server_name: str) -> bool:
        """Gracefully stop an MCP server"""
        if server_name not in self.processes:
            logger.warning(f"{server_name} is not being managed")
            return True
        
        try:
            process = self.processes[server_name]
            if process.is_running():
                logger.info(f"Stopping {server_name} (PID: {process.pid})")
                
                # Try graceful shutdown first
                process.terminate()
                
                # Wait up to 10 seconds for graceful shutdown
                try:
                    process.wait(timeout=10)
                except psutil.TimeoutExpired:
                    logger.warning(f"Force killing {server_name}")
                    process.kill()
                    process.wait()
                
                logger.info(f"Successfully stopped {server_name}")
            
            del self.processes[server_name]
            return True
            
        except Exception as e:
            logger.error(f"Error stopping {server_name}: {e}")
            return False
    
    def get_process_health(self, server_name: str) -> Optional[ProcessHealth]:
        """Get detailed health information for a process"""
        if server_name not in self.processes:
            return None
        
        try:
            process = self.processes[server_name]
            if not process.is_running():
                return None
            
            # Get process metrics
            memory_info = process.memory_info()
            memory_mb = memory_info.rss / (1024 * 1024)
            cpu_percent = process.cpu_percent()
            
            # Calculate uptime
            create_time = datetime.fromtimestamp(process.create_time())
            uptime = (datetime.now() - create_time).total_seconds()
            
            return ProcessHealth(
                pid=process.pid,
                memory_mb=memory_mb,
                cpu_percent=cpu_percent,
                uptime_seconds=int(uptime),
                status=process.status()
            )
            
        except Exception as e:
            logger.error(f"Error getting health for {server_name}: {e}")
            return None
    
    def check_and_restart_if_needed(self, server_name: str) -> bool:
        """Check server health and restart if necessary"""
        config = self.server_configs[server_name]
        health = self.get_process_health(server_name)
        
        # Process is dead
        if health is None:
            if self.restart_counts.get(server_name, 0) < config.max_restart_attempts:
                logger.warning(f"{server_name} is dead, attempting restart")
                self.restart_counts[server_name] = self.restart_counts.get(server_name, 0) + 1
                return self.start_server(server_name)
            else:
                logger.error(f"{server_name} exceeded max restart attempts")
                return False
        
        # Memory usage too high
        if health.memory_mb > config.max_memory_mb:
            logger.warning(f"{server_name} using {health.memory_mb:.1f}MB (limit: {config.max_memory_mb}MB)")
            if self.restart_counts.get(server_name, 0) < config.max_restart_attempts:
                logger.info(f"Restarting {server_name} due to high memory usage")
                self.stop_server(server_name)
                self.restart_counts[server_name] = self.restart_counts.get(server_name, 0) + 1
                return self.start_server(server_name)
        
        # Reset restart count on successful health check
        if health.status == psutil.STATUS_RUNNING:
            self.restart_counts[server_name] = 0
        
        return True
    
    def health_monitor_loop(self):
        """Continuous health monitoring loop"""
        while self.running:
            try:
                for server_name, config in self.server_configs.items():
                    # Check if it's time for a health check
                    last_check = self.last_health_check.get(server_name, datetime.min)
                    if (datetime.now() - last_check).total_seconds() >= config.health_check_interval:
                        self.check_and_restart_if_needed(server_name)
                        self.last_health_check[server_name] = datetime.now()
                
                time.sleep(5)  # Check every 5 seconds
                
            except Exception as e:
                logger.error(f"Error in health monitor: {e}")
                time.sleep(10)  # Wait longer on error
    
    def start_all(self):
        """Start all configured MCP servers"""
        logger.info("Starting MCP Process Manager")
        self.running = True
        
        # Start all servers
        for server_name in self.server_configs:
            self.start_server(server_name)
        
        # Start health monitoring
        self.health_thread = threading.Thread(target=self.health_monitor_loop, daemon=True)
        self.health_thread.start()
        
        logger.info("MCP Process Manager started successfully")
    
    def stop_all(self):
        """Stop all managed processes"""
        logger.info("Stopping MCP Process Manager")
        self.running = False
        
        # Stop health monitoring
        if self.health_thread:
            self.health_thread.join(timeout=5)
        
        # Stop all servers
        for server_name in list(self.processes.keys()):
            self.stop_server(server_name)
        
        logger.info("MCP Process Manager stopped")
    
    def status_report(self) -> Dict:
        """Generate comprehensive status report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'servers': {},
            'summary': {
                'total_servers': len(self.server_configs),
                'running_servers': 0,
                'total_memory_mb': 0,
                'healthy_servers': 0
            }
        }
        
        for server_name, config in self.server_configs.items():
            health = self.get_process_health(server_name)
            
            if health:
                report['servers'][server_name] = {
                    'status': 'running',
                    'pid': health.pid,
                    'memory_mb': health.memory_mb,
                    'cpu_percent': health.cpu_percent,
                    'uptime_seconds': health.uptime_seconds,
                    'restart_count': self.restart_counts.get(server_name, 0),
                    'max_memory_mb': config.max_memory_mb,
                    'memory_usage_percent': (health.memory_mb / config.max_memory_mb) * 100
                }
                
                report['summary']['running_servers'] += 1
                report['summary']['total_memory_mb'] += health.memory_mb
                
                if health.memory_mb <= config.max_memory_mb:
                    report['summary']['healthy_servers'] += 1
            else:
                report['servers'][server_name] = {
                    'status': 'stopped',
                    'restart_count': self.restart_counts.get(server_name, 0)
                }
        
        return report

if __name__ == "__main__":
    import signal
    import os
    
    manager = MCPProcessManager()
    
    def signal_handler(sig, frame):
        print("\nShutting down MCP Process Manager...")
        manager.stop_all()
        exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        manager.start_all()
        
        # Keep running and provide status updates
        while True:
            time.sleep(60)  # Status report every minute
            report = manager.status_report()
            logger.info(f"Status: {report['summary']['running_servers']}/{report['summary']['total_servers']} servers running, "
                       f"{report['summary']['total_memory_mb']:.1f}MB total memory")
                       
    except KeyboardInterrupt:
        manager.stop_all()
