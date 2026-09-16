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
SELECT entry, name, level_min AS lvl_min, level_max AS lvl_max, faction,
       `rank`, type, npc_flags, unit_class, health_multiplier AS hp_mult
FROM _creature_current;

CREATE OR REPLACE VIEW n_spawn AS
SELECT a.kind, c.id AS entry, a.zone, a.area, c.map,
       c.spawntimesecsmin AS resp_min, c.spawntimesecsmax AS resp_max,
       c.wander_distance AS wander
FROM creature c
JOIN cmp.areas a ON a.src = 'v' AND a.kind = 'creature' AND a.id = c.guid
WHERE c.id > 0 AND 10 BETWEEN c.patch_min AND c.patch_max
UNION ALL
SELECT a.kind, c.id2, a.zone, a.area, c.map,
       c.spawntimesecsmin, c.spawntimesecsmax, c.wander_distance
FROM creature c
JOIN cmp.areas a ON a.src = 'v' AND a.kind = 'creature' AND a.id = c.guid
WHERE c.id2 > 0 AND 10 BETWEEN c.patch_min AND c.patch_max
UNION ALL
SELECT a.kind, c.id3, a.zone, a.area, c.map,
       c.spawntimesecsmin, c.spawntimesecsmax, c.wander_distance
FROM creature c
JOIN cmp.areas a ON a.src = 'v' AND a.kind = 'creature' AND a.id = c.guid
WHERE c.id3 > 0 AND 10 BETWEEN c.patch_min AND c.patch_max
UNION ALL
SELECT a.kind, c.id4, a.zone, a.area, c.map,
       c.spawntimesecsmin, c.spawntimesecsmax, c.wander_distance
FROM creature c
JOIN cmp.areas a ON a.src = 'v' AND a.kind = 'creature' AND a.id = c.guid
WHERE c.id4 > 0 AND 10 BETWEEN c.patch_min AND c.patch_max
UNION ALL
SELECT a.kind, c.id5, a.zone, a.area, c.map,
       c.spawntimesecsmin, c.spawntimesecsmax, c.wander_distance
FROM creature c
JOIN cmp.areas a ON a.src = 'v' AND a.kind = 'creature' AND a.id = c.guid
WHERE c.id5 > 0 AND 10 BETWEEN c.patch_min AND c.patch_max
UNION ALL
SELECT a.kind, g.id AS entry, a.zone, a.area, g.map,
       g.spawntimesecsmin, g.spawntimesecsmax, 0
FROM gameobject g
JOIN cmp.areas a ON a.src = 'v' AND a.kind = 'gobject' AND a.id = g.guid
WHERE 10 BETWEEN g.patch_min AND g.patch_max;

CREATE OR REPLACE VIEW n_quest AS
SELECT entry, Title AS title, QuestLevel AS lvl, MinLevel AS min_lvl,
       ZoneOrSort AS zone_or_sort, PrevQuestId AS prev, NextQuestId AS next,
       ExclusiveGroup AS excl_group, RequiredRaces AS req_race,
       RequiredClasses AS req_class,
       RewMoneyMaxLevel AS rew_money_max_level, RewXP AS rew_xp
FROM _quest_current;

CREATE OR REPLACE VIEW n_quest_obj AS
SELECT entry AS quest, 'npc'  AS kind, ReqCreatureOrGOId1 AS target, ReqCreatureOrGOCount1 AS cnt FROM _quest_current WHERE ReqCreatureOrGOId1 > 0
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
SELECT entry AS quest, 'item'   AS kind, RewItemId1 AS id, RewItemCount1 AS cnt FROM _quest_current WHERE RewItemId1 > 0
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
UNION ALL SELECT entry, 'spell',  RewSpell, 1 FROM _quest_current WHERE RewSpell > 0
UNION ALL SELECT entry, 'money',  0, RewOrReqMoney FROM _quest_current WHERE RewOrReqMoney > 0;

-- Signs carry meaning in this lineage: a negative chance means the row only
-- drops for a player on the quest, a negative mincount means the row is a
-- reference into reference_loot_template rather than an item.
CREATE OR REPLACE VIEW n_loot AS
SELECT 'creature' AS tbl, entry, item, ABS(ChanceOrQuestChance) AS chance, groupid AS grp,
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

CREATE OR REPLACE VIEW n_rel AS
SELECT 'questgiver' AS kind, id AS npc, quest AS target FROM creature_questrelation WHERE 10 BETWEEN patch_min AND patch_max
UNION ALL SELECT 'questender', id, quest FROM creature_involvedrelation WHERE 10 BETWEEN patch_min AND patch_max
UNION ALL SELECT 'vendor',     entry, item FROM npc_vendor
UNION ALL SELECT 'trainer',    entry, spell FROM npc_trainer
UNION ALL SELECT 'link',       guid, master_guid FROM creature_linking;
