# Edge Cases & Boundary Conditions — Five Parsecs Campaign Manager

Each section lists edge cases organized by system. Use these to generate targeted tests (gdUnit4 unit tests or MCP-automated UI tests). Priority: P0 = crash/data loss, P1 = wrong behavior, P2 = cosmetic/polish.

---

## Character System

### Identity & Names
| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| CH-001 | Empty character name ("") | Validation error, creation blocked | P0 |
| CH-002 | Very long name (200+ chars) | Truncated or scrollable, no crash | P1 |
| CH-003 | Special characters in name (emoji, unicode, quotes) | Displays correctly, saves/loads intact | P1 |
| CH-004 | Duplicate names in crew | Allowed (distinguish by character_id) | P2 |
| CH-005 | Name with only whitespace | Treated as empty, validation error | P1 |

### Stats at Boundaries
| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| CH-010 | All stats at 0 | Character functional, combat severely limited | P1 |
| CH-011 | All stats at maximum (5/6/8/3) | No overflow, advancement blocked | P0 |
| CH-012 | Luck at -1 (alien species) | Displayed correctly, no underflow on use | P1 |
| CH-013 | Speed at base 4 (minimum) | Movement not negative after debuffs | P1 |
| CH-014 | Toughness 0 → health = 2 (toughness + 2) | Health correctly derived | P0 |
| CH-015 | Advance stat already at max | Rejected, XP refunded or not spent | P0 |
| CH-016 | Advance with insufficient XP (e.g., 6 XP, cost 7) | Rejected, no partial advancement | P0 |

### Status & Lifecycle
| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| CH-020 | Captain dies (status → DEAD) | Prompt to assign new captain, or game over | P0 |
| CH-021 | All crew members DEAD | Campaign end / game over screen | P0 |
| CH-022 | All crew INJURED simultaneously | Can still proceed (limited actions) | P1 |
| CH-023 | All crew RECOVERING (none ACTIVE) | Turn phases handle gracefully (skip mission?) | P1 |
| CH-024 | Character goes MISSING then returns | Stats/equipment preserved | P1 |
| CH-025 | Retire captain | New captain assignment required | P0 |

### Implants
| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| CH-030 | 0 implants | Valid, no errors | P2 |
| CH-031 | Exactly 3 implants (max) | All function, no additional allowed | P1 |
| CH-032 | Try to add 4th implant | Rejected with clear message | P0 |
| CH-033 | Remove implant mid-campaign | Slot freed, stat bonus removed | P1 |

### Bot Characters
| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| CH-040 | Bot with luck stat (should be 0) | Luck fixed at 0, cannot advance | P1 |
| CH-041 | Bot upgrades (credits, not XP) | Uses credits correctly | P1 |
| CH-042 | Bot in Bug Hunt (via transfer) | Enlistment roll applied | P2 |

---

## Crew System

| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| CR-001 | Minimum crew size (2 including captain) | All phases functional | P0 |
| CR-002 | Maximum crew size (6) | All phases functional, UI not clipped | P0 |
| CR-003 | Try to add beyond max crew | Rejected | P1 |
| CR-004 | Remove all non-captain crew (crew = 1) | Recruitment forced or limited gameplay | P1 |
| CR-005 | Crew with all same character class | Valid, no duplicate-class errors | P2 |
| CR-006 | Crew with mixed species (Human + Kerin + Soulless + Bot) | All species rules apply correctly | P1 |

---

## Economy & Credits

| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| EC-001 | 0 credits at upkeep phase | Debt increases, crew morale penalty | P0 |
| EC-002 | Negative credits (should not occur) | Clamped to 0, or debt system activates | P0 |
| EC-003 | Purchase with insufficient funds | Transaction rejected, item not added | P0 |
| EC-004 | Sell with empty equipment inventory | "Nothing to sell" message | P1 |
| EC-005 | Sell DAMAGED item (condition-based pricing) | Reduced price displayed correctly | P1 |
| EC-006 | Sell CRITICAL condition item | Minimal price (near 0) | P2 |
| EC-007 | Very large credit balance (>100,000) | Number formatting works, no overflow | P2 |
| EC-008 | Transaction during phase transition | No double-charge or lost items | P0 |
| EC-009 | Ship debt payment with 0 credits | Debt accumulates, penalty applied | P1 |

