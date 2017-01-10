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

noContainerCount=0
noPortCount=0

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
    echo "[EVENT] creating app..."
    query "POST" "$auth" "$createAppApi" "{\"data\": [{\"type\": \"containers\", \"attributes\": {\"image_name\": \"${DOCKER_IMAGE}\", \"instances\": 1, \"mem\": 512, \"cmd\": \"\", \"envs\": [{\"key\": \"SS_SERVER_PORT\", \"value\": \"${SS_SERVER_PORT}\"}, {\"key\": \"SS_PASSWORD\", \"value\": \"${SS_PASSWORD}\"}, {\"key\": \"KCP_SERVER_PORT\", \"value\": \"${KCP_SERVER_PORT}\"}, {\"key\": \"KCP_CRYPT\", \"value\": \"${KCP_CRYPT}\"}, {\"key\": \"KCP_DSCP\", \"value\": \"${KCP_DSCP}\"}, {\"key\": \"KCP_OPTIONS\", \"value\": \"${KCP_OPTIONS}\"}, {\"key\": \"KCP_MTU\", \"value\": \"${KCP_MTU}\"} ], \"ports\": [{\"number\": ${SS_SERVER_PORT}, \"protocol\": \"tcp\"}, {\"number\": ${KCP_SERVER_PORT}, \"protocol\": \"udp\"} ]} }, {\"type\": \"apps\", \"attributes\": {\"name\": \"ss-kcp\"} } ] }"
}

powerUpContainer(){
    containerId=$(getContainerId)
    powerApi="https://app.arukas.io/api/containers/$containerId/power"
    echo "[EVENT] starting container..."
    query "POST" "$auth" "$powerApi"
    sleep 3
    echo "[EVENT] stopping container..."
    query "DELETE" "$auth" "$powerApi"
    sleep 3
    echo "[EVENT] starting container..."
    query "POST" "$auth" "$powerApi"

}

deleteApps(){
    json=$(query "GET" "$auth" "$listAppApi")
    _apps=$(echo $json|jq '.data')
    _appCount=$(echo $_apps|jq '.|length')
    for i in `seq 0 $_appCount`;
    do
        _appName=$(echo $_apps|jq '.['$i'].attributes.name'|sed 's/"//g')
        if [ "$_appName" = "ss-kcp" ] ; then
            _appId=$(echo $_apps|jq '.['$i'].id'|sed 's/"//g')
            deleteApi="https://app.arukas.io/api/apps/$_appId"
            echo "[EVENT] deleteing app... [$_appId]"
            query "DELETE" "$auth" "$deleteApi"
        fi
    done
}
getContainerId(){
#    echo "[EVENT] getting containerId..."
    json=$(query "GET" "$auth" "$listAppApi")
    _apps=$(echo $json|jq '.data')
    _appCount=$(echo $_apps|jq '.|length')
    _containerId=""
    for i in `seq 0 $_appCount`;
    do
        _appName=$(echo $_apps|jq '.['$i'].attributes.name'|sed 's/"//g')
        if [ "$_appName" = "ss-kcp" ] ; then
                _containerId=$(echo $_apps|jq '.['$i'].relationships.container.data.id'|sed 's/"//g')
        fi
    done
    echo $_containerId
}
getContainerInfo(){
#    echo "[EVENT] getting containerInfo..."
    json=$(query "GET" "$auth" "$listContainerApi")
    _containers=$(echo $json|jq '.data')
    _containerCount=$(echo $_containers|jq '.|length')
    _containerInfo=""
    for i in `seq 0 $_containerCount`;
    do
        _containerId=$(echo $json|jq '.data['$i'].id'|sed 's/"//g')
        if [ "$_containerId" = "$1" ] ; then
                _containerInfo=$(echo $json|jq '.data['$i']')
        fi
    done
    echo $_containerInfo

}

resetGfwApp(){
    echo "[EVENT] resetGfwApp ..."

    containerId=$(getContainerId)
    echo "[EVENT] got containerId ... $containerId"

    [ "$containerId" = "" ] && noContainerCount=$(($noContainerCount + 1))

    echo "noContainerCount=$noContainerCount"

    containerInfo=$(getContainerInfo "$containerId")
    echo "[EVENT] got containerInfo ... $containerInfo"

    _envs=$(echo $containerInfo|jq '.attributes.envs')
    _envCount=$(echo $_envs |jq '.|length' )
    _ports=$(echo $containerInfo|jq '.attributes.ports')
    _portCount=$(echo $_ports |jq '.|length' )
    _portMappings=$(echo $containerInfo|jq '.attributes.port_mappings')
    _updateAt=$(echo $containerInfo|jq '.attributes.updated_at')
    _updateDate=$(echo $_updateAt|sed 's/"//g'|awk -FT '{print $1}')
    _updateTimeStamp=0
    [ "$_updateDate" != "" ] && _updateTimeStamp=$(date -d $_updateDate +%s)

    for i in `seq 0 $_envCount`;
    do
        _env=$(echo $_envs |jq '.['$i'].key'|sed 's/"//g')

        if [ "$_env" = "KCP_SERVER_PORT" ] ;then
            _kcpServerPort=$(echo $_envs |jq '.['$i'].value'|sed 's/"//g')
        fi
        if [ "$_env" = "SS_SERVER_PORT" ] ;then
            _ssServerPort=$(echo $_envs |jq '.['$i'].value'|sed 's/"//g')
        fi
    done

    for i in `seq 0 $_portCount`;
    do
        _protocol=$(echo $_ports |jq '.['$i'].protocol'|sed 's/"//g')
        _protocol_port=$(echo $_ports |jq '.['$i'].number'|sed 's/"//g')
        if [ "$_protocol" = "udp" ] && [ "$_protocol_port" = "$_kcpServerPort" ] ;then
            _kcpUdpPortIndex=$i
        fi
        if [ "$_protocol" = "tcp" ] && [ "$_protocol_port" = "$_ssServerPort" ] ;then
            _ssTcpPortIndex=$i
        fi
    done

    open_udp_port=$(echo $containerInfo|jq '.attributes.port_mappings[0]['$_kcpUdpPortIndex'].service_port'|sed 's/"//g')
    open_host=$(echo $containerInfo|jq '.attributes.port_mappings[0]['$_kcpUdpPortIndex'].host'|sed 's/"//g')
    open_tcp_port=$(echo $containerInfo|jq '.attributes.port_mappings[0]['$_ssTcpPortIndex'].service_port'|sed 's/"//g')

    [ "$open_udp_port" = "null" ] && [ "$containerId" != "" ] && noPortCount=$(($noPortCount + 1))
    echo "noPortCount=$noPortCount"

    restart=false

    [ "$SS_SERVER_PORT" != "$open_tcp_port" ] && [ "null" != "$open_tcp_port" ] && [ "" != "$open_tcp_port" ] && SS_SERVER_PORT=$open_tcp_port && restart=true && export SS_SERVER_PORT
    [ "$KCP_SERVER_PORT" != "$open_udp_port" ] && [ "null" != "$open_udp_port" ] && [ "" != "$open_udp_port" ] && KCP_SERVER_PORT=$open_udp_port && restart=true && export KCP_SERVER_PORT
    [ "$KCP_SERVER_ADDR" != "$open_host" ] && [ "null" != "$open_host" ] && [ "" != "$open_host" ] && KCP_SERVER_ADDR=$open_host && restart=true && export KCP_SERVER_ADDR

    if [ $restart == true ] ;then
        echo "[EVENT] "`date`
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
    sleep $ARUKAS_CHECK_FEQ

}

echo $auth
while true; do
    resetGfwApp
done