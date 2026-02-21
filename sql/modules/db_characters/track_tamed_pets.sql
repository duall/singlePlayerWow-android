CREATE TABLE IF NOT EXISTS `beastmaster_tamed_pets` (
    `owner_guid` INT UNSIGNED NOT NULL,
    `entry`      INT UNSIGNED NOT NULL,
    `name`       VARCHAR(32)  NOT NULL,
    `date_tamed` TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`owner_guid`, `entry`),
    KEY `idx_beastmaster_tamed_pets_owner_guid` (`owner_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;