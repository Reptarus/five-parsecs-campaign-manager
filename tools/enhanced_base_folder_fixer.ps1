#!/usr/bin/env pwsh

<#
.SYNOPSIS
Enhanced Base Folder Fixer for Five Parsecs Campaign Manager

.DESCRIPTION
Systematically fixes linter warnings in base folder files:
- Missing property declarations
- UNSAFE_METHOD_ACCESS patterns  
- Duplicate code removal
- Excessive @warning_ignore cleanup
- Type annotation improvements

.PARAMETER DryRun
Show what would be changed without making changes

.PARAMETER BackupFiles
Create .backup files before making changes (default: true)

.PARAMETER TargetPath
Path to the src/base directory (default: src/base)
#>

param(
    [switch]$DryRun = $false,
    [switch]$BackupFiles = $true,
    [string]$TargetPath = "src/base"
)

# Enhanced fix tracking
class FixResult {
    [string]$FilePath
    [string]$FixType
    [string]$Description
    [int]$LineNumber
    [string]$OriginalCode
    [string]$FixedCode
    [bool]$Success
}

# Global tracking
$global:FixResults = @()
$global:FixStats = @{
    'MissingDeclarations' = 0
    'UnsafeMethodAccess' = 0
    'DuplicateCode' = 0
    'WarningCleanup' = 0
    'TypeAnnotations' = 0
    'TotalFiles' = 0
    'TotalFixes' = 0
}

function Write-FixResult {
    param(
        [string]$FilePath,
        [string]$FixType,
        [string]$Description,
        [int]$LineNumber = 0,
        [string]$OriginalCode = "",
        [string]$FixedCode = "",
        [bool]$Success = $true
    )
    
    $result = [FixResult]::new()
    $result.FilePath = $FilePath
    $result.FixType = $FixType
    $result.Description = $Description
    $result.LineNumber = $LineNumber
    $result.OriginalCode = $OriginalCode
    $result.FixedCode = $FixedCode
    $result.Success = $Success
    
    $global:FixResults += $result
    $global:FixStats[$FixType]++
    $global:FixStats['TotalFixes']++
    
    if ($DryRun) {
        Write-Host "    [DRY RUN] $Description" -ForegroundColor Cyan
    } else {
        Write-Host "    [FIXED] $Description" -ForegroundColor Green
    }
}

