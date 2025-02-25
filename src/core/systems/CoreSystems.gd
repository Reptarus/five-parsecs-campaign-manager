
extends Node

# Based on Core Rules tutorial mechanics
enum TutorialMode {
    QUICK_START,
    STORY_TRACK,
    BATTLE,
    ADVANCED
}

class TutorialState:
    var is_active: bool = false
    var current_step: String = ""
    var completed_steps: Array[String] = []
    var current_mode: TutorialMode = TutorialMode.QUICK_START
    var progress: float = 0.0

    func _init() -> void:
        completed_steps = []

class TutorialProgress:
    var steps_completed: int = 0
    var total_steps: int = 0
    var current_phase: String = ""
    var is_complete: bool = false

    func get_progress() -> float:
        if total_steps == 0:
            return 0.0
        return float(steps_completed) / float(total_steps)

class GameTutorialManager:
    var current_state: TutorialState
    var progress: TutorialProgress
    
    func _init() -> void:
        current_state = TutorialState.new()
        progress = TutorialProgress.new()
    
    func load_tutorial_content(tutorial_type: String) -> void:
        # Implementation for loading tutorial content
        pass

# Tutorial System Integration
class TutorialManager:
    var active_mode: TutorialMode
    var tutorial_state: TutorialState
    var tutorial_manager: GameTutorialManager
    var tutorial_progress: TutorialProgress
    
    func _init() -> void:
        tutorial_state = TutorialState.new()
        tutorial_manager = GameTutorialManager.new()
        tutorial_progress = TutorialProgress.new()
    
    func get_tutorial_state() -> TutorialState:
        return tutorial_state

    func is_tutorial_active() -> bool:
        return tutorial_state and tutorial_state.is_active

    func get_current_tutorial_mode() -> TutorialMode:
        return active_mode

    func start_tutorial(mode: TutorialMode) -> void:
        active_mode = mode
        tutorial_state.is_active = true
        match mode:
            TutorialMode.QUICK_START:
                _start_quick_start_tutorial()
            TutorialMode.STORY_TRACK:
                _start_story_track_tutorial()
            TutorialMode.BATTLE:
                _start_battle_tutorial()
            TutorialMode.ADVANCED:
                _start_advanced_tutorial()

    func _start_quick_start_tutorial() -> void:
        tutorial_state.current_step = "introduction"
        tutorial_manager.load_tutorial_content("quick_start")

    func _start_story_track_tutorial() -> void:
        tutorial_state.current_step = "event_1"
        tutorial_manager.load_tutorial_content("story_track")

    func _start_battle_tutorial() -> void:
        tutorial_state.current_step = "movement_basics"
        tutorial_manager.load_tutorial_content("battle")

    func _start_advanced_tutorial() -> void:
        tutorial_state.current_step = "campaign_setup"
        tutorial_manager.load_tutorial_content("advanced")

