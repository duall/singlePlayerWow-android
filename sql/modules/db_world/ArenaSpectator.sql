DELETE FROM `creature_template` WHERE `entry`=190000;
INSERT INTO `creature_template` (`entry`, `name`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `scale`, `rank`, `dmgschool`, `baseattacktime`, `rangeattacktime`, `unit_class`, `unit_flags`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `AIName`, `MovementType`, `HoverHeight`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `flags_extra`, `ScriptName`) VALUES
(190000, "Arena Spectator", "Speak", 0, 80, 80, 2, 35, 3, 1, 0, 0, 2000, 0, 1, 0, 7, 138936390, 0, 0, 0, '', 0, 1, 0, 0, 1, 0, 16777216, 'ArenaSpectatorNPC_Creature');

DELETE FROM `creature_template_model` WHERE `CreatureID` = 190000;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(190000, 0, 29348, 1, 1, 0);

SET @NPC_TEXT_SPECTATOR = "The lists in the menu contain all currently ongoing arena matches. You can spectate a match by simply selecting the one you desire. If you want to spectate a specific player, select the corresponding option and enter a playername.$B$BThe following command allows you to leave the arena you are spectating.$B.spectate leave$B$BTo watch the match from the perspective of a contestant use$B.spectate watch playername/target$B$BYou can enter a playername or simply select a target to do so.$BNo target resets the view to yourself.$B$BPlease remember that you cannot use say while spectating.$BUse a different channel like guild to execute commands.";
DELETE FROM `npc_text` WHERE `id`=190017;
INSERT INTO `npc_text` (`id`, `text0_0`, `text0_1`, `Probability0`) VALUES
(190017, @NPC_TEXT_SPECTATOR, @NPC_TEXT_SPECTATOR, 1);
