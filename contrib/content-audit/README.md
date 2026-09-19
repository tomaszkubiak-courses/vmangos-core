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
| Quest item drop rates | 5687 | 2240 | 12 | 1 | 9 | 2 | 0 |
| Spawn rates | 8637 | 1708 | 20 | 11 | 0 | 0 | 9 |

**Lineage** (added by Task 13 for creatures and quest item drops, extended to
spawn rates by Task 14, after the sample above was judged) is a subset of
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
| Common `(kind, entry, zone)` spawn groups with identical count AND respawn | 9343 of 16933 (55%) |

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
-- common spawn groups with identical count AND respawn (cmp.spawn_agg, diffs/06_spawns.sql)
SELECT COUNT(*) FROM cmp.spawn_agg mz JOIN cmp.spawn_agg ac
  ON ac.src='ac' AND ac.kind=mz.kind AND ac.zone=mz.zone AND ac.entry=mz.entry
  WHERE mz.src='mz' AND mz.n=ac.n AND mz.resp_min<=>ac.resp_min;
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

**Follow-up 3 (task-16) widens the loot kind from exact match to a 15%
near-match**, because exact match missed a drifted-but-still-shared row:
AzerothCore routes some loot rows through `reference_loot_template`, which
resolves a value mangoszero still stores raw a few points differently (item
3014: mangoszero 80% flat, AzerothCore's reference table resolves the same
row to 70%). The judged sample cross-checked six such items against pfQuest
as a vanilla reference and found this realm's stored per-creature chance
matched vanilla exactly on all six, while the peers' near-agreed value was
the drifted one. `cmp.peer_lineage`'s `loot` kind now marks a pair `mz`/`ac`
agree on within 15% relative (`cmp._agrees_num(..., 0.15, 0)` on the
percentage-point-scaled effective chance), not just byte-identical pairs -
15%, not 30%, because at 30% the test starts to catch pairs that could be
independent agreement rather than one drifted shared row, and because a
lineage test has to stay far tighter than the 2x `ratio_tol` the finding was
already judged `strong` under, or it proves nothing about shared ancestry.
Measured on this corpus: of the 51 strong `quest_item_drops` findings that
survived the exact-match version, 23 fall within 15% of each other and 36
within 30% - the 15% band moves 23 to `lineage`, leaving 28 `strong`.

**Task 14 extends this to `spawns`' two magnitude fields (`spawn_count`,
`respawn_min`), on different grounds than the level pair above.**
`cmp.strength` judges `lvl_min`/`lvl_max`/`faction`/`rank`/`type` by byte
equality, so a `strong` finding on any one of them already means mz and ac
match exactly - testing that again is circular, which is why creature_stat
needs the *whole pair* (neither field alone is new information, but "both
fields separately happen to match" is). `spawn_count` and `respawn_min` are
different: `cmp.strength_mag` judges them under a TOLERANCE (0.50 ratio / 5
absolute for count, 2x for respawn), so a `strong` finding there only means
mz and ac were *close*, not identical - byte identity is extra information on
each field, independently of the other. A realm can also inherit a shared
spawn count while retuning its own respawn timer, or vice versa, so nothing
requires both to move together the way a level pair does. `cmp.peer_lineage`
therefore carries two kinds for this topic, `spawn_count` and `respawn_min`,
each judged on its own field alone - confirmed by measurement, not just
argument: requiring the joint match above against the pre-Task-14 `strong`
findings gives only 641 of 929 `spawn_count` and 809 of 1023 `respawn_min`,
not the 806 and 902 the per-field kinds actually give (1708 of 1952 overall,
87%).

### Before / after (Task 13, extended to spawns by Task 14 and to a loot
near-match by Follow-up 3)

