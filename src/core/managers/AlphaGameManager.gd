class_name AlphaGameManager
extends Node

## Alpha Game Manager - Integrates all systems for Five Parsecs Campaign Manager
## Manages the complete campaign turn flow with all new support systems

signal campaign_turn_started()
signal campaign_turn_completed()
signal system_error(message: String)

# Core systems
var enemy_generator # EnemyGenerator
var upkeep_system # UpkeepSystem
var trading_system # TradingSystem

# Current campaign data
var current_campaign: Resource = null
var current_mission: Resource = null
var current_enemies: Array[Resource] = []
var current_battle_result: Resource = null

# UI references
var main_game_scene: MainGameScene = null
var ui_manager: Node = null

func _ready() -> void:
	_initialize_systems()
	_setup_autoload_connections()

func _initialize_systems() -> void:
	"""Initialize all core game systems"""
	enemy_generator = preload("res://src/core/systems/EnemyGenerator.gd").new()
	upkeep_system = preload("res://src/core/systems/UpkeepSystem.gd").new()
	trading_system = preload("res://src/core/systems/TradingSystem.gd").new()
	
	# Connect system signals
	_connect_system_signals()
	
	print("Alpha Game Manager: All systems initialized")

func _connect_system_signals() -> void:
	"""Connect signals from all systems"""
	if enemy_generator:
		enemy_generator.enemies_generated.connect(_on_enemies_generated)
	
	if upkeep_system:
		upkeep_system.upkeep_calculated.connect(_on_upkeep_calculated)
		upkeep_system.upkeep_paid.connect(_on_upkeep_paid)
		upkeep_system.insufficient_funds.connect(_on_insufficient_funds)
	
	if trading_system:
		trading_system.market_generated.connect(_on_market_generated)
		trading_system.trade_completed.connect(_on_trade_completed)
		trading_system.trade_failed.connect(_on_trade_failed)

func _setup_autoload_connections() -> void:
	"""Setup connections with autoload systems"""
	# Connect to UI Manager if available
	ui_manager = get_node_or_null("/root/UIManager")
	if ui_manager and ui_manager.has_signal("scene_changed"):
		ui_manager.scene_changed.connect(_on_ui_scene_changed)

# ===== CAMPAIGN MANAGEMENT =====

func start_new_campaign(campaign_data: Resource) -> void:
	"""Start a new campaign with provided data"""
	current_campaign = campaign_data
	
	# Initialize campaign defaults
	_initialize_campaign_defaults()
	
	# Start first campaign turn
	campaign_turn_started.emit()
	print("Alpha Game Manager: New campaign started")

func _initialize_campaign_defaults() -> void:
	"""Set up default campaign values"""
	if not current_campaign:
		return
	
	# Set default credits if not set
	if not current_campaign.has_meta("credits"):
		current_campaign.set_meta("credits", 1000)
	
	# Initialize empty inventory if not set
	if not current_campaign.has_meta("inventory"):
		current_campaign.set_meta("inventory", [])
	
	# Set default living standard
	if not current_campaign.has_meta("living_standard"):
		current_campaign.set_meta("living_standard", "normal")
	
	# Initialize ship data if not set
	if not current_campaign.has_meta("ship_data"):
		var ship = Resource.new()
		ship.set_meta("hull_damage", 0)
		ship.set_meta("modifications", [])
		current_campaign.set_meta("ship_data", ship)

func load_campaign(campaign_data: Resource) -> void:
	"""Load an existing campaign"""
	current_campaign = campaign_data
	print("Alpha Game Manager: Campaign loaded")

# ===== MISSION MANAGEMENT =====

func generate_enemies_for_mission(mission: Resource) -> Array[Resource]:
	"""Generate enemies for the current mission"""
	if not enemy_generator:
		system_error.emit("Enemy generator not available")
		return []
	
	var crew_size = _get_crew_size()
	return enemy_generator.generate_enemies_for_mission(mission, crew_size)

func start_mission(mission: Resource) -> void:
	"""Start a mission and generate enemies"""
	current_mission = mission
	current_enemies = generate_enemies_for_mission(mission)
	print("Alpha Game Manager: Mission started - %s" % mission.get_meta("mission_type"))

func complete_mission(battle_result: Resource) -> void:
	"""Complete mission and apply results"""
	current_battle_result = battle_result
	
	# Apply battle results to campaign
	if battle_result and battle_result.has_method("get"):
		var victory = battle_result.victory if battle_result.has("victory") else false
		var credits_earned = battle_result.credits_earned if battle_result.has("credits_earned") else 0
		
		if victory:
			_apply_victory_rewards(credits_earned)
		else:
			_apply_defeat_consequences()
	
	# Clear current mission
	current_mission = null
	current_enemies.clear()

func _apply_victory_rewards(credits: int) -> void:
	"""Apply rewards for mission victory"""
	var current_credits = _get_campaign_credits()
	_set_campaign_credits(current_credits + credits)
	print("Alpha Game Manager: Victory! Earned %d credits" % credits)

func _apply_defeat_consequences() -> void:
	"""Apply consequences for mission defeat"""
	# TODO: Implement defeat consequences (injuries, lost equipment, etc.)
	print("Alpha Game Manager: Mission failed - applying consequences")

# ===== UPKEEP MANAGEMENT =====

func calculate_campaign_upkeep() -> Dictionary:
	"""Calculate upkeep for current campaign turn"""
	if not upkeep_system or not current_campaign:
		return {}
	
	return upkeep_system.calculate_upkeep_costs(current_campaign)

func pay_campaign_upkeep() -> bool:
	"""Attempt to pay campaign upkeep"""
	if not upkeep_system or not current_campaign:
		return false
	
	var upkeep_costs = calculate_campaign_upkeep()
	return upkeep_system.pay_upkeep(current_campaign, upkeep_costs)

