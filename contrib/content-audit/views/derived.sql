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
