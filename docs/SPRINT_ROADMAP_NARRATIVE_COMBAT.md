# Sprint Roadmap — Narrative Systems + Combat Modes

**Created**: 2026-05-27
**Updated**: 2026-05-29 — Sprints 1-6 SHIPPED (B2/A5/Tier 2/B3/A2/A1) + retro-review fix pass.
**Owner**: Elijah Rhyne
**Basis**: `docs/COMBAT_SIMULATION_MODES_RESEARCH.md` (books-first combat-mode research, May 26) + the narrative system design ([[project-narrative-system-design]], `docs/design/narrative_system_design.md`).

## Status snapshot (May 29 2026)

**Sprints DONE** (in order shipped):

- ✅ **B0 + B1** No-Minis fidelity spike + No-Minis Combat mode (May 27) — `NoMinisResolver.gd` book-faithful round/firefight/morale-bail, routed in BattlePhase, Salvage fallback, 12/12 tests
- ✅ **B2** Auto-resolve narrative bridge (May 29) — `CampaignTurnController._on_battle_completed` wraps auto-resolved battles in `NarrativeScreen` as `Aftermath: Victory/Objective Held/Withdrawal` beat before POST_MISSION. 8 gdUnit4 tests pin producer/consumer dict contract
- ✅ **A5** SceneAtmosphereLayer (May 29) — GPUParticles2D-driven, 5 effects, sibling of SceneStage, AtmosphereCatalog SSOT, `world_trait_atmosphere.json` mapping, Reduced Motion gated, procedural texture fallback (PNGs OPTIONAL)
- ✅ **Tier 2 image slots** (May 29) — `SceneStage.gd` `anchor_mode`/`scale_mode`/`source`; `Tier2AssetRegistry.gd`; SOP §4a
- ✅ **B3** Dramatic Combat completion (May 29) — Adjusted Shooting wired through both resolvers, 35-row `dramatic_weapons_stats` table, rule instructions emit, dramatic_effects populated, citation drift fixed
- ✅ **A2** Advisor quote expansion (May 29) — 18 → 108 quotes (6/cell)
- ✅ **A1** Settings checkbox (May 29) — discovered pre-existing in `SettingsScreen.gd`, round-trip verified
- ✅ **Sub-cat scene PoC** (May 29) — 8 of 14 sub-category scenes shipped (ship_interior_*, starport_*, alien_ruins, wilderness_approach); 6 still NEEDED
- ✅ **Species placeholders** (May 29) — engineer/krag/skulker/psionic/unity_agent (×3 variants); de_converted [OUT OF SCOPE]

**Retro-review pass (May 29, post-commit 6892c7fe)**: code-reviewer agent caught 4 silent-failure bugs + 1 test gap. All fixed: producer/consumer key drift (briefing/held_field), DRAMATIC_COMBAT dead-code wiring, dead slot drift. 8 new gdUnit4 bug-pin tests in `tests/unit/test_b2_narrative_bridge.gd`.

**Sprints NEXT**:

- **A3 Crew Tasks** (interactive event types) — the ~16 outcome-driven types still go through `CrewTaskEventDialog`; routing those through NarrativeScreen needs an interactive-choice pattern
- **A4 PostBattle wizard** — 14-step interactive flow producing irreversible economy state; dedicated sprint
- **B4 Grid-Based Movement** — heaviest, most independent; 3×3/3×4/4×4 tactical view

**Original Status (May 27)**: Narrative scene composition + ambient motion shipped May 27 (PoC). Lead sprint chosen: **B0+B1 No-Minis foundation**.

---

## Organizing principle (from the combat research)

5PFH's own rules model combat as **two orthogonal axes**, and the sprints split along them:

- **Representation axis** (how much the player physically plays): Full-minis companion *(shipped)* → Grid-based *(B4)* → No-Minis abstract *(B1)* → Auto-resolve *(B2)*.
- **Flavor toggle** (orthogonal, layers on any representation): Dramatic Combat on/off *(B3)*.
- **Narrative is a wrapper, not a mode** — it presents any real resolution as story. The shipped `NarrativeScreen`/`SceneStage` is the presentation layer **both workstreams converge into** (the convergence point is **B2**, the "play it out for me" digital-version pitch).

A true standalone *narrative-resolution* ruleset (resolve a whole fight as prose) is NOT in the Core Rules or Compendium — it lives in the separate Tactics book, out of scope. In-app, "narrative combat" = presenting a real No-Minis / Dramatic resolution through the narrative layer.

---

## Workstream A — Narrative integration

