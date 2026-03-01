# Safe Manager File Deletion Script (PowerShell)
# Shows what will be deleted before actual deletion

$ProjectRoot = "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"
$BackupDir = "$ProjectRoot\backup\managers_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MANAGER FILE DELETION - DRY RUN" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Find all Manager files
$ManagerFiles = Get-ChildItem -Path "$ProjectRoot\src" -Filter "*Manager*.gd" -Recurse -File

Write-Host "Found $($ManagerFiles.Count) Manager files:`n" -ForegroundColor Yellow

# Group by directory for better visualization
$ManagerFiles | Group-Object DirectoryName | ForEach-Object {
    $RelativePath = $_.Name.Replace($ProjectRoot, ".")
    Write-Host "`n📁 $RelativePath" -ForegroundColor Green
    $_.Group | ForEach-Object {
        $Size = [math]::Round($_.Length / 1KB, 2)
        Write-Host "   ❌ $($_.Name) ($Size KB)" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Manager files to delete: $($ManagerFiles.Count)" -ForegroundColor Yellow
Write-Host "Total size: $([math]::Round(($ManagerFiles | Measure-Object -Property Length -Sum).Sum / 1KB, 2)) KB`n" -ForegroundColor Yellow

# Ask for confirmation
$Confirm = Read-Host "Do you want to DELETE these files? (yes/no)"

if ($Confirm -ne "yes") {
    Write-Host "`n❌ Deletion cancelled. No files were deleted." -ForegroundColor Red
    exit 0
}


# Create backup directory
Write-Host "`n📦 Creating backup..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

# Backup all Manager files
$BackupCount = 0
foreach ($File in $ManagerFiles) {
    $RelativePath = $File.FullName.Replace("$ProjectRoot\src\", "")
    $BackupPath = Join-Path $BackupDir $RelativePath
    $BackupParent = Split-Path $BackupPath -Parent
    
    New-Item -ItemType Directory -Force -Path $BackupParent | Out-Null
    Copy-Item $File.FullName -Destination $BackupPath
    $BackupCount++
}

Write-Host "✅ Backed up $BackupCount files to: $BackupDir`n" -ForegroundColor Green

# Delete Manager files
Write-Host "🗑️  Deleting Manager files..." -ForegroundColor Cyan
$DeletedCount = 0

foreach ($File in $ManagerFiles) {
    try {
        # Try git rm first
        $GitResult = git rm -f $File.FullName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✓ git rm: $($File.Name)" -ForegroundColor Green
        } else {
            # Fall back to regular delete
            Remove-Item $File.FullName -Force
            Write-Host "   ✓ deleted: $($File.Name)" -ForegroundColor Yellow
        }
        $DeletedCount++
    } catch {
        Write-Host "   ✗ failed: $($File.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DELETION COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ Deleted: $DeletedCount files" -ForegroundColor Green
Write-Host "📦 Backup: $BackupDir" -ForegroundColor Cyan
Write-Host "`nRun 'git status' to see changes`n" -ForegroundColor Yellow
