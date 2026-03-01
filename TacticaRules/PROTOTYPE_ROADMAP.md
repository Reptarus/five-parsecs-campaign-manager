# Age of Fantasy Digital - Prototype Roadmap

**Document Version**: 1.0
**Created**: 2024-11-22
**Target**: Playable prototype in 8 weeks

---

## Overview

### Goal
Create a playable prototype demonstrating:
- Unit deployment on a 3D battlefield
- Alternating unit activation
- Movement with pathfinding
- Basic shooting and melee combat
- Morale system
- Win condition checking

### Not Included in Prototype
- Campaign mode
- Army builder
- Advanced rules (stratagems, missions)
- Multiplayer networking
- Full AI (basic AI only)
- Polish (animations, VFX, audio)

---

## Phase Summary

| Phase | Duration | Focus | Deliverable |
|-------|----------|-------|-------------|
| 1 | Weeks 1-2 | Core Framework | Empty battlefield, selectable unit |
| 2 | Weeks 3-4 | Movement System | Unit movement with visualization |
| 3 | Week 5 | Turn Structure | Alternating activation working |
| 4 | Weeks 6-7 | Combat System | Shooting and melee resolution |
| 5 | Week 8 | Integration & Polish | Playable prototype |

---

## Phase 1: Core Framework (Weeks 1-2)

### Objectives
1. Project setup and configuration
2. Create Battle scene with environment
3. Create basic Unit scene
4. Implement camera controls
5. Implement selection system

### Week 1 Tasks

#### Day 1-2: Project Setup
- [ ] Create project structure (directories)
- [ ] Configure project settings (physics layers, input)
- [ ] Create autoload scripts (BattleState, DiceSystem)
- [ ] Set up testing infrastructure

**Success Criteria**: Project runs, physics layers configured

#### Day 3-4: Battle Scene
- [ ] Create `Battle.tscn` with full structure
- [ ] Add ground plane with collision
- [ ] Add WorldEnvironment and lighting
- [ ] Add Manager nodes (empty scripts)
- [ ] Add container nodes (Units, Effects, etc.)

**Success Criteria**: Scene loads, ground visible, proper lighting

#### Day 5-7: Camera System
- [ ] Create `BattleCamera.tscn`
- [ ] Implement pan (WASD or middle mouse)
- [ ] Implement rotate (right mouse drag)
- [ ] Implement zoom (scroll wheel)
- [ ] Add boundary clamping

**Success Criteria**: Camera controls feel responsive, stays in bounds

### Week 2 Tasks

#### Day 1-3: Unit Scene
- [ ] Create `BaseUnit.tscn` with full structure
- [ ] Add placeholder model (capsule)
- [ ] Add collision shape
- [ ] Add NavigationAgent3D
- [ ] Add selection indicator (torus)
- [ ] Create `GameBaseUnit.gd` script

**Success Criteria**: Unit spawns in scene, has collision

#### Day 4-5: Selection System
- [ ] Create `SelectionManager.gd`
- [ ] Implement raycast from mouse to world
- [ ] Detect unit under cursor
- [ ] Select/deselect units
- [ ] Visual feedback (show selection indicator)

**Success Criteria**: Click unit → highlights, click elsewhere → deselects

#### Day 6-7: Integration & Testing
- [ ] Spawn multiple units in scene
- [ ] Test selection with multiple units
- [ ] Write unit tests for selection
- [ ] Fix any issues

**Success Criteria**: Can select any unit in scene reliably

### Phase 1 Deliverable
- Battle scene with environment
- Camera with full controls
- Selectable units with visual feedback
- Project foundation for Phase 2

---

## Phase 2: Movement System (Weeks 3-4)

### Objectives
1. Calculate movement ranges
2. Visualize movement range
3. Implement pathfinding
4. Show movement preview
5. Execute movement

### Week 3 Tasks

#### Day 1-2: Movement Range Calculation
- [ ] Create `MovementManager.gd`
- [ ] Calculate valid movement area based on unit stats
- [ ] Account for difficult terrain (when implemented)
- [ ] Create movement range shader

**Success Criteria**: Movement range calculated correctly

#### Day 3-4: Movement Visualization
- [ ] Apply movement range shader to indicator
- [ ] Show/hide on selection
- [ ] Test visual appearance
- [ ] Adjust shader parameters for clarity

**Success Criteria**: Clear visual showing where unit can move

#### Day 5-7: Pathfinding Setup
- [ ] Add NavigationRegion3D to battlefield
- [ ] Bake navigation mesh
- [ ] Configure NavigationAgent3D on units
- [ ] Test basic pathfinding

**Success Criteria**: Units can find paths around obstacles

### Week 4 Tasks

#### Day 1-2: Movement Preview
- [ ] Create `MovementPreview.tscn`
- [ ] Show path line from unit to cursor
- [ ] Show destination marker
- [ ] Update in real-time as mouse moves