Extends the shipped Phase 1 (Story Track) + the May 27 scene PoC. Mostly `ui-panel-developer` + `campaign-systems-engineer`. Runs largely parallel to combat (no hard dependency, except A5 atmosphere which B2 would showcase). Phase numbering follows the design doc.

**Art production tracker**: [`docs/design/ART_PRODUCTION_LIST.md`](design/ART_PRODUCTION_LIST.md) — master list of every art asset across all sprints (Story Track 02-07 scenes, species figures, atmosphere particles, sub-category fallback scenes, optional UI icons). The detailed per-scene Story Track spec lives at [`docs/design/STORY_TRACK_SCENE_ASSETS.md`](design/STORY_TRACK_SCENE_ASSETS.md).

| ID | Sprint | Scope | Key files |
|----|--------|-------|-----------|
| A1 | Narrative settings + scene fan-out | Real Settings checkbox (today the toggle is `.cfg`-only via `are_narrative_events_enabled()`); author `story_event_02..07` SceneStage manifests as art lands (gated on hand-export) | `SettingsScreen.gd`, `data/scenes/`, `docs/sop/narrative-scene-authoring.md` |
| A2 | Phase 3 — Character events | Route the 30 D100 character events through `NarrativeScreen`; expand the advisor quote pool beyond the 1-per-cell scaffold | `CharacterPhasePanel.gd`, `data/narrative/advisor_quotes.json` |
| A3 | Phase 4 — Crew task events | `CrewTaskEventDialog` (26 event types) → `NarrativeScreen`; bulk `art_tag` retrofit on outcomes | `CrewTaskEventDialog.gd` |
| A4 | Phase 5 — Travel + PostBattle beats | Narrative wrap on travel events + post-battle (uses the existing `narrative_win`/`narrative_lose` StoryEvent fields) | `TravelPhaseUI.gd`, `PostBattleSequence` |
| A5 | Phase 6 — Atmosphere + polish | `SceneAtmosphereLayer` (GPUParticles2D — research done, jump to Phase C), typewriter text, audio hooks. Sibling inside IllustrationFrame, NOT a child of SceneStage | new `SceneAtmosphereLayer.gd`, `docs/research/scene-stage-atmosphere.md`, [[project-scene-stage-atmosphere-research]] |

### Wiring status (May 27)

The NarrativeScreen integration pattern (branch on `are_narrative_events_enabled()`, present, delegate back) was replicated to three more event sources. All gated, all fall back to the prior UI when the toggle is off or the screen fails to load, all verified (parse + dict shape + `present()` + opener resolution via MCP `run_script`).

- **A1 (partial)**: per-scene art export list persisted at `docs/design/STORY_TRACK_SCENE_ASSETS.md`. The 7 `story_event_0N.json` manifests exist; 02-07 await hand-exported art (render via gradient fallback until then). Real Settings checkbox still pending.
- **A2 / CharacterPhase (done)**: `CharacterPhasePanel.gd` routes the campaign Character phase events (the 7 world-phase events in `src/data/character_events.gd`) through `NarrativeScreen` as a serial chain. NOTE: the 30 D100 *post-battle* character events (`data/campaign_tables/character_events.json`) are a SEPARATE table surfaced in `PostBattleSequence` — that is A4, not done. New art_tag `character_event` → `ship_interior`.
- **A3 / Crew tasks (partial)**: `CrewTaskComponent.gd` routes only the OUTCOME-INDEPENDENT events (INFO_ONLY, GAIN_CREDITS, GAIN_XP, GAIN_STORY_POINT, ROLL_ON_TABLE, SICK_BAY, GAIN_RIVAL, GAIN_PATRON, IMMUNE, DEFERRED) through `NarrativeScreen`. The ~16 interactive types (rolls/choices/pickers/trades) stay on `CrewTaskEventDialog`, which is the engine producing the `outcome` dict `_on_event_completed` needs. Routing those is the remaining A3 work. New art_tag `crew_task_event` → `starport`.
- **A4 / Travel (partial)**: `TravelPhaseUI.gd` presents each starship travel event as a narrative INTRO beat (art_tag `space_travel`); the panel still drives effects/choices. **PostBattle is NOT wired** — `PostBattleSequence` is a 14-step interactive wizard producing irreversible economy state; it warrants a dedicated A4 pass, not a tail-end wire.

---

## Workstream B — Combat modes (the "no minis" ladder)

The standalone-direction work. `battle-systems-engineer`. All modes use actual 5PFH rules — do NOT invent combat systems; values come from the Compendium / `Nominis.json`.

