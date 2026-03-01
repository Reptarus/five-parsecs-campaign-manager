# Age of Fantasy - Advanced Rules Integration

This document outlines the advanced rules from the "Age of Fantasy - Advanced Rules v3.3.1" supplement and provides a plan for integrating them into the Musica Tactica codebase as toggleable options.

## 1. Advanced Rules Configuration

To manage these advanced rules, we will introduce a new resource to store the settings for which rules are active. This allows for easy toggling of rules without changing the core game logic directly.

**File:** `src/resources/configurations/AdvancedRulesSettings.gd`

```gdscript
# src/resources/configurations/AdvancedRulesSettings.gd
class_name AdvancedRulesSettings
extends Resource

@export_group("Advanced Rules")
@export var use_terrain_placement_styles: bool = false
@export var use_deployment_styles: bool = false
@export var use_extra_missions: bool = false
@export var use_side_missions: bool = false
@export var use_extra_actions: bool = false
@export var use_solid_buildings: bool = false
@export var use_random_events: bool = false
@export var use_battlefield_conditions: bool = false
@export var use_terrain_objective_effects: bool = false

func _init():
    pass
```

This settings resource can be loaded by the `BattleManager` or `GameStateMachine` at the start of a battle to configure the active rules.

## 2. Terrain Placement Styles

The advanced rules provide several methods for placing terrain on the battlefield. We can integrate these into the `BattlefieldManager`.

**File:** `src/core/BattlefieldManager.gd`

We will add an enum for the different placement styles and a function to execute the chosen style.

```gdscript
# src/core/BattlefieldManager.gd

# ... existing code ...

enum TerrainPlacementStyle {
    RANDOM,
    ALTERNATING_FREE,
    ALTERNATING_RESTRICTED,
    FULL_TABLE,
    TWO_HALVES,
    SIX_SQUARES
}

@export var terrain_placement_style: TerrainPlacementStyle = TerrainPlacementStyle.ALTERNATING_FREE

# ... existing code ...

func _initialize_simple_battlefield() -> void:
    # ... existing code ...
    
    # New logic to handle different placement styles
    var advanced_rules_settings = load("res://src/resources/configurations/AdvancedRulesSettings.tres")
    if advanced_rules_settings and advanced_rules_settings.use_terrain_placement_styles:
        _place_terrain_by_style(terrain_placement_style)
    else:
        # Default terrain placement
        pass
        
    battlefield_initialized.emit(battlefield_bounds)
    print("[BattlefieldManager] Battlefield initialized with bounds: %s" % battlefield_bounds)

func _place_terrain_by_style(style: TerrainPlacementStyle) -> void:
    match style:
        TerrainPlacementStyle.RANDOM:
            _place_terrain_randomly()
        TerrainPlacementStyle.ALTERNATING_FREE:
            _place_terrain_alternating_free()
        # ... implement other styles here ...

func _place_terrain_randomly() -> void:
    # Implementation for random terrain placement
    print("[BattlefieldManager] Placing terrain using RANDOM style.")
    # ... logic to divide table and place terrain ...

func _place_terrain_alternating_free() -> void:
    # Implementation for alternating free placement
    print("[BattlefieldManager] Placing terrain using ALTERNATING (FREE) style.")
    # ... logic for players to alternate placing terrain ...

# ... existing code ...
```

## 3. Deployment Styles

The advanced rules offer various deployment styles beyond the standard frontline deployment. These can be integrated into the `DeploymentManager`.

**File:** `src/core/DeploymentManager.gd`

We will add an enum for deployment styles and modify the `start_deployment` function to handle the selected style.

```gdscript
# src/core/DeploymentManager.gd

# ... existing code ...

enum DeploymentStyle {
    FRONTLINE,
    LONG_HAUL,
    SIDE_BATTLE,
    ENCIRCLED,
    SPEARHEAD,
    FLANK_ASSAULT
}

@export var deployment_style: DeploymentStyle = DeploymentStyle.FRONTLINE

# ... existing code ...

func start_deployment() -> void:
    var advanced_rules_settings = load("res://src/resources/configurations/AdvancedRulesSettings.tres")
    if advanced_rules_settings and advanced_rules_settings.use_deployment_styles:
        _setup_deployment_zones(deployment_style)
    else:
        _setup_deployment_zones(DeploymentStyle.FRONTLINE)

    current_deploying_team = TeamManager.Team.TEAM_A
    deployment_state = {
        TeamManager.Team.TEAM_A: false,
        TeamManager.Team.TEAM_B: false
    }
    deployment_started.emit()

func _setup_deployment_zones(style: DeploymentStyle) -> void:
    # Logic to create and position deployment zones based on the style
    # This will involve creating Area3D nodes for the deployment zones
    # and assigning them to the teams in the TeamManager.
    print("[DeploymentManager] Setting up deployment zones for style: %s" % DeploymentStyle.keys()[style])
    match style:
        DeploymentStyle.FRONTLINE:
            # ... logic for frontline deployment zones ...
            pass
        DeploymentStyle.LONG_HAUL:
            # ... logic for long haul deployment zones ...
            pass
        # ... implement other styles here ...

# ... existing code ...
```

