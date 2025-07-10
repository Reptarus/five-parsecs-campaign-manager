@tool
extends Resource
class_name PsionicPower

## Five Parsecs Psionic Power Definition
##
## Represents a single psionic power with its characteristics and effects
## following Five Parsecs From Home Core Rules.

const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")

enum PowerType {
    BARRIER, GRAB, LIFT, SHROUD, ENRAGE,
    PREDICT, SHOCK, REJUVENATE, GUIDE, PSIONIC_SCARE
}

@export var power_type: PowerType
@export var affects_robotic_targets: bool
@export var target_self: bool
@export var persists: bool
@export var description: String

# Static power data cache
static var _power_data_cache: Dictionary = {}
static var _is_data_loaded: bool = false

func _init(type: PowerType = PowerType.BARRIER, robotic: bool = false, self_target: bool = false, persistent: bool = false, desc: String = ""):
    self.power_type = type
    self.affects_robotic_targets = robotic
    self.target_self = self_target
    self.persists = persistent
    self.description = desc
    
    # Load data from JSON if not already loaded
    _load_power_data()
    _apply_power_data()

## Load psionic power data from JSON
static func _load_power_data() -> void:
    if _is_data_loaded:
        return
    
    _power_data_cache = UniversalResourceLoader.load_json_safe("res://data/psionic_powers.json", "Psionic Powers")
    _is_data_loaded = true

## Apply power-specific data from cache
func _apply_power_data() -> void:
    if not _is_data_loaded:
        _load_power_data()
    
    var power_name = PowerType.keys()[power_type].to_lower()
    var data = _power_data_cache.get(power_name, {})
    
    if data.size() > 0:
        affects_robotic_targets = data.get("affects_robotic_targets", false)
        target_self = data.get("target_self", false)
        persists = data.get("persists", false)
        description = data.get("description", _get_default_description())
    else:
        # Use default values if no data found
        _set_default_values()

## Set default values for power when no data is available
func _set_default_values() -> void:
    description = _get_default_description()
    # Set other defaults based on power type
    match power_type:
        PowerType.BARRIER:
            affects_robotic_targets = false
            target_self = true
            persists = true
        PowerType.GRAB, PowerType.LIFT:
            affects_robotic_targets = true
            target_self = false
            persists = false
        PowerType.SHOCK:
            affects_robotic_targets = false
            target_self = false
            persists = false
        _:
            affects_robotic_targets = false
            target_self = false
            persists = false

## Get default description for power type
func _get_default_description() -> String:
    match power_type:
        PowerType.BARRIER:
            return "Creates a protective barrier around the psionicist"
        PowerType.GRAB:
            return "Telekinetically grabs and manipulates objects"
        PowerType.LIFT:
            return "Lifts objects or characters with telekinetic force"
        PowerType.SHROUD:
            return "Creates a concealing shroud effect"
        PowerType.ENRAGE:
            return "Causes target to become enraged and hostile"
        PowerType.PREDICT:
            return "Grants precognitive insight into future events"
        PowerType.SHOCK:
            return "Delivers a psychic shock to the target"
        PowerType.REJUVENATE:
            return "Heals wounds and restores vitality"
        PowerType.GUIDE:
            return "Provides guidance and enhances accuracy"
        PowerType.PSIONIC_SCARE:
            return "Instills fear and panic in the target"
        _:
            return "Unknown psionic power"
