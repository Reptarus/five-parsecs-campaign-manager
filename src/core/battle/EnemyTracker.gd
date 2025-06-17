@tool
class_name FPCM_EnemyTracker
extends Control

## Enemy Tracker - Tabletop Assistant Style
##
## Simple enemy status tracking that stays true to tabletop game assistance.
## Tracks activation, health, and position without being a video game.
##
## Features:
## - Simple status indicators (active/inactive/down)
## - Health tracking with visual indicators
## - Activation sequence management
## - Position reference (not movement automation)

# Signals
signal enemy_activated(enemy_id: String)
signal enemy_status_changed(enemy_id: String, old_status: String, new_status: String)
signal all_enemies_activated()
signal turn_reset_requested()

# UI Components
@onready var enemy_list: VBoxContainer = $ScrollContainer/EnemyList
@onready var turn_control: HBoxContainer = $TurnControl
@onready var activation_button: Button = $TurnControl/NextActivation
@onready var reset_button: Button = $TurnControl/ResetTurn

# Enemy data
var enemies: Dictionary = {}
var activation_order: Array[String] = []
var current_activation_index: int = 0
var turn_complete: bool = false

# Visual settings
var status_colors = {
	"active": Color.GREEN,
	"inactive": Color.GRAY,
	"stunned": Color.YELLOW,
	"down": Color.RED,
	"removed": Color.BLACK
}

func _ready():
	_setup_ui()
	_connect_signals()

## Setup UI components
func _setup_ui() -> void:
	activation_button.text = "Next Enemy"
	reset_button.text = "Reset Turn"
	
	# Set minimum size for the tracker
	custom_minimum_size = Vector2(250, 400)

## Connect UI signals
func _connect_signals() -> void:
	activation_button.pressed.connect(_on_next_activation_pressed)
	reset_button.pressed.connect(_on_reset_turn_pressed)

## Add enemy to tracking system
func add_enemy(enemy_id: String, enemy_data: Dictionary) -> void:
	var enemy_info = {
		"id": enemy_id,
		"name": enemy_data.get("name", "Enemy " + enemy_id),
		"type": enemy_data.get("type", "Basic"),
		"health": enemy_data.get("health", 1),
		"max_health": enemy_data.get("max_health", 1),
		"toughness": enemy_data.get("toughness", 3),
		"status": "inactive",
		"position_ref": enemy_data.get("position_ref", ""),
		"special_rules": enemy_data.get("special_rules", []),
		"activated_this_turn": false
	}
	
	enemies[enemy_id] = enemy_info
	activation_order.append(enemy_id)
	_create_enemy_display(enemy_info)
	_update_activation_controls()

## Remove enemy from tracking
func remove_enemy(enemy_id: String) -> void:
	if enemy_id in enemies:
		enemies.erase(enemy_id)
		activation_order.erase(enemy_id)
		_remove_enemy_display(enemy_id)
		_update_activation_controls()

## Update enemy health
func update_enemy_health(enemy_id: String, new_health: int) -> void:
	if enemy_id not in enemies:
		return
	
	var enemy = enemies[enemy_id]
	var old_status = enemy.status
	
	enemy.health = max(0, new_health)
	
	# Update status based on health
	if enemy.health <= 0 and enemy.status != "down":
		enemy.status = "down"
		enemy_status_changed.emit(enemy_id, old_status, "down")
	elif enemy.health > 0 and enemy.status == "down":
		enemy.status = "inactive"
		enemy_status_changed.emit(enemy_id, old_status, "inactive")
	
	_update_enemy_display(enemy_id)

## Update enemy status manually
func update_enemy_status(enemy_id: String, new_status: String) -> void:
	if enemy_id not in enemies:
		return
	
	var enemy = enemies[enemy_id]
	var old_status = enemy.status
	
	enemy.status = new_status
	enemy_status_changed.emit(enemy_id, old_status, new_status)
	_update_enemy_display(enemy_id)

## Activate next enemy in sequence
func activate_next_enemy() -> String:
	if current_activation_index >= activation_order.size():
		_complete_turn()
		return ""
	
	var enemy_id = activation_order[current_activation_index]
	var enemy = enemies.get(enemy_id, {})
	
	# Skip enemies that are down or removed
	if enemy.get("status", "") in ["down", "removed"]:
		current_activation_index += 1
		return activate_next_enemy()
	
	# Activate the enemy
	_activate_enemy(enemy_id)
	current_activation_index += 1
	
	return enemy_id

## Reset turn for new activation sequence
func reset_turn() -> void:
	current_activation_index = 0
	turn_complete = false
	
	# Reset all enemy activation status
	for enemy_id in enemies:
		enemies[enemy_id].activated_this_turn = false
		if enemies[enemy_id].status == "active":
			enemies[enemy_id].status = "inactive"
	
	_update_all_displays()
	_update_activation_controls()
	turn_reset_requested.emit()

