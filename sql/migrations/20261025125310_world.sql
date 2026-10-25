DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20261025125310');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20261025125310');
-- Add your query below.

-- Quests started from a gameobject or an item have no quest giver whose faction keeps the
-- other side away, so the race mask is the only gate, and these carried none. A Horde
-- character could take Foreboding Plans from the Syndicate Documents in Alterac and was
-- then sent to Magistrate Maleb in Southshore to turn it in. Masks from the retail data,
-- reduced to the vanilla races.

-- Alliance
UPDATE `quest_template` SET `RequiredRaces` = 77 WHERE `RequiredRaces` = 0 AND `entry` IN (45, 68, 71, 74, 169, 180, 199, 225, 230, 248, 249, 256, 283, 284, 285, 286, 292, 311, 324, 328, 329, 417, 474, 510, 511, 632, 684, 685, 720, 739, 779, 930, 931, 1055, 1288, 1455, 1465, 1649, 2867, 2940, 2942, 3368, 4127, 4135, 4264, 4265, 4281, 4722, 4723, 4725, 4727, 4728, 4730, 4731, 4732, 4733, 4863, 4864, 5217, 5220, 5223, 5226, 5841, 6389, 6661, 6662, 7495, 7735, 7781, 8778, 8780, 8781);

-- Horde
UPDATE `quest_template` SET `RequiredRaces` = 178 WHERE `RequiredRaces` = 0 AND `entry` IN (100, 398, 410, 431, 439, 549, 566, 567, 585, 586, 588, 654, 795, 926, 1239, 1261, 1527, 1918, 2782, 2903, 2933, 2978, 3482, 3513, 4081, 4082, 4561, 4661, 4881, 4882, 4903, 5230, 5232, 5234, 5236, 6390, 6522, 6564, 7490, 7738, 7783, 7861, 7862, 8409, 8785, 8786, 8787);

-- Welcome! (the starting gift letters), one race each
UPDATE `quest_template` SET `RequiredRaces` = 1 WHERE `RequiredRaces` = 0 AND `entry` = 5805;
UPDATE `quest_template` SET `RequiredRaces` = 8 WHERE `RequiredRaces` = 0 AND `entry` = 5842;
UPDATE `quest_template` SET `RequiredRaces` = 130 WHERE `RequiredRaces` = 0 AND `entry` = 5843;
UPDATE `quest_template` SET `RequiredRaces` = 32 WHERE `RequiredRaces` = 0 AND `entry` = 5844;
UPDATE `quest_template` SET `RequiredRaces` = 16 WHERE `RequiredRaces` = 0 AND `entry` = 5847;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
