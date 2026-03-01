@echo off
echo Fixing Godot MCP Server...

cd /d "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\mcp-servers\godot-mcp"

echo.
echo Step 1: Ensuring dependencies are installed...
call npm install

echo.
echo Step 2: Building server...
call npm run build

echo.
echo Step 3: Testing production mode...
set NODE_ENV=production
set DEBUG=false
set GODOT_PATH=C:\Users\elija\Desktop\GoDot\Godot 4.4\Godot_v4.4.1-stable_win64_console.exe

echo.
echo Server should now run without debug output.
echo Close this window and restart Claude Desktop.
pause
