# Content audit pipeline — design

Date: 2026-09-16
Status: approved, ready for implementation planning
Scope: sub-project 1 of three (see Decomposition)

## Problem

Levelling through this realm surfaces content defects — missing or misplaced creatures,
quests that cannot be started or completed, rewards that look wrong, quest items that
never drop, spawns that are too sparse or respawn too slowly. The defects are found one
at a time, by playing, which is the slowest possible discovery method and gives no
indication of how many remain.

Three other World of Warcraft server databases are checked out beside this repository and
describe overlapping content. Comparing them against this realm's world database, area by
area, turns defect discovery into a batch process.

## Deliverable

A **discrepancy report per area**. The pipeline produces reviewable Markdown; a human
decides what is a real defect. The pipeline never writes SQL and never modifies the live
world database. Acting on findings is out of scope for all three sub-projects.

## Sources

| Key | Source | Lineage | Value | Hazard |
|---|---|---|---|---|
| `v` | this realm's live world DB | VMaNGOS / Nostalrius | the subject | — |
| `mz` | mangoszero-database | MaNGOS Zero, vanilla 1.12 | only independent vanilla peer | older schema vocabulary |
| `tw` | tortoise-wow | VMaNGOS fork, "classic plus" | carries their fixes | shares VMaNGOS bugs; adds custom content |
| `ac` | azerothcore-wotlk | TrinityCore, 3.3.5 | best sniff fidelity | expansion drift |

The Classic-Wow-Database checkout is **not** a source. It is an aowow-derived PHP viewer
for 1.12 that renders a MaNGOS-shaped database; it contributes no content data. It may
later be useful as a browsing front end, which is a separate question.

pfQuest is likewise not a source for this sub-project. Its data is derived and already
aligned with this realm, so it would mostly confirm what `v` says.

### Weighting — consensus, no authority

No source is treated as correct. A finding is a disagreement, and a human adjudicates it.

Because `tw` is a fork of `v`, `tw` agreeing with `v` carries no information. It counts
as a vote only when it disagrees with `v`.

- **Strong** — `v` differs from both `mz` and `ac`, and `mz` and `ac` agree with each other.
- **Weak** — `v` differs from exactly one of `mz` / `ac`, or `mz` and `ac` disagree.
- **Appendix** — the entity is absent from `v` and `mz` but present in `ac` (probable
  post-vanilla content, cross-checked against `ac.creature_template.exp = 0`), or present
  only in `tw` (probable classic-plus custom content).

Appendix entries are reported, not discarded. An entity only AzerothCore has is
occasionally real vanilla content that both vanilla databases dropped, and that case is
exactly the kind of gap this exercise exists to find.

## Topics

1. **Creatures** — template presence, level range, faction, rank, type, NPC flags, and
   effective health at the minimum and maximum level of the range.
2. **Connected creatures** — four relationship families, all in scope:
   - linked pulls, groups and spawn pools;
   - quest relations (which NPC starts and ends which quest);
   - vendor stock, trainer lists, gossip menus;
   - summons and spawn-on-death / spawn-on-event adds.
3. **Quests** — presence, level, minimum level, race and class gating, prerequisite and
   follow-up chain links, exclusive groups, objectives.
4. **Quest rewards** — reward and choice items, money, reputation, spell rewards, and
   experience.
5. **Quest item drop rates** — the effective probability that an item a quest objective
   requires drops from a given loot table, with loot groups resolved and reference tables
   expanded.
6. **Spawn rates** — per (area, entry) spawn count, minimum and maximum respawn time,
   wander distance; the same for gameobject spawns.

## Decomposition

Three sub-projects. Only SP1 is specified here.

- **SP1 — pipeline and pilot.** Build the corpus, the area resolver, the normalizing view
  layer, the diff engine and the report generator. Prove all six topics end to end on one
  outdoor zone and one instance.
- **SP2 — outdoor sweep.** Run the pipeline over every vanilla zone, batched by levelling
  band. Mostly execution; the normalizing views will need repair as unusual zones surface.
- **SP3 — instances.** Same topics, different questions: boss loot tables, trash spawn
  counts, encounter-linked spawns, instance quest chains. Enough structural difference to
  earn its own spec.

