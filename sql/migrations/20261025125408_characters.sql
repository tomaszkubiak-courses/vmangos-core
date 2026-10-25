DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20261025125408');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20261025125408');
-- Add your query below.

-- Companion to 20261025125310_world: drop the quests that migration restricts to one
-- faction from the logs of characters of the other faction, who took them before the race
-- mask existed and can never turn them in. Completed quests are left alone.

-- Alliance quests held by Horde characters
DELETE `qs` FROM `character_queststatus` `qs` JOIN `characters` `c` ON `c`.`guid` = `qs`.`guid`
WHERE `qs`.`rewarded` = 0 AND `c`.`race` IN (2, 5, 6, 8) AND `qs`.`quest` IN (45, 68, 71, 74, 169, 180, 199, 225, 230, 248, 249, 256, 283, 284, 285, 286, 292, 311, 324, 328, 329, 417, 474, 510, 511, 632, 684, 685, 720, 739, 779, 930, 931, 1055, 1288, 1455, 1465, 1649, 2867, 2940, 2942, 3368, 4127, 4135, 4264, 4265, 4281, 4722, 4723, 4725, 4727, 4728, 4730, 4731, 4732, 4733, 4863, 4864, 5217, 5220, 5223, 5226, 5841, 6389, 6661, 6662, 7495, 7735, 7781, 8778, 8780, 8781);

-- Horde quests held by Alliance characters
DELETE `qs` FROM `character_queststatus` `qs` JOIN `characters` `c` ON `c`.`guid` = `qs`.`guid`
WHERE `qs`.`rewarded` = 0 AND `c`.`race` IN (1, 3, 4, 7) AND `qs`.`quest` IN (100, 398, 410, 431, 439, 549, 566, 567, 585, 586, 588, 654, 795, 926, 1239, 1261, 1527, 1918, 2782, 2903, 2933, 2978, 3482, 3513, 4081, 4082, 4561, 4661, 4881, 4882, 4903, 5230, 5232, 5234, 5236, 6390, 6522, 6564, 7490, 7738, 7783, 7861, 7862, 8409, 8785, 8786, 8787);

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
