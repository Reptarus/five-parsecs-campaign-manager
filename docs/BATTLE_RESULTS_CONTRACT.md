# Battle Results Contract (SSOT)

**Owner:** `src/core/battle/BattleResultNormalizer.gd`
**Established:** 2026-07-10 (wiring-audit sprint, Wave 1a)

This is the single source of truth for the battle-result dictionary that flows
**producer → normalizer → post-battle consumers**. Before this contract existed,
the consumers read an OLD key vocabulary (from the bypassed legacy
`src/core/battle/BattleResults.gd` `to_dict()`) while the live producers emitted
a NEW one — so injuries silently never applied, Danger Pay dropped, "A Bitter
Day" never fired, and journal entries stamped turn 0. Every mismatch degraded
silently (default-valued reads), which is why tests, `--headless`, and MCP all
passed through it.

## The pipeline

```
PRODUCER (one of 3)                     NORMALIZER                 CONSUMERS
TacticalBattleUI._resolve_battle    ┐   CampaignTurnController.    PostBattlePhase.gd
TacticalBattleUI auto_result_dict   ├─► _normalize_battle_results  + post_battle/*.gd
BattleResultsInputForm._on_submit   ┘   (calls the normalizer      + PostBattleSequence.gd
                                        BEFORE set_battle_results)
```

`GameState.set_battle_results()` DEEP-DUPLICATES on store, so the normalizer MUST
run before it — mutating the stored dict afterward is a silent no-op.

## Rules

1. **Producer keys are pinned by tests** (`test_battle_results_input_form.gd`,
   `test_post_battle_success_cascade.gd`) and read directly by PostBattleSequence.
   NEVER rename or remove a producer key.
2. **The normalizer is ADD-ONLY and IDEMPOTENT** — `if not results.has(k)` before
   every write. It fills the consumer-side keys the producers don't carry; it
   never overwrites an existing value. Re-running it is a no-op.
3. **New consumer need?** Add the key to the normalizer (mapped from producer
   data or the mission), plus a case in `test_battle_result_normalizer.gd`. Do
   NOT add a fourth read-fallback in a consumer.

## Producer vocabulary (24 keys, shared across the 3 producers)

`victory, won, success, held_field, objective_id, objective_met, rounds_fought,`
`crew_casualties (int), crew_injuries (int), crew_casualties_data (array),`
`crew_injuries_data (array), crew_participants (array of character objects),`
`defeated_enemies, enemies_defeated_count, enemies_remaining, crew_alive,`
`is_red_zone, is_black_zone, is_quest_finale, mission_source, mission_type,`
`auto_resolved, psionic_uses` (+ `objective_progress` on the 2 TacticalBattleUI
producers; the LOG_ONLY form adds `fled_early, enemy_type`).

## Normalizer-added keys (consumer vocabulary)

| Key | Source | Consumer |
|-----|--------|----------|
| `turn` | `campaign.progress_data["turns_played"] + 1` | journal/entry stamps (11 sites) |
| `mission_source` | mission `mission_source`/`source` | PaymentProcessor patron logic |
| `danger_pay` | mission `danger_pay` (numeric only) | PaymentProcessor Get Paid (Core Rules p.120) |
| `patron_id` | mission (patron missions only) | RivalPatronResolver |
| `faction_id`/`faction_job_id`/`rival_id`/`is_invasion` | mission passthrough | Payment/Rival/Loot |
| `is_rival_mission` | derived from mission_source/rival_id | PaymentProcessor |
| `injuries_sustained` | mapped from `crew_injuries_data` (crew_id/name/origin/species_id) | InjuryProcessor |
| `casualties` | mapped from `crew_casualties_data`, shape `{...,type:"killed"}` | Bitter-Day + XP |
| `is_rival`/`rival_id` on each `defeated_enemies` element | when mission carried a rival | RivalPatronResolver |

## Consumer read-fallbacks kept (both keys stay live)

- `PostBattlePhase.gd`: `enemies_defeated_count` → `enemies_defeated` (map
  auto-resolve writes the bare key); `defeated_enemies` → `defeated_enemy_list`
  (legacy `BattleResults.gd` key).
- `LootProcessor.gd`: `is_quest_finale` → `quest_final_stage`/`is_quest_final`.

## Cut list — NOT wired (need per-kill attribution = feature work)

`first_casualty_by`, `unique_kills` (ExperienceTrainingProcessor XP bonuses),
`kills_by_character`, `damage_dealt_per_unit`, `damage_taken_per_unit`,
`units_downed` (PostBattleCompletion per-unit stats). These require the battle
sim to track per-kill attribution, which it does not. The consumers read them
with empty defaults (harmless). Wiring them is a battle-sim feature, not a
contract fix. **Rulebook check pending** (Core Rules pp.121-122 XP rules) — if
the book does not grant first-casualty/unique-kill XP, delete the reads as
fabricated; if it does, they become a feature-backlog item.