**Pilot: Westfall (zone 40) and The Deadmines (zone 1581).** Between them they exercise
every topic — a quest chain with prerequisites, quest item drops, vendors and a flight
master, linked Defias patrols, a spawn-on-event script at the harvest golems, and an
attached instance. Both are small enough that a human can read the entire report and judge
whether each finding is real, which is the only thing that validates a pilot.

## Architecture

### Component 1 — the corpus

A second `mysqld`, started from the portable MySQL install that already ships with the
server directory, using its own datadir outside every repository, on port 3307, launched
with `--no-defaults` so it cannot inherit the live server's configuration.

Seven schemas:

| Schema | Built from |
|---|---|
| `v` | `mysqldump --single-transaction` of the live world DB |
| `mz` | mangoszero `World/Setup/mangosdLoadDB.sql` (schema), then `World/Setup/FullDB/*.sql` (data), then `World/Updates` release directories in order |
| `tw` | tortoise-wow `sql/base/tw_world_*.sql` (each file carries its own `CREATE TABLE`), then `sql/database_updates` |
| `ac` | azerothcore `data/sql/base/db_world/*.sql`, then the ~854 files in `data/sql/updates/db_world` in filename order |
| `characters`, `realmd`, `logs` | copied from the live instance, small; present only so a scratch `mangosd` can boot against the corpus instead of the live databases |

The live world database is read with `--single-transaction`. Every table in it is InnoDB,
so the dump takes no locks and the running server is unaffected.

Setup is one idempotent script: drop schema, recreate, import, log. The AzerothCore update
run uses `--force` and **keeps its failure log as an output of the build, not as noise**.
Some failures are expected — updates that reference schemas outside `db_world` — but an
unreviewed failure log is how a half-applied schema gets diffed against as though it were
complete.

Approximate cost: 3 GB of disk and 30–60 minutes for the initial build, dominated by the
AzerothCore import.

### Component 2 — the area resolver

`creature` and `gameobject` carry map and coordinates but no zone or area column, so
nothing partitions by area until coordinates are resolved.

`TerrainManager::GetZoneAndAreaId(zoneId, areaId, mapId, x, y, z)`
(`src/game/Maps/GridMap.h`) does exactly this, lazily loading terrain and requiring no
`Map` object. It is authoritative by construction: it returns what the running server
itself believes the area to be.

A temporary console command added to `src/game/Commands/DebugCommands.cpp` reads a CSV of
`src,kind,id,map,x,y,z` and writes the same rows with `zone,area` appended. It runs on a
**scratch `mangosd`** whose four database connections point at the corpus instance, so
neither the live server nor live character data is involved. Start it, run the command,
exit.

Flow: build corpus → export the union of all four sources' spawn coordinates
(roughly 900k rows) to CSV → run the resolver → `LOAD DATA INFILE` the result back into a
`cmp.areas` table → join to the already-imported `dbc.area_table` for area names and
parent zones.

Two accepted limits:

- AzerothCore spawns on maps with no 1.12 map file (Outland, Northrend, the Blood Elf and
  Draenei starting areas) resolve to nothing and drop out. That is the correct outcome,
  but the dropped count is **reported**, because an unexpectedly large one means the map
  data is not where the scratch server thinks it is rather than that the content is
  post-vanilla.
- Where a vanilla zone's area data changed between 1.12 and 3.3.5, an AzerothCore spawn
  can resolve into a neighbouring subzone. Reports roll up to zone level, which absorbs
  nearly all of this.

The command is marked temporary and removed once the resolver CSV exists. It is not a
feature; re-running it costs little enough that keeping it in the tree buys nothing.

### Component 3 — normalizing views

The three lineages share almost no column vocabulary. `creature_template` alone spells the
minimum level `level_min`, `MinLevel` and `minlevel`; mangoszero splits faction into
`FactionAlliance` and `FactionHorde` where the others have one column.

Each source therefore gets one view set inside its own schema, all exposing the same seven
shapes:

```
n_creature  (entry, name, lvl_min, lvl_max, faction, rank, type, npc_flags)
n_spawn     (kind, entry, zone_id, area_id, map, resp_min, resp_max, wander)
n_quest     (entry, title, lvl, min_lvl, zone_or_sort, prev, next, excl_group,
             req_race, req_class)
n_quest_obj (quest, kind, target, count)        -- npc | item | go | rep
n_quest_rew (quest, kind, id, count)            -- item | choice | money | rep | spell
n_loot      (tbl, entry, item, chance, grp, ref, quest_only, cmin, cmax)
n_rel       (kind, npc, target)                 -- questgiver | questender | vendor |
                                                -- trainer | link | summon
```

