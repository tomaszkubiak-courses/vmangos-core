-- Effective creature health, resolved through each source's own pipeline.
--
-- Health is not a column that can be renamed into a shared shape: every
-- source computes it differently, so this view reproduces each pipeline
-- rather than comparing raw columns.
--
--   v:  creature_classlevelstats.health * creature_template.health_multiplier
--   tw: absolute creature_template.health_min / health_max
--   ac: creature_classlevelstats.basehp{exp} * creature_template.HealthModifier,
--       where {exp} (0/1/2 = classic/TBC/WotLK) picks the tier column
--   mz: creature_template_classlevelstats.BaseHealthExp0 * HealthMultiplier when
--       creature_template.ArmorMultiplier > 0 and a stats row exists (the core's
--       actual gate), falling back to the absolute MinLevelHealth/MaxLevelHealth
--       columns otherwise
--
-- Two corrections to the plan this was written from, both verified against
-- the corpus and, for mz, against the mangoszero-server source rather than
-- guessed:
--
-- 1. The plan's tw branch joined tw.creature_classlevelstats, which does not
--    exist - this fork has no creature stat table at all (only
--    player_classlevelstats). The plan's conclusion from that ("tw abstains
--    on health") does not follow: tw.creature_template carries absolute
--    health_min/health_max columns, so tw stores effective health outright
--    the same way mz does, rather than a multiplier against a stat table.
--    Dropping tw would lose a whole source's vote for no reason.
--
-- 2. v.creature_template is keyed (entry, patch) - 15217 rows, 10381
--    distinct entries. Reading it directly, as the plan's v branch did,
--    would reintroduce the duplicate-entry bug Task 4 fixed with
--    v._creature_current (one row per entry, the greatest patch <= this
--    realm's configured WowPatch of 10). This view reads _creature_current
--    instead. tw has no patch dimension at all (verified: no `patch` column
--    on tw.creature_template), so it needs no equivalent helper.
--
-- The mangoszero formula was not guessed: Creature::SelectLevel in
-- mangoszero-server's src/game/Object/CreatureLevel.cpp uses
-- creature_template_classlevelstats (via ObjectMgr::GetCreatureClassLvlStats)
-- as the *primary* source whenever creature_template.ArmorMultiplier > 0 and
-- a matching stats row exists - true for 9100/9113 template rows in this
-- corpus, and BaseHealthExp0 is nonzero on every one of the 189 stat rows.
-- MinLevelHealth/MaxLevelHealth are the fallback, used only for the ~13
-- rows where ArmorMultiplier <= 0 (a linear interpolation between the two
-- by relative level, which collapses to picking the smaller of the two
-- values when MinLevel == MaxLevel). This is the reverse of the priority
-- the plan's COALESCE gave; the plan's own fallback note said to prefer
-- whichever the source actually reads, so this view does.
--
-- Fix round 1 found that an earlier version of this view implemented only
-- half of that gate: it fell back to the absolute columns when no
-- classlevelstats row matched, but never checked ArmorMultiplier at all. On
-- this corpus a classlevelstats row matches for every one of the 13
-- ArmorMultiplier <= 0 rows, so all 13 were silently taking the
-- classlevelstats path - up to 119x off from the value the core actually
-- computes. The mz branch below tests ArmorMultiplier explicitly, mirroring
-- Creature::SelectLevel's `cinfo->ArmorMultiplier > 0 && cCLS` condition
-- (cCLS itself requires BaseHealthExp0 != 0 and BaseDamageExp0 > 0.01, both
-- checked here too, though no row in this corpus currently fails either).
--
-- Both tw and mz store two absolute values (min/max) rather than one row
-- per level, and 288 tw rows / 68 mz rows have level_min == level_max with
-- the two values genuinely different - a naive "one branch per endpoint"
-- union would emit two rows for the same (src, entry, lvl) with different
-- hp, breaking the one-row-per-key contract. Both branches below instead
-- start from the *distinct* set of levels per entry (a plain UNION, not
-- UNION ALL, collapses level_min == level_max to one row before the health
-- lookup), independently of which formula ends up producing the value for
-- that row.
--
-- Where mz's fallback path (the 13 ArmorMultiplier <= 0 rows, none of which
-- currently have MinLevelHealth != MaxLevelHealth) has to pick one of the
-- two stored values for a single collapsed level, it uses LEAST()/GREATEST()
-- rather than "MinLevelHealth at MinLevel, MaxLevelHealth at MaxLevel" -
-- this is exact, not an approximation: it reproduces
-- Creature::SelectLevel's own std::min/std::max of the two columns for any
-- row that reaches this branch, including a future one where
-- MinLevelHealth is the larger of the two. All 68 of the mz rows with
-- level_min == level_max and differing stored health currently have a valid
-- classlevelstats row and ArmorMultiplier > 0, so none of them reach this
-- branch on this corpus today - the LEAST()/GREATEST() choice is proven
-- correct by construction, not by a live example. tw has no equivalent
-- engine source to check against, so its tie (health_max on collapse) stays
-- a documented arbitrary choice, not a claimed match to anything.
--
-- The rank multiplier (CONFIG_FLOAT_RATE_CREATURE_*_HP in VMaNGOS) is
-- excluded on purpose: it is server tuning, not content, and a rank
-- disagreement between sources is already reported as a `rank` finding in
-- topic 1. Including it here would report the same defect twice.

