#!/bin/bash


#######      connect to remote host and exec commmand  client.sh #####



if [ `echo "$0" |grep -c "/"` -gt 0 ];then
    cd ${0%/*}
fi

PROGRAM_DIR=`pwd`
cd ..
BASE_DIR=`pwd`
PROGRAM_NAME=`basename $0`

. ${BASE_DIR}/bin/pub.lib


##################  CONFIG ################################
TEMP_DIR=${BASE_DIR}/temp
LOG_DIR=${BASE_DIR}/log
BIN_DIR=${BASE_DIR}/bin
CONFIG_DIR=${BASE_DIR}/conf

#RSH=/usr/bin/rsh
SSH=/usr/bin/ssh


##########  exec user ############
EXEC_USER=root

######   log file  #####
LOG_FILE=${LOG_DIR}/${PROGRAM_NAME}.log

#############  all remote config file  ##########
CONFIG_FILE=${BASE_DIR}/conf/connect.conf

#####  收集到的系统配置文件  动态生成 ####
SYSTEM_CONFIG_FILE=${CONFIG_DIR}/systeminfo.conf

EXEC_SCRIPT="${BIN_DIR}/client/client.sh"
EXPECT_SCRIPT="${BIN_DIR}/execCmdFile.exp"
SCP_SCRIPT="${BIN_DIR}/execScp.exp"

EXEC_TIME_SLEEP=0.3
##NOT_CON_IPADDR_LOG=${TEMP_DIR}/notconnectip.log
LOOP_SLEEP_TIME=20


##########  线程数过多，导致回传文件失败  需要设置线程数 及时延  #########
THREAD_NUM=10

######### 当线程数到达 THREAD_NUM 后进行时延 秒 #########
THREAD_SLEEP_TIME=20

####  script time out defult is 300 seconds #######
EXEC_TIME_OUT_CHECK=600

EXEC_TIME_OUT_RUN=7200

######  wait time to get 130 网段 resulut #######
TIME_TO_GET130_RESULT=100
#TIME_TO_GET130_RESULT=50

#########  end of config   #####



################  script use config need not to modify  ####################
#PROGRAM_NAME=`basename $0`
SEND_FILE_DIR=${TEMP_DIR}/sendFileDir
SEND_FILE_DIR_BIN=${SEND_FILE_DIR}/bin
SEND_FILE_DIR_CONF=${SEND_FILE_DIR}/conf
SEND_FILE_TAR_FILE=${SEND_FILE_DIR}/sendFile.tar.gz

AVAILABLE_CONFIG_FILE=${BASE_DIR}/conf/connect.conf.use
resultDir=${TEMP_DIR}/result
ALL_IP_LIST_FILE=${TEMP_DIR}/allIP.list
recordResultFile=${TEMP_DIR}/result.list
recordResultFailed=${TEMP_DIR}/execFailed.list

######  130 网段不能反向SSH 服务端超时主动取文件 ########
#CONFIG_130_FILE=${TEMP_DIR}/config130.conf.tmp

#######   exists 130 ip addresses  defealt exists this ip addresses. ########
#exists130Flag=0

########## 客户端要执行的程序配置文件##########
CLIENT_CONFIG_FILE=${BASE_DIR}/conf/client.conf


##########  130 ipaddresses  file ############
#ALL_130IP_LIST_FILE=${TEMP_DIR}/all130IP.list

########## ready to get 130 files, this file get file  ${CONFIG_130_FILE} and ${ALL_IP_LIST_FILE}  intersection ###########
#READY_TO_GET_130FILE=${TEMP_DIR}/readytoget130ipaddress.tmp

main()
{
    typeset func=main
    if [ $# -gt 2 ];then
        showHelp 
        return 1
    fi

    case "$1" in
     "-help"|"--help"|"-Help"|"--Help"|"-h")
        showHelp
        return 0
     ;; 
     check)
        checkEnv || return 1
        syncScriptAndExecCheck || return 1
        EXEC_TIME_OUT=${EXEC_TIME_OUT_CHECK}
     ;;      
     run)
        checkEnv || return 1
        execTheScript || return 1
        EXEC_TIME_OUT=${EXEC_TIME_OUT_RUN}
     ;;      
     *)
        showHelp
        return 1
     ;; 
    esac 
    
    #####   获取所有有效IP地址   #########
    awk '{print $3}' ${AVAILABLE_CONFIG_FILE} > ${ALL_IP_LIST_FILE}
    resultFlag=0
    beginTime=`date +%s`
    while [ TRUE ];do
        getRemoteExecResult || return 1
        
        if [ ! -s "${ALL_IP_LIST_FILE}" ];then
            log_echo "info" "main" "All result is completed."
            break                
        fi
        log_echo "info" "$func" "wait ${LOOP_SLEEP_TIME} secords to get result,please wait..."
        sleep ${LOOP_SLEEP_TIME}
        currentTime=`date +%s`
        expenseTime=`expr ${currentTime} - ${beginTime}`
        if [ "${expenseTime}" -gt "${EXEC_TIME_OUT}" ];then
            ########  all time expired  #########
            log_echo "info" "main" "Time out ..set time is ${EXEC_TIME_OUT} but expense time is ${expenseTime} "
            log_echo "error" "main" "Can not get result from IP list is  ${ALL_IP_LIST_FILE} . "
            cat ${ALL_IP_LIST_FILE}
            return 1
        fi
    done
    
    awk '{if($2!=0)print $0}' ${recordResultFile} > ${recordResultFailed}   
    if [ $? -ne 0 ];then
        log_echo "error" "main" "Command error , CMD = [    awk '{if($2!=0)print $0}' ${recordResultFile} > ${recordResultFailed}        ] ."
        return 1
    fi
    
    if [ -s "${recordResultFailed}" ];then
        log_echo "error" "main" "exec failed ip list is :"
        cat ${recordResultFailed}
        return 1
    fi
    rm -f ${AVAILABLE_CONFIG_FILE} 
    log_echo "info" "Exit func ${func} with successed."     
    return 0
}
getLocalHostConncetInfoToConfigFile()
{
    typeset func=getLocalHostConncetInfoToConfigFile
    if [ $# -ne 1 ];then
        log_echo "error" "${func}" "Parameter error , ${func} orgConfigFile."
        return 1        
    fi
    typeset ORG_CONFIG_FILE="$1"
    ### localIP write to a file ,ready to send to remote host  ###
    SEND_TO_REMOTE_FILE=${SEND_FILE_DIR_CONF}/${localip}_config.conf
    > ${SEND_TO_REMOTE_FILE}
    localIP_line=`grep -w "${localip}" ${ORG_CONFIG_FILE}`
    ##echo "8888888888888888888888 : $localIP_line"
    if [ -z "${localIP_line}" ];then
        log_echo "error" "${func}" "Get local ip config failed ."
        return 1
    fi
    chmod 666 ${SEND_TO_REMOTE_FILE} && echo "${localIP_line}" > ${SEND_TO_REMOTE_FILE}
    if [ $? -ne 0 ];then
        log_echo "error" "${func}" "Command error CMD = [    chmod 666 ${SEND_TO_REMOTE_FILE} && echo "${localIP_line}" > ${SEND_TO_REMOTE_FILE}      ] ."
        return 1
    fi  
    log_echo "info" "Exit func ${func} with successed." 
    return 0
}

#####  get available config item to AVAILABLE_CONFIG_FILE  file ###############
getAvailableConfigFile()
{
    typeset func=getAvailableConfigFile
    if [ $# -ne 2 ];then
        log_echo "error" "${func}" "Parameter is error. usage : ${func} org_configfile  newconfigfile."
        return 1
    fi
    typeset ORG_CONFIG_FILE="$1"
    typeset NEW_CONFIG_FILE="$2"
    typeset eachIP=""
    ####  # delete comment #############
    cat "${ORG_CONFIG_FILE}" | grep -v '^#' > ${NEW_CONFIG_FILE} 
    #########  sort uniq ########
    sort -u ${NEW_CONFIG_FILE} | uniq > ${NEW_CONFIG_FILE}.use 
    #### delete local ip lines ######
    for eachIP in `echo "${localip}"`;do
        sed -i /${eachIP}/d  ${NEW_CONFIG_FILE}.use
    done
    ### delete blank line ########
    sed -i '/^$/d' ${NEW_CONFIG_FILE} && sed -i /^[[:space:]]*$/d ${NEW_CONFIG_FILE}.use
    if [ $? -ne 0 ];then
        log_echo "error" "${func}" "Delete blank lines failed. CMD = [   sed -i '/^$/d' ${NEW_CONFIG_FILE} && sed -i /^[[:space:]]*$/d ${NEW_CONFIG_FILE}.use    ]."
        return 1
    fi
    cp -f ${NEW_CONFIG_FILE}.use  ${NEW_CONFIG_FILE} && rm -f ${NEW_CONFIG_FILE}.use
    log_echo "info" "${func}" "Exit func : ${func} with successed ."
    return 0
}

showHelp()
{
cat << EOF

This script is used to cleanup log file

USAGE: `basename $0` [--help] 

OPTIONS:
   --help| -help                           Display this help
    check                                  Check config right
    run                                    Run the script

EXAMPLE: 
show how to use script
 ./$(basename $0) [--help|-help|]

check config all right.
 ./$(basename $0) check

run:
 ./$(basename $0) run

EOF
    return 0
}

checkEnv()
{
    typeset flag=0
    typeset eachDir=""
    typeset eachConfigFile=""
    typeset eachExcFile=""
    typeset eachCmdFile=""
    log_echo "info" "$func" "Enter $func with successed ."
    for eachDir in ${TEMP_DIR} ${LOG_DIR} ${BIN_DIR} ${resultDir} ${SEND_FILE_DIR} ${SEND_FILE_DIR_BIN} ${SEND_FILE_DIR_CONF};do
        mkdir -p ${eachDir}
        if [ $? -ne 0 ];then
            log_echo "error" "Create directory failed. CMD = [   mkdir -p ${eachDir}  ]"
            flag=1    
        fi
    done
    ####  check file is exsits  #############
    for eachConfigFile in ${CONFIG_FILE} ${CLIENT_CONFIG_FILE};do
        if [ ! -f "${eachConfigFile}" ];then
            log_echo "error" "File is not exists ,file is : ${eachConfigFile}"
            flag=1    
        fi
        chmod 666 ${eachConfigFile}
        if [ $? -ne 0 ];then
            log_echo "error" "Command is error,CMD = [     chmod 666 ${eachConfigFile}     ]"
            flag=1    
        fi
    done
    for eachExcFile in  ${EXEC_SCRIPT} ${EXPECT_SCRIPT} ${SCP_SCRIPT};do
        chmod +x ${eachExcFile}
        if [ $? -ne 0 ];then
            log_echo "error" "Command is error,CMD = [      chmod +x ${eachExcFile}      ]"
            flag=1    
        fi
    done    
    #####  exec  user is right  #########    
    if [ "`whoami`" != "${EXEC_USER}" ];then
        log_echo "error" "Exec user is not eqeul ${EXEC_USER},please check"
        flag=1
    fi
    ###########  exec command +x  ##########
    for eachCmdFile in ${SSH};do
        if [ ! -x "${eachCmdFile}" ];then
            chmod +x ${eachCmdFile}
            if [ $? -ne 0 ];then
                log_echo "error" "Command is failed. CMD=[  chmod +x ${eachCmdFile}    ]"
                flag=1
            fi
        fi    
    done
    ###  get system info ####
    if [ ! -s "${SYSTEM_CONFIG_FILE}" ];then
        getSystemInfoToConfig "${SYSTEM_CONFIG_FILE}" || return 1
    fi
    . ${SYSTEM_CONFIG_FILE}
    
    getAvailableConfigFile "${CONFIG_FILE}"  "${AVAILABLE_CONFIG_FILE}" || return 1
    ####   check config file is right #########
    while read theUser thePasswd theIPaddr;do
        if [ -z "${theIPaddr}" ];then
            log_echo "error" "The ip addres is null ,please check."
            flag=1
            break
        fi
    done < ${AVAILABLE_CONFIG_FILE}
    
    ######check muti process is runing ? must only one process run ########
    processNum=`ps -ef | grep "${BIN_DIR}/${PROGRAM_NAME}" | grep run | grep -v grep | wc -l`
    #echo "processNum : ${processNum}"
    if [ ${processNum} -gt 2 ];then
        log_echo "error" "The program : ${PROGRAM_NAME} is running ,so exit."
        flag=1
    fi
    
    getLocalHostConncetInfoToConfigFile "${CONFIG_FILE}" || flag=1
    getSSHConnectNum || return 1
    systemSetNum="${RETURN[0]}"
    typeset nowNum=`wc -l ${AVAILABLE_CONFIG_FILE} | awk '{print $1}'`
    if [ ${nowNum} -gt ${systemSetNum} ];then
        log_echo "info" "${func}" "Please set ssh connect number."
        ${flag}=1
    fi    
    
    ### delete all result file ####
    rm -rf ${resultDir}/*
    > ${recordResultFile}
    > ${recordResultFailed}
    > ${ALL_IP_LIST_FILE}
    
    if [ "${flag}" -ne 0 ];then
        log_echo "error" "Exit checkEnv failed.please check."
        return 1
    fi 
    log_echo "info" "Exit checkEnv successed."
    return 0
}

syncScriptAndExecCheck()
{
    typeset func=syncScriptAndExecCheck
    log_echo "info" "$func" "Enter  ${func} with successed  ."
    typeset varFile=""
    typeset eachFile=""
    ####  cp files to  directory  ready to send.#######
    typeset clientListFiles=`ls ${BIN_DIR}/client`
    for eachFile in ${clientListFiles};do
        typeset eachFile=${BIN_DIR}/client/${eachFile}
        typeset absultListFiles="${absultListFiles}  ${eachFile}"
    done
    for varFile in ${EXPECT_SCRIPT} ${SCP_SCRIPT} ${absultListFiles}  ${BASE_DIR}/bin/pub.lib  ${CLIENT_CONFIG_FILE};do
        cp -f ${varFile} ${SEND_FILE_DIR_BIN}
    done
    
    typeset tarFileName=`basename ${SEND_FILE_TAR_FILE}`
    tarGzFile ${SEND_FILE_DIR} ${tarFileName} || return 1    
    EXEC_REMOTE_SCRIPT=${BIN_DIR}/client.sh    
    
    cat "${AVAILABLE_CONFIG_FILE}" | while read theUser thePasswd theIPaddr ThePort
    do
        if [ -z "${ThePort}" ];then
            ThePort=22
        fi
        decrypt "${thePasswd}" || return 1
        typeset thePasswd="${RETURN[0]}"
        #### create remote directory ####
        ${EXPECT_SCRIPT}  ${theUser}  ${theIPaddr}  "${thePasswd}"  ${ThePort}  "mkdir -p ${BASE_DIR}"  1>/dev/null 2>&1 && ${SCP_SCRIPT}  ${theUser}  ${theIPaddr}  "${thePasswd}"  ${SEND_FILE_TAR_FILE}  ${BASE_DIR}  ${ThePort} 1>/dev/null 2>&1 && ${EXPECT_SCRIPT} ${theUser} ${theIPaddr}  "${thePasswd}"  ${ThePort}  "cd ${BASE_DIR} && tar -zxf ${tarFileName} && echo success" 1>/dev/null 2>&1 && ${EXPECT_SCRIPT} ${theUser} ${theIPaddr} "${thePasswd}" ${ThePort} "chmod +x ${EXEC_REMOTE_SCRIPT} && sh ${EXEC_REMOTE_SCRIPT} ${localip} ${resultDir} ${theIPaddr} check >/dev/null 2>&1"  &
        ##log_echo "info" "${func}" "Create directory : ${BASE_DIR} and send file and exec file success in host : ${theIPaddr}. "    
    done
    log_echo "info" "${func}" "Exit func ${func} with success. "    
    return 0
}

execTheScript()
{
    typeset func=execTheScript
    log_echo "info" "Enter func ${func} ."
    num=0
    while read theUser thePasswd theIPaddr ThePort;do
        if [ -z "${ThePort}" ];then
            ThePort=22
        fi
        ### EXPECT_SCRIPT username hostIP password port CmdFile
        EXEC_REMOTE_SCRIPT=${BIN_DIR}/client.sh
        decrypt "${thePasswd}" || return 1
        thePasswd="${RETURN[0]}"
        nohup ${EXPECT_SCRIPT} ${theUser} ${theIPaddr} ${thePasswd} ${ThePort} "nohup chmod +x ${EXEC_REMOTE_SCRIPT} && nohup ${EXEC_REMOTE_SCRIPT} ${localip} ${resultDir} ${theIPaddr} run >/dev/null 2>&1"  &
        
        num=`expr ${num} + 1 `
        if [ "${num}" -gt "${THREAD_NUM}" ];then
            sleep ${THREAD_SLEEP_TIME}
            num=0
        fi
    done < ${AVAILABLE_CONFIG_FILE}    
    log_echo "info" "Exit func ${func} with success."
    return 0
}

getRemoteExecResult()
{
    typeset func=getRemoteExecResult
    scriptName=`basename ${EXEC_SCRIPT}`
    retStr=`ls ${resultDir} | grep ".*${scriptName}"`
    if [ ! -z "${retStr}" ];then
        for eachResult in `echo "${retStr}"`
        do
            execResult=`awk '{print $1}' ${resultDir}/${eachResult}`
            execInfo=`awk '{print $2}' ${resultDir}/${eachResult}`
            retIP=`echo "${eachResult}" | awk -F'_' '{print $1}'`
            log_echo "info" "${func}" "Remote host ${retIP} exec result is ${execResult} ,exec info : ${execInfo} "
            if [ "${execResult}" != "0" ];then
                resultFlag=1
                execInfo="exec_failed"
            fi
            ### writ record result to file ##
            echo "${retIP}  ${execResult}  ${execInfo}" >> ${recordResultFile}
            rm -f ${resultDir}/${eachResult}
            
            #### delete ip address from all ipaddress list #######
            sed -i /${retIP}/d "${ALL_IP_LIST_FILE}"
            if [ $? -ne 0 ];then
                log_echo "error" "${func}" "Delete line failed ,CMD = [    sed -i /${retIP}/d ${ALL_IP_LIST_FILE}     ] "
                return 1
            fi
        done
    fi
    #log_echo "info" "Exit func ${func} with success."
    return 0
}

main $*