## 4. Extra Actions

The advanced rules introduce several new actions that units can perform. These can be added to the `GameBaseUnit` class and the UI for selecting actions.

**File:** `src/core/GameBaseUnit.gd`

We will extend the `ActionType` enum and add functions to handle the new actions.

```gdscript
# src/core/GameBaseUnit.gd

# ... existing code ...

# Action types for tactical decisions
enum ActionType {
    ADVANCE,
    HOLD,
    RUSH,
    CHARGE,
    # New Advanced Actions
    ASSAULT,
    LAST_STAND,
    HUNKER_DOWN,
    DEFENSIVE_STANCE,
    FOCUSED_FIRE,
    HEAVY_CHARGE,
    STEALTH_MOVE,
    COVERING_FIRE,
    OVERWATCH
}

# ... existing code ...

func perform_assault(target: GameBaseUnit) -> void:
    if not can_perform_action(ActionType.ASSAULT): return
    # Logic for assault action (shoot then charge with penalty)
    print("[GameBaseUnit] %s performs ASSAULT on %s" % [unit_name, target.unit_name])
    # ... implementation ...
    set_action_completed()

func perform_last_stand() -> void:
    if not can_perform_action(ActionType.LAST_STAND): return
    # Logic for last stand action (for shaken units)
    print("[GameBaseUnit] %s performs LAST STAND" % unit_name)
    # ... implementation ...
    set_action_completed()

# ... add functions for other new actions ...

func can_perform_action(action: ActionType) -> bool:
    var advanced_rules_settings = load("res://src/resources/configurations/AdvancedRulesSettings.tres")
    if advanced_rules_settings and advanced_rules_settings.use_extra_actions:
        # Check if the action is one of the advanced actions
        if action > ActionType.CHARGE:
            return true # Add more specific checks if needed
    
    # Original action checks
    match action:
        ActionType.ADVANCE:
            return can_move
        ActionType.HOLD:
            return true
        ActionType.RUSH:
            return can_move
        ActionType.CHARGE:
            return can_attack
    return false

func set_action_completed() -> void:
    # Logic to mark the unit's action as completed for the turn
    pass

# ... existing code ...
```

This is a starting point for the integration. I will continue to flesh out this document with the remaining advanced rules, including Side-Missions, Solid Buildings, Random Events, and more, along with their corresponding integration plans.

## 5. Campaign Rules

To support campaign play, we need a `CampaignManager` to track progress across multiple battles.

**File:** `src/core/campaign/CampaignManager.gd`
```gdscript
# src/core/campaign/CampaignManager.gd
class_name CampaignManager
extends Node

var campaign_data: Dictionary = {
    "players": {},
    "current_round": 1,
    "max_rounds": 5
}

func start_campaign(players: Array) -> void:
    for p in players:
        campaign_data.players[p.player_id] = {
            "vp": 0,
            "army": p.army_roster
        }

func end_battle(winner_id: int, destruction_points: Dictionary) -> void:
    # Award VP and update armies
    pass

func save_campaign() -> void:
    var file = FileAccess.open("user://campaign_save.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(campaign_data))
    file.close()

func load_campaign() -> void:
    var file = FileAccess.open("user://campaign_save.json", FileAccess.READ)
    if file:
        var data = JSON.parse_string(file.get_as_text())
        if data:
            campaign_data = data
    file.close()
```

## 6. Mission Cards

Mission cards can be implemented using `Resource` objects for the card data and a manager to handle the deck.

**File:** `src/resources/mission_cards/MissionCard.gd`
```gdscript
# src/resources/mission_cards/MissionCard.gd
class_name MissionCard
extends Resource

@export var card_id: int
@export var title: String
@export var description: String
@export var vp_reward: int = 1

enum ConditionType { DESTROY_UNIT, CONTROL_OBJECTIVE, SLAY_HERO }
@export var condition: ConditionType
@export var condition_value: String # e.g., "Objective 3" or "HeroUnit"
```

**File:** `src/core/MissionDeckManager.gd`
```gdscript
# src/core/MissionDeckManager.gd
class_name MissionDeckManager
extends Node

var shared_deck: Array[MissionCard]
var player1_hand: Array[MissionCard]
var player2_hand: Array[MissionCard]

func _ready() -> void:
    # Load all mission cards from a directory
    pass

func draw_cards(player_id: int, count: int) -> void:
    # Logic to draw cards from the deck to the player's hand
    pass

func check_card_completion(player_id: int) -> void:
    # Logic to check if any cards in the player's hand are completed
    pass
```

