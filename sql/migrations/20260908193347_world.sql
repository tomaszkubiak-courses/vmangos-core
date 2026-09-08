DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260908193347');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260908193347');
-- Add your query below.

-- Blood of Heroes (chest 176213) links trap 176214, which casts Call of the Hero
-- and summons an elite Fallen Hero. 26 of the 114 chest spawns had no trap beside
-- them, so those chests opened silently. The trap is looked up within the range of
-- the trap spell (5 yards), and every paired trap sits on the exact coordinates of
-- its chest, so give the unpaired chests a trap copied from their own placement.
INSERT INTO `gameobject` (`id`, `map`, `position_x`, `position_y`, `position_z`, `orientation`,
                          `rotation0`, `rotation1`, `rotation2`, `rotation3`,
                          `spawntimesecsmin`, `spawntimesecsmax`, `animprogress`, `state`,
                          `spawn_flags`, `visibility_mod`, `patch_min`, `patch_max`)
SELECT 176214, `c`.`map`, `c`.`position_x`, `c`.`position_y`, `c`.`position_z`, `c`.`orientation`,
       `c`.`rotation0`, `c`.`rotation1`, `c`.`rotation2`, `c`.`rotation3`,
       `c`.`spawntimesecsmin`, `c`.`spawntimesecsmax`, `c`.`animprogress`, `c`.`state`,
       `c`.`spawn_flags`, `c`.`visibility_mod`, `c`.`patch_min`, `c`.`patch_max`
FROM `gameobject` `c`
WHERE `c`.`id` = 176213
  AND NOT EXISTS (SELECT 1 FROM `gameobject` `t`
                  WHERE `t`.`id` = 176214 AND `t`.`map` = `c`.`map`
                    AND POW(`t`.`position_x` - `c`.`position_x`, 2)
                      + POW(`t`.`position_y` - `c`.`position_y`, 2)
                      + POW(`t`.`position_z` - `c`.`position_z`, 2) <= 25);

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
