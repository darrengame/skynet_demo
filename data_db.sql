CREATE DATABASE `GUID`
CREATE TABLE GUID.SEQUENCE_ID(
    id bigint(20) unsigned NOT NULL auto_increment,
    value char(20) NOT NULL default '',
    PRIMARY KEY (id),
)ENGINE=MyISAM;