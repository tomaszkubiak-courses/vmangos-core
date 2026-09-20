-- Normalising views for a VMaNGOS-lineage schema.
-- Every diff query reads these and never the underlying tables.
--
-- Two corrections to the plan this was written from, found by querying the
-- corpus directly rather than trusting the plan's column list (see
-- task-4-report.md for the full account with row counts):
--
-- 1. This schema keys creature_template and quest_template on (entry, patch):
--    one row per content patch a row was introduced or changed in, not one
--    row per entry. At load time the core picks, per entry, the row with the
--    greatest patch not exceeding the realm's configured WowPatch. This realm
--    runs mangosd.conf WowPatch = 10 (WOW_PATCH_112), so _creature_current and
--    _quest_current below pick that row per entry and every other view reads
--    through them instead of the raw tables. Selecting straight from
--    creature_template/quest_template, as the plan did, would have emitted
--    every patch revision as a separate row and silently multiplied every
--    downstream join.
--
--    The same schema also carries a *range* form of the same idea,
--    patch_min/patch_max, on creature/gameobject spawns, the three loot
--    tables, and the two quest-relation tables. A range already identifies at
--    most one row per key, so those are filtered with a plain
--    "10 BETWEEN patch_min AND patch_max" rather than a MAX().
--
-- 2. A `creature` spawn can name up to five possible creatures (id, id2..id5)
--    as a random-pick pool. n_spawn emits one row per non-zero id so a pooled
--    spawn counts toward every creature it can produce, not just id.
--
-- A third correction, from fix round 1: the seven-view contract promises
-- identical column names *and types*, but nothing enforced the second half.
-- ac's id-ish columns are declared `int`, this schema's are `mediumint`;
-- ac's `chance`/`ref`/`quest_only`/`cmin` in n_loot are narrower too. CAST
-- can only target SIGNED/UNSIGNED (both become `bigint`) or FLOAT/DOUBLE
-- exactly, never a specific narrower width like INT or MEDIUMINT, so the
-- only type all four sources can be made to agree on is the wider one -
-- narrowing ac down to match would risk truncating a real (if currently
-- unused) id range, which the fix round explicitly ruled out. Every
-- id/quest/entry/item/target-shaped column below is therefore cast to
-- UNSIGNED (BIGINT unsigned), and every quest chain column that the
-- PrevQuestId/NextQuestId/ExclusiveGroup convention allows to be negative is
-- cast to SIGNED (BIGINT signed) instead, in whichever source needs it to
-- match. Only the first branch of a UNION ALL needs the CAST: MySQL infers a
-- UNION's result type as the widest type contributed by any branch, so
-- widening one branch widens the whole view.

-- Internal helpers, not part of the seven-view contract: one row per entry,
-- picked as described above. Kept as views (not repeated subqueries) so the
-- patch-picking logic exists in exactly one place per table.
CREATE OR REPLACE VIEW _creature_current AS
SELECT ct.*
FROM creature_template ct
JOIN (
    SELECT entry, MAX(patch) AS patch
    FROM creature_template
    WHERE patch <= 10
    GROUP BY entry
) latest ON latest.entry = ct.entry AND latest.patch = ct.patch;

CREATE OR REPLACE VIEW _quest_current AS
SELECT qt.*
FROM quest_template qt
JOIN (
    SELECT entry, MAX(patch) AS patch
    FROM quest_template
    WHERE patch <= 10
    GROUP BY entry
) latest ON latest.entry = qt.entry AND latest.patch = qt.patch;

CREATE OR REPLACE VIEW n_creature AS
SELECT CAST(entry AS UNSIGNED) AS entry, name, level_min AS lvl_min, level_max AS lvl_max, faction,
       `rank`, type, npc_flags, unit_class, health_multiplier AS hp_mult
FROM _creature_current;

