# StoryClock.gd
class_name StoryClock
extends Resource

signal event_triggered

@export var ticks: int = 0
@export var event_type: GlobalEnums.StrifeType = GlobalEnums.StrifeType.RESOURCE_CONFLICT

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
	event_type = GlobalEnums.StrifeType.values()[randi() % GlobalEnums.StrifeType.size()]

func serialize() -> Dictionary:
	return {
		"ticks": ticks,
		"event_type": GlobalEnums.StrifeType.keys()[event_type]
	}

static func deserialize(data: Dictionary) -> StoryClock:
	var clock = StoryClock.new()
	clock.set_ticks(data.get("ticks", 0))
	if data.has("event_type"):
		clock.event_type = GlobalEnums.StrifeType[data["event_type"]]
	return clock

func _init(initial_ticks: int = 0) -> void:
	ticks = initial_ticks
	generate_event()
