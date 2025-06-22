# PowerShell Script to Fix Five Parsecs Campaign Manager Linter Errors
# Run this from the project root directory

param(
    [switch]$DryRun,
    [switch]$Verbose
)

Write-Host "Five Parsecs Campaign Manager - Linter Error Fix Script" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green

$ErrorCount = 0
$FixCount = 0

# Function to log fixes
function Log-Fix {
    param($Message, $File = "")
    $script:FixCount++
    if ($Verbose) {
        Write-Host "FIX $FixCount`: $Message" -ForegroundColor Yellow
        if ($File) {
            Write-Host "  File: $File" -ForegroundColor Gray
        }
    }
}

# Function to safely modify files
function Fix-File {
    param($FilePath, $SearchPattern, $ReplacePattern, $Description)
    
    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath -Raw
        if ($content -match $SearchPattern) {
            if (-not $DryRun) {
                $content = $content -replace $SearchPattern, $ReplacePattern
                Set-Content $FilePath $content -NoNewline
            }
            Log-Fix $Description $FilePath
            return $true
        }
    }
    return $false
}

Write-Host "Phase 1: Fixing Unterminated Strings" -ForegroundColor Cyan

# Fix unterminated string literals (missing closing quotes)
$gdFiles = Get-ChildItem -Path "src" -Recurse -Filter "*.gd"

foreach ($file in $gdFiles) {
    $content = Get-Content $file.FullName -Raw
    $modified = $false
    
    # Fix unterminated node path strings
    $pattern = '(\$"[^"]*?)(\s*$)'
    if ($content -match $pattern) {
        $content = $content -replace '(\$"[^"]*?)(\s*$)', '$1"$2'
        $modified = $true
        Log-Fix "Fixed unterminated node path string" $file.FullName
    }
    
    # Fix unterminated regular strings
    $pattern = '(?<!#)("[^"]*?)(\s*$)'
    if ($content -match $pattern) {
        $content = $content -replace '(?<!#)("[^"]*?)(\s*$)', '$1"$2'
        $modified = $true
        Log-Fix "Fixed unterminated string literal" $file.FullName
    }
    
    if ($modified -and -not $DryRun) {
        Set-Content $file.FullName $content -NoNewline
    }
}

Write-Host "Phase 2: Cleaning Corrupted @warning_ignore Annotations" -ForegroundColor Cyan

foreach ($file in $gdFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Remove orphaned @warning_ignore annotations
    $content = $content -replace '^\s*@warning_ignore\([^)]*\)\s*$\r?\n', ''
    
    # Remove @warning_ignore from middle of arrays/dictionaries  
    $content = $content -replace ',\s*@warning_ignore\([^)]*\)\s*,', ','
    $content = $content -replace '\[\s*@warning_ignore\([^)]*\)\s*', '['
    $content = $content -replace ',\s*@warning_ignore\([^)]*\)\s*\]', ']'
    
    # Remove @warning_ignore from control flow
    $content = $content -replace '(if|while|for|return)\s+@warning_ignore\([^)]*\)\s+', '$1 '
    
    if ($content -ne $originalContent) {
        if (-not $DryRun) {
            Set-Content $file.FullName $content -NoNewline
        }
        Log-Fix "Cleaned corrupted @warning_ignore annotations" $file.FullName
    }
}

Write-Host "Phase 3: Fixing Parameter Naming Mismatches" -ForegroundColor Cyan

foreach ($file in $gdFiles) {
    $content = Get-Content $file.FullName -Raw
    $lines = $content -split "`r?`n"
    $modified = $false
    
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        
        # Find function declarations with _parameter names
        if ($line -match 'func\s+\w+\([^)]*(_\w+)[^)]*\)\s*:') {
            $paramMatch = [regex]::Match($line, '_(\w+)')
            if ($paramMatch.Success) {
                $paramName = $paramMatch.Groups[1].Value
                $underscoreParam = "_$paramName"
                
                # Look for usage of the parameter without underscore in the function body
                $j = $i + 1
                $indentLevel = ($line -replace '^(\t*|\s*).*', '$1').Length
                
                while ($j -lt $lines.Length) {
                    $currentLine = $lines[$j]
                    $currentIndent = ($currentLine -replace '^(\t*|\s*).*', '$1').Length
                    
                    # Stop if we're back to same or less indentation (end of function)
                    if ($currentLine.Trim() -ne "" -and $currentIndent -le $indentLevel) {
                        break
                    }
                    
                    # Replace parameter usage
                    if ($currentLine -match "\b$paramName\b" -and $currentLine -notmatch "\b$underscoreParam\b") {
                        $lines[$j] = $currentLine -replace "\b$paramName\b", $underscoreParam
                        $modified = $true
                        Log-Fix "Fixed parameter naming mismatch: $paramName -> $underscoreParam" $file.FullName
                    }
                    
                    $j++
                }
            }
        }
    }
    
    if ($modified -and -not $DryRun) {
        Set-Content $file.FullName ($lines -join "`n") -NoNewline
    }
}

