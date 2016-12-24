#!/bin/bash


#######     auto upgrade system   #####



if [ `echo "$0" |grep -c "/"` -gt 0 ];then
    cd ${0%/*}
fi

PROGRAM_DIR=`pwd`
cd ..
BASE_DIR=`pwd`
PROGRAM_NAME=`basename $0`

. ${BASE_DIR}/bin/pub.lib

#DATE=`date +'%Y%m%d_%H%M'`
#TS=`date +%s`

TEMP_DIR=${BASE_DIR}/temp
LOG_DIR=${BASE_DIR}/log
CONFIG_DIR=${BASE_DIR}/conf
BIN_DIR=${BASE_DIR}/bin

######   log file  #####
LOG_FILE=${LOG_DIR}/${PROGRAM_NAME}.log

###  tomcat 配置文件  ####
#TOMCAT_DETAIL_FILE=${CONFIG_DIR}/tomcatdetailconfig.conf

####   本次运行所需的配置信息    ####
TOMCAT_USE_DETAIL_FILE=${CONFIG_DIR}/tomcatdetailconfig_use.conf

#####  sftp 配置文件  ####
SFTP_CONFIG_FILE=${BASE_DIR}/conf/sftp.conf

####   数据库配置文件  ####
DB_CONFIG_FILE=${CONFIG_DIR}/db.conf

########  sftp expect 交互脚本 ##########
SFTP_SCRIPT=${BIN_DIR}/execSftp.exp

#####  收集到的系统配置文件  动态生成 ####
SYSTEM_CONFIG_FILE=${CONFIG_DIR}/systeminfo.conf

######### 从sftp 上下载的war包存放目录 需要配置 #######
UPGRADE_PKG_DIR=/home/upgrade

########   同步文件，用于进行同步升级  ######
#SERIAL_FILE=${TEMP_DIR}/upgrade_serial.file
SERIAL_FILE_FOR_SQL=${TEMP_DIR}/upgrade_serial2.file
SERIAL_FILE_FOR_SQL_ROLLBACK=${TEMP_DIR}/rollback_serial2.file

###  超时时间 #######
EXPIRE_TIME=720

main()
{
    resultFileDir="$1"
    
    action="$2"
    package="$3"
    envName="$4"
    backupDir="$5"
    DATE_TS="$6"
    version="$7"
    
    typeset downloadPkgDir="${UPGRADE_PKG_DIR}/${DATE_TS}"
    typeset stepsql=${TEMP_DIR}/step.sql
    typeset outstepfile=${TEMP_DIR}/outstep.tmp
    case "${action}" in
     "-help"|"--help"|"-Help"|"--Help"|"-h")
        showHelp
        return 0
     ;; 
     check)
        log_echo ""
        log_echo "start $action ...."
        checkEnv || return 1
        updateFlagToSql "check_flag"  "${DATE_TS}"  "1"  "${stepsql}"  "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        checkApp "${TOMCAT_USE_DETAIL_FILE}"  "${package}"  "${SYSTEM_CONFIG_FILE}"  "2" 
        if [ $? -ne 0 ];then
            updateFlagToSql "check_flag"  "${DATE_TS}"  "-1"  "${stepsql}"  "${outstepfile}"  || return 1
            return 1
        else
            setFlag "check_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "check_flag"  "${DATE_TS}"  "2"  "${stepsql}"   "${DB_CONFIG_FILE}"   "${outstepfile}"  || return 1
        fi
        return 0
     ;;      
     backup)
        log_echo ""
        log_echo "start $action ...."
        checkEnv || return 1
        updateFlagToSql "check_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        checkApp "${TOMCAT_USE_DETAIL_FILE}"  "${package}"  "${SYSTEM_CONFIG_FILE}"  "2" 
        if [ $? -ne 0 ];then
            updateFlagToSql "check_flag"  "${DATE_TS}"  "-1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
            return 1
        else
            setFlag "check_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "check_flag"  "${DATE_TS}"  "2"  "${stepsql}"    "${DB_CONFIG_FILE}"   "${outstepfile}"  || return 1
        fi
        
        log_echo "info" "$func" "Check other machine step : [  check   ]   run successed .  "        
        echo "select check_flag from upgrade_record_table where begin_time='${DATE_TS}';" > ${stepsql}
        waitStepSynchro "${DB_CONFIG_FILE}"  "${stepsql}"  "${outstepfile}"  "${EXPIRE_TIME}" || return 1 
        log_echo ""
        updateFlagToSql "backup_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        backupApp "${backupDir}"  "${package}"  "${SYSTEM_CONFIG_FILE}"   "${envName}"
        if [ $? -ne 0 ];then
            updateFlagToSql "backup_flag"  "${DATE_TS}"  "-1"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
            return 1
        else
            setFlag "backup_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "backup_flag"  "${DATE_TS}"  "2"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        fi
        return 0
     ;;  
     backupall)
        log_echo "start $action is developing ...."
        return 0
     ;;                       
     upgrade)
        log_echo ""
        log_echo "start $action ...."
        checkEnv || return 1
        updateFlagToSql "check_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        checkApp "${TOMCAT_USE_DETAIL_FILE}"  "${package}"  "${SYSTEM_CONFIG_FILE}"  "2" 
        if [ $? -ne 0 ];then
            updateFlagToSql "check_flag"  "${DATE_TS}"  "-1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
            return 1
        else
            setFlag "check_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "check_flag"  "${DATE_TS}"  "2"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        fi
        
        log_echo "info" "$func" "Check other machine step : [  check   ]   run successed .  "        
        echo "select check_flag from upgrade_record_table where begin_time='${DATE_TS}';" > ${stepsql}
        waitStepSynchro "${DB_CONFIG_FILE}"  "${stepsql}"  "${outstepfile}"  "${EXPIRE_TIME}" || return 1 
        log_echo ""
        updateFlagToSql "backup_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        backupApp "${backupDir}"  "${package}"  "${SYSTEM_CONFIG_FILE}"   "${envName}"
        if [ $? -ne 0 ];then
            updateFlagToSql "backup_flag"  "${DATE_TS}"  "-1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
            return 1
        else
            setFlag "backup_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "backup_flag"  "${DATE_TS}"  "2"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        fi
        
        log_echo "info" "$func" "Check other machine step : [  check   ]  and [  backup   ]  run successed .  "        
        echo "select check_flag,backup_flag from upgrade_record_table where begin_time='${DATE_TS}'" > ${stepsql}
        waitStepSynchro "${DB_CONFIG_FILE}"  "${stepsql}"  "${outstepfile}"  "${EXPIRE_TIME}" || return 1 
        log_echo ""
        updateFlagToSql "upgrade_flag"  "${DATE_TS}"  "1"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
        upgradeApp "${UPGRADE_PKG_DIR}/${DATE_TS}/${package}"  "${SYSTEM_CONFIG_FILE}"  "${backupDir}"    "${envName}" 
        if [ $? -ne 0 ];then
            updateFlagToSql "upgrade_flag"  "${DATE_TS}"  "-1"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
            return 1
        else
            setFlag "upgrade_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "upgrade_flag"  "${DATE_TS}"  "2"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
        fi
        log_echo "info" "$func" "upgrade successed ,ip: [  ${localip}   ] ."
        return 0
     ;;     
     upgrade_serial)
        log_echo ""
        log_echo "start $action ...."
        checkEnv || return 1
        updateFlagToSql "check_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        checkApp "${TOMCAT_USE_DETAIL_FILE}"  "${package}"  "${SYSTEM_CONFIG_FILE}"  "2" 
        if [ $? -ne 0 ];then
            updateFlagToSql "check_flag"  "${DATE_TS}"  "-1"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
            return 1
        else
            setFlag "check_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "check_flag"  "${DATE_TS}"  "2"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        fi
        
        log_echo "info" "$func" "Check other machine step : [  check   ]   run successed .  "        
        echo "select check_flag from upgrade_record_table where begin_time='${DATE_TS}';" > ${stepsql}
        waitStepSynchro "${DB_CONFIG_FILE}"  "${stepsql}"  "${outstepfile}"  "${EXPIRE_TIME}" || return 1 
        log_echo ""
        updateFlagToSql "backup_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        backupApp "${backupDir}"  "${package}"  "${SYSTEM_CONFIG_FILE}"   "${envName}"
        if [ $? -ne 0 ];then
            updateFlagToSql "backup_flag"  "${DATE_TS}"  "-1"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
            return 1
        else
            setFlag "backup_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "backup_flag"  "${DATE_TS}"  "2"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
        fi
        
        log_echo "info" "$func" "Check other machine step : [  check   ]  and [  backup   ]  run successed .  "        
        echo "select check_flag,backup_flag from upgrade_record_table where begin_time='${DATE_TS}';" > ${stepsql}
        waitStepSynchro "${DB_CONFIG_FILE}"  "${stepsql}"  "${outstepfile}"  "${EXPIRE_TIME}" || return 1 
        log_echo ""
        updateFlagToSql "upgrade_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        upgradeAppSerialBySql "${downloadPkgDir}/${package}"  "${DB_CONFIG_FILE}"  "${EXPIRE_TIME}"   "${SERIAL_FILE_FOR_SQL}"  "${SYSTEM_CONFIG_FILE}"   "${DATE_TS}"   "${backupDir}"   "${envName}" || return 1 
        log_echo "info" "$func" "upgrade successed ,ip: [  ${localip}   ] ."
        return 0
     ;;      
     startup)
        log_echo ""
        log_echo "start $action ...."
        checkEnv || return 1
        checkApp "${TOMCAT_USE_DETAIL_FILE}"  "${package}"  "${SYSTEM_CONFIG_FILE}"  "2"  || return 1
        startTomcatApp "${SYSTEM_CONFIG_FILE}"  "300"  "20" || return 1
        return 0
     ;;
     rollback)
        log_echo ""
        log_echo "start $action ...."
        checkEnv || return 1
        updateFlagToSql "check_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        checkApp "${TOMCAT_USE_DETAIL_FILE}"  "${package}"  "${SYSTEM_CONFIG_FILE}"  "2" 
        if [ $? -ne 0 ];then
            updateFlagToSql "check_flag"  "${DATE_TS}"  "-1"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
            return 1
        else
            setFlag "check_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "check_flag"  "${DATE_TS}"  "2"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        fi
        
        log_echo "info" "$func" "Check other machine step : [  check   ]   run successed .  "        
        echo "select check_flag from upgrade_record_table where begin_time='${DATE_TS}';" > ${stepsql}
        waitStepSynchro "${DB_CONFIG_FILE}"  "${stepsql}"  "${outstepfile}"  "${EXPIRE_TIME}" || return 1 
        log_echo ""
        updateFlagToSql "backup_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        backupApp "${backupDir}"  "${package}"  "${SYSTEM_CONFIG_FILE}"   "${envName}"
        if [ $? -ne 0 ];then
            updateFlagToSql "backup_flag"  "${DATE_TS}"  "-1"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
            return 1
        else
            setFlag "backup_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "backup_flag"  "${DATE_TS}"  "2"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
        fi
        
        log_echo "info" "$func" "Check other machine step : [  check   ]  and [  backup   ]  run successed .  "        
        echo "select check_flag,backup_flag from upgrade_record_table where begin_time='${DATE_TS}';" > ${stepsql}
        waitStepSynchro "${DB_CONFIG_FILE}"  "${stepsql}"  "${outstepfile}"  "${EXPIRE_TIME}" || return 1 
        log_echo ""
        updateFlagToSql "rollback_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        
        #### 将回滚的版本号写入到数据库中###
        echo "update upgrade_record_table set rollback_to_version='${version}' where begin_time='${DATE_TS}';" > ${stepsql}
        execSqlToFile "${DB_CONFIG_FILE}" "${stepsql}"  "${outstepfile}"  || return 1
        rollbackTomcatApp "${backupDir}"  "${SYSTEM_CONFIG_FILE}"  "${version}"
        if [ $? -ne 0 ];then
            updateFlagToSql "rollback_flag"  "${DATE_TS}"  "-1"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
            return 1
        else
            setFlag "rollback_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "rollback_flag"  "${DATE_TS}"  "2"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
        fi
        log_echo "info" "$func" "rollback successed ,ip: [  ${localip}   ] ."
        return 0
     ;;
     rollback_serial)
        log_echo ""
        log_echo "start $action ...."
        checkEnv || return 1
        updateFlagToSql "check_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        checkApp "${TOMCAT_USE_DETAIL_FILE}"  "${package}"  "${SYSTEM_CONFIG_FILE}"  "2" 
        if [ $? -ne 0 ];then
            updateFlagToSql "check_flag"  "${DATE_TS}"  "-1"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
            return 1
        else
            setFlag "check_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "check_flag"  "${DATE_TS}"  "2"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        fi
        
        log_echo "info" "$func" "Other machine step : [  check   ]   run , so wait ..  "            
        echo "select check_flag from upgrade_record_table where begin_time='${DATE_TS}';" > ${stepsql}
        waitStepSynchro "${DB_CONFIG_FILE}"  "${stepsql}"  "${outstepfile}"  "${EXPIRE_TIME}" || return 1 
        log_echo "info" "$func" "Other machine step : [  check   ]   run successed .  "            
        log_echo ""
        updateFlagToSql "backup_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        backupApp "${backupDir}"  "${package}"  "${SYSTEM_CONFIG_FILE}"   "${envName}"
        if [ $? -ne 0 ];then
            updateFlagToSql "backup_flag"  "${DATE_TS}"  "-1"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
            return 1
        else
            setFlag "backup_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "backup_flag"  "${DATE_TS}"  "2"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
        fi
        
        log_echo "info" "$func" "Other machine step : [  check   ]   and [  backup   ]  run , so wait ..  "            
        echo "select check_flag,backup_flag from upgrade_record_table where begin_time='${DATE_TS}';" > ${stepsql}
        waitStepSynchro "${DB_CONFIG_FILE}"  "${stepsql}"  "${outstepfile}"  "${EXPIRE_TIME}" || return 1 
        log_echo "info" "$func" "Other machine step : [  check   ]  and [  backup   ]  run successed ."
        log_echo ""
        updateFlagToSql "rollback_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        
        #### 将回滚的版本号写入到数据库中###
        echo "update upgrade_record_table set rollback_to_version='${version}' where begin_time='${DATE_TS}';" > ${stepsql}
        execSqlToFile "${DB_CONFIG_FILE}" "${stepsql}"  "${outstepfile}"  || return 1
        rollbackSerialTomcatAppBySql "${backupDir}"   "${EXPIRE_TIME}"   "${SERIAL_FILE_FOR_SQL_ROLLBACK}"   "${SYSTEM_CONFIG_FILE}"  "${DB_CONFIG_FILE}"  "${DATE_TS}"  "${version}"  || return 1
        #rollbackSerialTomcatAppBySftp "${backupDir}"  "${EXPIRE_TIME}"  "`dirname ${SERIAL_FILE}`"  "`basename ${SERIAL_FILE}`"  "${SYSTEM_CONFIG_FILE}"  "${SFTP_SCRIPT}"   "${SFTP_CONFIG_FILE}"  "${version}"  || return 1
        return 0
     ;;
     restart)
        log_echo ""
        log_echo "start $action ...."
        checkEnv || return 1
        checkApp "${TOMCAT_USE_DETAIL_FILE}"  "${package}"  "${SYSTEM_CONFIG_FILE}"  "2" || return 1
        setFlag "check_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
        stopTomcatApp  "${SYSTEM_CONFIG_FILE}" || return 1
        startTomcatApp "${SYSTEM_CONFIG_FILE}"  "300"  "20"  || return 1
        return 0
     ;;    
     restart_serial)
        log_echo ""
        log_echo "start $action ...."
        checkEnv || return 1
        updateFlagToSql "check_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        checkApp "${TOMCAT_USE_DETAIL_FILE}"  "${package}"  "${SYSTEM_CONFIG_FILE}"  "2" 
        if [ $? -ne 0 ];then
            updateFlagToSql "check_flag"  "${DATE_TS}"  "-1"  "${stepsql}"   "${DB_CONFIG_FILE}"     "${outstepfile}"  || return 1
            return 1
        else
            setFlag "check_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
            updateFlagToSql "check_flag"  "${DATE_TS}"  "2"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        fi
        
        log_echo "info" "$func" "Other machine step : [  check   ]   run , so wait ..  "        
        echo "select check_flag from upgrade_record_table where begin_time='${DATE_TS}';" > ${stepsql}
        waitStepSynchro "${DB_CONFIG_FILE}"  "${stepsql}"  "${outstepfile}"  "${EXPIRE_TIME}" || return 1 
        log_echo "info" "$func" "Other machine step : [  check   ]   run  successed ..  "
        log_echo ""
        updateFlagToSql "restart_flag"  "${DATE_TS}"  "1"  "${stepsql}"    "${DB_CONFIG_FILE}"    "${outstepfile}"  || return 1
        restartAppSerialBySql  "${SYSTEM_CONFIG_FILE}"  "${DB_CONFIG_FILE}"   "${SERIAL_FILE_FOR_SQL}"   "${DATE_TS}"  "${EXPIRE_TIME}"  "${envName}"  || return 1
        return 0
     ;;     
     stop)
        log_echo ""
        log_echo "start $action ...."
        checkEnv || return 1
        checkApp "${TOMCAT_USE_DETAIL_FILE}"  "${package}"  "${SYSTEM_CONFIG_FILE}"  "2" || return 1
        setFlag "check_flag"  "true"   "${SYSTEM_CONFIG_FILE}"  || return 1
        stopTomcatApp  "${SYSTEM_CONFIG_FILE}" || return 1
        return 0
     ;; 
     cleanup)
        log_echo "start $action ...."
        #####  backupBaseDir not include time factor directory ######
        typeset backupBaseDir="`dirname ${backupDir}`"
        #cleanupApp "${}"  "${}"   "${}"   "${}"  "${backupBaseDir}@/tmp/upgradeReadyToDelete" || return 1
        return 0
     ;;                     
     stop_clientscript)
        log_echo "start $action ...."
        stopClientScript
        return 0
     ;;  
     *)
        showHelp
        return 1
     ;; 
    esac     
    log_echo "info" "${func}" "Exit func ${func} with successed."
    return 0
}

####  更新标识到数据库中 #####
updateFlagToSql()
{
    typeset func=updateFlagToSql
    if [ $# -ne 6 ];then
        log_echo "error" "${func}" "Parameter error , usage : ${func}  flagname  datets  setflagvalue  sqlfile  dbconfigfile outputfile "
        return 1
    fi
    #log_echo "info" "${func}" "Enter ${func} with successed."
    typeset flagname="$1"
    typeset datets="$2"
    typeset setflagvalue="$3"
    typeset sqlfile="$4"
    typeset dbconfigfile="$5"
    typeset outputfile="$6"
    echo "update upgrade_record_table set ${flagname}=${setflagvalue} where ip='${localip}' and begin_time='${datets}';" > ${sqlfile}
    execSqlToFile "${dbconfigfile}" "${sqlfile}"  "${outputfile}"  || return 1
    log_echo "info" "${func}" "Exit ${func} with successed."
    return 0
}


####  更改标识到文件中  ####
setFlag()
{
    typeset func=setFlag
    if [ $# -ne 3 ];then
        log_echo "error" "${func}" "Parameter error , usage : ${func}  flagname  settoname  configfile   "
        return 1
    fi
    #log_echo "info" "${func}" "Enter ${func} with successed."
    typeset flagname="$1"
    typeset settoname="$2"
    typeset configfile="$3"
    sed -i  's/^'"${flagname}"'=.*/'"${flagname}"'='"${settoname}"'/g' ${configfile}
    if [ $? -ne 0 ];then
        log_echo "error" "main" "Command error ,CMD = [    sed -i  's/^'"${flagname}"'=.*/'"${flagname}"'='"${settoname}"'/g' ${configfile}     ]"
        return 1
    fi
    log_echo "info" "${func}" "Exit ${func} with successed."
    return 0
}

