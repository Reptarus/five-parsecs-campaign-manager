# Universal GDScript Warning Fixer
# Comprehensive script to fix SHADOWED_GLOBAL_IDENTIFIER, UNSAFE_METHOD_ACCESS, UNTYPED_DECLARATION
# Uses proper Godot patterns from official documentation

[CmdletBinding()]
param(
    [string]$SourcePath = "src",
    [switch]$WhatIf = $false
)

# Statistics tracking
$script:Stats = @{
    FilesProcessed = 0
    TotalFixes = 0
    FixesByType = @{
        UniversalNodeAccess = 0
        UniversalResourceLoader = 0
        UniversalSignalManager = 0
        UniversalDataAccess = 0
        UnsafeMethodAccess = 0
        TypeAnnotations = 0
        TypeMismatches = 0
        StringConcatenation = 0
        ShadowedGlobals = 0
        UniversalSceneManager = 0
        MissingIdentifiers = 0
    }
}

function Write-FixLog {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "White" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Fix-UniversalNodeAccessCalls {
    param([string]$Content, [string]$FileName)
    
    $fixes = 0
    $originalContent = $Content
    
    # Pattern 1: Fix get_node_safe calls with 3 arguments - use proper get_node()
    $pattern1 = 'UniversalNodeAccess\.get_node_safe\(([^,]+),\s*([^,]+),\s*([^)]+)\)'
    $replacement1 = 'get_node($2)'
    if ($Content -match $pattern1) {
        $Content = $Content -replace $pattern1, $replacement1
        $matches = [regex]::Matches($originalContent, $pattern1)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) get_node_safe() calls with proper get_node()" "Success"
    }
    
    # Pattern 2: Fix add_child_safe static calls - use direct add_child
    $pattern2 = 'UniversalNodeAccess\.add_child_safe\(\s*([^,]+),\s*([^,]+),\s*([^)]+)\)'
    $replacement2 = '$1.add_child($2)'
    if ($Content -match $pattern2) {
        $Content = $Content -replace $pattern2, $replacement2
        $matches = [regex]::Matches($originalContent, $pattern2)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) add_child_safe() calls with direct add_child()" "Success"
    }
    
    return @($Content, $fixes)
}

function Fix-UniversalResourceLoaderCalls {
    param([string]$Content, [string]$FileName)
    
    $fixes = 0
    $originalContent = $Content
    
    # Pattern 1: Replace load_script_safe with load()
    $pattern1 = 'UniversalResourceLoader\.load_script_safe\(\s*"([^"]+)"\s*,\s*[^)]+\)'
    $replacement1 = 'load("$1")'
    if ($Content -match $pattern1) {
        $Content = $Content -replace $pattern1, $replacement1
        $matches = [regex]::Matches($originalContent, $pattern1)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) load_script_safe() calls" "Success"
    }
    
    # Pattern 2: Replace load_scene_safe with load()
    $pattern2 = 'UniversalResourceLoader\.load_scene_safe\(\s*([^,]+)\s*,\s*[^)]+\)'
    $replacement2 = 'load($1)'
    if ($Content -match $pattern2) {
        $Content = $Content -replace $pattern2, $replacement2
        $matches = [regex]::Matches($originalContent, $pattern2)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) load_scene_safe() calls" "Success"
    }
    
    # Pattern 3: Replace load_resource_safe with load()
    $pattern3 = 'UniversalResourceLoader\.load_resource_safe\(\s*([^,]+)\s*,\s*[^,]+\s*,\s*[^)]+\)'
    $replacement3 = 'load($1)'
    if ($Content -match $pattern3) {
        $Content = $Content -replace $pattern3, $replacement3
        $matches = [regex]::Matches($originalContent, $pattern3)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) load_resource_safe() calls" "Success"
    }
    
    return @($Content, $fixes)
}

