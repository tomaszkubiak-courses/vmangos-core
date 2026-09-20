-- Normalising views for a MaNGOS Zero schema.
-- Differences from the VMaNGOS lineage: mixed-case column names, faction split
-- into an Alliance and a Horde column, absolute health on the template, no
-- RewXP column at all, a single random-pick creature id (no id2..id5 pool),
-- and no content-patch dimension anywhere in this schema (verified: neither
-- creature_template nor quest_template carries a `patch` column, and none of
-- creature/gameobject/the loot tables/the quest-relation tables carry
-- patch_min/patch_max) - so, unlike v.sql and tw.sql, nothing here needs the
-- greatest-patch-not-exceeding-10 pick.
--
-- One correction to the plan this was written from: the plan claimed
-- n_quest_obj, n_quest_rew, n_loot and n_rel are "character-identical to
-- v.sql" and said to copy them unchanged. That held for three of the four -
-- verified against information_schema.columns, not just trusted. It did not
-- hold for n_rel: this schema has no creature_questrelation or
-- creature_involvedrelation tables at all. Both are folded into one
-- `quest_relations(actor, entry, quest, role)` table, and role's two values
-- were not documented anywhere in the checked-out mangoszero-database repo.
-- Disambiguated empirically: for every quest below 100 where v's questgiver
-- and questender creatures differ, matching the quest id against
-- quest_relations shows role=0 on the same creature id as v's
-- creature_questrelation (questgiver) and role=1 on the same id as v's
-- creature_involvedrelation (questender), confirmed on quests 5, 8, 26, 35 (see
-- task-4-report.md). actor=0 is the creature case (actor=1/2, a small
-- minority, are gameobject- and item-triggered quest relations that the other
-- three sources' views do not carry either).
--
-- From fix round 1: entry/quest/item/target columns are CAST to UNSIGNED and
-- the signed quest-chain columns to SIGNED (both land on BIGINT, the only
-- width CAST can produce) so this schema's mediumint/smallint columns match
-- ac's wider int columns exactly - see v.sql's header for the full
-- reasoning. rew_xp, which this schema cannot express at all, is CAST(NULL
-- AS UNSIGNED) rather than a bare NULL so it carries a real numeric type
-- instead of MySQL's untyped-literal varbinary.

CREATE OR REPLACE VIEW n_creature AS
SELECT CAST(Entry AS UNSIGNED) AS entry, Name AS name, MinLevel AS lvl_min, MaxLevel AS lvl_max,
       FactionAlliance AS faction, `Rank` AS `rank`, CreatureType AS type,
       NpcFlags AS npc_flags, UnitClass AS unit_class,
       HealthMultiplier AS hp_mult
FROM creature_template;

CREATE OR REPLACE VIEW n_spawn AS
SELECT a.kind, CAST(c.id AS UNSIGNED) AS entry, a.zone, a.area, CAST(c.map AS UNSIGNED) AS map,
       c.spawntimesecs AS resp_min, c.spawntimesecs AS resp_max,
       c.spawndist AS wander
FROM creature c
JOIN cmp.areas a ON a.src = 'mz' AND a.kind = 'creature' AND a.id = c.guid
UNION ALL
SELECT a.kind, g.id, a.zone, a.area, g.map, g.spawntimesecs, g.spawntimesecs, 0
FROM gameobject g
JOIN cmp.areas a ON a.src = 'mz' AND a.kind = 'gobject' AND a.id = g.guid;

-- req_race: masked to the vanilla race bits, see views/v.sql.
CREATE OR REPLACE VIEW n_quest AS
SELECT CAST(entry AS UNSIGNED) AS entry, Title AS title, CAST(QuestLevel AS UNSIGNED) AS lvl, MinLevel AS min_lvl,
       ZoneOrSort AS zone_or_sort, CAST(PrevQuestId AS SIGNED) AS prev, CAST(NextQuestId AS SIGNED) AS next,
       CAST(ExclusiveGroup AS SIGNED) AS excl_group, CAST(IF(RequiredRaces & 255 = 255, 0, RequiredRaces & 255) AS UNSIGNED) AS req_race,
       CAST(RequiredClasses AS UNSIGNED) AS req_class,
       RewMoneyMaxLevel AS rew_money_max_level, CAST(NULL AS UNSIGNED) AS rew_xp
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
-- Fix round 3, item 12b: see v.sql's n_quest_rew for the full account.
-- RewSpellCast is a second, independent spell-reward slot, not a
-- fall-back column for RewSpell; both are unioned as their own rows.
UNION ALL SELECT entry, 'spell',  RewSpell, 1 FROM quest_template WHERE RewSpell > 0
UNION ALL SELECT entry, 'spell',  RewSpellCast, 1 FROM quest_template WHERE RewSpellCast > 0
UNION ALL SELECT entry, 'money',  0, RewOrReqMoney FROM quest_template WHERE RewOrReqMoney > 0;

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

-- Task 9 Step 0 fix: see v.sql's n_rel comment. creature_linking is keyed
-- by spawn GUID; both sides are resolved to creature entry here so
-- n_rel.npc/target mean the same thing as the other four kinds. npc is
-- explicitly CAST here too, for the same type-consistency reason as v.sql:
-- without an explicit width the type contract with the other three sources
-- is only accidental.
CREATE OR REPLACE VIEW n_rel AS
SELECT 'questgiver' AS kind, CAST(entry AS UNSIGNED) AS npc, CAST(quest AS UNSIGNED) AS target FROM quest_relations WHERE actor = 0 AND role = 0
UNION ALL SELECT 'questender', entry, quest FROM quest_relations WHERE actor = 0 AND role = 1
UNION ALL SELECT 'vendor',     entry, item FROM npc_vendor
UNION ALL SELECT 'trainer',    entry, spell FROM npc_trainer
UNION ALL SELECT DISTINCT 'link', c1.id, c2.id
    FROM creature_linking l
    JOIN creature c1 ON c1.guid = l.guid
    JOIN creature c2 ON c2.guid = l.master_guid;

-- Quest chain edges; see views/v.sql for why the raw column cannot be
-- compared directly. This schema has no patch dimension on quest_template
-- (mz) / has flattened it (tw), so the edges come straight off the table.
CREATE OR REPLACE VIEW n_quest_chain AS
SELECT DISTINCT CAST(ABS(PrevQuestId) AS UNSIGNED) AS prev, CAST(entry AS UNSIGNED) AS next
FROM quest_template WHERE PrevQuestId <> 0
UNION
SELECT DISTINCT CAST(entry AS UNSIGNED), CAST(ABS(NextQuestId) AS UNSIGNED)
FROM quest_template WHERE NextQuestId <> 0
UNION
SELECT DISTINCT CAST(entry AS UNSIGNED), CAST(NextQuestInChain AS UNSIGNED)
FROM quest_template WHERE NextQuestInChain <> 0;
