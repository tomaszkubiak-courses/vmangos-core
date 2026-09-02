DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260902185414');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260902185414');
-- Add your query below.

-- Tuten'kash never marked his encounter as done, so instance_razorfen_downs kept
-- m_auiEncounter[0] at NOT_STARTED forever and the gong stayed interactive on every
-- later visit to a saved instance. Set the encounter from his death, the way the tomb
-- creatures already bump the gong wave counter.
UPDATE `creature_template` SET `ai_name`='EventAI' WHERE `entry`=7355;

DELETE FROM `creature_ai_events` WHERE `id`=735501;
INSERT INTO `creature_ai_events` (`id`, `creature_id`, `condition_id`, `event_type`, `event_inverse_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action1_script`, `action2_script`, `action3_script`, `comment`) VALUES
(735501, 7355, 0, 6, 0, 100, 0, 0, 0, 0, 0, 735501, 0, 0, 'Tuten''kash - Set Data on Death');

DELETE FROM `creature_ai_scripts` WHERE `id`=735501;
INSERT INTO `creature_ai_scripts` (`id`, `delay`, `priority`, `command`, `datalong`, `datalong2`, `datalong3`, `datalong4`, `target_param1`, `target_param2`, `target_type`, `data_flags`, `dataint`, `dataint2`, `dataint3`, `dataint4`, `x`, `y`, `z`, `o`, `condition_id`, `comments`) VALUES
(735501, 0, 0, 37, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Tuten''kash - Set Data');

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
