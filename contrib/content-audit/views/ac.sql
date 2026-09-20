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
--
-- From fix round 1: this schema's id-ish columns (entry, quest, item, ref,
-- quest_only, cmin) and chance are narrower than the other three sources'
-- (int/tinyint/float here vs mediumint/bigint/double there). CAST can only
-- target SIGNED/UNSIGNED (both become BIGINT) or FLOAT/DOUBLE exactly, so
-- every one of those is cast to whichever of those two families matches, and
-- this schema's own already-wide columns are cast too so the whole set of
-- four converges on the same type rather than three of them moving and this
-- one standing still - see v.sql's header for the full reasoning. rew_xp,
-- which this schema has no direct column for, is CAST(NULL AS UNSIGNED)
-- rather than a bare NULL so it carries a real numeric type instead of
-- MySQL's untyped-literal varbinary.

CREATE OR REPLACE VIEW n_creature AS
SELECT CAST(entry AS UNSIGNED) AS entry, name, minlevel AS lvl_min, maxlevel AS lvl_max, faction,
       `rank`, type, npcflag AS npc_flags, unit_class,
       HealthModifier AS hp_mult
FROM creature_template;

CREATE OR REPLACE VIEW n_spawn AS
SELECT a.kind, CAST(c.id AS UNSIGNED) AS entry, a.zone, a.area, c.map,
       c.spawntimesecs AS resp_min, c.spawntimesecs AS resp_max,
       c.wander_distance AS wander
FROM creature c
JOIN cmp.areas a ON a.src = 'ac' AND a.kind = 'creature' AND a.id = c.guid
UNION ALL
SELECT a.kind, g.id, a.zone, a.area, CAST(g.map AS UNSIGNED) AS map, g.spawntimesecs, g.spawntimesecs, 0
FROM gameobject g
JOIN cmp.areas a ON a.src = 'ac' AND a.kind = 'gobject' AND a.id = g.guid;

-- QuestLevel is SIGNED here (fix round 3, item 12c), matching prev/next/
-- excl_group's existing SIGNED casts below: quest 1652 (and 1323 other rows
-- corpus-wide) has QuestLevel = -1, WotLK's "scales to the player" marker.
-- CAST(... AS UNSIGNED) wrapped that to 18446744073709551615, a value that
-- can never legitimately match anything and read as a random-looking wall
-- of digits rather than the real, if incommensurable, figure. -1 is kept
-- (not turned into NULL/abstain) on purpose: cmp.strength (the function
-- 03_quests.sql's lvl finding uses) has no lone-peer-abstention guard the
-- way cmp.strength_mag does, so a NULL ac argument here would still mark
-- every one of these rows 'weak' whenever mz voted at all, regardless of
-- whether mz agreed with v - the exact contentless-weak shape strength_mag
-- exists elsewhere to suppress, reintroduced through the back door. -1
-- disagreeing with v's real level is an honest, real disagreement (a fixed
-- vanilla level versus a WotLK scaling marker), not a manufactured one.
CREATE OR REPLACE VIEW n_quest AS
SELECT CAST(q.ID AS UNSIGNED) AS entry, q.LogTitle AS title, CAST(q.QuestLevel AS SIGNED) AS lvl,
       q.MinLevel AS min_lvl, q.QuestSortID AS zone_or_sort,
       CAST(0 AS SIGNED) AS prev, CAST(q.RewardNextQuest AS SIGNED) AS next, CAST(0 AS SIGNED) AS excl_group,
       CAST(q.AllowableRaces AS UNSIGNED) AS req_race, CAST(0 AS UNSIGNED) AS req_class,
       q.RewardMoney AS rew_money_max_level, CAST(NULL AS UNSIGNED) AS rew_xp
FROM quest_template q;

CREATE OR REPLACE VIEW n_quest_obj AS
SELECT CAST(ID AS UNSIGNED) AS quest, 'npc' AS kind, RequiredNpcOrGo1 AS target, RequiredNpcOrGoCount1 AS cnt FROM quest_template WHERE RequiredNpcOrGo1 > 0
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
SELECT CAST(ID AS UNSIGNED) AS quest, 'item' AS kind, RewardItem1 AS id, RewardAmount1 AS cnt FROM quest_template WHERE RewardItem1 > 0
UNION ALL SELECT ID, 'item',   RewardItem2, RewardAmount2 FROM quest_template WHERE RewardItem2 > 0
UNION ALL SELECT ID, 'item',   RewardItem3, RewardAmount3 FROM quest_template WHERE RewardItem3 > 0
UNION ALL SELECT ID, 'item',   RewardItem4, RewardAmount4 FROM quest_template WHERE RewardItem4 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID1, RewardChoiceItemQuantity1 FROM quest_template WHERE RewardChoiceItemID1 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID2, RewardChoiceItemQuantity2 FROM quest_template WHERE RewardChoiceItemID2 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID3, RewardChoiceItemQuantity3 FROM quest_template WHERE RewardChoiceItemID3 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID4, RewardChoiceItemQuantity4 FROM quest_template WHERE RewardChoiceItemID4 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID5, RewardChoiceItemQuantity5 FROM quest_template WHERE RewardChoiceItemID5 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID6, RewardChoiceItemQuantity6 FROM quest_template WHERE RewardChoiceItemID6 > 0
-- rep's amount abstains (fix round 3, item 12a): RewardFactionValueN is not
-- a reputation amount in this schema, it is a signed index into
-- QuestFactionReward.dbc (resolved at runtime by Player::RewardReputation),
-- ranging -7..9 on this corpus against v's raw RewRepValue amounts of
-- -500..500. Feeding it into the shared cnt column voted in a different
-- unit than every other source, so ac's vote could essentially never match
-- - 3275 of 3573 rep: findings carried a non-NULL ac value, not one of them
-- 'strong'. The DBC that would resolve the index isn't in this corpus, so
-- abstaining (CAST(NULL AS SIGNED), not a bare NULL, to keep a real numeric
-- type per this file's header) is the honest answer; the (quest, 'rep',
-- faction id) row itself is kept so ac still corroborates which factions a
-- quest rewards, just not the amount.
--
-- RewardFactionOverrideN - the actual raw-amount override this schema
-- offers instead of the abs-index path - is left unread here, per the fix
-- brief's request to note it rather than wire it up this round: 97 of
-- quest_template's rows have a nonzero override on this corpus, so a future
-- pass resolving it would recover a real amount for those, not just a
-- second abstention.
UNION ALL SELECT ID, 'rep',    RewardFactionID1, CAST(NULL AS SIGNED) FROM quest_template WHERE RewardFactionID1 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID2, CAST(NULL AS SIGNED) FROM quest_template WHERE RewardFactionID2 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID3, CAST(NULL AS SIGNED) FROM quest_template WHERE RewardFactionID3 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID4, CAST(NULL AS SIGNED) FROM quest_template WHERE RewardFactionID4 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID5, CAST(NULL AS SIGNED) FROM quest_template WHERE RewardFactionID5 > 0
UNION ALL SELECT ID, 'spell',  RewardSpell, 1 FROM quest_template WHERE RewardSpell > 0
UNION ALL SELECT ID, 'money',  0, RewardMoney FROM quest_template WHERE RewardMoney > 0;