**Success Criteria**: Clear preview of movement path

#### Day 3-4: Movement Execution
- [ ] Implement click-to-move
- [ ] Animate unit along path
- [ ] Handle movement completion
- [ ] Emit signals for turn management

**Success Criteria**: Unit smoothly moves to clicked location

#### Day 5-7: Movement Validation & Testing
- [ ] Validate destination is in range
- [ ] Validate path is not blocked
- [ ] Cancel movement with right-click
- [ ] Write movement tests
- [ ] Edge case handling

**Success Criteria**: Movement system robust and tested

### Phase 2 Deliverable
- Movement range visualization
- Click-to-move with pathfinding
- Movement preview (path + destination)
- Movement validation

---

## Phase 3: Turn Structure (Week 5)

### Objectives
1. Implement battle phases
2. Track unit activations
3. Implement action selection
4. Create basic UI

### Week 5 Tasks

#### Day 1-2: Battle State Machine
- [ ] Create `BattleManager.gd` with phases
- [ ] Implement phase transitions
- [ ] Track current round
- [ ] Emit phase_changed signals

**Success Criteria**: Phases transition correctly

#### Day 2-3: Turn Management
- [ ] Create `TurnManager.gd`
- [ ] Track activated/not activated units
- [ ] Implement alternating activation
- [ ] Determine first player each round

**Success Criteria**: Units activate in correct order

#### Day 4-5: Action System
- [ ] Create `ActionManager.gd`
- [ ] Implement action types (Hold, Advance, Rush, Charge)
- [ ] Validate action availability
- [ ] Apply action effects (movement restrictions)

**Success Criteria**: Actions modify unit behavior correctly

#### Day 6-7: Basic UI
- [ ] Create `BattleHUD.tscn`
- [ ] Create `ActionMenu.tscn`
- [ ] Show current phase/round/player
- [ ] Show action buttons for selected unit
- [ ] End turn button

**Success Criteria**: UI reflects game state, actions selectable

### Phase 3 Deliverable
- Working turn structure
- Alternating activation
- Action selection UI
- Round progression

---

## Phase 4: Combat System (Weeks 6-7)

### Objectives
1. Implement shooting attacks
2. Implement melee combat
3. Handle damage and wounds
4. Implement morale system
5. Visual feedback for combat

### Week 6 Tasks

#### Day 1-2: Target Selection
- [ ] Create `TargetingManager.gd`
- [ ] Highlight valid targets
- [ ] Check range to target
- [ ] Check line of sight

**Success Criteria**: Valid targets clearly indicated

#### Day 3-4: Shooting Resolution
- [ ] Create `CombatManager.gd`
- [ ] Roll quality tests for attacks
- [ ] Apply armor piercing
- [ ] Roll defense saves
- [ ] Calculate wounds

**Success Criteria**: Shooting math correct per rules

#### Day 5-7: Damage & Effects
- [ ] Apply wounds to target
- [ ] Create `DamageNumber.tscn`
- [ ] Handle unit destruction
- [ ] Update health bars
- [ ] Create `DiceRollDisplay.tscn`

**Success Criteria**: Combat results shown clearly

### Week 7 Tasks

#### Day 1-2: Melee Combat
- [ ] Implement charge action
- [ ] Move into base contact
- [ ] Resolve melee attacks
- [ ] Implement strike back
- [ ] Track fatigue

**Success Criteria**: Melee resolution correct

#### Day 3-4: Morale System
- [ ] Create `MoraleManager.gd`
- [ ] Test morale on casualties
- [ ] Test morale on melee loss
- [ ] Apply shaken status
- [ ] Implement routing

**Success Criteria**: Morale tests trigger correctly

#### Day 5-7: Combat Polish & Testing
- [ ] Visual feedback for all combat steps
- [ ] Combat log/history
- [ ] Write combat tests
- [ ] Balance testing
- [ ] Bug fixes

**Success Criteria**: Combat feels complete and correct

### Phase 4 Deliverable
- Full shooting resolution
- Full melee resolution
- Morale system
- Visual feedback for all combat

---

## Phase 5: Integration & Polish (Week 8)

### Objectives
1. Complete game loop
2. Add win conditions
3. Basic AI opponent
4. Deployment phase
5. Final testing

### Week 8 Tasks

#### Day 1-2: Victory Conditions
- [ ] Track objective control (if used)
- [ ] Check for full route
- [ ] Check for point threshold
- [ ] End game screen

**Success Criteria**: Game ends when victory achieved

#### Day 2-3: Deployment Phase
- [ ] Create deployment zones (Area3D)
- [ ] Allow unit placement during deployment
- [ ] Validate deployment (in zone, spacing)
- [ ] Transition to battle when complete

**Success Criteria**: Units can be deployed before battle

#### Day 4-5: Basic AI
- [ ] Create `AIManager.gd`
- [ ] Simple target priority (closest, weakest)
- [ ] Move toward objectives/enemies
- [ ] Select appropriate action
- [ ] Execute attacks

