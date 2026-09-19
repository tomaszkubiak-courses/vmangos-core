# Content audit pipeline

Compares this realm's world database against three other server databases and
writes one Markdown discrepancy report per game zone.

Design: `docs/superpowers/specs/2026-09-16-content-audit-pipeline-design.md`

## Setup

    cp config.env.example config.env    # then fill it in; config.env is gitignored
    sh build_corpus.sh                  # 30-60 minutes, ~3 GB

`build_corpus.sh` starts a throwaway MySQL instance and imports eight schemas
into it: `v` (a snapshot of the live world database), `mz`, `tw`, `ac`, the
three live realm databases so a scratch core can boot against the corpus
rather than against the live server, and `dbc` (a snapshot of the live DBC
reference tables, needed later to resolve zone names via `dbc.area_table`).

The live databases are only ever read, and only with `--single-transaction`, so
the running server is unaffected.

## Reading the import logs

`logs/*.err` hold the failures from the `--force` update passes. Errors naming a
schema other than the one being built are expected. An error naming a table the
pipeline reads is not - a half-applied schema is indistinguishable from missing
content in the reports.

## Running

    sh export_coords.sh      # spawn coordinates out of the corpus
    sh run_resolver.sh       # resolve them to game areas through the core
    sh load_areas.sh         # resolved areas back into the corpus
    sh build_views.sh        # normalising views for all four sources
    sh run_diffs.sh          # populate cmp.findings
    python report.py 40 1581 # one report per zone id

## Checks

    python test_pipeline.py

## Pilot results (Westfall and The Deadmines)

Measured by hand-checking a drawn sample against the sources' raw tables - not
against the normalising views, because a view cannot be the witness for its own
correctness. 112 rows, up to 20 per topic, drawn from the rows the report
actually renders in its six topic tables (the collapsed restatements and the
appendix moves are excluded: the rate that matters is the one a reader meets in
the body of the document). The draw is reproducible - ordering is a
deterministic hash of entity id, zone and field rather than `RAND()`.

Every row was judged into one of three verdicts. **Real** means the values
reproduce and the difference is one this realm would want to act on. **Expected**
means they reproduce but the difference is correct for a vanilla realm and needs
no action - post-vanilla content, WotLK rescaling, a fork's own custom content.
**Artefact** means the finding did not survive contact with the raw data.

| Topic | Findings | Lineage | Sampled | Real | Expected | Artefact | Unsure |
|---|---|---|---|---|---|---|---|
| Creatures | 10834 | 67 | 20 | 19 | 1 | 0 | 0 |
| Connected creatures | 12091 | 0 | 20 | 13 | 7 | 0 | 0 |
| Quests | 6522 | 0 | 20 | 0 | 19 | 1 | 0 |
| Quest rewards | 5712 | 0 | 20 | 16 | 2 | 2 | 0 |
| Quest item drop rates | 5687 | 2217 | 12 | 1 | 9 | 2 | 0 |
| Spawn rates | 8637 | 0 | 20 | 11 | 0 | 0 | 9 |

**Lineage** (added by Task 13, after the sample above was judged) is a subset of
each topic's `strong` count, not an addition to `Findings` - it never adds or
removes a row, only relabels one that was already `strong`. It means
mangoszero and AzerothCore agree with each other and disagree with this realm
*and* their agreement traces back to one shared-ancestor database row, not two
independent sources reaching the same conclusion (see "Peer independence" below).
The sample judging above predates this label, so its Real/Expected/Artefact/Unsure
columns still count lineage rows under whichever verdict their old `strong` label
earned them.

The quest topic was expected to be the noisiest: AzerothCore's `exp` column
filters post-vanilla creatures cleanly, but quests have no equivalent marker and
many were revamped between 1.12 and 3.3.5.

### What the sample changed

The judging found six structural defects, and none of them was a tolerance
problem, so **no tolerance was changed**. All six are fixed; the finding counts
in the table above are the corrected ones, while the verdict columns were
measured before the fixes, so they still count artefacts that no longer occur.