function Fix-MissingPropertyDeclarations {
    param([string]$FilePath, [string[]]$Lines)
    
    $fixed = $false
    $newLines = @()
    
    # Fix BaseCrew.gd missing 'name' property
    if ($FilePath -like "*BaseCrew.gd") {
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            $line = $Lines[$i]
            
            # Add name property after other properties
            if ($line -match "var credits: int = 1000" -and -not ($Lines | Where-Object { $_ -match "var name: String" })) {
                $newLines += $line
                $newLines += "var name: String = """" # Crew name property"
                Write-FixResult -FilePath $FilePath -FixType "MissingDeclarations" -Description "Added missing 'name' property to BaseCrew" -LineNumber ($i + 1)
                $fixed = $true
            }
            # Fix references to use proper property name
            elseif ($line -match '"name": name' -and $line -notmatch 'node_name') {
                $fixedLine = $line -replace '"name": name', '"name": name'
                $newLines += $fixedLine
                if ($line -ne $fixedLine) {
                    Write-FixResult -FilePath $FilePath -FixType "MissingDeclarations" -Description "Fixed name property reference" -LineNumber ($i + 1) -OriginalCode $line -FixedCode $fixedLine
                    $fixed = $true
                }
            }
            else {
                $newLines += $line
            }
        }
    }
    # Fix BaseCombatManager.gd missing 'position' property in BaseCombatState
    elseif ($FilePath -like "*BaseCombatManager.gd") {
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            $line = $Lines[$i]
            
            # Add position property to BaseCombatState class
            if ($line -match "var node_position: Vector2i" -and -not ($Lines | Where-Object { $_ -match "var position: Vector2i" })) {
                $newLines += "    var position: Vector2i = Vector2i.ZERO # Battle position"
                $newLines += $line
                Write-FixResult -FilePath $FilePath -FixType "MissingDeclarations" -Description "Added missing 'position' property to BaseCombatState" -LineNumber ($i + 1)
                $fixed = $true
            }
            else {
                $newLines += $line
            }
        }
    }
    else {
        $newLines = $Lines
    }
    
    return @($newLines, $fixed)
}

function Fix-DuplicateCode {
    param([string]$FilePath, [string[]]$Lines)
    
    $fixed = $false
    $newLines = @()
    $seenLines = @{}
    
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i].Trim()
        $originalLine = $Lines[$i]
        
        # Check for duplicate status assignment in BaseCrewMember.gd
        if ($FilePath -like "*BaseCrewMember.gd" -and $line -match 'if data\.has\("status"\): status = data\.status') {
            if ($seenLines.ContainsKey($line)) {
                Write-FixResult -FilePath $FilePath -FixType "DuplicateCode" -Description "Removed duplicate status assignment line" -LineNumber ($i + 1) -OriginalCode $originalLine
                $fixed = $true
                continue # Skip this duplicate line
            } else {
                $seenLines[$line] = $i
            }
        }
        
        $newLines += $originalLine
    }
    
    return @($newLines, $fixed)
}

function Fix-UnsafeMethodAccess {
    param([string]$FilePath, [string[]]$Lines)
    
    $fixed = $false
    $newLines = @()
    
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        $originalLine = $line
        
        # Pattern 1: Direct .get() calls on potentially unsafe objects
        if ($line -match '(\w+)\.get\("([^"]+)"(?:,\s*([^)]+))?\)' -and $line -notmatch 'data\.get\(' -and $line -notmatch 'config\.get\(' -and $line -notmatch 'Dictionary\.get\(') {
            $objectName = $Matches[1]
            $propertyName = $Matches[2]
            $defaultValue = if ($Matches[3]) { $Matches[3] } else { "null" }
            
            # Add safe access pattern
            $safePattern = "if $objectName and $objectName.has(`"$propertyName`"): $objectName.get(`"$propertyName`", $defaultValue) else $defaultValue"
            $line = $line -replace [regex]::Escape($Matches[0]), $safePattern
            
            if ($originalLine -ne $line) {
                Write-FixResult -FilePath $FilePath -FixType "UnsafeMethodAccess" -Description "Added safe .get() access for $objectName.$propertyName" -LineNumber ($i + 1) -OriginalCode $originalLine -FixedCode $line
                $fixed = $true
            }
        }
        
        # Pattern 2: Resource.get() calls without validation
        if ($line -match 'character_data\.get\("([^"]+)"\)' -and $line -notmatch 'Variant') {
            $propertyName = $Matches[1]
            $line = $line -replace 'character_data\.get\("' + $propertyName + '"\)', "character_data.get(`"$propertyName`") if character_data else null"
            
            if ($originalLine -ne $line) {
                Write-FixResult -FilePath $FilePath -FixType "UnsafeMethodAccess" -Description "Added null check for character_data.get($propertyName)" -LineNumber ($i + 1) -OriginalCode $originalLine -FixedCode $line
                $fixed = $true
            }
        }
        
        $newLines += $line
    }
    
    return @($newLines, $fixed)
}

function Fix-ExcessiveWarningIgnores {
    param([string]$FilePath, [string[]]$Lines)
    
    $fixed = $false
    $newLines = @()
    $warningIgnoreCount = 0
    $removedIgnores = @()
    
    # Common warnings that can often be fixed instead of ignored
    $fixableWarnings = @(
        'untyped_declaration',
        'unsafe_method_access', 
        'unsafe_property_access',
        'unused_parameter',
        'return_value_discarded'
    )
    
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        
        if ($line -match '@warning_ignore\("([^"]+)"\)') {
            $warningType = $Matches[1]
            $warningIgnoreCount++
            
            # Remove specific fixable warnings - we'll fix them instead
            if ($warningType -in $fixableWarnings) {
                $removedIgnores += $warningType
                Write-FixResult -FilePath $FilePath -FixType "WarningCleanup" -Description "Removed @warning_ignore($warningType) - will fix instead" -LineNumber ($i + 1) -OriginalCode $line
                $fixed = $true
                continue # Skip this line
            }
        }
        
        $newLines += $line
    }
    
    if ($warningIgnoreCount -gt 10) {
        Write-FixResult -FilePath $FilePath -FixType "WarningCleanup" -Description "File has $warningIgnoreCount warning ignores, removed $($removedIgnores.Count) fixable ones"
    }
    
    return @($newLines, $fixed)
}

function Fix-TypeAnnotations {
    param([string]$FilePath, [string[]]$Lines)
    
    $fixed = $false
    $newLines = @()
    
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        $originalLine = $line
        
        # Pattern 1: Add type annotations for common variable patterns
        if ($line -match '^\s*var (\w+) = (\w+)\.get\(' -and $line -notmatch ':') {
            $varName = $Matches[1]
            # Add Variant type for .get() operations
            $line = $line -replace "var $varName =", "var ${varName}: Variant ="
            
            if ($originalLine -ne $line) {
                Write-FixResult -FilePath $FilePath -FixType "TypeAnnotations" -Description "Added Variant type annotation for $varName" -LineNumber ($i + 1) -OriginalCode $originalLine -FixedCode $line
                $fixed = $true
            }
        }
        
        # Pattern 2: Add type annotations for Dictionary operations
        if ($line -match '^\s*var (\w+) = \{\}' -and $line -notmatch ':') {
            $varName = $Matches[1]
            $line = $line -replace "var $varName =", "var ${varName}: Dictionary ="
            
            if ($originalLine -ne $line) {
                Write-FixResult -FilePath $FilePath -FixType "TypeAnnotations" -Description "Added Dictionary type annotation for $varName" -LineNumber ($i + 1) -OriginalCode $originalLine -FixedCode $line
                $fixed = $true
            }
        }
        
        # Pattern 3: Add type annotations for Array operations  
        if ($line -match '^\s*var (\w+) = \[\]' -and $line -notmatch ':') {
            $varName = $Matches[1]
            $line = $line -replace "var $varName =", "var ${varName}: Array ="
            
            if ($originalLine -ne $line) {
                Write-FixResult -FilePath $FilePath -FixType "TypeAnnotations" -Description "Added Array type annotation for $varName" -LineNumber ($i + 1) -OriginalCode $originalLine -FixedCode $line
                $fixed = $true
            }
        }
        
        $newLines += $line
    }
    
    return @($newLines, $fixed)
}

function Process-File {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found: $FilePath"
        return
    }
    
    Write-Host "Processing: $FilePath" -ForegroundColor Yellow
    $global:FixStats['TotalFiles']++
    
    try {
        $lines = Get-Content $FilePath -Encoding UTF8
        $originalLines = $lines
        $hasChanges = $false
        
        # Apply all fix phases
        $result = Fix-MissingPropertyDeclarations -FilePath $FilePath -Lines $lines
        $lines = $result[0]
        $hasChanges = $hasChanges -or $result[1]
        
        $result = Fix-DuplicateCode -FilePath $FilePath -Lines $lines  
        $lines = $result[0]
        $hasChanges = $hasChanges -or $result[1]
        
        $result = Fix-UnsafeMethodAccess -FilePath $FilePath -Lines $lines
        $lines = $result[0] 
        $hasChanges = $hasChanges -or $result[1]
        
        $result = Fix-TypeAnnotations -FilePath $FilePath -Lines $lines
        $lines = $result[0]
        $hasChanges = $hasChanges -or $result[1]
        
        $result = Fix-ExcessiveWarningIgnores -FilePath $FilePath -Lines $lines
        $lines = $result[0]
        $hasChanges = $hasChanges -or $result[1]
        
        # Write changes if any
        if ($hasChanges -and -not $DryRun) {
            if ($BackupFiles) {
                Copy-Item $FilePath "$FilePath.backup"
                Write-Host "    Created backup: $FilePath.backup" -ForegroundColor Blue
            }
            
            # Write fixed content
            $lines | Set-Content $FilePath -Encoding UTF8
            Write-Host "    Updated file: $FilePath" -ForegroundColor Green
        }
        elseif ($hasChanges -and $DryRun) {
            Write-Host "    [DRY RUN] Would update: $FilePath" -ForegroundColor Cyan
        }
        else {
            Write-Host "    No changes needed" -ForegroundColor Gray
        }
    }
    catch {
        Write-Error "Error processing $FilePath`: $_"
    }
}

function Show-Summary {
    Write-Host "`n" + "="*50 -ForegroundColor Magenta
    Write-Host "ENHANCED BASE FOLDER FIXER SUMMARY" -ForegroundColor Magenta  
    Write-Host "="*50 -ForegroundColor Magenta
    
    Write-Host "Files Processed: $($global:FixStats['TotalFiles'])" -ForegroundColor White
    Write-Host "Total Fixes Applied: $($global:FixStats['TotalFixes'])" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Fix Categories:" -ForegroundColor Yellow
    Write-Host "  Missing Declarations: $($global:FixStats['MissingDeclarations'])" -ForegroundColor Green
    Write-Host "  Unsafe Method Access: $($global:FixStats['UnsafeMethodAccess'])" -ForegroundColor Green  
    Write-Host "  Duplicate Code: $($global:FixStats['DuplicateCode'])" -ForegroundColor Green
    Write-Host "  Warning Cleanup: $($global:FixStats['WarningCleanup'])" -ForegroundColor Green
    Write-Host "  Type Annotations: $($global:FixStats['TypeAnnotations'])" -ForegroundColor Green
    
    if ($DryRun) {
        Write-Host "`nDRY RUN COMPLETE - No files were modified" -ForegroundColor Cyan
        Write-Host "Run without -DryRun to apply fixes" -ForegroundColor Cyan
    }
}

# Main execution
Write-Host "Enhanced Base Folder Fixer for Five Parsecs Campaign Manager" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE - No files will be modified" -ForegroundColor Cyan
    Write-Host ""
}

# Find all .gd files in the base directory
$baseFiles = Get-ChildItem -Path $TargetPath -Filter "*.gd" -Recurse | Where-Object { 
    $_.Name -notmatch "test" -and $_.Directory.Name -ne "tests" 
}

Write-Host "Found $($baseFiles.Count) base files to process" -ForegroundColor White
Write-Host ""

# Process each file
foreach ($file in $baseFiles) {
    Process-File -FilePath $file.FullName
}

Show-Summary

Write-Host "`nBase folder enhancement complete!" -ForegroundColor Green 