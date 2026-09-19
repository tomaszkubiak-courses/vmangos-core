-- Topic 1: creature templates, per zone.
--
-- A creature belongs to a zone if it is spawned there in any source. That is
-- what makes a missing template reportable: a creature spawned in Westfall
-- by mangoszero but absent from the live database has no live spawn to find
-- it by.
--
-- cmp.zone_creature is created here and consumed by Step 2
-- (diffs/02_relations.sql), on a separate connection. The files run in glob
-- order (01_ before 02_), so this view must exist by the time 02 runs; do
-- not rename or drop it without updating that file too.

-- Every (zone, creature) pair any source places in the world.
CREATE OR REPLACE VIEW cmp.zone_creature AS
SELECT DISTINCT zone, entry FROM v.n_spawn  WHERE kind = 'creature'
UNION SELECT DISTINCT zone, entry FROM mz.n_spawn WHERE kind = 'creature'
UNION SELECT DISTINCT zone, entry FROM tw.n_spawn WHERE kind = 'creature'
UNION SELECT DISTINCT zone, entry FROM ac.n_spawn WHERE kind = 'creature';

-- `rank` is a real column of n_creature and a reserved word on this MySQL
-- build; every reference below is backticked (recorded from Task 4).
--
-- Task 13: cmp.peer_lineage (kind='creature_stat') only ever carries rows
-- for field IN ('lvl_min', 'lvl_max') - see views/derived.sql. The LEFT
-- JOIN below is harmless for every other field (exists, faction, rank,
-- type): pl.k1 is NULL there, cmp.apply_lineage sees is_lineage=FALSE, and
-- the strength value it returns is unchanged. No WHERE-clause update is
-- needed: cmp.apply_lineage only ever turns 'strong' into 'lineage', never
-- into or out of '', so the WHERE clause below still filters on the
-- pre-lineage cmp.strength(...) call exactly as before.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zc.zone, 'creatures', 'creature', zc.entry, f.field,
       f.v, f.mz, f.tw, f.ac,
       cmp.apply_lineage(cmp.strength(f.v, f.mz, f.ac), pl.k1 IS NOT NULL),
       CASE WHEN f.v IS NULL THEN 'absent from the live database' ELSE '' END
FROM cmp.zone_creature zc
JOIN (
    SELECT zc2.entry,
           'exists' AS field,
           CASE WHEN cv.entry  IS NULL THEN NULL ELSE '1' END AS v,
           CASE WHEN cmz.entry IS NULL THEN NULL ELSE '1' END AS mz,
           CASE WHEN ctw.entry IS NULL THEN NULL ELSE '1' END AS tw,
           CASE WHEN cac.entry IS NULL THEN NULL ELSE '1' END AS ac
    FROM (SELECT DISTINCT entry FROM cmp.zone_creature) zc2
    LEFT JOIN v.n_creature  cv  ON cv.entry  = zc2.entry
    LEFT JOIN mz.n_creature cmz ON cmz.entry = zc2.entry
    LEFT JOIN tw.n_creature ctw ON ctw.entry = zc2.entry
    LEFT JOIN ac.n_creature cac ON cac.entry = zc2.entry

    UNION ALL

    SELECT zc2.entry, fld.field,
           CAST(CASE fld.field WHEN 'lvl_min' THEN cv.lvl_min WHEN 'lvl_max' THEN cv.lvl_max
                               WHEN 'faction' THEN cv.faction WHEN 'rank' THEN cv.`rank`
                               WHEN 'type' THEN cv.type END AS CHAR),
           CAST(CASE fld.field WHEN 'lvl_min' THEN cmz.lvl_min WHEN 'lvl_max' THEN cmz.lvl_max
                               WHEN 'faction' THEN cmz.faction WHEN 'rank' THEN cmz.`rank`
                               WHEN 'type' THEN cmz.type END AS CHAR),
           CAST(CASE fld.field WHEN 'lvl_min' THEN ctw.lvl_min WHEN 'lvl_max' THEN ctw.lvl_max
                               WHEN 'faction' THEN ctw.faction WHEN 'rank' THEN ctw.`rank`
                               WHEN 'type' THEN ctw.type END AS CHAR),
           CAST(CASE fld.field WHEN 'lvl_min' THEN cac.lvl_min WHEN 'lvl_max' THEN cac.lvl_max
                               WHEN 'faction' THEN cac.faction WHEN 'rank' THEN cac.`rank`
                               WHEN 'type' THEN cac.type END AS CHAR)
    FROM (SELECT DISTINCT entry FROM cmp.zone_creature) zc2
    CROSS JOIN (SELECT 'lvl_min' AS field UNION ALL SELECT 'lvl_max'
                UNION ALL SELECT 'faction' UNION ALL SELECT 'rank'
                UNION ALL SELECT 'type') fld
    JOIN v.n_creature  cv  ON cv.entry  = zc2.entry
    LEFT JOIN mz.n_creature cmz ON cmz.entry = zc2.entry
    LEFT JOIN tw.n_creature ctw ON ctw.entry = zc2.entry
    LEFT JOIN ac.n_creature cac ON cac.entry = zc2.entry
) f ON f.entry = zc.entry
LEFT JOIN cmp.peer_lineage pl
  ON pl.kind = 'creature_stat' AND pl.k1 = CAST(zc.entry AS CHAR) AND pl.k2 = f.field
WHERE cmp.strength(f.v, f.mz, f.ac) <> '';

-- Effective health, at the 20% tolerance from the spec. AzerothCore's vote is
-- advisory: WotLK inflated creature health as policy, so it counts only where
-- mangoszero agrees. Passing NULL for ac where mz is absent expresses exactly
-- that - an unsupported AzerothCore figure cannot make a finding strong, and
-- combined with the mandatory WHERE form below it drops those rows instead
-- of writing empty ones.
--
-- Mandatory numeric form (see diffs/00_schema.sql): filter with
-- cmp.strength_mag(...) <> '', never restate the tolerance arithmetic here.
-- strength_mag, not strength_num: hp@N is a magnitude topic, so a lone
-- voting peer that agrees with v must not write a contentless 'weak'
-- (fix round 2, item 2).
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zc.zone, 'creatures', 'creature', zc.entry,
       CONCAT('hp@', hv.lvl),
       ROUND(hv.hp), ROUND(hmz.hp), ROUND(htw.hp), ROUND(hac.hp),
       cmp.strength_mag(
           hv.hp,
           hmz.hp,
           CASE WHEN hmz.hp IS NULL THEN NULL ELSE hac.hp END,
           0.20, 0),
       'AzerothCore health is advisory; WotLK inflated creature health'
FROM cmp.zone_creature zc
JOIN      cmp.n_creature_hp hv  ON hv.src  = 'v'  AND hv.entry  = zc.entry
LEFT JOIN cmp.n_creature_hp hmz ON hmz.src = 'mz' AND hmz.entry = zc.entry AND hmz.lvl = hv.lvl
LEFT JOIN cmp.n_creature_hp htw ON htw.src = 'tw' AND htw.entry = zc.entry AND htw.lvl = hv.lvl
LEFT JOIN cmp.n_creature_hp hac ON hac.src = 'ac' AND hac.entry = zc.entry AND hac.lvl = hv.lvl
WHERE cmp.strength_mag(
        hv.hp,
        hmz.hp,
        CASE WHEN hmz.hp IS NULL THEN NULL ELSE hac.hp END,
        0.20, 0) <> '';
