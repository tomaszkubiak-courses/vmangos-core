DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260902194737');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260902194737');
-- Add your query below.

-- CreatureEventAI logs "EventMap for Creature %u is empty but creature is using
-- CreatureEventAI" every time one of these spawns. Migration 20260901065601 removed the
-- event lists of Lanie Reed and Omusa Thunderhorn but only cleared ai_name on their patch 0
-- rows, and creature_template is keyed on (entry, patch), so the higher patch rows this
-- realm actually loads kept pointing at an AI with nothing left to run. Corrupted Saber has
-- been in the same state for longer - it is never spawned from the creature table, only
-- swapped in over Common Kitten, so it only shows up in the log occasionally.
UPDATE `creature_template` SET `ai_name`='' WHERE `entry`=2941 AND `patch`=3;
UPDATE `creature_template` SET `ai_name`='' WHERE `entry`=10042 AND `patch`=0;
UPDATE `creature_template` SET `ai_name`='' WHERE `entry`=10378 AND `patch`=4;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
