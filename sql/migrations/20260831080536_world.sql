DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260831080536');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260831080536');
-- Add your query below.

-- Battleground start announcement variant that carries the player count each side
-- started with. Used when Battleground.QueueAnnouncer.Start is 2; entry 717 is the
-- existing text without the counts.
REPLACE INTO `mangos_string` (`entry`, `content_default`) VALUES
(11020, '|cffff0000[BG Queue Announcer]:|r %s -- [%u-%u] Started! %u Alliance vs %u Horde|r');

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