| ID | Sprint | Scope | Key files | Citation |
|----|--------|-------|-----------|----------|
| B0 | **No-Minis fidelity spike** *(gates B1/B2)* | Compare `BattleResolver.resolve_battle()` against the No-Minis ruleset. Decide: align to the book, or keep the current abstraction (and document the divergence). Short, high-information, no UI | `src/core/battle/BattleResolver.gd` vs `data/RulesReference/Nominis.json` | Compendium p.66 |
| B1 | No-Minis Combat mode | The abstract resolution (the standalone spine): round phases (battle-flow events → initiative → firefight), initiative on one die fewer, firefight selects 3 random enemies (4 if 7+), 8 action choices, per-mission notes, Salvage-mission fallback | `BattleResolver.gd`, `src/core/campaign/phases/BattlePhase.gd` | Compendium p.66; `Nominis.json` |
| B2 | **Auto-resolve + Narrative (the bridge)** | Wrap a resolved battle (No-Minis or standard) in `NarrativeScreen` + `SceneStage` — "play it out for me" presented as an illustrated story beat. The convergence of both workstreams; the digital-version pitch | `NarrativeScreen.gd`, `SceneStage.gd`, `BattleResolver.gd` | — |
| B3 | Dramatic Combat completion | Finish the partial scaffold (verified May 26): **Adjusted Shooting** (open 5+, cover 6+), **Duck Back**, **Lunge** consumer (data exists, no consumer), **Dramatic Weapons** stat table; fix the dead `dramatic_effects: []` display + the citation drift. Campaign-setup toggle | `BattleCalculations.gd` (Phase 11), `data/compendium/difficulty_toggles.json`, `BattlePhase.gd` (~1955), `TacticalBattleUI.gd` (~4114) | Compendium p.87-89 |
| B4 | Grid-Based Movement | On-screen 3×3 / 3×4 / 4×4 tactical view; squares are Open or Close-Quarters; ranged/brawl resolved by core rules within. Note (don't silently fix) the book's own balance caveat. Heaviest, most independent | `BattlefieldMapView`, `TacticalBattleUI.gd` | Compendium p.90-93 |

---

## Dependencies & sequencing

```
B0 (fidelity spike) ──> B1 (No-Minis mode) ──> B2 (auto-resolve + narrative, THE BRIDGE)
                                                   ^
A1..A5 (narrative integration, parallel) ──────────┘  (A5 atmosphere showcased by B2)

B3 (Dramatic Combat) ── independent toggle, layers on any representation
B4 (Grid movement)   ── independent mode, heaviest
```

- **B0 gates B1**: don't build/align No-Minis before knowing whether `BattleResolver` already implements it.
- **B1 enables B2**: the narrative bridge wraps the No-Minis resolution.
- **B2 is the strategic peak**: it combines the two shipped systems (narrative scene + auto-resolve) into the "digital version" Modiphius asked for.
- **B3/B4 are independent** and can slot in any order; B3 is lower-risk (finishing existing scaffold), B4 is the largest.
- **Workstream A is parallel** (different agent, no combat dependency).

## Lead sprint (chosen May 27): B0 + B1 — No-Minis Combat

Foundation-first. **Verify before wiring**:

1. **B0 spike**: read `Nominis.json` fully; trace `BattleResolver.resolve_battle()`; produce a parity table (book rule → code presence). Decide align vs keep, and write the decision to `docs/decision-log` or the combat research doc.
2. **B1 wire**: implement/align the No-Minis round structure and resolution to match the book; handle the Salvage-mission caveat with a documented fallback.
3. **Test**: headless resolution-parity checks against `Nominis.json`; a campaign battle resolved end-to-end in No-Minis mode.

Guardrails: every numeric/threshold value must come from the Compendium or `Nominis.json` (no invented combat data — see CLAUDE.md "Data Integrity Rules"). `qa-specialist` is the final verification step.

---

## Open questions carried from the research

- **Fidelity**: is `BattleResolver.resolve_battle()` No-Minis, or a separate abstraction? (B0 answers this.)
- **Salvage**: No-Minis "is not easily usable with the Salvage mission type" (Compendium p.116) — needs a fallback.
- **Doc discrepancy** (fix opportunistically): `CLAUDE.md` lists `docs/rules/core_rulebook.txt`, `compendium_source.txt`, `5PCompendium/` as available extractions; they do not exist. Either regenerate or correct CLAUDE.md.
- **Dramatic Combat citation drift** (B3): code says p.89-95 / p.91 / p.92; the actual sections are Dramatic Combat p.87, Dramatic Weapons p.88-89.
