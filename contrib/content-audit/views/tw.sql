-- Normalising views for tortoise-wow, a VMaNGOS fork.
-- The plan said this file could be a straight `sed 's/src = .v./src = .tw./'`
-- copy of v.sql because tw is the same lineage. That held for n_spawn's join
-- condition, which is all the plan checked, but not for the rest of the
-- schema - verified against information_schema.columns rather than trusted:
--
--   - No `patch` column on creature_template or quest_template, and no
--     patch_min/patch_max anywhere (creature, gameobject, the three loot
--     tables, the two quest-relation tables all lack it). This fork flattened
--     the content-patch dimension entirely (6708 quest_template rows = 6708
--     distinct entries, 14339 creature_template rows = 14339 distinct
--     entries), so none of the _current-view plumbing v.sql needs applies
--     here.
--   - creature_template has no health_multiplier or any other multiplier
--     column at all - only absolute health_min/health_max - and there is no
--     creature_classlevelstats table to derive one from (v has both; tw has
--     neither). This fork's creature health model is not "level table times
--     a multiplier", it is a flat stored value. n_creature.hp_mult is NULL
--     here for that reason: fabricating a ratio would misrepresent it as the
--     same kind of number the other three sources report. Recorded as an
--     open question for whoever implements Task 5's HP comparison.
--   - creature has only id, id2, id3, id4 - no id5 - but the same random-pick
--     pool problem applies to id2..id4 (verified non-zero on 6786/2366/192
--     rows respectively), so n_spawn still unpivots them the same way v.sql
--     does for its five.
--
-- n_quest_obj, n_quest_rew, n_loot and n_rel use the same column names as
-- v.sql's raw tables (verified), so those four are copied unchanged, aside
-- from the same type-alignment casts described below.
--
-- From fix round 1, two more corrections:
--
--   - entry/quest/item/target columns are CAST to UNSIGNED and the signed
--     quest-chain columns to SIGNED (both land on BIGINT, the only width
--     CAST can produce) so this schema's mediumint/smallint columns match
--     ac's wider int columns exactly - see v.sql's header for the full
--     reasoning. hp_mult, which this schema cannot express (see above), is
--     CAST(NULL AS FLOAT) rather than a bare NULL so it carries a real
--     numeric type instead of MySQL's untyped-literal varbinary.
--   - n_spawn's id2/id3/id4 branches are UNIONed with plain UNION, not
--     UNION ALL, deduping on the full row (guid, entry, map, resp_min,
--     resp_max, wander) before the join to cmp.areas. tw guid 30977 has
--     id = id2 = 2914; without the dedupe that spawn point emitted two
--     identical n_spawn rows for entry 2914. The join to cmp.areas happens
--     after the dedupe, on guid, so two distinct guids of the same creature
--     in the same zone still produce two separate n_spawn rows.

CREATE OR REPLACE VIEW n_creature AS
SELECT CAST(entry AS UNSIGNED) AS entry, name, level_min AS lvl_min, level_max AS lvl_max, faction,
       `rank`, type, npc_flags, unit_class, CAST(NULL AS FLOAT) AS hp_mult
FROM creature_template;

CREATE OR REPLACE VIEW n_spawn AS
SELECT a.kind, s.entry, a.zone, a.area, s.map, s.resp_min, s.resp_max, s.wander
FROM (
    SELECT guid, CAST(id AS UNSIGNED) AS entry, map,
           spawntimesecsmin AS resp_min, spawntimesecsmax AS resp_max,
           wander_distance AS wander
    FROM creature
    WHERE id > 0
    UNION
    SELECT guid, id2, map, spawntimesecsmin, spawntimesecsmax, wander_distance
    FROM creature
    WHERE id2 > 0
    UNION
    SELECT guid, id3, map, spawntimesecsmin, spawntimesecsmax, wander_distance
    FROM creature
    WHERE id3 > 0
    UNION
    SELECT guid, id4, map, spawntimesecsmin, spawntimesecsmax, wander_distance
    FROM creature
    WHERE id4 > 0
) s
JOIN cmp.areas a ON a.src = 'tw' AND a.kind = 'creature' AND a.id = s.guid
UNION ALL
SELECT a.kind, CAST(g.id AS UNSIGNED) AS entry, a.zone, a.area, CAST(g.map AS UNSIGNED) AS map,
       g.spawntimesecsmin, g.spawntimesecsmax, 0
