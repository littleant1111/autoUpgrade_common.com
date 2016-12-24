#!/bin/bash

#######     auto upgrade system  server  #####

if [ `echo "$0" |grep -c "/"` -gt 0 ];then
    cd ${0%/*}
fi

PROGRAM_DIR=`pwd`
cd ..
BASE_DIR=`pwd`
PROGRAM_NAME=`basename $0`
DATE=`date +'%Y%m%d_%H%M'`
TS=`date +%s`

TEMP_DIR=${BASE_DIR}/temp
LOG_DIR=${BASE_DIR}/log
CONFIG_DIR=${BASE_DIR}/conf
BIN_DIR=${BASE_DIR}/bin
INFO_DIR=${BASE_DIR}/info

RESULT_DIR=${TEMP_DIR}/result

. ${BASE_DIR}/bin/pub.lib


###############  config  ############################

#####  所有连接配置信息列表 ##########
ALL_CONNECT_FILE=${BASE_DIR}/conf/allconnect.conf

### 应用备份目录 #####
BACKUPAPP_BASE_DIR=/backupapp/test88/${DATE}_${TS}


##########  开始执行之前停顿时间 ############
sleepTimeToStart=2

##############  end of config #######################
LOG_FILE=${LOG_DIR}/${PROGRAM_NAME}.log
SERVER_SCRIPT=${BASE_DIR}/bin/server.sh
CLIENT_SCRIPT_NAME="autoUpgradeClient.sh"
SFTP_SCRIPT="${BIN_DIR}/execSftp.exp"

###########  连接配置信息 动态 自动生成，不需要配置##########
CON_FILE=${BASE_DIR}/conf/connect.conf

###############   客户端脚本的配置文件   自动生成 一般不需要配置 ###########
COF_FILE=${BASE_DIR}/conf/client.conf

#########    所有环境配置信息   ############
ALL_INFO_CONFIG=${BASE_DIR}/info/all.config

##### send email address 多个以,隔开 #####
EMAIL_ADDRESS="284373267@qq.com"

###  tomcat  所有的详细配置文件  ####
TOMCAT_DETAIL_FILE=${INFO_DIR}/tomcatdetailconfig.conf

####   本次运行所需的配置信息    ####
TOMCAT_USE_DETAIL_FILE=${INFO_DIR}/tomcatdetailconfig_use.conf

#####  sftp 配置文件  ####
SFTP_CONFIG_FILE=${BASE_DIR}/conf/sftp.conf

####   数据库配置文件  ####
DB_CONFIG_FILE=${CONFIG_DIR}/db.conf

#####  收集到的系统配置文件  动态生成 ####
SYSTEM_CONFIG_FILE=${CONFIG_DIR}/systeminfo.conf

##########  ${PROGRAM_NAME} running flag 程序运行的标识   #########
RUNNING_FLAG_FILE=${CONFIG_DIR}/${PROGRAM_NAME}_running.flag

########   同步文件，用于进行同步升级  ######
#SERIAL_FILE=${TEMP_DIR}/upgrade_serial.file

##########  operating all log ######
OPERATION_LOG_FILE=${LOG_DIR}/allOperate.log

main()
{
    if [ $# -lt 1 ];then
        showHelp
        return 1
    fi
    
    g_envName="$1"
    g_action="$2"
    g_packageName="$3"
    g_version="$4"
    
    ##### allpara  ###
    g_allpara=$*
    
    ###### 记录包对应的ip地址列表 ########
    g_ipAddresses=""
    
    ######### 判断是包或者 包列表 #######
    g_isPkgOrList=""   
    
    case "${g_envName}" in
     "-help"|"--help"|"-Help"|"--Help"|"-h"|"help")
        showHelp
        return 0
     ;; 
     check_configall|tomcat|all)
     ;;  
     *)
        log_echo "error" "$func" "g_envName parameter error. "
        showHelp
        return 1
     ;;      
    esac
    
    typeset eachAction=""
    case "${g_action}" in
     check_config_connect)
        checkBaseEnv || return 1
        checkParaEnv || return 1
        cat "${ALL_CONNECT_FILE}" > "${CON_FILE}"
        runServerScript "check"
        if [ $? -ne 0 ];then
            sendEmail "check config file failed,ip address: ${errorIpAddress},more log see ip addresses log file:${LOG_DIR}/${CLIENT_SCRIPT_NAME}.log" "${g_action} failed. " "${EMAIL_ADDRESS}"
        fi
        exitScriptWithSuccessed
        return 0
     ;;      
     check)
        checkRunEnv || return 1
        modifyConnectInfo "${g_envName}" || exitScriptWithFailed || return 1
        for  eachAction in "check"  "run";do
            runServerScript "${eachAction}" || exitScriptWithFailed || return 1
        done
        exitScriptWithSuccessed
        return 0        
     ;;      
     backup)
        checkRunEnv || return 1
        modifyConnectInfo "${g_envName}" || exitScriptWithFailed || return 1
        for  eachAction in "check"  "run";do
            runServerScript "${eachAction}" || exitScriptWithFailed || return 1
        done        
        exitScriptWithSuccessed
        return 0           
     ;;      
     upgrade)
        checkRunEnv || return 1
        modifyConnectInfo "${g_envName}" || exitScriptWithFailed || return 1
        for  eachAction in "check"  "run";do
            runServerScript "${eachAction}" || exitScriptWithFailed || return 1
        done        
        exitScriptWithSuccessed
        return 0          
     ;;     
     upgrade_serial)
        checkRunEnv || return 1
        modifyConnectInfo "${g_envName}" || exitScriptWithFailed || return 1
        #uploadSerialFileToSftpServer "${SFTP_CONFIG_FILE}"  "${SERIAL_FILE}"  "${SFTP_SCRIPT}"  || return 1
        for  eachAction in "check"  "run";do
            runServerScript "${eachAction}" || exitScriptWithFailed || return 1
        done        
        exitScriptWithSuccessed
        return 0          
     ;;       
     startup)
        checkRunEnv || return 1
        modifyConnectInfo "${g_envName}" || exitScriptWithFailed || return 1
        for  eachAction in "check"  "run";do
            runServerScript "${eachAction}" || exitScriptWithFailed || return 1
        done        
        exitScriptWithSuccessed
        return 0          
     ;;
     rollback)
        BACKUPAPP_BASE_DIR=`dirname "${BACKUPAPP_BASE_DIR}"`
        checkRunEnv || return 1
        modifyConnectInfo "${g_envName}" || exitScriptWithFailed || return 1
        for  eachAction in "check"  "run";do
            runServerScript "${eachAction}" || exitScriptWithFailed || return 1
        done        
        exitScriptWithSuccessed
        return 0          
     ;;
     rollback_serial)
        BACKUPAPP_BASE_DIR=`dirname "${BACKUPAPP_BASE_DIR}"`
        checkRunEnv || return 1
        modifyConnectInfo "${g_envName}" || exitScriptWithFailed || return 1
        #uploadSerialFileToSftpServer "${SFTP_CONFIG_FILE}"  "${SERIAL_FILE}"  "${SFTP_SCRIPT}"  || return 1
        for  eachAction in "check"  "run";do
            runServerScript "${eachAction}" || exitScriptWithFailed || return 1
        done        
        exitScriptWithSuccessed
        return 0          
     ;;
     restart)
        checkRunEnv || return 1
        modifyConnectInfo "${g_envName}" || exitScriptWithFailed || return 1
        for  eachAction in "check"  "run";do
            runServerScript "${eachAction}" || exitScriptWithFailed || return 1
        done        
        exitScriptWithSuccessed
        return 0          
     ;;  
     restart_serial)
        checkRunEnv || return 1
        modifyConnectInfo "${g_envName}" || exitScriptWithFailed || return 1
        for  eachAction in "check"  "run";do
            runServerScript "${eachAction}" || exitScriptWithFailed || return 1
        done        
        exitScriptWithSuccessed
        return 0          
     ;;      
     stop)
        checkRunEnv || return 1
        modifyConnectInfo "${g_envName}" || exitScriptWithFailed || return 1
        for  eachAction in "check"  "run";do
            runServerScript "${eachAction}" || exitScriptWithFailed || return 1
        done        
        exitScriptWithSuccessed
        return 0          
     ;;      
     cleanup)
        checkRunEnv || return 1
        modifyConnectInfo "${g_envName}" || exitScriptWithFailed || return 1
        for  eachAction in "check"  "run";do
            runServerScript "${eachAction}" || exitScriptWithFailed || return 1
        done        
        exitScriptWithSuccessed
        return 0          
     ;;             
     stop_clientscript)
        log_echo "aaaaaaaaa "
        return 0          
     ;;  
     *)
        log_echo "error" "$func" "g_action parameter error. "
        showHelp
        exitScriptWithFailed || return 1
     ;; 
    esac      
}

##########  run server.sh script run|check  #######
runServerScript()
{
    typeset func=runServerScript
    if [ $# -ne 1 ];then
        log_echo "error" "${func}" "Parameter error usage : ${func}  [check|run]"
        return 1
    fi        
    log_echo "info" "$func" "Enter $func with successed ."
    typeset check_or_run="$1"
    
    bash ${SERVER_SCRIPT} ${check_or_run}
    if [ $? -ne 0 ];then
        typeset upgradeclientName=`echo "${CLIENT_SCRIPT_NAME}" | awk -F'.' '{print $1}'`
        typeset tmpfile=/tmp/${func}.tmp
        typeset eachFile=""
        > ${tmpfile}
        cd ${RESULT_DIR} && find ${RESULT_DIR} -maxdepth 1 -name "*_${upgradeclientName}.tar.gz" > ${tmpfile}
        if [ -s "${tmpfile}" ];then
            while read eachFile;do
                typeset filename=`basename ${eachFile}`
                typeset readyToCreateDirName=`echo "${filename}" | awk -F'_' '{print $1}'`
                typeset createDir="${RESULT_DIR}/${readyToCreateDirName}"
                mkdir -p "${createDir}"  && mv ${eachFile} ${createDir} && cd ${createDir} && tar -zxf ${createDir}/${filename}
                if [ $? -ne 0 ];then
                    log_echo "error" "${func}" "Command exec failed. CMD=[   mkdir -p "${createDir}"  && mv ${eachFile} ${createDir} && cd ${createDir} && tar -zxf ${createDir}/${filename}   ]  "
                    return 1
                fi
                rm -f ${createDir}/${filename}
                typeset remoteIP="`echo "${readyToCreateDirName}" | awk -F'_' '{print $1}'`"
                log_echo "remoteIP:[ ${remoteIP} ] error log :"
                grep -w "error" ${createDir}/${CLIENT_SCRIPT_NAME}.log | tail -1 
                log_echo "error" "$func" "More log see file:[   ${createDir}/${CLIENT_SCRIPT_NAME}.log   ]"
            done <${tmpfile}
        fi
        
        rm -f ${tmpfile} 
        return 1
    fi
    log_echo "info" "$func" "Exit $func with successed."
    return 0   
}

###### cleanup temp files ##########
cleanupTempFile()
{
    typeset func=cleanupTempFile
    typeset eachTempFiles=""
    for eachTempFiles in "${TOMCAT_DETAIL_FILE}";do
        typeset FileName="`basename "${eachTempFiles}"`"
        typeset tempFile="${BIN_DIR}/client/${FileName}"
        if [ -f "${tempFile}" ];then
            rm -f "${tempFile}"
        fi
    done
    
    rm -f "${BASE_DIR}/nohup.out"
    rm -rf "${TEMP_DIR}"
    log_echo "info" "$func" "Exit $func with successed."
    return 0    
}

checkBaseEnv()
{
    typeset func=checkBaseEnv
    typeset flag=0 
    typeset eachDir=""
    typeset eachScript=""
    typeset eachCheckFile=""
    log_echo "info" "$func" "Enter $func with successed."
    for eachDir in ${TEMP_DIR}  ${LOG_DIR}  ${CONFIG_DIR}  ${BIN_DIR}  ${INFO_DIR};do
        mkdir -p ${eachDir}
        if [ $? -ne 0 ];then
            log_echo "error" "Command is error,CMD = [     mkdir -p ${eachDir}    ]"
            flag=1    
        fi
    done
    if [ ! -f "${LOG_FILE}" ];then
        touch ${LOG_FILE} && chmod 666 ${LOG_FILE}
        if [ $? -ne 0 ];then
            log_echo "error" "Command is error,CMD = [     touch ${LOG_FILE} && chmod 666 ${LOG_FILE}     ]"
            flag=1    
        fi
    fi
    for eachScript in ${SERVER_SCRIPT} ${SFTP_SCRIPT};do
        chmod +x ${eachScript}
        if [ $? -ne 0 ];then
            log_echo "error" "Command is error,CMD = [      chmod +x ${eachScript}     ]"
            flag=1    
        fi        
    done    
    
    checkFilesExists  "${TOMCAT_DETAIL_FILE}" "${SFTP_CONFIG_FILE}"  "${DB_CONFIG_FILE}" || flag=1 
    
    if [ "${g_packageName}" != "none" ];then
        accordPkgGetConfigItemToFile "${g_packageName}"  "${TOMCAT_DETAIL_FILE}"  "${TOMCAT_USE_DETAIL_FILE}" || flag=1
    fi
    ####### synchronization detail config to client directory ,so server.sh will copy files to remote host ######
    cp -f  ${INFO_DIR}/*  "${BIN_DIR}/client"
    typeset eachDetailFile=""
    for eachDetailFile in "${SFTP_CONFIG_FILE}" "${SFTP_SCRIPT}"  "${DB_CONFIG_FILE}";do
        cp -f "${eachDetailFile}" "${BIN_DIR}/client"
    done    
    installExpect "/tmp/$func.tmp" || flag=1 
    
    if [ "${flag}" -ne "0" ];then
        log_echo "error" "$func" "Exit $func failed . please see before messages ."
        return 1
    fi 
    log_echo "info" "$func" "Exit $func with successed."
    return 0
}

checkParaEnv()
{
    typeset func=checkParaEnv
    typeset flag=0 
    log_echo "info" "$func" "Enter $func with successed."
    ########  check parameter1   ###########
    case "${g_envName}" in
     tomcat)
        log_echo "info" "$func" "You choice g_envName:[  ${g_envName}  ] ."
     ;;
    all)
        case "${g_action}" in
        backupall|guanghua888test|stop_clientscript)
            log_echo "info" "$func" "You choice g_action ."
         ;; 
          *)
            log_echo "error" "$func" "Parameter error ."
            return 1      
         ;;
        esac                
     ;;
    check_configall)
        case "${g_action}" in
          check_config_connect)
            log_echo "info" "$func" "You choice g_action ."
            if [ "${g_packageName}" != "none" ];then
                log_echo "error" "$func" "Parameter error , package must be [ none ] to check config file ."
                return 1
            else
                return 0
            fi
         ;; 
          *)
            log_echo "error" "$func" "Parameter error ."
            return 1      
         ;;
        esac                
     ;;     
      *)
        log_echo "error" "$func" "Parameter error ."
        return 1      
     ;;  
     esac
    
    ########  check parameter3   ###########
    if [ "${g_packageName}" = "all" ];then
        log_echo "info" "$func" "all parameter will backup all."
    else
        isPkgOrList="pkg"
    fi
    
    if [ ${flag} -ne 0 ];then
        log_echo "error" "$func" "Exit $func failed.please check."
        return 1
    fi     
    log_echo "info" "$func" "Exit $func with successed."
    return 0
}

checkRunEnv()
{
    typeset func=checkRunEnv
    typeset flag=0
    checkBaseEnv || return 1
    checkParaEnv || return 1
    
    #### record operate  ###
    recordOperateLog
    
    ### get system info ###
    getSystemInfoToConfig "${SYSTEM_CONFIG_FILE}" || return 1
    
    ##########  check muti line run   ##########
    if [ ! -f "${RUNNING_FLAG_FILE}" ];then
        echo "${PROGRAM_NAME} isrunning" > ${RUNNING_FLAG_FILE}
    else
        typeset isrunStr=`head -1 ${RUNNING_FLAG_FILE} | awk '{print $2}'`
        if [ "${isrunStr}" = "isrunning" ];then
            log_echo "error" "$func" "Another program :[ ${PROGRAM_NAME}  ] is running , please check." 
            log_echo "error" "$func" "Please remove flag file :[  ${RUNNING_FLAG_FILE}   ] and run again." 
            flag=1
        fi
    fi
    
    if [ "${isPkgOrList}" != "pkg" ];then
        log_echo "info" "$func" "is not a pkg or new function is devoloping.."
        flag=1
    fi
    
    checkSftpConfig  "${SFTP_SCRIPT}"   "${SFTP_CONFIG_FILE}"   "${g_packageName}" "${TEMP_DIR}" || flag=1
    if [ "${flag}" -ne "0" ];then
        log_echo "error" "$func" "Exit $func failed.please check."
        return 1
    fi 
    checkDbConfigFile  "${DB_CONFIG_FILE}"  || flag=1
    ##>${SERIAL_FILE}
    #### record id to file ####
    echo "${DATE}_${TS}" > ${LOG_DIR}/runid.log
    log_echo "info" "$func" "Exit $func with successed."
    return 0
}

### 动态修改连接配置信息，根据服务端根据配置连接到远程机器  ##########
modifyConnectInfo()
{
    typeset func=modifyConnectInfo
    ####  跟据包名得到IP地址列表 ##########
    if [ $# -ne 1 ];then
        log_echo "error" "${func}" "Parameter error usage : ${func}  envtype "
        log_echo "error" "${func}" "You can use like: ${func}  [tomcat|php|..]"
        return 1
    fi
    log_echo "info" "$func" "Enter $func with successed."
    
    typeset envtype=$1
    typeset eachIP=""
    typeset i=1
    typeset recordsql=${TEMP_DIR}/record.sql
    typeset outrecordfile=${TEMP_DIR}/recordsql.tmp
    > ${recordsql}
    case "${envtype}" in
     tomcat)
        accordPkgNameEnvNameGetIpAddress  "${TOMCAT_DETAIL_FILE}"  "${g_packageName}"  || return 1
        typeset ipAddresses="${RETURN[0]}"    
        >"${CON_FILE}"
        for eachIP in `echo "${ipAddresses}"`;do
            ######## 动态生成配置文件 ############
            modifyConnectConfigFile "${ALL_CONNECT_FILE}" "${CON_FILE}"  "${eachIP}" ||  return 1
            if [ -z "${g_version}" ];then
                g_version="none"
            fi
            #if [ "${g_action}" = "upgrade_serial"  -o  "${g_action}" = "rollback_serial"  ];then
            #    echo "${eachIP} unknow" >> ${SERIAL_FILE}
            #fi
            if [ "${g_action}" = "check"  -o  "${g_action}" = "backup" -o  "${g_action}" = "upgrade" -o  "${g_action}" = "upgrade_serial" -o "${g_action}" = "rollback" -o "${g_action}" = "rollback_serial" -o  "${g_action}" = "restart_serial" ];then
                echo "insert into upgrade_record_table values (NULL,'${DATE}_${TS}','${g_packageName}','${g_envName}','${g_action}','${eachIP}',0,0,0,0,'',0);" >> ${recordsql}
            fi
            i=`expr $i + 1 `
        done      
        execSqlToFile  "${DB_CONFIG_FILE}"  "${recordsql}"  "${outrecordfile}" || return 1
     ;;       
      *)
        log_echo "error" "$func" "envtype:[  ${envtype}  ] error or not support." 
        return 1
     ;; 
    esac    
    modifyClientConfigFile ${COF_FILE}  ${CLIENT_SCRIPT_NAME}  YES  ${g_action}   ${g_packageName}   "${BACKUPAPP_BASE_DIR}"  ${g_envName}  ${DATE}_${TS}  ${g_version} || return 1
    log_echo "info" "$func" "Exit $func with successed."
    return 0
}

##### 根据 包名 得到对应配置信息   #####
accordPkgGetConfigItemToFile()
{
    typeset func=accordPkgGetConfigItemToFile
    if [ $# -ne 3 ];then
        log_echo "error" "${func}" "Parameter error usage : ${func}  pkgname  detailconfigfile "
        log_echo "error" "${func}" "You can use like: ${func}  me.war ${TOMCAT_DETAIL_FILE}"
        return 1
    fi
    log_echo "info" "$func" "Enter $func with successed."
    typeset pkgname="$1"
    typeset detailconfigfile="$2"
    typeset newdetailconfigfile="$3"
    typeset tmpFile="/tmp/$func.tmp"
    
    grep "^${pkgname}_"  "${detailconfigfile}"   > ${newdetailconfigfile} 
    if [ $? -ne 0 ];then
        log_echo "error" "${func}" "Can not get config to new config file.CMD=[  grep "^${pkgname}_"  "${detailconfigfile}"   > ${newdetailconfigfile}     ]"
        return 1
    fi
    log_echo "info" "$func" "Exit $func with successed."
    return 0
}

##### check url can open #########
##### config file line like:  prefixpkgname ipaddress urls  #########
checkUrlCanOpenFromConfigFile()
{
    typeset func=checkUrlCanOpenFromConfigFile
    if [ $# -ne 2 ];then
        log_echo "error" "${func}" "Parameter error usage : ${func}  pkgIpUrlsConfigFile errorUrlFile"
        return 1
    fi      
    typeset pkgIpUrlsConfigFile="$1"
    typeset newErrorPkgIpUrlFile="$2"
    checkFileExists "${pkgIpUrlsConfigFile}" || return 1
    if [ ! -s "${pkgIpUrlsConfigFile}" ];then
        log_echo "error" "$func" "File is null file:[ ${pkgIpUrlsConfigFile} ] ,please check ." 
        return 1        
    fi
    cat "${pkgIpUrlsConfigFile}" | while read eachPrefixPkgName eachIP eachusls;do
        if [ -z "${eachusls}" ];then
            continue
        fi
        typeset eachUrl=""
        typeset tmpstr=`echo "${eachusls}" | grep "@"`
        if [ -z "${tmpstr}" ];then
            canOpenUrl "${eachusls}"
            if [ $? -ne 0 ];then
                echo "${eachPrefixPkgName}  ${eachIP}" >> ${newErrorPkgIpUrlFile}
            fi
        else
            for eachUrl in `echo "${eachusls}" | tr -s "@" "  "`;do
                canOpenUrl "${eachUrl}"
                if [ $? -ne 0 ];then
                    echo "${eachPrefixPkgName}  ${eachIP}" >> ${newErrorPkgIpUrlFile}
                fi
            done        
        fi
    done
    
    sort -u ${newErrorPkgIpUrlFile} | uniq >${newErrorPkgIpUrlFile}.use
    cp -f ${newErrorPkgIpUrlFile}.use ${newErrorPkgIpUrlFile}
    rm -f ${newErrorPkgIpUrlFile}.use
    log_echo "info" "$func" "Exit $func with successed."
    return 0 
}

####### send to remote host check url  ###
accordErrorUrlSendRometeHost()
{
    typeset func=accordErrorUrlSendRometeHost
    if [ $# -ne 2 ];then
        log_echo "error" "${func}" "Parameter error usage : ${func}  ErrorPkgIpUrlFile notCheckPackageListFile"
        return 1
    fi      
    typeset ErrorPkgIpUrlFile="$1"
    typeset notCheckPackageListFile="$2"
    
    if [ ! -s "${ErrorPkgIpUrlFile}" ];then
        log_echo "info" "$func" "ALL url is right..."
        return 0
    fi
    while read prefixPkgName ipaddr;do
        typeset pkgname="${prefixPkgName}.war"
        if [ -f "${notCheckPackageListFile}" -a -s "${notCheckPackageListFile}" ];then
            if [ "`grep -c "${pkgname}" "${notCheckPackageListFile}"`" -gt 0 ];then
                continue
            fi
        fi
        ######## 修改配置文件############
        > ${CON_FILE}
        modifyConnectConfigFile "${ALL_CONNECT_FILE}" "${CON_FILE}"  "${ipaddr}" ||  return 1
        if [ -z "${g_version}" ];then
            g_version="none"
        fi
        modifyClientConfigFile ${COF_FILE}  ${CLIENT_SCRIPT_NAME}  YES  ${g_action}   ${pkgname}   "${BACKUPAPP_BASE_DIR}"  ${g_envName}  ${DATE}_${TS}  ${g_version} || return 1
        #### mutiline run  #######
        runServerScript "check" 
        runServerScript "run" 
    done < ${ErrorPkgIpUrlFile}
    log_echo "info" "$func" "Exit $func with successed."
    return 0
}

##### exit with falied ####
exitScriptWithFailed()
{
    typeset func=exitScriptWithFailed
    typeset stime=`date +%Y-%m-%d-%H:%M:%S`
    typeset execuser=`whoami`
    typeset execip=`who im i | awk '{print $NF}' | tr -s '(' " " | tr -s ")" " "`    
    rm -f ${RUNNING_FLAG_FILE}
    echo "${stime} ${execuser} ${execip} ${PROGRAM_NAME} ${g_allpara} exec_failed" >> ${OPERATION_LOG_FILE}
    return 1
}

exitScriptWithSuccessed()
{
    typeset func=exitScriptWithSuccessed
    typeset stime=`date +%Y-%m-%d-%H:%M:%S`
    typeset execuser=`whoami`
    typeset execip=`who im i | awk '{print $NF}' | tr -s '(' " " | tr -s ")" " "`
    echo "${stime} ${execuser} ${execip} ${PROGRAM_NAME} ${g_allpara} exec_successed" >> ${OPERATION_LOG_FILE}
    rm -f ${RUNNING_FLAG_FILE}
    cleanupTempFile
    return 0
}

#### record operate log #######
recordOperateLog()
{
    typeset func=recordOperateLog
    typeset stime=`date +%Y-%m-%d-%H:%M:%S`
    typeset execuser=`whoami`
    typeset execip=`who im i | awk '{print $NF}' | tr -s '(' " " | tr -s ")" " "`
    if [ ! -f "${OPERATION_LOG_FILE}" ];then
        echo "${stime} ${execuser} ${execip} ${PROGRAM_NAME} ${g_allpara} beginrun" >  ${OPERATION_LOG_FILE}
    else
        echo "${stime} ${execuser} ${execip} ${PROGRAM_NAME} ${g_allpara} beginrun" >> ${OPERATION_LOG_FILE}
    fi
}

#####  show how to use the script  ########
showHelp()
{

cat << EOF
  
This script is used to auto danymic deal you system.

USAGE: ${PROGRAM_NAME} [-help|--help] 

OPTIONS:
   
  para1: [help|sc|all]:          preproduct env  or   product env 
        --help| -help :                  Display this help
            sc :                         product env
         tomcat:                         tomcat env
            all:                         backup all system, glassfish will backup  /glassfish 
                                                 was will backup  /wasprofiles
                                                 tomcat will backup  /usr/local/tomcat7*
 check_configall:              check config file:[ ${ALL_CONNECT_FILE}  ] connect                                                  
 
                                                          
  para2 g_action                        accord you choice to use.
            check_config_connect:         check config file:[ ${ALL_CONNECT_FILE}  ] connect is right
            check     :                   check system env is right
            backup    :                   backup system.acord you package.
            backupall :                   backup all system, para1 must be all.
            upgrade   :                   upgrade system, acord you package and sc
            startup   :                   start package aplication, parallel or serial
                                          acord you package and sc
                                          is parallel startup.
                                          sc(product) is serial startup.
            rollback  :                   rollback package aplication
            restart   :                   restart package application. 
            stop      :                   restart package application.
            cleanup   :                   cleanup package application.and some temp files 
              
  para3 package|a.list                accord you choice to use.
            xx.war    :                   deal this package, accord you parameter1 and parameter2
            xx.list   :                   a list file, like this:
                                              a.war
                                              b.war
                                              c.war
            all       :                   backup all system, para1 must be all ,para2 must be [backupall|backup_d01|backup_dm]
            none      :                   not include package
            
  para4  g_version number(Optional):    this choice is for para2 is rollback use
                                        rollback this g_version : "20150602_2010_1433247002"

EXAMPLE: 
EOF

typeset demoPkg=xx.war
echo -e "show how to use script"
echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME} [--help|-help|help] \033[0m"
echo ""
echo -e "check all config is right."
echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME}   check_configall   check_config_connect   none  \033[0m"
echo ""
echo -e "check config right and run env is right."
echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME}   tomcat   check   ${demoPkg}  \033[0m"
echo ""
echo -e "backup ${demoPkg} package."
echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME}   tomcat   backup   ${demoPkg}     \033[0m"
echo ""
#echo -e "backup all system."
#echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME}   all   backupall   all  \033[0m"
#echo ""
echo -e "upgrade ${demoPkg} package."
echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME}   tomcat   upgrade   ${demoPkg}     \033[0m"
echo ""
echo -e "serial upgrade  ${demoPkg} package."
echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME}   tomcat   upgrade_serial   ${demoPkg}     \033[0m"
echo ""
echo -e "startup ${demoPkg} package,if program is started, will not deal ."
echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME}   tomcat   startup   ${demoPkg}     \033[0m"
echo ""
echo -e "restart ${demoPkg} package,if program is started, will stop it ,and then startup parallel"
echo -e "                         if program is not started, will start it parallel "
echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME}  tomcat   restart   ${demoPkg}     \033[0m"
echo ""
echo -e "restart ${demoPkg} package serial "
echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME}  tomcat   restart_serial   ${demoPkg}     \033[0m"
echo ""
echo -e "stop ${demoPkg} package,if program is started, will stop it."
echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME}  tomcat   stop   ${demoPkg}     \033[0m"
echo ""
echo -e "rollbak ${demoPkg} package,rollback to a g_version,"
echo -e "                           accord to para4 if para4 is null will rollback the latest g_version."
echo -e " rollback to latest g_version:"
echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME}  tomcat   rollback   ${demoPkg}     \033[0m"
echo ""
echo -e " rollback to g_version 20150602_2010_1433247002 :"
echo -e "\033[32m  ${PROGRAM_DIR}/${PROGRAM_NAME}  tomcat   rollback   ${demoPkg}   20150602_2010_1433247002  \033[0m"
echo -e "if you want to know more about g_version ,can goto directory : [   `dirname ${BACKUPAPP_BASE_DIR}`    ],run command [   ls -l   ]"
echo ""
echo -e "check xx.war package url can open? if not open, then auto restart app, if can open ,not deal. "
echo ""


showWarInHelp
echo ""
echo -e "Support package tomcat war is : \033[32m   ${RETURN[1]}    \033[0m"
echo ""
echo -e "if you want to add package , you can config file :[  \033[32m   ${TOMCAT_DETAIL_FILE} \033[0m   ]  "
echo ""
echo -e "if you want to config user and passwd in config file:[  \033[32m   ${ALL_CONNECT_FILE} \033[0m   ]  "
    return 0
}

showWarInHelp()
{
    typeset func=showWarInHelp
    typeset connFile="${TOMCAT_DETAIL_FILE}"
    if [ -f "${connFile}" ];then
        typeset tmpWar=""
        typeset alltomcatWar=`awk -F'_' '{print $1}' ${connFile} | sort -u | uniq`
        for tmpWar in `echo "${alltomcatWar}"`;do
            if [ -z "${tmpWar}" ];then
                RETURN[1]="${tmpWar}"
            else
                RETURN[1]="${RETURN[1]}   ${tmpWar}"
            fi            
        done        
    fi
}

main $*