**Success Criteria**: AI takes reasonable actions

#### Day 6-7: Final Integration & Testing
- [ ] Full game loop test
- [ ] Multi-turn game test
- [ ] Edge case testing
- [ ] Performance testing
- [ ] Bug fixes
- [ ] Documentation

**Success Criteria**: Playable prototype complete

### Phase 5 Deliverable
- Complete game loop
- Victory/defeat conditions
- Basic AI opponent
- Deployment phase
- Playable prototype

---

## Risk Mitigation

### High-Risk Areas

1. **Pathfinding Performance**
   - Risk: Slow with many units
   - Mitigation: Use NavigationServer3D, cache paths
   - Fallback: Simpler grid-based movement

2. **Line of Sight Complexity**
   - Risk: Edge cases with terrain
   - Mitigation: Start simple (center-to-center)
   - Fallback: Ignore LoS for prototype

3. **UI Responsiveness**
   - Risk: UI blocks 3D interaction
   - Mitigation: Proper input handling order
   - Fallback: Simplify UI

4. **Combat Math Accuracy**
   - Risk: Doesn't match tabletop
   - Mitigation: Test-driven development
   - Fallback: Simplify rules

### Dependencies

```
Phase 1 (Foundation)
    ↓
Phase 2 (Movement) ← Requires: Selection, Units
    ↓
Phase 3 (Turns) ← Requires: Movement, Actions
    ↓
Phase 4 (Combat) ← Requires: Turns, Targeting
    ↓
Phase 5 (Polish) ← Requires: All above
```

### Scope Reduction Options

If falling behind, cut in this order:
1. AI (use 2-player only)
2. Morale system
3. Melee (shooting only)
4. Deployment (pre-placed units)
5. Visual effects

---

## Success Metrics

### Phase 1 Complete When:
- [ ] Camera controls feel good
- [ ] Units selectable reliably
- [ ] No runtime errors

### Phase 2 Complete When:
- [ ] Movement visualization clear
- [ ] Pathfinding works with obstacles
- [ ] Movement animation smooth

### Phase 3 Complete When:
- [ ] Turn structure matches rules
- [ ] All actions available
- [ ] UI reflects game state

### Phase 4 Complete When:
- [ ] Combat math matches tabletop
- [ ] Visual feedback clear
- [ ] Morale tests trigger correctly

### Phase 5 Complete When:
- [ ] Full game playable
- [ ] Game ends with victory
- [ ] AI takes actions
- [ ] No game-breaking bugs

---

## Post-Prototype Roadmap

### Version 0.2 - Content
- Multiple unit types
- Terrain variety
- Special rules implementation
- Sound effects

### Version 0.3 - Polish
- Animations (walk, attack, death)
- Particle effects
- Music
- Better UI

### Version 0.4 - Features
- Army builder
- Save/load battles
- Scenario editor
- Advanced AI

### Version 0.5 - Campaign
- Campaign mode integration
- Persistent armies
- Between-battle management

### Version 1.0 - Release
- Full content
- Multiplayer
- Mod support
- Platform releases

---

## Time Estimates

### Hours per Phase

| Phase | Minimum | Expected | Maximum |
|-------|---------|----------|---------|
| 1 | 15 | 20 | 30 |
| 2 | 15 | 20 | 30 |
| 3 | 10 | 15 | 20 |
| 4 | 20 | 30 | 40 |
| 5 | 15 | 20 | 30 |
| **Total** | **75** | **105** | **150** |

At 3 hours/day: 5-7 weeks
At 2 hours/day: 7-10 weeks
At 5 hours/day: 3-4 weeks

---

## Getting Started

### Day 1 Checklist

1. [ ] Create new Godot 4.x project
2. [ ] Set up directory structure
3. [ ] Configure physics layers
4. [ ] Configure input map
5. [ ] Create `BattleState.gd` autoload
6. [ ] Create `DiceSystem.gd` autoload (copy from Five Parsecs)
7. [ ] Set up gdUnit4 for testing

### First Week Goal

Have a scene where you can:
- Pan/rotate/zoom camera
- See ground with lighting
- See a unit (placeholder mesh)
- Click to select unit
- Click elsewhere to deselect

This foundation enables all subsequent development.

---

## Tools & Resources

### Required
- Godot 4.2+ (recommend 4.3+)
- gdUnit4 for testing
- Git for version control

### Recommended
- Blender for models
- Aseprite for textures
- Audacity for audio
- Draw.io for diagrams

### Asset Sources (Prototype)
- Godot primitives (CSG, primitives)
- Kenney.nl free assets
- OpenGameArt.org
- Mixamo (animations)

---

This roadmap provides a realistic path to a playable prototype. Adjust timelines based on your available hours and experience level. Focus on getting each phase working before moving to the next.
