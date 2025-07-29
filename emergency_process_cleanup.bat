@echo off
echo === Emergency MCP Process Cleanup ===
echo.

REM Kill all aseprite-mcp processes (the major resource hog)
echo Terminating aseprite-mcp processes...
taskkill /F /IM python.exe /FI "COMMANDLINE eq *aseprite-mcp*"

REM Kill stale obsidian MCP processes  
echo Terminating obsidian-mcp processes...
taskkill /F /IM python.exe /FI "COMMANDLINE eq *obsidian_mcp_server.py*"

REM Keep current working processes:
REM - gemini_mcp_server.py (PID 45296)
REM - windows-mcp extensions 
REM - blender-mcp extensions

echo.
echo Cleanup complete. Checking remaining Python processes...
tasklist /FI "IMAGENAME eq python.exe" /FO TABLE

echo.
echo === Manual verification ===
echo Check that these critical processes are still running:
echo - gemini_mcp_server.py (PID 45296)
echo - windows-mcp extensions (4 processes)
echo - blender-mcp (2 processes)