---

## Equipment System

| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| EQ-001 | Equip 2 armor pieces on same character | Second rejected (1 armor slot) | P0 |
| EQ-002 | Empty ship stash | "No equipment in stash" message | P1 |
| EQ-003 | Equipment at CRITICAL condition | Visible warning, reduced effectiveness | P1 |
| EQ-004 | Unequip last weapon before battle | Warning or allowed with unarmed penalty | P1 |
| EQ-005 | equipment_data key is "equipment" (not "pool") | Always access via correct key | P0 |
| EQ-006 | Equipment assigned to DEAD character | Equipment returned to stash | P1 |
| EQ-007 | Duplicate equipment IDs in inventory | No crash, items distinguishable | P2 |

---

## Save/Load System

| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| SL-001 | Unicode in campaign name (e.g., "Crew alpha") | Saves and loads correctly | P1 |
| SL-002 | Save with empty crew (0 members) | Valid save, loads correctly | P1 |
| SL-003 | Load from older schema version | Migration applied, data preserved | P0 |
| SL-004 | Load corrupted JSON (missing brackets) | Error message, no crash | P0 |
| SL-005 | Load with missing required fields | Default values applied, warning shown | P0 |
| SL-006 | Float-to-int roundtrip (JSON stores as float) | Integer fields cast back correctly | P0 |
| SL-007 | Dual key aliases present after load | Both id/character_id and name/character_name exist | P0 |
| SL-008 | Save during phase transition | Consistent state saved (not mid-transition) | P0 |
| SL-009 | Auto-save trigger | Fires at end of each turn cycle | P1 |
| SL-010 | Load campaign, modify, save, load again | All modifications preserved | P0 |
| SL-011 | Ironman mode save (single slot) | Only one save file, no manual save/load | P1 |
| SL-012 | Save file exceeds disk space | Graceful error, previous save not corrupted | P0 |

---

## Battle System

| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| BT-001 | 0 enemies generated | Battle auto-completes as victory | P1 |
| BT-002 | All crew casualties in round 1 | Battle ends, defeat processed | P0 |
| BT-003 | Morale check with all enemies dead | Auto-pass, battle ends | P1 |
| BT-004 | Point-blank range combat (range 0-1") | Uses point-blank rules | P1 |
| BT-005 | Beyond maximum weapon range | Shot automatically misses | P1 |
| BT-006 | Combat skill 0 vs toughness 6 | Very unlikely hit, but possible on crits | P2 |
| BT-007 | Auto-resolve with 1 crew member | Valid, high casualty risk | P1 |
| BT-008 | FULL_ORACLE tier with minimal crew | All oracle features available | P2 |
| BT-009 | Battle with no deployment zone assigned | Fallback to STANDARD deployment | P1 |
| BT-010 | Switch between LOG_ONLY/ASSISTED/FULL_ORACLE mid-battle | State preserved, UI adjusts | P1 |

---

## Campaign Turn Phases

| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| TP-001 | Skip optional phase (no story events available) | Phase auto-completes | P1 |
| TP-002 | Travel with 0 credits (can't afford) | Stay option only, or go into debt | P0 |
| TP-003 | Upkeep with dead crew members | Don't charge for dead members | P1 |
| TP-004 | No job offers generated | "No opportunities available" message | P1 |
| TP-005 | Accept mission then try to go back | Mission locked, no double-accept | P0 |
| TP-006 | Advancement with 0 XP on all members | "No one eligible" message | P1 |
| TP-007 | Trading in CRISIS market state | Prices inflated correctly | P1 |
| TP-008 | Trading in BOOM market state | Prices reduced correctly | P1 |
| TP-009 | Character event: random death | Character removed, crew updated | P0 |
| TP-010 | End phase: victory condition met | Campaign end screen triggered | P0 |
| TP-011 | End phase: mandatory save fails (disk full) | Error message, can retry | P0 |
| TP-012 | Turn 50+ (long campaign stability) | No performance degradation | P1 |
| TP-013 | Phase data handoff: null/empty data from previous phase | Next phase handles gracefully | P0 |

---

## Bug Hunt Gamemode

| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| BH-001 | Transfer character from standard to Bug Hunt | Enlistment roll, stats mapped | P1 |
| BH-002 | Transfer back from Bug Hunt to standard | Reverse mapping, equipment returned | P1 |
| BH-003 | Bug Hunt campaign with 0 grunts | Valid (main characters only) | P1 |
| BH-004 | Load standard save as Bug Hunt | Fails gracefully (type detection) | P0 |
| BH-005 | Load Bug Hunt save as standard | Fails gracefully (type detection) | P0 |
| BH-006 | temp_data namespace collision check | "bug_hunt_*" keys don't interfere with standard keys | P0 |
| BH-007 | TacticalBattleUI in bug_hunt mode: morale hidden | Morale panel not visible | P1 |
| BH-008 | Contact markers displayed (Bug Hunt only) | ContactMarkerPanel visible | P1 |
| BH-009 | Abort + Complete buttons: no double navigation | `_bug_hunt_returning` flag prevents | P0 |

---

## DLC / Compendium System

| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| DLC-001 | Toggle DLC flag mid-campaign | Feature appears/disappears gracefully | P1 |
| DLC-002 | All 37 ContentFlags enabled | No conflicts, all features accessible | P1 |
| DLC-003 | All ContentFlags disabled (base game only) | Core gameplay unaffected | P0 |
| DLC-004 | Partial DLC ownership (1 of 3 packs) | Only owned pack features enabled | P0 |
| DLC-005 | DLCManager null (autoload not loaded) | Graceful fallback, base game works | P0 |
| DLC-006 | Purchase flow: success | DLC flag set, features unlocked | P1 |
| DLC-007 | Purchase flow: failure/cancel | State unchanged, can retry | P1 |
| DLC-008 | OfflineStoreAdapter (dev mode) | All purchases auto-succeed | P2 |
| DLC-009 | Self-gating data classes with flag disabled | Return empty arrays, no crash | P0 |

---

## UI / Navigation

| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| UI-001 | Back button from every screen | Returns to previous, no dead ends | P0 |
| UI-002 | Rapid navigation (fast clicks) | No duplicate scene loads or crashes | P0 |
| UI-003 | Resize window during animation | No visual artifacts | P2 |
| UI-004 | Empty list in every list-based UI | "No items" placeholder shown | P1 |
| UI-005 | Screen rotation portrait ↔ landscape | Layout adapts, touch targets preserved | P1 |
| UI-006 | Navigate to screen with stale data | Data refreshed on enter | P0 |
| UI-007 | SceneRouter history: navigate 10+ screens deep | Back button traverses correctly | P1 |
| UI-008 | Scene cache: revisit cached scene | Data refreshed, not stale | P0 |

---

## Campaign Creation

| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| CC-001 | Skip steps (try to jump to step 7) | Blocked, must complete in order | P0 |
| CC-002 | Go back from step 4 to step 1, change config | Subsequent steps re-validate | P0 |
| CC-003 | Create campaign with all defaults (no changes) | Valid campaign created | P0 |
| CC-004 | Create campaign with INSANITY difficulty | Extremely hard, but functional | P1 |
| CC-005 | Select all victory conditions simultaneously | All tracked, first met triggers end | P1 |
| CC-006 | Empty equipment generation (bad RNG) | At least minimum gear provided | P1 |
| CC-007 | World generation: volcanic + peaceful strife | Valid combination, no conflict | P2 |
| CC-008 | Final review: all data displayed correctly | Every field from steps 1-6 shown | P0 |

---

## Victory Conditions

| ID | Edge Case | Expected Behavior | Pri |
|----|-----------|-------------------|-----|
| VC-001 | TURNS_20 at turn 20 exactly | Victory triggered, not turn 21 | P0 |
| VC-002 | CREDITS_50K with exactly 50,000 | Victory triggered (>=, not >) | P0 |
| VC-003 | Multiple conditions met simultaneously | First check wins, clear victory screen | P1 |
| VC-004 | Victory condition met mid-phase | Completes current phase, then triggers | P1 |
| VC-005 | STORY_COMPLETE with no story track | Condition unreachable, warn at setup | P1 |
| VC-006 | All 18+ victory types individually tested | VictoryChecker handles each correctly | P0 |
