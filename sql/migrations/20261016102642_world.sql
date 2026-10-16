DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20261016102642');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20261016102642');
-- Add your query below.
-- The Heart of Hakkar: migration 20220821213227 moved the eight Heart of Hakkar Spell
-- Emitters from guid 100001-100008 to 600001-600008, but rewrote only target_param1 in
-- quest_end_scripts. The respawn commands keep their guid in datalong, so they still
-- named 100001-100008, which are now Felwood mining nodes, and the emitters never appeared.
UPDATE `quest_end_scripts` SET `datalong`=`datalong`+500000 WHERE `id`=8183 AND `command`=9 AND `datalong` BETWEEN 100001 AND 100008;


-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
