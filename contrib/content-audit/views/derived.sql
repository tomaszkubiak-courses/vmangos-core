-- Effective creature health, resolved through each source's own pipeline.
--
-- Health is not a column that can be renamed into a shared shape: every
-- source computes it differently, so this view reproduces each pipeline
-- rather than comparing raw columns.
--
--   v:  creature_classlevelstats.health * creature_template.health_multiplier
--   tw: absolute creature_template.health_min / health_max
--   ac: creature_classlevelstats.basehp0 * creature_template.HealthModifier
--   mz: creature_template_classlevelstats.BaseHealthExp0 * HealthMultiplier,
--       falling back to the absolute MinLevelHealth/MaxLevelHealth columns
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
-- rows where ArmorMultiplier is 0 (a linear interpolation between the two
-- by relative level, which collapses to picking the smaller of the two
-- values when MinLevel == MaxLevel). This is the reverse of the priority
-- the plan's COALESCE gave; the plan's own fallback note said to prefer
-- whichever the source actually reads, so this view does.
--
-- Both tw and mz store two absolute values (min/max) rather than one row
-- per level, and 288 tw rows / 68 mz rows have level_min == level_max with
-- the two values genuinely different - a naive "one branch per endpoint"
-- union would emit two rows for the same (src, entry, lvl) with different
-- hp, breaking the one-row-per-key contract. Both branches below instead
-- start from the *distinct* set of levels per entry (a plain UNION, not
-- UNION ALL, collapses level_min == level_max to one row before the health
-- lookup), and break the tie deterministically when it still occurs: mz
-- keeps MinLevelHealth (matching the core's own min() when the interpolation
-- fallback path is hit at a single level), tw keeps health_max. Both are
-- documented simplifications of a sub-1% edge case, not a claim that the two
-- values are equal.
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
SELECT 'ac', ct.entry, cls.level, cls.basehp0 * ct.HealthModifier
FROM ac.creature_template ct
JOIN ac.creature_classlevelstats cls
  ON cls.class = ct.unit_class AND cls.level IN (ct.minlevel, ct.maxlevel)
UNION ALL
SELECT 'mz', l.Entry, l.lvl,
       COALESCE(
           cls.BaseHealthExp0 * ct.HealthMultiplier,
           CASE WHEN l.lvl = ct.MinLevel
                THEN NULLIF(ct.MinLevelHealth, 0)
                ELSE NULLIF(ct.MaxLevelHealth, 0)
           END)
FROM (
    SELECT Entry, MinLevel AS lvl FROM mz.creature_template
    UNION
    SELECT Entry, MaxLevel FROM mz.creature_template
) l
JOIN mz.creature_template ct ON ct.Entry = l.Entry
LEFT JOIN mz.creature_template_classlevelstats cls
  ON cls.Class = ct.UnitClass AND cls.Level = l.lvl;
