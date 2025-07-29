# MCP Ecosystem Production Deployment Guide

## 🚀 Quick Start (5 Minutes)

### Step 1: Validate Environment
```bash
# Run validation
python simple_validate.py

# Should show only 1 issue: Missing GOOGLE_API_KEY
```

### Step 2: Set API Key
```bash
# Windows (PowerShell) - Session only
$env:GOOGLE_API_KEY = "your_api_key_here"

# Windows (PowerShell) - Permanent
[Environment]::SetEnvironmentVariable("GOOGLE_API_KEY", "your_api_key_here", "User")

# Verify
echo $env:GOOGLE_API_KEY
```

### Step 3: Start the Ecosystem
```bash
# Start all MCP servers and bridge processor
python mcp_ecosystem_manager.py start

# Check status
python mcp_ecosystem_manager.py status
```

### Step 4: Configure Claude Desktop
1. Copy `claude_desktop_config.json` to Claude's config directory
2. Restart Claude Desktop
3. Verify connections with: `Add MCP server from file`

## ✅ Success Verification

### Health Check
```bash
# Quick health check
curl http://localhost:8080/health

# Expected response:
{
  "status": "healthy",
  "details": {
    "active_servers": 3,
    "total_servers": 3,
    "bridge_queue_size": 0,
    "error_rate_percent": 0.0
  }
}
```

### Bridge Test
```bash
# Create test request
echo '{
  "request_id": "test_123",
  "tool_name": "gemini_quick_query", 
  "arguments": {"query": "What is 2+2?"}
}' > mcp_bridge/requests/test_123.json

# Check for response (should appear within 5 seconds)
ls mcp_bridge/responses/test_123.json
```

## 🔄 Cross-Platform Workflow Examples

### Example 1: Gemini CLI → Claude Desktop Handoff

**In Gemini CLI:**
```bash
# Create analysis request
echo '{
  "request_id": "analysis_001",
  "tool_name": "gemini_analyze_code", 
  "arguments": {
    "code_content": "def hello():\n    print(\"world\")",
    "analysis_type": "comprehensive"
  },
  "client_id": "gemini_cli"
}' > mcp_bridge/requests/analysis_001.json

# Wait for response
cat mcp_bridge/responses/analysis_001.json
```

**In Claude Desktop:**
- Access response via Memory MCP
- Continue analysis using Filesystem MCP
- Leverage full context for iterative development

### Example 2: Godot → Gemini → Claude Workflow

**In Godot (via MCP):**
1. Export scene structure via Godot MCP
2. Create optimization request via bridge
3. Receive AI-generated improvements

**Bridge Request:**
```json
{
  "request_id": "godot_optimization",
  "tool_name": "gemini_analyze_code",
  "arguments": {
    "code_content": "[exported_gdscript]",
    "analysis_type": "performance"
  },
  "metadata": {
    "source": "godot_engine", 
    "scene": "MainGameplay.tscn"
  }
}
```

### Example 3: Cursor WSL Integration

**WSL Configuration:**
```json
{
  "mcp.servers": {
    "gemini-bridge": {
      "command": "python3",
      "args": ["/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/mcp_bridge_client.py"],
      "env": {
        "BRIDGE_ENDPOINT": "http://localhost:8080"
      }
    }
  }
}
```

## 🛠️ Advanced Configuration

### High-Performance Settings
```json
{
  "bridge": {
    "max_concurrent_requests": 20,
    "processing_timeout_seconds": 45,
    "cleanup_interval_hours": 6
  },
  "monitoring": {
    "metrics_interval": 60,
    "alert_memory_threshold_mb": 1024
  }
}
```

### Development Environment
```json
{
  "bridge": {
    "max_concurrent_requests": 5,
    "processing_timeout_seconds": 15
  },
  "monitoring": {
    "log_level": "DEBUG",
    "metrics_enabled": true
  }
}
```

## 🔧 Troubleshooting Common Issues

### Issue: Bridge Not Responding
**Symptoms:** Requests created but no responses
**Solution:**
```bash
# Check process status
python mcp_ecosystem_manager.py status

# Restart if needed
python mcp_ecosystem_manager.py restart

# Check logs
tail -f mcp_bridge.log
```

### Issue: Memory Usage High
**Symptoms:** System slow, memory warnings
**Solution:**
```bash
# Check current usage
python -c "import psutil; print(f'Memory: {psutil.virtual_memory().percent:.1f}%')"

# Clean up old files
find mcp_bridge -name "*.json" -mtime +1 -delete

# Restart with reduced concurrency
# Edit mcp_config.json: "max_concurrent_requests": 5
python mcp_ecosystem_manager.py restart
```

