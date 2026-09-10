DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260910101849');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260910101849');
-- Add your query below.

-- Essence of the Elements (11129) is the quest item for The Last Element, which
-- asks for ten of them. The right twelve creatures dropped it, but at quest drop
-- chances between 0.5% and 4%, so ten of them was hundreds of kills rather than
-- the handful the quest is built around.
--
-- Retail drops it at 80% from every creature on the list and at 100% from Scald,
-- which is what both the sniffed WotLK loot and the MaNGOS Zero vanilla database
-- carry. The stack sizes here already match those sources; only the chance was
-- wrong.
UPDATE `creature_loot_template` SET `ChanceOrQuestChance` = -100
    WHERE `item` = 11129 AND `entry` = 8281;
UPDATE `creature_loot_template` SET `ChanceOrQuestChance` = -80
    WHERE `item` = 11129 AND `entry` IN (8905, 8906, 8908, 8909, 8910, 8911, 8923, 9017, 9025, 9026, 9156);

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