-- Only the first branch of each UNION ALL below casts entry/map explicitly;
-- MySQL infers a UNION's column type as the widest type used by any branch,
-- so one CAST is enough to widen the whole view - see the type-alignment
-- note above _creature_current for why entry and map need it at all.
--
-- From fix round 1: the five id-slot branches are UNIONed with plain UNION
-- (not UNION ALL) inside the `pool` subquery, deduping on the full row
-- (guid, entry, map, resp_min, resp_max, wander) - two spawns 66243 and
-- 66009 corpus-wide have id = id2 for the same creature (v guid 190209,
-- tw guid 30977), and without the dedupe that one spawn point would emit
-- two identical n_spawn rows for the same entry. The join to cmp.areas
-- happens *after* this dedupe, on `guid`, so two distinct guids of the same
-- creature in the same zone still produce two separate n_spawn rows -
-- deduping post-join (e.g. DISTINCT on the final SELECT, which does not
-- carry guid) would have collapsed those too and silently undercounted
-- every zone's real spawn totals.
CREATE OR REPLACE VIEW n_spawn AS
SELECT a.kind, s.entry, a.zone, a.area, s.map, s.resp_min, s.resp_max, s.wander
FROM (
    SELECT guid, CAST(id AS UNSIGNED) AS entry, map,
           spawntimesecsmin AS resp_min, spawntimesecsmax AS resp_max,
           wander_distance AS wander
    FROM creature
    WHERE id > 0 AND 10 BETWEEN patch_min AND patch_max
    UNION
    SELECT guid, id2, map, spawntimesecsmin, spawntimesecsmax, wander_distance
    FROM creature
    WHERE id2 > 0 AND 10 BETWEEN patch_min AND patch_max
    UNION
    SELECT guid, id3, map, spawntimesecsmin, spawntimesecsmax, wander_distance
    FROM creature
    WHERE id3 > 0 AND 10 BETWEEN patch_min AND patch_max
    UNION
    SELECT guid, id4, map, spawntimesecsmin, spawntimesecsmax, wander_distance
    FROM creature
    WHERE id4 > 0 AND 10 BETWEEN patch_min AND patch_max
    UNION
    SELECT guid, id5, map, spawntimesecsmin, spawntimesecsmax, wander_distance
    FROM creature
    WHERE id5 > 0 AND 10 BETWEEN patch_min AND patch_max
) s
JOIN cmp.areas a ON a.src = 'v' AND a.kind = 'creature' AND a.id = s.guid
UNION ALL
SELECT a.kind, CAST(g.id AS UNSIGNED) AS entry, a.zone, a.area, CAST(g.map AS UNSIGNED) AS map,
       g.spawntimesecsmin, g.spawntimesecsmax, 0
FROM gameobject g
JOIN cmp.areas a ON a.src = 'v' AND a.kind = 'gobject' AND a.id = g.guid
WHERE 10 BETWEEN g.patch_min AND g.patch_max;

CREATE OR REPLACE VIEW n_quest AS
SELECT CAST(entry AS UNSIGNED) AS entry, Title AS title, CAST(QuestLevel AS UNSIGNED) AS lvl, MinLevel AS min_lvl,
       ZoneOrSort AS zone_or_sort, CAST(PrevQuestId AS SIGNED) AS prev, CAST(NextQuestId AS SIGNED) AS next,
       CAST(ExclusiveGroup AS SIGNED) AS excl_group, CAST(RequiredRaces AS UNSIGNED) AS req_race,
       CAST(RequiredClasses AS UNSIGNED) AS req_class,
       RewMoneyMaxLevel AS rew_money_max_level, CAST(RewXP AS UNSIGNED) AS rew_xp
FROM _quest_current;

CREATE OR REPLACE VIEW n_quest_obj AS
SELECT CAST(entry AS UNSIGNED) AS quest, 'npc'  AS kind, ReqCreatureOrGOId1 AS target, ReqCreatureOrGOCount1 AS cnt FROM _quest_current WHERE ReqCreatureOrGOId1 > 0
UNION ALL SELECT entry, 'npc',  ReqCreatureOrGOId2, ReqCreatureOrGOCount2 FROM _quest_current WHERE ReqCreatureOrGOId2 > 0
UNION ALL SELECT entry, 'npc',  ReqCreatureOrGOId3, ReqCreatureOrGOCount3 FROM _quest_current WHERE ReqCreatureOrGOId3 > 0
UNION ALL SELECT entry, 'npc',  ReqCreatureOrGOId4, ReqCreatureOrGOCount4 FROM _quest_current WHERE ReqCreatureOrGOId4 > 0
UNION ALL SELECT entry, 'go',  -ReqCreatureOrGOId1, ReqCreatureOrGOCount1 FROM _quest_current WHERE ReqCreatureOrGOId1 < 0
UNION ALL SELECT entry, 'go',  -ReqCreatureOrGOId2, ReqCreatureOrGOCount2 FROM _quest_current WHERE ReqCreatureOrGOId2 < 0
UNION ALL SELECT entry, 'go',  -ReqCreatureOrGOId3, ReqCreatureOrGOCount3 FROM _quest_current WHERE ReqCreatureOrGOId3 < 0
UNION ALL SELECT entry, 'go',  -ReqCreatureOrGOId4, ReqCreatureOrGOCount4 FROM _quest_current WHERE ReqCreatureOrGOId4 < 0
UNION ALL SELECT entry, 'item', ReqItemId1, ReqItemCount1 FROM _quest_current WHERE ReqItemId1 > 0
UNION ALL SELECT entry, 'item', ReqItemId2, ReqItemCount2 FROM _quest_current WHERE ReqItemId2 > 0
UNION ALL SELECT entry, 'item', ReqItemId3, ReqItemCount3 FROM _quest_current WHERE ReqItemId3 > 0
UNION ALL SELECT entry, 'item', ReqItemId4, ReqItemCount4 FROM _quest_current WHERE ReqItemId4 > 0;

