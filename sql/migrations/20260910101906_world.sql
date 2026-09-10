DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260910101906');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260910101906');
-- Add your query below.

-- Migration 20260908193744 put the three Thunderbrew Lager Kegs behind the Grim
-- Guzzler bar on a straight line, but it derived the spacing from the pair that
-- already stood there - 1.61 yards - and the barrels still overlap at that
-- distance. It also gave all three the same facing.
--
-- The sniffed retail positions have them 3.8 and 4.3 yards apart along the bar,
-- each turned slightly further out than the one before it. Use those instead of
-- a spacing guessed from the broken layout. The rotation quaternion is written
-- in the same sign convention the rest of this table uses (q and -q describe the
-- same rotation), so it stays comparable with the neighbouring rows.
UPDATE `gameobject` SET `position_x` = 914.763, `position_y` = -146.862, `position_z` = -49.7579,
                        `orientation` = 3.64769, `rotation2` = -0.968154, `rotation3` = 0.250357
    WHERE `guid` = 43098 AND `id` = 164911;
UPDATE `gameobject` SET `position_x` = 916.727, `position_y` = -150.147, `position_z` = -49.7584,
                        `orientation` = 3.70111, `rotation2` = -0.961122, `rotation3` = 0.276124
    WHERE `guid` = 43099 AND `id` = 164911;
UPDATE `gameobject` SET `position_x` = 918.736, `position_y` = -153.958, `position_z` = -49.7580,
                        `orientation` = 3.71367, `rotation2` = -0.959369, `rotation3` = 0.282154
    WHERE `guid` = 43097 AND `id` = 164911;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
