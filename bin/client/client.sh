#!/bin/bash

if [ `echo "$0" |grep -c "/"` -gt 0 ];then
    cd ${0%/*}
fi



PROGRAM_DIR=`pwd`
cd ..
BASE_DIR=`pwd`
PROGRAM_NAME=`basename $0`


. ${BASE_DIR}/bin/pub.lib

TEMP_DIR=${BASE_DIR}/temp
LOG_DIR=${BASE_DIR}/log
CONFIG_DIR=${BASE_DIR}/conf
BIN_DIR=${BASE_DIR}/bin

LOG_FILE=${LOG_DIR}/${PROGRAM_NAME}.log

EXPECT_SCRIPT="${BIN_DIR}/execCmdFile.exp"
SCP_SCRIPT="${BIN_DIR}/execScp.exp"

######################################    config      ###################################################

. ${BIN_DIR}/client.conf

###################################### end of config ####################################################



##########################################################################################################
##########################################################################################################
main()
{
    echo "000000000000000000"  >> ${LOG_FILE}
    echo "all parameters is :" >> ${LOG_FILE}
    echo "$*" >> ${LOG_FILE}

    typeset func=main
    if [ $# -ne 4 ];then
        log_echo "error" "${func}" "Parameter error , ${PROGRAM_NAME} remoteIpAddr remeteDir theLocalIP [check|run]. "
        return 1
    fi
    remoteIpAddr=$1
    remeteDir=$2
    theLocalIP=$3
    action=$4
    
    resultFile=${TEMP_DIR}/result/${theLocalIP}_${PROGRAM_NAME}
    CONFIG_FILE=${CONFIG_DIR}/${remoteIpAddr}_config.conf    
    execFlag=0
    execResult=1
    execInfo=""
    
    case "$4" in
     check)
        checkEnv || return 1
        echo "0   testok" > ${resultFile}
        sendResultFile "${CONFIG_FILE}" "${resultFile}"
     ;;      
     run)
        checkEnv || return 1
        
        if [ ! -f "${BIN_DIR}/${EXEC_CLIENT_SCRIPT}" ];then
            log_echo "error" "$func"  "File is not exists, file is : [  ${BIN_DIR}/${EXEC_CLIENT_SCRIPT}   ]"
            return 1
        fi
        
        allPara=""
        for eachPara in ${PARAMETER[@]};do
            allPara="${allPara} ${eachPara}"
        done        
        
        if [ "${havaResultFile}" = "YES" ];then
            chmod +x "${BIN_DIR}/${EXEC_CLIENT_SCRIPT}"  &&  bash "${BIN_DIR}/${EXEC_CLIENT_SCRIPT}"  "${RESULT_FILE_DIR}"  "${allPara}"    
        else
            chmod +x "${BIN_DIR}/${EXEC_CLIENT_SCRIPT}"  &&  bash "${BIN_DIR}/${EXEC_CLIENT_SCRIPT}"  "${allPara}"    
        fi
        
        if [ $? -ne 0 ];then
            echo "1   exec_failed" > ${resultFile}
        else
            echo "0   exec_successed" > ${resultFile}
        fi
        sendResultFile "${CONFIG_FILE}" "${resultFile}"
        ######### tar file ######
        if [ "${havaResultFile}" = "YES" ];then
            clientScriptName="`basename ${EXEC_CLIENT_SCRIPT}`"
            clientScriptName=`echo "${clientScriptName}" | awk -F'.' '{print $1}'`
            ###### cp logs to dir: RESULT_FILE_DIR#######
            cp -f ${LOG_DIR}/*log  ${RESULT_FILE_DIR}
            tarGzFile "${RESULT_FILE_DIR}" "${theLocalIP}_${clientScriptName}.tar.gz" || return 1
            sendResultPackageFile "${CONFIG_FILE}"  "${RESULT_FILE_DIR}/${theLocalIP}_${clientScriptName}.tar.gz"  "${remeteDir}"  || return 1
        fi        
     ;;      
     *)
        log_echo "error" "${func}" "Parameter error . action must be check or run. "
        return 1
     ;; 
    esac     
    return 0
}

checkEnv()
{
    typeset flag=0
    typeset func=checkEnv
    log_echo "info" "$func" "Enter $func with successed ."
    ### create dir ####
    for eacheDir in ${TEMP_DIR} ${LOG_DIR} ${CONFIG_DIR};do
        mkdir -p ${eacheDir}
        if [ $? -ne 0 ];then
            log_echo "error" "Create directory failed. CMD =   [  mkdir -p ${eacheDir}    ]"
            flag=1
            execFlag=1
        fi
    done    
    
    if [ "${havaResultFile}" = "YES" ];then
        mkdir -p ${RESULT_FILE_DIR}/clientResult
        rm -rf ${RESULT_FILE_DIR}/clientResult/*
        ######  reset result directory  #########
        RESULT_FILE_DIR=${RESULT_FILE_DIR}/clientResult
    fi
    
    installExpect "/tmp/$func.tmp" || flag=1 
    ###  check each file exists ###
    for eachCFile in ${CONFIG_FILE} ${EXPECT_SCRIPT} ${SCP_SCRIPT};do
        if [ ! -f "${eachCFile}" ];then
            log_echo "error" "File is not exists, file is : ${eachCFile}"
            flag=1
            execFlag=1            
        fi
    done
    
    ####  chmod to each exec file #####
    for eachFile in ${EXPECT_SCRIPT} ${SCP_SCRIPT};do
        chmod +x ${eachFile}
        if [ $? -ne 0 ];then
            log_echo "error" "Command failed. CMD =   [  chmod +x ${eachFile}   ]"
            flag=1
            execFlag=1
        fi        
    done
    
    #### check config file right ####
    lines=`wc -l ${CONFIG_FILE}`
    if [ "${lines}" -ge "2" ];then
        log_echo "error" "Match more lines in file ${CONFIG_FILE} "
        flag=1
        execFlag=1        
    fi
    
    rm -rf ${TEMP_DIR}/result && mkdir -p ${TEMP_DIR}/result
    if [ $? -ne 0 ];then
        log_echo "error" "Create directory failed. CMD =   [     rm -rf ${TEMP_DIR}/result && mkdir -p ${TEMP_DIR}/result     ]"
        flag=1
        execFlag=1
    fi
    
    touch ${resultFile} && chmod 666 ${resultFile}
    if [ $? -ne 0 ];then
        log_echo "error" "Command failed. CMD =   [    touch ${resultFile} && chmod 666 ${resultFile}    ]"
        flag=1
        execFlag=1
    fi
    if [ "${flag}" -eq 1 ];then
        exitWithFailed "${execFlag}"
        return 1
    fi
    log_echo "info" "${func}" "Exit func ${func} with successed."
    return 0
}

exitWithSuccess()
{
    echo "0  ${execInfo}" > ${resultFile}
    sendResultFile "${CONFIG_FILE}" "${resultFile}" || return 1
    return 0
}

exitWithFailed()
{
    typeset func=exitWithFailed
    if [ $# -ne 1 ];then
        log_echo "error" "${func}" "Parameter error ,${func} flag "
        return 1
    fi
    typeset theFlag=$1
    
    if [ "${theFlag}" -ne 0 ];then
        ## remote touch a file in remeteDir ###
        return 1
    else
        echo "1  ${execInfo}" > ${resultFile}
        sendResultFile "${CONFIG_FILE}" "${resultFile}" || return 1
    fi
    
}

#######   发送执行结果返回值  ############
sendResultFile()
{
    typeset func=sendResultFile
    if [ $# -ne 2 ];then
        log_echo "error" "$func" "parameter error, $func configFile resultFile"
        return 1
    fi
    typeset CONFIG_FILE="$1"
    typeset resultFile="$2"
    
    while read theUser thePasswd theIPaddr ThePort;do
        if [ -z "${ThePort}" ];then
            ThePort=22
        fi
        decrypt "${thePasswd}" || return 1
        thePasswd="${RETURN[0]}"
        ### send file to remote host ########
        ${SCP_SCRIPT} ${theUser} ${theIPaddr} ${thePasswd} ${resultFile}  ${remeteDir}  ${ThePort} 
        if [ $? -ne 0 ];then
            log_echo "error" "${func}" "Scp file failed. CMD =[   ${SCP_SCRIPT} ${theUser} ${theIPaddr} " '***'  "${resultFile}  ${remeteDir}  ${ThePort}     ]."
            return 1
        fi    
    done < ${CONFIG_FILE}
    log_echo "info" "${func}" "Exit func ${func} with success."
    return 0
}

########## 发送执行后产生的文件，打包后发送  ##########
sendResultPackageFile()
{
    typeset func=sendResultPackageFile
    if [ $# -ne 3 ];then
        log_echo "error" "$func" "parameter error, $func CONFIG_FILE resultFile remoteDir"
        return 1
    fi
    
    typeset theConfigFile="$1"
    typeset theResultFile="$2"
    typeset theRemoteDir="$3"
    
    while read theUser thePasswd theIPaddr ThePort;do
        if [ -z "${ThePort}" ];then
            ThePort=22
        fi
        decrypt "${thePasswd}" || return 1
        thePasswd="${RETURN[0]}"            
        ### send file to remote host ########
        ${SCP_SCRIPT} ${theUser} ${theIPaddr} ${thePasswd} ${theResultFile}  ${theRemoteDir}  ${ThePort} 
        if [ $? -ne 0 ];then
            log_echo "error" "${func}" "Scp file failed. CMD =[   ${SCP_SCRIPT} ${theUser} ${theIPaddr} ${thePasswd} ${theResultFile}  ${theRemoteDir}  ${ThePort}      ]."
            return 1
        fi    
    done < ${theConfigFile}    
    
    log_echo "info" "${func}" "Exit func ${func} with success."
    return 0
}

main $*
