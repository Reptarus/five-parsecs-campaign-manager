#### The campaign-wide data flow sweep (Aug 1 2026) — the rest of the funnel

Follow-up to the battle funnel below, over the WHOLE turn. Same defect family,
plus two new shapes. **Anything called a "dead file" is a liability, not a
curiosity — check what its only callers were before shelving it.**

**Dead files hold live rules hostage.** `src/core/campaign/phases/TravelPhase.gd`
and `phases/WorldPhase.gd` have ZERO instantiations (travel really happens in
`UpkeepPhaseComponent`, the World Phase upkeep step). Between them they held the
ONLY callers of three real mechanics:
`record_invaded_planet()` → so `invaded_planets` was never populated → so
`GalacticWarProcessor` returned at its own `is_empty()` guard **every turn** and
the p.126 step-14 table had never rolled in any campaign (it was itself
"repaired" a week earlier, in a file that never runs); `repair_hull()` → the p.59
free 1 HP/turn repair; and the `fuel_credits` consumer → p.79 fuel was
unspendable. All three now live in the upkeep step. Both dead files are on the
post-tablet purge list.

**Detached-node lookups.** A component created with `.new()` (tests, probes)
cannot resolve `get_node_or_null("/root/X")` — the call ERRORS and aborts the
enclosing function, silently returning the default. An MCP probe of
`_hull_damage()` read 0 for a damaged ship purely because the node was not in
the tree. Add it to the tree before asserting, or the probe measures the trap
rather than the code.

| Fix | Was |
|---|---|
| Crew-card write-back is a **whitelist** (`CharacterDetailsScreen.EDITABLE_KEYS`) | merged ALL of `to_dictionary()` back over the live crew dict — and `from_dictionary` narrows `equipment` to `Array[String]`, so **opening a crew card deleted every Dictionary-shaped item they owned** |
| Advanced Training uses `acquired_training` / `add_training()` | assigned to `Character.training`, a property Character does not have (the int lives on `BaseCharacterResource`, which Character does NOT extend) — a nonexistent-property write ABORTS the handler, so the XP deduction on the next line never ran and the button did nothing, ever |
| Assign Equipment replays through `EquipmentTransferService` | the component works on `duplicate(true)` copies and all three transfer paths were `has_method()` guards on methods with zero definitions — gear reassignment never reached the campaign |
| `qol_data["turn_checklist"]` (reader fixed) | reader looked for `checklist_settings`, which nothing has ever written → veteran mode never survived a reload; `completed_actions` was not serialized at all |
| Sick bay writes an `injuries` entry with `recovery_turns` | wrote an orphan `sick_bay_turns_remaining`; the countdown clears sick bay when `injuries` is empty, which was true immediately → 3 turns lasted 1 |
| Finalization reads crew **dual-shape** | `member is Dictionary` gates on the one path that only ever sees Character RESOURCES → WEALTH +1D6cr, FAME +1SP and the whole Prison Planet boxout were dead on every new campaign |
| p.59 travel gate + paid repair UI | "a ship with Hull Point damage cannot leave for another planet" was unimplemented |

**Elite Rank perks (p.65) are BLOCKED, not broken.** Reading the page changed
the spec: `extra_starting_characters` does NOT add crew — it widens the
CANDIDATE POOL ("You are still limited to your starting crew size"), and the XP
is "assigned to any characters you like". Both need player-choice UI the
creation wizard has no concept of. Semantics documented at the write site.

---

*Extracted from `CLAUDE.md` on 2026-08-06 to keep the always-loaded file small. The durable rules from this audit remain inline in CLAUDE.md; this file is the full narrative record.*
