DROP PROCEDURE IF EXISTS add_migration;
DELIMITER ??
CREATE PROCEDURE `add_migration`()
BEGIN
DECLARE v INT DEFAULT 1;
SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='20260828181326');
IF v = 0 THEN
INSERT INTO `migrations` VALUES ('20260828181326');
-- Add your query below.
-- Drop the bot help topics for content this server does not have.
--
-- ai_playerbot_help_texts is served to players verbatim by PlayerbotHelpMgr, and the
-- generator that would rewrite it is compiled out (GenerateBotHelp is never defined), so
-- these rows outlive the code they describe. The Death Knight class AI and the Karazhan
-- strategies have been removed from the module, which leaves 73 topics describing a class
-- that does not exist before 3.0 and a raid that does not exist before TBC. The same rows
-- are gone from sql/world/ai_playerbot_texts.sql, so a fresh import agrees with this.
--
-- The updates below remove the links to those topics from the topics that survive - mostly
-- the generated 'list:generic ...' indexes, which would otherwise keep offering them as
-- clickable entries that resolve to nothing.

IF (SELECT COUNT(*) FROM `information_schema`.`TABLES` WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'ai_playerbot_help_texts') > 0 THEN

DELETE FROM `ai_playerbot_help_texts` WHERE `name` IN (
    'action:add nether portal - perseverence for tank',
    'action:deathknight anti magic shell',
    'action:deathknight anti magic zone',
    'action:deathknight blood boil',
    'action:deathknight blood tap',
    'action:deathknight bone shield',
    'action:deathknight corpse explosion',
    'action:deathknight dark command',
    'action:deathknight death and decay',
    'action:deathknight death coill',
    'action:deathknight death grip',
    'action:deathknight death pact',
    'action:deathknight death strike',
    'action:deathknight ghoul frenzy',
    'action:deathknight horn of winter',
    'action:deathknight howling blast',
    'action:deathknight icebound fortitude',
    'action:deathknight icy touch',
    'action:deathknight improved icy talons',
    'action:deathknight mind freeze',
    'action:deathknight pestilence',
    'action:deathknight plague strike',
    'action:deathknight raise dead',
    'action:deathknight rune tap',
    'action:deathknight unholy blight',
    'action:deathknight vampiric blood',
    'action:disable karazhan strategy',
    'action:disable netherspite fight strategy',
    'action:disable prince malchezaar fight strategy',
    'action:enable karazhan strategy',
    'action:enable netherspite fight strategy',
    'action:enable prince malchezaar fight strategy',
    'action:move away from netherspite infernal',
    'action:remove nether portal buffs from netherspite',
    'list:deathknight action',
    'list:deathknight strategy',
    'list:deathknight trigger',
    'strategy:deathknight bdps',
    'strategy:deathknight blood',
    'strategy:deathknight frost',
    'strategy:deathknight frost aoe',
    'strategy:deathknight nc',
    'strategy:deathknight pull',
    'strategy:deathknight react',
    'strategy:deathknight unholy',
    'strategy:deathknight unholy aoe',
    'strategy:karazhan',
    'strategy:netherspite',
    'strategy:prince malchezaar',
    'trigger:deathknight aoe',
    'trigger:deathknight blessing of salvation',
    'trigger:deathknight blood tap',
    'trigger:deathknight bone shield',
    'trigger:deathknight death coil',
    'trigger:deathknight enemy out of melee range',
    'trigger:deathknight greater blessing of salvation',
    'trigger:deathknight horn of winter',
    'trigger:deathknight icy touch',
    'trigger:deathknight icy touch on attacker',
    'trigger:deathknight improved icy talons',
    'trigger:deathknight mind freeze',
    'trigger:deathknight plague strike',
    'trigger:deathknight plague strike on attacker',
    'trigger:deathknight raise dead',
    'trigger:deathknight trigger',
    'trigger:end netherspite fight',
    'trigger:end prince malchezaar fight',
    'trigger:enter karazhan',
    'trigger:generic netherspite beams cheat need refresh',
    'trigger:leave karazhan',
    'trigger:netherspite infernal too close',
    'trigger:start netherspite fight',
    'trigger:start prince malchezaar fight'
);

