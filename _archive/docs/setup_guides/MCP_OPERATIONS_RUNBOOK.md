# MCP Ecosystem Production Operations Runbook

## Overview
This runbook provides comprehensive procedures for deploying, monitoring, and maintaining the MCP ecosystem in production environments. It addresses common operational scenarios, troubleshooting procedures, and emergency response protocols.

## Quick Start Deployment

### Prerequisites Checklist
- [ ] Python 3.9+ installed with pip
- [ ] Node.js 18+ installed with npm
- [ ] Required environment variables configured
- [ ] Network ports 3000-3002, 8080 available
- [ ] Minimum 2GB RAM, 5GB disk space available

### Environment Variables
```bash
# Required
export GOOGLE_API_KEY="your_gemini_api_key_here"

# Optional - Model Configuration
export GEMINI_FLASH_MODEL="gemini-2.0-flash-exp"
export GEMINI_PRO_MODEL="gemini-2.0-flash-thinking-exp"

# Optional - Performance Tuning
export MCP_MAX_CONCURRENT_REQUESTS="10"
export MCP_PROCESSING_TIMEOUT="30"
export MCP_HEALTH_CHECK_PORT="8080"
```

### Installation & Startup
```bash
# 1. Install Python dependencies
pip install psutil aiofiles watchdog aiohttp requests

# 2. Install Node.js dependencies (for memory server)
npm install -g @modelcontextprotocol/server-memory

# 3. Start the ecosystem
python mcp_ecosystem_manager.py start --environment production

# 4. Verify health status
python mcp_ecosystem_manager.py status
```

## Architecture Components

### Core Services
1. **MCP Process Manager** - Manages lifecycle of all MCP servers
2. **Bridge Processor** - Handles request/response processing for stateless clients
3. **Health Monitor** - Provides HTTP health checks and metrics collection
4. **Metrics Collector** - Stores performance data and triggers alerts

### Service Dependencies
```
Health Monitor (Port 8080)
├── MCP Process Manager
│   ├── Gemini Orchestrator (Port 3000)
│   ├── Memory Server (Port 3001)
│   └── Filesystem Server (Port 3002)
└── Bridge Processor
    ├── Request Directory Monitor
    ├── Response Generator
    └── Queue Management
```

## Monitoring & Health Checks

### Health Check Endpoints
- **Primary**: `http://localhost:8080/health`
- **Kubernetes**: `http://localhost:8080/healthz`

### Health Status Definitions
- **healthy** (200): All services operational, error rate < 5%
- **degraded** (200): Some issues present, error rate 5-15%
- **critical** (503): Major issues, error rate > 15% or core services down
- **down** (503): Ecosystem not responding

### Key Metrics to Monitor
```json
{
  "active_servers": "Number of running MCP servers",
  "bridge_queue_size": "Pending requests in processing queue",
  "error_rate_percent": "Percentage of failed requests",
  "memory_usage_mb": "Total memory consumption",
  "average_processing_time_ms": "Mean request processing time"
}
```

### Alerting Thresholds
- **Warning**: Error rate > 5%, Queue size > 20, Memory > 500MB
- **Critical**: Error rate > 15%, Queue size > 50, Memory > 1GB
- **Emergency**: All servers down, No responses for 5+ minutes

## Common Operational Procedures

### Graceful Restart
```bash
# Standard restart (recommended for updates)
python mcp_ecosystem_manager.py restart

# Force restart (if graceful restart fails)
pkill -f "mcp_ecosystem_manager.py"
python mcp_ecosystem_manager.py start
```

### Configuration Updates
```bash
# 1. Update mcp_config.json with new settings
# 2. Validate configuration
python -c "import json; json.load(open('mcp_config.json'))"

# 3. Apply changes with graceful restart
python mcp_ecosystem_manager.py restart
```

### Log Management
```bash
# View real-time logs
tail -f mcp_ecosystem.log mcp_bridge.log mcp_manager.log

# Rotate logs (configure with logrotate)
mv mcp_ecosystem.log mcp_ecosystem.log.1
mv mcp_bridge.log mcp_bridge.log.1
mv mcp_manager.log mcp_manager.log.1

# Restart logging
python mcp_ecosystem_manager.py restart
```

