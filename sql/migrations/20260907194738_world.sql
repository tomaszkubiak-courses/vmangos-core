DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260907194738');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260907194738');
-- Add your query below.

-- Clear the loot id on gameobject templates whose `gameobject_loot_template`
-- entry does not exist. All thirteen are unspawned: two Blizzard test objects
-- ("I Should not be here B", "TEST MHeiberg Chest"), ten dead duplicates of
-- Food Crate (the eleven Food Crates that are actually spawned all have loot),
-- and an unspawned Metal Casing. No player can open any of them, so inventing
-- loot for them would be inventing content; drop the dangling reference instead.
UPDATE `gameobject_template` SET `data1` = 0 WHERE `entry` IN (252, 3692, 3696, 3697, 3698, 3699, 3701, 3708, 3709, 3712, 3713, 177865, 180618) AND `type` = 3 AND `data1` IN (753, 2573, 2594, 2595, 2596, 2597, 2599, 9937, 9943, 9946, 9952, 14733, 17461);

-- "Suzi Test Object 1" is an unspawned door whose linked-trap field points at a
-- spell focus rather than a trap. CheckGOLinkedTrapId only warns about it.
UPDATE `gameobject_template` SET `data3` = 0 WHERE `entry` = 148500 AND `type` = 1 AND `data3` = 148501;

-- These two rows repeat the proc flags already in spell.dbc. The proc handler
-- falls back to the dbc value whenever the column is zero, so clearing it is
-- behaviourally identical; the rows stay for their school mask and procEx.
UPDATE `spell_proc_event` SET `procFlags` = 0 WHERE `entry` = 6346 AND `procFlags` = 139264;
UPDATE `spell_proc_event` SET `procFlags` = 0 WHERE `entry` = 11119 AND `procFlags` = 65536;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