CREATE DATABASE IF NOT EXISTS cmp DEFAULT CHARACTER SET utf8mb4;

CREATE OR REPLACE VIEW cmp.n_creature_hp AS
SELECT CAST('v' AS CHAR(4)) AS src, CAST(ct.entry AS UNSIGNED) AS entry,
       CAST(cls.level AS UNSIGNED) AS lvl,
       CAST(cls.health * ct.health_multiplier AS DOUBLE) AS hp
FROM v._creature_current ct
JOIN v.creature_classlevelstats cls
  ON cls.class = ct.unit_class AND cls.level IN (ct.level_min, ct.level_max)
UNION ALL
SELECT 'tw', l.entry, l.lvl,
       CASE WHEN l.lvl = ct.level_min THEN ct.health_min ELSE ct.health_max END
FROM (
    SELECT entry, level_min AS lvl FROM tw.creature_template
    UNION
    SELECT entry, level_max FROM tw.creature_template
) l
JOIN tw.creature_template ct ON ct.entry = l.entry
UNION ALL
SELECT 'ac', ct.entry, cls.level,
       (CASE ct.exp WHEN 1 THEN cls.basehp1 WHEN 2 THEN cls.basehp2 ELSE cls.basehp0 END)
       * ct.HealthModifier
FROM ac.creature_template ct
JOIN ac.creature_classlevelstats cls
  ON cls.class = ct.unit_class AND cls.level IN (ct.minlevel, ct.maxlevel)
UNION ALL
SELECT 'mz', l.Entry, l.lvl,
       CASE
           WHEN ct.ArmorMultiplier > 0 AND cls.BaseHealthExp0 IS NOT NULL
                AND cls.BaseHealthExp0 <> 0 AND cls.BaseDamageExp0 > 0.01
               THEN cls.BaseHealthExp0 * ct.HealthMultiplier
           WHEN l.lvl = ct.MinLevel THEN LEAST(ct.MinLevelHealth, ct.MaxLevelHealth)
           ELSE GREATEST(ct.MinLevelHealth, ct.MaxLevelHealth)
       END
FROM (
    SELECT Entry, MinLevel AS lvl FROM mz.creature_template
    UNION
    SELECT Entry, MaxLevel FROM mz.creature_template
) l
JOIN mz.creature_template ct ON ct.Entry = l.Entry
LEFT JOIN mz.creature_template_classlevelstats cls
  ON cls.Class = ct.UnitClass AND cls.Level = l.lvl;

