# Advanced PowerShell Script for Complex Linter Errors
# Addresses class inheritance, property redefinition, and other complex issues

param(
    [switch]$DryRun,
    [switch]$Verbose
)

Write-Host "Advanced Five Parsecs Linter Error Fix Script" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

$FixCount = 0

function Log-Fix {
    param($Message, $File = "")
    $script:FixCount++
    if ($Verbose) {
        Write-Host "ADVANCED FIX $FixCount`: $Message" -ForegroundColor Cyan
        if ($File) {
            Write-Host "  File: $File" -ForegroundColor Gray
        }
    }
}

Write-Host "Phase 1: Fixing Class Inheritance Issues" -ForegroundColor Cyan

# Fix GameLocation.gd inheritance issues
$gameLocationPath = "src/game/world/GameLocation.gd"
if (Test-Path $gameLocationPath) {
    $content = Get-Content $gameLocationPath -Raw
    
    # Fix common inheritance syntax errors
    $content = $content -replace 'extends\s+RefCounted\s+class_name', 'extends RefCounted
class_name'
    $content = $content -replace 'extends\s+"[^"]*"\s+class_name', 'extends RefCounted
class_name'
    
    # Ensure proper class structure
    if ($content -notmatch '@tool\s*extends\s+RefCounted\s*class_name') {
        $content = $content -replace '^(@tool\s*)?class_name\s+(\w+)', '@tool
extends RefCounted
class_name $2'
    }
    
    if (-not $DryRun) {
        Set-Content $gameLocationPath $content -NoNewline
    }
    Log-Fix "Fixed GameLocation.gd inheritance structure" $gameLocationPath
}

Write-Host "Phase 2: Fixing Property Redefinition Errors" -ForegroundColor Cyan

# Fix BattleCharacter.gd property redefinition
$battleCharPath = "src/game/combat/BattleCharacter.gd"
if (Test-Path $battleCharPath) {
    $content = Get-Content $battleCharPath -Raw
    
    # Remove duplicate property definitions
    $content = $content -replace 'var\s+character_name:\s*String:\s*get:\s*return\s+[^
]*
\s*set\([^)]*\):[^
]*
(?=.*var\s+character_name)', ''
    
    # Fix property getter/setter syntax
    $content = $content -replace 'var\s+(\w+):\s*(\w+):\s*get:\s*return\s+([^
]*)\s*set\([^)]*\):[^
]*', 'var $1: $2:
	get:
		return $3
	set(value):
		$3 = value'
    
    if (-not $DryRun) {
        Set-Content $battleCharPath $content -NoNewline
    }
    Log-Fix "Fixed BattleCharacter.gd property redefinition errors" $battleCharPath
}

Write-Host "Phase 3: Fixing SceneRouter Class Name Conflicts" -ForegroundColor Cyan

# Fix SceneRouter.gd naming conflict with autoload
$sceneRouterPath = "src/ui/screens/SceneRouter.gd"
if (Test-Path $sceneRouterPath) {
    $content = Get-Content $sceneRouterPath -Raw
    
    # Rename class to avoid autoload conflict
    $content = $content -replace 'class_name\s+SceneRouter', 'class_name SceneRouterController'
    $content = $content -replace 'extends\s+SceneRouter', 'extends SceneRouterController'
    
    if (-not $DryRun) {
        Set-Content $sceneRouterPath $content -NoNewline
    }
    Log-Fix "Fixed SceneRouter class name conflict" $sceneRouterPath
}

Write-Host "Phase 4: Fixing Array and Dictionary Syntax Errors" -ForegroundColor Cyan

$gdFiles = Get-ChildItem -Path "src" -Recurse -Filter "*.gd"

foreach ($file in $gdFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Fix arrays with corrupted syntax
    $content = $content -replace '\[\s*@warning_ignore\([^)]*\)\s*([^]]*)\]', '[$1]'
    $content = $content -replace '\{\s*@warning_ignore\([^)]*\)\s*([^}]*)\}', '{$1}'
    
    # Fix incomplete arrays/dictionaries
    $content = $content -replace '\[\s*([^]]*?),\s*\]', '[$1]'
    $content = $content -replace '\{\s*([^}]*?),\s*\}', '{$1}'
    
    # Fix array append with missing arguments
    $content = $content -replace '\.append\(\s*\)', '.append("")'
    
    if ($content -ne $originalContent) {
        if (-not $DryRun) {
            Set-Content $file.FullName $content -NoNewline
        }
        Log-Fix "Fixed array/dictionary syntax errors" $file.FullName
    }
}

Write-Host "Phase 5: Fixing Export Variable Syntax" -ForegroundColor Cyan

foreach ($file in $gdFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Fix @export syntax errors
    $content = $content -replace '@export\s+@warning_ignore\([^)]*\)\s+var', '@export var'
    $content = $content -replace '@export\([^)]*\)\s+@warning_ignore\([^)]*\)\s+var', '@export var'
    
    # Fix onready syntax errors
    $content = $content -replace '@onready\s+@warning_ignore\([^)]*\)\s+var', '@onready var'
    
    if ($content -ne $originalContent) {
        if (-not $DryRun) {
            Set-Content $file.FullName $content -NoNewline
        }
        Log-Fix "Fixed @export/@onready syntax errors" $file.FullName
    }
}

Write-Host "Phase 6: Fixing Signal Connection Syntax" -ForegroundColor Cyan

