DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260905122635');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260905122635');
-- Add your query below.

-- Colonel Kurzen's EventAI drives a two phase cycle - cast Smoke Bomb, which triggers
-- Stealth (8822) on him, then Garrote once that stealth is gone - but all three of its
-- SCRIPT_COMMAND_SET_PHASE rows use mode 1 (increment) while `datalong` already holds the
-- absolute phase the comments name. Aggro increments 0 to 1, the Smoke Bomb script then
-- adds 2 and lands on 3 instead of 2. Phase 3 is not masked out of the Smoke Bomb event
-- (event_inverse_phase_mask 5 only skips phases 0 and 2), so it fires again and adds 2
-- once more, and the phase climbs by two every cast until it passes 31 and the core
-- refuses it: "SCRIPT_COMMAND_SET_PHASE (script id 81303) attempt to increment Phase above
-- 31". Nothing ever brings the phase back down, so from the first Smoke Bomb onwards he is
-- stuck in a phase where neither of his two abilities behaves as written.
--
-- Set the phase outright (mode 0) in all three scripts. The values already stored are the
-- phases the comments and the event phase masks expect: 1 on aggro, 2 after Smoke Bomb so
-- the missing-stealth event can run, and back to 1 after Garrote so the Smoke Bomb timer
-- takes over again.
UPDATE `creature_ai_scripts` SET `datalong2`=0 WHERE `id`=81301 AND `command`=44 AND `datalong`=1;
UPDATE `creature_ai_scripts` SET `datalong2`=0 WHERE `id`=81302 AND `command`=44 AND `datalong`=2;
UPDATE `creature_ai_scripts` SET `datalong2`=0 WHERE `id`=81303 AND `command`=44 AND `datalong`=1;

-- The row comments still read "Increment Phase", which is what they no longer do.
UPDATE `creature_ai_scripts` SET `comments`='Colonel Kurzen - Set Phase 1' WHERE `id`=81301 AND `command`=44;
UPDATE `creature_ai_scripts` SET `comments`='Colonel Kurzen - Set Phase 2' WHERE `id`=81302 AND `command`=44;
UPDATE `creature_ai_scripts` SET `comments`='Colonel Kurzen - Set Phase 1' WHERE `id`=81303 AND `command`=44;




-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
