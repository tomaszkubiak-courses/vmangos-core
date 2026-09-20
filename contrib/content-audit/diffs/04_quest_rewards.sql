-- Topic 4: quest rewards, including experience.
--
-- This file depends on cmp.zone_quest, created by diffs/03_quests.sql on the
-- connection before this one (files run in glob order, 03_ before 04_).

-- Reward items, choice items, reputation, spell and money. Counts stay on
-- cmp.strength like the objective counts in 03_quests.sql - small exact
-- integers, exact match is the intended semantic.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quest_rewards', 'quest', r.quest,
       CONCAT(r.kind, ':', r.id),
       rv.cnt, rmz.cnt, rtw.cnt, rac.cnt,
       cmp.strength(rv.cnt, rmz.cnt, rac.cnt), ''
FROM cmp.zone_quest zq
JOIN (
    SELECT quest, kind, id FROM v.n_quest_rew
    UNION SELECT quest, kind, id FROM mz.n_quest_rew
    UNION SELECT quest, kind, id FROM ac.n_quest_rew
) r ON r.quest = zq.quest
LEFT JOIN v.n_quest_rew  rv  ON rv.quest  = r.quest AND rv.kind  = r.kind AND rv.id  = r.id
LEFT JOIN mz.n_quest_rew rmz ON rmz.quest = r.quest AND rmz.kind = r.kind AND rmz.id = r.id
LEFT JOIN tw.n_quest_rew rtw ON rtw.quest = r.quest AND rtw.kind = r.kind AND rtw.id = r.id
LEFT JOIN ac.n_quest_rew rac ON rac.quest = r.quest AND rac.kind = r.kind AND rac.id = r.id
WHERE cmp.strength(rv.cnt, rmz.cnt, rac.cnt) <> '';

-- Experience, the figure. AzerothCore votes on the boolean only (below), so
-- it is passed as a literal NULL here: it abstains on the number and cannot
-- strengthen a finding about it.
--
-- Magnitude call site, per diffs/00_schema.sql: cmp.strength_mag, not
-- cmp.strength_num or cmp.strength. ac's argument is always NULL for this
-- field, so a bare cmp.strength_num would read "mz votes and agrees with v,
-- ac abstains" as a contentless 'weak' on every single row - exactly the
-- shape strength_mag exists to suppress - and cmp.strength (byte equality)
-- is wrong for a computed float regardless.
--
-- 5% relative tolerance, not the spec's "quest experience: any difference".
-- v stores RewXP directly; cmp.n_quest_xp reconstructs mz's figure from the
-- vanilla formula (cmp.vanilla_quest_xp) rather than reading a stored
-- number, so this is a stored value against a formula reconstruction, not
-- two stored values. Comparing that pair at "any difference" flags the
-- corpus wholesale: Task 6 measured 1427 of 1662 flagged rows rounding to
-- ratio 1.0, with only 2.3% differing by more than 15%. abs_tol is 0: the
-- smallest formula value in this corpus is 50 XP, so a relative check alone
-- already separates rounding noise from real outliers (see
-- test_vmangos_stored_xp_agrees_with_its_own_inputs in test_pipeline.py).
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quest_rewards', 'quest', zq.quest, 'xp',
       ROUND(xv.xp), ROUND(xmz.xp), ROUND(xtw.xp), NULL,
       cmp.strength_mag(xv.xp, xmz.xp, NULL, 0.05, 0),
       'AzerothCore abstains on the figure; it votes only on awards_xp'
FROM cmp.zone_quest zq
JOIN      cmp.n_quest_xp xv  ON xv.src  = 'v'  AND xv.quest  = zq.quest
LEFT JOIN cmp.n_quest_xp xmz ON xmz.src = 'mz' AND xmz.quest = zq.quest
LEFT JOIN cmp.n_quest_xp xtw ON xtw.src = 'tw' AND xtw.quest = zq.quest
WHERE cmp.strength_mag(xv.xp, xmz.xp, NULL, 0.05, 0) <> '';

-- Whether a quest awards experience at all. Every source can answer this, so
-- it stays a plain boolean vote on cmp.strength.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quest_rewards', 'quest', zq.quest, 'awards_xp',
       xv.awards_xp, xmz.awards_xp, xtw.awards_xp, xac.awards_xp,
       cmp.strength(xv.awards_xp, xmz.awards_xp, xac.awards_xp), ''
FROM cmp.zone_quest zq
JOIN      cmp.n_quest_xp xv  ON xv.src  = 'v'  AND xv.quest  = zq.quest
LEFT JOIN cmp.n_quest_xp xmz ON xmz.src = 'mz' AND xmz.quest = zq.quest
LEFT JOIN cmp.n_quest_xp xtw ON xtw.src = 'tw' AND xtw.quest = zq.quest
LEFT JOIN cmp.n_quest_xp xac ON xac.src = 'ac' AND xac.quest = zq.quest
WHERE cmp.strength(xv.awards_xp, xmz.awards_xp, xac.awards_xp) <> '';

-- Single-source finding: the stored reward contradicts the vanilla formula
-- applied to the quest's own inputs. No peer is relevant here, so strength
-- is hardcoded 'strong' rather than computed - there is nothing for
-- cmp.strength/cmp.strength_mag to judge peer agreement on.
--
-- The formula's answer goes in the note, NOT in mz_value. It used to sit in
-- the mangoszero column, so all 249 of these rows rendered an expected value
-- under a heading naming a database that never voted on them - a column
-- whose content is not what its header says, the same defect shape as the
-- six Task 12 fixed. Every peer column is NULL here on purpose: all three
-- peers really did abstain, and report.py renders a NULL as a blank cell
-- meaning exactly that.
--
-- The WHERE predicate is the same relative-tolerance check
-- test_vmangos_stored_xp_agrees_with_its_own_inputs asserts (5%, no absolute
-- floor), not the plan's ABS(...) > 1 - that absolute tolerance was the one
-- Task 6's fix round removed, because it made almost the whole level 1-50
-- band "disagree" on rounding noise alone (2213 quests average 5-15 XP off
-- a formula answer in the hundreds). Restricted to levels 1-50:
-- cmp.vanilla_quest_xp's /0.6 branch does not model the real, smooth
-- level-51-60 XP taper, so nearly all ~1098 quests in that band would fail
-- this check by construction and bury the ~235 genuine outliers the 1-50
-- band actually has.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quest_rewards', 'quest', q.entry, 'xp_self_consistency',
       q.rew_xp, NULL, NULL, NULL, 'strong',
       CONCAT('stored RewXP disagrees with the vanilla formula on this quest own inputs; ',
              'the formula gives ', ROUND(cmp.vanilla_quest_xp(q.lvl, q.rew_money_max_level)))
FROM cmp.zone_quest zq
JOIN v.n_quest q ON q.entry = zq.quest
WHERE q.rew_xp > 0 AND q.rew_money_max_level > 0
  AND q.lvl BETWEEN 1 AND 50
  AND ABS(q.rew_xp - cmp.vanilla_quest_xp(q.lvl, q.rew_money_max_level))
      / cmp.vanilla_quest_xp(q.lvl, q.rew_money_max_level) > 0.05;
