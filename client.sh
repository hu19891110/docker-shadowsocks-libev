#!/bin/sh

if [ "" != "$KCP_SERVER_PORT" ] &&  [ "" != "$KCP_SERVER_ADDR" ];then
    nohup kcp-client -l :$KCP_LOCAL_PORT -r $KCP_SERVER_ADDR:$KCP_SERVER_PORT --crypt $KCP_CRYPT --mtu $KCP_MTU --mode $KCP_MODE --dscp $KCP_DSCP $KCP_OPTIONS --log /dev/stdout &
fi
nohup ss-local -s 127.0.0.1 -p $KCP_LOCAL_PORT  -l $SS_LOCAL_PORT -k $SS_PASSWORD -m $SS_METHOD -t $SS_TIMEOUT -b $SS_LOCAL_ADDR -A --fast-open $SS_OPTIONS ${SS_DEBUG} &
auth="authorization: Basic `echo $ARUKAS_TOKEN:$ARUKAS_SECERT|tr -d "\n" |base64|tr -d "\n"`"

listContainerApi=https://app.arukas.io/api/containers
createAppApi=https://app.arukas.io/api/app-sets
listAppApi=https://app.arukas.io/api/apps

DOCKER_IMAGE="tofuliang/docker-shadowsocks-libev:latest"
_kcpServerPort=x
_kcpUdpPortIndex=x
_ssServerPort=x
_ssTcpPortIndex=x

COW_DEBUG=""
SS_DEBUG=""
WGET_DEBUG="-q"
[ "$DEBUG" == "true" ] && COW_DEBUG="-debug"
[ "$DEBUG" == "true" ] && SS_DEBUG="-v"
[ "$DEBUG" == "true" ] && WGET_DEBUG="-d -v "

TIMEZONE=8

noContainerCount=0
noPortCount=0
checkFeq=$ARUKAS_CHECK_FEQ

getLocalTime(){
    addSec=$(($TIMEZONE * 3600))
    timeStamp=$((`date -u +%s` + $addSec))
    time=$(date -d @$timeStamp|sed 's/Jan/01/g;s/Feb/02/g;s/Mar/03/g;s/Apr/04/g;s/May/05/g;s/Jun/06/g;s/Jul/07/g;s/Aug/08/g;s/Sep/09/g;s/Oct/10/g;s/Nov/11/g;s/Dec/12/g')
    echo $time|awk '{print $6"/"$2"/"$3" "$4}'
}

query() {
    wget ${WGET_DEBUG} \
    --no-check-certificate \
    --method $1 \
    --header 'content-type: application/vnd.api+json' \
    --header 'accept: application/vnd.api+json' \
    --header "$2" \
    --header 'cache-control: no-cache' \
    --body-data "$4" \
    --output-document \
    - $3
}

createApp(){
    echo "[EVENT] "`getLocalTime`" creating app..."
    KCP_SRV_OPTION=`echo $KCP_OPTIONS|sed 's/--conn\s*[0-9]*//g'|sed 's/--autoexpire\s*[0-9]*//g'`
    query "POST" "$auth" "$createAppApi" "{\"data\": [{\"type\": \"containers\", \"attributes\": {\"image_name\": \"${DOCKER_IMAGE}\", \"instances\": 1, \"mem\": 512, \"cmd\": \"\", \"envs\": [{\"key\": \"SS_SERVER_PORT\", \"value\": \"${SS_SERVER_PORT}\"}, {\"key\": \"SS_PASSWORD\", \"value\": \"${SS_PASSWORD}\"}, {\"key\": \"KCP_SERVER_PORT\", \"value\": \"${KCP_SERVER_PORT}\"}, {\"key\": \"KCP_CRYPT\", \"value\": \"${KCP_CRYPT}\"}, {\"key\": \"KCP_DSCP\", \"value\": \"${KCP_DSCP}\"},{\"key\": \"KCP_MODE\", \"value\": \"${KCP_MODE}\"}, {\"key\": \"KCP_OPTIONS\", \"value\": \"${KCP_SRV_OPTION}\"}, {\"key\": \"KCP_MTU\", \"value\": \"${KCP_MTU}\"}, {\"key\": \"SSH_PASS\", \"value\": \"${SSH_PASS}\"} ], \"ports\": [{\"number\": ${SS_SERVER_PORT}, \"protocol\": \"tcp\"}, {\"number\": ${KCP_SERVER_PORT}, \"protocol\": \"udp\"} ]}, {\"number\": 22, \"protocol\": \"tcp\"} ]} }, {\"type\": \"apps\", \"attributes\": {\"name\": \"ss-kcp\"} } ] }"
}

