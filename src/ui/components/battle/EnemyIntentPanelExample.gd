extends Control

## Example usage of EnemyIntentPanel
## This demonstrates how to populate and update the panel

@onready var intent_panel: EnemyIntentPanel = $EnemyIntentPanel

func _ready() -> void:
	# Connect signals
	intent_panel.intent_revealed.connect(_on_intent_revealed)
	intent_panel.target_highlighted.connect(_on_target_highlighted)

	# Set AI behavior type
	intent_panel.set_ai_behavior_type("Aggressive")

	# Example: Set initial enemy intents
	var example_intents: Array = [
		{
			"enemy_id": "enemy_1",
			"enemy_name": "Raider Captain",
			"type": EnemyIntentPanel.IntentType.ATTACK,
			"target_id": "player_1",
			"target_name": "Captain Nash"
		},
		{
			"enemy_id": "enemy_2",
			"enemy_name": "Raider Scout",
			"type": EnemyIntentPanel.IntentType.MOVE,
			"target_id": "cover_3",
			"target_name": "Cover Alpha"
		},
		{
			"enemy_id": "enemy_3",
			"enemy_name": "Raider Heavy",
			"type": EnemyIntentPanel.IntentType.DEFEND,
			"target_id": "",
			"target_name": ""
		}
	]

	intent_panel.set_enemy_intents(example_intents)

func _on_intent_revealed(enemy_id: String, intent: Dictionary) -> void:
	print("Intent revealed for %s: %s" % [enemy_id, intent])

func _on_target_highlighted(target_id: String) -> void:
	print("Target highlighted: %s" % target_id)
	# In a real implementation, you would highlight the target on the battlefield

# Example: Update a specific enemy's intent during battle
func _on_enemy_turn_changed(enemy_id: String) -> void:
	# Example: Enemy changes from moving to attacking
	intent_panel.update_enemy_intent(
		enemy_id,
		EnemyIntentPanel.IntentType.ATTACK,
		"player_2",
		"Crew Member Delta"
	)
