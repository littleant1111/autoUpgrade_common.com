
-- ÿ����������������õı� 
-- DROP TABLE IF EXISTS `upgrade_running_table`;
-- CREATE TABLE `upgrade_running_table` (
--     `id` int(11) NOT NULL AUTO_INCREMENT primary key comment '������ʱ��¼�������', 
--     `sequence` int NOT NULL comment '����˳��',
--     `ip` varchar(20) NOT NULL comment '�������ڵ�IP ��ַ', 
--     `check_flag` tinyint default 0 comment '�����������ʶ��0 �� δִ�У�1:ִ���У�2��ִ�гɹ� ��-1��ִ��ʧ��', 
--     `backup_flag` tinyint default 0 comment '�������������ɹ���ʶ��0 �� δִ�У�1��ִ���У�2��ִ�гɹ� ��-1��ִ��ʧ��',
--     `upgrade_flag` tinyint default 0 comment '�������������ɹ���ʶ��0 �� δִ�У�1��ִ���У�2��ִ�гɹ� ��-1��ִ��ʧ��'
-- ) ENGINE=MyISAM DEFAULT CHARSET=utf8 comment '������ʱ��¼��';

-- insert into `upgrade_running_table` values (NULL,1,'10.72.8.110',0,0,0),(NULL,1,'10.72.8.97',0,0,0);

-- ÿ������������м�¼�ı�
DROP TABLE IF EXISTS `upgrade_record_table`;
CREATE TABLE `upgrade_record_table` (
    `id` int(11) NOT NULL AUTO_INCREMENT primary key, 
    `begin_time`  varchar(32) NOT NULL default '' comment '������ʼ��ʱ��,ÿ������ֻ��Ψһ��һ��time', 
    `package_name` varchar(32) NOT NULL default '' comment '�����İ�����',
    `env_type` varchar(32) NOT NULL default '' comment '��������������tomcat',
    `action_name` varchar(32) NOT NULL default '' comment '���з�����action ����',
    `ip` varchar(32) NOT NULL comment '�����ڵ��IP��ַ,��¼��Ӧ�ڵ�IP��ַ', 
    `check_flag` tinyint default 0 comment '�����������ʶ��0 �� δִ�У�1:ִ���У�2��ִ�гɹ� ��-1��ִ��ʧ��', 
    `backup_flag` tinyint default 0 comment '�������豸�ݱ�ʶ��0 �� δִ�У�1��ִ���У�2��ִ�гɹ� ��-1��ִ��ʧ��', 
    `upgrade_flag` tinyint default 0 comment '�������������ɹ���ʶ��0 �� δִ�У�1��ִ���У�2��ִ�гɹ� ��-1��ִ��ʧ��',
    `rollback_flag` tinyint default 0 comment '�������������ɹ���ʶ��0 �� δִ�У�1��ִ���У�2��ִ�гɹ� ��-1��ִ��ʧ��',
    `rollback_to_version` varchar(32) NOT NULL default '' comment '����ǻع�����˴�Ϊ�ع��İ汾�ţ���begin_time ֵ����',
    `restart_flag` tinyint default 0 comment '�������裬�����ɹ���ʶ��0 �� δִ�У�1��ִ���У�2��ִ�гɹ� ��-1��ִ��ʧ��'
) ENGINE=MyISAM DEFAULT CHARSET=utf8 comment '������¼��';



