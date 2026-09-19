-- Topic 3: quest existence, gating and objectives, per zone.
--
-- A quest is placed by where its giver stands, not by ZoneOrSort. That column
-- is a client sort key - negative for class and profession quests - and it
-- disagrees with the quest's actual location often enough to misfile
-- findings.
--
-- cmp.zone_quest stays v+mz only, unlike diffs/02_relations.sql's
-- cmp.zone_creature, which nominates from all four sources. That widening
-- does not apply here: measured on this corpus, nominating zone-quest pairs
-- from tw and ac as well moves the pair count from 4409 to 6946 and the
-- quest count from 3788 to 6059, and 2254 of those 2271 added quests (99%)
-- do not exist in v.n_quest at all - tortoise-wow custom content and
-- TBC/WotLK quests neither vanilla peer can vote on. This view decides which
-- quests ENTER the audit, and nominating from a WotLK database would
-- contradict the spec's roles for tw and ac. tw and ac still vote on every
-- quest v or mz nominates, in both queries below.
CREATE OR REPLACE VIEW cmp.zone_quest AS
SELECT DISTINCT s.zone, r.target AS quest
FROM v.n_rel r
JOIN v.n_spawn s ON s.kind = 'creature' AND s.entry = r.npc
WHERE r.kind = 'questgiver'
UNION
SELECT DISTINCT s.zone, r.target
FROM mz.n_rel r
JOIN mz.n_spawn s ON s.kind = 'creature' AND s.entry = r.npc
WHERE r.kind = 'questgiver';

-- Existence and the fields that gate a quest: one guarded INSERT, not the
-- INSERT-then-UPDATE-then-DELETE the plan drafted (the mandatory shape from
-- diffs/00_schema.sql / diffs/01_creatures.sql). The derived table computes
-- each field's four values once; the outer WHERE filters on the same
-- cmp.strength call instead of a second pass writing rows that assert
-- nothing and then deleting them.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT f.zone, 'quests', 'quest', f.quest, f.field, f.v, f.mz, f.tw, f.ac,
       cmp.strength(f.v, f.mz, f.ac), ''
FROM (
    SELECT zq.zone, zq.quest, fld.field,
           CAST(CASE fld.field WHEN 'exists'    THEN IF(qv.entry IS NULL, NULL, '1')
                               WHEN 'lvl'       THEN qv.lvl
                               WHEN 'min_lvl'   THEN qv.min_lvl
                               WHEN 'req_race'  THEN qv.req_race
                               WHEN 'next'      THEN qv.next END AS CHAR) AS v,
           CAST(CASE fld.field WHEN 'exists'    THEN IF(qmz.entry IS NULL, NULL, '1')
                               WHEN 'lvl'       THEN qmz.lvl
                               WHEN 'min_lvl'   THEN qmz.min_lvl
                               WHEN 'req_race'  THEN qmz.req_race
                               WHEN 'next'      THEN qmz.next END AS CHAR) AS mz,
           CAST(CASE fld.field WHEN 'exists'    THEN IF(qtw.entry IS NULL, NULL, '1')
                               WHEN 'lvl'       THEN qtw.lvl
                               WHEN 'min_lvl'   THEN qtw.min_lvl
                               WHEN 'req_race'  THEN qtw.req_race
                               WHEN 'next'      THEN qtw.next END AS CHAR) AS tw,
           CAST(CASE fld.field WHEN 'exists'    THEN IF(qac.entry IS NULL, NULL, '1')
                               WHEN 'lvl'       THEN qac.lvl
                               WHEN 'min_lvl'   THEN qac.min_lvl
                               WHEN 'req_race'  THEN qac.req_race
                               WHEN 'next'      THEN qac.next END AS CHAR) AS ac
    FROM cmp.zone_quest zq
    CROSS JOIN (SELECT 'exists' AS field UNION ALL SELECT 'lvl' UNION ALL SELECT 'min_lvl'
                UNION ALL SELECT 'req_race' UNION ALL SELECT 'next') fld
    LEFT JOIN v.n_quest  qv  ON qv.entry  = zq.quest
    LEFT JOIN mz.n_quest qmz ON qmz.entry = zq.quest
    LEFT JOIN tw.n_quest qtw ON qtw.entry = zq.quest
    LEFT JOIN ac.n_quest qac ON qac.entry = zq.quest
) f
WHERE cmp.strength(f.v, f.mz, f.ac) <> '';

-- Objectives: present in one source, absent in another, or a different
-- required count. Counts stay on cmp.strength (byte equality), not
-- cmp.strength_mag: they are small exact integers (kill/collect counts a
-- quest objective demands), so exact match is the intended semantic - unlike
-- the drop-chance and xp figures in 04_quest_rewards.sql / 05_quest_item_drops.sql,
-- which are computed magnitudes and use cmp.strength_mag instead.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quests', 'quest', o.quest,
       CONCAT('obj:', o.kind, ':', o.target),
       ov.cnt, omz.cnt, otw.cnt, oac.cnt,
       cmp.strength(ov.cnt, omz.cnt, oac.cnt),
       'objective count'
FROM cmp.zone_quest zq
JOIN (
    SELECT quest, kind, target FROM v.n_quest_obj
    UNION SELECT quest, kind, target FROM mz.n_quest_obj
    UNION SELECT quest, kind, target FROM ac.n_quest_obj
) o ON o.quest = zq.quest
LEFT JOIN v.n_quest_obj  ov  ON ov.quest  = o.quest AND ov.kind  = o.kind AND ov.target  = o.target
LEFT JOIN mz.n_quest_obj omz ON omz.quest = o.quest AND omz.kind = o.kind AND omz.target = o.target
LEFT JOIN tw.n_quest_obj otw ON otw.quest = o.quest AND otw.kind = o.kind AND otw.target = o.target
LEFT JOIN ac.n_quest_obj oac ON oac.quest = o.quest AND oac.kind = o.kind AND oac.target = o.target
WHERE cmp.strength(ov.cnt, omz.cnt, oac.cnt) <> '';
