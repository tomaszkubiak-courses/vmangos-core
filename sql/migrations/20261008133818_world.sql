DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20261008133818');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20261008133818');
-- Add your query below.
-- Horde Laborer: the emote script turns to and emotes at four other laborers by guid. They
-- can be dead and waiting to respawn, which logged FindScriptTargets errors; skip them quietly.
UPDATE `generic_scripts` SET `data_flags` = `data_flags` | 16 WHERE `id` = 1471803 AND `target_type` = 11;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
