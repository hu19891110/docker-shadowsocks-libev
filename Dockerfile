#
# Dockerfile for shadowsocks-libev and kcptun
#

FROM alpine
MAINTAINER tofuliang@gmail.com

ENV SS_VER 2.6.1
ENV SS_URL https://github.com/shadowsocks/shadowsocks-libev/archive/v$SS_VER.tar.gz
ENV SS_DIR shadowsocks-libev-$SS_VER

ENV KCP_VER 20170112
ENV KCP_URL https://github.com/xtaci/kcptun/releases/download/v$KCP_VER/kcptun-linux-amd64-$KCP_VER.tar.gz

ENV COW_VER 0.9.8
ENV COW_URL https://github.com/cyfdecyf/cow/releases/download/$COW_VER/cow-linux64-$COW_VER.gz

RUN set -ex \
    && apk add --no-cache pcre openssh \
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
        && curl -sSL $COW_URL |gzip -d > /usr/local/bin/cow \
        && chmod a+x /usr/local/bin/cow \
        && mkdir /etc/cow \
        && curl -sSL https://raw.githubusercontent.com/cyfdecyf/cow/master/doc/sample-config/rc > /etc/cow/rc \
    && apk del TMP \
    && cd /lib && ln -s libcrypto.so.38 libcrypto.so.1.0.0 \
    && cd /usr/lib && ln -s ../../lib/libcrypto.so.1.0.0 libcrypto.so.1.0.0 \
    && ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -P "" \
    && echo "PermitRootLogin yes"  >> /etc/ssh/sshd_config \
    && echo "#!/bin/sh" >> /usr/local/bin/server.sh \
    && echo "" >> /usr/local/bin/server.sh \
    && echo "echo root:\$SSH_PASS|chpasswd;" >> /usr/local/bin/server.sh \
    && echo "/usr/sbin/sshd;" >> /usr/local/bin/server.sh \
    && echo "nohup kcp-server -l :\$KCP_SERVER_PORT -t 127.0.0.1:\$SS_SERVER_PORT --crypt \$KCP_CRYPT --mtu \$KCP_MTU --mode \$KCP_MODE --dscp \$KCP_DSCP \$KCP_OPTIONS &" >> /usr/local/bin/server.sh \
    && echo "ss-server -s "\$SS_SERVER_ADDR" -p "\$SS_SERVER_PORT" -m "\$SS_METHOD" -k "\$SS_PASSWORD" -t "\$SS_TIMEOUT" -d "\$DNS_ADDR" -u -A --fast-open \$SS_OPTIONS" >> /usr/local/bin/server.sh \
    && chmod a+x /usr/local/bin/server.sh


ENV SS_SERVER_ADDR 0.0.0.0
ENV SS_SERVER_PORT 23493
ENV SS_LOCAL_ADDR 0.0.0.0
ENV SS_LOCAL_PORT  1080
ENV SS_METHOD      aes-256-cfb
ENV SS_TIMEOUT     60
ENV DNS_ADDR       8.8.8.8
ENV SS_PASSWORD=
ENV SS_OPTIONS=
ENV SSH_PASS=toor


ENV KCP_SERVER_ADDR=
ENV KCP_SERVER_PORT 33493
ENV KCP_LOCAL_PORT 33493
ENV KCP_CRYPT aes-128
ENV KCP_MTU 1350
ENV KCP_MODE fast
ENV KCP_DSCP 0
ENV KCP_OPTIONS=

ENV COW_LOCAL_ADDR 0.0.0.0
ENV COW_LOCAL_PORT 7777

CMD /usr/local/bin/server.sh
