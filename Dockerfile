#
# Dockerfile for shadowsocks-libev and kcptun
#

FROM alpine
MAINTAINER tofuliang@gmail.com

ENV SS_VER 2.5.6
ENV SS_URL https://github.com/shadowsocks/shadowsocks-libev/archive/v$SS_VER.tar.gz
ENV SS_DIR shadowsocks-libev-$SS_VER

ENV KCP_VER 20161207
ENV KCP_URL https://github.com/xtaci/kcptun/releases/download/v$KCP_VER/kcptun-linux-amd64-$KCP_VER.tar.gz

RUN set -ex \
    && apk add --no-cache pcre \
    && apk add --no-cache \
               --virtual TMP autoconf \
                             build-base \
                             curl \
                             libtool \
                             linux-headers \
                             openssl-dev \
                             pcre-dev \
    && curl -sSL $SS_URL | tar xz \
    && cd $SS_DIR \
        && ./configure --disable-documentation \
        && make -j${NPROC} install \
        && cd .. \
        && rm -rf $SS_DIR \
        && curl -sSL $KCP_URL |tar xz -C /usr/local/bin \
        && mv /usr/local/bin/server_linux_amd64 /usr/local/bin/kcp-server \
        && mv /usr/local/bin/client_linux_amd64 /usr/local/bin/kcp-client \
    && apk del --virtual TMP \
    && echo "#!/bin/sh" >> /usr/local/bin/server.sh \
    && echo "" >> /usr/local/bin/server.sh \
    && echo "nohup kcp-server -l :\$KCP_SERVER_PORT -t 127.0.0.1:\$SS_SERVER_PORT --crypt \$KCP_CRYPT --mtu \$KCP_MTU --mode \$KCP_MODE --dscp \$KCP_DSCP \$KCP_OPTIONS &" >> /usr/local/bin/server.sh \
    && echo "ss-server -s "\$SS_SERVER_ADDR" -p "\$SS_SERVER_PORT" -m "\$SS_METHOD" -k "\$SS_PASSWORD" -t "\$SS_TIMEOUT" -d "\$DNS_ADDR" -u -A --fast-open \$SS_OPTIONS" >> /usr/local/bin/server.sh \
    && chmod a+x /usr/local/bin/server.sh \
    \
    && echo "#!/bin/sh" >> /usr/local/bin/client.sh \
    && echo "" >> /usr/local/bin/client.sh \
    && echo "nohup kcp-client -l :\$KCP_LOCAL_PORT -r \$KCP_SERVER_ADDR:\$KCP_SERVER_PORT --crypt \$KCP_CRYPT --mtu \$KCP_MTU --mode \$KCP_MODE --dscp \$KCP_DSCP \$KCP_OPTIONS &" >> /usr/local/bin/client.sh \
    && echo "ss-local -s 127.0.0.1 -p "\$KCP_LOCAL_PORT"  -l \$SS_LOCAL_PORT -k "\$SS_PASSWORD" -m "\$SS_METHOD" -t "\$SS_TIMEOUT" -b \$SS_LOCAL_ADDR -u -A --fast-open \$SS_OPTIONS" >> /usr/local/bin/client.sh \
    && chmod a+x /usr/local/bin/client.sh


ENV SS_SERVER_ADDR 0.0.0.0
ENV SS_SERVER_PORT 23493
ENV SS_LOCAL_ADDR 0.0.0.0
ENV SS_LOCAL_PORT  1080
ENV SS_METHOD      aes-256-cfb
ENV SS_TIMEOUT     60
ENV DNS_ADDR       8.8.8.8
ENV SS_PASSWORD=
ENV SS_OPTIONS=


ENV KCP_SERVER_ADDR=
ENV KCP_SERVER_PORT 33493
ENV KCP_LOCAL_PORT 33493
ENV KCP_CRYPT aes-128
ENV KCP_MTU 1350
ENV KCP_MODE fast
ENV KCP_DSCP 0
ENV KCP_OPTIONS=

EXPOSE $SS_SERVER_PORT/tcp
EXPOSE $SS_SERVER_PORT/udp
EXPOSE $SS_LOCAL_PORT/tcp
EXPOSE $SS_LOCAL_PORT/udp
EXPOSE $KCP_SERVER_PORT/tcp
EXPOSE $KCP_SERVER_PORT/udp
EXPOSE $KCP_LOCAL_PORT/tcp
EXPOSE $KCP_LOCAL_PORT/udp

CMD /usr/local/bin/server.sh