foreach ($file in $gdFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Fix signal connections with missing parameters
    $content = $content -replace '\.connect\(\s*\)', '.connect(_on_signal)'
    $content = $content -replace '\.connect\([^,)]*,\s*\)', '.connect($1, _on_signal)'
    
    # Fix signal emissions with corrupted syntax
    $content = $content -replace '\.emit\(\s*@warning_ignore\([^)]*\)\s*\)', '.emit()'
    
    if ($content -ne $originalContent) {
        if (-not $DryRun) {
            Set-Content $file.FullName $content -NoNewline
        }
        Log-Fix "Fixed signal connection syntax" $file.FullName
    }
}

Write-Host "Phase 7: Creating Additional Missing Dependencies" -ForegroundColor Cyan

# Additional missing files that may be needed
$additionalFiles = @{
    "src/core/systems/ResourceSystem.gd" = @"
@tool
extends RefCounted
class_name ResourceSystem

## Resource management system for Five Parsecs
## Handles resource tracking and allocation

signal resource_changed(resource_type: String, amount: int)

var resources: Dictionary = {}

func _init() -> void:
	_initialize_resources()

func _initialize_resources() -> void:
	resources = {
		"credits": 1000,
		"supplies": 50,
		"fuel": 100,
		"medical_supplies": 20
	}

func get_resource(resource_type: String) -> int:
	return resources.get(resource_type, 0)

func set_resource(resource_type: String, amount: int) -> void:
	resources[resource_type] = amount
	resource_changed.emit(resource_type, amount)

func modify_resource(resource_type: String, change: int) -> bool:
	var current = get_resource(resource_type)
	var new_amount = current + change
	
	if new_amount < 0:
		return false
	
	set_resource(resource_type, new_amount)
	return true

func has_resource(resource_type: String) -> bool:
	return resources.has(resource_type)

func can_afford(costs: Dictionary) -> bool:
	for resource_type in costs:
		if get_resource(resource_type) < costs[resource_type]:
			return false
	return true
"@

    "src/core/systems/items/GameWeapon.gd" = @"
@tool
extends Resource
class_name GameWeapon

## Weapon resource for Five Parsecs

@export var weapon_name: String = ""
@export var damage: int = 1
@export var range: int = 12
@export var shots: int = 1
@export var weapon_type: String = "basic"
@export var cost: int = 100

func _init() -> void:
	pass

func get_display_name() -> String:
	return weapon_name

func get_damage() -> int:
	return damage

func get_range() -> int:
	return range
"@

    "src/core/terrain/TerrainEffects.gd" = @"
@tool
extends RefCounted
class_name TerrainEffects

## Terrain effects system for Five Parsecs battles

static func apply_terrain_effect(character: Node, terrain_type: int) -> void:
	match terrain_type:
		TerrainTypes.Type.DIFFICULT:
			# Reduce movement
			pass
		TerrainTypes.Type.HAZARD:
			# Apply damage
			pass
		_:
			pass

static func get_movement_modifier(terrain_type: int) -> float:
	return TerrainTypes.get_movement_cost(terrain_type)

static func get_cover_modifier(terrain_type: int) -> int:
	return TerrainTypes.get_cover_bonus(terrain_type)
"@

    "src/core/terrain/TerrainSystem.gd" = @"
@tool
extends RefCounted
class_name TerrainSystem

## Terrain management system for Five Parsecs

signal terrain_updated(position: Vector2, terrain_type: int)

var terrain_grid: Dictionary = {}
var grid_size: Vector2i = Vector2i(20, 20)

func _init() -> void:
	_initialize_terrain()

func _initialize_terrain() -> void:
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			terrain_grid[Vector2i(x, y)] = TerrainTypes.Type.OPEN

func set_terrain(position: Vector2i, terrain_type: int) -> void:
	terrain_grid[position] = terrain_type
	terrain_updated.emit(Vector2(position), terrain_type)

func get_terrain(position: Vector2i) -> int:
	return terrain_grid.get(position, TerrainTypes.Type.OPEN)
"@

    "src/data/resources/Deployment/ObjectiveMarker.gd" = @"
@tool
extends Resource
class_name ObjectiveMarker

## Objective marker resource for Five Parsecs missions

@export var marker_id: String = ""
@export var marker_type: String = "standard"
@export var position: Vector2 = Vector2.ZERO
@export var is_completed: bool = false

func _init() -> void:
	pass

func complete_objective() -> void:
	is_completed = true

func get_display_name() -> String:
	return marker_type.capitalize() + " Objective"
"@
}

foreach ($file in $additionalFiles.Keys) {
    $directory = Split-Path $file -Parent
    if (-not (Test-Path $directory)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        Log-Fix "Created missing directory" $directory
    }
    
    if (-not (Test-Path $file)) {
        if (-not $DryRun) {
            Set-Content $file $additionalFiles[$file] -NoNewline
        }
        Log-Fix "Created additional missing dependency file" $file
    }
}

# Summary
Write-Host "`nAdvanced Linter Error Fix Summary" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host "Total advanced fixes applied: $FixCount" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "DRY RUN - No files were actually modified" -ForegroundColor Magenta
    Write-Host "Run without -DryRun to apply fixes" -ForegroundColor Magenta
} else {
    Write-Host "All advanced fixes have been applied to the files" -ForegroundColor Green
}

Write-Host "`nRecommended Next Steps:" -ForegroundColor Cyan
Write-Host "1. Open Godot editor and check for remaining errors" -ForegroundColor White
Write-Host "2. Run project validation to ensure everything works" -ForegroundColor White
Write-Host "3. Test core functionality" -ForegroundColor White
Write-Host "4. Commit all changes to version control" -ForegroundColor White 