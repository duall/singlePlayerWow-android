-- DB: characters
CREATE TABLE IF NOT EXISTS `mod_npc_talent_template_gear` (
  `playerClass` varchar(50) NOT NULL,
  `playerSpec` varchar(50) NOT NULL,
  `playerRaceMask` int unsigned DEFAULT '0',
  `pos` int unsigned NOT NULL DEFAULT '0',
  `itemEntry` int unsigned NOT NULL DEFAULT '0',
  `enchant` int unsigned NOT NULL DEFAULT '0',
  `socket1` int unsigned NOT NULL DEFAULT '0',
  `socket2` int unsigned NOT NULL DEFAULT '0',
  `socket3` int unsigned NOT NULL DEFAULT '0',
  `bonusEnchant` int unsigned NOT NULL DEFAULT '0',
  `prismaticEnchant` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=UTF8MB4 COMMENT='Templates';


CREATE TABLE IF NOT EXISTS `mod_npc_talent_template_talents` (
  `playerClass` varchar(50) NOT NULL,
  `playerSpec` varchar(50) NOT NULL,
  `talentId` int unsigned NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=UTF8MB4 COMMENT='Templates';


CREATE TABLE IF NOT EXISTS `mod_npc_talent_template_glyphs` (
  `playerClass` varchar(50) NOT NULL,
  `playerSpec` varchar(50) NOT NULL,
  `slot` tinyint unsigned NOT NULL DEFAULT '0',
  `glyph` smallint unsigned NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=UTF8MB4 COMMENT='Templates';


CREATE TABLE IF NOT EXISTS `mod_npc_talent_template_index` (
  `playerClass` varchar(50) NOT NULL,
  `playerSpec` varchar(50) NOT NULL,
  `gossipAction` int unsigned NOT NULL DEFAULT '0',
  `gossipText` varchar(200) NOT NULL,
  `mask` int unsigned NOT NULL DEFAULT '0',
  `minLevel` int unsigned NOT NULL DEFAULT '0',
  `maxLevel` int unsigned NOT NULL DEFAULT '0',
  `gearOverride` varchar(50) NOT NULL DEFAULT '',
  `glyphOverride` varchar(50) NOT NULL DEFAULT '',
  `talentOverride` varchar(50) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=UTF8MB4 COMMENT='Templates';