powerUpContainer(){
    containerId=$(getContainerId)
    inspectApi="https://app.arukas.io/api/containers/$containerId"
    powerApi="https://app.arukas.io/api/containers/$containerId/power"
    echo "[EVENT] "`getLocalTime`" starting container..."
    query "POST" "$auth" "$powerApi"
    sleep 3
#    echo "[EVENT] "`getLocalTime`" stopping container..."
#    query "DELETE" "$auth" "$powerApi"
#    sleep 3
#    echo "[EVENT] "`getLocalTime`" starting container..."
#    query "POST" "$auth" "$powerApi"
    echo "[EVENT] "`getLocalTime`" inspecting container..."
    query "GET" "$auth" "$inspectApi"
    sleep 3
    query "GET" "$auth" "$inspectApi"
    sleep 3
    query "GET" "$auth" "$inspectApi"
}

deleteApps(){
    json=$(query "GET" "$auth" "$listAppApi")
    _apps=$(echo $json|jq '.data' 2>/dev/null)
    _appCount=$(echo $_apps|jq '.|length')
    for i in `seq 0 $_appCount`;
    do
        _appName=$(echo $_apps|jq '.['$i'].attributes.name'|sed 's/"//g' 2>/dev/null)
        if [ "$_appName" = "ss-kcp" ] ; then
            _appId=$(echo $_apps|jq '.['$i'].id'|sed 's/"//g' 2>/dev/null)
            deleteApi="https://app.arukas.io/api/apps/$_appId"
            echo "[EVENT] deleteing app... [$_appId]"
            query "DELETE" "$auth" "$deleteApi"
        fi
    done
}
getContainerId(){
#    echo "[EVENT] getting containerId..."
    json=$(query "GET" "$auth" "$listAppApi")
    _apps=$(echo $json|jq '.data' 2>/dev/null)
    _appCount=$(echo $_apps|jq '.|length' 2>/dev/null)
    _containerId=""
    for i in `seq 0 $_appCount`;
    do
        _appName=$(echo $_apps|jq '.['$i'].attributes.name'|sed 's/"//g' 2>/dev/null)
        if [ "$_appName" = "ss-kcp" ] ; then
                _containerId=$(echo $_apps|jq '.['$i'].relationships.container.data.id'|sed 's/"//g' 2>/dev/null)
        fi
    done
    echo $_containerId
}
getContainerInfo(){
#    echo "[EVENT] getting containerInfo..."
    json=$(query "GET" "$auth" "$listContainerApi")
    _containers=$(echo $json|jq '.data' 2>/dev/null)
    _containerCount=$(echo $_containers|jq '.|length' 2>/dev/null)
    _containerInfo=""
    for i in `seq 0 $_containerCount`;
    do
        _containerId=$(echo $json|jq '.data['$i'].id' 2>/dev/null|sed 's/"//g' 2>/dev/null)
        if [ "$_containerId" = "$1" ] ; then
                _containerInfo=$(echo $json|jq '.data['$i']' 2>/dev/null)
        fi
    done
    echo $_containerInfo

}

