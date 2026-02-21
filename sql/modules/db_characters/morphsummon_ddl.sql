CREATE TABLE IF NOT EXISTS `mod_morphsummon_felguard_weapon` (
  `PlayerGUIDLow` int(10) unsigned NOT NULL,
  `FelguardItemID` int(10) unsigned NOT NULL COMMENT 'Item ID for Felguard virtual item slot 0',
  PRIMARY KEY (`PlayerGUIDLow`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='mod-morphsummon; used for custom Felguard weapons';
