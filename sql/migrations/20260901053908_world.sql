DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260901053908');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260901053908');
-- Add your query below.

-- Hive'Zora Wasp (11727) toggles between two combat phases: it stacks a poison in
-- phase 1, moves to phase 2 once the target carries ten stacks, and drops back to
-- phase 1 when the stacks fall away. Its creature_ai_events rows say exactly that -
-- "Set Phase 1 on Aggro", "Set Phase 2 on Target Max Poison Aura Stack", "Set Phase
-- to 0 on Evade" - and their inverse phase masks only ever select phases 0, 1 and 2.
--
-- The scripts behind them do not set a phase, they add to it. The three combat ones
-- use SCRIPT_COMMAND_SET_PHASE in SO_SETPHASE_INCREMENT mode, so aggro adds one and
-- the poison toggle adds two and one more each way round. The evade one is worse than
-- wrong: it decrements by zero, which leaves the phase exactly where it was, so
-- nothing ever takes any of it back. The phase only climbs. Once it passes 31 the
-- command refuses to run at all:
--
--   SCRIPT_COMMAND_SET_PHASE (script id 1172703) attempt to increment Phase above 31.
--   Phase mask cannot be used with phases past 31. CreatureEntry = 11727
--
-- sixteen of those in two minutes of one run, after which the wasp is stuck in
-- whatever phase it reached and its poison event no longer matches.
--
-- Set the phases outright (SO_SETPHASE_RAW, datalong2 = 0) so the toggle is a toggle.
-- Each statement is guarded on the values it is replacing, so a database that already
-- carries the corrected rows is left alone.

UPDATE `creature_ai_scripts` SET `datalong` = 1, `datalong2` = 0, `comments` = 'Hive\'Zora Wasp - Set Phase 1'
WHERE `id` = 1172701 AND `command` = 44 AND `datalong` = 1 AND `datalong2` = 1;

UPDATE `creature_ai_scripts` SET `datalong` = 2, `datalong2` = 0, `comments` = 'Hive\'Zora Wasp - Set Phase 2'
WHERE `id` = 1172703 AND `command` = 44 AND `datalong` = 2 AND `datalong2` = 1;

UPDATE `creature_ai_scripts` SET `datalong` = 1, `datalong2` = 0, `comments` = 'Hive\'Zora Wasp - Set Phase 1'
WHERE `id` = 1172704 AND `command` = 44 AND `datalong` = 1 AND `datalong2` = 1;

UPDATE `creature_ai_scripts` SET `datalong` = 0, `datalong2` = 0, `comments` = 'Hive\'Zora Wasp - Set Phase 0'
WHERE `id` = 1172705 AND `command` = 44 AND `datalong` = 0 AND `datalong2` = 2;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
