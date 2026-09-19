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
-- missing from v's aggregate is a genuine zero spawn count there, not an
-- abstention - COALESCE(av.n, 0) is correct for v, not a stand-in for NULL.
--
-- It is NOT correct for the peers. When BOTH mz and ac are absent for a
-- combination, COALESCE(...,0) on each makes them agree with each other on
-- the value 0, and cmp.strength_num's second branch reads that mutual
-- agreement as corroboration - promoting "neither peer said anything" to
-- 'strong', the report's top label. Two independent absences are the
-- weakest evidence there is, not the strongest (measured before this fix:
-- 140 of 1098 strong spawn_count findings, 12.8%, were exactly this case).
-- So the peer arguments - both the ones passed to cmp.strength_num and the
-- stored mz_value/ac_value columns - stay NULL when absent, the same
-- "absent from the live database" idiom 01_creatures.sql uses. An absent
-- tw is likewise left NULL in the stored column for the same reason, even
-- though tw is never an argument to the consensus function.
--
-- Mandatory numeric form (see diffs/00_schema.sql): filter with
-- cmp.strength_mag(...) <> '', never restate the tolerance arithmetic here.
-- strength_mag, not strength_num: spawn_count is a magnitude topic, so a
-- lone voting peer that agrees with v must not write a contentless 'weak'
-- (fix round 2, item 2 - measured before this fix: 4562 of 5487 weak
-- spawn_count findings, 83%, were exactly this case).
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT k.zone, 'spawns', k.kind, k.entry, 'spawn_count',
       COALESCE(av.n, 0), amz.n, atw.n, aac.n,
       cmp.strength_mag(COALESCE(av.n, 0), amz.n, aac.n, 0.50, 5),
       ''
FROM (SELECT DISTINCT kind, zone, entry FROM cmp.spawn_agg) k
LEFT JOIN cmp.spawn_agg av  ON av.src  = 'v'  AND av.kind  = k.kind AND av.zone  = k.zone AND av.entry  = k.entry
LEFT JOIN cmp.spawn_agg amz ON amz.src = 'mz' AND amz.kind = k.kind AND amz.zone = k.zone AND amz.entry = k.entry
LEFT JOIN cmp.spawn_agg atw ON atw.src = 'tw' AND atw.kind = k.kind AND atw.zone = k.zone AND atw.entry = k.entry
LEFT JOIN cmp.spawn_agg aac ON aac.src = 'ac' AND aac.kind = k.kind AND aac.zone = k.zone AND aac.entry = k.entry
WHERE cmp.strength_mag(COALESCE(av.n, 0), amz.n, aac.n, 0.50, 5) <> '';

-- resp_min of 0 means "no respawn" rather than "respawns instantly", and a
-- (kind, zone, entry) combination absent from a peer's aggregate means that
-- peer never spawns the creature there at all - neither is a real respawn
-- window, so both collapse to NULL (an abstention from this comparison,
-- not a disagreement) via the IF() wrapper below, rather than dividing a
-- real window into a meaningless ratio against 0. v itself is guarded the
-- same way: only rows where v has a real, nonzero respawn window are
-- candidates at all (the inner JOIN plus the av.resp_min > 0 guard).
--
-- strength_mag, not strength_num: respawn_min is a magnitude topic, so a
-- lone voting peer that agrees with v must not write a contentless 'weak'
-- (fix round 2, item 2 - measured before this fix: 1334 of 7416 weak
-- respawn_min findings, 18%, were exactly this case). The IF() wrappers
-- above already null a peer *toward* abstention (a real 0 read as "no
-- respawn"), which is the safe direction and stays unchanged.
--
-- ac's respawn figure is advisory (fix round 3, item 12d), the same
-- pattern 01_creatures.sql already applies to hp@N: ac.gameobject.
-- spawntimesecs is 120 on 36.5% of its 96628 rows (v's own most common
-- value is 300 at 22.6%) - a categorical default covering over a third of
-- the table, not tens of thousands of independently tuned figures, and it
-- was voting against the realm on 3501 of 7096 respawn_min findings.
-- Gating ac's argument on mangozero corroborating it (NULL whenever mz
-- doesn't also vote a real respawn window) keeps every row where mz backs
-- ac up and silences the ones asserting nothing but ac's own bulk default.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT k.zone, 'spawns', k.kind, k.entry, 'respawn_min',
       av.resp_min, amz.resp_min, atw.resp_min, aac.resp_min,
       cmp.strength_mag(
           av.resp_min,
           IF(amz.resp_min > 0, amz.resp_min, NULL),
           CASE WHEN amz.resp_min > 0 THEN IF(aac.resp_min > 0, aac.resp_min, NULL) ELSE NULL END,
           1.0, 0),
       ''
FROM (SELECT DISTINCT kind, zone, entry FROM cmp.spawn_agg) k
JOIN      cmp.spawn_agg av  ON av.src  = 'v'  AND av.kind  = k.kind AND av.zone  = k.zone AND av.entry  = k.entry
LEFT JOIN cmp.spawn_agg amz ON amz.src = 'mz' AND amz.kind = k.kind AND amz.zone = k.zone AND amz.entry = k.entry
LEFT JOIN cmp.spawn_agg atw ON atw.src = 'tw' AND atw.kind = k.kind AND atw.zone = k.zone AND atw.entry = k.entry
LEFT JOIN cmp.spawn_agg aac ON aac.src = 'ac' AND aac.kind = k.kind AND aac.zone = k.zone AND aac.entry = k.entry
WHERE av.resp_min > 0
  AND cmp.strength_mag(
           av.resp_min,
           IF(amz.resp_min > 0, amz.resp_min, NULL),
           CASE WHEN amz.resp_min > 0 THEN IF(aac.resp_min > 0, aac.resp_min, NULL) ELSE NULL END,
           1.0, 0) <> '';
