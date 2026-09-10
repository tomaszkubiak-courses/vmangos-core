DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260910101818');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260910101818');
-- Add your query below.

-- Gammerita, the rare crab in Dustwallow Marsh, was sharing the model of the
-- ordinary Surf Glider (7114) that spawns around her, so she looked like just
-- another crab. Retail gives her the larger crab model 5127 - the one the Giant
-- Surf Glider uses - which is also what she has in every other core's data.
UPDATE `creature_template` SET `display_id1` = 5127 WHERE `entry` = 7977 AND `display_id1` = 7114;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