CREATE OR REPLACE VIEW n_loot AS
SELECT 'creature' AS tbl, CAST(Entry AS UNSIGNED) AS entry, CAST(Item AS UNSIGNED) AS item, CAST(Chance AS DOUBLE) AS chance,
       GroupId AS grp, CAST(Reference AS SIGNED) AS ref, CAST(QuestRequired AS SIGNED) AS quest_only,
       CAST(MinCount AS SIGNED) AS cmin, MaxCount AS cmax
FROM creature_loot_template
UNION ALL
SELECT 'gobject', Entry, Item, Chance, GroupId, Reference, QuestRequired, MinCount, MaxCount
FROM gameobject_loot_template
UNION ALL
SELECT 'reference', Entry, Item, Chance, GroupId, Reference, QuestRequired, MinCount, MaxCount
FROM reference_loot_template;

CREATE OR REPLACE VIEW n_rel AS
-- SIGNED, not UNSIGNED: this schema's vendor.item column is declared as
-- plain (signed) int, unlike the other branches here and unlike every
-- other source's equivalent columns. Casting the first branch to UNSIGNED
-- and combining it with that still-signed one widened the whole view to
-- DECIMAL rather than BIGINT (MySQL's promotion rule for a mixed
-- signed/unsigned UNION), which is a data_type the other three sources
-- never produce. SIGNED sidesteps the mix entirely - every value below
-- (npc/spell/item ids) is far inside signed BIGINT range.
-- npc is cast here too (Task 9): the other three sources now explicitly
-- CAST their own npc column to keep the type-consistency contract after
-- Step 0's link fix changed which branch used to drive their width.
--
-- No `trainer` branch (Task 9 fix round 2, item 1): this schema's real
-- trainer data is creature_default_trainer -> trainer -> trainer_spell,
-- not npc_trainer, which is a legacy stub table here (4934 rows). Measured
-- on the real tables, over the 213 trainer NPCs v and ac share: ac
-- averages 35.5 spells against v's 16.6 and agrees with v within the
-- trainer_spell_count tolerance on only 119 of 213 (56%), where mz agrees
-- on 189 of 213 (89%) - WotLK roughly doubled trainer lists, so even ac's
-- *correct* trainer data cannot corroborate a vanilla spell count, and
-- npc_trainer's stub rows are worse still (458 of 459 non-NULL
-- trainer_spell_count findings against them had ac <= 3 spells). ac
-- already abstains on `link` for the analogous reason; this drops
-- `trainer` from n_rel entirely rather than repointing it at either table,
-- so ac abstains on trainer_spell_count via the existing NULL-peer
-- machinery (see diffs/02_relations.sql).
SELECT 'questgiver' AS kind, CAST(id AS SIGNED) AS npc, CAST(quest AS SIGNED) AS target FROM creature_queststarter
UNION ALL SELECT 'questender', id, quest FROM creature_questender
UNION ALL SELECT 'vendor',     entry, item FROM npc_vendor;

-- Quest chain edges; see views/v.sql for why the raw column cannot be
-- compared directly. This schema keeps PrevQuestID/NextQuestID in
-- quest_template_addon (9464 rows), not quest_template - quest_template's
-- RewardNextQuest is the WotLK auto-offer column, which is this family's
-- NextQuestInChain and a different fact.
CREATE OR REPLACE VIEW n_quest_chain AS
SELECT DISTINCT CAST(ABS(PrevQuestID) AS UNSIGNED) AS prev, CAST(ID AS UNSIGNED) AS next
FROM quest_template_addon WHERE PrevQuestID <> 0
UNION
SELECT DISTINCT CAST(ID AS UNSIGNED), CAST(ABS(NextQuestID) AS UNSIGNED)
FROM quest_template_addon WHERE NextQuestID <> 0
UNION
SELECT DISTINCT CAST(ID AS UNSIGNED), CAST(RewardNextQuest AS UNSIGNED)
FROM quest_template WHERE RewardNextQuest <> 0;
