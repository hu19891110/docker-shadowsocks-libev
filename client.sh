#!/bin/sh

if [ "" != "$KCP_SERVER_PORT" ] &&  [ "" != "$KCP_SERVER_ADDR" ];then
    nohup kcp-client -l :$KCP_LOCAL_PORT -r $KCP_SERVER_ADDR:$KCP_SERVER_PORT --crypt $KCP_CRYPT --mtu $KCP_MTU --mode $KCP_MODE --dscp $KCP_DSCP $KCP_OPTIONS &
fi
nohup ss-local -s 127.0.0.1 -p $KCP_LOCAL_PORT  -l $SS_LOCAL_PORT -k $SS_PASSWORD -m $SS_METHOD -t $SS_TIMEOUT -b $SS_LOCAL_ADDR -A --fast-open $SS_OPTIONS &
auth="authorization: Basic `echo $ARUKAS_TOKEN:$ARUKAS_SECERT|tr -d "\n" |base64|tr -d "\n"`"
api=https://app.arukas.io/api/containers
_kcpServerPort=x
_kcpUdpPortIndex=x
_ssServerPort=x
_ssTcpPortIndex=x

query() {
    wget --quiet \
    --no-check-certificate \
    --method $1 \
    --header "'content-type: application/vnd.api+json'" \
    --header "'accept: application/vnd.api+json'" \
    --header "$2" \
    --header "'cache-control: no-cache'" \
    --output-document \
    - $3
}

while true; do
    restart=false
    json=$(query "GET" "$auth" "$api")
    _containerId=$(echo $json|jq '.data[0].id'|sed 's/"//g')
    _envs=$(echo $json|jq '.data[0].attributes.envs')
    _envCount=$(echo $_envs |jq '.|length' )
    _ports=$(echo $json|jq '.data[0].attributes.ports')
    _portCount=$(echo $_ports |jq '.|length' )
    _portMappings=$(echo $json|jq '.data[0].attributes.port_mappings')
    _updateAt=$(echo $json|jq '.data[0].attributes.updated_at')
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

    open_udp_port=$(echo $json|jq '.data[0].attributes.port_mappings[0]['$_kcpUdpPortIndex'].service_port'|sed 's/"//g')
    open_host=$(echo $json|jq '.data[0].attributes.port_mappings[0]['$_kcpUdpPortIndex'].host'|sed 's/"//g')
    open_tcp_port=$(echo $json|jq '.data[0].attributes.port_mappings[0]['$_ssTcpPortIndex'].service_port'|sed 's/"//g')

    [ "$SS_SERVER_PORT" != "$open_tcp_port" ] && [ "null" != "$open_tcp_port" ] && SS_SERVER_PORT=$open_tcp_port && restart=true && export SS_SERVER_PORT
    [ "$KCP_SERVER_PORT" != "$open_udp_port" ] && [ "null" != "$open_udp_port" ] && KCP_SERVER_PORT=$open_udp_port && restart=true && export KCP_SERVER_PORT
    [ "$KCP_SERVER_ADDR" != "$open_host" ] && [ "null" != "$open_host" ] && KCP_SERVER_ADDR=$open_host && restart=true && export KCP_SERVER_ADDR

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

        [ "$KCP_SERVER_ADDR"x != "x" ] && [ "$KCP_SERVER_PORT"x != "x" ] && nohup kcp-client -l :$KCP_LOCAL_PORT -r $KCP_SERVER_ADDR:$KCP_SERVER_PORT --crypt $KCP_CRYPT --mtu $KCP_MTU --mode $KCP_MODE --dscp $KCP_DSCP $KCP_OPTIONS &
        cp /etc/cow/rc /etc/cow/rc.run \
        && echo "alwaysProxy = true" >> /etc/cow/rc.run \
        && echo "loadBalance = backup" >> /etc/cow/rc.run \
        && echo "estimateTarget = www.google.com" >> /etc/cow/rc.run \
        && echo "dialTimeout = 3s" >> /etc/cow/rc.run \
        && echo "proxy = ss://${SS_METHOD}-auth:${SS_PASSWORD}@127.0.0.1:${KCP_LOCAL_PORT}" >> /etc/cow/rc.run \
        && echo "proxy = ss://${SS_METHOD}-auth:${SS_PASSWORD}@${KCP_SERVER_ADDR}:${SS_SERVER_PORT}" >> /etc/cow/rc.runx
        nohup cow -rc=/etc/cow/rc.run -listen=http://${COW_LOCAL_ADDR}:${COW_LOCAL_PORT} &
    fi
    if [ $(($_updateTimeStamp - 1482364800)) -gt 0 ] && [ $((`date -u +%s` - $_updateTimeStamp)) -gt 86400 ] && [ $((`date -u +%H` + 8 - 3)) -eq 0 ];then
        powerApi="https://app.arukas.io/api/containers/$_containerId/power"
        echo "[EVENT] "`date`
        echo "[EVENT] stopping container..."
        query "DELETE" "$auth" "$powerApi"
        sleep 3
        echo "[EVENT] starting container..."
        query "POST" "$auth" "$powerApi"
    fi
    sleep $ARUKAS_CHECK_FEQ
done