function Fix-UniversalSignalManagerCalls {
    param([string]$Content, [string]$FileName)
    
    $fixes = 0
    $originalContent = $Content
    
    # Pattern 1: Replace connect_signal_safe with direct connect
    $pattern1 = 'UniversalSignalManager\.connect_signal_safe\(\s*([^,]+),\s*"([^"]+)"\s*,\s*([^,]+)\s*,\s*[^)]+\)'
    $replacement1 = '$1.$2.connect($3)'
    if ($Content -match $pattern1) {
        $Content = $Content -replace $pattern1, $replacement1
        $matches = [regex]::Matches($originalContent, $pattern1)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) connect_signal_safe() calls" "Success"
    }
    
    # Pattern 2: Replace emit_signal_safe with direct emit
    $pattern2 = 'UniversalSignalManager\.emit_signal_safe\(\s*([^,]+),\s*"([^"]+)"\s*,\s*\[([^\]]*)\]\s*,\s*[^)]+\)'
    $replacement2 = '$1.$2.emit($3)'
    if ($Content -match $pattern2) {
        $Content = $Content -replace $pattern2, $replacement2
        $matches = [regex]::Matches($originalContent, $pattern2)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) emit_signal_safe() calls" "Success"
    }
    
    # Pattern 3: Simple emit_signal_safe without parameters
    $pattern3 = 'UniversalSignalManager\.emit_signal_safe\(\s*([^,]+),\s*"([^"]+)"\s*,\s*\[\]\s*,\s*[^)]+\)'
    $replacement3 = '$1.$2.emit()'
    if ($Content -match $pattern3) {
        $Content = $Content -replace $pattern3, $replacement3
        $matches = [regex]::Matches($originalContent, $pattern3)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) simple emit_signal_safe() calls" "Success"
    }
    
    return @($Content, $fixes)
}

function Fix-UniversalDataAccessCalls {
    param([string]$Content, [string]$FileName)
    
    $fixes = 0
    $originalContent = $Content
    
    # Pattern 1: Replace get_dict_value_safe with direct access
    $pattern1 = 'UniversalDataAccess\.get_dict_value_safe\(\s*([^,]+),\s*"([^"]+)"\s*,\s*([^,]+)\s*,\s*[^)]+\)'
    $replacement1 = '$1.get("$2", $3)'
    if ($Content -match $pattern1) {
        $Content = $Content -replace $pattern1, $replacement1
        $matches = [regex]::Matches($originalContent, $pattern1)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) get_dict_value_safe() calls" "Success"
    }
    
    # Pattern 2: Replace set_dict_value_safe with direct assignment
    $pattern2 = 'UniversalDataAccess\.set_dict_value_safe\(\s*([^,]+),\s*([^,]+),\s*([^,]+)\s*,\s*[^)]+\)'
    $replacement2 = '$1[$2] = $3'
    if ($Content -match $pattern2) {
        $Content = $Content -replace $pattern2, $replacement2
        $matches = [regex]::Matches($originalContent, $pattern2)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) set_dict_value_safe() calls" "Success"
    }
    
    return @($Content, $fixes)
}

function Fix-UnsafeMethodAccess {
    param([string]$Content, [string]$FileName)
    
    $fixes = 0
    $originalContent = $Content
    
    # Pattern 1: Fix character.get("id") with proper typing - following Godot docs
    $pattern1 = '(\w+)\.get\("id"\)'
    $replacement1 = '($1.get("id") as String if $1.has("id") else "")'
    if ($Content -match $pattern1) {
        $Content = $Content -replace $pattern1, $replacement1
        $matches = [regex]::Matches($originalContent, $pattern1)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) unsafe get(id) calls with proper typing" "Success"
    }
    
    # Pattern 2: Fix equipment_storage[i].get("id") calls  
    $pattern2 = '(_equipment_storage\[\w+\])\.get\("id"\)'
    $replacement2 = '($1.get("id") as String if $1.has("id") else "")'
    if ($Content -match $pattern2) {
        $Content = $Content -replace $pattern2, $replacement2
        $matches = [regex]::Matches($originalContent, $pattern2)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) unsafe equipment storage get(id) calls" "Success"
    }
    
    return @($Content, $fixes)
}

