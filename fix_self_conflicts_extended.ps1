# PowerShell script to find and fix 'Self' constant conflicts in GDScript files
# This script looks for inherited classes that both define 'const Self =' which causes conflicts
# Extended version that also checks global class names and aliases

# Function to extract the parent class path from a GDScript file
function Get-ParentClass {
    param (
        [string]$FilePath
    )
    
    $content = Get-Content $FilePath -Raw
    if ($content -match 'extends\s+"([^"]+)"') {
        return @{
            Type = "Path"
            Value = $matches[1]
        }
    }
    elseif ($content -match 'extends\s+(\S+)') {
        # Check if it's not a built-in class
        $className = $matches[1]
        if ($className -notmatch '^(Node|Control|Resource|Area|Camera|Button|LineEdit|Label|Panel|RichTextLabel|ScrollContainer|TextEdit|TextureRect|Sprite|AnimatedSprite|CollisionShape|KinematicBody|StaticBody|HTTPRequest|Timer)$') {
            return @{
                Type = "ClassName"
                Value = $className
            }
        }
    }
    
    return $null
}

# Function to check if a file defines 'const Self ='
function Has-SelfConstant {
    param (
        [string]$FilePath
    )
    
    $content = Get-Content $FilePath -Raw
    return $content -match 'const\s+Self\s+=\s+preload\('
}

# Function to rename Self constant to ThisClass
function Fix-SelfConstant {
    param (
        [string]$FilePath
    )
    
    $content = Get-Content $FilePath -Raw
    $newContent = $content -replace 'const\s+Self\s+=\s+preload\(', 'const ThisClass = preload('
    
    # Also replace any usages of Self. with ThisClass.
    $newContent = $newContent -replace '(?<!\w)Self\.', 'ThisClass.'
    
    Set-Content -Path $FilePath -Value $newContent
    Write-Host "Fixed: $FilePath"
}

# Function to find class path from global class name
function Find-ClassPath {
    param (
        [string]$ClassName
    )
    
    # Search for class_name declarations
    $matches = Get-ChildItem -Path "src" -Recurse -Include "*.gd" | 
               Select-String -Pattern "class_name\s+$ClassName"
    
    if ($matches.Count -gt 0) {
        return $matches[0].Path
    }
    
    # Search for aliases/constants like FPCM_ClassName = preload(...)
    $aliasMatches = Get-ChildItem -Path "src" -Recurse -Include "*.gd" | 
                    Select-String -Pattern "const\s+$ClassName\s+=\s+preload\("
    
    if ($aliasMatches.Count -gt 0) {
        $aliasFile = $aliasMatches[0].Path
        $aliasLine = $aliasMatches[0].Line
        if ($aliasLine -match 'preload\("([^"]+)"\)') {
            $pathFromRes = $matches[1] -replace "res://", ""
            return Join-Path $PSScriptRoot $pathFromRes
        }
    }
    
    return $null
}

# Main script
$scriptFiles = Get-ChildItem -Path "src" -Recurse -Include "*.gd"
$fixedFiles = @()
$logFile = "self_conflicts_log.txt"

"Self Constant Conflicts Report" | Out-File -FilePath $logFile
"================================" | Out-File -FilePath $logFile -Append
"" | Out-File -FilePath $logFile -Append

foreach ($file in $scriptFiles) {
    if (Has-SelfConstant -FilePath $file.FullName) {
        $parentClassInfo = Get-ParentClass -FilePath $file.FullName
        
        if ($parentClassInfo) {
            $absoluteParentPath = $null
            
            if ($parentClassInfo.Type -eq "Path") {
                # Handle path-based extends
                $parentClassPath = $parentClassInfo.Value
                if ($parentClassPath.StartsWith("res://")) {
                    $absoluteParentPath = $parentClassPath -replace "res://", ""
                    $absoluteParentPath = Join-Path $PSScriptRoot $absoluteParentPath
                } else {
                    $absoluteParentPath = Join-Path (Split-Path $file.FullName -Parent) $parentClassPath
                }
            } elseif ($parentClassInfo.Type -eq "ClassName") {
                # Handle class name-based extends
                $className = $parentClassInfo.Value
                $absoluteParentPath = Find-ClassPath -ClassName $className
                
                if ($absoluteParentPath) {
                    "Found class path for {0}: {1}" -f $className, $absoluteParentPath | Out-File -FilePath $logFile -Append
                } else {
                    "Could not find class path for {0}" -f $className | Out-File -FilePath $logFile -Append
                }
            }
            
            # Check if parent class exists and also defines Self
            if ($absoluteParentPath -and (Test-Path $absoluteParentPath)) {
                if (Has-SelfConstant -FilePath $absoluteParentPath) {
                    $conflictMessage = "Conflict detected: {0} extends {1}" -f $file.FullName, $parentClassInfo.Value
                    Write-Host $conflictMessage
                    $conflictMessage | Out-File -FilePath $logFile -Append
                    
                    Fix-SelfConstant -FilePath $file.FullName
                    $fixedFiles += $file.FullName
                }
            }
        }
    }
}

$summary = "Fixed {0} files with Self constant conflicts" -f $fixedFiles.Count
Write-Host $summary
$summary | Out-File -FilePath $logFile -Append
"" | Out-File -FilePath $logFile -Append
"Fixed Files:" | Out-File -FilePath $logFile -Append
$fixedFiles | ForEach-Object { $_ | Out-File -FilePath $logFile -Append } 