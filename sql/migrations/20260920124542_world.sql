DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260920124542');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260920124542');
-- Add your query below.

-- The Horde half of the Ahn'Qiraj war effort dust turn-in has no spawn, so
-- "Scouring the Desert" (9422) cannot be completed by a Horde character.
--
-- Both faction versions of that quest are completed by walking up to a
-- marker creature rather than an npc: the Alliance quest 9419 wants
-- creature 17090 "Silithus Dust Turnin Quest Doodad", the Horde quest 9422
-- wants 18199 "Silithus Dust Turnin Quest Doodad Horde". This database has
-- a creature_template row for both and a spawn for only the Alliance one,
-- so the Alliance quest works and the Horde one has no target anywhere in
-- the world. Both comparison databases spawn both markers, at the same
-- coordinates and even under the same guids this database already uses for
-- the Alliance marker, which is what makes the missing row unambiguous
-- rather than a design choice.
--
-- The row mirrors the Alliance marker's own spawn exactly - 300 second
-- respawn, no wander, patch 10 only, same map - and takes the guid both
-- other databases use for it, which is free here.

INSERT IGNORE INTO `creature`
    (`guid`, `id`, `map`, `position_x`, `position_y`, `position_z`, `orientation`,
     `spawntimesecsmin`, `spawntimesecsmax`, `wander_distance`, `health_percent`,
     `mana_percent`, `movement_type`, `spawn_flags`, `patch_min`, `patch_max`)
VALUES
    (42745, 18199, 1, -7568.77, 763.379, -17.5984, 5.91667, 300, 300, 0, 100, 0, 0, 0, 10, 10);

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
