DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20261016102715');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20261016102715');
-- Add your query below.
-- Seer Wiserunner: the line of sight greeting fires for any non-hostile unit, but its
-- condition 772 (quest Rite of Vision taken) can only be checked on a player, so every
-- Mulgore Protector walking past logged "CONDITION 772 type 9 used with bad parameters".
-- Check that the target is a player (condition 85) before the quest.
DELETE FROM `conditions` WHERE `condition_entry`=298402;
INSERT INTO `conditions` (`condition_entry`, `type`, `value1`, `value2`, `value3`, `value4`, `flags`) VALUES (298402, -1, 85, 772, 0, 0, 0);
UPDATE `creature_ai_events` SET `condition_id`=298402 WHERE `id`=298402 AND `creature_id`=2984;


-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
