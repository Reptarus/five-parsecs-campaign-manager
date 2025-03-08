# PowerShell script to fix extends statements in test files
Write-Host "Fixing extends statements in test files..."

# Define the absolute test directory path - THIS IS THE IMPORTANT PART
$testDir = Join-Path $PWD "tests"
Write-Host "Using test directory: $testDir"

# Function to fix extends statements in a file
function Fix-Extends {
    param (
        [string]$FilePath,
        [string]$Pattern,
        [string]$Replacement,
        [string]$Comment = "# Use explicit preloads instead of global class names"
    )
    
    # Only process if the file exists
    if (Test-Path -Path $FilePath) {
        $content = Get-Content -Path $FilePath -Raw
        if ($content -match $Pattern -and $content -notmatch 'extends "res://') {
            Write-Host "  Fixing $FilePath"
            
            # Replace pattern and add comment
            $newContent = $content -replace $Pattern, "$Replacement`n$Comment"
            
            Set-Content -Path $FilePath -Value $newContent -NoNewline
            return $true
        }
    } else {
        Write-Host "  File not found: $FilePath"
    }
    return $false
}

# Fix GameTest extends
Write-Host "Fixing extends GameTest references..."
$gameTestFiles = Get-ChildItem -Path $testDir -Filter "*.gd" -Recurse | 
                 Where-Object { (Get-Content $_.FullName -Raw) -match 'extends GameTest' -and (Get-Content $_.FullName -Raw) -notmatch 'extends "res://' }

$count = 0
foreach ($file in $gameTestFiles) {
    if (Fix-Extends -FilePath $file.FullName -Pattern 'extends GameTest' -Replacement 'extends "res://tests/fixtures/base/game_test.gd"') {
        $count++
    }
}
Write-Host "Fixed $count GameTest references"

# Fix BattleTest extends
Write-Host "Fixing extends BattleTest references..."
$battleTestFiles = Get-ChildItem -Path $testDir -Filter "*.gd" -Recurse | 
                  Where-Object { (Get-Content $_.FullName -Raw) -match 'extends BattleTest' -and (Get-Content $_.FullName -Raw) -notmatch 'extends "res://' }

$count = 0
foreach ($file in $battleTestFiles) {
    if (Fix-Extends -FilePath $file.FullName -Pattern 'extends BattleTest' -Replacement 'extends "res://tests/fixtures/specialized/battle_test.gd"') {
        $count++
    }
}
Write-Host "Fixed $count BattleTest references"

# Fix UITest extends
Write-Host "Fixing extends UITest references..."
$uiTestFiles = Get-ChildItem -Path $testDir -Filter "*.gd" -Recurse | 
              Where-Object { (Get-Content $_.FullName -Raw) -match 'extends UITest' -and (Get-Content $_.FullName -Raw) -notmatch 'extends "res://' }

$count = 0
foreach ($file in $uiTestFiles) {
    if (Fix-Extends -FilePath $file.FullName -Pattern 'extends UITest' -Replacement 'extends "res://tests/fixtures/specialized/ui_test.gd"') {
        $count++
    }
}
Write-Host "Fixed $count UITest references"

# Fix CampaignTest extends
Write-Host "Fixing extends CampaignTest references..."
$campaignTestFiles = Get-ChildItem -Path $testDir -Filter "*.gd" -Recurse | 
                    Where-Object { (Get-Content $_.FullName -Raw) -match 'extends CampaignTest' -and (Get-Content $_.FullName -Raw) -notmatch 'extends "res://' }

$count = 0
foreach ($file in $campaignTestFiles) {
    if (Fix-Extends -FilePath $file.FullName -Pattern 'extends CampaignTest' -Replacement 'extends "res://tests/fixtures/specialized/campaign_test.gd"') {
        $count++
    }
}
Write-Host "Fixed $count CampaignTest references"

# Fix EnemyTest extends
Write-Host "Fixing extends EnemyTest references..."
$enemyTestFiles = Get-ChildItem -Path $testDir -Filter "*.gd" -Recurse | 
                 Where-Object { (Get-Content $_.FullName -Raw) -match 'extends EnemyTest' -and (Get-Content $_.FullName -Raw) -notmatch 'extends "res://' }

$count = 0
foreach ($file in $enemyTestFiles) {
    if (Fix-Extends -FilePath $file.FullName -Pattern 'extends EnemyTest' -Replacement 'extends "res://tests/fixtures/specialized/enemy_test.gd"') {
        $count++
    }
}
Write-Host "Fixed $count EnemyTest references"

# Fix MobileTest extends
Write-Host "Fixing extends MobileTest references..."
$mobileTestFiles = Get-ChildItem -Path $testDir -Filter "*.gd" -Recurse | 
                  Where-Object { (Get-Content $_.FullName -Raw) -match 'extends MobileTest' -and (Get-Content $_.FullName -Raw) -notmatch 'extends "res://' }

$count = 0
foreach ($file in $mobileTestFiles) {
    if (Fix-Extends -FilePath $file.FullName -Pattern 'extends MobileTest' -Replacement 'extends "res://tests/fixtures/specialized/mobile_test.gd"') {
        $count++
    }
}
Write-Host "Fixed $count MobileTest references"

Write-Host "Done! Please check the modified files." 