DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260906102115');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260906102115');
-- Add your query below.

-- Upstream corrected two migrations that this database had already run, and a correction to
-- the file cannot undo what the old file did here. Both changes are applied by hand below.

-- 20260731074614 gave every Jadefire Run spawn a fixed 300 second respawn. The corrected
-- file spreads them between 300 and 480 seconds, and gives Xavaric a far longer
-- window than the trash around him.
UPDATE `creature` SET `spawntimesecsmax`=480 WHERE `guid` BETWEEN 17221 AND 17259 AND `id` IN (7107, 7111);
UPDATE `creature` SET `spawntimesecsmin`=720, `spawntimesecsmax`=960 WHERE `guid`=17260 AND `id`=10648;

-- 20260901065601 deleted the event lists of Lanie Reed and Omusa Thunderhorn along with the
-- ones it meant to remove. Both summon guardians when attacked and both lost that; the
-- follow-up migration here only silenced the resulting "EventMap for Creature is empty"
-- warning by clearing ai_name, because at the time the deletion looked deliberate. Put the
-- events, their actions and the AI name back. Delete first so the migration is safe on a
-- database that never lost them.
DELETE FROM `creature_ai_events` WHERE `creature_id` IN (2941, 10378);
DELETE FROM `creature_ai_scripts` WHERE `id` IN (294101, 1037801);

INSERT INTO `creature_ai_events` (`id`, `creature_id`, `condition_id`, `event_type`, `event_inverse_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action1_script`, `action2_script`, `action3_script`, `comment`) VALUES
(294101, 2941, 0, 4, 0, 100, 0, 0, 0, 0, 0, 294101, 0, 0, 'Lanie Reed - Summon Enraged Gryphons on Aggro'),
(1037801, 10378, 0, 4, 0, 100, 0, 0, 0, 0, 0, 1037801, 0, 0, 'Omusa Thunderhorn - Summon Enraged Wyverns on Aggro');

INSERT INTO `creature_ai_scripts` (`id`, `delay`, `priority`, `command`, `datalong`, `datalong2`, `datalong3`, `datalong4`, `target_param1`, `target_param2`, `target_type`, `data_flags`, `dataint`, `dataint2`, `dataint3`, `dataint4`, `x`, `y`, `z`, `o`, `condition_id`, `comments`) VALUES
(294101, 0, 0, 10, 9526, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 4, 0, 0, 0, 0, 0, 'Lanie Reed - Summon Creature Enraged Gryphon'),
(294101, 0, 0, 10, 9526, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 4, 0, 0, 0, 0, 0, 'Lanie Reed - Summon Creature Enraged Gryphon'),
(294101, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4568, 0, 0, 0, 0, 0, 0, 0, 0, 'Lanie Reed - Say Text'),
(1037801, 0, 0, 10, 9297, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 4, 0, 0, 0, 0, 0, 'Omusa Thunderhorn - Summon Creature Enraged Wyvern'),
(1037801, 0, 0, 10, 9297, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 4, 0, 0, 0, 0, 0, 'Omusa Thunderhorn - Summon Creature Enraged Wyvern'),
(1037801, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4561, 0, 0, 0, 0, 0, 0, 0, 0, 'Omusa Thunderhorn - Say Text');

UPDATE `creature_template` SET `ai_name`='EventAI' WHERE `entry`=2941 AND `patch`=3;
UPDATE `creature_template` SET `ai_name`='EventAI' WHERE `entry`=10378 AND `patch`=4;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
