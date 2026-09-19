DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260919220257');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260919220257');
-- Add your query below.
-- Quest 2986 "Call of Water" could be accepted and never handed in.
--
-- The level-20 shaman water totem quest exists in four parallel variants -
-- 1528, 1529, 2985 and 2986 - one per trainer who starts it, all of them
-- ending at Islen Waterseer (5901) and all chaining onward into 1530. This
-- database has her ender row for three of the four and is missing it for
-- 2986, whose giver (Narm Skychaser, 3066) hands it out regardless. A shaman
-- who takes it from him has nowhere to return it, and 1530 and the rest of
-- the chain behind it stay unreachable.
--
-- Both comparison databases carry the row, and the three sibling variants
-- here already agree on the same ender, so this is a dropped row rather than
-- a deliberate difference.
-- INSERT IGNORE, not a plain INSERT: (id, quest) is the primary key, so this
-- is a no-op if the row is ever added by a world DB update before the
-- migration runs.
INSERT IGNORE INTO `creature_involvedrelation` (`id`, `quest`, `patch_min`, `patch_max`)
VALUES (5901, 2986, 0, 10);

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
