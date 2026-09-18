CREATE DATABASE IF NOT EXISTS cmp DEFAULT CHARACTER SET utf8mb4;

DROP TABLE IF EXISTS cmp.findings;
CREATE TABLE cmp.findings (
    zone        INT UNSIGNED NOT NULL,
    topic       VARCHAR(32)  NOT NULL,
    entity_kind VARCHAR(16)  NOT NULL,
    entity_id   INT UNSIGNED NOT NULL,
    field       VARCHAR(48)  NOT NULL,
    v_value     VARCHAR(128),
    mz_value    VARCHAR(128),
    tw_value    VARCHAR(128),
    ac_value    VARCHAR(128),
    strength    VARCHAR(8)   NOT NULL,
    note        VARCHAR(255) NOT NULL DEFAULT '',
    KEY ix_zone_topic (zone, topic),
    KEY ix_strength (strength)
) ENGINE=InnoDB;

-- The consensus rule, in one place.
--
-- tortoise-wow is a fork of the live database, so its agreement carries no
-- information and it is not an argument here. It enters a report only where it
-- disagrees, as context on a finding the peers already raised.
--
-- A NULL peer is abstaining - it cannot express this field at all - and an
-- abstention never strengthens a finding. This also covers v itself being
-- NULL (the entity is missing from the realm under audit): '<=>' treats
-- NULL as a real value there, so a v that is absent while both independent
-- peers agree on a value still reads as both peers differing from v, which
-- is exactly the missing-entity finding this audit must not lose.
DROP FUNCTION IF EXISTS cmp.strength;
CREATE FUNCTION cmp.strength(v VARCHAR(128), mz VARCHAR(128), ac VARCHAR(128))
RETURNS VARCHAR(8) DETERMINISTIC
RETURN CASE
    WHEN mz IS NULL AND ac IS NULL                      THEN ''
    WHEN mz IS NOT NULL AND ac IS NOT NULL
         AND NOT (v <=> mz) AND NOT (v <=> ac)
         AND (mz <=> ac)                                THEN 'strong'
    WHEN NOT (v <=> mz) OR NOT (v <=> ac)               THEN 'weak'
    ELSE ''
END;