## 7. Terrain and Objective Effects

This can be integrated into the `BattlefieldManager` by adding a chance to apply a random effect when terrain or objectives are interacted with.

**File:** `src/core/BattlefieldManager.gd`
```gdscript
# src/core/BattlefieldManager.gd
# ... (add to existing file)

func _on_unit_enters_terrain(unit, terrain_feature) -> void:
    var advanced_rules_settings = load("res://src/resources/configurations/AdvancedRulesSettings.tres")
    if advanced_rules_settings and advanced_rules_settings.use_terrain_objective_effects:
        if not terrain_feature.has("effect_applied"):
            _apply_random_terrain_effect(terrain_feature)

func _on_objective_seized(unit, objective) -> void:
    var advanced_rules_settings = load("res://src/resources/configurations/AdvancedRulesSettings.tres")
    if advanced_rules_settings and advanced_rules_settings.use_terrain_objective_effects:
        if not objective.has("effect_applied"):
            _apply_random_objective_effect(objective)

func _apply_random_terrain_effect(terrain_feature) -> void:
    # ... logic to apply a random effect from the rulebook ...
    terrain_feature["effect_applied"] = true

func _apply_random_objective_effect(objective) -> void:
    # ... logic to apply a random effect from the rulebook ...
    objective["effect_applied"] = true
```

## 8. Command Points

Command Points can be added as a resource to the `TacticsPlayer` and a new manager can handle the stratagems.

**File:** `src/core/TacticsPlayer.gd`
```gdscript
# src/core/TacticsPlayer.gd
# ... (add to existing file)

@export var command_points: int = 0

func spend_command_points(amount: int) -> bool:
    if command_points >= amount:
        command_points -= amount
        return true
    return false
```

**File:** `src/core/StratagemManager.gd`
```gdscript
# src/core/StratagemManager.gd
class_name StratagemManager
extends Node

func use_stratagem(player: TacticsPlayer, stratagem_name: String) -> void:
    # ... logic to execute the stratagem and spend CP ...
    pass
```

## 9. Deployment Styles in Godot

To implement the deployment styles, we can create `Area3D` nodes programmatically in the `DeploymentManager` based on the selected style.

**File:** `src/core/DeploymentManager.gd`
```gdscript
# src/core/DeploymentManager.gd
# ... (add to existing file)

func _setup_deployment_zones(style: DeploymentStyle) -> void:
    # Clear existing zones
    for child in get_children():
        if child is Area3D:
            child.queue_free()

    var battlefield_size = Vector2(50, 50) # Example size

    match style:
        DeploymentStyle.FRONTLINE:
            _create_zone("ZoneA", Rect2(0, 0, battlefield_size.x, 12), TeamManager.Team.TEAM_A)
            _create_zone("ZoneB", Rect2(0, battlefield_size.y - 12, battlefield_size.x, 12), TeamManager.Team.TEAM_B)
        DeploymentStyle.SPEARHEAD:
            var zone_a_points = [Vector2(0,0), Vector2(battlefield_size.x/2, battlefield_size.y/2), Vector2(0, battlefield_size.y)]
            var zone_b_points = [Vector2(battlefield_size.x,0), Vector2(battlefield_size.x/2, battlefield_size.y/2), Vector2(battlefield_size.x, battlefield_size.y)]
            _create_polygon_zone("ZoneA", zone_a_points, TeamManager.Team.TEAM_A)
            _create_polygon_zone("ZoneB", zone_b_points, TeamManager.Team.TEAM_B)
        # ... other styles

func _create_zone(name: String, rect: Rect2, team: int) -> void:
    var area = Area3D.new()
    area.name = name
    var shape = BoxShape3D.new()
    shape.size = Vector3(rect.size.x, 10, rect.size.y)
    var shape_owner = area.create_shape_owner(area)
    area.shape_owner_add_shape(shape_owner, shape)
    area.position = Vector3(rect.position.x + rect.size.x / 2, 5, rect.position.y + rect.size.y / 2)
    add_child(area)
    team_manager.assign_deployment_zone(team, area)

func _create_polygon_zone(name: String, points: Array[Vector2], team: int) -> void:
    var area = Area3D.new()
    area.name = name
    var shape = ConcavePolygonShape3D.new()
    var packed_points = PackedVector3Array()
    for p in points:
        packed_points.push_back(Vector3(p.x, 0, p.y))
    shape.faces = Geometry3D.triangulate_polygon(packed_points)
    var shape_owner = area.create_shape_owner(area)
    area.shape_owner_add_shape(shape_owner, shape)
    add_child(area)
    team_manager.assign_deployment_zone(team, area)
```