UPDATE `ai_playerbot_help_texts` SET `template_text` = REPLACE(`template_text`, '[h:list:deathknight strategy|deathknight]', '') WHERE `name` = 'object:strategy';
UPDATE `ai_playerbot_help_texts` SET `template_text` = REPLACE(`template_text`, '[h:list:deathknight trigger|deathknight]', '') WHERE `name` = 'object:trigger';
UPDATE `ai_playerbot_help_texts` SET `template_text` = REPLACE(`template_text`, '[h:list:deathknight action|deathknight]', '') WHERE `name` = 'object:action';
UPDATE `ai_playerbot_help_texts` SET `template_text` = REPLACE(REPLACE(REPLACE(REPLACE(`template_text`, '[h:trigger|enter karazhan] ', ''), '[h:action|enable karazhan strategy] ', ''), '[h:trigger|leave karazhan] ', ''), '[h:action|disable karazhan strategy] ', '') WHERE `name` = 'strategy:dungeon';
UPDATE `ai_playerbot_help_texts` SET `template_text` = REPLACE(REPLACE(`template_text`, '[h:action:deathknight corpse explosion|corpse explosion] ', ''), '[h:strategy:deathknight unholy aoe|unholy aoe]', '') WHERE `name` = 'trigger:loot available';
UPDATE `ai_playerbot_help_texts` SET `template_text` = REPLACE(REPLACE(REPLACE(REPLACE(`template_text`, '[h:action:deathknight anti magic zone|anti magic zone] ', ''), '[h:strategy:deathknight frost|frost]', ''), '[h:strategy:deathknight blood|blood]', ''), '[h:strategy:deathknight unholy|unholy]', '') WHERE `name` = 'trigger:critical aoe heal';
UPDATE `ai_playerbot_help_texts` SET `template_text` = REPLACE(REPLACE(REPLACE(REPLACE(`template_text`, '[h:trigger:deathknight enemy out of melee range|enemy out of melee range] ', ''), '[h:strategy:deathknight frost|frost]', ''), '[h:strategy:deathknight blood|blood]', ''), '[h:strategy:deathknight unholy|unholy]', '') WHERE `name` = 'action:reach melee';
UPDATE `ai_playerbot_help_texts` SET `template_text` = REPLACE(REPLACE(REPLACE(`template_text`, '[h:strategy|karazhan] ', ''), '[h:strategy|netherspite] ', ''), '[h:strategy|prince malchezaar] ', '') WHERE `name` = 'list:generic strategy';
UPDATE `ai_playerbot_help_texts` SET `template_text` = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(`template_text`, '[h:trigger|end netherspite fight]', ''), '[h:trigger|end prince malchezaar fight] ', ''), '[h:trigger|enter karazhan] ', ''), '[h:trigger|leave karazhan]', ''), '[h:trigger|netherspite beams cheat need refresh] ', ''), '[h:trigger|netherspite infernal too close] ', ''), '[h:trigger|start netherspite fight]', ''), '[h:trigger|start prince malchezaar fight] ', '') WHERE `name` = 'list:generic trigger';
UPDATE `ai_playerbot_help_texts` SET `template_text` = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(`template_text`, '[h:action|add nether portal - perseverence for tank] ', ''), '[h:action|disable karazhan strategy] ', ''), '[h:action|disable netherspite fight strategy] ', ''), '[h:action|disable prince malchezaar fight strategy] ', ''), '[h:action|enable karazhan strategy] ', ''), '[h:action|enable netherspite fight strategy] ', ''), '[h:action|enable prince malchezaar fight strategy] ', ''), '[h:action|move away from netherspite infernal] ', ''), '[h:action|remove nether portal buffs from netherspite] ', '') WHERE `name` = 'list:generic action';
UPDATE `ai_playerbot_help_texts` SET `template_text` = REPLACE(`template_text`, '[h:strategy|netherspite]', '') WHERE `name` = 'trigger:void zone too close';
UPDATE `ai_playerbot_help_texts` SET `template_text` = REPLACE(`template_text`, '[h:strategy|netherspite]', '') WHERE `name` = 'action:move away from void zone';

END IF;



-- End of migration.
END IF;
END??
DELIMITER ;
CALL add_migration();
DROP PROCEDURE IF EXISTS add_migration;
