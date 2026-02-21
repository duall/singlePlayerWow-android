-- ############################################################
-- BEASTMASTER NPC & VENDOR SETUP (Entry: 601026)
-- ############################################################

-- Variables for easy editing
SET
@Entry      := 601026,
@Model      := 26314, -- Northrend Worgen White
@Name       := 'White Fang',
@Title      := 'BeastMaster',
@Icon       := '',
@GossipMenu := 0, -- Let script handle gossip, not DB
@MinLevel   := 80,
@MaxLevel   := 80,
@Faction    := 35,
@NPCFlag    := 4194433, -- Vendor + Gossip + Stable + Trainer, etc.
@Scale      := 1.0,
@Rank       := 0,
@Type       := 7,
@TypeFlags  := 0,
@FlagsExtra := 2,
@AIName     := '',
@Script     := 'BeastMaster';

-- Remove any existing NPC with this entry
DELETE FROM `creature_template` WHERE `entry` = @Entry;
INSERT INTO `creature_template` (
    `entry`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `unit_class`, `unit_flags`, `type`, `type_flags`, `RegenHealth`, `flags_extra`, `AIName`, `ScriptName`
) VALUES
(@Entry, @Name, @Title, @Icon, @GossipMenu, @MinLevel, @MaxLevel, @Faction, @NPCFlag, 1, 1.14286, @Scale, @Rank, 1, 2, @Type, @TypeFlags, 1, @FlagsExtra, @AIName, @Script);

-- Set display/model
DELETE FROM `creature_template_model` WHERE `CreatureID` = @Entry;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(@Entry, 0, @Model, @Scale, 1);

-- Equip the NPC with items (optional flavor)
DELETE FROM `creature_equip_template` WHERE `CreatureID` = @Entry AND `ID` = 1;
INSERT INTO `creature_equip_template` VALUES (@Entry, 1, 2196, 1906, 0, 18019); -- Haunch of Meat, Torch

-- NPC greeting and menu text
DELETE FROM `npc_text` WHERE `ID` IN (601026, 601027);
INSERT INTO `npc_text` (`ID`, `text0_0`) VALUES 
(601026, 'Greetings, $N.$b$bIf you''re looking for a trustful companion to take on your travels, you have come to the right place. I can offer you a variety of tamed pets to choose from. I can also supply you with food so that you can take good care of your new friend.'),
(601027, 'What kind of pet are you interested in?');

-- Dummy gossip_menu to suppress DB warnings (not used by script)
DELETE FROM `gossip_menu` WHERE `MenuID` = 60102;
INSERT INTO `gossip_menu` VALUES (60102, 68);

-- ############################################################
-- BEASTMASTER VENDOR ITEMS
-- ############################################################

DELETE FROM `npc_vendor` WHERE `entry` = @Entry;

-- Add pet food and special items to vendor
INSERT INTO `npc_vendor` (`entry`, `item`) VALUES
(@Entry, 35953), (@Entry, 33454), (@Entry, 27854), (@Entry, 8952), (@Entry, 4599), (@Entry, 3771), (@Entry, 3770), (@Entry, 2287), (@Entry, 117),
(@Entry, 35947), (@Entry, 33452), (@Entry, 27859), (@Entry, 8948), (@Entry, 4608), (@Entry, 4607), (@Entry, 4606), (@Entry, 4605), (@Entry, 4604),
(@Entry, 35950), (@Entry, 33449), (@Entry, 27855), (@Entry, 8950), (@Entry, 4601), (@Entry, 4544), (@Entry, 4542), (@Entry, 4541), (@Entry, 4540),
(@Entry, 35948), (@Entry, 35949), (@Entry, 27856), (@Entry, 8953), (@Entry, 4602), (@Entry, 4539), (@Entry, 4538), (@Entry, 4537), (@Entry, 4536),
(@Entry, 35951), (@Entry, 33451), (@Entry, 27858), (@Entry, 8957), (@Entry, 21552), (@Entry, 4594), (@Entry, 4593), (@Entry, 4592), (@Entry, 787),
(@Entry, 35952), (@Entry, 33443), (@Entry, 27857), (@Entry, 8932), (@Entry, 3927), (@Entry, 1707), (@Entry, 422), (@Entry, 414), (@Entry, 2070),
(@Entry, 33875), (@Entry, 21024);

-- ############################################################
-- FIX GAME OBJECT DISPLAY IDS
-- ############################################################

-- Update invalid displayId for game objects
UPDATE `gameobject_template`
SET `displayId` = 4075  -- Valid console model for GoType 7
WHERE `entry` IN (500042, 500043) AND `type` = 7;

UPDATE `gameobject_template`
SET `displayId` = 4461  -- Valid destructible building model for GoType 33
WHERE `entry` = 500040 AND `type` = 33;

-- ############################################################
-- END OF FILE
-- ############################################################

-- After running this SQL:
-- 1. Restart your worldserver (required for item_template and gameobject_template changes).
-- 3. Clear your WoW client Cache folder if the icon or name does not update.
-- 4. Check worldserver.log for any remaining game object errors.