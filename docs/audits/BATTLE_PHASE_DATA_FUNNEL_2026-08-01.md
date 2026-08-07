#### The battle-phase data funnel (Aug 1 2026) — the mission carries its own identity

Follow-up audit to the sprint above, on the BOUNDARIES rather than the interior.
Same defect shape six more times: **a post-battle consumer reading a key that no
producer anywhere ever wrote.** Every rule was already implemented and correct;
each was gated on data that never arrived, and nothing errored, because
`.get(key, default)` on a missing key is a silent default, not a fault.

The going-forward rule: **anything the post-battle sequence needs to know about
the scenario must be stamped onto `mission_data` before the battle**, and pass
through `BattleResultNormalizer` — the one chokepoint every path crosses (played,
LOG_ONLY, in-battle auto-resolve, map auto-resolve). Adding a consumer read
without a producer write is the bug, not the feature.

| Key | Book rule it gates | Was |
|---|---|---|
| `rival_id` | p.119 Step 1 removal roll ("On a 4 or better [...] remove them") | never set → holding the field vs a Rival could only ADD Rivals |
| `patron_id` | p.119 Step 2, BOTH directions (add on success, errata v1.06 remove on failure) | never set → the whole step inert |
| `is_invasion` | p.120 no payment, p.120 no Finds, p.121 no Loot, p.119 skip | only `mission_source` existed; nothing translated it |
| `enemy_is_invasion_threat` | p.121 Step 6, the Invasion check itself | no producer, though `enemy_types.json` has always carried the profiles' "Invasion Threat" |
| `invasion_evidence_found` | p.121 Finds 26-35 / 76-90 feeding Step 6 | the "instead find Invasion Evidence" branch did not exist |
| `enemy_category` | p.101 Roving Threats "never become Rivals" | no skip existed |

**`RivalEncounterCheck.gd` (p.85) is the Rival gate.** The old check could not run:
it asked `RivalBattleGenerator.check_rival_encounter()` (**zero definitions
repo-wide**, so the guard was permanently false) and fell back to
`progress_data["rival_count"]`, which nothing writes. Rivals never tracked the
crew down in any campaign. Count comes from the canonical `campaign.rivals`;
p.78 Decoy adds to the roll (**higher = evade**); the book then says *"Select the
exact Rival at random from those on your list"* — that id is the only reason the
post-battle step can work.

**Battlefield Finds is ONE roll (p.121), gated on Hold the Field (p.120), never
after an Invasion (p.120).** It rolled once *per crew member*. The objective does
NOT gate it — "you may do so even if you failed to achieve or did not have an
objective" — only the field does.

**Known gap (reported, not silently skipped):** the Track crew task (p.78, "6+
locates a Rival **of your choice**") resolves but has no picker, so
`tracked_rivals` stays empty and the p.119 "+1 if you Tracked them down" modifier
is still off. Choosing for the player would fabricate a decision the book gives
them.

---

*Extracted from `CLAUDE.md` on 2026-08-06 to keep the always-loaded file small. The durable rules from this audit remain inline in CLAUDE.md; this file is the full narrative record.*
