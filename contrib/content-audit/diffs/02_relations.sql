-- Topic 2: connected creatures. Trainer relations, plus three per-target
-- relationship families and the (post-Task-9-Step-0) link family.
--
-- This file depends on cmp.zone_creature, created by diffs/01_creatures.sql
-- on the connection before this one (files run in glob order, 01_ before
-- 02_, each on its own connection). Zone placement is taken from there
-- rather than from a separate v+mz spawn query, so this topic and topic 1
-- never disagree about where a creature is.
--
-- A source with no rows at all of a given kind is abstaining, not
-- reporting absence: AzerothCore has no creature_linking equivalent, so it
-- must not vote on links. cmp.rel_kinds_present and the kmz/ktw/kac joins
-- below are what enforce that for the per-target kinds.

CREATE OR REPLACE VIEW cmp.rel_kinds_present AS
SELECT 'v'  AS src, kind FROM v.n_rel  GROUP BY kind
UNION ALL SELECT 'mz', kind FROM mz.n_rel GROUP BY kind
UNION ALL SELECT 'tw', kind FROM tw.n_rel GROUP BY kind
UNION ALL SELECT 'ac', kind FROM ac.n_rel GROUP BY kind;

-- (a) Trainer relations, one finding per trainer NPC rather than per spell.
-- Under the plan's original per-spell shape this kind alone produced 28446
-- of 35651 relation findings (80%) on this corpus, restating one fact - v
-- has far fewer, shorter trainer lists than mz/tw/ac - tens of thousands of
-- times and burying every other relation finding in the report (Task 4
-- already judged the size gap a genuine content difference, not a bug). All
-- four sources have trainer rows (v 4676, mz 27324, tw 38038, ac 4934), so
-- an absent (src, npc) pair here is a real zero - "this source's trainer
-- does not teach this spell list" - not an abstention, and no
-- rel_kinds_present gating is needed for this half of the topic.
CREATE OR REPLACE VIEW cmp.trainer_spell_count AS
SELECT 'v'  AS src, npc, COUNT(*) AS n FROM v.n_rel  WHERE kind = 'trainer' GROUP BY npc
UNION ALL SELECT 'mz', npc, COUNT(*) FROM mz.n_rel WHERE kind = 'trainer' GROUP BY npc
UNION ALL SELECT 'tw', npc, COUNT(*) FROM tw.n_rel WHERE kind = 'trainer' GROUP BY npc
UNION ALL SELECT 'ac', npc, COUNT(*) FROM ac.n_rel WHERE kind = 'trainer' GROUP BY npc;

CREATE OR REPLACE VIEW cmp.trainer_npc AS
SELECT DISTINCT npc FROM v.n_rel  WHERE kind = 'trainer'
UNION SELECT DISTINCT npc FROM mz.n_rel WHERE kind = 'trainer'
UNION SELECT DISTINCT npc FROM tw.n_rel WHERE kind = 'trainer'
UNION SELECT DISTINCT npc FROM ac.n_rel WHERE kind = 'trainer';

INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT z.zone, 'relations', 'creature', tn.npc, 'trainer_spell_count',
       COALESCE(tv.n, 0), COALESCE(tmz.n, 0), COALESCE(ttw.n, 0), COALESCE(tac.n, 0),
       cmp.strength_num(COALESCE(tv.n, 0), COALESCE(tmz.n, 0), COALESCE(tac.n, 0), 0.50, 5),
       ''
FROM cmp.trainer_npc tn
JOIN cmp.zone_creature z ON z.entry = tn.npc
LEFT JOIN cmp.trainer_spell_count tv  ON tv.src  = 'v'  AND tv.npc  = tn.npc
LEFT JOIN cmp.trainer_spell_count tmz ON tmz.src = 'mz' AND tmz.npc = tn.npc
LEFT JOIN cmp.trainer_spell_count ttw ON ttw.src = 'tw' AND ttw.npc = tn.npc
LEFT JOIN cmp.trainer_spell_count tac ON tac.src = 'ac' AND tac.npc = tn.npc
WHERE cmp.strength_num(COALESCE(tv.n, 0), COALESCE(tmz.n, 0), COALESCE(tac.n, 0), 0.50, 5) <> '';

-- (b) vendor, questgiver, questender and link stay per-target: a specific
-- missing vendor item or quest giver is directly actionable, and at ~7k
-- rows (post-Step-0, with link now entry-keyed) the volume is fine.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT z.zone, 'relations', 'creature', r.npc,
       CONCAT(r.kind, ':', r.target),
       CASE WHEN rv.npc  IS NULL THEN NULL ELSE '1' END,
       CASE WHEN rmz.npc IS NULL AND kmz.kind IS NOT NULL THEN '0'
            WHEN rmz.npc IS NULL THEN NULL ELSE '1' END,
       CASE WHEN rtw.npc IS NULL AND ktw.kind IS NOT NULL THEN '0'
            WHEN rtw.npc IS NULL THEN NULL ELSE '1' END,
       CASE WHEN rac.npc IS NULL AND kac.kind IS NOT NULL THEN '0'
            WHEN rac.npc IS NULL THEN NULL ELSE '1' END,
       cmp.strength(
           CASE WHEN rv.npc IS NULL THEN '0' ELSE '1' END,
           CASE WHEN kmz.kind IS NULL THEN NULL WHEN rmz.npc IS NULL THEN '0' ELSE '1' END,
           CASE WHEN kac.kind IS NULL THEN NULL WHEN rac.npc IS NULL THEN '0' ELSE '1' END),
       ''
FROM (
    SELECT kind, npc, target FROM v.n_rel  WHERE kind IN ('vendor', 'questgiver', 'questender', 'link')
    UNION SELECT kind, npc, target FROM mz.n_rel WHERE kind IN ('vendor', 'questgiver', 'questender', 'link')
    UNION SELECT kind, npc, target FROM tw.n_rel WHERE kind IN ('vendor', 'questgiver', 'questender', 'link')
    UNION SELECT kind, npc, target FROM ac.n_rel WHERE kind IN ('vendor', 'questgiver', 'questender', 'link')
) r
JOIN cmp.zone_creature z ON z.entry = r.npc
LEFT JOIN v.n_rel  rv  ON rv.kind  = r.kind AND rv.npc  = r.npc AND rv.target  = r.target
LEFT JOIN mz.n_rel rmz ON rmz.kind = r.kind AND rmz.npc = r.npc AND rmz.target = r.target
LEFT JOIN tw.n_rel rtw ON rtw.kind = r.kind AND rtw.npc = r.npc AND rtw.target = r.target
LEFT JOIN ac.n_rel rac ON rac.kind = r.kind AND rac.npc = r.npc AND rac.target = r.target
LEFT JOIN cmp.rel_kinds_present kmz ON kmz.src = 'mz' AND kmz.kind = r.kind
LEFT JOIN cmp.rel_kinds_present ktw ON ktw.src = 'tw' AND ktw.kind = r.kind
LEFT JOIN cmp.rel_kinds_present kac ON kac.src = 'ac' AND kac.kind = r.kind
WHERE cmp.strength(
        CASE WHEN rv.npc IS NULL THEN '0' ELSE '1' END,
        CASE WHEN kmz.kind IS NULL THEN NULL WHEN rmz.npc IS NULL THEN '0' ELSE '1' END,
        CASE WHEN kac.kind IS NULL THEN NULL WHEN rac.npc IS NULL THEN '0' ELSE '1' END) <> '';