Per-topic `strong` / `lineage` / `weak` counts on this corpus, immediately
before and after `cmp.peer_lineage` was wired in (quest item drop rates'
"After" column is the exact-match figure from Task 13; the near-match column
is Follow-up 3's further move on top of it). Three topics move; the other
three are unaffected because their comparable kinds are all boolean-shaped
(`relations`) or have no lineage evidence measured against them at all
(`quests`, `quest_rewards`):

| Topic | Before (strong / weak) | After exact-match (strong / lineage / weak) | After near-match (strong / lineage / weak) | Moved to lineage |
|---|---|---|---|---|
| Creatures | 184 / 10650 | 117 / 67 / 10650 | 117 / 67 / 10650 | 67 |
| Connected creatures | 1915 / 10176 | 1915 / 0 / 10176 | 1915 / 0 / 10176 | 0 |
| Quests | 438 / 6084 | 438 / 0 / 6084 | 438 / 0 / 6084 | 0 |
| Quest rewards | 372 / 5340 | 372 / 0 / 5340 | 372 / 0 / 5340 | 0 |
| Quest item drop rates | 2268 / 3419 | 51 / 2217 / 3419 | 28 / 2240 / 3419 | 2240 |
| Spawn rates | 1952 / 6685 | 244 / 1708 / 6685 | 244 / 1708 / 6685 | 1708 |

Total findings per topic are unchanged in every row - `cmp.apply_lineage` only
ever relabels an existing `strong` row, it never adds or removes one. Spawn
rates' 1708 splits 806 of 929 `spawn_count` and 902 of 1023 `respawn_min`.
Quest item drop rates' 23-row near-match move (2217 to 2240) is Follow-up 3's
own figure, not a second independent measurement of the exact-match one.

## Relation and objective findings have a direction

A `relations` finding (vendor/questgiver/questender/link) or a `quests`
`obj:` finding fires when this realm and both peers disagree - but "disagree"
covers two unrelated claims. This realm can carry something neither peer
has, or it can lack something both peers have. `strong` and `weak` do not
distinguish them, and treating both as one undifferentiated pile of
disagreement buries the one the audit exists to find under the other, which
is usually just the peers being a leaner or different content set.

Measured on this corpus: of the 1915 `strong` `relations` findings, 985 are
"this realm has it; neither peer does" and 930 are "this realm lacks it;
both peers have it". The judged sample found the shape concretely - 39 of its
40 `relations` rows were the first kind, and 30 of those were a single PvP
rank-quest cluster (creatures 14733, 15350, 15351) that this realm carries
completely and correctly while neither peer ever imported it; reported once
per row, that one import gap in the peers read as 30 separate defects here.
The same split exists for `quests`' `obj:` findings, on narrower ground: of
28 strong findings, only 6 are a genuine existence gap (this realm's quest
has no row for the objective at all, while both peers agree on one) - the
other 22 have the objective on all three sides and disagree only on the
required count, which is not a direction claim at all.

`diffs/02_relations.sql` and `diffs/03_quests.sql` now write the direction
into the finding's `note` column at the point the row is inserted - "this
realm has it; neither peer does" or "this realm lacks it; both peers have
it" - rather than leaving a reader to reconstruct it from the value columns.
Neither direction is suppressed: "this realm has content the peers lack" is
occasionally a real finding in its own right (custom content that should not
be there, or a spawn belonging to another patch), and the audit's own
doctrine is that suppression hides more than it saves. `report.py`'s
per-topic count line gains the same split, so a reader ranking zones can see
at a glance how many of a topic's findings are the peers being short rather
than this realm.

## A vendor with no stock needs no peer at all

The vendor findings are the least trustworthy block this audit produces.
`vendor:<item>` rows are judged the same way as every other relation - two
peers agreeing against this realm - but there is no independent vanilla
reference to settle them, and the one reference this project uses elsewhere
does not help: pfQuest's vanilla database is generated **from a VMaNGOS
database** (its own README says so), so it shares this realm's lineage. Its
agreement is inheritance, not evidence, exactly like the shared loot rows
`cmp.peer_lineage` exists to catch. Measured on this corpus: of the 595
`strong` vendor findings shaped "this realm has it; neither peer does",
pfQuest confirms the pair on 595 - all of them - which says nothing about
vanilla and everything about where its data came from.

Where a reference of the same lineage still carries information is when it
*disagrees*. Of the 792 `strong` vendor findings shaped "this realm lacks
it; both peers have it", pfQuest lists the pair on 55 - and all 55 sit on
just three NPCs that have no `npc_vendor` row at all.

That last shape does not need a reference database, a peer, or a tolerance.
`creature_template.npc_flags` bit `0x4` is `UNIT_NPC_FLAG_VENDOR`: the client
offers "Browse Goods" and the core answers `CMSG_LIST_INVENTORY`. If
`npc_vendor` then has no row for that creature, the player gets an empty
window - a contradiction between two halves of this database, provable from
this database. `diffs/02_relations.sql` block (c) reports it as
`vendor_flag_no_stock`, hardcoded `strong` with the peers' item counts as
context only, the same single-source shape as `xp_self_consistency`.

It finds 17 rows over 13 creatures (four PvP quartermasters are spawned in
two zones each and are reported in both, like every other zone-keyed
finding). The join to `cmp.zone_creature` is what keeps it honest: only
creatures actually spawned somewhere are considered, which silently drops
the 16 unspawned placeholders in `creature_template` - "Programmer Vendor",
"Eric's AAA Special Vendor", the `[UNUSED]` rows - without needing a name
blocklist. Eight of the 13 have peer stock to copy from; the other five have
none in either peer either, and for those the open question is which half is
wrong, the flag or the missing stock.
