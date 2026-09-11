DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260911215241');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260911215241');
-- Add your query below.

-- Flik's Frog (14866) never moved with Flik (14860). Flik patrols the Darkmoon Faire
-- on a 45 to 58 point path; the frog was spawned on top of him with movement_type 0
-- and stayed at the spawn point. Flik's own EventAI (1486001) talks every 30-45s and
-- its second step plays the frog's croak on the nearest 14866 within 10 yards, so
-- once he had walked away every one of those steps failed:
--   FindScriptTargets: Failed to find target for script with id 1486001
--   (target_param1: 14866), (target_param2: 10), (target_type: 10)
-- The frog is meant to hop along beside him.

-- Offset the frog 1.5 yards behind Flik. The follow distance and angle are derived
-- from the difference between the two spawn points (CreatureLinkingHolder::SetFollowing),
-- so sharing his coordinates exactly would have the frog follow at zero distance,
-- standing inside him.
UPDATE `creature` SET `position_x`=-1543.7059, `position_y`=172.0778 WHERE `guid`=54426 AND `id`=14866;
UPDATE `creature` SET `position_x`=-9581.6615, `position_y`=36.0248 WHERE `guid`=56624 AND `id`=14866;

-- flag 512 = FLAG_FOLLOW. search_range 0 means the master is resolved as the single
-- 14860 spawn on that map, which is what both faire maps have.
DELETE FROM `creature_linking_template` WHERE `entry`=14866;
INSERT INTO `creature_linking_template` (`entry`, `map`, `master_entry`, `flag`, `search_range`) VALUES
(14866, 0, 14860, 512, 0),
(14866, 1, 14860, 512, 0);

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
