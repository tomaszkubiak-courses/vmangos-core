DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260829231808');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260829231808');
-- Add your query below.

-- Two data faults that logged errors during a 2h run with the world populated.
--
-- 1. Fallenroot Rogue (4789) carried an EVENT_T_REACHED_HOME event that ran
--    SCRIPT_COMMAND_SET_INST_DATA (index 4, value 2) on the Blackfathom Deeps
--    instance script. The creature has no spawn on map 48 at all - all six of
--    its spawns are outdoors on Kalimdor - so the command could only ever run
--    on a map with no instance script, and every reset of one of those six
--    spawns logged
--        SCRIPT_COMMAND_SET_INST_DATA (script id 478903) call for map without
--        an instance script, skipping.
--    Even inside the instance it would have done nothing: instance_blackfathom
--    _deeps only handles data types 10, 11 and 12, and 4 is DATA_SHRINE4, a
--    GetData64 index. The event is dead in every location it can reach, so it
--    and its script are removed rather than re-pointed.

DELETE FROM `creature_ai_events` WHERE `id`=478903 AND `creature_id`=4789;
DELETE FROM `creature_ai_scripts` WHERE `id`=478903;

-- 2. Janey Anship (1413) chats with Lisan Pierce (1414) and Suzanne (1415) on
--    an EVENT_T_TIMER_OOC that fires every 60 seconds. The scripts it starts
--    address both of them with target_type 10 (nearest creature with entry)
--    and a 10 yard search radius, which only holds while Janey is parked at
--    waypoint 101 next to them in the Stormwind Trade District. Janey's path
--    is 101 points long and loops most of the city, so whenever the timer came
--    round while she was walking the lookup failed and logged
--        FindScriptTargets: Failed to find target for script with id 141301
--        (target_param1: 1415), (target_param2: 10), (target_type: 10).
--    Gate the event on Suzanne actually being within the same 10 yards the
--    scripts search. CONDITION_NEARBY_CREATURE tests the condition target, and
--    EventAI passes the creature as the source, so the row needs
--    CONDITION_FLAG_SWAP_TARGETS (2). value4 = 1 excludes Janey herself.

DELETE FROM `conditions` WHERE `condition_entry`=1413;
INSERT INTO `conditions` (`condition_entry`, `type`, `value1`, `value2`, `value3`, `value4`, `flags`) VALUES (1413, 20, 1415, 10, 0, 1, 2);

UPDATE `creature_ai_events` SET `condition_id`=1413 WHERE `id`=141301 AND `creature_id`=1413;

-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
