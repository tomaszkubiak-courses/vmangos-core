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
       cmp.strength(f.v, f.mz, f.ac),
       -- Follow-up 4: name the patch revision when the quest has more than one.
       --
       -- quest_template is keyed (entry, patch) here and _quest_current picks
       -- the highest row at or below the realm's WowPatch, so a finding
       -- compares this realm's CURRENT revision against peers that have no
       -- patch dimension at all and carry exactly one version - usually the
       -- older one. That reads as this realm being wrong when it is serving
       -- the later revision correctly. Measured: 287 quest entries carry more
       -- than one patch row and 102 of them differ in level between
       -- revisions; 20 strong findings (16 lvl, 4 min_lvl) sit on that shape.
       -- Three of them were accepted as real defects by a judging pass before
       -- this note existed (quests 8292, 8293 and 7875, where the patch-6 row
       -- this realm serves is right and the peers hold the patch-3 value).
       --
       -- Read from the raw table on purpose: _quest_current exists precisely
       -- to hide the patch dimension, so it cannot answer how many revisions
       -- a quest has.
       CASE WHEN (SELECT COUNT(*) FROM v.quest_template qp
                   WHERE qp.entry = f.quest AND qp.patch <= 10) > 1
            THEN CONCAT('this realm serves the patch ',
                        (SELECT MAX(qp2.patch) FROM v.quest_template qp2
                          WHERE qp2.entry = f.quest AND qp2.patch <= 10),
                        ' revision of this quest; the peers carry one version and no patch dimension')
            ELSE '' END
FROM (
    SELECT zq.zone, zq.quest, fld.field,
           CAST(CASE fld.field WHEN 'exists'    THEN IF(qv.entry IS NULL, NULL, '1')
                               WHEN 'lvl'       THEN qv.lvl
                               WHEN 'min_lvl'   THEN qv.min_lvl
                               WHEN 'req_race'  THEN qv.req_race END AS CHAR) AS v,
           CAST(CASE fld.field WHEN 'exists'    THEN IF(qmz.entry IS NULL, NULL, '1')
                               WHEN 'lvl'       THEN qmz.lvl
                               WHEN 'min_lvl'   THEN qmz.min_lvl
                               WHEN 'req_race'  THEN qmz.req_race END AS CHAR) AS mz,
           CAST(CASE fld.field WHEN 'exists'    THEN IF(qtw.entry IS NULL, NULL, '1')
                               WHEN 'lvl'       THEN qtw.lvl
                               WHEN 'min_lvl'   THEN qtw.min_lvl
                               WHEN 'req_race'  THEN qtw.req_race END AS CHAR) AS tw,
           CAST(CASE fld.field WHEN 'exists'    THEN IF(qac.entry IS NULL, NULL, '1')
                               WHEN 'lvl'       THEN qac.lvl
                               WHEN 'min_lvl'   THEN qac.min_lvl
                               WHEN 'req_race'  THEN qac.req_race END AS CHAR) AS ac
    FROM cmp.zone_quest zq
    CROSS JOIN (SELECT 'exists' AS field UNION ALL SELECT 'lvl' UNION ALL SELECT 'min_lvl'
                UNION ALL SELECT 'req_race') fld
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
--
-- note (Follow-up 3, task-16 part B): cmp.strength's first branch (both
-- peers NULL) already means a 'strong' row here always has mz and ac both
-- non-null and agreeing - the only way v can still differ is either v
-- itself is NULL (this quest has no row for this objective at all: a real
-- existence gap) or v holds a different, non-null count than the peers'
-- shared one (both sides have the objective, they only disagree on the
-- required count - not an existence claim in either direction). Measured
-- on this corpus: of 28 strong obj: findings, 6 are the v-IS-NULL gap and
-- 22 are the differing-count shape - so only the 6 get a direction note;
-- the other 22 keep the plain 'objective count' note, since "this realm
-- has it; neither peer does" would be false when this realm's row exists
-- too, just with a different number.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quests', 'quest', o.quest,
       CONCAT('obj:', o.kind, ':', o.target),
       ov.cnt, omz.cnt, otw.cnt, oac.cnt,
       cmp.strength(ov.cnt, omz.cnt, oac.cnt),
       CASE WHEN cmp.strength(ov.cnt, omz.cnt, oac.cnt) = 'strong' AND ov.cnt IS NULL
                THEN 'objective count; this realm lacks it; both peers have it'
            ELSE 'objective count' END
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

