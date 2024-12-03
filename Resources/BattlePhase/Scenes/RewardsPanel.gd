extends PanelContainer

signal loot_rolled
signal status_rolled

@onready var base_payment_label: Label = %BasePaymentLabel
@onready var objective_bonus_label: Label = %ObjectiveBonusLabel
@onready var battlefield_bonus_label: Label = %BattlefieldBonusLabel
@onready var total_label: Label = %TotalLabel
@onready var loot_list: RichTextLabel = %LootList
@onready var status_list: RichTextLabel = %StatusList
@onready var roll_loot_button: Button = %RollLootButton
@onready var roll_status_button: Button = %RollStatusButton

var game_state_manager: Node
var total_payout: int = 0
var loot_items: Array = []

func _ready() -> void:
	game_state_manager = get_node("/root/GameStateManager")
	calculate_rewards()

func calculate_rewards() -> void:
	var victory = game_state_manager.game_state.current_mission.is_completed()
	
	# Calculate base payout using PostBattlePhase.gd formula
	var base_payout = 500
	var difficulty_multiplier = game_state_manager.game_state.difficulty_settings.battle_difficulty * 0.5
	var performance_bonus = 200 if victory else 0
	var casualties_penalty = game_state_manager.game_state.enemies_defeated_count * -50
	
	total_payout = int(base_payout + (base_payout * difficulty_multiplier) + performance_bonus + casualties_penalty)
	
	# Update labels
	base_payment_label.text = "Base Payment: %d" % base_payout
	objective_bonus_label.text = "Objective Bonus: %d" % performance_bonus
	battlefield_bonus_label.text = "Battlefield Bonus: %d" % (base_payout * difficulty_multiplier)
	total_label.text = "Total: %d" % total_payout

func _on_roll_loot_pressed() -> void:
	roll_loot_button.disabled = true
	var finds = generate_battlefield_finds()
	loot_items.clear()
	loot_list.clear()
	
	for item in finds:
		if _try_add_to_inventory(item):
			loot_items.append(item)
			loot_list.append_text("• %s (Added to inventory)\n" % item)
		else:
			loot_list.append_text("• %s (Inventory full!)\n" % item)
	
	loot_rolled.emit()

func _on_roll_status_pressed() -> void:
	roll_status_button.disabled = true
	var patron = game_state_manager.game_state.current_mission.patron
	var reputation_change = 1 if game_state_manager.game_state.current_mission.is_completed() else -1
	
	status_list.clear()
	status_list.append_text("• Patron: %s - Reputation %s\n" % [
		patron.name, 
		"Increased" if reputation_change > 0 else "Decreased"
	])
	
	patron.adjust_reputation(reputation_change)
	status_rolled.emit()

func _try_add_to_inventory(item: LootItem) -> bool:
	var ship_inventory = game_state_manager.game_state.current_ship.inventory
	return ship_inventory.add_item(item)

func generate_battlefield_finds() -> Array:
	var finds = []
	var possible_finds = ["Ammo Cache", "Medical Supplies", "Scrap Metal", "Alien Artifact", "Abandoned Equipment"]
	var num_finds = randi() % 3 + 1
	
	for _i in range(num_finds):
		var item_name = possible_finds[randi() % possible_finds.size()]
		var item = LootItem.new()
		item.name = item_name
		item.weight = randf_range(1.0, 5.0)
		item.value = randi_range(50, 200)
		finds.append(item)
	
	return finds

func finalize_rewards() -> void:
	game_state_manager.game_state.credits += total_payout

class LootItem:
	var name: String
	var weight: float
	var value: int
	
	func _init(item_name: String = "", item_weight: float = 1.0, item_value: int = 0) -> void:
		name = item_name
		weight = item_weight
		value = item_value
