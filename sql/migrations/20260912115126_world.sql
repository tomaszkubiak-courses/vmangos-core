DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260912115126');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260912115126');
-- Add your query below.

-- Flik's Frog (14866) follows Flik (14860) around the Darkmoon Faire since the
-- creature_linking_template entry added in 20260911215241. The second step of Flik's
-- talk script plays the frog's croak on the nearest 14866 within ten yards, a radius
-- that suited a frog standing on his spawn point but not one walking behind him: a
-- follower drops back whenever it has to path around the faire's tents and stalls, and
-- with Flik never pausing on his 58 point patrol it can be more than ten yards behind
-- when the next talk comes round. Over a thirteen hour run eighteen of his croaks were
-- lost that way:
--   FindScriptTargets: Failed to find target for script with id 1486001
--   (target_param1: 14866), (target_param2: 10), (target_type: 10)
-- Thirty yards covers the lag and is the radius Donna's own script already uses. Both
-- frogs are on separate maps, so a wider search cannot pick up the wrong one.
UPDATE `generic_scripts` SET `target_param2`=30 WHERE `id`=1486001 AND `command`=16 AND `target_param1`=14866;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
