# Deployment & Victory Reference

## DeploymentManager.gd
- **Path**: `src/core/managers/DeploymentManager.gd`
- **extends**: Resource

### Signals
```
deployment_zones_generated(zones: Array[Dictionary])
terrain_generated(terrain: Array[Dictionary])
```

### Properties
- `current_deployment_type: GameEnums.DeploymentType`
- `terrain_layout: Array[Dictionary]`
- `grid_size: Vector2i` (default 24×24)

### Deployment Zone Sizes
| Type | Size |
|------|------|
| STANDARD | 6×4 |
| LINE | 8×2 |
| AMBUSH | 4×6 |
| SCATTERED | 3×3 |
| DEFENSIVE | 5×5 |
| INFILTRATION | 4×4 |
| REINFORCEMENT | 6×3 |
| OFFENSIVE | 5×4 |
| CONCEALED | 4×4 |
| BOLSTERED_LINE | 10×2 |

### Key Methods
```
get_zone_size(deployment_type) -> Vector2         # static
generate_deployment_zones() -> Array[Dictionary]  # {position, size, type}
generate_terrain_layout(features: Array) -> Array[Dictionary]  # {type, position}
```

### Terrain Feature Constants
```
TERRAIN_FEATURE_SPAWN_POINT = 100
TERRAIN_FEATURE_EXIT_POINT = 101
TERRAIN_FEATURE_OBJECTIVE = 102
```

---

## VictoryChecker.gd
- **Path**: `src/core/victory/VictoryChecker.gd`
- **extends**: RefCounted
- **class_name**: VictoryChecker

### Main Method
```
check_victory(campaign: Variant, turn_number: int = 0) -> Dictionary
# Returns: {achieved: bool, message: String}
```

### 18 Victory Types (+ NONE)

| Type | Name | Target | Progress Source |
|------|------|--------|-----------------|
| TURNS_20 | Short Campaign | 20 turns | turn_number |
| TURNS_50 | Standard Campaign | 50 turns | turn_number |
| TURNS_100 | Epic Campaign | 100 turns | turn_number |
| CREDITS_THRESHOLD | Wealthy | 10,000 credits | resources.credits |
| CREDITS_50K | Wealthy | 50,000 credits | resources.credits |
| CREDITS_100K | Rich | 100,000 credits | resources.credits |
| REPUTATION_THRESHOLD | Famous | Rep 20 | resources.reputation |
| REPUTATION_10 | Known | Rep 10 | resources.reputation |
| REPUTATION_20 | Famous | Rep 20 | resources.reputation |
| QUESTS_3 | Quest Starter | 3 quests | completed_missions.size() |
| QUESTS_5 | Quest Seeker | 5 quests | completed_missions.size() |
| QUESTS_10 | Quest Master | 10 quests | completed_missions.size() |
| BATTLES_20 | Seasoned Crew | 20 battles | battle_stats.battles_won |
| BATTLES_50 | Veteran Crew | 50 battles | battle_stats.battles_won |
| BATTLES_100 | Legendary Crew | 100 battles | battle_stats.battles_won |
| STORY_COMPLETE | Story Complete | — | Instant victory |
| STORY_POINTS_10 | Story Builder | 10 points | resources.story_points |
| STORY_POINTS_20 | Story Master | 20 points | resources.story_points |
| NONE | No condition | — | Never achieved |

### Two VictoryDescriptions Files
- `src/core/victory/` — basic descriptions
- `src/game/victory/` — full descriptions (used by UI)
