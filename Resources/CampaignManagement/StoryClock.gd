# StoryClock.gd
class_name StoryClock
extends Resource

enum GlobalEvent {
	MARKET_CRASH,
	WAR_OUTBREAK,
	PLAGUE_SPREAD,
	ALIEN_INVASION,
	REBELLION,
	TECH_BREAKTHROUGH,
	NATURAL_DISASTER
}

signal event_triggered
@export var ticks: int = 0
@export var event_type: GlobalEvent = GlobalEvent.MARKET_CRASH

func set_ticks(value: int) -> void:
	ticks = max(0, value)

func count_down(won_mission: bool) -> void:
	var decrease = 2 if won_mission else 1
	ticks = max(0, ticks - decrease)
	if is_event_triggered():
		event_triggered.emit()

func is_event_triggered() -> bool:
	return ticks <= 0

func generate_event() -> void:
	event_type = GlobalEvent.values()[randi() % GlobalEvent.size()]

func serialize() -> Dictionary:
	return {
		"ticks": ticks,
		"event_type": GlobalEvent.keys()[event_type]
	}

func deserialize(data: Dictionary) -> void:
	ticks = data.get("ticks", 0)
	if data.has("event_type"):
		event_type = GlobalEvent[data["event_type"]]

func _init(initial_ticks: int = 0) -> void:
	ticks = initial_ticks
	generate_event()
