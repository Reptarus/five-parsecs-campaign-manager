@echo off
echo ========================================
echo Five Parsecs Campaign Manager
echo Simple Warning Fixer
echo ========================================
echo.

echo This script will fix the most critical warnings:
echo 1. Signal modernization (emit_signal to .emit)
echo 2. Basic type annotations
echo 3. Unterminated string fixes
echo.

echo Press any key to continue or Ctrl+C to cancel...
pause >nul

echo.
echo Starting fixes...
echo.

REM Use PowerShell for reliable text processing
powershell -Command "& {
    Write-Host 'Processing .gd files...'
    $files = Get-ChildItem -Path '..\src', '..\tests' -Filter '*.gd' -Recurse
    $totalFiles = $files.Count
    $processedFiles = 0
    $totalFixes = 0
    
    Write-Host \"Found $totalFiles .gd files\"
    
    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw
        $originalContent = $content
        $fileFixes = 0
        
        # Fix 1: Signal modernization - emit_signal('name') to name.emit()
        $pattern1 = 'emit_signal\(\"([^\"]+)\"\)'
        if ($content -match $pattern1) {
            $content = $content -replace 'emit_signal\(\"([^\"]+)\"\)', '$1.emit()'
            $fileFixes++
        }
        
        # Fix 2: Signal modernization with args - emit_signal('name', args) to name.emit(args)
        $pattern2 = 'emit_signal\(\"([^\"]+)\",\s*([^)]+)\)'
        if ($content -match $pattern2) {
            $content = $content -replace 'emit_signal\(\"([^\"]+)\",\s*([^)]+)\)', '$1.emit($2)'
            $fileFixes++
        }
        
        # Fix 3: Basic type annotations - var name: to var name: Dictionary
        $pattern3 = '^(\s*var\s+\w+)\s*:\s*$'
        if ($content -match $pattern3) {
            $content = $content -replace '^(\s*var\s+\w+)\s*:\s*$', '$1: Variant'
            $fileFixes++
        }
        
        # Fix 4: Remove redundant warning comments
        $pattern4 = '\s*#\s*warning:\s*return\s*value\s*discarded\s*\(intentional\)'
        if ($content -match $pattern4) {
            $content = $content -replace '\s*#\s*warning:\s*return\s*value\s*discarded\s*\(intentional\)', ''
            $fileFixes++
        }
        
        # Write back if changed
        if ($content -ne $originalContent) {
            Set-Content -Path $file.FullName -Value $content -NoNewline
            $processedFiles++
            $totalFixes += $fileFixes
            Write-Host \"Fixed: $($file.Name) ($fileFixes fixes)\"
        }
    }
    
    Write-Host \"\"
    Write-Host \"========================================\"
    Write-Host \"SUMMARY\"
    Write-Host \"========================================\"
    Write-Host \"Total files scanned: $totalFiles\"
    Write-Host \"Files modified: $processedFiles\"
    Write-Host \"Total fixes applied: $totalFixes\"
    Write-Host \"\"
    Write-Host \"Next steps:\"
    Write-Host \"1. Open Godot and check for compilation errors\"
    Write-Host \"2. Test your project functionality\"
    Write-Host \"3. Run this script again if more fixes are needed\"
}"

echo.
echo ========================================
echo Script completed!
echo ========================================
echo.
echo Press any key to exit...
pause >nul 