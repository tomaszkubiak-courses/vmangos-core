-- Topic 2: connected creatures. Trainer relations, plus three per-target
-- relationship families and the (post-Task-9-Step-0) link family.
--
-- This file depends on cmp.zone_creature, created by diffs/01_creatures.sql
-- on the connection before this one (files run in glob order, 01_ before
-- 02_, each on its own connection). Zone placement is taken from there
-- rather than from a separate v+mz spawn query, so this topic and topic 1
-- never disagree about where a creature is.
--
-- A source with no rows at all of a given kind is abstaining, not
-- reporting absence: AzerothCore has no creature_linking equivalent, so it
-- must not vote on links. cmp.rel_kinds_present and the kmz/ktw/kac joins
-- below are what enforce that for the per-target kinds.

CREATE OR REPLACE VIEW cmp.rel_kinds_present AS
SELECT 'v'  AS src, kind FROM v.n_rel  GROUP BY kind
UNION ALL SELECT 'mz', kind FROM mz.n_rel GROUP BY kind
UNION ALL SELECT 'tw', kind FROM tw.n_rel GROUP BY kind
UNION ALL SELECT 'ac', kind FROM ac.n_rel GROUP BY kind;

-- (a) Trainer relations, one finding per trainer NPC rather than per spell.
-- Under the plan's original per-spell shape this kind alone produced 28446
-- of 35651 relation findings (80%) on this corpus, restating one fact - v
-- has far fewer, shorter trainer lists than mz/tw/ac - tens of thousands of
-- times and burying every other relation finding in the report (Task 4
-- already judged the size gap a genuine content difference, not a bug).
--
-- ac abstains on trainer entirely (Task 9 fix round 2, item 1; see the
-- comment on views/ac.sql's n_rel): its real trainer data lives in tables
-- this pipeline does not read, and the legacy npc_trainer stub it read
-- before cannot corroborate a vanilla spell count. That abstention needs
-- no gating here - ac.n_rel simply has no 'trainer' rows any more, so the
-- 'ac' branch of cmp.trainer_spell_count below is always empty and tac.n
-- arrives NULL through the ordinary LEFT JOIN, the same as any other
-- missing (src, npc) pair. v, mz and tw all still have trainer rows (v
-- 4676, mz 27324, tw 38038) and vote as before.
--
-- An absent (src, npc) pair is still a real, informative zero for v (see
-- the mandatory COALESCE(tv.n, 0) below), because we know the realm under
-- audit's full NPC set. It is NOT safe to coalesce for the peers: two
-- peers independently having no trainer row for the same npc is not the
-- same thing as two peers agreeing the npc teaches 0 spells, and
-- COALESCE(...,0) on both would make that non-agreement read as
-- corroboration - the same fabricated-'strong' shape fixed for
-- spawn_count in diffs/06_spawns.sql (fix round 1). The peer arguments
-- below stay NULL when absent.
CREATE OR REPLACE VIEW cmp.trainer_spell_count AS
SELECT 'v'  AS src, npc, COUNT(*) AS n FROM v.n_rel  WHERE kind = 'trainer' GROUP BY npc
UNION ALL SELECT 'mz', npc, COUNT(*) FROM mz.n_rel WHERE kind = 'trainer' GROUP BY npc
UNION ALL SELECT 'tw', npc, COUNT(*) FROM tw.n_rel WHERE kind = 'trainer' GROUP BY npc
UNION ALL SELECT 'ac', npc, COUNT(*) FROM ac.n_rel WHERE kind = 'trainer' GROUP BY npc;

CREATE OR REPLACE VIEW cmp.trainer_npc AS
SELECT DISTINCT npc FROM v.n_rel  WHERE kind = 'trainer'
UNION SELECT DISTINCT npc FROM mz.n_rel WHERE kind = 'trainer'
UNION SELECT DISTINCT npc FROM tw.n_rel WHERE kind = 'trainer'
UNION SELECT DISTINCT npc FROM ac.n_rel WHERE kind = 'trainer';

-- strength_mag, not strength_num: trainer_spell_count is a magnitude topic
-- (fix round 2, item 2) - now that ac abstains on trainer entirely (item
-- 1), tac.n is NULL for every row, and a bare cmp.strength_num would write
-- a contentless 'weak' every time mz alone votes and agrees with v.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT z.zone, 'relations', 'creature', tn.npc, 'trainer_spell_count',
       COALESCE(tv.n, 0), tmz.n, ttw.n, tac.n,
       cmp.strength_mag(COALESCE(tv.n, 0), tmz.n, tac.n, 0.50, 5),
       ''
FROM cmp.trainer_npc tn
JOIN cmp.zone_creature z ON z.entry = tn.npc
LEFT JOIN cmp.trainer_spell_count tv  ON tv.src  = 'v'  AND tv.npc  = tn.npc
LEFT JOIN cmp.trainer_spell_count tmz ON tmz.src = 'mz' AND tmz.npc = tn.npc
LEFT JOIN cmp.trainer_spell_count ttw ON ttw.src = 'tw' AND ttw.npc = tn.npc
LEFT JOIN cmp.trainer_spell_count tac ON tac.src = 'ac' AND tac.npc = tn.npc
WHERE cmp.strength_mag(COALESCE(tv.n, 0), tmz.n, tac.n, 0.50, 5) <> '';

-- (b) vendor, questgiver, questender and link stay per-target: a specific
-- missing vendor item or quest giver is directly actionable, and at ~7k
-- rows (post-Step-0, with link now entry-keyed) the volume is fine.
--
-- v_value (fix round 3, item 12f): v's schema always has npc_vendor,
-- creature_queststarter, creature_involvedrelation and creature_linking, so
-- v can always state whether a creature it has sells an item, gives a
-- quest, or links to another spawn - a missing row there is a real,
-- expressible "no", not an abstention. The old CASE stored NULL for every
-- one of those real "no" answers (8286 of 12091 relation findings,
-- report.py's blank-cell caption calling every one of them something v
-- "cannot express at all"), with no distinction from the one case that
-- genuinely is an abstention: v not having the NPC (a creature_template
-- row) at all, checked with a correlated EXISTS against the raw table
-- below rather than a JOIN to v.n_creature - n_creature reads through
-- _creature_current, a GROUP BY over the whole (entry, patch)-keyed table,
-- and joining that view here (rather than probing it once per candidate
-- row against creature_template's own (entry, patch) primary key) turned
-- the query's cost estimate from 1e6 rows to 1e27 and it had to be killed
-- after 7 minutes. Existence does not depend on which patch a row belongs
-- to, so the raw table needs no patch filtering to answer it. This only
-- changes the DISPLAY column - the strength() call two lines down keeps
-- its unconditional '0' for a missing v row on purpose (per
-- diffs/00_schema.sql: an npc genuinely missing from v must still read as
-- v disagreeing with two corroborating peers, the "content missing from
-- the realm" finding this audit exists to catch), so no finding's
-- strength moves.
--
-- note (Follow-up 3, task-16 part B): a 'strong' finding here means v
-- differs from both mz and ac while mz and ac agree with each other - and
-- that agreement can point either way. v='1' with mz=ac='0' is this realm
-- carrying a relation neither peer has (985 of 1915 strong relations
-- findings on this corpus - almost never a gap, since mangoszero is a
-- leaner content set and AzerothCore is a different expansion); v='0'
-- with mz=ac='1' is the opposite, and the one the audit exists to find
-- (930 of 1915). Recorded here, not suppressed - the ruling is explicit
-- that "this realm has content the peers lack" is still worth a reader's
-- attention, just a different claim than a gap. Only stated when the
-- finding is 'strong': a 'weak' finding means the peers disagree with
-- each other too, so there is no single peer-side answer to name.
-- cmp.strength(...) is called a third time here (already appears in the
-- SELECT list and in the WHERE clause below) rather than restating its
-- inputs under a different name, so this column can never drift from the
-- verdict actually stored.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT z.zone, 'relations', 'creature', r.npc,
       CONCAT(r.kind, ':', r.target),
       CASE WHEN NOT EXISTS (SELECT 1 FROM v.creature_template ct WHERE ct.entry = r.npc) THEN NULL
            WHEN rv.npc IS NULL THEN '0' ELSE '1' END,
       CASE WHEN rmz.npc IS NULL AND kmz.kind IS NOT NULL THEN '0'
            WHEN rmz.npc IS NULL THEN NULL ELSE '1' END,
       CASE WHEN rtw.npc IS NULL AND ktw.kind IS NOT NULL THEN '0'
            WHEN rtw.npc IS NULL THEN NULL ELSE '1' END,
       CASE WHEN rac.npc IS NULL AND kac.kind IS NOT NULL THEN '0'
            WHEN rac.npc IS NULL THEN NULL ELSE '1' END,
       cmp.strength(
           CASE WHEN rv.npc IS NULL THEN '0' ELSE '1' END,
           CASE WHEN kmz.kind IS NULL THEN NULL WHEN rmz.npc IS NULL THEN '0' ELSE '1' END,
           CASE WHEN kac.kind IS NULL THEN NULL WHEN rac.npc IS NULL THEN '0' ELSE '1' END),
       CASE WHEN cmp.strength(
                     CASE WHEN rv.npc IS NULL THEN '0' ELSE '1' END,
                     CASE WHEN kmz.kind IS NULL THEN NULL WHEN rmz.npc IS NULL THEN '0' ELSE '1' END,
                     CASE WHEN kac.kind IS NULL THEN NULL WHEN rac.npc IS NULL THEN '0' ELSE '1' END) <> 'strong'
                THEN ''
            WHEN rv.npc IS NULL THEN 'this realm lacks it; both peers have it'
            ELSE 'this realm has it; neither peer does' END
FROM (
    SELECT kind, npc, target FROM v.n_rel  WHERE kind IN ('vendor', 'questgiver', 'questender', 'link')
    UNION SELECT kind, npc, target FROM mz.n_rel WHERE kind IN ('vendor', 'questgiver', 'questender', 'link')
    UNION SELECT kind, npc, target FROM tw.n_rel WHERE kind IN ('vendor', 'questgiver', 'questender', 'link')
    UNION SELECT kind, npc, target FROM ac.n_rel WHERE kind IN ('vendor', 'questgiver', 'questender', 'link')
) r
JOIN cmp.zone_creature z ON z.entry = r.npc
LEFT JOIN v.n_rel  rv  ON rv.kind  = r.kind AND rv.npc  = r.npc AND rv.target  = r.target
LEFT JOIN mz.n_rel rmz ON rmz.kind = r.kind AND rmz.npc = r.npc AND rmz.target = r.target
LEFT JOIN tw.n_rel rtw ON rtw.kind = r.kind AND rtw.npc = r.npc AND rtw.target = r.target
LEFT JOIN ac.n_rel rac ON rac.kind = r.kind AND rac.npc = r.npc AND rac.target = r.target
LEFT JOIN cmp.rel_kinds_present kmz ON kmz.src = 'mz' AND kmz.kind = r.kind
LEFT JOIN cmp.rel_kinds_present ktw ON ktw.src = 'tw' AND ktw.kind = r.kind
LEFT JOIN cmp.rel_kinds_present kac ON kac.src = 'ac' AND kac.kind = r.kind
WHERE cmp.strength(
        CASE WHEN rv.npc IS NULL THEN '0' ELSE '1' END,
        CASE WHEN kmz.kind IS NULL THEN NULL WHEN rmz.npc IS NULL THEN '0' ELSE '1' END,
        CASE WHEN kac.kind IS NULL THEN NULL WHEN rac.npc IS NULL THEN '0' ELSE '1' END) <> '';

-- (c) Vendor-flagged NPCs with no stock at all. Single-source finding: both
-- halves of the contradiction are this database's own, so no peer is needed
-- to judge it and strength is hardcoded 'strong' (the same shape as
-- xp_self_consistency in diffs/04_quest_rewards.sql). The peer columns carry
-- the peers' item counts as context only; they do not decide anything here.
--
-- creature_template.npc_flags bit 0x4 is UNIT_NPC_FLAG_VENDOR
-- (src/game/Objects/UnitDefines.h): the client shows a "Browse Goods" gossip
-- option and the core accepts CMSG_LIST_INVENTORY for that NPC. With no
-- npc_vendor row the player gets an empty vendor window - a visible defect
-- that needs no reference database to establish.
--
-- Why this exists even though topic (b) already compares vendor stock
-- item by item: a peer comparison can only speak where a peer has the NPC
-- and the item, and the audit's own vendor findings are the least
-- trustworthy block it produces (no independent vanilla reference - pfQuest,
-- the reference used for loot, is generated FROM a VMaNGOS database and so
-- shares this realm's lineage, which makes its agreement inheritance rather
-- than evidence). This check needs none of that.
--
-- The join to cmp.zone_creature is also the filter that keeps the check
-- honest: it only sees creatures that are actually spawned somewhere, which
-- drops the 16 unspawned placeholder vendors in the template table
-- ("Programmer Vendor", "[UNUSED] ...", "Eric's AAA Special Vendor") without
-- naming any of them.
--
-- Both halves are deliberately unfiltered by patch - MAX(npc_flags) over the
-- entry's revisions, and an unqualified npc_vendor probe: an NPC that
-- sells nothing at ANY patch is the case being reported, and a per-patch
-- shortage is topic (b)'s business.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT z.zone, 'relations', 'creature', ct.entry, 'vendor_flag_no_stock',
       '0',
       (SELECT COUNT(*) FROM mz.npc_vendor n WHERE n.entry = ct.entry),
       (SELECT COUNT(*) FROM tw.npc_vendor n WHERE n.entry = ct.entry),
       (SELECT COUNT(*) FROM ac.npc_vendor n WHERE n.entry = ct.entry),
       'strong',
       'flagged as a vendor by this realm own creature_template, with no npc_vendor row at any patch'
FROM (SELECT entry, MAX(npc_flags) AS npc_flags FROM v.creature_template GROUP BY entry) ct
JOIN cmp.zone_creature z ON z.entry = ct.entry
WHERE (ct.npc_flags & 4) > 0
  AND NOT EXISTS (SELECT 1 FROM v.npc_vendor nv WHERE nv.entry = ct.entry);