# ===== TRADING MANAGEMENT =====

func generate_market(world_type: String = "frontier") -> Array[Resource]:
	"""Generate market for current world"""
	if not trading_system:
		system_error.emit("Trading system not available")
		return []
	
	return trading_system.generate_market(world_type)

func buy_item(item: Resource) -> bool:
	"""Buy an item from the market"""
	if not trading_system or not current_campaign:
		return false
	
	return trading_system.buy_item(item, current_campaign)

func sell_item(item: Resource) -> bool:
	"""Sell an item to the market"""
	if not trading_system or not current_campaign:
		return false
	
	return trading_system.sell_item(item, current_campaign)

# ===== CAMPAIGN TURN FLOW =====

func start_campaign_turn() -> void:
	"""Start a new campaign turn"""
	campaign_turn_started.emit()
	
	# Calculate upkeep at start of turn
	var upkeep_costs = calculate_campaign_upkeep()
	print("Alpha Game Manager: Campaign turn started. Upkeep: %d credits" % upkeep_costs.get("total", 0))

func complete_campaign_turn() -> void:
	"""Complete the current campaign turn"""
	# Apply end-of-turn effects
	_apply_end_turn_effects()
	
	campaign_turn_completed.emit()
	print("Alpha Game Manager: Campaign turn completed")

func _apply_end_turn_effects() -> void:
	"""Apply effects at end of campaign turn"""
	# Heal injured crew members
	_process_injury_recovery()
	
	# Apply any ongoing effects
	_process_ongoing_effects()

func _process_injury_recovery() -> void:
	"""Process injury recovery for crew members"""
	var crew_members = _get_crew_members()
	for crew_member in crew_members:
		if crew_member.has_method("get_meta") and crew_member.has_method("set_meta"):
			var recovery_time = crew_member.get_meta("recovery_time")
			if recovery_time > 0:
				crew_member.set_meta("recovery_time", recovery_time - 1)
				if recovery_time <= 1:
					crew_member.set_meta("injured", false)

func _process_ongoing_effects() -> void:
	"""Process ongoing campaign effects"""
	# Clear temporary effects
	if current_campaign and current_campaign.has_method("set_meta"):
		current_campaign.set_meta("luxury_bonus", false)

# ===== UTILITY FUNCTIONS =====

func _get_crew_size() -> int:
	"""Get current crew size"""
	var crew_members = _get_crew_members()
	return crew_members.size()

func _get_crew_members() -> Array[Resource]:
	"""Get crew members from campaign"""
	if current_campaign and current_campaign.has_method("get_meta"):
		var crew = current_campaign.get_meta("crew_members")
		return crew if crew != null else []
	return []

func _get_campaign_credits() -> int:
	"""Get current campaign credits"""
	if current_campaign and current_campaign.has_method("get_meta"):
		return current_campaign.get_meta("credits")
	return 0

func _set_campaign_credits(credits: int) -> void:
	"""Set campaign credits"""
	if current_campaign and current_campaign.has_method("set_meta"):
		current_campaign.set_meta("credits", credits)

# ===== SIGNAL HANDLERS =====

func _on_enemies_generated(enemies: Array[Resource]) -> void:
	"""Handle enemy generation completion"""
	current_enemies = enemies
	print("Alpha Game Manager: Generated %d enemies" % enemies.size())

func _on_upkeep_calculated(cost: int, breakdown: Dictionary) -> void:
	"""Handle upkeep calculation"""
	print("Alpha Game Manager: Upkeep calculated - %d credits" % cost)

func _on_upkeep_paid(remaining_credits: int) -> void:
	"""Handle successful upkeep payment"""
	print("Alpha Game Manager: Upkeep paid - %d credits remaining" % remaining_credits)

func _on_insufficient_funds(required: int, available: int) -> void:
	"""Handle insufficient funds for upkeep"""
	print("Alpha Game Manager: Insufficient funds - need %d, have %d" % [required, available])
	
	# Apply upkeep failure consequences
	if upkeep_system:
		var consequences = upkeep_system.handle_upkeep_failure(current_campaign)
		print("Alpha Game Manager: Upkeep failure consequences applied")

func _on_market_generated(items: Array[Resource]) -> void:
	"""Handle market generation"""
	print("Alpha Game Manager: Market generated with %d items" % items.size())

func _on_trade_completed(item: Resource, transaction_type: String, credits: int) -> void:
	"""Handle successful trade"""
	var item_name = item.get_meta("name") if item.has_method("get_meta") else "Unknown"
	print("Alpha Game Manager: %s completed - %s for %d credits" % [transaction_type, item_name, credits])

func _on_trade_failed(reason: String) -> void:
	"""Handle failed trade"""
	print("Alpha Game Manager: Trade failed - %s" % reason)

func _on_ui_scene_changed(scene_name: String) -> void:
	"""Handle UI scene changes"""
	print("Alpha Game Manager: UI scene changed to %s" % scene_name)

# ===== PUBLIC API =====

func get_current_campaign() -> Resource:
	"""Get current campaign data"""
	return current_campaign

func get_current_mission() -> Resource:
	"""Get current mission data"""
	return current_mission

func get_current_enemies() -> Array[Resource]:
	"""Get current enemies"""
	return current_enemies

func get_enemy_generator() -> EnemyGenerator:
	"""Get enemy generator system"""
	return enemy_generator

func get_upkeep_system():
	"""Get upkeep system"""
	return upkeep_system

func get_trading_system():
	"""Get trading system"""
	return trading_system

func is_campaign_active() -> bool:
	"""Check if a campaign is currently active"""
	return current_campaign != null