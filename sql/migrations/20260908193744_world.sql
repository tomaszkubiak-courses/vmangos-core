DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260908193744');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260908193744');
-- Add your query below.

-- The three Thunderbrew Lager Kegs behind the Grim Guzzler stood in a triangle
-- roughly 1.6 yards on a side, so the barrels overlapped each other. Two of them
-- (43097 and 43098) were already a clean pair, spaced 1.61 yards apart along the
-- wall, square to the direction they face; the third sat 1.5 yards out in front of
-- that pair and slightly between them.
--
-- Put all three on the line the pair defines, evenly spaced at the same 1.61 yards
-- and centred on where the group already was, so the row does not grow into the
-- room in either direction. 43098 gives up its differing facing and takes the one
-- the other two share.
UPDATE `gameobject` SET `position_x` = 914.0072, `position_y` = -146.2743, `position_z` = -49.7569,
                        `orientation` = 3.64774, `rotation2` = -0.968147, `rotation3` = 0.250381
    WHERE `guid` = 43098 AND `id` = 164911;
UPDATE `gameobject` SET `position_x` = 914.7875, `position_y` = -147.6820, `position_z` = -49.7569
    WHERE `guid` = 43099 AND `id` = 164911;
UPDATE `gameobject` SET `position_x` = 915.5678, `position_y` = -149.0897, `position_z` = -49.7569
    WHERE `guid` = 43097 AND `id` = 164911;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