Diff queries touch `n_*` and nothing else. This is the boundary that matters: adding a
fifth source later is one more view set and zero changes to any diff query, and it is what
keeps SP2 from becoming a rewrite.

Three further shapes sit on top of those seven. They cannot be produced by renaming
columns, because each source computes the value through its own pipeline and the view has
to reproduce that pipeline before the numbers mean the same thing. They are where most of
the risk in this component lives.

#### Effective health — `n_creature_hp (entry, lvl, hp)`

| Source | Pipeline |
|---|---|
| `v`, `tw` | `creature_classlevelstats` by (level, `unit_class`) → `base_health` × `creature_template.health_multiplier` |
| `ac` | `creature_classlevelstats` by (level, class) → `basehp0` × `creature_template.HealthModifier` |
| `mz` | `creature_template.MinLevelHealth` / `MaxLevelHealth`, already absolute |

Evaluated at both ends of the level range. AzerothCore's vote here is **advisory only**:
WotLK inflated creature health systematically, so an AC disagreement is evidence about
nothing unless `mz` agrees with it.

#### Quest experience — `n_quest_xp (quest, xp, awards_xp)`

VMaNGOS stores `quest_template.RewXP` outright. MaNGOS Zero has no such column —
`Quest::XPValue` derives the figure from `RewMoneyMaxLevel` and `QuestLevel` through a
piecewise divisor, at full value when the player's level matches the quest's. Both sources
carry those two inputs, so the vanilla formula reproduces as a `CASE` expression over
`QuestLevel` and the comparison is exact.

This yields a second check for free. Running the same formula against **VMaNGOS's own**
`RewMoneyMaxLevel` and `QuestLevel` and comparing it to its stored `RewXP` finds quests
whose reward disagrees with the vanilla formula — a defect that needs no second source to
confirm, and one the consensus rule would otherwise never surface.

AzerothCore cannot vote on the number. `RewardXPDifficulty` is an index into `QuestXP.dbc`,
which is not available here, and WotLK rebalanced quest experience regardless — the figure
would be wrong even with the file. AC votes only on `awards_xp`, the boolean.

#### Effective drop chance — `n_loot_eff (tbl, entry, item, p_drop, quest_only)`

The lineages disagree about where meaning lives. AzerothCore splits it into columns —
`Reference`, `QuestRequired`, `Chance`, `GroupId`. VMaNGOS and MaNGOS Zero overload signs:
a negative `ChanceOrQuestChance` means quest-only, a negative `mincountOrRef` means a
reference into `reference_loot_template`. Unpacking the signs is mechanical.

What is not mechanical is that a raw chance column is not a drop probability. Rows in a
group with `groupid > 0` compete for one roll, explicit chances are absolute within that
roll, and members with chance 0 divide the remainder. References have to be expanded — a
recursive CTE, since depth is rarely more than two. Only after all of that does comparing
a number across sources mean anything, which is why topic 5 depends on this view rather
than on `n_loot` directly.

### Component 4 — the diff engine

One SQL file per topic, each writing rows into a single findings table:

```
findings(zone_id, topic, entity_kind, entity_id, field,
         v_value, mz_value, tw_value, ac_value, strength, note)
```

Entity identity is the Blizzard entry id, which is shared across all four sources for
creatures, quests, items and gameobjects. **Spawn GUIDs are not comparable.** Spawn
comparison is therefore an aggregate per (zone, entry): how many spawns, and what respawn
window — never a per-GUID diff.

#### Tolerances

Exact equality on numbers would make the report entirely noise.

- Effective drop chance: flag at a ratio of 2x or more, or an absolute gap of 5 points
  or more.
- Respawn time: flag at a ratio of 2x or more.
- Spawn count per (zone, entry): flag at a difference of 50% or more, or 5 spawns or more.
- Effective health: flag at 20% or more. Tighter than the others because health is a
  resolved number rather than a designer's round figure, so a real disagreement shows up
  small.
- Quest experience: flag at any difference. Both vanilla sources compute it from the same
  formula over the same inputs, so there is no legitimate spread to absorb.

#### Comparability limits

