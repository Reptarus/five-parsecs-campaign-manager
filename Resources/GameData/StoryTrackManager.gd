class_name StoryTrackManager
extends Node

signal story_event_triggered(event_id: String)
signal story_clock_updated(ticks: int)
signal companion_status_changed(companion: Dictionary)

var current_event: Dictionary
var story_clock: int = 5  # Start with 5 ticks as per Core Rules
var story_state: Dictionary = {}

# Based on Core Rules Story Track (p.153-162)
const STORY_EVENTS := {
    "event_1": {
        "title": "Foiled!",
        "description": "The captain was excited this morning. A big job lined up...",
        "required_setup": {
            "patron_search": true,
            "no_rival_tracking": true
        },
        "battle_setup": {
            "enemy_count": 6,
            "enemy_type": "hired_guns",
            "deployment": "ambush",
            "special_rules": ["no_initiative"]
        },
        "next_clock": 3,
        "rewards": {
            "victory": {
                "credits": "normal",
                "story_points": 0
            },
            "hold_field": {
                "battlefield_find": true
            }
        }
    },
    "event_2": {
        "title": "On the Trail",
        "description": "Your snooping around has paid off. Q'narr, a smuggler and petty crook...",
        "battle_setup": {
            "enemy_type": "blood_storm_mercs",
            "min_enemies": 4,
            "special_rules": ["interrogation"]
        },
        "next_clock": 2,
        "travel_required": true,
        "rewards": {
            "brawl_capture": {
                "story_points": 1
            }
        }
    },
    "event_3": {
        "title": "Disrupting the Plan",
        "description": "Your old friend is up to something big...",
        "required_setup": {
            "no_patron": true,
            "no_rival_tracking": true,
            "planner_required": true
        },
        "battle_setup": {
            "enemy_setup": "compound",
            "enemy_count": 8,
            "objective": "plant_device",
            "reinforcements": {
                "round_8": 2,
                "round_12": 2
            }
        },
        "next_clock": 5,
        "rewards": {
            "victory": {
                "loot_rolls": 1
            }
        }
    },
    "event_4": {
        "title": "The Enemy Strikes Back",
        "description": "A direct attack on your ship, while docked in port...",
        "battle_setup": {
            "enemy_groups": 2,
            "enemy_type": "hired_muscle",
            "deployment": "ship_defense",
            "special_rules": ["impaired_allowed"]
        },
        "next_clock": 3,
        "rewards": {
            "hold_field": {
                "bonus_xp": 1,
                "battlefield_finds": 2,
                "remove_rival": true
            },
            "failure": {
                "ship_damage": "1D6+10"
            }
        }
    },
    "event_5": {
        "title": "Kidnap",
        "description": "Not content with trying to kill you, Q'Narr has gone after another...",
        "required_setup": {
            "immediate_travel": true,
            "max_crew": 4
        },
        "battle_setup": {
            "search_markers": 6,
            "war_bots": true,
            "evidence_required": true
        },
        "next_clock": "evidence_based",
        "rewards": {
            "upkeep_covered": true
        }
    },
    "event_6": {
        "title": "We're Coming!",
        "description": "You have managed to track down where they are holding your friend...",
        "battle_setup": {
            "enemy_type": "hired_muscle",
            "enemy_count": "base_5",
            "deployment": "stealth",
            "captive_rescue": true,
            "preparation_time": {
                "penalty": 1,
                "per_turn": 1
            }
        },
        "next_clock": 2
    },
    "event_7": {
        "title": "Time to Settle This",
        "description": "This is it. You've managed to track your old rival to his hide-out...",
        "required_setup": {
            "max_delay": 3,
            "travel_required": true,
            "special_location": "moon_base"
        },
        "battle_setup": {
            "terrain": "moonscape",
            "armor": "atmosphere_suits",
            "enemy_setup": "compound",
            "nemesis": true
        },
        "rewards": {
            "victory": {
                "xp": 1,
                "story_points": 3,
                "credits": "1D6+2",
                "loot_rolls": 3,
                "remove_rival": true
            }
        }
    }
}

func _ready() -> void:
    setup_initial_event()

func setup_initial_event() -> void:
    story_clock = 5
    current_event = STORY_EVENTS["event_1"]
    story_event_triggered.emit("event_1")

func update_clock(mission_won: bool) -> void:
    if mission_won:
        story_clock -= 1
    else:
        var roll := randi() % 6 + 1
        match roll:
            1: pass  # Clock doesn't count down
            2,3,4,5: story_clock -= 1
            6: story_clock -= 2
    
    story_clock_updated.emit(story_clock)
    
    if story_clock <= 0:
        trigger_next_event()

