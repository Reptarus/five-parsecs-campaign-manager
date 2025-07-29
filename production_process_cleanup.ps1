# Emergency Process Cleanup - Production Fix
# Target the specific aseprite-mcp processes that are causing resource contention

# Get all python processes and filter for aseprite-mcp
$aseprite_processes = Get-WmiObject Win32_Process | Where-Object { 
    $_.CommandLine -like "*aseprite-mcp*" -and $_.Name -eq "python.exe" 
}

Write-Host "Found $($aseprite_processes.Count) aseprite-mcp processes to terminate"

# Kill the resource hogs
foreach ($proc in $aseprite_processes) {
    Write-Host "Terminating PID $($proc.ProcessId): $($proc.CommandLine)"
    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
}

# Clean up old obsidian processes too
$obsidian_processes = Get-WmiObject Win32_Process | Where-Object { 
    $_.CommandLine -like "*obsidian_mcp_server.py*" -and $_.Name -eq "python.exe" 
}

foreach ($proc in $obsidian_processes) {
    Write-Host "Terminating PID $($proc.ProcessId): $($proc.CommandLine)"
    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
}

Write-Host "`nCleanup complete. Remaining Python processes:"
Get-Process python -ErrorAction SilentlyContinue | Select-Object Id, ProcessName, @{Name="Memory(MB)";Expression={[math]::Round($_.WorkingSet/1MB,2)}}