## Get current enemy status summary
func get_status_summary() -> Dictionary:
	var summary = {
		"total": enemies.size(),
		"active": 0,
		"inactive": 0,
		"down": 0,
		"stunned": 0,
		"removed": 0
	}
	
	for enemy_id in enemies:
		var status = enemies[enemy_id].status
		if status in summary:
			summary[status] += 1
	
	return summary

## Get next enemy to activate (for preview)
func get_next_enemy() -> Dictionary:
	if current_activation_index >= activation_order.size():
		return {}
	
	var enemy_id = activation_order[current_activation_index]
	return enemies.get(enemy_id, {})

## Private helper methods

func _activate_enemy(enemy_id: String) -> void:
	if enemy_id not in enemies:
		return
	
	var enemy = enemies[enemy_id]
	enemy.status = "active"
	enemy.activated_this_turn = true
	
	_update_enemy_display(enemy_id)
	enemy_activated.emit(enemy_id)

func _complete_turn() -> void:
	turn_complete = true
	_update_activation_controls()
	all_enemies_activated.emit()

func _create_enemy_display(enemy_info: Dictionary) -> void:
	# Create simple enemy panel (can be enhanced later with custom scenes)
	var enemy_panel = _create_simple_enemy_panel(enemy_info)
	enemy_panel.name = "Enemy_" + enemy_info.id
	enemy_list.add_child(enemy_panel)

func _create_simple_enemy_panel(enemy_info: Dictionary) -> Control:
	var panel = Panel.new()
	var vbox = VBoxContainer.new()
	
	# Enemy name and type
	var name_label = Label.new()
	name_label.text = enemy_info.name + " (" + enemy_info.type + ")"
	vbox.add_child(name_label)
	
	# Health display
	var health_label = Label.new()
	health_label.text = "Health: " + str(enemy_info.health) + "/" + str(enemy_info.max_health)
	health_label.name = "HealthLabel"
	vbox.add_child(health_label)
	
	# Status indicator
	var status_label = Label.new()
	status_label.text = "Status: " + enemy_info.status.capitalize()
	status_label.name = "StatusLabel"
	vbox.add_child(status_label)
	
	# Position reference
	if enemy_info.position_ref != "":
		var pos_label = Label.new()
		pos_label.text = "Position: " + enemy_info.position_ref
		pos_label.name = "PositionLabel"
		vbox.add_child(pos_label)
	
	panel.add_child(vbox)
	panel.custom_minimum_size = Vector2(200, 80)
	return panel

func _remove_enemy_display(enemy_id: String) -> void:
	var panel = enemy_list.get_node_or_null("Enemy_" + enemy_id)
	if panel:
		panel.queue_free()

func _update_enemy_display(enemy_id: String) -> void:
	var panel = enemy_list.get_node_or_null("Enemy_" + enemy_id)
	if not panel:
		return
	
	var enemy = enemies[enemy_id]
	
	# Update health label
	var health_label = panel.get_node_or_null("VBoxContainer/HealthLabel")
	if health_label:
		health_label.text = "Health: " + str(enemy.health) + "/" + str(enemy.max_health)
	
	# Update status label and color
	var status_label = panel.get_node_or_null("VBoxContainer/StatusLabel")
	if status_label:
		status_label.text = "Status: " + enemy.status.capitalize()
		status_label.modulate = status_colors.get(enemy.status, Color.WHITE)
	
	# Update panel background based on status
	if panel is Panel:
		var style = StyleBoxFlat.new()
		style.bg_color = status_colors.get(enemy.status, Color.WHITE)
		style.bg_color.a = 0.2 # Make it subtle
		panel.add_theme_stylebox_override("panel", style)

func _update_all_displays() -> void:
	for enemy_id in enemies:
		_update_enemy_display(enemy_id)

func _update_activation_controls() -> void:
	if turn_complete:
		activation_button.text = "Turn Complete"
		activation_button.disabled = true
	else:
		var next_enemy = get_next_enemy()
		if next_enemy.is_empty():
			activation_button.text = "No More Enemies"
			activation_button.disabled = true
		else:
			activation_button.text = "Activate: " + next_enemy.get("name", "Unknown")
			activation_button.disabled = false

## Signal handlers
func _on_next_activation_pressed() -> void:
	activate_next_enemy()
	_update_activation_controls()

func _on_reset_turn_pressed() -> void:
	reset_turn()

## Export methods for integration with battle system
func export_enemy_data() -> Dictionary:
	return {
		"enemies": enemies.duplicate(),
		"activation_order": activation_order.duplicate(),
		"current_activation": current_activation_index,
		"turn_complete": turn_complete
	}

func import_enemy_data(data: Dictionary) -> void:
	enemies = data.get("enemies", {})
	activation_order = data.get("activation_order", [])
	current_activation_index = data.get("current_activation", 0)
	turn_complete = data.get("turn_complete", false)
	
	_rebuild_display()

func _rebuild_display() -> void:
	# Clear existing displays
	for child in enemy_list.get_children():
		child.queue_free()
	
	# Recreate displays
	for enemy_id in enemies:
		_create_enemy_display(enemies[enemy_id])
	
	_update_activation_controls()