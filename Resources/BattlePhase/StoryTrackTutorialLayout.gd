class_name StoryTrackTutorialLayout
extends Resource

# Based on Appendix V from Core Rules
const STORY_TRACK_TUTORIAL := {
    "introduction": {
        "grid_size": Vector2i(15, 15),
        "player_start": Vector2(2, 7),
        "terrain": [
            # Basic cover setup for initial story mission
            {"type": "COVER", "position": Vector2(4, 7)},
            {"type": "COVER", "position": Vector2(7, 7)},
            {"type": "BUILDING", "position": Vector2(10, 7)},
            {"type": "ELEVATED", "position": Vector2(7, 4)}
        ],
        "objectives": [
            {"type": "STORY_POINT", "position": Vector2(13, 7), "description": "Investigate the mysterious signal"}
        ],
        "enemies": [
            {"type": "Basic", "position": Vector2(12, 6), "behavior": "PATROL"},
            {"type": "Basic", "position": Vector2(12, 8), "behavior": "GUARD"}
        ],
        "story_elements": {
            "initial_hook": "Your crew picks up a mysterious signal...",
            "discovery_text": "The signal leads to an abandoned research facility...",
            "completion_text": "You've discovered the first clue to a larger mystery..."
        }
    },
    "story_development": {
        "grid_size": Vector2i(18, 18),
        "player_start": Vector2(3, 9),
        "terrain": [
            # More complex terrain for story development
            {"type": "BUILDING", "position": Vector2(6, 9), "story_relevance": "Research Lab"},
            {"type": "COVER", "position": Vector2(9, 9)},
            {"type": "HAZARD", "hazard_type": "Experimental Field", "position": Vector2(12, 9)},
            {"type": "ELEVATED", "position": Vector2(15, 9)}
        ],
        "objectives": [
            {"type": "STORY_DATA", "position": Vector2(16, 9), "description": "Retrieve research data"},
            {"type": "STORY_CONTACT", "position": Vector2(8, 9), "description": "Meet informant"}
        ],
        "enemies": [
            {"type": "Elite", "position": Vector2(14, 8), "behavior": "PROTECT"},
            {"type": "Basic", "position": Vector2(14, 10), "behavior": "PATROL"},
            {"type": "Basic", "position": Vector2(10, 9), "behavior": "PATROL"}
        ],
        "story_elements": {
            "plot_development": "The research data reveals a hidden conspiracy...",
            "character_interaction": "The informant shares crucial information...",
            "story_choice": {
                "option_a": "Follow the corporate lead",
                "option_b": "Investigate the underground connection"
            }
        }
    },
    "story_climax": {
        "grid_size": Vector2i(20, 20),
        "player_start": Vector2(2, 10),
        "terrain": [
            # Climactic battle setup
            {"type": "BUILDING", "position": Vector2(8, 10), "story_relevance": "Secret Facility"},
            {"type": "COVER", "position": Vector2(12, 10)},
            {"type": "HAZARD", "hazard_type": "Security System", "position": Vector2(15, 10)},
            {"type": "ELEVATED", "position": Vector2(18, 10), "story_relevance": "Command Center"}
        ],
        "objectives": [
            {"type": "STORY_CONFRONTATION", "position": Vector2(19, 10), "description": "Confront the mastermind"},
            {"type": "STORY_EVIDENCE", "position": Vector2(14, 10), "description": "Secure crucial evidence"}
        ],
        "enemies": [
            {"type": "Elite", "position": Vector2(17, 9), "behavior": "BOSS"},
            {"type": "Elite", "position": Vector2(17, 11), "behavior": "GUARD"},
            {"type": "Basic", "position": Vector2(13, 10), "behavior": "PATROL"},
            {"type": "Basic", "position": Vector2(13, 8), "behavior": "PATROL"}
        ],
        "story_elements": {
            "climax_setup": "You've finally tracked down the source of the conspiracy...",
            "boss_encounter": "The mastermind reveals their true motives...",
            "resolution_choices": {
                "option_a": "Bring them to justice",
                "option_b": "Make a deal",
                "option_c": "Eliminate the threat"
            }
        }
    }
}

static func get_story_layout(phase: String) -> Dictionary:
    return STORY_TRACK_TUTORIAL.get(phase, STORY_TRACK_TUTORIAL.introduction) 