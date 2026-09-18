-- Topic 6: spawn counts and respawn windows, per zone and creature.
--
-- GUIDs are not comparable between sources, so this is always an aggregate.
-- Tolerances from the spec: count differs by 50% or by 5 spawns; respawn by
-- 2x. entity_kind here is n_spawn.kind, so both 'creature' and 'gobject'
-- appear in this topic - that is correct and intended.

CREATE OR REPLACE VIEW cmp.spawn_agg AS
SELECT 'v' AS src, kind, zone, entry, COUNT(*) AS n,
       MIN(resp_min) AS resp_min, MAX(resp_max) AS resp_max
FROM v.n_spawn GROUP BY kind, zone, entry
UNION ALL
SELECT 'mz', kind, zone, entry, COUNT(*), MIN(resp_min), MAX(resp_max)
FROM mz.n_spawn GROUP BY kind, zone, entry
UNION ALL
SELECT 'tw', kind, zone, entry, COUNT(*), MIN(resp_min), MAX(resp_max)
FROM tw.n_spawn GROUP BY kind, zone, entry
UNION ALL
SELECT 'ac', kind, zone, entry, COUNT(*), MIN(resp_min), MAX(resp_max)
FROM ac.n_spawn GROUP BY kind, zone, entry;

-- Every source populates n_spawn, so a (kind, zone, entry) combination
-- missing from a peer's aggregate is a genuine zero spawn count there, not
-- an abstention - COALESCE(...,0) is correct, not a stand-in for NULL.
--
-- Mandatory numeric form (see diffs/00_schema.sql): filter with
-- cmp.strength_num(...) <> '', never restate the tolerance arithmetic here.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT k.zone, 'spawns', k.kind, k.entry, 'spawn_count',
       COALESCE(av.n, 0), COALESCE(amz.n, 0), COALESCE(atw.n, 0), COALESCE(aac.n, 0),
       cmp.strength_num(COALESCE(av.n, 0), COALESCE(amz.n, 0), COALESCE(aac.n, 0), 0.50, 5),
       ''
FROM (SELECT DISTINCT kind, zone, entry FROM cmp.spawn_agg) k
LEFT JOIN cmp.spawn_agg av  ON av.src  = 'v'  AND av.kind  = k.kind AND av.zone  = k.zone AND av.entry  = k.entry
LEFT JOIN cmp.spawn_agg amz ON amz.src = 'mz' AND amz.kind = k.kind AND amz.zone = k.zone AND amz.entry = k.entry
LEFT JOIN cmp.spawn_agg atw ON atw.src = 'tw' AND atw.kind = k.kind AND atw.zone = k.zone AND atw.entry = k.entry
LEFT JOIN cmp.spawn_agg aac ON aac.src = 'ac' AND aac.kind = k.kind AND aac.zone = k.zone AND aac.entry = k.entry
WHERE cmp.strength_num(COALESCE(av.n, 0), COALESCE(amz.n, 0), COALESCE(aac.n, 0), 0.50, 5) <> '';

-- resp_min of 0 means "no respawn" rather than "respawns instantly", and a
-- (kind, zone, entry) combination absent from a peer's aggregate means that
-- peer never spawns the creature there at all - neither is a real respawn
-- window, so both collapse to NULL (an abstention from this comparison,
-- not a disagreement) via the IF() wrapper below, rather than dividing a
-- real window into a meaningless ratio against 0. v itself is guarded the
-- same way: only rows where v has a real, nonzero respawn window are
-- candidates at all (the inner JOIN plus the av.resp_min > 0 guard).
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT k.zone, 'spawns', k.kind, k.entry, 'respawn_min',
       av.resp_min, amz.resp_min, atw.resp_min, aac.resp_min,
       cmp.strength_num(
           av.resp_min,
           IF(amz.resp_min > 0, amz.resp_min, NULL),
           IF(aac.resp_min > 0, aac.resp_min, NULL),
           1.0, 0),
       ''
FROM (SELECT DISTINCT kind, zone, entry FROM cmp.spawn_agg) k
JOIN      cmp.spawn_agg av  ON av.src  = 'v'  AND av.kind  = k.kind AND av.zone  = k.zone AND av.entry  = k.entry
LEFT JOIN cmp.spawn_agg amz ON amz.src = 'mz' AND amz.kind = k.kind AND amz.zone = k.zone AND amz.entry = k.entry
LEFT JOIN cmp.spawn_agg atw ON atw.src = 'tw' AND atw.kind = k.kind AND atw.zone = k.zone AND atw.entry = k.entry
LEFT JOIN cmp.spawn_agg aac ON aac.src = 'ac' AND aac.kind = k.kind AND aac.zone = k.zone AND aac.entry = k.entry
WHERE av.resp_min > 0
  AND cmp.strength_num(
           av.resp_min,
           IF(amz.resp_min > 0, amz.resp_min, NULL),
           IF(aac.resp_min > 0, aac.resp_min, NULL),
           1.0, 0) <> '';
