# PowerShell script to find and fix 'Self' constant conflicts in GDScript files
# This script looks for inherited classes that both define 'const Self =' which causes conflicts

# Function to extract the parent class path from a GDScript file
function Get-ParentClass {
    param (
        [string]$FilePath
    )
    
    $content = Get-Content $FilePath -Raw
    if ($content -match 'extends\s+"([^"]+)"') {
        return $matches[1]
    }
    elseif ($content -match 'extends\s+(\S+)') {
        return $matches[1]
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

# Main script
$scriptFiles = Get-ChildItem -Path "src" -Recurse -Include "*.gd"
$fixedFiles = @()

foreach ($file in $scriptFiles) {
    if (Has-SelfConstant -FilePath $file.FullName) {
        $parentClassPath = Get-ParentClass -FilePath $file.FullName
        
        if ($parentClassPath -and $parentClassPath -ne "Node" -and $parentClassPath -ne "Resource" -and $parentClassPath -ne "Control") {
            # Convert relative path to absolute path if needed
            if ($parentClassPath.StartsWith("res://")) {
                $absoluteParentPath = $parentClassPath -replace "res://", ""
                $absoluteParentPath = Join-Path $PSScriptRoot $absoluteParentPath
            } else {
                $absoluteParentPath = Join-Path (Split-Path $file.FullName -Parent) $parentClassPath
            }
            
            # Check if parent class exists and also defines Self
            if (Test-Path $absoluteParentPath) {
                if (Has-SelfConstant -FilePath $absoluteParentPath) {
                    Write-Host "Conflict detected: $($file.FullName) extends $parentClassPath"
                    Fix-SelfConstant -FilePath $file.FullName
                    $fixedFiles += $file.FullName
                }
            }
        }
    }
}

Write-Host "Fixed $($fixedFiles.Count) files with Self constant conflicts" 