-- DATA
SET @ENTRY := 55009;
SET @NAME := 'Pick a spec';
SET @SUBNAME := 'AzerothCore Template';
SET @TEXT := 'Here you can select a character template which will gear up, gem up, set talent specialization, and set glyphs for your character instantly.';
SET @DISPLAY_ID := 24877;

DELETE FROM `creature_template` WHERE `entry` = @ENTRY;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `unit_class`, `unit_flags`, `type`, `type_flags`, `RegenHealth`, `flags_extra`, `ScriptName`) VALUES
(@ENTRY, @NAME , @SUBNAME, 'Speak', 0, 80, 80, 35, 1, 1, 1.14286, 1, 0, 1, 2, 7, 138936390, 1, 2, 'npc_talent_template');

DELETE FROM `creature_template_model` WHERE `CreatureID` = @ENTRY;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(@ENTRY, 0, @DISPLAY_ID, 1, 1, 0);

DELETE FROM `npc_text` WHERE `ID` = @ENTRY;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`) VALUES
(@ENTRY, @TEXT, @TEXT);

DELETE FROM `creature_template_movement` WHERE `CreatureId` = @ENTRY;
INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`) VALUES
(@ENTRY, 1, 1, 0, 0, 0, 0, NULL);

-- module string
SET @MODULE_STRING := 'npc-talent-template';
DELETE FROM `module_string` WHERE `module` = @module_string;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
(@MODULE_STRING, 1, 'You need to remove all your equipped items in order to use this feature!'),
(@MODULE_STRING, 2, 'You have already spent some talent points. You need to reset your talents first!'),
(@MODULE_STRING, 3, 'Successfully equipped {} {} template!'),
(@MODULE_STRING, 4, 'Your equipped gear has been destroyed.'),
(@MODULE_STRING, 5, 'Your glyphs have been removed.'),
(@MODULE_STRING, 6, 'NYI: Copied character {} successfully'),
(@MODULE_STRING, 7, 'You have unspent talent points. Please spend all your talent points and re-extract the template.'),
(@MODULE_STRING, 8, 'Get glyphs and re-extract the template!'),
(@MODULE_STRING, 9, 'Template successfully created!'),
(@MODULE_STRING, 10, 'Template skeleton successfully created! You can `.templatenpc reload` to test your template. WARNING: Templates need to be manually exported to `.sql`. See documentation for more info.'),
(@MODULE_STRING, 11, 'Reloading templates for Template NPC table...'),
(@MODULE_STRING, 12, 'Template NPC templates reloaded.');

-- 'deDE', 'ruRU', 'ruRU', 'koKR', 'frFR', 'zhCN', 'zhTW', 'esES', 'esMX',
DELETE FROM `module_string_locale` WHERE `module` = @MODULE_STRING;
-- INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
-- (@MODULE_STRING, 0 , 'deDE', ''),
