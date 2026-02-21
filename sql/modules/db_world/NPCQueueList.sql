DELETE FROM `creature_template` WHERE `entry` = 93080;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(93080, 0, 0, 0, 0, 0, 'Show Queues', '', 'Speak', 0, 30, 30, 0, 35, 1, 1, 1, 1, 1, 20, 1, 0, 0, 1, 0, 0, 1, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 16777218, 'queue_list_npc', 0);

DELETE FROM `creature_template_model` WHERE (`CreatureID` = 93080);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(93080, 0, 28205, 1, 1, 0);

SET @NPC_TEXT_QUEUE="This NPC lets you display all active battleground or arena queues (if any). $B$BAlternatively, you can check the queues without interacting with the NPC by using the following commands: $B$B.queue show bg $B$B.queue show arena normal $B$B.queue show arena rated $B$BNote that the queue doesn't update in real-time; it refreshes periodically (by default every 5 seconds).";
DELETE FROM `npc_text` WHERE `id`=93081;
INSERT INTO `npc_text` (`id`, `text0_0`, `text0_1`, `Probability0`) VALUES
(93081, @NPC_TEXT_QUEUE, @NPC_TEXT_QUEUE, 1);

-- Command
SET @NPC_QUEUE_COMMAND_DESC = 'Syntax .queue show bg or .queue show arena normal/rated';
DELETE FROM `command` WHERE `name` IN ('queue', 'queue show', 'queue show bg', 'queue show arena', 'queue show arena normal', 'queue show arena rated');
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('queue', 0, @NPC_QUEUE_COMMAND_DESC),
('queue show', 0, @NPC_QUEUE_COMMAND_DESC),
('queue show bg', 0, @NPC_QUEUE_COMMAND_DESC),
('queue show arena normal', 0, @NPC_QUEUE_COMMAND_DESC),
('queue show arena rated', 0, @NPC_QUEUE_COMMAND_DESC);
