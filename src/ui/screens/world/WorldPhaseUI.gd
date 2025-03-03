class_name WorldPhaseUI
extends Control

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const WorldManager := preload("res://src/game/world/GameWorldManager.gd")
const GameWorld := preload("res://src/game/world/GameWorld.gd")

signal phase_completed
signal phase_cancelled

@onready var world_info_panel: Control = $WorldInfoPanel
@onready var resource_panel: Control = $ResourcePanel
@onready var market_panel: Control = $MarketPanel
@onready var events_panel: Control = $EventsPanel

var world_manager: WorldManager
var current_world: GameWorld

func _ready() -> void:
    if not world_info_panel or not resource_panel or not market_panel or not events_panel:
        push_error("Required UI components not found in WorldPhaseUI")
        return

func initialize(data: Dictionary) -> void:
    world_manager = data.get("world_manager")
    current_world = world_manager.current_world if world_manager else null
    
    if not world_manager or not current_world:
        push_error("WorldPhaseUI initialization failed: missing required data")
        return
    
    _connect_signals()
    _update_ui()

func _connect_signals() -> void:
    if world_manager:
        world_manager.world_updated.connect(_on_world_updated)
        world_manager.economy_updated.connect(_on_economy_updated)
        world_manager.strife_level_changed.connect(_on_strife_level_changed)

func _update_ui() -> void:
    if not current_world:
        return
        
    # Update world info
    world_info_panel.update_info({
        "name": current_world.name,
        "environment": GameEnums.PlanetEnvironment.keys()[current_world.environment_type],
        "faction": GameEnums.FactionType.keys()[current_world.faction_type],
        "strife_level": GameEnums.StrifeType.keys()[current_world.strife_level],
        "world_features": current_world.world_features.map(func(f): return GameEnums.WorldTrait.keys()[f])
    })
    
    # Update resources
    var resources := {}
    for resource_type in current_world.resources:
        resources[GameEnums.ResourceType.keys()[resource_type]] = current_world.resources[resource_type]
    resource_panel.update_resources(resources)
    
    # Update market
    var market_data := {}
    for item_type in current_world.market_prices:
        market_data[GameEnums.ItemType.keys()[item_type]] = current_world.market_prices[item_type]
    market_panel.update_prices(market_data)
    
    # Update events
    events_panel.clear_events()
    if current_world.strife_level > GameEnums.StrifeType.NONE:
        events_panel.add_event({
            "type": "strife",
            "level": current_world.strife_level,
            "unity_progress": current_world.unity_progress
        })

func _on_world_updated(world: GameWorld) -> void:
    if world == current_world:
        _update_ui()

func _on_economy_updated(world: GameWorld, market_data: Dictionary) -> void:
    if world == current_world:
        var formatted_data := {}
        for item_type in market_data:
            formatted_data[GameEnums.ItemType.keys()[item_type]] = market_data[item_type]
        market_panel.update_prices(formatted_data)

func _on_strife_level_changed(world: GameWorld, new_level: int) -> void:
    if world == current_world:
        world_info_panel.update_strife_level(GameEnums.StrifeType.keys()[new_level])
        events_panel.update_strife_level(new_level)

func _on_complete_phase_pressed() -> void:
    phase_completed.emit()

func _on_cancel_phase_pressed() -> void:
    phase_cancelled.emit()

func cleanup() -> void:
    if world_manager:
        if world_manager.world_updated.is_connected(_on_world_updated):
            world_manager.world_updated.disconnect(_on_world_updated)
        if world_manager.economy_updated.is_connected(_on_economy_updated):
            world_manager.economy_updated.disconnect(_on_economy_updated)
        if world_manager.strife_level_changed.is_connected(_on_strife_level_changed):
            world_manager.strife_level_changed.disconnect(_on_strife_level_changed)