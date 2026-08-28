DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260828065450');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260828065450');
-- Add your query below.

-- Silence two script target lookups that fail as a matter of course.
--
-- The Diseased Wolf and the Mistwing Ravager cast through a creature_ai_scripts action
-- with target_type 4 (TARGET_T_HOSTILE_RANDOM). When the event fires but the threat list
-- has already emptied - the victim died, or the creature evaded - there is no random
-- hostile to pick and the lookup fails, which logs an ERROR line per attempt. The script
-- is skipped either way; SF_GENERAL_SKIP_MISSING_TARGETS (0x10) only stops the logging.
UPDATE `creature_ai_scripts` SET `data_flags` = `data_flags` | 0x10 WHERE `id` IN (876401, 181701) AND `command` = 15 AND `target_type` = 4;

-- The Southshore Crier's movement script starts a script for all nearby creatures after a
-- two second delay, guarded by conditions 2434 and 2435 (CONDITION_NEARBY_CREATURE, which
-- needs a WorldObject target). The rows carry SF_GENERAL_TARGET_SELF, so the target is the
-- crier itself; if the crier is gone by the time the queued action runs, the condition is
-- evaluated against a null target and reports bad parameters. Skipping the action when its
-- source no longer exists gives the same outcome without the DB error.
UPDATE `creature_movement_scripts` SET `data_flags` = `data_flags` | 0x10 WHERE `id` = 243501 AND `command` = 68 AND `condition_id` IN (2434, 2435);

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
