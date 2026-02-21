
SET
@Entry      := 300000,
@Model      := 24877,
@Name       := "Cromi",
@Title      := "Instance Reset";

DELETE FROM `creature_template` WHERE `entry` = @Entry;

INSERT INTO `creature_template` (`entry`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `unit_class`, `unit_flags`, `type`, `type_flags`, `RegenHealth`, `flags_extra`, `ScriptName`) VALUES
(@Entry, @Name, @Title, "Speak", 0, 80, 80, 35, 0, 1, 1.14286, 1, 0, 1, 2, 7, 138936390, 1, 2, "instance_reset");

DELETE FROM `creature_template_model` where creatureid=@Entry;

INSERT INTO `creature_template_model` (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) VALUES
(@Entry, '0', @Model, '1', '1', NULL);

UPDATE `creature_template` SET `npcflag`=`npcflag`|1, `flags_extra`=`flags_extra`|16777216 WHERE `entry`=@Entry;

DELETE FROM `creature_template_locale` WHERE `entry`=@Entry;

INSERT INTO `creature_template_locale` (`entry`, `locale`, `Name`, `Title`, `VerifiedBuild`) VALUES
(@Entry, 'esES', @Name, 'Reinicio de instancias', 0),
(@Entry, 'esMX', @Name, 'Reinicio de instancias', 0),
(@Entry, 'frFR', @Name, 'Redémarrage des instances', 0),
(@Entry, 'koKR', @Name, '인스턴스 재시작', 0),
(@Entry, 'deDE', @Name, 'Neustart der Instanz', 0),
(@Entry, 'zhCN', @Name, '重新启动实例', 0),
(@Entry, 'zhTW', @Name, '重置副本', 0),
(@entry, 'ruRU', @name, 'Перезапуск подземелий', 0);
