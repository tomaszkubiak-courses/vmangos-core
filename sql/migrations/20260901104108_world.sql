DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260901104108');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260901104108');
-- Add your query below.

-- "The Treasure of the Shen'dralar" (7462) cannot be picked up. Nothing offers it:
-- there is no row for it in creature_questrelation, none in gameobject_questrelation,
-- and no item_template.start_quest points at it. Its prerequisite "The Madness Within"
-- (7461) has NextQuestId 0, so the chain does not carry it either - and it would not
-- help if it did, because Player::GetNextQuest only returns a follow-up that the
-- questgiver already has in its relation map. All that exists for 7462 is the turn-in,
-- gameobject_involvedrelation 179517.
--
-- 173 quests on this database have no questgiver of any kind, so a missing relation is
-- not on its own evidence of a fault - most of that set is content that was removed or
-- never used. 7462 is the one that stands out: pfQuest's vanilla database, generated
-- from VMaNGOS, names a starter for exactly one of those 173, and it names Shen'dralar
-- Ancient (14358) - the same NPC that both starts and ends the prerequisite 7461, and
-- the only other quest giver in that chain.
--
-- Patch window and giver match the rows already there for 7461 and for the 7462 turn-in,
-- all of which are 1..10.

-- (id, quest) is the primary key, so IGNORE makes this a no-op on a database that
-- already carries the row.
INSERT IGNORE INTO `creature_questrelation` (`id`, `quest`, `patch_min`, `patch_max`)
VALUES (14358, 7462, 1, 10);

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
