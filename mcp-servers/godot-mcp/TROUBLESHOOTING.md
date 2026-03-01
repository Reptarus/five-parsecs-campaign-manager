# Godot MCP Server - Troubleshooting Guide

## ES Module Compatibility Fix (2025-11-14)

### Issue
The server was failing to start with the error:
```
ReferenceError: require is not defined in ES module scope
```

### Root Cause
The `production-wrapper.js` file was using CommonJS syntax (`require()`) while `package.json` declared `"type": "module"`, forcing Node.js to treat all `.js` files as ES modules.

### Solution
Converted `production-wrapper.js` to use ES module syntax:
- Changed `const { spawn } = require('child_process');` → `import { spawn } from 'child_process';`
- Changed `const path = require('path');` → `import path from 'path';`
- Changed `require('./build/index.js');` → `import('./build/index.js');`

### Verification
After the fix, the server starts successfully:
```bash
cd C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\mcp-servers\godot-mcp
node production-wrapper.js
# Should output: "Godot MCP server running on stdio"
```

## Common Issues

### Godot Path Warnings
If you see warnings like:
```
[SERVER] Could not find Godot in common locations for win32
```

**Solution:** Ensure the `GODOT_PATH` environment variable is set in `claude_desktop_config.json`:
```json
"env": {
  "GODOT_PATH": "C:\\Users\\elija\\Desktop\\GoDot\\Godot 4.4\\Godot_v4.4.1-stable_win64_console.exe"
}
```

### Server Not Connecting
1. Check Claude Desktop logs at: `C:\Users\elija\AppData\Roaming\Claude\logs\mcp-server-godot.log`
2. Restart Claude Desktop to reconnect all MCP servers
3. Verify Node.js is installed: `node --version` (should be v22.16.0 or higher)

### Module Not Found Errors
Ensure dependencies are installed:
```bash
cd C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\mcp-servers\godot-mcp
npm install
```

## Contact
For issues, check the main project documentation or MCP debugging guide:
https://modelcontextprotocol.io/docs/tools/debugging
