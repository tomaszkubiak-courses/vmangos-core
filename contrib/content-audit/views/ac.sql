-- Normalising views for a TrinityCore/AzerothCore schema.
-- This lineage splits into columns what the vanilla ones overload into signs:
-- Reference, QuestRequired and Chance are separate, so n_loot is a rename.
--
-- One correction to the plan this was written from: the plan's n_spawn read
-- `c.id1`, assuming this schema numbers its random-pick creature id column
-- the same way the DB parlance for "multiple template ids" usually does.
-- Verified against information_schema.columns instead: ac.creature has a
-- single `id` column, no id1/id2/etc - this lineage has no random-pick spawn
-- pool at all, so unlike v.sql and tw.sql, n_spawn here does not need to
-- unpivot anything.
--
-- AzerothCore has no direct equivalent of `creature_linking`, so n_rel omits
-- the `link` kind entirely - an abstention, not a claim that the relationship
-- is absent (see task-4-report.md and the pipeline README).

CREATE OR REPLACE VIEW n_creature AS
SELECT entry, name, minlevel AS lvl_min, maxlevel AS lvl_max, faction,
       `rank`, type, npcflag AS npc_flags, unit_class,
       HealthModifier AS hp_mult
FROM creature_template;

CREATE OR REPLACE VIEW n_spawn AS
SELECT a.kind, c.id AS entry, a.zone, a.area, c.map,
       c.spawntimesecs AS resp_min, c.spawntimesecs AS resp_max,
       c.wander_distance AS wander
FROM creature c
JOIN cmp.areas a ON a.src = 'ac' AND a.kind = 'creature' AND a.id = c.guid
UNION ALL
SELECT a.kind, g.id, a.zone, a.area, g.map, g.spawntimesecs, g.spawntimesecs, 0
FROM gameobject g
JOIN cmp.areas a ON a.src = 'ac' AND a.kind = 'gobject' AND a.id = g.guid;

CREATE OR REPLACE VIEW n_quest AS
SELECT q.ID AS entry, q.LogTitle AS title, q.QuestLevel AS lvl,
       q.MinLevel AS min_lvl, q.QuestSortID AS zone_or_sort,
       0 AS prev, q.RewardNextQuest AS next, 0 AS excl_group,
       q.AllowableRaces AS req_race, 0 AS req_class,
       q.RewardMoney AS rew_money_max_level, NULL AS rew_xp
FROM quest_template q;

CREATE OR REPLACE VIEW n_quest_obj AS
SELECT ID AS quest, 'npc' AS kind, RequiredNpcOrGo1 AS target, RequiredNpcOrGoCount1 AS cnt FROM quest_template WHERE RequiredNpcOrGo1 > 0
UNION ALL SELECT ID, 'npc',  RequiredNpcOrGo2, RequiredNpcOrGoCount2 FROM quest_template WHERE RequiredNpcOrGo2 > 0
UNION ALL SELECT ID, 'npc',  RequiredNpcOrGo3, RequiredNpcOrGoCount3 FROM quest_template WHERE RequiredNpcOrGo3 > 0
UNION ALL SELECT ID, 'npc',  RequiredNpcOrGo4, RequiredNpcOrGoCount4 FROM quest_template WHERE RequiredNpcOrGo4 > 0
UNION ALL SELECT ID, 'go',  -RequiredNpcOrGo1, RequiredNpcOrGoCount1 FROM quest_template WHERE RequiredNpcOrGo1 < 0
UNION ALL SELECT ID, 'go',  -RequiredNpcOrGo2, RequiredNpcOrGoCount2 FROM quest_template WHERE RequiredNpcOrGo2 < 0
UNION ALL SELECT ID, 'go',  -RequiredNpcOrGo3, RequiredNpcOrGoCount3 FROM quest_template WHERE RequiredNpcOrGo3 < 0
UNION ALL SELECT ID, 'go',  -RequiredNpcOrGo4, RequiredNpcOrGoCount4 FROM quest_template WHERE RequiredNpcOrGo4 < 0
UNION ALL SELECT ID, 'item', RequiredItemId1, RequiredItemCount1 FROM quest_template WHERE RequiredItemId1 > 0
UNION ALL SELECT ID, 'item', RequiredItemId2, RequiredItemCount2 FROM quest_template WHERE RequiredItemId2 > 0
UNION ALL SELECT ID, 'item', RequiredItemId3, RequiredItemCount3 FROM quest_template WHERE RequiredItemId3 > 0
UNION ALL SELECT ID, 'item', RequiredItemId4, RequiredItemCount4 FROM quest_template WHERE RequiredItemId4 > 0;

CREATE OR REPLACE VIEW n_quest_rew AS
SELECT ID AS quest, 'item' AS kind, RewardItem1 AS id, RewardAmount1 AS cnt FROM quest_template WHERE RewardItem1 > 0
UNION ALL SELECT ID, 'item',   RewardItem2, RewardAmount2 FROM quest_template WHERE RewardItem2 > 0
UNION ALL SELECT ID, 'item',   RewardItem3, RewardAmount3 FROM quest_template WHERE RewardItem3 > 0
UNION ALL SELECT ID, 'item',   RewardItem4, RewardAmount4 FROM quest_template WHERE RewardItem4 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID1, RewardChoiceItemQuantity1 FROM quest_template WHERE RewardChoiceItemID1 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID2, RewardChoiceItemQuantity2 FROM quest_template WHERE RewardChoiceItemID2 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID3, RewardChoiceItemQuantity3 FROM quest_template WHERE RewardChoiceItemID3 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID4, RewardChoiceItemQuantity4 FROM quest_template WHERE RewardChoiceItemID4 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID5, RewardChoiceItemQuantity5 FROM quest_template WHERE RewardChoiceItemID5 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID6, RewardChoiceItemQuantity6 FROM quest_template WHERE RewardChoiceItemID6 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID1, RewardFactionValue1 FROM quest_template WHERE RewardFactionID1 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID2, RewardFactionValue2 FROM quest_template WHERE RewardFactionID2 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID3, RewardFactionValue3 FROM quest_template WHERE RewardFactionID3 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID4, RewardFactionValue4 FROM quest_template WHERE RewardFactionID4 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID5, RewardFactionValue5 FROM quest_template WHERE RewardFactionID5 > 0
UNION ALL SELECT ID, 'spell',  RewardSpell, 1 FROM quest_template WHERE RewardSpell > 0
UNION ALL SELECT ID, 'money',  0, RewardMoney FROM quest_template WHERE RewardMoney > 0;

CREATE OR REPLACE VIEW n_loot AS
SELECT 'creature' AS tbl, Entry AS entry, Item AS item, Chance AS chance,
       GroupId AS grp, Reference AS ref, QuestRequired AS quest_only,
       MinCount AS cmin, MaxCount AS cmax
FROM creature_loot_template
UNION ALL
SELECT 'gobject', Entry, Item, Chance, GroupId, Reference, QuestRequired, MinCount, MaxCount
FROM gameobject_loot_template
UNION ALL
SELECT 'reference', Entry, Item, Chance, GroupId, Reference, QuestRequired, MinCount, MaxCount
FROM reference_loot_template;

CREATE OR REPLACE VIEW n_rel AS
SELECT 'questgiver' AS kind, id AS npc, quest AS target FROM creature_queststarter
UNION ALL SELECT 'questender', id, quest FROM creature_questender
UNION ALL SELECT 'vendor',     entry, item FROM npc_vendor
UNION ALL SELECT 'trainer',    ID, SpellID FROM npc_trainer;