CREATE OR REPLACE VIEW n_quest_rew AS
SELECT CAST(entry AS UNSIGNED) AS quest, 'item'   AS kind, RewItemId1 AS id, RewItemCount1 AS cnt FROM _quest_current WHERE RewItemId1 > 0
UNION ALL SELECT entry, 'item',   RewItemId2, RewItemCount2 FROM _quest_current WHERE RewItemId2 > 0
UNION ALL SELECT entry, 'item',   RewItemId3, RewItemCount3 FROM _quest_current WHERE RewItemId3 > 0
UNION ALL SELECT entry, 'item',   RewItemId4, RewItemCount4 FROM _quest_current WHERE RewItemId4 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId1, RewChoiceItemCount1 FROM _quest_current WHERE RewChoiceItemId1 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId2, RewChoiceItemCount2 FROM _quest_current WHERE RewChoiceItemId2 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId3, RewChoiceItemCount3 FROM _quest_current WHERE RewChoiceItemId3 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId4, RewChoiceItemCount4 FROM _quest_current WHERE RewChoiceItemId4 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId5, RewChoiceItemCount5 FROM _quest_current WHERE RewChoiceItemId5 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId6, RewChoiceItemCount6 FROM _quest_current WHERE RewChoiceItemId6 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction1, RewRepValue1 FROM _quest_current WHERE RewRepFaction1 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction2, RewRepValue2 FROM _quest_current WHERE RewRepFaction2 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction3, RewRepValue3 FROM _quest_current WHERE RewRepFaction3 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction4, RewRepValue4 FROM _quest_current WHERE RewRepFaction4 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction5, RewRepValue5 FROM _quest_current WHERE RewRepFaction5 > 0
-- Fix round 3, item 12b: RewSpellCast (cast on the player at turn-in) is a
-- second, independent spell reward slot from RewSpell (taught to the
-- player) - not an alternate column for the same fact. Quest 3861
-- ("CLUCK!") has RewSpell=0, RewSpellCast=13563; the old single-branch view
-- read this as "no spell reward" while ac's RewardSpell (which this
-- lineage's schema maps to the cast-on-complete effect) correctly saw
-- 13563, manufacturing a "content missing from the realm" finding for
-- content the realm actually has. Verified corpus-wide: 319 of 4727
-- quest_template rows have RewSpellCast<>0 against only 95 with
-- RewSpell<>0. Both are unioned as their own rows below (a quest with both
-- set emits both, rather than the view picking one), matching how ac's
-- single RewardSpell column already votes on this fact.
UNION ALL SELECT entry, 'spell',  RewSpell, 1 FROM _quest_current WHERE RewSpell > 0
UNION ALL SELECT entry, 'spell',  RewSpellCast, 1 FROM _quest_current WHERE RewSpellCast > 0
UNION ALL SELECT entry, 'money',  0, RewOrReqMoney FROM _quest_current WHERE RewOrReqMoney > 0;

-- Signs carry meaning in this lineage: a negative chance means the row only
-- drops for a player on the quest, a negative mincount means the row is a
-- reference into reference_loot_template rather than an item.
CREATE OR REPLACE VIEW n_loot AS
SELECT 'creature' AS tbl, CAST(entry AS UNSIGNED) AS entry, CAST(item AS UNSIGNED) AS item, ABS(ChanceOrQuestChance) AS chance, groupid AS grp,
       CASE WHEN mincountOrRef < 0 THEN -mincountOrRef ELSE 0 END AS ref,
       CASE WHEN ChanceOrQuestChance < 0 THEN 1 ELSE 0 END AS quest_only,
       CASE WHEN mincountOrRef > 0 THEN mincountOrRef ELSE 1 END AS cmin, maxcount AS cmax
FROM creature_loot_template
WHERE 10 BETWEEN patch_min AND patch_max
UNION ALL
SELECT 'gobject', entry, item, ABS(ChanceOrQuestChance), groupid,
       CASE WHEN mincountOrRef < 0 THEN -mincountOrRef ELSE 0 END,
       CASE WHEN ChanceOrQuestChance < 0 THEN 1 ELSE 0 END,
       CASE WHEN mincountOrRef > 0 THEN mincountOrRef ELSE 1 END, maxcount
