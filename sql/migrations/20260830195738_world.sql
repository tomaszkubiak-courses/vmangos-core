DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260830195738');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260830195738');
-- Add your query below.

-- Glutton's "Yell on Aggro" carries EFLAG_REPEATABLE. EVENT_T_AGGRO fires once per
-- combat by definition, so CreatureEventAIMgr rejects the flag on it and complains
-- on every startup:
--
--   CreatureEventAI:  Creature 8567 has EFLAG_REPEATABLE set. Event can never be
--   repeatable. Removing flag for event 856701.
--
-- The core strips the flag itself, so this only silences the error - behaviour is
-- already what the corrected row describes. Upstream's own copy of
-- 20260823080903_world.sql inserts this row with event_flags = 0; the version this
-- fork took off the pull request branch predated that block, so the correction was
-- never applied here. This is the only row in the table with the flag set on an
-- event type that cannot repeat.
UPDATE `creature_ai_events` SET `event_flags` = 0 WHERE `id` = 856701 AND `creature_id` = 8567;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