resetGfwApp(){
    echo "[EVENT] "`getLocalTime`" resetGfwApp ..."

    containerId=$(getContainerId)
    echo "[EVENT] "`getLocalTime`" got containerId ... $containerId"

    [ "$containerId" = "" ] && noContainerCount=$(($noContainerCount + 1))

    echo "[EVENT] "`getLocalTime`" noContainerCount=$noContainerCount"

    if [ $checkFeq -gt 0 ];then
        if [ $noPortCount -gt 0 ] || [ $noContainerCount -gt 0 ];then
            checkFeq=$(($checkFeq - 10))
        fi
    fi

    containerInfo=$(getContainerInfo "$containerId")
    echo "[EVENT] "`getLocalTime`" got containerInfo ... $containerInfo"

    if [ `echo $containerInfo|wc -c` -gt 100 ];then
        checkFeq=$ARUKAS_CHECK_FEQ
        _envs=$(echo $containerInfo|jq '.attributes.envs' 2>/dev/null)
        _envCount=$(echo $_envs |jq '.|length' )
        _ports=$(echo $containerInfo|jq '.attributes.ports' 2>/dev/null)
        _portCount=$(echo $_ports |jq '.|length' 2>/dev/null)
        _portMappings=$(echo $containerInfo|jq '.attributes.port_mappings' 2>/dev/null)
        _updateAt=$(echo $containerInfo|jq '.attributes.updated_at' 2>/dev/null)
        _updateDate=$(echo $_updateAt|sed 's/"//g'|awk -FT '{print $1}' 2>/dev/null)
        _updateTimeStamp=0
        [ "$_updateDate" != "" ] && _updateTimeStamp=$(date -d $_updateDate +%s 2>/dev/null)

        for i in `seq 0 $_envCount`;
        do
            _env=$(echo $_envs |jq '.['$i'].key'|sed 's/"//g' 2>/dev/null)

            if [ "$_env" = "KCP_SERVER_PORT" ] ;then
                _kcpServerPort=$(echo $_envs |jq '.['$i'].value'|sed 's/"//g' 2>/dev/null)
            fi
            if [ "$_env" = "SS_SERVER_PORT" ] ;then
                _ssServerPort=$(echo $_envs |jq '.['$i'].value'|sed 's/"//g' 2>/dev/null)
            fi
        done

        for i in `seq 0 $_portCount`;
        do
            _protocol=$(echo $_ports |jq '.['$i'].protocol'|sed 's/"//g' 2>/dev/null)
            _protocol_port=$(echo $_ports |jq '.['$i'].number'|sed 's/"//g' 2>/dev/null)
            if [ "$_protocol" = "udp" ] && [ "$_protocol_port" = "$_kcpServerPort" ] ;then
                _kcpUdpPortIndex=$i
            fi
            if [ "$_protocol" = "tcp" ] && [ "$_protocol_port" = "$_ssServerPort" ] ;then
                _ssTcpPortIndex=$i
            fi
        done

        open_udp_port=$(echo $containerInfo|jq '.attributes.port_mappings[0]['$_kcpUdpPortIndex'].service_port'|sed 's/"//g' 2>/dev/null)
        open_host=$(echo $containerInfo|jq '.attributes.port_mappings[0]['$_kcpUdpPortIndex'].host'|sed 's/"//g' 2>/dev/null)
        open_tcp_port=$(echo $containerInfo|jq '.attributes.port_mappings[0]['$_ssTcpPortIndex'].service_port'|sed 's/"//g' 2>/dev/null)

        restart=false

        [ "$SS_SERVER_PORT" != "$open_tcp_port" ] && [ "null" != "$open_tcp_port" ] && [ "" != "$open_tcp_port" ] && SS_SERVER_PORT=$open_tcp_port && restart=true && export SS_SERVER_PORT
        [ "$KCP_SERVER_PORT" != "$open_udp_port" ] && [ "null" != "$open_udp_port" ] && [ "" != "$open_udp_port" ] && KCP_SERVER_PORT=$open_udp_port && restart=true && export KCP_SERVER_PORT
        [ "$KCP_SERVER_ADDR" != "$open_host" ] && [ "null" != "$open_host" ] && [ "" != "$open_host" ] && KCP_SERVER_ADDR=$open_host && restart=true && export KCP_SERVER_ADDR

        if [ $restart == true ] ;then
            echo "[EVENT] "`getLocalTime`
            echo "[EVENT] KCP_SERVER_PORT: $KCP_SERVER_PORT"
            echo "[EVENT] KCP_SERVER_ADDR: $KCP_SERVER_ADDR"
            if [ `ps aux |grep kcp|grep -v grep|wc -l` -gt 0 ]; then
                echo "[EVENT] restarting KCP_CLIENT ..."
                ps aux |grep kcp|grep -v grep|awk '{print $1}' |xargs kill -9
            fi
            if [ `ps aux |grep cow|grep -v grep|wc -l` -gt 0 ]; then
                echo "[EVENT] restarting COW_CLIENT ..."
                ps aux |grep cow|grep -v grep|awk '{print $1}' |xargs kill -9
            fi

            nohup kcp-client -l :$KCP_LOCAL_PORT -r $KCP_SERVER_ADDR:$KCP_SERVER_PORT --crypt $KCP_CRYPT --mtu $KCP_MTU --mode $KCP_MODE --dscp $KCP_DSCP $KCP_OPTIONS --log /dev/stdout &
            cp /etc/cow/rc /etc/cow/rc.run \
            && echo "alwaysProxy = true" >> /etc/cow/rc.run \
            && echo "loadBalance = backup" >> /etc/cow/rc.run \
            && echo "estimateTarget = www.google.com" >> /etc/cow/rc.run \
            && echo "dialTimeout = 3s" >> /etc/cow/rc.run \
            && echo "proxy = socks5://127.0.0.1:${SS_LOCAL_PORT}" >> /etc/cow/rc.run \
            && echo "proxy = ss://${SS_METHOD}-auth:${SS_PASSWORD}@${KCP_SERVER_ADDR}:${SS_SERVER_PORT}" >> /etc/cow/rc.run
            nohup cow -rc=/etc/cow/rc.run ${COW_DEBUG} -logFile=/dev/stdout -listen=http://${COW_LOCAL_ADDR}:${COW_LOCAL_PORT} &
        fi

        if [ "$open_udp_port" = "null" ] && [ "$containerId" != "" ];then
            noPortCount=$(($noPortCount + 1))

            if [ $checkFeq -gt 0 ];then
                if [ $noPortCount -gt 0 ] || [ $noContainerCount -gt 0 ];then
                    checkFeq=$(($checkFeq - 10))
                fi
            fi
        fi
        echo "[EVENT] "`getLocalTime`" noPortCount=$noPortCount"

    fi

    if [ $noPortCount -gt 5 ];then
        deleteApps
        echo $(createApp)
        sleep 5
        echo $(powerUpContainer)
        sleep 10
        noPortCount=0
        noContainerCount=0
    fi

    if [ $noContainerCount -gt 5 ];then
        deleteApps
        echo $(createApp)
        sleep 5
        echo $(powerUpContainer)
        sleep 10
        noPortCount=0
        noContainerCount=0
    fi

    if [ $(($_updateTimeStamp - 1482364800)) -gt 0 ] && [ $((`date -u +%s` - $_updateTimeStamp)) -gt 86400 ] && [ $((`date -u +%H` + 8 - 3)) -gt 0 ];then
        deleteApps
        echo $(createApp)
        sleep 5
        echo $(powerUpContainer)
        sleep 10
        noPortCount=0
        noContainerCount=0
    fi
    echo "`getLocalTime` sleeping ${checkFeq} ..."
    sleep $checkFeq

}

echo $auth
while true; do
    resetGfwApp
done