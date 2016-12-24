
-- 每次升级都会进行重置的表 
-- DROP TABLE IF EXISTS `upgrade_running_table`;
-- CREATE TABLE `upgrade_running_table` (
--     `id` int(11) NOT NULL AUTO_INCREMENT primary key comment '升级临时记录表的主键', 
--     `sequence` int NOT NULL comment '升级顺序',
--     `ip` varchar(20) NOT NULL comment '待升级节点IP 地址', 
--     `check_flag` tinyint default 0 comment '升级步骤检查标识，0 ： 未执行，1:执行中，2：执行成功 ，-1：执行失败', 
--     `backup_flag` tinyint default 0 comment '升级步骤升级成功标识，0 ： 未执行，1：执行中，2：执行成功 ，-1：执行失败',
--     `upgrade_flag` tinyint default 0 comment '升级步骤升级成功标识，0 ： 未执行，1：执行中，2：执行成功 ，-1：执行失败'
-- ) ENGINE=MyISAM DEFAULT CHARSET=utf8 comment '升级临时记录表';

-- insert into `upgrade_running_table` values (NULL,1,'10.72.8.110',0,0,0),(NULL,1,'10.72.8.97',0,0,0);

-- 每次升级都会进行记录的表
DROP TABLE IF EXISTS `upgrade_record_table`;
CREATE TABLE `upgrade_record_table` (
    `id` int(11) NOT NULL AUTO_INCREMENT primary key, 
    `begin_time`  varchar(32) NOT NULL default '' comment '发布开始的时间,每个任务只有唯一的一个time', 
    `package_name` varchar(32) NOT NULL default '' comment '发布的包名称',
    `env_type` varchar(32) NOT NULL default '' comment '环境类型名称如tomcat',
    `action_name` varchar(32) NOT NULL default '' comment '运行发布的action 名称',
    `ip` varchar(32) NOT NULL comment '升级节点的IP地址,记录对应节点IP地址', 
    `check_flag` tinyint default 0 comment '升级步骤检查标识，0 ： 未执行，1:执行中，2：执行成功 ，-1：执行失败', 
    `backup_flag` tinyint default 0 comment '升级步骤备份标识，0 ： 未执行，1：执行中，2：执行成功 ，-1：执行失败', 
    `upgrade_flag` tinyint default 0 comment '升级步骤升级成功标识，0 ： 未执行，1：执行中，2：执行成功 ，-1：执行失败',
    `rollback_flag` tinyint default 0 comment '升级步骤升级成功标识，0 ： 未执行，1：执行中，2：执行成功 ，-1：执行失败',
    `rollback_to_version` varchar(32) NOT NULL default '' comment '如果是回滚，则此处为回滚的版本号，与begin_time 值类似',
    `restart_flag` tinyint default 0 comment '重启步骤，重启成功标识，0 ： 未执行，1：执行中，2：执行成功 ，-1：执行失败'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 comment '升级记录表';