Two sources are deliberately not given a full vote on two topics:

- **AzerothCore does not vote on quest experience numbers**, only on whether a quest
  awards experience at all. The figure is unavailable and would be WotLK-rebalanced if it
  were.
- **AzerothCore's health vote is advisory**, counting only when MaNGOS Zero agrees with
  it, because WotLK inflated creature health as a matter of policy rather than per
  creature.

Both limits are stated in each report so a reader knows why a health or experience finding
carries fewer votes than the strength rule would otherwise suggest.

### Component 5 — the report generator

One Markdown file per zone:

```
Summary                       finding counts by strength
1. Creatures
2. Connected creatures        2a linked/groups  2b quest relations
                              2c vendor/trainer/gossip  2d summons
3. Quests
4. Quest rewards
5. Quest item drop rates
6. Spawn rates and counts
Appendix A                    AzerothCore-only entities (probable post-vanilla)
Appendix B                    tortoise-only entities (probable classic-plus custom)
Appendix C                    spawns whose coordinates resolved to no area
Comparability notes           where AzerothCore's vote is reduced, and why
```

Section 4 carries one extra block: quests whose stored `RewXP` disagrees with the vanilla
formula applied to their own `RewMoneyMaxLevel` and `QuestLevel`. These are
single-source findings and are listed separately from the consensus ones, because no
amount of cross-source agreement is relevant to them.

Each finding is one table row: entity, field, the four values, strength, one-line note.

Generation runs each topic's SQL through the MySQL client in batch mode and pipes the TSV
into a standard-library Python script that assembles the Markdown. No database driver, no
ORM, no new dependency.

Reports are written to `doc/local/content-audit/`, which `.gitignore` already excludes.
That keeps forty zones of generated Markdown out of the core repository's history.

## Verification

`test_pipeline.py`, five assertions, no framework:

1. **Resolver** — Hogger resolves to Elwynn Forest and Edwin VanCleef to The Deadmines.
2. **Normalization** — every source's `n_quest` view is non-empty, and one known Westfall
   quest has the same objective shape in `v` and `mz`.
3. **Consensus rule** — against a synthetic fixture, `v=1, mz=2, ac=2` yields *strong*
   and `v=1, mz=2, ac=1` yields nothing.
4. **Effective drop chance** — against a hand-built loot table: an ungrouped 25% row
   yields 0.25; a group of one explicit 30% row and two chance-0 rows yields 0.30 and
   0.35 each; a row referencing a sub-table yields the sub-table's own resolved
   probability. Reference expansion terminates on a table that references itself.
5. **Quest experience formula** — a quest with a known `RewMoneyMaxLevel` and
   `QuestLevel` produces the figure MaNGOS Zero's `Quest::XPValue` produces for the same
   inputs, checked at a level in each branch of the piecewise divisor.

Three and four are the ones that matter. The consensus rule and the loot probability
resolution are the only real logic in the pipeline; everything else is transport, and a
wrong probability is worse than no probability because it looks authoritative.

## Out of scope

No user interface. No SQL fix generation. No locale, spell or talent comparison. No
scheduling and no incremental refresh — regenerating a zone is cheap enough that caching
would cost more than it saves.

Nothing is excluded from the six topics themselves. Creature health, quest experience and
loot group resolution were each considered for deferral and each kept, because all three
fall inside topics 1, 4 and 5 respectively and dropping them would have quietly shrunk
the brief.

## Risks

- **AzerothCore import failures.** 854 update files applied with `--force`. Mitigated by
  treating the failure log as a reviewed output.
- **Normalizing views are where the effort actually is.** Ten shapes across four sources
  is forty view definitions, each needing its own column archaeology, and three of the
  ten reproduce a source's internal computation rather than reading a column. The pilot
  exists mostly to find out how bad this is before committing to SP2.
- **Effective drop chance is the one piece that can be confidently wrong.** Group and
  reference resolution produces a plausible-looking number whatever the bug, and topic 5
  is built entirely on it. Assertion 4 exists for this and should be written before the
  view is.
- **Expansion drift.** The `exp = 0` filter catches post-vanilla creatures cleanly but has
  no equivalent for quests, whose revamps between 1.12 and 3.3.5 are invisible in the
  schema. Expect the quest topic to carry the most false positives, and expect the pilot
  to tell us the rate.