FROM gameobject g
JOIN cmp.areas a ON a.src = 'tw' AND a.kind = 'gobject' AND a.id = g.guid;

CREATE OR REPLACE VIEW n_quest AS
SELECT CAST(entry AS UNSIGNED) AS entry, Title AS title, CAST(QuestLevel AS UNSIGNED) AS lvl, MinLevel AS min_lvl,
       ZoneOrSort AS zone_or_sort, CAST(PrevQuestId AS SIGNED) AS prev, CAST(NextQuestId AS SIGNED) AS next,
       CAST(ExclusiveGroup AS SIGNED) AS excl_group, CAST(RequiredRaces AS UNSIGNED) AS req_race,
       CAST(RequiredClasses AS UNSIGNED) AS req_class,
       RewMoneyMaxLevel AS rew_money_max_level, CAST(RewXP AS UNSIGNED) AS rew_xp
FROM quest_template;

CREATE OR REPLACE VIEW n_quest_obj AS
SELECT CAST(entry AS UNSIGNED) AS quest, 'npc'  AS kind, ReqCreatureOrGOId1 AS target, ReqCreatureOrGOCount1 AS cnt FROM quest_template WHERE ReqCreatureOrGOId1 > 0
UNION ALL SELECT entry, 'npc',  ReqCreatureOrGOId2, ReqCreatureOrGOCount2 FROM quest_template WHERE ReqCreatureOrGOId2 > 0
UNION ALL SELECT entry, 'npc',  ReqCreatureOrGOId3, ReqCreatureOrGOCount3 FROM quest_template WHERE ReqCreatureOrGOId3 > 0
UNION ALL SELECT entry, 'npc',  ReqCreatureOrGOId4, ReqCreatureOrGOCount4 FROM quest_template WHERE ReqCreatureOrGOId4 > 0
UNION ALL SELECT entry, 'go',  -ReqCreatureOrGOId1, ReqCreatureOrGOCount1 FROM quest_template WHERE ReqCreatureOrGOId1 < 0
UNION ALL SELECT entry, 'go',  -ReqCreatureOrGOId2, ReqCreatureOrGOCount2 FROM quest_template WHERE ReqCreatureOrGOId2 < 0
UNION ALL SELECT entry, 'go',  -ReqCreatureOrGOId3, ReqCreatureOrGOCount3 FROM quest_template WHERE ReqCreatureOrGOId3 < 0
UNION ALL SELECT entry, 'go',  -ReqCreatureOrGOId4, ReqCreatureOrGOCount4 FROM quest_template WHERE ReqCreatureOrGOId4 < 0
UNION ALL SELECT entry, 'item', ReqItemId1, ReqItemCount1 FROM quest_template WHERE ReqItemId1 > 0
UNION ALL SELECT entry, 'item', ReqItemId2, ReqItemCount2 FROM quest_template WHERE ReqItemId2 > 0
UNION ALL SELECT entry, 'item', ReqItemId3, ReqItemCount3 FROM quest_template WHERE ReqItemId3 > 0
UNION ALL SELECT entry, 'item', ReqItemId4, ReqItemCount4 FROM quest_template WHERE ReqItemId4 > 0;

