-- Topic 5: the effective drop chance of items a quest objective requires.
--
-- Scoped to quest items on purpose. Every other loot difference is noise at
-- this stage; an item a quest demands that drops at a tenth the rate the
-- peers agree on is the defect that stalls a player.
--
-- This file depends on cmp.zone_quest, created by diffs/03_quests.sql on an
-- earlier connection (files run in glob order).

CREATE OR REPLACE VIEW cmp.quest_items AS
SELECT DISTINCT zq.zone, o.quest, o.target AS item
FROM cmp.zone_quest zq
JOIN v.n_quest_obj o ON o.quest = zq.quest AND o.kind = 'item'
UNION
SELECT DISTINCT zq.zone, o.quest, o.target
FROM cmp.zone_quest zq
JOIN mz.n_quest_obj o ON o.quest = zq.quest AND o.kind = 'item';

-- cmp.n_loot_eff is a WITH RECURSIVE view (views/loot_eff_body.sql x4, one
-- per source, unioned) - 7,698,092 rows on this corpus. A single COUNT(*)
-- over it takes 2m39s, and no index can exist on a view, so MySQL must
-- re-execute the recursive CTE from scratch for every query that touches it.
-- The obvious query below (a DISTINCT scan plus four LEFT JOIN probes
-- against cmp.n_loot_eff directly) is five such passes.
--
-- Instead, scan it exactly once here, filtered down to the items a quest
-- objective actually demands (2217 distinct items -> 106,530 rows, a 72x
-- reduction), and index the result. DROP TABLE IF EXISTS first: run_diffs.sh
-- rebuilds cmp.findings from scratch on every run and this table must be
-- just as non-cumulative, or a stale row from a previous corpus rebuild
-- could outlive the source data it was scoped from.
DROP TABLE IF EXISTS cmp.quest_loot_eff;
CREATE TABLE cmp.quest_loot_eff (
    src    VARCHAR(16)    NOT NULL,
    tbl    VARCHAR(16)    NOT NULL,
    entry  INT UNSIGNED   NOT NULL,
    item   INT UNSIGNED   NOT NULL,
    p_drop DOUBLE         NOT NULL,
    KEY ix_item_src_tbl_entry (item, src, tbl, entry)
) ENGINE=InnoDB;

INSERT INTO cmp.quest_loot_eff (src, tbl, entry, item, p_drop)
SELECT src, tbl, entry, item, p_drop
FROM cmp.n_loot_eff
WHERE item IN (SELECT DISTINCT item FROM cmp.quest_items);

-- Magnitude call site, per diffs/00_schema.sql: cmp.strength_mag, not
-- cmp.strength (byte equality is wrong for an independently computed
-- float) and not cmp.strength_num (a lone voting peer that agrees with v
-- would write a contentless 'weak' - the same shape fixed for hp@N,
-- trainer_spell_count, spawn_count and respawn_min).
--
-- Applied to p_drop scaled to PERCENTAGE POINTS (p_drop * 100), not the raw
-- 0..1 fraction the plan called for. Verified on this corpus and by direct
-- construction: cmp._agrees_num's ratio predicate divides by
-- GREATEST(LEAST(ABS(a), ABS(b)), 1) - a floor of 1, calibrated for the
-- magnitude-scale topics it already serves (health in the hundreds,
-- spawn counts). Fed the raw fraction, that floor makes the denominator 1
-- for any p_drop pair (both always < 1), so the ratio check collapses to
-- "ABS(a-b) <= 1.0", which is true for every possible pair of fractions in
-- [0,1] and is checked (and short-circuits to TRUE) BEFORE abs_tol is ever
-- reached - cmp._agrees_num(0.02, 0.99, 1.0, 0.05), a 49x disagreement,
-- returns TRUE. Run against this corpus with the raw fraction as the plan
-- specified, this query produced zero findings out of 113556 candidate
-- rows despite 9657 of them differing from v by more than 5 points in
-- absolute terms. Scaling to percentage points first (abs_tol becomes 5,
-- the spec's 5 points, not 0.05) makes the floor negligible against typical
-- drop-chance magnitudes and restores both halves of the "2x ratio or 5
-- points" rule; cmp.strength_mag(2, 99, 99, 1.0, 5) correctly returns
-- 'strong'. The stored display columns already round p_drop * 100 to 2
-- decimals - this reuses that same scale for the comparison instead of
-- introducing a second one.
--
-- The mandatory numeric form (WHERE cmp.strength_mag(...) <> '') restates
-- that same function call rather than the tolerance arithmetic inline - the
-- plan's draft WHERE clause spelled out the 2x/5-point check by hand, which
-- is exactly what the mandatory form exists to forbid.
--
-- COALESCE(..., 0) on v only, per diffs/00_schema.sql's spawn_count
-- comment: v's absence from a (tbl, entry) combination is a real, known
-- zero (this audit knows the realm's full loot table set), but coalescing
-- a peer's absence to 0 would let two independently absent peers agree with
-- each other on a value neither one asserted - the exact defect fixed for
-- spawn_count in diffs/06_spawns.sql. lmz.p_drop and lac.p_drop stay NULL
-- when absent, both as strength_mag arguments and as stored columns.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT qi.zone, 'quest_item_drops', 'item', qi.item,
       CONCAT(src.tbl, ':', src.entry),
       ROUND(lv.p_drop * 100, 2), ROUND(lmz.p_drop * 100, 2),
       ROUND(ltw.p_drop * 100, 2), ROUND(lac.p_drop * 100, 2),
       cmp.strength_mag(COALESCE(lv.p_drop, 0) * 100, lmz.p_drop * 100, lac.p_drop * 100, 1.0, 5),
       CONCAT('quest ', qi.quest)
FROM cmp.quest_items qi
JOIN (SELECT DISTINCT tbl, entry, item FROM cmp.quest_loot_eff) src ON src.item = qi.item
LEFT JOIN cmp.quest_loot_eff lv  ON lv.src  = 'v'  AND lv.tbl  = src.tbl AND lv.entry  = src.entry AND lv.item  = qi.item
LEFT JOIN cmp.quest_loot_eff lmz ON lmz.src = 'mz' AND lmz.tbl = src.tbl AND lmz.entry = src.entry AND lmz.item = qi.item
LEFT JOIN cmp.quest_loot_eff ltw ON ltw.src = 'tw' AND ltw.tbl = src.tbl AND ltw.entry = src.entry AND ltw.item = qi.item
LEFT JOIN cmp.quest_loot_eff lac ON lac.src = 'ac' AND lac.tbl = src.tbl AND lac.entry = src.entry AND lac.item = qi.item
WHERE cmp.strength_mag(COALESCE(lv.p_drop, 0) * 100, lmz.p_drop * 100, lac.p_drop * 100, 1.0, 5) <> '';