class WeaponTraitSystem:
    var available_traits: Dictionary = {
        "Focused": {"effect": "Improved accuracy at short range"},
        "Critical": {"effect": "Enhanced critical hit chance"},
        "Area": {"effect": "Affects multiple targets"},
        "Piercing": {"effect": "Ignores portion of armor"},
        "Melee": {"effect": "+2 to Brawling rolls"},
        "Pistol": {"effect": "+1 to Brawling rolls"},
        "Heavy": {"effect": "-1 to Hit if moved"},
        "Elegant": {"effect": "Reroll in Brawling"},
        "Clumsy": {"effect": "-1 to Brawling vs faster opponent"},
        "Impact": {"effect": "Extra Stun marker"},
        "Single use": {"effect": "One use per battle"},
        "Snap shot": {"effect": "+1 to Hit within 6\""},
        "Stun": {"effect": "Target is Stunned"},
        "Terrifying": {"effect": "Target must retreat"}
    }
    
    # Core trait effect implementations
    func _apply_pistol_bonus(combat_action: Dictionary) -> void:
        if combat_action.get("type") == "brawl":
            combat_action["brawl_bonus"] = combat_action.get("brawl_bonus", 0) + 1

    func _apply_heavy_penalty(combat_action: Dictionary) -> void:
        if combat_action.get("moved_this_turn", false):
            combat_action["hit_penalty"] = combat_action.get("hit_penalty", 0) + 1

    func _apply_elegant_effect(combat_action: Dictionary) -> void:
        if combat_action.get("type") == "brawl":
            combat_action["can_reroll"] = true

    func _apply_clumsy_effect(combat_action: Dictionary) -> void:
        var target_speed = combat_action.get("target_speed", 0)
        var attacker_speed = combat_action.get("attacker_speed", 0)
        if target_speed > attacker_speed:
            combat_action["brawl_penalty"] = combat_action.get("brawl_penalty", 0) + 1

    func _apply_impact_effect(combat_action: Dictionary) -> void:
        combat_action["extra_stun"] = true

    func _apply_single_use_effect(combat_action: Dictionary) -> void:
        combat_action["consume_after_use"] = true

    func _apply_snap_shot_effect(combat_action: Dictionary) -> void:
        if combat_action.has("range") and combat_action["range"] <= 6:
            combat_action["hit_bonus"] = combat_action.get("hit_bonus", 0) + 1

    func _apply_stun_effect(combat_action: Dictionary) -> void:
        combat_action["apply_stun"] = true

    func _apply_terrifying_effect(combat_action: Dictionary) -> void:
        combat_action["force_retreat"] = true

    # Error handling for trait effects
    func apply_trait_effects(weapon: Dictionary, combat_action: Dictionary) -> Dictionary:
        if not weapon or not combat_action:
            push_error("Invalid weapon or combat action data")
            return combat_action
            
        var traits: Array = weapon.get("traits", [])
        for current_trait in traits:
            if not current_trait in available_traits:
                push_warning("Unknown weapon trait: %s" % current_trait)
                continue
                
            match current_trait:
                "Focused":
                    _apply_focused_effect(combat_action)
                "Critical":
                    _apply_critical_effect(combat_action)
                "Area":
                    _apply_area_effect(combat_action)
                "Piercing":
                    _apply_piercing_effect(combat_action)
                "Melee":
                    _apply_melee_bonus(combat_action)
                "Pistol":
                    _apply_pistol_bonus(combat_action)
                "Heavy":
                    _apply_heavy_penalty(combat_action)
                "Elegant":
                    _apply_elegant_effect(combat_action)
                "Clumsy":
                    _apply_clumsy_effect(combat_action)
                "Impact":
                    _apply_impact_effect(combat_action)
                "Single use":
                    _apply_single_use_effect(combat_action)
                "Snap shot":
                    _apply_snap_shot_effect(combat_action)
                "Stun":
                    _apply_stun_effect(combat_action)
                "Terrifying":
                    _apply_terrifying_effect(combat_action)
                _:
                    push_warning("Unhandled weapon trait: %s" % current_trait)
        
        return combat_action

    # Validation helpers
    func validate_combat_action(action: Dictionary) -> bool:
        var required_fields := ["type", "weapon", "attacker", "target"]
        for field in required_fields:
            if not action.has(field):
                push_error("Combat action missing required field: %s" % field)
                return false
        return true

    func validate_weapon_data(weapon: Dictionary) -> bool:
        var required_fields := ["id", "traits", "damage"]
        for field in required_fields:
            if not weapon.has(field):
                push_error("Weapon data missing required field: %s" % field)
                return false
        return true

    # Core Rules weapon traits integration
    func _apply_focused_effect(combat_action: Dictionary) -> void:
        if combat_action.has("range") and combat_action["range"] <= 6:
            combat_action["hit_bonus"] = combat_action.get("hit_bonus", 0) + 1

    func _apply_critical_effect(combat_action: Dictionary) -> void:
        combat_action["critical_bonus"] = combat_action.get("critical_bonus", 0) + 1

    func _apply_area_effect(combat_action: Dictionary) -> void:
        combat_action["area_effect"] = true

    func _apply_piercing_effect(combat_action: Dictionary) -> void:
        combat_action["piercing"] = true

    func _apply_melee_bonus(combat_action: Dictionary) -> void:
        if combat_action.get("type") == "brawl":
            combat_action["brawl_bonus"] = combat_action.get("brawl_bonus", 0) + 2

class TerrainSubsystem:
    var terrain_types: Dictionary = {
        "open": {"movement_cost": 1},
        "difficult": {"movement_cost": 2},
        "very_difficult": {"movement_cost": 3},
        "impassable": {"movement_cost": - 1},
        "cover": {
            "movement_cost": 1,
            "provides_cover": true,
            "cover_bonus": 1
        },
        "elevated": {
            "movement_cost": 2,
            "height_advantage": true,
            "provides_cover": true
        }
    }
    
    func get_terrain_effect(type: String, action_type: String) -> Dictionary:
        var terrain = terrain_types.get(type, {})
        match action_type:
            "movement":
                return {"cost": terrain.get("movement_cost", 1)}
            "combat":
                return {
                    "cover": terrain.get("provides_cover", false),
                    "bonus": terrain.get("cover_bonus", 0)
                }
            _:
                push_warning("Unknown action type: %s" % action_type)
                return {}

class MovementSystem:
    const BASE_MOVE: float = 6.0
    const DIFFICULT_TERRAIN_MODIFIER: float = 0.5
    const RUNNING_BONUS: float = 2.0
    
    var terrain_system: TerrainSubsystem
    var parent_core_systems: CoreSystems # Renamed to avoid confusion
    
    func calculate_movement_cost(distance: float, terrain_type: String) -> float:
        var terrain_effect = terrain_system.get_terrain_effect(terrain_type, "movement")
        return distance * terrain_effect.get("cost", 1.0)
    
    func can_dash(unit: Node) -> bool:
        # Check tutorial state for movement restrictions
        if parent_core_systems:
            var tutorial_state = parent_core_systems.tutorial_manager.get_tutorial_state()
            if tutorial_state and tutorial_state.is_active:
                return tutorial_state.current_step != "movement_basics"
        return true

# Core system variables
var tutorial_manager: TutorialManager
var weapon_system: WeaponTraitSystem
var terrain_system: TerrainSubsystem
var movement_system: MovementSystem

func _ready() -> void:
    tutorial_manager = TutorialManager.new()
    weapon_system = WeaponTraitSystem.new()
    terrain_system = TerrainSubsystem.new()
    movement_system = MovementSystem.new()
    movement_system.terrain_system = terrain_system
    movement_system.parent_core_systems = self