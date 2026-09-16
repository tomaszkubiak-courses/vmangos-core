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
-- v.sql's raw tables (verified), so those four are copied unchanged.

CREATE OR REPLACE VIEW n_creature AS
SELECT entry, name, level_min AS lvl_min, level_max AS lvl_max, faction,
       `rank`, type, npc_flags, unit_class, NULL AS hp_mult
FROM creature_template;

CREATE OR REPLACE VIEW n_spawn AS
SELECT a.kind, c.id AS entry, a.zone, a.area, c.map,
       c.spawntimesecsmin AS resp_min, c.spawntimesecsmax AS resp_max,
       c.wander_distance AS wander
FROM creature c
JOIN cmp.areas a ON a.src = 'tw' AND a.kind = 'creature' AND a.id = c.guid
WHERE c.id > 0
UNION ALL
SELECT a.kind, c.id2, a.zone, a.area, c.map,
       c.spawntimesecsmin, c.spawntimesecsmax, c.wander_distance
FROM creature c
JOIN cmp.areas a ON a.src = 'tw' AND a.kind = 'creature' AND a.id = c.guid
WHERE c.id2 > 0
UNION ALL
SELECT a.kind, c.id3, a.zone, a.area, c.map,
       c.spawntimesecsmin, c.spawntimesecsmax, c.wander_distance
FROM creature c
JOIN cmp.areas a ON a.src = 'tw' AND a.kind = 'creature' AND a.id = c.guid
WHERE c.id3 > 0
UNION ALL
SELECT a.kind, c.id4, a.zone, a.area, c.map,
       c.spawntimesecsmin, c.spawntimesecsmax, c.wander_distance
FROM creature c
JOIN cmp.areas a ON a.src = 'tw' AND a.kind = 'creature' AND a.id = c.guid
WHERE c.id4 > 0
UNION ALL
SELECT a.kind, g.id AS entry, a.zone, a.area, g.map,
       g.spawntimesecsmin, g.spawntimesecsmax, 0
FROM gameobject g
JOIN cmp.areas a ON a.src = 'tw' AND a.kind = 'gobject' AND a.id = g.guid;

CREATE OR REPLACE VIEW n_quest AS
SELECT entry, Title AS title, QuestLevel AS lvl, MinLevel AS min_lvl,
       ZoneOrSort AS zone_or_sort, PrevQuestId AS prev, NextQuestId AS next,
       ExclusiveGroup AS excl_group, RequiredRaces AS req_race,
       RequiredClasses AS req_class,
       RewMoneyMaxLevel AS rew_money_max_level, RewXP AS rew_xp
FROM quest_template;

CREATE OR REPLACE VIEW n_quest_obj AS
SELECT entry AS quest, 'npc'  AS kind, ReqCreatureOrGOId1 AS target, ReqCreatureOrGOCount1 AS cnt FROM quest_template WHERE ReqCreatureOrGOId1 > 0
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
SELECT entry AS quest, 'item'   AS kind, RewItemId1 AS id, RewItemCount1 AS cnt FROM quest_template WHERE RewItemId1 > 0
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
SELECT 'creature' AS tbl, entry, item, ABS(ChanceOrQuestChance) AS chance, groupid AS grp,
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
SELECT 'questgiver' AS kind, id AS npc, quest AS target FROM creature_questrelation
UNION ALL SELECT 'questender', id, quest FROM creature_involvedrelation
UNION ALL SELECT 'vendor',     entry, item FROM npc_vendor
UNION ALL SELECT 'trainer',    entry, spell FROM npc_trainer
UNION ALL SELECT 'link',       guid, master_guid FROM creature_linking;