-- Quest chain edges, replacing the old `next` field (2026-09-20).
--
-- The old comparison put this realm's NextQuestId beside mangoszero's
-- NextQuestId and AzerothCore's RewardNextQuest, and it was wrong twice
-- over. RewardNextQuest is the WotLK auto-offer column - this family's
-- NextQuestInChain, a different fact - while AzerothCore's actual
-- NextQuestID lives in quest_template_addon, which nothing here read. And
-- even against the right column, "A unlocks B" is spelled on either end:
-- this realm writes NextQuestId on A, the peers overwhelmingly write
-- PrevQuestId on B. Measured on the old shape: 257 of the 280 strong `next`
-- findings were this realm holding a link both peers read as 0, and 193 of
-- those 257 (75%) were carried by mangoszero on the successor's PrevQuestId
-- - the same edge, reported as a defect because it was read off the wrong
-- end.
--
-- n_quest_chain (one per source, see views/v.sql) collapses both spellings
-- into the same (prev, next) edge, so what is compared here is the fact and
-- not the convention. One finding per edge, the same per-target shape the
-- relations topic uses for vendor/questgiver rows.
--
-- A source that does not have BOTH quests cannot express an edge between
-- them: it abstains (NULL), exactly as a source missing an NPC abstains on
-- that NPC's vendor list in diffs/02_relations.sql. Only a source holding
-- both quests and not the edge is saying no.
--
-- The finding is filed against the predecessor, in the predecessor's zone.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quests', 'quest', e.prev, CONCAT('chain:', e.next),
       CASE WHEN NOT EXISTS (SELECT 1 FROM v.n_quest q WHERE q.entry = e.prev)
              OR NOT EXISTS (SELECT 1 FROM v.n_quest q WHERE q.entry = e.next) THEN NULL
            WHEN cv.prev IS NULL THEN '0' ELSE '1' END,
       CASE WHEN NOT EXISTS (SELECT 1 FROM mz.n_quest q WHERE q.entry = e.prev)
              OR NOT EXISTS (SELECT 1 FROM mz.n_quest q WHERE q.entry = e.next) THEN NULL
            WHEN cmz.prev IS NULL THEN '0' ELSE '1' END,
       CASE WHEN NOT EXISTS (SELECT 1 FROM tw.n_quest q WHERE q.entry = e.prev)
              OR NOT EXISTS (SELECT 1 FROM tw.n_quest q WHERE q.entry = e.next) THEN NULL
            WHEN ctw.prev IS NULL THEN '0' ELSE '1' END,
       CASE WHEN NOT EXISTS (SELECT 1 FROM ac.n_quest q WHERE q.entry = e.prev)
              OR NOT EXISTS (SELECT 1 FROM ac.n_quest q WHERE q.entry = e.next) THEN NULL
            WHEN cac.prev IS NULL THEN '0' ELSE '1' END,
       cmp.strength(
           CASE WHEN NOT EXISTS (SELECT 1 FROM v.n_quest q WHERE q.entry = e.prev)
                  OR NOT EXISTS (SELECT 1 FROM v.n_quest q WHERE q.entry = e.next) THEN NULL
                WHEN cv.prev IS NULL THEN '0' ELSE '1' END,
           CASE WHEN NOT EXISTS (SELECT 1 FROM mz.n_quest q WHERE q.entry = e.prev)
                  OR NOT EXISTS (SELECT 1 FROM mz.n_quest q WHERE q.entry = e.next) THEN NULL
                WHEN cmz.prev IS NULL THEN '0' ELSE '1' END,
           CASE WHEN NOT EXISTS (SELECT 1 FROM ac.n_quest q WHERE q.entry = e.prev)
                  OR NOT EXISTS (SELECT 1 FROM ac.n_quest q WHERE q.entry = e.next) THEN NULL
                WHEN cac.prev IS NULL THEN '0' ELSE '1' END),
       CASE WHEN cmp.strength(
                     CASE WHEN NOT EXISTS (SELECT 1 FROM v.n_quest q WHERE q.entry = e.prev)
                            OR NOT EXISTS (SELECT 1 FROM v.n_quest q WHERE q.entry = e.next) THEN NULL
                          WHEN cv.prev IS NULL THEN '0' ELSE '1' END,
                     CASE WHEN NOT EXISTS (SELECT 1 FROM mz.n_quest q WHERE q.entry = e.prev)
                            OR NOT EXISTS (SELECT 1 FROM mz.n_quest q WHERE q.entry = e.next) THEN NULL
                          WHEN cmz.prev IS NULL THEN '0' ELSE '1' END,
                     CASE WHEN NOT EXISTS (SELECT 1 FROM ac.n_quest q WHERE q.entry = e.prev)
                            OR NOT EXISTS (SELECT 1 FROM ac.n_quest q WHERE q.entry = e.next) THEN NULL
                          WHEN cac.prev IS NULL THEN '0' ELSE '1' END) <> 'strong' THEN ''
            WHEN cv.prev IS NULL THEN 'this realm lacks it; both peers have it'
            ELSE 'this realm has it; neither peer does' END
FROM (
    SELECT prev, next FROM v.n_quest_chain
    UNION SELECT prev, next FROM mz.n_quest_chain
    UNION SELECT prev, next FROM tw.n_quest_chain
    UNION SELECT prev, next FROM ac.n_quest_chain
) e
JOIN cmp.zone_quest zq ON zq.quest = e.prev
LEFT JOIN v.n_quest_chain  cv  ON cv.prev  = e.prev AND cv.next  = e.next
LEFT JOIN mz.n_quest_chain cmz ON cmz.prev = e.prev AND cmz.next = e.next
LEFT JOIN tw.n_quest_chain ctw ON ctw.prev = e.prev AND ctw.next = e.next
LEFT JOIN ac.n_quest_chain cac ON cac.prev = e.prev AND cac.next = e.next
WHERE cmp.strength(
        CASE WHEN NOT EXISTS (SELECT 1 FROM v.n_quest q WHERE q.entry = e.prev)
               OR NOT EXISTS (SELECT 1 FROM v.n_quest q WHERE q.entry = e.next) THEN NULL
             WHEN cv.prev IS NULL THEN '0' ELSE '1' END,
        CASE WHEN NOT EXISTS (SELECT 1 FROM mz.n_quest q WHERE q.entry = e.prev)
               OR NOT EXISTS (SELECT 1 FROM mz.n_quest q WHERE q.entry = e.next) THEN NULL
             WHEN cmz.prev IS NULL THEN '0' ELSE '1' END,
        CASE WHEN NOT EXISTS (SELECT 1 FROM ac.n_quest q WHERE q.entry = e.prev)
               OR NOT EXISTS (SELECT 1 FROM ac.n_quest q WHERE q.entry = e.next) THEN NULL
             WHEN cac.prev IS NULL THEN '0' ELSE '1' END) <> '';