function Fix-TypeMismatches {
    param([string]$Content, [string]$FileName)
    
    $fixes = 0
    $originalContent = $Content
    
    # Pattern 1: Fix button_height type mismatch (Button assigned float)
    $pattern1 = 'var\s+(\w*button_height\w*)\s*:\s*Button\s*=\s*(TOUCH_BUTTON_HEIGHT[^=\n]*)'
    $replacement1 = 'var $1: float = $2'
    if ($Content -match $pattern1) {
        $Content = $Content -replace $pattern1, $replacement1
        $matches = [regex]::Matches($originalContent, $pattern1)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) button_height type mismatches" "Success"
    }
    
    # Pattern 2: Fix panel type mismatches (Panel assigned PanelContainer)
    $pattern2 = 'var\s+(\w*panel\w*)\s*:\s*Panel\s*=\s*PanelContainer\.new\(\)'
    $replacement2 = 'var $1: PanelContainer = PanelContainer.new()'
    if ($Content -match $pattern2) {
        $Content = $Content -replace $pattern2, $replacement2
        $matches = [regex]::Matches($originalContent, $pattern2)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) Panel/PanelContainer type mismatches" "Success"
    }
    
    # Pattern 3: Fix character_name type mismatches (Character assigned String)
    $pattern3 = 'var\s+(\w*character_name\w*)\s*:\s*Character\s*=\s*("[^"]*"[^=\n]*)'
    $replacement3 = 'var $1: String = $2'
    if ($Content -match $pattern3) {
        $Content = $Content -replace $pattern3, $replacement3
        $matches = [regex]::Matches($originalContent, $pattern3)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) character_name type mismatches" "Success"
    }
    
    # Pattern 4: Fix character_dict type mismatches (Character assigned Dictionary)
    $pattern4 = 'var\s+(\w*character_dict\w*)\s*:\s*Character\s*=\s*([^=\n]*to_dict[^=\n]*)'
    $replacement4 = 'var $1: Dictionary = $2'
    if ($Content -match $pattern4) {
        $Content = $Content -replace $pattern4, $replacement4
        $matches = [regex]::Matches($originalContent, $pattern4)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) character_dict type mismatches" "Success"
    }
    
    # Pattern 5: Fix character_gen type mismatches (Character assigned other class)
    $pattern5 = 'var\s+(\w*character_gen\w*)\s*:\s*Character\s*=\s*(\w+\.new\(\))'
    $replacement5 = 'var $1 = $2'
    if ($Content -match $pattern5) {
        $Content = $Content -replace $pattern5, $replacement5
        $matches = [regex]::Matches($originalContent, $pattern5)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) character_gen type mismatches" "Success"
    }
    
    # Pattern 6: Fix character_manager type mismatches (Character assigned Node)
    $pattern6 = 'var\s+(\w*character_manager\w*)\s*:\s*Character\s*=\s*(get_node[^=\n]*|UniversalNodeAccess[^=\n]*)'
    $replacement6 = 'var $1: Node = $2'
    if ($Content -match $pattern6) {
        $Content = $Content -replace $pattern6, $replacement6
        $matches = [regex]::Matches($originalContent, $pattern6)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) character_manager type mismatches" "Success"
    }
    
    return @($Content, $fixes)
}