### Resource Cleanup
```bash
# Clean old bridge files (>24 hours)
find mcp_bridge/requests -name "*.json" -mtime +1 -delete
find mcp_bridge/responses -name "*.json" -mtime +1 -delete

# Clean old metrics files (>7 days)
find metrics -name "*.json" -mtime +7 -delete

# Clean old log files (>30 days)
find . -name "*.log.*" -mtime +30 -delete
```

## Troubleshooting Guide

### Issue: Bridge Responses Not Generated
**Symptoms**: Requests in mcp_bridge/requests but no responses
**Diagnosis Steps**:
1. Check bridge processor status: `curl localhost:8080/health`
2. Verify gemini-orchestrator process: `ps aux | grep gemini`
3. Check API key: `echo $GOOGLE_API_KEY`
4. Review bridge logs: `tail -50 mcp_bridge.log`

**Resolution**:
```bash
# Restart bridge processor
python mcp_ecosystem_manager.py restart

# If API key issues
export GOOGLE_API_KEY="correct_key"
python mcp_ecosystem_manager.py restart

# If queue backlog
rm mcp_bridge/requests/*.json  # Clear pending requests
python mcp_ecosystem_manager.py restart
```

### Issue: High Memory Usage
**Symptoms**: Memory > 1GB, system performance degraded
**Diagnosis Steps**:
1. Check process memory: `python -c "import psutil; print(psutil.virtual_memory())"`
2. Identify heavy processes: `ps aux --sort=-%mem | head -10`
3. Check for memory leaks: `cat mcp_manager.log | grep "memory"`

**Resolution**:
```bash
# Restart specific high-memory processes
python mcp_ecosystem_manager.py restart

# If persistent, adjust configuration
# Edit mcp_config.json - reduce max_concurrent_requests
python mcp_ecosystem_manager.py restart
```

### Issue: Process Accumulation (Zombie Processes)
**Symptoms**: Multiple python processes, > 50 processes running
**Diagnosis Steps**:
1. List all python processes: `ps aux | grep python | wc -l`
2. Identify MCP processes: `ps aux | grep -E "(aseprite|gemini|mcp)"`
3. Check process creation times

**Resolution**:
```bash
# Emergency cleanup (use our previous script)
powershell -ExecutionPolicy Bypass -File production_process_cleanup.ps1

# Restart ecosystem
python mcp_ecosystem_manager.py start
```

### Issue: API Rate Limiting
**Symptoms**: "quota exceeded" or "rate limit" errors in logs
**Diagnosis Steps**:
1. Check error patterns: `grep -i "rate\|quota" mcp_bridge.log`
2. Review API usage: Check Gemini API console
3. Monitor request frequency: `cat metrics/*.json | jq '.total_requests'`

**Resolution**:
```bash
# Reduce concurrent requests
# Edit mcp_config.json:
"max_concurrent_requests": 5,
"processing_timeout_seconds": 60

# Restart with new limits
python mcp_ecosystem_manager.py restart
```

## Performance Optimization

### Resource Allocation Guidelines
- **Development**: 1GB RAM, 2 CPU cores, 5GB disk
- **Staging**: 2GB RAM, 4 CPU cores, 10GB disk  
- **Production**: 4GB RAM, 8 CPU cores, 20GB disk

### Scaling Configuration
```json
{
  "bridge": {
    "max_concurrent_requests": 20,
    "processing_timeout_seconds": 30,
    "cleanup_interval_hours": 12
  },
  "monitoring": {
    "metrics_interval": 300,
    "health_endpoint_port": 8080,
    "alert_memory_threshold_mb": 2048
  }
}
```

### Performance Tuning Checklist
- [ ] Optimize queue size for your request volume
- [ ] Adjust timeout values based on API response times
- [ ] Configure appropriate cleanup intervals
- [ ] Set memory thresholds based on available resources
- [ ] Enable metrics collection for monitoring

## Security Considerations

### API Key Management
```bash
# Store in secure environment variables
export GOOGLE_API_KEY="$(cat /secure/path/to/api-key)"

# Rotate keys regularly
# 1. Generate new key in Google Cloud Console
# 2. Update environment variable
# 3. Restart ecosystem
# 4. Revoke old key after verification
```

