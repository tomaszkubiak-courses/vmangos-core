WITH RECURSIVE
-- Per group: how much chance is spoken for, and how many rows share the rest.
grp AS (
    SELECT tbl, entry, grp AS g,
           SUM(CASE WHEN chance > 0 THEN chance ELSE 0 END) AS sum_explicit,
           SUM(CASE WHEN chance = 0 THEN 1 ELSE 0 END)      AS n_equal
    FROM __SRC__.n_loot
    GROUP BY tbl, entry, grp
),
-- The probability of each row firing, before any reference is followed.
-- Ungrouped rows roll independently. Grouped rows compete for one roll:
-- an explicit chance is absolute within it, and rows at zero divide the rest.
base AS (
    SELECT l.tbl, l.entry, l.item, l.ref, l.quest_only,
           CASE
               WHEN l.grp = 0     THEN l.chance / 100.0
               WHEN l.chance > 0  THEN l.chance / 100.0
               WHEN g.n_equal > 0 THEN GREATEST(100.0 - g.sum_explicit, 0) / g.n_equal / 100.0
               ELSE 0
           END AS p_local
    FROM __SRC__.n_loot l
    JOIN grp g ON g.tbl = l.tbl AND g.entry = l.entry AND g.g = l.grp
),
-- Follow references, multiplying probabilities. The depth cap is what makes a
-- self-referencing table terminate; five is far beyond any real loot tree (the
-- deepest chain measured across all four corpus sources is 2 hops).
walk AS (
    SELECT tbl, entry AS root_entry, item, ref, quest_only, p_local AS p, 0 AS depth
    FROM base
    WHERE tbl <> 'reference'
    UNION ALL
    SELECT w.tbl, w.root_entry, b.item, b.ref,
           GREATEST(w.quest_only, b.quest_only), w.p * b.p_local, w.depth + 1
    FROM walk w
    JOIN base b ON b.tbl = 'reference' AND b.entry = w.ref
    WHERE w.ref > 0 AND w.depth < 5
)
-- A row is a resolved leaf once it stops pointing anywhere else (ref = 0) -
-- real data's item column is meaningless noise on a ref > 0 row (it mirrors
-- the reference id itself, not a real item; verified against creature_loot_template
-- directly). depth >= 5 also counts as a leaf: a chain that is still
-- unresolved at the cap is a table that references itself (real data never
-- reaches depth 2), and reporting its last-known item/probability beats
-- silently dropping it from the audit. An item reachable by several paths
-- drops if any path fires; clamp before the logarithm, since a row at 100%
-- would otherwise take LOG(0).
SELECT CAST('__SRC__' AS CHAR(16)) AS src,
       CAST(root_entry AS UNSIGNED) AS entry,
       CAST(item AS UNSIGNED) AS item,
       CAST(quest_only AS UNSIGNED) AS quest_only,
       CAST(1 - EXP(SUM(LOG(1 - LEAST(p, 0.999999)))) AS DOUBLE) AS p_drop,
       CAST(tbl AS CHAR(16)) AS tbl
FROM walk
WHERE item > 0 AND (ref = 0 OR depth >= 5)
GROUP BY tbl, root_entry, item, quest_only;