####  步骤同步  ###
waitStepSynchro()
{
    typeset func=waitStepSynchro
    if [ $# -ne 4 ];then
        log_echo "error" "${func}" "Parameter error , usage : ${func}   db.conf   a.sql  outstepfile  expirtime  "
        return 1
    fi
    typeset dbconfigfile="$1"
    typeset stepsql="$2"
    typeset outstepfile="$3"
    typeset expirtime="$4"
    log_echo "info" "$func" "Enter $func with successed ."
    typeset beginTime=`date +%s`
    while [ true ];do
        execSqlToFile "${dbconfigfile}" "${stepsql}"  "${outstepfile}"  || return 1
        typeset countFailed=`grep -wc '\-1' "${outstepfile}"`
        typeset countnotcom=`grep -wEc '0|1' "${outstepfile}"`
        if [ ${countFailed} -gt 0 ];then
            log_echo "error" "$func" "Found other machine run failed .please check table: [  upgrade_record_table    ]  , begin_time : [  ${DATE_TS}  ]"
            return 1
        fi
        if [ ${countnotcom} -gt 0 ];then
            log_echo "info" "$func" "Waitting other machine run check and backup ."
            sleep 10
            typeset currentTime=`date +%s`
            typeset expenseTime=`expr ${currentTime} - ${beginTime}`
            if [ "${expenseTime}" -gt "${expirtime}" ];then
                log_echo "error" "$func" "Expire time exec time:[  ${expenseTime}  ]  more than :[   ${expirtime}   ]"
                return 1
            fi
        fi
        if [ ${countFailed} -eq 0  -a ${countnotcom} -eq 0 ];then
            log_echo "info" "$func" "Checked step flag successed ." 
            break
        fi
    done
    log_echo "info" "${func}" "Exit func ${func} with successed."
    return 0
}


###  停止客户端脚本 #####
stopClientScript()
{
    typeset func=stopClientScript
    ps -ef | grep "${PROGRAM_NAME}" | grep -v grep | awk '{print $2}' | xargs kill -9 >/dev/null 2>&1
    log_echo "info" "${func}" "Exit func ${func} with successed."
    return 0    
}

checkEnv()
{
    typeset func=checkEnv
    typeset eachDir=""
    typeset eachDetailFile=""
    ####### check run base env #########
    for eachDir in ${TEMP_DIR}  ${LOG_DIR}  ${CONFIG_DIR}  ${BIN_DIR};do
        mkdir -p "${eachDir}"
        if [ $? -ne 0 ];then
            log_echo "error" "$func" "Command error . CMD=[  mkdir -p ${eachDir}   ]"
            return 1
        fi
    done
    ######### check mutiline run #########
    
    ########### check detail config file ###########
    for eachDetailFile in "${TOMCAT_USE_DETAIL_FILE}"  "${SFTP_CONFIG_FILE}"  "${DB_CONFIG_FILE}";do
        typeset configFileName="`basename "${eachDetailFile}"`"
        typeset orgConfigFile="${BIN_DIR}/${configFileName}"
        checkFileExists "${orgConfigFile}" || return 1
        mv "${orgConfigFile}"  "${CONFIG_DIR}"
        if [ $? -ne 0 ];then
            log_echo "error" "$func" "Command error . CMD=[  mv "${orgConfigFile}"  "${CONFIG_DIR}"   ]"
            return 1
        fi
    done
    
    ###  system config ####
    getSystemInfoToConfig "${SYSTEM_CONFIG_FILE}" || return 1
    . ${SYSTEM_CONFIG_FILE}
    . ${SFTP_CONFIG_FILE}
    
    #####  check sftp server ######
    checkSftpConfig  "${SFTP_SCRIPT}"   "${SFTP_CONFIG_FILE}"   "${package}"  "${TEMP_DIR}" || return 1
    
    log_echo "info" "$func" "Is going to download file : [ $package  ] from sftp server : [   $SFTP_HOST_IP      ],please wait ...."
    ####  下载 sftp服务器 上的新包到本地 ###
    mkdir -p "${downloadPkgDir}"  &&  ${SFTP_SCRIPT}  "${SFTP_USER}"  "${SFTP_HOST_IP}"  "${SFTP_PASS}"  "${SFTP_FILE_DIR}/${package}" "${downloadPkgDir}" "getFile"
    if [ $? -ne 0 ];then
        log_echo "error" "$func" "DownLoad file : [  $package    ]   from : [  ${SFTP_HOST_IP}    ] remote-dir: [  ${SFTP_FILE_DIR}/${package}   ]   with user : [  ${SFTP_USER}   ]. please check ."
        return 1
    fi
    
    ###### 检查下载后的包是否可以解压  #########
    typeset prefixPkgName=`echo "${package}" | awk -F'.' '{print $1}'`
    cd ${downloadPkgDir} &&  unzip -d ${prefixPkgName} ${package}
    if [ $? -ne 0 ];then
        log_echo "error" "$func" "unzip  file  failed . CMD = [  cd ${downloadPkgDir} &&  unzip -d ${prefixPkgName} ${package}    ] ."
        return 1
    fi
    
    ### 备份目录是否存在  ###
    typeset backupBaseDir="`dirname ${backupDir}`"
    checkDirExists "${backupBaseDir}" || return 1
    chmod 777 -R ${backupBaseDir}
    
    #### 将标识位写入到文件中  ##########
    echo "check_flag=false" >> ${SYSTEM_CONFIG_FILE}
    echo "backup_flag=false" >> ${SYSTEM_CONFIG_FILE}
    echo "upgrade_flag=false" >> ${SYSTEM_CONFIG_FILE}
    echo "rollback_flag=false" >> ${SYSTEM_CONFIG_FILE}
    echo "cleanup_flag=false" >> ${SYSTEM_CONFIG_FILE}
    #>${SERIAL_FILE}
    log_echo "info" "Exit func ${func} with successed."
    return 0
}

showHelp()
{
    log_echo "$*"
    return 0
}

main $*