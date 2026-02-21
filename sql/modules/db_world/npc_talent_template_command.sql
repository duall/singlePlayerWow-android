-- COMMAND
DELETE FROM `command` WHERE `name` IN ('templatenpc reload', 'templatenpc create');
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('templatenpc reload', 3, 'Syntax: .templatenpc reload\nType .templatenpc reload to reload Template NPC database changes'),
('templatenpc create', 3, 'Syntax: .templatenpc create\nType .templatenpc create [name] to create a Template for your class with the desired name. This name is case-sensitive');