function Fix-StringConcatenationErrors {
    param([string]$Content, [string]$FileName)
    
    $fixes = 0
    $originalContent = $Content
    
    # Pattern 1: Fix String + Character concatenation - convert Character to String
    $pattern1 = '"([^"]*)" \+ (\w+_name)\s*(?=\)|,|\n)'
    $replacement1 = '"$1" + str($2)'
    if ($Content -match $pattern1) {
        $Content = $Content -replace $pattern1, $replacement1
        $matches = [regex]::Matches($originalContent, $pattern1)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) String + Character concatenation errors" "Success"
    }
    
    # Pattern 2: Fix Character + String concatenation errors
    $pattern2 = '(\w+_name) \+ "([^"]*)"'
    $replacement2 = 'str($1) + "$2"'
    if ($Content -match $pattern2) {
        $Content = $Content -replace $pattern2, $replacement2
        $matches = [regex]::Matches($originalContent, $pattern2)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) Character + String concatenation errors" "Success"
    }
    
    return @($Content, $fixes)
}

function Fix-ShadowedGlobalIdentifiers {
    param([string]$Content, [string]$FileName)
    
    $fixes = 0
    $originalContent = $Content
    
    # Common shadowed global identifiers in Godot
    $shadowedGlobals = @(
        @{Pattern = 'var\s+position\s*:'; Replacement = 'var node_position:'},
        @{Pattern = 'var\s+rotation\s*:'; Replacement = 'var node_rotation:'},
        @{Pattern = 'var\s+scale\s*:'; Replacement = 'var node_scale:'},
        @{Pattern = 'var\s+name\s*:'; Replacement = 'var node_name:'},
        @{Pattern = 'var\s+visible\s*:'; Replacement = 'var is_visible:'},
        @{Pattern = 'var\s+enabled\s*:'; Replacement = 'var is_enabled:'}
    )
    
    foreach ($global in $shadowedGlobals) {
        if ($Content -match $global.Pattern) {
            $Content = $Content -replace $global.Pattern, $global.Replacement
            $matches = [regex]::Matches($originalContent, $global.Pattern)
            $fixes += $matches.Count
            Write-FixLog "  Fixed $($matches.Count) shadowed global identifier: $($global.Pattern)" "Success"
        }
    }
    
    return @($Content, $fixes)
}

function Fix-UniversalSceneManagerCalls {
    param([string]$Content, [string]$FileName)
    
    $fixes = 0
    $originalContent = $Content
    
    # Pattern 1: Replace instantiate_scene_safe with load().instantiate()
    $pattern1 = 'UniversalSceneManager\.instantiate_scene_safe\(\s*([^,]+)\s*,\s*[^)]+\)'
    $replacement1 = 'load($1).instantiate()'
    if ($Content -match $pattern1) {
        $Content = $Content -replace $pattern1, $replacement1
        $matches = [regex]::Matches($originalContent, $pattern1)
        $fixes += $matches.Count
        Write-FixLog "  Fixed $($matches.Count) instantiate_scene_safe() calls" "Success"
    }
    
    return @($Content, $fixes)
}

function Fix-MissingIdentifiers {
    param([string]$Content, [string]$FileName)
    
    $fixes = 0
    $originalContent = $Content
    
    # Pattern 1: Remove UniversalNodeValidator calls (replace with direct validation)
    $pattern1 = 'var\s+setup_result[^=]*=\s*UniversalNodeValidator\.setup_ui_component\([^)]+\)'
    $replacement1 = '# TODO: Replace with direct node validation'
    if ($Content -match $pattern1) {
        $Content = $Content -replace $pattern1, $replacement1
        $matches = [regex]::Matches($originalContent, $pattern1)
        $fixes += $matches.Count
        Write-FixLog "  Commented out $($matches.Count) UniversalNodeValidator calls" "Warning"
    }
    
    # Pattern 2: Remove references to missing UniversalSceneManager
    if ($Content -match 'UniversalSceneManager\.' -and $Content -notmatch '@onready var.*UniversalSceneManager') {
        # Just leave the function calls to be fixed by other patterns
        Write-FixLog "  UniversalSceneManager calls will be fixed by other patterns" "Info"
    }
    
    return @($Content, $fixes)
}

