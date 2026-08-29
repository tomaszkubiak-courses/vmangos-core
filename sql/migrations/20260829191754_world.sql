DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260829191754');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260829191754');
-- Add your query below.

-- The Moonglade cross-faction flight emissaries were pointing at taxi paths
-- that do not exist in the 1.12.1 client. TaxiPath.dbc for build 5875 has no
-- entries at all between 122 and 140, so ObjectMgr rejected both rows at load
-- with "has datalong = 134 in SCRIPT_COMMAND_SEND_TAXI_PATH ... but this taxi
-- path does not exist", dropped the gossip options that referenced them, and
-- then reported the surviving `locales_gossip_menu_option` rows as orphans.
-- Both flights were dead in game.
--
-- The paths the client actually ships are:
--   315  Nighthaven, Moonglade (node 62) -> Rut'theran Village (node 27)
--   316  Nighthaven, Moonglade (node 63) -> Thunder Bluff (node 22)
-- Node 62 and node 27 both carry a Horde mount, which matches Silva
-- Fil'naveth ferrying Horde druids home; node 63 and node 22 both carry an
-- Alliance mount, matching Bunthen Plainswind.

UPDATE `gossip_scripts` SET `datalong`=315 WHERE `id`=4041 AND `command`=30 AND `datalong`=134;
UPDATE `gossip_scripts` SET `datalong`=316 WHERE `id`=4042 AND `command`=30 AND `datalong`=135;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
