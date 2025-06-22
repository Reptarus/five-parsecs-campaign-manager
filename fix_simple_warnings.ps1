# Simplified PowerShell Script to Fix Common Godot Linter Warnings
# Focuses on the most common and straightforward warning fixes

param(
    [switch]$DryRun,
    [switch]$Verbose
)

Write-Host "Five Parsecs Campaign Manager - Simple Warning Fix Script" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green

$FixCount = 0
$ProcessedFiles = 0

function Log-Fix {
    param($Message, $File = "")
    $script:FixCount++
    if ($Verbose -or -not $DryRun) {
        Write-Host "FIX $FixCount`: $Message" -ForegroundColor Yellow
        if ($File) {
            Write-Host "  File: $File" -ForegroundColor Gray
        }
    }
}

# Get all .gd files
$gdFiles = Get-ChildItem -Path "src" -Recurse -Filter "*.gd" -ErrorAction SilentlyContinue

if ($gdFiles.Count -eq 0) {
    Write-Host "No .gd files found in src directory" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($gdFiles.Count) .gd files to process" -ForegroundColor Cyan

# Phase 1: Fix unused variable warnings by prefixing with underscore
Write-Host "`nPhase 1: Fixing Unused Variables" -ForegroundColor Cyan

foreach ($file in $gdFiles) {
    $ProcessedFiles++
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    
    if ([string]::IsNullOrEmpty($content)) {
        continue
    }
    
    $originalContent = $content
    $lines = $content -split "`r?`n"
    $modified = $false
    
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        
        # Find variable declarations that might be unused
        if ($line -match '^\s*var\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*[:=]' -and $line -notmatch '^\s*var\s+_') {
            $varName = $matches[1]
            
            # Skip common variables that are likely used
            if ($varName -in @('data', 'result', 'config', 'settings', 'state', 'info', 'content', 'value', 'item', 'node')) {
                continue
            }
            
            # Quick check if variable appears used elsewhere (simple heuristic)
            $usageCount = 0
            for ($j = 0; $j -lt $lines.Length; $j++) {
                if ($j -ne $i -and $lines[$j] -match "\b$varName\b") {
                    $usageCount++
                }
            }
            
            # If appears to be unused (only appears once - the declaration), prefix with underscore
            if ($usageCount -eq 0) {
                $lines[$i] = $line -replace "var\s+$varName", "var _$varName"
                $modified = $true
                Log-Fix "Prefixed potentially unused variable: $varName -> _$varName" $file.Name
            }
        }
    }
    
    if ($modified -and -not $DryRun) {
        Set-Content $file.FullName ($lines -join "`n") -NoNewline
    }
}

# Phase 2: Fix obvious type annotation warnings
Write-Host "`nPhase 2: Adding Type Annotations" -ForegroundColor Cyan

foreach ($file in $gdFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    
    if ([string]::IsNullOrEmpty($content)) {
        continue
    }
    
    $originalContent = $content
    
    # Add type annotations for obvious cases
    $patterns = @{
        'var\s+(\w+)\s*=\s*true\b' = 'var $1: bool = true'
        'var\s+(\w+)\s*=\s*false\b' = 'var $1: bool = false'
        'var\s+(\w+)\s*=\s*"[^"]*"' = 'var $1: String = $0'
        'var\s+(\w+)\s*=\s*\[\]' = 'var $1: Array = []'
        'var\s+(\w+)\s*=\s*\{\}' = 'var $1: Dictionary = {}'
        'var\s+(\w+)\s*=\s*\d+(?!\.)' = 'var $1: int = $0'
        'var\s+(\w+)\s*=\s*\d+\.\d+' = 'var $1: float = $0'
    }
    
    foreach ($pattern in $patterns.Keys) {
        $replacement = $patterns[$pattern]
        if ($content -match $pattern) {
            $newContent = $content -replace $pattern, $replacement
            if ($newContent -ne $content) {
                $content = $newContent
                Log-Fix "Added type annotation for obvious type" $file.Name
            }
        }
    }
    
    if ($content -ne $originalContent -and -not $DryRun) {
        Set-Content $file.FullName $content -NoNewline
    }
}

