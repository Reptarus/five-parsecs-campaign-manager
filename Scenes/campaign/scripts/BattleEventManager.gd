class_name BattleEventManager
extends Resource

enum EventType {
	CRITICAL_HIT,
	WEAPON_MALFUNCTION,
	REINFORCEMENTS,
	ENVIRONMENTAL_HAZARD,
	MORALE_BOOST,
	MORALE_DROP,
	TACTICAL_ADVANTAGE,
	ENEMY_MISTAKE,
	UNEXPECTED_ALLY,
	EQUIPMENT_FAILURE,
	HEROIC_MOMENT,
	LUCKY_DODGE,
	AMMO_SHORTAGE,
	COVER_DESTROYED,
	ENEMY_SURRENDER,
	FRIENDLY_FIRE,
	SNIPER_SHOT,
	MELEE_CLASH,
	GRENADE_THROW,
	MEDICAL_EMERGENCY
}

var game_state: GameState

func _init(_game_state: GameState):
	game_state = _game_state

func generate_event() -> Dictionary:
	var event_type = EventType.values()[randi() % EventType.size()]
	return _create_event(event_type)

func _create_event(event_type: EventType) -> Dictionary:
	var event = {
		"type": event_type,
		"description": "",
		"effect": {}
	}
	
	match event_type:
		EventType.CRITICAL_HIT:
			event.description = "A well-aimed shot finds a weak spot!"
			event.effect = {"damage": 2, "target": "enemy"}
		EventType.WEAPON_MALFUNCTION:
			event.description = "A weapon jams at a critical moment."
			event.effect = {"disable_weapon": true, "target": "player"}
		EventType.REINFORCEMENTS:
			event.description = "Additional forces arrive on the battlefield."
			event.effect = {"add_units": randi() % 3 + 1, "target": "enemy"}
		EventType.ENVIRONMENTAL_HAZARD:
			event.description = "The environment becomes more dangerous."
			event.effect = {"damage": 1, "target": "all"}
		EventType.MORALE_BOOST:
			event.description = "The team's spirits are lifted!"
			event.effect = {"morale_boost": true, "target": "player"}
		EventType.MORALE_DROP:
			event.description = "The enemy's morale falters."
			event.effect = {"morale_drop": true, "target": "enemy"}
		EventType.TACTICAL_ADVANTAGE:
			event.description = "A tactical opportunity presents itself."
			event.effect = {"bonus_action": true, "target": "player"}
		EventType.ENEMY_MISTAKE:
			event.description = "The enemy makes a costly error."
			event.effect = {"penalty": true, "target": "enemy"}
		EventType.UNEXPECTED_ALLY:
			event.description = "An unexpected ally joins the fray."
			event.effect = {"add_units": 1, "target": "player"}
		EventType.EQUIPMENT_FAILURE:
			event.description = "A piece of equipment malfunctions."
			event.effect = {"disable_item": true, "target": "player"}
		EventType.HEROIC_MOMENT:
			event.description = "A team member performs a heroic act!"
			event.effect = {"bonus_action": true, "extra_damage": 1, "target": "player"}
		EventType.LUCKY_DODGE:
			event.description = "An attack is miraculously avoided."
			event.effect = {"avoid_damage": true, "target": "player"}
		EventType.AMMO_SHORTAGE:
			event.description = "Ammunition runs low."
			event.effect = {"reduce_attacks": 1, "target": "player"}
		EventType.COVER_DESTROYED:
			event.description = "Cover is blown apart by enemy fire."
			event.effect = {"remove_cover": true, "target": "all"}
		EventType.ENEMY_SURRENDER:
			event.description = "Some enemy units surrender!"
			event.effect = {"remove_units": randi() % 2 + 1, "target": "enemy"}
		EventType.FRIENDLY_FIRE:
			event.description = "In the chaos, friendly fire occurs."
			event.effect = {"damage": 1, "target": "player"}
		EventType.SNIPER_SHOT:
			event.description = "A precision shot from a hidden position."
			event.effect = {"damage": 3, "target": "random"}
		EventType.MELEE_CLASH:
			event.description = "Close-quarters combat erupts."
			event.effect = {"melee_bonus": true, "target": "all"}
		EventType.GRENADE_THROW:
			event.description = "A grenade is tossed into the fray!"
			event.effect = {"aoe_damage": 2, "target": "random"}
		EventType.MEDICAL_EMERGENCY:
			event.description = "A team member requires immediate medical attention."
			event.effect = {"require_medic": true, "target": "player"}
	
	return event

func apply_event(event: Dictionary, player_team: Array, enemy_team: Array) -> void:
	match event.effect.target:
		"player":
			_apply_to_team(event.effect, player_team)
		"enemy":
			_apply_to_team(event.effect, enemy_team)
		"all":
			_apply_to_team(event.effect, player_team)
			_apply_to_team(event.effect, enemy_team)
		"random":
			if randf() > 0.5:
				_apply_to_team(event.effect, player_team)
			else:
				_apply_to_team(event.effect, enemy_team)

func _apply_to_team(effect: Dictionary, team: Array) -> void:
	if "damage" in effect:
		for unit in team:
			unit.take_damage(effect.damage)
	if "disable_weapon" in effect:
		var random_unit = team[randi() % team.size()]
		random_unit.disable_weapon()
	if "add_units" in effect:
		for i in range(effect.add_units):
			team.append(game_state.character_generator.generate_character())
	if "morale_boost" in effect:
		for unit in team:
			unit.boost_morale()
	if "morale_drop" in effect:
		for unit in team:
			unit.lower_morale()
	if "bonus_action" in effect:
		var random_unit = team[randi() % team.size()]
		random_unit.grant_bonus_action()
	if "penalty" in effect:
		var random_unit = team[randi() % team.size()]
		random_unit.apply_penalty()
	if "disable_item" in effect:
		var random_unit = team[randi() % team.size()]
		random_unit.disable_random_item()
	if "avoid_damage" in effect:
		var random_unit = team[randi() % team.size()]
		random_unit.avoid_next_damage()
	if "reduce_attacks" in effect:
		for unit in team:
			unit.reduce_attacks(effect.reduce_attacks)
	if "remove_cover" in effect:
		for unit in team:
			unit.remove_cover()
	if "remove_units" in effect:
		for i in range(min(effect.remove_units, team.size())):
			team.pop_back()
	if "melee_bonus" in effect:
		for unit in team:
			unit.grant_melee_bonus()
	if "aoe_damage" in effect:
		for unit in team:
			unit.take_damage(effect.aoe_damage)
	if "require_medic" in effect:
		var random_unit = team[randi() % team.size()]
		random_unit.require_medical_attention()