Write-Host "Phase 4: Fixing Missing Function Parentheses" -ForegroundColor Cyan

foreach ($file in $gdFiles) {
    # Fix missing closing parentheses in function declarations
    Fix-File $file.FullName 'func\s+(\w+)\([^)]*->' 'func $1($2) ->' "Fixed missing parenthesis in function declaration"
    
    # Fix incomplete function calls
    Fix-File $file.FullName '(\w+)\(\s*$' '$1()' "Fixed incomplete function call"
}

Write-Host "Phase 5: Fixing Multi-line Expression Errors" -ForegroundColor Cyan

foreach ($file in $gdFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Fix return statements split across lines with annotations
    $content = $content -replace 'return\s*\r?\n\s*@warning_ignore\([^)]*\)\s*', 'return '
    
    # Fix expressions split with annotations in the middle
    $content = $content -replace '(\w+)\s*\r?\n\s*@warning_ignore\([^)]*\)\s*([.(\[])', '$1$2'
    
    if ($content -ne $originalContent) {
        if (-not $DryRun) {
            Set-Content $file.FullName $content -NoNewline
        }
        Log-Fix "Fixed multi-line expression with misplaced annotations" $file.FullName
    }
}

Write-Host "Phase 6: Creating Missing Core Dependencies" -ForegroundColor Cyan

# Define missing core files that need to be created
$missingFiles = @{
    "src/core/systems/TableLoader.gd" = @"
@tool
extends RefCounted
class_name TableLoader

## Table loading system for Five Parsecs
## Simple implementation for loading game tables

static func load_tables_from_directory(directory_path: String) -> Dictionary:
	var tables: Dictionary = {}
	var dir = DirAccess.open(directory_path)
	
	if dir == null:
		push_warning("Cannot access directory: " + directory_path)
		return tables
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var table_data = load_table_file(directory_path + "/" + file_name)
			if not table_data.is_empty():
				tables[file_name.get_basename()] = table_data
		file_name = dir.get_next()
	
	return tables

static func load_table_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("Cannot open file: " + file_path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_warning("Cannot parse JSON file: " + file_path)
		return {}
	
	return json.get_data()
"@

    "src/core/systems/PositionValidator.gd" = @"
@tool
extends RefCounted
class_name PositionValidator

## Position validation system for Five Parsecs battlefields
## Validates positions for various battlefield elements

func get_valid_cover_point(existing_positions: Array) -> Vector2:
	# Simple implementation - return a random valid position
	var max_attempts = 50
	for i in range(max_attempts):
		var pos = Vector2(randf_range(0, 50), randf_range(0, 50))
		var valid = true
		
		for existing in existing_positions:
			if existing.has("position") and existing.position.distance_to(pos) < 5.0:
				valid = false
				break
		
		if valid:
			return pos
	
	return Vector2.ZERO

func get_valid_hazard_point(existing_positions: Array) -> Vector2:
	# Simple implementation - return a random valid position
	var max_attempts = 50
	for i in range(max_attempts):
		var pos = Vector2(randf_range(0, 50), randf_range(0, 50))
		var valid = true
		
		for existing in existing_positions:
			if existing.has("position") and existing.position.distance_to(pos) < 3.0:
				valid = false
				break
		
		if valid:
			return pos
	
	return Vector2.ZERO

func get_valid_strategic_point(existing_positions: Array) -> Vector2:
	# Simple implementation - return a random valid position
	var max_attempts = 50
	for i in range(max_attempts):
		var pos = Vector2(randf_range(0, 50), randf_range(0, 50))
		var valid = true
		
		for existing in existing_positions:
			if existing.has("position") and existing.position.distance_to(pos) < 8.0:
				valid = false
				break
		
		if valid:
			return pos
	
	return Vector2.ZERO
"@
}

foreach ($file in $missingFiles.Keys) {
    $directory = Split-Path $file -Parent
    if (-not (Test-Path $directory)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        Log-Fix "Created missing directory" $directory
    }
    
    if (-not (Test-Path $file)) {
        if (-not $DryRun) {
            Set-Content $file $missingFiles[$file] -NoNewline
        }
        Log-Fix "Created missing core dependency file" $file
    }
}

# Summary
Write-Host "`nLinter Error Fix Summary" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green
Write-Host "Total fixes applied: $FixCount" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "DRY RUN - No files were actually modified" -ForegroundColor Magenta
    Write-Host "Run without -DryRun to apply fixes" -ForegroundColor Magenta
} else {
    Write-Host "All fixes have been applied to the files" -ForegroundColor Green
}

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Check Godot editor for any remaining errors" -ForegroundColor White
Write-Host "2. Test the project to ensure everything still works" -ForegroundColor White
Write-Host "3. Commit the changes to version control" -ForegroundColor White 