-- The vanilla quest experience formula, transcribed from Quest::XPValue
-- (mangoszero-server's src/game/WorldHandlers/QuestDef.cpp, lines 242-304).
-- MaNGOS Zero computes this at runtime; VMaNGOS stores the result as RewXP.
-- Both carry the inputs (RewMoneyMaxLevel, QuestLevel), so the comparison is
-- exact rather than approximate.
--
-- The full function also scales the result by how far the receiving
-- player's level is above the quest's (100% up to +5, stepping down to 10%
-- at +9 or more) and applies ceilf() to the result. This view implements
-- only the full-value case - player level equal to quest level, which keeps
-- the player inside the "no discount" band and is what this comparison
-- assumes throughout, per the brief - and does not apply ceilf(), matching
-- the brief's own stub function (step 4) and its ROUND()-with-tolerance
-- test. Every branch below was read from the source, not guessed:
--
--   qLevel >= 65            money_max_level / 6.0
--   qLevel == 64             money_max_level / 4.8
--   qLevel == 63             money_max_level / 3.6
--   qLevel == 62             money_max_level / 2.4
--   qLevel == 61             money_max_level / 1.2
--   0 < qLevel <= 60         money_max_level / 0.6   (the ELSE branch the
--                            brief flagged as a placeholder - every quest in
--                            the pilot zones is below level 61, so this is
--                            the only branch most rows in this corpus reach)
--   qLevel <= 0              0 (fullxp is never assigned; QuestDef.cpp's own
--                            "uint32 qLevel = QuestLevel > 0 ? ... : 0"
--                            clamp means no branch's condition can match)
--
-- money_max_level <= 0 also yields 0: XPValue's own outer
-- "if (RewMoneyMaxLevel > 0)" gate means fullxp is never computed at all
-- otherwise, and the function returns 0.

DROP FUNCTION IF EXISTS cmp.vanilla_quest_xp;
CREATE FUNCTION cmp.vanilla_quest_xp(quest_level INT, money_max_level INT)
RETURNS DOUBLE DETERMINISTIC
RETURN CASE
    WHEN money_max_level <= 0 THEN 0
    WHEN quest_level >= 65 THEN money_max_level / 6.0
    WHEN quest_level  = 64 THEN money_max_level / 4.8
    WHEN quest_level  = 63 THEN money_max_level / 3.6
    WHEN quest_level  = 62 THEN money_max_level / 2.4
    WHEN quest_level  = 61 THEN money_max_level / 1.2
    WHEN quest_level  > 0 AND quest_level <= 60 THEN money_max_level / 0.6
    ELSE 0
END;

-- cmp.n_quest_xp(src, quest, xp, awards_xp). xp is NULL for ac, which
-- cannot supply a vanilla figure (see below); awards_xp is the boolean
-- every source can vote on.
--
-- ac's n_quest.rew_money_max_level is mapped from RewardMoney (the actual
-- money reward), not from a RewMoneyMaxLevel-equivalent formula input -
-- feeding it to vanilla_quest_xp would silently compute a meaningless
-- figure, not merely an inaccurate one, so ac abstains on xp entirely and
-- votes only on whether the quest awards experience at all.
CREATE OR REPLACE VIEW cmp.n_quest_xp AS
SELECT 'v' AS src, entry AS quest, CAST(rew_xp AS DOUBLE) AS xp,
       CASE WHEN rew_xp > 0 THEN 1 ELSE 0 END AS awards_xp
FROM v.n_quest
UNION ALL
SELECT 'tw', entry, CAST(rew_xp AS DOUBLE),
       CASE WHEN rew_xp > 0 THEN 1 ELSE 0 END
FROM tw.n_quest
UNION ALL
SELECT 'mz', entry, cmp.vanilla_quest_xp(lvl, rew_money_max_level),
       CASE WHEN rew_money_max_level > 0 THEN 1 ELSE 0 END
FROM mz.n_quest
UNION ALL
-- AzerothCore cannot supply a vanilla figure: RewardXPDifficulty indexes
-- QuestXP.dbc, which is not available here, and WotLK rebalanced quest
-- experience regardless. It votes on the boolean only.
SELECT 'ac', ID, CAST(NULL AS DOUBLE),
       CASE WHEN RewardXPDifficulty > 0 THEN 1 ELSE 0 END
FROM ac.quest_template;

-- Effective drop probability per source. The body lives in loot_eff_body.sql
-- so that the checks can run it against a fixture schema. build_views.sh
-- generates cmp.n_loot_eff_v/_mz/_tw/_ac from that body (one WITH RECURSIVE
-- view per source - a recursive CTE cannot be repeated inside a UNION ALL)
-- and then defines cmp.n_loot_eff as a plain UNION ALL over those four,
-- immediately before it sources this file.

-- Task 13: cmp.peer_lineage. One shared-ancestry table, not six scattered
-- tests - see diffs/00_schema.sql's comment above cmp.apply_lineage for the
-- doctrine this implements and why a boolean-shaped kind (vendor,
-- questgiver/questender/link) carries no rows here.
--
-- Schema is generic across kinds on purpose (kind, k1, k2, k3) rather than
-- one column set per kind, so a future comparable kind is one more INSERT,
-- not a new table. The PRIMARY KEY doubles as the only index a lookup
-- needs, because k1/k2/k3 are always populated in the same order the diffs
-- join against:
--   kind='loot':          k1=tbl, k2=entry, k3=item
--   kind='creature_stat':  k1=entry, k2=field ('lvl_min'/'lvl_max'), k3='' (unused)
--   kind='spawn_count':    k1=spawn kind ('creature'/'gobject'), k2=zone, k3=entry
--   kind='respawn_min':    k1=spawn kind ('creature'/'gobject'), k2=zone, k3=entry
DROP TABLE IF EXISTS cmp.peer_lineage;
CREATE TABLE cmp.peer_lineage (
    kind VARCHAR(16) NOT NULL,
    k1   VARCHAR(32) NOT NULL,
    k2   VARCHAR(32) NOT NULL,
    k3   VARCHAR(32) NOT NULL DEFAULT '',
    PRIMARY KEY (kind, k1, k2, k3)
) ENGINE=InnoDB;

-- 'loot': the value is the EFFECTIVE drop chance (cmp.n_loot_eff_mz/_ac),
-- not the raw creature_loot_template/gameobject_loot_template chance column
-- - that is the value diffs/05_quest_item_drops.sql actually judges peer
-- agreement on, at the same (tbl, entry, item) grain, rounded to the same
-- 2-decimal percentage-point precision the topic already stores. Reading
-- the two per-source recursive views directly (not the four-way
-- cmp.n_loot_eff union diffs/05_quest_item_drops.sql's own comment warns
-- off) keeps this to the two sources that matter and pays the recursive
-- CTE's cost exactly once per source, here, rather than once per query
-- site. Measured on this corpus: 1m34s, 743337 matching rows before the
-- GROUP BY collapses them to one row per key - acceptable during
-- build_views.sh, which nothing downstream re-enters mid-run the way
-- run_diffs.sh's long queries do.
--
-- Follow-up 3 (task-16): exact match is too strict here. AzerothCore
-- routes a loot row through reference_loot_template often enough that a
-- shared-ancestor value drifts a few points off mangoszero's still-raw
-- copy of the same row (measured: item 3014, creature 435 - mz stores the
-- ancestral 80% flat, ac's reference table resolves the same row to 70%),
-- and the exact test above missed all of those, leaving them to read as
-- ordinary independent corroboration. Widened to a relative near-match:
-- mz and ac's effective drop chances (already scaled to percentage points,
-- to sidestep cmp._agrees_num's floor-of-1 trap the way
-- diffs/05_quest_item_drops.sql's own strength_mag call site already does)
-- agree within 15% relative, via cmp._agrees_num with abs_tol=0 so a small
-- absolute slack near zero never substitutes for the ratio test.
--
-- 15%, not 30%: measured on this corpus, of the 51 strong quest_item_drops
-- findings that survive today, 23 peer pairs fall within 15% of each other
-- and 36 within 30% - the wider threshold starts pulling in pairs that
-- could plausibly be independent agreement rather than one drifted shared
-- row. This must also stay far tighter than the tolerance the finding was
-- already judged 'strong' under - cmp.strength_mag's own call for this
-- topic uses ratio_tol=1.0 (roughly "within 2x") - because a lineage test
-- at the same looseness as the agreement test it sits inside proves
-- nothing: it would relabel corroboration that has nothing to do with
-- shared ancestry. 15% is close enough to be the signature of a rounding
-- or reference-table indirection on one shared row, not two sources that
-- merely landed in the same ballpark.
INSERT INTO cmp.peer_lineage (kind, k1, k2, k3)
SELECT 'loot', mz.tbl, CAST(mz.entry AS CHAR), CAST(mz.item AS CHAR)
FROM cmp.n_loot_eff_mz mz
JOIN cmp.n_loot_eff_ac ac
  ON ac.tbl = mz.tbl AND ac.entry = mz.entry AND ac.item = mz.item
WHERE cmp._agrees_num(ROUND(mz.p_drop * 100, 2), ROUND(ac.p_drop * 100, 2), 0.15, 0)
GROUP BY mz.tbl, mz.entry, mz.item;

-- 'creature_stat': the level PAIR, not each level field independently.
-- Caught while measuring this on the corpus, before wiring it in: a lone
-- field (lvl_min alone, or lvl_max alone) is the wrong grain, because
-- diffs/01_creatures.sql's 'strong' verdict for these fields already comes
-- from cmp.strength's byte-equality test - a 'strong' lvl_min finding
-- ALREADY means mz.lvl_min = ac.lvl_min exactly, by construction. Testing
-- that same single field again here is not a second, independent check; it
-- is the same test, so it fired on literally 100% of the existing strong
-- lvl_min/lvl_max findings (measured: 72 of 72) rather than isolating the
-- shared-ancestor subset. It also does not match the brief's own value-space
-- reasoning: a bare level (1..63ish) is not "wide enough that agreeing by
-- chance is implausible" - the brief's own example is "a level pair", and
-- the evidence figure it cites (7246 of 9112, 80%) is measured jointly, on
-- BOTH fields matching at once, not on either alone. A creature whose min
-- and max level both agree between mz and ac is comparatively hard to reach
-- by coincidence (up to ~63x63 combinations, most creatures narrow); a
-- single matching scalar is not. Both fields below share the same WHERE
-- (the joint pair), so a lineage row for one field's finding implies the
-- other field also matched - if only one of the two matched, neither field
-- is marked, and that 'strong' finding is left alone as ordinary
-- independent agreement.
INSERT INTO cmp.peer_lineage (kind, k1, k2, k3)
SELECT 'creature_stat', CAST(mz.entry AS CHAR), 'lvl_min', ''
FROM mz.n_creature mz JOIN ac.n_creature ac ON ac.entry = mz.entry
WHERE mz.lvl_min = ac.lvl_min AND mz.lvl_max = ac.lvl_max
UNION ALL
SELECT 'creature_stat', CAST(mz.entry AS CHAR), 'lvl_max', ''
FROM mz.n_creature mz JOIN ac.n_creature ac ON ac.entry = mz.entry
WHERE mz.lvl_min = ac.lvl_min AND mz.lvl_max = ac.lvl_max;

-- 'spawn_count' / 'respawn_min': diffs/06_spawns.sql's two magnitude fields,
-- each keyed on (spawn kind, zone, entry) - cmp.spawn_agg's own grain - with
-- k1=kind ('creature'/'gobject'), k2=zone, k3=entry.
--
-- This is NOT the creature_stat shape above, on purpose, even though both
-- are "two related fields sharing a table". creature_stat needs the WHOLE
-- level pair because cmp.strength (byte equality) already means a 'strong'
-- lvl_min finding implies mz=ac on lvl_min exactly - testing that one field
-- again proves nothing, only the pair is new information. spawn_count and
-- respawn_min are judged by cmp.strength_mag under a TOLERANCE instead (0.50
-- ratio / 5 absolute for count, 2x for respawn), so a 'strong' finding there
-- only means mz and ac fall within tolerance of each other, not that they
-- hold the same number - byte identity is extra information on each field
-- independently, and neither field's identity is implied by the other's.
-- There is also no reason to demand both: a realm can inherit a shared
-- spawn count while independently retuning the respawn timer, or vice versa.
-- So each field gets its own kind and its own WHERE, unlike creature_stat's
-- shared one.
--
-- Measured on this corpus before wiring: of 16933 (kind, zone, entry) groups
-- common to mz and ac, 9343 (55%) match on BOTH count and respawn - but
-- applying that joint condition to the existing 'strong' findings gives 641
-- of 929 spawn_count and 809 of 1023 respawn_min, not the per-field figures
-- below - confirming the two fields are independent evidence, not one
-- signal. Testing each field against its OWN peer identity gives 806 of 929
-- strong spawn_count findings (87%) and 902 of 1023 strong respawn_min
-- findings (88%) with byte-identical mz/ac values - 1708 of 1952 overall.
--
-- resp_min uses <=> (both are NULL-safe here in principle, though
-- cmp.spawn_agg's MIN(resp_min) is never actually NULL on this corpus) -
-- matching the null-safety diffs/00_schema.sql uses throughout rather than
-- a bare '=' that would silently drop a NULL pairing instead of matching it.
-- A group where both peers store a real respawn of 0 poses no risk of a
-- false 'lineage' here: 06_spawns.sql's IF() wrappers already null out a
-- zero respawn before it ever reaches cmp.strength_mag, so that finding can
-- never be 'strong' in the first place and this row is simply never looked
-- up - the same "harmless LEFT JOIN" property 01_creatures.sql's comment
-- documents for creature_stat's other fields.
INSERT INTO cmp.peer_lineage (kind, k1, k2, k3)
SELECT 'spawn_count', mz.kind, CAST(mz.zone AS CHAR), CAST(mz.entry AS CHAR)
FROM cmp.spawn_agg mz
JOIN cmp.spawn_agg ac
  ON ac.src = 'ac' AND ac.kind = mz.kind AND ac.zone = mz.zone AND ac.entry = mz.entry
WHERE mz.src = 'mz' AND mz.n = ac.n
UNION ALL
SELECT 'respawn_min', mz.kind, CAST(mz.zone AS CHAR), CAST(mz.entry AS CHAR)
FROM cmp.spawn_agg mz
JOIN cmp.spawn_agg ac
  ON ac.src = 'ac' AND ac.kind = mz.kind AND ac.zone = mz.zone AND ac.entry = mz.entry
WHERE mz.src = 'mz' AND mz.resp_min <=> ac.resp_min;