### Network Security
- Bind health endpoint to localhost only in production
- Use reverse proxy (nginx) for external access
- Implement authentication for admin endpoints
- Configure firewall rules for MCP server ports

### Data Protection
- Bridge request/response files contain sensitive data
- Ensure proper file permissions: `chmod 600 mcp_bridge/*/*`
- Implement log rotation with secure deletion
- Regular backup of configuration files

## Backup & Disaster Recovery

### Critical Data to Backup
1. **Configuration Files**: `mcp_config.json`, environment variables
2. **Memory Server Data**: Persistent storage from memory MCP
3. **Metrics History**: Recent performance data for analysis
4. **Log Files**: For forensic analysis and debugging

### Backup Procedure
```bash
#!/bin/bash
# Daily backup script
BACKUP_DIR="/backup/mcp-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Configuration and state
cp mcp_config.json "$BACKUP_DIR/"
cp -r mcp_bridge/responses "$BACKUP_DIR/"
cp -r metrics "$BACKUP_DIR/"

# Compress and store
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

# Cleanup old backups (>30 days)
find /backup -name "mcp-*.tar.gz" -mtime +30 -delete
```

### Disaster Recovery
1. **Complete System Failure**: Restore from backup, reinstall dependencies
2. **Partial Service Failure**: Restart affected components only
3. **Data Corruption**: Restore from latest backup, validate integrity
4. **API Key Compromise**: Immediately rotate keys, restart all services

## Automation & CI/CD Integration

### Health Check Integration
```bash
# Kubernetes liveness probe
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

# Docker health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```

### Automated Deployment
```yaml
# GitHub Actions example
name: Deploy MCP Ecosystem
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      
      - name: Install dependencies
        run: pip install -r requirements.txt
      
      - name: Run health check
        run: python mcp_ecosystem_manager.py status
      
      - name: Deploy
        run: |
          python mcp_ecosystem_manager.py stop
          python mcp_ecosystem_manager.py start
```

## Metrics & Analytics

### Key Performance Indicators
- **Availability**: Uptime percentage (target: 99.5%)
- **Latency**: Average response time (target: <2 seconds)
- **Throughput**: Requests per minute (baseline: establish from usage)
- **Error Rate**: Failed requests percentage (target: <1%)

### Metrics Collection
```bash
# Export metrics to monitoring system
curl localhost:8080/health | jq '.details' > /var/log/mcp-metrics.json

# Generate daily report
python -c "
import json, glob
files = glob.glob('metrics/*.json')
data = [json.load(open(f)) for f in files[-24:]]  # Last 24 hours
avg_memory = sum(d['memory_usage_mb'] for d in data) / len(data)
print(f'Average memory usage: {avg_memory:.1f}MB')
"
```

## Contact & Escalation

### Support Contacts
- **Primary**: System Administrator
- **Secondary**: Development Team Lead  
- **Emergency**: On-call Engineer (24/7)

### Escalation Criteria
- **Level 1**: Service degraded, error rate 5-15%
- **Level 2**: Service critical, error rate >15% or partial outage
- **Level 3**: Complete outage, data loss risk, security incident

### Communication Channels
- **Status Updates**: Internal chat (#mcp-status)
- **Incident Response**: Email + phone call
- **Post-Incident**: Written report with lessons learned

## Appendix: Emergency Procedures

### Complete System Recovery
```bash
# 1. Stop all processes
pkill -f mcp_ecosystem_manager
pkill -f python | grep -E "(gemini|mcp|bridge)"

# 2. Clean environment
rm -rf mcp_bridge/requests/*
rm -rf mcp_bridge/responses/*

# 3. Verify environment
python -c "import os; assert os.getenv('GOOGLE_API_KEY'), 'API key missing'"

# 4. Start fresh
python mcp_ecosystem_manager.py start --environment production

# 5. Validate
sleep 10
curl -f localhost:8080/health
```

### Data Recovery
```bash
# Restore from backup
tar -xzf /backup/mcp-YYYYMMDD.tar.gz
cp mcp-YYYYMMDD/mcp_config.json .
cp -r mcp-YYYYMMDD/metrics .

# Restart with restored configuration
python mcp_ecosystem_manager.py restart
```

This runbook should be reviewed quarterly and updated based on operational experience and system changes.