CREATE OR REPLACE VIEW n_quest_rew AS
SELECT CAST(entry AS UNSIGNED) AS quest, 'item'   AS kind, RewItemId1 AS id, RewItemCount1 AS cnt FROM quest_template WHERE RewItemId1 > 0
UNION ALL SELECT entry, 'item',   RewItemId2, RewItemCount2 FROM quest_template WHERE RewItemId2 > 0
UNION ALL SELECT entry, 'item',   RewItemId3, RewItemCount3 FROM quest_template WHERE RewItemId3 > 0
UNION ALL SELECT entry, 'item',   RewItemId4, RewItemCount4 FROM quest_template WHERE RewItemId4 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId1, RewChoiceItemCount1 FROM quest_template WHERE RewChoiceItemId1 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId2, RewChoiceItemCount2 FROM quest_template WHERE RewChoiceItemId2 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId3, RewChoiceItemCount3 FROM quest_template WHERE RewChoiceItemId3 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId4, RewChoiceItemCount4 FROM quest_template WHERE RewChoiceItemId4 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId5, RewChoiceItemCount5 FROM quest_template WHERE RewChoiceItemId5 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId6, RewChoiceItemCount6 FROM quest_template WHERE RewChoiceItemId6 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction1, RewRepValue1 FROM quest_template WHERE RewRepFaction1 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction2, RewRepValue2 FROM quest_template WHERE RewRepFaction2 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction3, RewRepValue3 FROM quest_template WHERE RewRepFaction3 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction4, RewRepValue4 FROM quest_template WHERE RewRepFaction4 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction5, RewRepValue5 FROM quest_template WHERE RewRepFaction5 > 0
UNION ALL SELECT entry, 'spell',  RewSpell, 1 FROM quest_template WHERE RewSpell > 0
UNION ALL SELECT entry, 'money',  0, RewOrReqMoney FROM quest_template WHERE RewOrReqMoney > 0;

-- Signs carry meaning in this lineage: a negative chance means the row only
-- drops for a player on the quest, a negative mincount means the row is a
-- reference into reference_loot_template rather than an item.
CREATE OR REPLACE VIEW n_loot AS
SELECT 'creature' AS tbl, CAST(entry AS UNSIGNED) AS entry, CAST(item AS UNSIGNED) AS item, ABS(ChanceOrQuestChance) AS chance, groupid AS grp,
       CASE WHEN mincountOrRef < 0 THEN -mincountOrRef ELSE 0 END AS ref,
       CASE WHEN ChanceOrQuestChance < 0 THEN 1 ELSE 0 END AS quest_only,
       CASE WHEN mincountOrRef > 0 THEN mincountOrRef ELSE 1 END AS cmin, maxcount AS cmax
FROM creature_loot_template
UNION ALL
SELECT 'gobject', entry, item, ABS(ChanceOrQuestChance), groupid,
       CASE WHEN mincountOrRef < 0 THEN -mincountOrRef ELSE 0 END,
       CASE WHEN ChanceOrQuestChance < 0 THEN 1 ELSE 0 END,
       CASE WHEN mincountOrRef > 0 THEN mincountOrRef ELSE 1 END, maxcount
FROM gameobject_loot_template
UNION ALL
SELECT 'reference', entry, item, ABS(ChanceOrQuestChance), groupid,
       CASE WHEN mincountOrRef < 0 THEN -mincountOrRef ELSE 0 END,
       CASE WHEN ChanceOrQuestChance < 0 THEN 1 ELSE 0 END,
       CASE WHEN mincountOrRef > 0 THEN mincountOrRef ELSE 1 END, maxcount
FROM reference_loot_template;

CREATE OR REPLACE VIEW n_rel AS
SELECT 'questgiver' AS kind, id AS npc, CAST(quest AS UNSIGNED) AS target FROM creature_questrelation
UNION ALL SELECT 'questender', id, quest FROM creature_involvedrelation
UNION ALL SELECT 'vendor',     entry, item FROM npc_vendor
UNION ALL SELECT 'trainer',    entry, spell FROM npc_trainer
UNION ALL SELECT 'link',       guid, master_guid FROM creature_linking;