- AzerothCore's reputation reward is a signed index into a DBC, not an amount
  (its range is -7..9 against vmangos' -500..500), so it disagreed with the realm
  on 3275 findings for reasons unrelated to content. It now abstains, as it
  already did for quest experience and trainer lists. No corroborated finding was
  lost: every one of those rows was `weak`.
- The vanilla-lineage views read `RewSpell` but not `RewSpellCast`, and 319
  quests use the latter against only 95 for the former - so the audit reported
  the realm as missing spell rewards it actually has. Both columns are read now.
- AzerothCore stores a quest level of -1 to mean "scales to the player", which
  was cast unsigned and reached the reports as 18446744073709551615 on 777 rows.
- AzerothCore's gameobject respawn time is a categorical default rather than
  tuned data - 120 seconds covers 36.5% of its table - and 5157 respawn findings
  rested on its word alone. It now counts only where mangoszero corroborates it,
  the rule creature health already used.
- 123 drop-rate findings compared loot rows for gameobjects that have no template
  row in any source: orphaned rows in every database, compared against each other.
- A source that has an NPC but no vendor row for an item is saying the NPC does
  not sell it. That was stored as an abstention and rendered as a blank cell
  under a caption promising the source could not express the field, on 8286 of
  the relation findings. Absence and abstention are now distinct.

### Where no tolerance helps, recorded rather than tuned

The quest topic is 19 of 20 **expected** rather than artefact, and two field
groups produce most of it: `req_race`, where this realm stores 0 for
"unrestricted" and the peers store an explicit race bitmask, and `next`, where
this realm records a quest chain on the successor's `PrevQuestId` while
AzerothCore records it on the predecessor's `RewardNextQuest`. Both are
conventions, not content, and both need a candidate-selection rule rather than a
number. Tuning a tolerance until the topic empties would report nothing and hide
everything.

The spawn topic's nine `unsure` rows are the AzerothCore respawn default above.
They are counted as unsure rather than artefact because "this is a default" could
not be proven from a raw table, only inferred from its distribution.

Two caveats on the verdicts themselves, from the judging: the `req_race`
explanation was spot-checked on 2 of its 15 rows rather than proven for all, and
AzerothCore's `RewardFactionOverrideN` column, which does carry a genuine raw
amount, is populated on 97 rows and is still not read.

## Peer independence: mangoszero and AzerothCore are not independent sources

The `strong` label rests on a claim: mangoszero and AzerothCore reached the same
conclusion independently, so their agreement is real corroboration. That claim
does not hold everywhere - both descend from MaNGOS and still carry stretches of
the exact same rows, and a `strong` finding built on one of those shared rows is
one witness counted twice, not two.

Measured directly against the corpus (2026-09-19, reproducible with the queries
below):

| Evidence | Figure |
|---|---|
| `(entry, item)` loot pairs in both `creature_loot_template`s | 56479 |
| ...of those, with byte-identical chance | 53104 (94%) |
| AzerothCore's whole `creature_loot_template` | 93648 rows |
| mangoszero's `npc_vendor` rows also in AzerothCore | 11283 of 12558 (90%) |
| Common creatures with identical min AND max level | 7246 of 9112 (80%) |

```sql
-- shared loot pairs / byte-identical chance
SELECT COUNT(*) FROM (SELECT DISTINCT mz.entry, mz.item FROM mz.creature_loot_template mz
  JOIN ac.creature_loot_template ac ON ac.Entry=mz.entry AND ac.Item=mz.item) x;
SELECT COUNT(*) FROM (SELECT DISTINCT mz.entry, mz.item FROM mz.creature_loot_template mz
  JOIN ac.creature_loot_template ac ON ac.Entry=mz.entry AND ac.Item=mz.item
  AND ac.Chance=ABS(mz.ChanceOrQuestChance)) x;
-- vendor overlap
SELECT COUNT(*) FROM mz.npc_vendor mz JOIN ac.npc_vendor ac ON ac.entry=mz.entry AND ac.item=mz.item;
-- common creatures with an identical level pair
SELECT COUNT(*) FROM mz.n_creature mz JOIN ac.n_creature ac ON ac.entry=mz.entry
  WHERE mz.lvl_min=ac.lvl_min AND mz.lvl_max=ac.lvl_max;
```

What it cost before this was fixed: the Alterac Valley zone report, 1418 strong
findings, read as the worst zone in the audit. Checked against pfQuest as a
vanilla reference, this realm is right on seven of its nine AV turn-in items,
and the peers' ~100-sources-per-item was the post-vanilla mapping both had
inherited, not a defect here.

**Existence overlap alone is not this signal.** Two independently correct
databases would both carry a row for a drop or a sale that genuinely exists, so
demoting a finding just because both peers have *some* row for its key would
empty the topic of real content - which is why `npc_vendor`, `creature_queststarter`
/ `creature_involvedrelation`, and `creature_linking` (the `relations` topic's
`vendor`/`questgiver`/`questender`/`link` kinds) get no row-level lineage
treatment at all: whether an NPC sells an item is boolean-shaped, and a value
space of `{0, 1}` is not wide enough that agreeing by chance is implausible.
Their 90% vendor-row overlap above is real and worth knowing, but it can only be
reported as a topic-level fact, not converted into a per-row verdict - the
`relations` topic's `strong`/`weak` split is unchanged by Task 13 for exactly
this reason.

Where the value space *is* wide enough - a float drop chance, a level **pair**
(not a bare level: cmp.strength's own byte-equality test already means a
`strong` `lvl_min` finding implies mz and ac agree on that one field exactly, so
testing the same field again proves nothing; the pair test above, `lvl_min` AND
`lvl_max` both agreeing, is the one actually checked) - `cmp.peer_lineage`
(`contrib/content-audit/views/derived.sql`) marks the matching keys, and
`cmp.apply_lineage` (`diffs/00_schema.sql`) relabels a `strong` finding built on
one of them to `lineage`. `lineage` still means this realm diverged from what
both peers inherited - it is the most actionable signal the audit produces - it
is just not two independent sources agreeing, so it is kept out of the `strong`
count.

### Before / after (Task 13)

Per-topic `strong` / `lineage` / `weak` counts on this corpus, immediately
before and after `cmp.peer_lineage` was wired in. Two topics move; the other
four are unaffected because their comparable kinds are all boolean-shaped
(`relations`) or have no lineage evidence measured against them at all
(`quests`, `quest_rewards`, `spawns`):

| Topic | Before (strong / weak) | After (strong / lineage / weak) | Moved to lineage |
|---|---|---|---|
| Creatures | 184 / 10650 | 117 / 67 / 10650 | 67 |
| Connected creatures | 1915 / 10176 | 1915 / 0 / 10176 | 0 |
| Quests | 438 / 6084 | 438 / 0 / 6084 | 0 |
| Quest rewards | 372 / 5340 | 372 / 0 / 5340 | 0 |
| Quest item drop rates | 2268 / 3419 | 51 / 2217 / 3419 | 2217 |
| Spawn rates | 1952 / 6685 | 1952 / 0 / 6685 | 0 |

Total findings per topic are unchanged in every row - `cmp.apply_lineage` only
ever relabels an existing `strong` row, it never adds or removes one.