FROM gameobject_loot_template
WHERE 10 BETWEEN patch_min AND patch_max
UNION ALL
SELECT 'reference', entry, item, ABS(ChanceOrQuestChance), groupid,
       CASE WHEN mincountOrRef < 0 THEN -mincountOrRef ELSE 0 END,
       CASE WHEN ChanceOrQuestChance < 0 THEN 1 ELSE 0 END,
       CASE WHEN mincountOrRef > 0 THEN mincountOrRef ELSE 1 END, maxcount
FROM reference_loot_template
WHERE 10 BETWEEN patch_min AND patch_max;

-- Task 9 Step 0 fix: creature_linking is keyed by spawn GUID, unlike the
-- other four kinds which key npc/target by creature entry, and GUIDs do not
-- survive the trip between databases at all (a guid in v and the same guid
-- in mz name unrelated rows). Both sides are resolved to creature entry
-- here so n_rel.npc/target mean the same thing for every kind. Verified on
-- the corpus: all 407 v link guids resolve on both sides (0 unresolvable),
-- collapsing to 58 distinct entry pairs. Exactly one linked spawn sits on an
-- id2 pool; reading c.id alone is correct to within that single row.
--
-- The old link branch (raw guid, an `int unsigned` column) happened to be
-- the widest contributor to npc's UNION type, so npc matched the other
-- three sources' int-typed npc column by accident rather than by CAST. The
-- new entry-keyed branch is narrower (mediumint), so npc now needs its own
-- explicit CAST here to keep the type-consistency contract
-- test_normalised_views_exist_and_agree_on_shape checks.
CREATE OR REPLACE VIEW n_rel AS
SELECT 'questgiver' AS kind, CAST(id AS UNSIGNED) AS npc, CAST(quest AS UNSIGNED) AS target FROM creature_questrelation WHERE 10 BETWEEN patch_min AND patch_max
UNION ALL SELECT 'questender', id, quest FROM creature_involvedrelation WHERE 10 BETWEEN patch_min AND patch_max
UNION ALL SELECT 'vendor',     entry, item FROM npc_vendor
-- A vendor's stock and a trainer's spell list have TWO sources in this
-- schema, and reading only the per-creature table understates both. A
-- creature_template row can name a shared list through vendor_id /
-- trainer_id (npc_vendor_template, npc_trainer_template), and the core uses
-- the two together, never one instead of the other -
-- WorldSession::SendListInventory (ItemHandler.cpp) reads GetVendorItems() and
-- GetVendorTemplateItems() side by side. On this realm the template path
-- carries 492 (creature, item) vendor pairs and 29990 (creature, spell)
-- trainer pairs over 284 creatures, against 4676 npc_trainer rows in total:
-- ignoring it is what made this realm look like it had far shorter trainer
-- lists than every peer, and it reported 55 strong "this realm lacks it"
-- vendor findings for items the realm does sell. mangoszero has both
-- template tables but leaves them empty, and AzerothCore has no vendor
-- template table at all, so no peer view needs this branch.
--
-- Two duplicate guards, both needed, because cmp.trainer_spell_count counts
-- rows: the NOT EXISTS covers a creature owning a direct row for something
-- its template also carries, and the DISTINCT covers the template table
-- repeating a spell (npc_trainer_template holds 2404 rows over 1393 distinct
-- entry+spell pairs - without it the trainer relation came out ~20000 rows
-- too large). Five duplicate (npc, spell) pairs survive and they are
-- npc_trainer's own: 4676 rows over 4671 distinct pairs.
UNION ALL SELECT DISTINCT 'vendor', ct.entry, nt.item
    FROM _creature_current ct
    JOIN npc_vendor_template nt ON nt.entry = ct.vendor_id
    WHERE ct.vendor_id <> 0
      AND NOT EXISTS (SELECT 1 FROM npc_vendor nv WHERE nv.entry = ct.entry AND nv.item = nt.item)
UNION ALL SELECT 'trainer',    entry, spell FROM npc_trainer
UNION ALL SELECT DISTINCT 'trainer', ct.entry, nt.spell
    FROM _creature_current ct
    JOIN npc_trainer_template nt ON nt.entry = ct.trainer_id
    WHERE ct.trainer_id <> 0
      AND NOT EXISTS (SELECT 1 FROM npc_trainer nt2 WHERE nt2.entry = ct.entry AND nt2.spell = nt.spell)
UNION ALL SELECT DISTINCT 'link', c1.id, c2.id
    FROM creature_linking l
    JOIN creature c1 ON c1.guid = l.guid
    JOIN creature c2 ON c2.guid = l.master_guid;