# Phase 3: Fix common return value discarded warnings with comments
Write-Host "`nPhase 3: Adding Return Value Ignore Comments" -ForegroundColor Cyan

foreach ($file in $gdFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    
    if ([string]::IsNullOrEmpty($content)) {
        continue
    }
    
    $originalContent = $content
    $lines = $content -split "`r?`n"
    $modified = $false
    
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        
        # Find lines that are likely emitting signals or appending to arrays without using return value
        if ($line -match '^\s*\w+\.emit\(' -or $line -match '^\s*\w+\.append\(' -or $line -match '^\s*\w+\.connect\(') {
            # Add a comment on the line before if not already there
            if ($i -gt 0 -and $lines[$i-1] -notmatch '@warning_ignore' -and $lines[$i-1] -notmatch '#.*warning.*ignore') {
                $lines[$i] = $line.TrimEnd() + "  # warning: return value discarded (intentional)"
                $modified = $true
                Log-Fix "Added return value ignore comment" $file.Name
            }
        }
    }
    
    if ($modified -and -not $DryRun) {
        Set-Content $file.FullName ($lines -join "`n") -NoNewline
    }
}

# Phase 4: Fix missing return statements in functions with return types
Write-Host "`nPhase 4: Adding Missing Return Statements" -ForegroundColor Cyan

foreach ($file in $gdFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    
    if ([string]::IsNullOrEmpty($content)) {
        continue
    }
    
    $lines = $content -split "`r?`n"
    $modified = $false
    
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        
        # Find function declarations with return types
        if ($line -match 'func\s+\w+\([^)]*\)\s*->\s*(\w+)\s*:') {
            $returnType = $matches[1]
            
            # Look ahead to see if there's a return statement in the function
            $hasReturn = $false
            $j = $i + 1
            $functionEnd = $lines.Length - 1
            
            # Find the end of the function (next function or end of file)
            while ($j -lt $lines.Length) {
                if ($lines[$j] -match '^\s*func\s+' -or $lines[$j] -match '^class\s+') {
                    $functionEnd = $j - 1
                    break
                }
                if ($lines[$j] -match '\breturn\b') {
                    $hasReturn = $true
                    break
                }
                $j++
            }
            
            # If no return statement found, add a default one
            if (-not $hasReturn -and $functionEnd -gt $i) {
                $defaultReturn = switch ($returnType) {
                    "bool" { "`treturn false" }
                    "int" { "`treturn 0" }
                    "float" { "`treturn 0.0" }
                    "String" { "`treturn ''" }
                    "Array" { "`treturn []" }
                    "Dictionary" { "`treturn {}" }
                    default { "`treturn null" }
                }
                
                # Insert return statement before function end
                $lines = $lines[0..$functionEnd] + $defaultReturn + $lines[($functionEnd+1)..($lines.Length-1)]
                $modified = $true
                Log-Fix "Added missing return statement for $returnType function" $file.Name
            }
        }
    }
    
    if ($modified -and -not $DryRun) {
        Set-Content $file.FullName ($lines -join "`n") -NoNewline
    }
}

# Summary
Write-Host "`nSimple Warning Fix Summary" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host "Files processed: $ProcessedFiles" -ForegroundColor White
Write-Host "Total warning fixes applied: $FixCount" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "`nDRY RUN - No files were actually modified" -ForegroundColor Magenta
    Write-Host "Run without -DryRun to apply the warning fixes" -ForegroundColor Magenta
} else {
    Write-Host "`nAll warning fixes have been applied to the files" -ForegroundColor Green
}

Write-Host "`nWarning Categories Addressed:" -ForegroundColor Cyan
Write-Host "1. ✓ Unused variables (prefixed with _)" -ForegroundColor White
Write-Host "2. ✓ Untyped variables (added type annotations)" -ForegroundColor White
Write-Host "3. ✓ Return value discarded (added comments)" -ForegroundColor White
Write-Host "4. ✓ Missing return statements (added defaults)" -ForegroundColor White

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Open Godot editor to check for remaining warnings" -ForegroundColor White
Write-Host "2. Review the prefixed variables to ensure they're truly unused" -ForegroundColor White
Write-Host "3. Test your project to ensure nothing was broken" -ForegroundColor White 