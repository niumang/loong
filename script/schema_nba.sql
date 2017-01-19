/*
Source Database       : nba
Target Server Type    : MYSQL
Target Server Version : 50547
File Encoding         : 65001

Date: 2017-01-06 16:44:48
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for player
-- ----------------------------
DROP TABLE IF EXISTS `player`;
CREATE TABLE `player` (
  `id` int(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(40) DEFAULT NULL,
  `weight` varchar(10) DEFAULT NULL,
  `height` varchar(10) DEFAULT NULL,
  `pos` varchar(10) DEFAULT NULL,
  `birthday` varchar(30) DEFAULT NULL,
  `team` varchar(30) DEFAULT NULL,
  `school` varchar(30) DEFAULT NULL,
  `country` varchar(30) DEFAULT NULL,
  `draft` varchar(30) DEFAULT NULL,
  `contract` varchar(80) DEFAULT NULL,
  `salary` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for player_stat
-- ----------------------------
DROP TABLE IF EXISTS `player_stat`;
CREATE TABLE `player_stat` (
  `id` int(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(40) DEFAULT NULL,
  `logo` mediumtext,
  `ppg` varchar(10) DEFAULT NULL,
  `lpg` varchar(10) DEFAULT NULL,
  `fga` varchar(11) DEFAULT NULL,
  `fgp` int(11) DEFAULT '0',
  `3pm` varchar(30) DEFAULT NULL,
  `3pa` varchar(30) DEFAULT NULL,
  `3pp` varchar(30) DEFAULT NULL,
  `fta` varchar(30) DEFAULT NULL,
  `ftm` varchar(30) DEFAULT NULL,
  `ftp` varchar(30) DEFAULT NULL,
  `defr` varchar(30) DEFAULT NULL,
  `offr` varchar(30) DEFAULT NULL,
  `apg` varchar(30) DEFAULT NULL,
  `spg` varchar(30) DEFAULT NULL,
  `bpg` varchar(30) DEFAULT NULL,
  `tpg` varchar(30) DEFAULT NULL,
  `fpg` varchar(30) DEFAULT NULL,
  `min` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for schedule
-- ----------------------------
DROP TABLE IF EXISTS `schedule`;
CREATE TABLE `schedule` (
  `id` int(20) NOT NULL AUTO_INCREMENT,
  `match_time` datetime DEFAULT NULL,
  `team` varchar(20) DEFAULT NULL,
  `home` varchar(20) DEFAULT NULL,
  `away` varchar(20) DEFAULT NULL,
  `home_score` int(11) DEFAULT NULL,
  `away_score` int(11) DEFAULT NULL,
  `result` varchar(3) DEFAULT NULL,
  `stat` longtext,
  `video` varchar(255) DEFAULT NULL,
  `highlight` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for team
-- ----------------------------
DROP TABLE IF EXISTS `team`;
CREATE TABLE `team` (
  `id` int(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(40) DEFAULT NULL,
  `logo` mediumtext,
  `zone` varchar(10) DEFAULT NULL,
  `win` int(11) DEFAULT NULL,
  `los` int(11) DEFAULT '0',
  `coach` varchar(30) DEFAULT NULL,
  `born` varchar(30) DEFAULT NULL,
  `site` varchar(30) DEFAULT NULL,
  `home` varchar(30) DEFAULT NULL,
  `zh_name` varchar(40) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for team_stat
-- ----------------------------
DROP TABLE IF EXISTS `team_stat`;
CREATE TABLE `team_stat` (
  `id` int(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(40) DEFAULT NULL,
  `logo` mediumtext,
  `ppg` varchar(10) DEFAULT NULL,
  `lpg` varchar(10) DEFAULT NULL,
  `fga` varchar(11) DEFAULT NULL,
  `fgp` int(11) DEFAULT '0',
  `3pm` varchar(30) DEFAULT NULL,
  `3pa` varchar(30) DEFAULT NULL,
  `3pp` varchar(30) DEFAULT NULL,
  `fta` varchar(30) DEFAULT NULL,
  `ftm` varchar(30) DEFAULT NULL,
  `ftp` varchar(30) DEFAULT NULL,
  `defr` varchar(30) DEFAULT NULL,
  `offr` varchar(30) DEFAULT NULL,
  `apg` varchar(30) DEFAULT NULL,
  `spg` varchar(30) DEFAULT NULL,
  `bpg` varchar(30) DEFAULT NULL,
  `tpg` varchar(30) DEFAULT NULL,
  `fpg` varchar(30) DEFAULT NULL,
  `min` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for zhibo
-- ----------------------------
DROP TABLE IF EXISTS `zhibo`;
CREATE TABLE `zhibo` (
  `id` int(20) NOT NULL AUTO_INCREMENT,
  `tv_date` datetime DEFAULT NULL,
  `home` varchar(20) DEFAULT NULL,
  `away` varchar(20) DEFAULT NULL,
  `play_url` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

