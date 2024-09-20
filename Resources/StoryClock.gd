# StoryClock.gd
class_name StoryClock
extends Resource

var ticks: int = 0

func set_ticks(value: int):
    ticks = value

func count_down(won_mission: bool):
    ticks -= 2 if won_mission else 1

func is_event_triggered() -> bool:
    return ticks <= 0

func serialize() -> Dictionary:
    return {
        "ticks": ticks
    }

static func deserialize(data: Dictionary) -> StoryClock:
    var clock = StoryClock.new()
    clock.set_ticks(data.get("ticks", 0))
    return clock