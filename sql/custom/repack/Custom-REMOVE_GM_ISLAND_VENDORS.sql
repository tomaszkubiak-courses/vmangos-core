-- Removes everything added by Custom-ADD_GM_ISLAND_VENDORS.sql.
DELETE FROM `creature_template` WHERE `entry` BETWEEN 90000 AND 90032;
DELETE FROM `creature_template` WHERE `entry`=20008;
DELETE FROM `npc_trainer` WHERE `entry` BETWEEN 90000 AND 90032;
DELETE FROM `npc_vendor` WHERE `entry` BETWEEN 90000 AND 90032;
DELETE FROM `conditions` WHERE `condition_entry` IN (1700000, 1700001);
DELETE FROM `creature` WHERE (`guid` BETWEEN 2000000 AND 2000033) OR (`id` BETWEEN 90000 AND 90032) OR (`id`=20008);
DELETE FROM `npc_gossip` WHERE `npc_guid` BETWEEN 2000000 AND 2000033;
DELETE FROM `npc_text` WHERE `ID` BETWEEN 90000 AND 90005;
DELETE FROM `broadcast_text` WHERE `entry` BETWEEN 99990 AND 99995;
DELETE FROM `gossip_scripts` WHERE `id`=13500;
DELETE FROM `gossip_menu_option` WHERE `menu_id`=13500;
DELETE FROM `gossip_menu` WHERE `entry`=13500;
