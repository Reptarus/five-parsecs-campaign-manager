# Test Organization Plan

## Revised Testing Strategy

### Phase 1: Core Stabilization
```gdscript
# Base test structure focusing on stability
@tool
extends "res://tests/fixtures/base_test.gd"

const GUT_TIMEOUT := 5.0
const TestedClass = preload("res://path/to/tested/class.gd")

var _instance: TestedClass

func before_each() -> void:
    await super.before_each()
    stabilize_test_environment()
    _instance = TestedClass.new()
    add_child(_instance)
    track_test_node(_instance)

func after_each() -> void:
    await super.after_each()
    _instance = null
```

### Phase 2: Core Systems Testing
1. Campaign State Management
   - Direct state verification
   - Minimal signal dependencies
   - Clear state transitions

2. Combat Resolution
   - Deterministic outcomes
   - State-based verification
   - Simplified flow

3. Resource Management
   - Direct resource tracking
   - Clear ownership
   - Explicit cleanup

### Phase 3: Integration Testing
1. Campaign Flow
   - Linear progression
   - State checkpoints
   - Minimal async operations

2. Mission Sequences
   - Predictable outcomes
   - State validation
   - Clear dependencies

### Phase 4: Mobile/Performance (Deferred)
- Touch input simulation
- Screen adaptation
- Performance metrics

## Directory Structure (Updated)
```
tests/
├── unit/                    # Core unit tests
│   ├── campaign/           # Campaign system tests
│   ├── combat/            # Combat system tests
│   ├── resource/          # Resource management tests
│   └── state/            # State management tests
├── integration/            # Simplified integration tests
│   ├── campaign_flow/     # Campaign progression
│   └── mission_flow/      # Mission sequences
├── deferred/              # Tests to implement later
│   ├── mobile/           # Mobile-specific tests
│   └── performance/      # Performance benchmarks
└── fixtures/             # Test utilities
    ├── base_test.gd     # Stabilized base test
    └── game_test.gd     # Game-specific utilities
```

## Implementation Guidelines

### 1. Test Structure
```gdscript
func test_feature() -> void:
    # Direct setup
    var subject = setup_test_subject()
    
    # Immediate action
    subject.do_something()
    
    # State verification
    assert_eq(subject.state, expected_state)
```

### 2. Async Handling
```gdscript
func test_async_feature() -> void:
    var subject = setup_test_subject()
    
    # Use simplified async
    await stabilize_async(func():
        subject.do_async_thing()
    )
    
    assert_eq(subject.state, expected_state)
```

### 3. Resource Management
```gdscript
# Explicit resource tracking
func track_resource(resource: Resource) -> void:
    _tracked_resources.append(resource)
    
# Automatic cleanup
func cleanup_resources() -> void:
    for resource in _tracked_resources:
        if resource and not resource.is_queued_for_deletion():
            resource.free()
    _tracked_resources.clear()
```

## Test Stabilization Tools

### 1. Environment Stabilization
```gdscript
func stabilize_test_environment() -> void:
    Engine.set_physics_ticks_per_second(60)
    Engine.set_max_fps(60)
    get_tree().set_debug_collisions_hint(false)
    await get_tree().physics_frame
```

### 2. Signal Handling
```gdscript
func wait_for_signal(object: Object, signal_name: String) -> void:
    var timer = get_tree().create_timer(GUT_TIMEOUT)
    var done = false
    object.connect(signal_name, func(): done = true, CONNECT_ONE_SHOT)
    timer.timeout.connect(func(): done = true)
    while not done:
        await get_tree().process_frame
```

### 3. State Verification
```gdscript
func verify_state(subject: Object, expected_states: Dictionary) -> void:
    for property in expected_states:
        assert_eq(subject[property], expected_states[property],
            "Property %s should match expected state" % property)
```

## Implementation Priority

1. **Week 1: Stabilization**
   - Implement base test improvements
   - Add stabilization tools
   - Convert existing tests to new pattern

2. **Week 2: Core Systems**
   - Campaign state tests
   - Combat resolution tests
   - Resource management tests

3. **Week 3: Integration**
   - Campaign flow tests
   - Mission sequence tests
   - State transition tests

4. **Future: Deferred Features**
   - Mobile testing
   - Performance benchmarks
   - Advanced scenarios

## Success Criteria

1. **Stability**
   - Tests run consistently
   - No random failures
   - Clear error messages

2. **Coverage**
   - Core systems tested
   - Critical paths verified
   - State transitions validated

3. **Maintainability**
   - Clear test structure
   - Minimal complexity
   - Easy to extend

## Progress Tracking

- ⬜ Base test stabilization
- ⬜ Core system tests
- ⬜ Integration tests
- ⬜ Documentation updates
- ⬜ Cleanup old tests

## Next Steps
1. Implement base test improvements
2. Add stabilization tools
3. Convert existing tests
4. Document new patterns 