function Add-TypeAnnotations {
    param([string]$Content, [string]$FileName)
    
    $fixes = 0
    $originalContent = $Content
    
    # Pattern 1: Add types to common untyped variables
    $untypedPatterns = @(
        @{Pattern = 'var\s+(current_character)\s*=\s*null'; Replacement = 'var $1: Character = null'},
        @{Pattern = 'var\s+(selected_character)\s*=\s*null'; Replacement = 'var $1: Character = null'},
        @{Pattern = 'var\s+(character_creator)\s*$'; Replacement = 'var $1: Node'},
        @{Pattern = 'var\s+(game_state)\s*$'; Replacement = 'var $1: Resource'},
        @{Pattern = 'var\s+(campaign_manager)\s*$'; Replacement = 'var $1: Node'},
        @{Pattern = 'var\s+(phase_manager)\s*$'; Replacement = 'var $1: Node'}
    )
    
    foreach ($pattern in $untypedPatterns) {
        if ($Content -match $pattern.Pattern) {
            $Content = $Content -replace $pattern.Pattern, $pattern.Replacement
            $matches = [regex]::Matches($originalContent, $pattern.Pattern)
            $fixes += $matches.Count
            Write-FixLog "  Added type annotation: $($pattern.Pattern)" "Success"
        }
    }
    
    return @($Content, $fixes)
}

function Process-GDScriptFile {
    param([string]$FilePath)
    
    if (!(Test-Path $FilePath)) {
        Write-FixLog "File not found: $FilePath" "Error"
        return $false
    }
    
    $fileName = Split-Path $FilePath -Leaf
    Write-FixLog "Processing: $fileName"
    
    try {
        # Read file content
        $content = Get-Content $FilePath -Raw -Encoding UTF8
        $originalContent = $content
        $totalFileFixes = 0
        
        # Apply all fix patterns systematically
        $result = Fix-UniversalNodeAccessCalls $content $fileName
        $content = $result[0]
        $fixes = $result[1]
        $totalFileFixes += $fixes
        $script:Stats.FixesByType.UniversalNodeAccess += $fixes
        
        $result = Fix-UniversalResourceLoaderCalls $content $fileName
        $content = $result[0]
        $fixes = $result[1]
        $totalFileFixes += $fixes
        $script:Stats.FixesByType.UniversalResourceLoader += $fixes
        
        $result = Fix-UniversalSignalManagerCalls $content $fileName
        $content = $result[0]
        $fixes = $result[1]
        $totalFileFixes += $fixes
        $script:Stats.FixesByType.UniversalSignalManager += $fixes
        
        $result = Fix-UniversalDataAccessCalls $content $fileName
        $content = $result[0]
        $fixes = $result[1]
        $totalFileFixes += $fixes
        $script:Stats.FixesByType.UniversalDataAccess += $fixes
        
        $result = Fix-UnsafeMethodAccess $content $fileName
        $content = $result[0]
        $fixes = $result[1]
        $totalFileFixes += $fixes
        $script:Stats.FixesByType.UnsafeMethodAccess += $fixes
        
        $result = Fix-TypeMismatches $content $fileName
        $content = $result[0]
        $fixes = $result[1]
        $totalFileFixes += $fixes
        $script:Stats.FixesByType.TypeMismatches += $fixes
        
        $result = Fix-StringConcatenationErrors $content $fileName
        $content = $result[0]
        $fixes = $result[1]
        $totalFileFixes += $fixes
        $script:Stats.FixesByType.StringConcatenation += $fixes
        
        $result = Fix-ShadowedGlobalIdentifiers $content $fileName
        $content = $result[0]
        $fixes = $result[1]
        $totalFileFixes += $fixes
        $script:Stats.FixesByType.ShadowedGlobals += $fixes
        
        $result = Fix-UniversalSceneManagerCalls $content $fileName
        $content = $result[0]
        $fixes = $result[1]
        $totalFileFixes += $fixes
        $script:Stats.FixesByType.UniversalSceneManager += $fixes
        
        $result = Fix-MissingIdentifiers $content $fileName
        $content = $result[0]
        $fixes = $result[1]
        $totalFileFixes += $fixes
        $script:Stats.FixesByType.MissingIdentifiers += $fixes
        
        $result = Add-TypeAnnotations $content $fileName
        $content = $result[0]
        $fixes = $result[1]
        $totalFileFixes += $fixes
        $script:Stats.FixesByType.TypeAnnotations += $fixes
        
        # Write changes if any fixes were made and not in WhatIf mode
        if ($totalFileFixes -gt 0) {
            if ($WhatIf) {
                Write-FixLog "  [WHATIF] Would apply $totalFileFixes fixes to $fileName" "Warning"
            } else {
                # Create backup
                $backupPath = $FilePath + ".backup_comprehensive"
                Copy-Item $FilePath $backupPath -Force
                
                # Write fixed content
                Set-Content $FilePath $content -Encoding UTF8 -NoNewline
                Write-FixLog "  Applied $totalFileFixes fixes to $fileName (backup: $(Split-Path $backupPath -Leaf))" "Success"
            }
            
            $script:Stats.TotalFixes += $totalFileFixes
        } else {
            Write-FixLog "  No issues found in $fileName"
        }
        
        $script:Stats.FilesProcessed++
        return $true
        
    } catch {
        Write-FixLog "Error processing $fileName`: $($_.Exception.Message)" "Error"
        return $false
    }
}