-- cmp.strength judges peer agreement with byte equality ('<=>'), which is
-- right for the boolean and existence topics (exists, relations,
-- objectives). Every numeric topic (effective health, spawn count, respawn
-- window, drop chance) instead judges v against a tolerance, so byte
-- equality between two independently computed floats is the wrong test for
-- them - it almost never holds, which makes 'strong' effectively
-- unreachable for those topics (measured: an 8704-candidate health-shaped
-- reproduction on this corpus gave 18 strong and 8686 weak before this
-- function existed).
--
-- cmp.strength_num is that sibling: same branch order, same abstention
-- semantics (a NULL peer can never produce 'strong'; a NULL v is a real,
-- distinct value, not an abstention - see cmp.strength's comment above) and
-- the same three return values, with the tolerance predicate
-- cmp._agrees_num substituted for '<=>' in both the "disagrees with v" and
-- the "peers agree with each other" positions.
--
-- Two tolerances, not one, because the topics need both shapes: a purely
-- relative one (health) and one where a small absolute slack matters more
-- than the ratio (spawn count, where 2 vs 3 should not be a finding even
-- though the ratio is large). Either tolerance may be 0 to mean "this half
-- of the rule does not apply" - respawn window and health have no absolute
-- component, so they pass abs_tol=0. cmp._agrees_num guards each half on
-- its own tolerance being > 0; a naive `ABS(a-b) >= abs_tol` would treat
-- abs_tol=0 as "everything differs" and turn every row into a finding.
--
-- The ratio denominator is GREATEST(LEAST(ABS(a), ABS(b)), 1), not
-- GREATEST(b, 1) the way the topics' own draft WHERE clauses had it -
-- dividing by whichever argument happens to be the peer is asymmetric
-- (a=2b gives ratio 1.0, but b=2a gives 0.5, so the same pair agrees or
-- disagrees depending on which source is v), and a consensus rule cannot
-- depend on argument order. This is a deliberate departure from the plan
-- and moves the candidate counts slightly; see the fix round 1 report.
--
-- Mandatory form for every numeric topic's diff query, so the Item 3
-- defect (a doubly-abstaining peer writing a contentless finding) cannot
-- recur: filter with `WHERE cmp.strength_num(...) <> ''`, never restate the
-- tolerance arithmetic in the WHERE clause. When mz abstains, the topic's
-- own advisory-ac wrapper (CASE WHEN mz IS NULL THEN NULL ELSE ac END, used
-- where ac's figure is only trustworthy alongside a corroborating mz)
-- nulls ac's argument too, both peer arguments arrive NULL, and
-- cmp.strength_num's first branch (shared with cmp.strength) returns ''
-- like any other doubly-abstaining row - the WHERE clause drops it by
-- construction instead of a bare tolerance predicate writing a finding
-- that asserts nothing.
--
-- Tolerance values, from the plan, for this signature:
--   topic                          ratio_tol   abs_tol
--   effective health               0.20        0
--   spawn count                    0.50        5
--   respawn window (2x)            1.0         0
--   drop chance (2x or 5 points)   1.0         0.05
DROP FUNCTION IF EXISTS cmp._agrees_num;
CREATE FUNCTION cmp._agrees_num(a DOUBLE, b DOUBLE, ratio_tol DOUBLE, abs_tol DOUBLE)
RETURNS BOOLEAN DETERMINISTIC
RETURN CASE
    WHEN a IS NULL AND b IS NULL                         THEN TRUE
    WHEN a IS NULL OR b IS NULL                           THEN FALSE
    WHEN ratio_tol > 0
         AND ABS(a - b) / GREATEST(LEAST(ABS(a), ABS(b)), 1) <= ratio_tol
                                                            THEN TRUE
    WHEN abs_tol > 0 AND ABS(a - b) <= abs_tol             THEN TRUE
    WHEN ratio_tol = 0 AND abs_tol = 0 AND a = b           THEN TRUE
    ELSE FALSE
END;

DROP FUNCTION IF EXISTS cmp.strength_num;
CREATE FUNCTION cmp.strength_num(v DOUBLE, mz DOUBLE, ac DOUBLE, ratio_tol DOUBLE, abs_tol DOUBLE)
RETURNS VARCHAR(8) DETERMINISTIC
RETURN CASE
    WHEN mz IS NULL AND ac IS NULL                       THEN ''
    WHEN mz IS NOT NULL AND ac IS NOT NULL
         AND NOT cmp._agrees_num(v, mz, ratio_tol, abs_tol)
         AND NOT cmp._agrees_num(v, ac, ratio_tol, abs_tol)
         AND cmp._agrees_num(mz, ac, ratio_tol, abs_tol)  THEN 'strong'
    WHEN NOT cmp._agrees_num(v, mz, ratio_tol, abs_tol)
         OR NOT cmp._agrees_num(v, ac, ratio_tol, abs_tol) THEN 'weak'
    ELSE ''
END;

-- cmp.strength_num's second branch ('weak' whenever v disagrees with mz OR
-- with ac) is correct for the existence topic and the per-target relation
-- kinds: there, a NULL peer genuinely means "this source cannot express
-- this fact" and the other peer's vote is the whole finding regardless of
-- whether it agrees with v. Task 8 tested that property on purpose and
-- cmp.strength_num above must go on providing it unchanged.
--
-- It is the wrong rule for the four *magnitude* topics wired to it
-- (effective health, trainer_spell_count, spawn_count, respawn_min): there,
-- a lone abstaining peer plus a voting peer that agrees with v is not a
-- disagreement anyone raised - it is one source, alone, matching v, and
-- cmp.strength_num's second branch still writes 'weak' for it because
-- `NOT cmp._agrees_num(v, NULL, ...)` is unconditionally TRUE. Measured on
-- this corpus, that is most of the 'weak' volume in every magnitude field,
-- and it corroborates nothing:
--   field                 weak total   contentless    strong affected
--   spawn_count           5487         4562 (83%)      0
--   respawn_min           7416         1334 (18%)      0
--   hp@N (all levels)     5747         696  (12%)       0
--   trainer_spell_count   514          180  (35%)       0
-- 6772 of 38771 findings (17.5%) assert nothing and disappear once this
-- function filters them. Zero 'strong' findings move in any field - the
-- case this suppresses only ever downgrades a contentless 'weak' to '',
-- which is what proves it cannot reach a corroborated signal.
--
-- cmp.strength_mag delegates to cmp.strength_num for every other input; it
-- only intercepts the lone-abstention-plus-agreement shape and reads it as
-- silence instead of a finding. Wire the four magnitude call sites to this
-- function, never to cmp.strength_num directly - the existence topic and
-- the per-target relation kinds must keep using cmp.strength_num (or
-- cmp.strength) so they keep reporting a lone peer's disagreement.
DROP FUNCTION IF EXISTS cmp.strength_mag;
CREATE FUNCTION cmp.strength_mag(v DOUBLE, mz DOUBLE, ac DOUBLE, ratio_tol DOUBLE, abs_tol DOUBLE)
RETURNS VARCHAR(8) DETERMINISTIC
RETURN CASE
    WHEN mz IS NULL AND ac IS NOT NULL
         AND cmp._agrees_num(v, ac, ratio_tol, abs_tol)     THEN ''
    WHEN ac IS NULL AND mz IS NOT NULL
         AND cmp._agrees_num(v, mz, ratio_tol, abs_tol)     THEN ''
    ELSE cmp.strength_num(v, mz, ac, ratio_tol, abs_tol)
END;
