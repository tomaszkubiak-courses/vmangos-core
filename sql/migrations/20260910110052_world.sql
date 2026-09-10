DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260910110052');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260910110052');
-- Add your query below.

-- The three gemstones for Seal of Ascension had drop chances that were never
-- checked against anything: 20% from War Master Voone, 25% from Highlord Omokk
-- and 30% from Overlord Wyrmthalak.
--
-- The sniffed WotLK data has all three at 100%, but that is not a vanilla value:
-- patch 2.2.0 is what made "the gems for the Seal of Ascension ... a 100% drop
-- from Overlord Wyrmthalak, War Master Voone and Highlord Omokk". Before that
-- they were ordinary chance drops, so the retail dumps cannot be copied here.
--
-- Use the rates collected in 1.13, which is the closest re-creation of the
-- pre-2.2 loot tables there is. They also fix the ordering: Bloodaxe is the most
-- common of the three and Spirestone the rarest, which is the order the vanilla
-- MaNGOS Zero data has as well, while the values here had Spirestone above
-- Smolderthorn.
--
-- The chances stay positive. These are quest items but not quest-only drops, so
-- they keep dropping for players who have not picked the quest up, which is how
-- every other core has them too.
UPDATE `creature_loot_template` SET `ChanceOrQuestChance` = 34.97 WHERE `entry` = 9237 AND `item` = 12335;
UPDATE `creature_loot_template` SET `ChanceOrQuestChance` = 27.47 WHERE `entry` = 9196 AND `item` = 12336;
UPDATE `creature_loot_template` SET `ChanceOrQuestChance` = 40.53 WHERE `entry` = 9568 AND `item` = 12337;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
