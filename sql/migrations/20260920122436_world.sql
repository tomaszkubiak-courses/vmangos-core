DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260920122436');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260920122436');
-- Add your query below.

-- Nine faction-specific quests are offered with no race restriction, so a
-- player of either faction can pick up both versions of the same quest.
--
-- Each of them is handed out by a creature whose faction is 35 (friendly to
-- everyone), so nothing else stops the wrong faction taking it: the giver's
-- own hostility is what covers the ordinary faction-specific quest, and
-- these have none. Five are same-titled Alliance/Horde pairs from the SAME
-- neutral giver - "Fire Plume Forged" (5801/5802) from Krinkle Goodsteel,
-- "You're a Mean One..." (6983/7043) from the Strange Snowman, and the
-- Winter Veil pairs "Metzen the Reindeer" (8746/8762) and "The Hero of the
-- Day" (8763/8799) from Kaymard Copperpinch and Wulmort Jinglepocket. A
-- quest that exists in an Alliance version and a Horde version of the same
-- name, from the same neutral npc, is race-gated by construction: without
-- the gate a single character can complete both and take both rewards.
-- Bijou's Belongings (4982) is the Horde half of the Blackrock Depths
-- prison chain, whose Alliance half runs through Marshal Windsor.
--
-- The masks are the vanilla race masks: 77 is Alliance (human, dwarf,
-- night elf, gnome), 178 is Horde (orc, tauren, troll, undead). Both
-- mangoszero and AzerothCore carry exactly these values for all nine, which
-- is how the gap was found; this database and the addon databases generated
-- from it carry 0.
--
-- Every patch revision of each quest is updated: the missing gate is not a
-- patch difference, the column is 0 on all of them.

UPDATE `quest_template` SET `RequiredRaces` = 77  WHERE `entry` IN (5801, 7043, 8762, 8763);
UPDATE `quest_template` SET `RequiredRaces` = 178 WHERE `entry` IN (4982, 5802, 6983, 8746, 8799);

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