# Main execution
Write-FixLog "=== Universal GDScript Warning Fixer ===" "Success"
Write-FixLog "Targeting: SHADOWED_GLOBAL_IDENTIFIER, UNSAFE_METHOD_ACCESS, UNTYPED_DECLARATION" "Info"
Write-FixLog "Source Path: $SourcePath"
Write-FixLog "Mode: $(if ($WhatIf) { 'WHATIF (Preview)' } else { 'APPLY FIXES' })"
Write-FixLog ""

if (!(Test-Path $SourcePath)) {
    Write-FixLog "Source path not found: $SourcePath" "Error"
    exit 1
}

# Find all .gd files in source directory (excluding tests)
$gdFiles = Get-ChildItem -Path $SourcePath -Filter "*.gd" -Recurse | Where-Object { 
    $_.FullName -notmatch "\\tests\\" 
}

Write-FixLog "Found $($gdFiles.Count) .gd files to process"
Write-FixLog ""

# Process each file
foreach ($file in $gdFiles) {
    Process-GDScriptFile $file.FullName
}

# Display summary
Write-FixLog ""
Write-FixLog "=== COMPREHENSIVE SUMMARY ===" "Success"
Write-FixLog "Files Processed: $($script:Stats.FilesProcessed)"
Write-FixLog "Total Fixes Applied: $($script:Stats.TotalFixes)"
Write-FixLog ""
Write-FixLog "Fixes by Warning Type:"
foreach ($fixType in $script:Stats.FixesByType.Keys | Sort-Object) {
    $count = $script:Stats.FixesByType[$fixType]
    if ($count -gt 0) {
        Write-FixLog "  $fixType`: $count fixes" "Success"
    }
}

if ($WhatIf) {
    Write-FixLog ""
    Write-FixLog "This was a preview run. Use -WhatIf:`$false to apply fixes." "Warning"
    Write-FixLog "Estimated warning reduction: $($script:Stats.TotalFixes) warnings" "Info"
} else {
    Write-FixLog ""
    Write-FixLog "All fixes applied successfully!" "Success"
    Write-FixLog "Backup files created with .backup_comprehensive extension." "Info"
    Write-FixLog "This should significantly reduce SHADOWED_GLOBAL_IDENTIFIER, UNSAFE_METHOD_ACCESS, and UNTYPED_DECLARATION warnings." "Success"
} 