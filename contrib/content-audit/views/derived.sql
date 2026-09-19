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
