
DROP TABLE IF EXISTS `emblem_transferences`;

CREATE TABLE `emblem_transferences` (
    `sender_guid` INT(10) NOT NULL,
    `receiver_guid` INT(10) NOT NULL,
    `emblem_entry` MEDIUMINT(8) NOT NULL,
    `amount` INT(11) NOT NULL,
    `active` BIT(1) NOT NULL DEFAULT b'1',
    `sent_timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `received_timestamp` TIMESTAMP NULL DEFAULT NULL
)
COMMENT='[mod-emblem-transfer] Registers transferences between characters'
COLLATE='latin1_swedish_ci'
ENGINE=InnoDB;