func trigger_next_event() -> void:
    var next_event_id := ""
    
    match current_event.get("id", ""):
        "event_1":
            next_event_id = "event_2"
        "event_2":
            next_event_id = "event_3"
        "event_3":
            next_event_id = "event_4"
        "event_4":
            next_event_id = "event_5"
        "event_5":
            # Special case - requires evidence collection
            if story_state.get("evidence_found", 0) >= 3:
                next_event_id = "event_6"
            else:
                return
        "event_6":
            next_event_id = "event_7"
        "event_7":
            _complete_story_track()
            return
    
    if next_event_id:
        current_event = STORY_EVENTS[next_event_id]
        current_event["id"] = next_event_id
        story_clock = current_event.get("next_clock", 5)
        story_event_triggered.emit(next_event_id)

func _complete_story_track() -> void:
    story_state["completed"] = true
    story_event_triggered.emit("story_complete")

# Add helper functions for specific event mechanics
func check_evidence_requirements() -> bool:
    var evidence_count: int = story_state.get("evidence_found", 0) as int
    if evidence_count >= 3:
        return true
        
    var roll: int = 1 + evidence_count + (randi() % 6)
    return roll >= 7

func handle_preparation_time() -> void:
    var prep_time = story_state.get("preparation_time", 0)
    if prep_time > 3:
        story_state["enemy_reinforcements"] = prep_time - 3

func get_event_rewards(event_id: String, outcome: String) -> Dictionary:
    var event = STORY_EVENTS.get(event_id, {})
    return event.get("rewards", {}).get(outcome, {})

func get_current_event_requirements() -> Dictionary:
    return current_event.get("required_setup", {})

func get_battle_setup() -> Dictionary:
    return current_event.get("battle_setup", {})

func handle_stealth_detection() -> bool:
    # Based on Core Rules stealth mechanics
    var detection_range: int = 6  # Base detection range in inches
    var alert_level: int = story_state.get("alert_level", 0)
    
    if alert_level > 0:
        detection_range += 2 * alert_level
    
    return detection_range

func trigger_alert(reason: String) -> void:
    var current_alert: int = story_state.get("alert_level", 0)
    story_state["alert_level"] = current_alert + 1
    
    match reason:
        "gunfire":
            story_state["alert_level"] += 1  # Extra alert level for gunfire
        "spotted":
            # Standard alert
            pass
        "body_found":
            story_state["alert_level"] += 2  # Major alert 

enum EvidenceType {
    CLUE,
    WITNESS_STATEMENT,
    PHYSICAL_EVIDENCE
}

func add_evidence(type: EvidenceType) -> void:
    var current_evidence: int = story_state.get("evidence_found", 0)
    story_state["evidence_found"] = current_evidence + 1
    
    # Special bonuses based on evidence type
    match type:
        EvidenceType.PHYSICAL_EVIDENCE:
            story_state["evidence_quality"] = story_state.get("evidence_quality", 0) + 2
        EvidenceType.WITNESS_STATEMENT:
            story_state["witness_available"] = true
        EvidenceType.CLUE:
            story_state["search_bonus"] = story_state.get("search_bonus", 0) + 1

func check_search_location(marker_id: int) -> Dictionary:
    var search_bonus: int = story_state.get("search_bonus", 0)
    var roll: int = (randi() % 6 + 1) + search_bonus
    
    if roll >= 5:
        var evidence_type: EvidenceType = EvidenceType.values()[randi() % EvidenceType.size()]
        add_evidence(evidence_type)
        return {
            "success": true,
            "type": evidence_type
        }
    return {
        "success": false
    }

func handle_companion_status(rescued: bool = false) -> void:
    if rescued:
        story_state["companion_rescued"] = true
        story_state["companion_status"] = "rescued"
        
        # Core Rules p.161 - Companion offers to join after Event 7
        if current_event.get("id") == "event_7":
            story_state["companion_joins"] = true
            companion_status_changed.emit({
                "status": "joins",
                "permanent": true,
                "no_upkeep": true
            })
    else:
        story_state["companion_status"] = "captured"
        # Will be rescued after Event 7
        story_state["delayed_rescue"] = true

func calculate_ship_damage(damage_spec: String) -> int:
    # Parse damage specifications like "1D6+10"
    var parts := damage_spec.split("+")
    var base_damage: int = 0
    
    if parts[0] == "1D6":
        base_damage = randi() % 6 + 1
    
    if parts.size() > 1:
        base_damage += parts[1].to_int()
        
    return base_damage

func apply_ship_damage(amount: int) -> void:
    story_state["ship_damage"] = story_state.get("ship_damage", 0) + amount
    
    # Emergency takeoff damage (Core Rules p.158)
    if story_state.get("emergency_takeoff", false):
        var emergency_damage: int = randi() % 6 + randi() % 6 + randi() % 6  # 3D6
        story_state["ship_damage"] += emergency_damage