### Issue: API Rate Limits
**Symptoms:** "quota exceeded" errors
**Solution:**
```bash
# Reduce request rate
# Edit mcp_config.json:
{
  "bridge": {
    "max_concurrent_requests": 3,
    "processing_timeout_seconds": 60
  }
}

# Add request delays
# Add "delay_between_requests_ms": 1000
```

## 📊 Monitoring & Metrics

### Real-time Monitoring
```bash
# Watch health status
watch -n 5 "curl -s localhost:8080/health | jq '.'"

# Monitor queue size
watch -n 2 "ls mcp_bridge/requests | wc -l"

# Track error rate
tail -f mcp_bridge.log | grep -i error
```

### Performance Metrics
```bash
# Average processing time
python -c "
import json, glob
files = glob.glob('metrics/*.json')
if files:
    data = [json.load(open(f)) for f in files[-10:]]
    avg_time = sum(d.get('avg_processing_time_ms', 0) for d in data) / len(data)
    print(f'Average processing time: {avg_time:.1f}ms')
"
```

## 🔐 Security & Best Practices

### API Key Security
```bash
# Store in secure file
echo "your_api_key" > /secure/path/api_key.txt
chmod 600 /secure/path/api_key.txt

# Use in startup script
export GOOGLE_API_KEY=$(cat /secure/path/api_key.txt)
python mcp_ecosystem_manager.py start
```

### Network Security
```bash
# Bind health endpoint to localhost only
# Edit mcp_config.json:
{
  "monitoring": {
    "health_endpoint_host": "127.0.0.1",
    "health_endpoint_port": 8080
  }
}
```

### File Permissions
```bash
# Secure bridge directories
chmod 700 mcp_bridge/
chmod 600 mcp_bridge/*/*.json
```

## 📦 Backup & Recovery

### Daily Backup Script
```bash
#!/bin/bash
# backup_mcp.sh
DATE=$(date +%Y%m%d)
BACKUP_DIR="/backup/mcp_$DATE"

mkdir -p "$BACKUP_DIR"
cp mcp_config.json "$BACKUP_DIR/"
cp claude_desktop_config.json "$BACKUP_DIR/"
cp -r metrics "$BACKUP_DIR/"
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

# Cleanup old backups
find /backup -name "mcp_*.tar.gz" -mtime +7 -delete
```

### Recovery Procedure
```bash
# 1. Stop ecosystem
python mcp_ecosystem_manager.py stop

# 2. Restore from backup
tar -xzf /backup/mcp_YYYYMMDD.tar.gz
cp mcp_YYYYMMDD/* .

# 3. Restart
python mcp_ecosystem_manager.py start

# 4. Verify
python mcp_ecosystem_manager.py status
```

## 🚢 Production Deployment

### Systemd Service (Linux)
```ini
[Unit]
Description=MCP Ecosystem Manager
After=network.target

[Service]
Type=simple
User=mcp-user
WorkingDirectory=/opt/mcp-ecosystem
Environment=GOOGLE_API_KEY=your_key_here
ExecStart=/usr/bin/python3 mcp_ecosystem_manager.py start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Docker Deployment
```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY . .
RUN pip install psutil aiofiles watchdog requests

ENV GOOGLE_API_KEY=""
EXPOSE 8080

CMD ["python", "mcp_ecosystem_manager.py", "start"]
```

### Windows Service
```powershell
# Install NSSM (Non-Sucking Service Manager)
# Create service
nssm install "MCPEcosystem" "python" "C:\path\to\mcp_ecosystem_manager.py start"
nssm set "MCPEcosystem" AppDirectory "C:\path\to\project"
nssm set "MCPEcosystem" AppEnvironmentExtra "GOOGLE_API_KEY=your_key_here"
nssm start "MCPEcosystem"
```

## 📈 Scaling Guidelines

### Resource Requirements
- **Development**: 1GB RAM, 2 CPU cores
- **Staging**: 2GB RAM, 4 CPU cores  
- **Production**: 4GB RAM, 8 CPU cores
- **High Load**: 8GB RAM, 16 CPU cores

### Horizontal Scaling
```bash
# Run multiple bridge processors
python mcp_bridge_processor.py --instance-id=bridge-1 &
python mcp_bridge_processor.py --instance-id=bridge-2 &

# Load balance health endpoints
# Use nginx or similar to distribute requests
```

This deployment guide provides everything needed to run your MCP ecosystem in production with confidence!
